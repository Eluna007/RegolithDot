#!/bin/bash
# Wofi flow retired — the Quickshell carousel (SUPER+W) is the only picker.
# This script just applies whatever path it's given.
selected="$1"
[ -z "$selected" ] && exit 0

# Remember this pick so it can be restored on the next boot.
echo "$selected" > "$HOME/.config/hypr/last-wallpaper.txt"

# Where matugen stages the colour it extracts, and where the login screen's
# copy of the wallpaper is taken from. matugen will not create the directory
# for an output_path, so it has to exist before matugen runs — on a fresh
# machine it does not.
STAGE="${XDG_CACHE_HOME:-$HOME/.cache}/apollo/theme"
mkdir -p "$STAGE"

# recolour <still-image>
#
# Everything downstream of the image being on screen, in one place so the
# still and animated branches below cannot drift apart. The argument is a
# *still*: the wallpaper itself, or a frame pulled out of a video — neither
# matugen nor the login screen can do anything with a video.
recolour() {
  local still="$1"

  matugen image "$still" --source-color-index 0

  # The lock screen's wallpaper path (hyprlock cannot read one out of a file),
  # written in the same run as the colours so the two cannot disagree.
  ~/.local/bin/hyprlock-wallpaper.sh

  # What the login screen should show. Its own copy is made by
  # apollo-sddm-sync, which runs as root; this only records where to find it,
  # because SDDM's greeter runs as its own user and cannot read $HOME at all.
  printf '%s\n' "$still" > "$STAGE/still.txt"

  # Recolour the shell, kitty, GTK, rofi and the staged login palette. A no-op
  # when dynamic colours are off, and it must never take the wallpaper down
  # with it if the settings binary was never built.
  #
  # Bounded, because an apollo-settings built before `theme` existed does not
  # reject the argument — it opens the settings *window* and blocks until you
  # close it, which would mean a GUI popping up on every single wallpaper
  # change. Newer builds exit non-zero on an unknown argument, so this only
  # bites a stale binary; it takes well under a second when it works at all.
  if command -v apollo-settings >/dev/null 2>&1; then
    if ! timeout 15 apollo-settings theme; then
      echo "wallpaper-switch: apollo-settings theme failed or timed out —" \
           "rebuild it if you have pulled since it was last built" >&2
    fi
  fi

  # And push it to the login screen, but only if that can be done without
  # asking for a password: this runs from a keybind and from session startup,
  # where a sudo prompt has nowhere to appear and would hang the script.
  # `sudo -n` fails immediately instead. Without the sudoers drop-in described
  # in MANUAL-INSTALL.md, run `sudo ~/.local/bin/apollo-sddm-sync` yourself.
  #
  # The absolute path is not tidiness. sudo replaces PATH with its own
  # `secure_path`, which on Arch is /usr/local/sbin:/usr/local/bin:/usr/sbin:
  # /usr/bin:/sbin:/bin — ~/.local/bin is not on it, so `sudo apollo-sddm-sync`
  # is "command not found" even with the script installed and the sudoers rule
  # in place. Named by its path, it resolves.
  local sync="$HOME/.local/bin/apollo-sddm-sync"
  if [ -x "$sync" ]; then
    sudo -n "$sync" >/dev/null 2>&1 || true
  fi
}

# spawn <command...> — start a background daemon that outlives this script.
#
# A plain `&` is not enough. This script is run from the shell's wallpaper
# picker, and anything it backgrounds stays in the script's process group — so
# when the caller reaps the script, the group goes with it and the wallpaper
# daemon dies seconds after starting. setsid puts it in a session of its own,
# where nothing upstream can take it down.
spawn() {
  if command -v setsid >/dev/null 2>&1; then
    setsid -f "$@" >/dev/null 2>&1
  else
    nohup "$@" >/dev/null 2>&1 &
    disown 2>/dev/null || true
  fi
}

# Start the new wallpaper before stopping the old one, always.
#
# Every flash of the bare Hyprland background came from doing it the other way
# round: kill the outgoing daemon, then spend a few hundred milliseconds
# starting the incoming one with nothing on screen in between. Switching from a
# video to a still was the worst of it, because the video branch had already
# killed hyprpaper, so the still had to cold-start it. Holding the old PIDs and
# killing them at the end means the outgoing wallpaper covers the screen right
# up until the incoming one is drawing.
old_mpv="$(pgrep -x mpvpaper 2>/dev/null | tr '\n' ' ')"
old_hypr="$(pgrep -x hyprpaper 2>/dev/null | tr '\n' ' ')"

retire() {
  # shellcheck disable=SC2086  # deliberately word-split: these are PID lists.
  [ -n "$1" ] && kill $1 2>/dev/null
  return 0
}

case "$selected" in
  *.gif|*.mp4|*.webm|*.mkv|*.mov)
    # Video AND gif both need mpvpaper — hyprpaper only ever shows a
    # static single frame, it can't animate a gif at all. mpv can loop
    # a gif exactly like a video.
    spawn mpvpaper -o "no-audio loop" '*' "$selected"

    # Wait for it to exist, then give it a moment to get its surface up.
    # There is nothing to ask mpvpaper about, so this is a settle rather than
    # a handshake — but it is bounded, and it is the difference between the
    # old wallpaper covering the gap and the compositor's default showing
    # through it.
    for _ in $(seq 1 40); do
      pgrep -x mpvpaper >/dev/null 2>&1 && break
      sleep 0.05
    done
    sleep 0.3

    retire "$old_mpv"
    retire "$old_hypr"

    # One frame, for everything that cannot animate: matugen, the lock screen
    # and the login screen. Kept in the cache rather than /tmp so it is still
    # there for the next boot's restore, and for a login screen sync run by
    # hand days later.
    FRAME="$STAGE/frame.png"
    ffmpeg -y -ss 00:00:01 -i "$selected" -frames:v 1 "$FRAME" -loglevel error
    recolour "$FRAME"
    ;;
  *)
    # Image-to-image: never restart hyprpaper. It swaps over its own IPC,
    # which is what avoids the flash of the bare compositor background.
    if [ -z "$old_hypr" ]; then
      spawn hyprpaper
      # Wait for hyprpaper's IPC to actually answer instead of guessing at a
      # sleep. A flat 0.5s was enough when hyprpaper was already warm, but not
      # at a cold start, where the compositor is bringing up the shell, two
      # portals and several daemons at the same time: the wallpaper request
      # landed before the socket was listening, was dropped, and the session
      # came up on the default Hyprland background.
      for _ in $(seq 1 60); do
        hyprctl hyprpaper listactive >/dev/null 2>&1 && break
        sleep 0.25
      done
    fi

    # hyprpaper's IPC no longer has `preload` (nor `unload`/`listloaded`) —
    # `wallpaper` loads the image on demand. Calling preload just returns
    # "invalid hyprpaper request". The surviving requests are:
    #   hyprctl hyprpaper wallpaper '[mon], [path], [fit_mode]'
    #   hyprctl hyprpaper listactive
    # Empty monitor = fallback, i.e. every output.
    if ! hyprctl hyprpaper wallpaper ",$selected,fill"; then
      echo "wallpaper-switch: hyprpaper rejected the wallpaper request" >&2
      exit 1
    fi

    # Only now: the still is up, so the video underneath it can go.
    retire "$old_mpv"

    recolour "$selected"
    ;;
esac
