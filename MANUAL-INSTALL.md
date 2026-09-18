# Apollo — Install Guide

Fresh Arch → riced desktop. Steps 1–7 in order.

There is no `install.sh`. Configs are deployed as symlinks into `~/.config`, so
edits in the repo are live and `git diff` shows what you changed.

---

## 1. Prerequisites

```bash
# An AUR helper. If you don't have one:
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay && makepkg -si
```

---

## 2. Packages

### 2.1 Core desktop

```bash
sudo pacman -S --needed \
  hyprland hypridle hyprlock hyprsunset \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  sddm qt6-wayland
```

Hyprland must be new enough to read `hyprland.lua`. Check with
`hyprctl version`; if it only knows `hyprland.conf`, Apollo won't load.

### 2.2 Shell

```bash
yay -S quickshell
```

### 2.3 Audio, network, bluetooth

```bash
sudo pacman -S pipewire wireplumber pipewire-pulse pipewire-alsa
sudo pacman -S networkmanager network-manager-applet bluez bluez-utils
```

### 2.4 Wallpaper, screenshots, clipboard

```bash
yay -S awww cliphist
sudo pacman -S grim slurp wl-clipboard
```

### 2.5 Terminal, launcher, file manager

```bash
sudo pacman -S \
  kitty rofi thunar tumbler ffmpegthumbnailer \
  gvfs gnome-themes-extra xdg-utils
```

### 2.6 Shell and editor

```bash
sudo pacman -S fish neovim git
```

### 2.7 Fonts and icons

```bash
sudo pacman -S ttf-jetbrains-mono-nerd papirus-icon-theme noto-fonts-emoji
```

### 2.8 System utilities

```bash
sudo pacman -S brightnessctl keyd htop pacman-contrib jq playerctl imagemagick
# playerctl + imagemagick drive the lock screen's music widgets and album art
# pacman-contrib provides `checkupdates` (bar update count) and `paccache`
# jq drives the keybind cheatsheet's `hyprctl binds -j` parsing
```

### 2.9 Apps, media, system info

```bash
sudo pacman -S firefox discord steam code mpv imv fastfetch
sudo pacman -S ranger 7zip zip wget openssh
yay -S spotify-launcher dgop
# ranger_devicons is vendored in this repo — nothing to install
```

### 2.10 Optional

```bash
# CPU temp in the bar — read from sysfs. To guarantee the module on boot:
grep -q AuthenticAMD /proc/cpuinfo && M=k10temp || M=coretemp
echo "$M" | sudo tee /etc/modules-load.d/apollo-temp.conf

sudo pacman -S upower            # battery stats in the system monitor panel
sudo pacman -S w3m python-pillow # ranger image previews
sudo pacman -S atool unrar unzip # ranger archive handling
sudo pacman -S lua               # lets apollo-doctor syntax-check the config
sudo pacman -S cava              # layout18's lock screen audio visualiser
```

Airplane mode uses `rfkill`, already in `util-linux`.

---

## 3. Services

```bash
sudo systemctl enable --now NetworkManager bluetooth
sudo systemctl enable --now keyd
sudo systemctl enable --now paccache.timer
sudo systemctl enable sddm
```

---

## 4. Themes

### 4.1 SDDM

The login screen is Apollo's own theme (`sddm/themes/apollo`), and it is the
one thing here that is **copied rather than symlinked**. SDDM's greeter runs as
the unprivileged `sddm` user before any session exists: it cannot read anything
under your home directory, so it cannot follow a symlink into this repo, and it
cannot be pointed at your wallpaper either.

```bash
sudo cp -r sddm/themes/apollo /usr/share/sddm/themes/apollo

# sddm.conf.d does not exist until something puts a file in it, and a fresh
# sddm install ships no drop-ins at all.
sudo mkdir -p /etc/sddm.conf.d
sudo cp sddm/sddm.conf /etc/sddm.conf.d/10-theme.conf
```

Then give it the current palette and wallpaper — this is the command to re-run
any time you want the login screen caught up by hand:

```bash
sudo ~/.local/bin/apollo-sddm-sync
```

**The full path is required, not tidiness.** `sudo` replaces `PATH` with its own
`secure_path`, and `~/.local/bin` is not on it — plain `sudo apollo-sddm-sync`
is "command not found" no matter how the script is installed.

That needs `apollo-settings` to have generated a palette first, which happens on
the first wallpaper change with **Dynamic colors** on (apollo-settings › Theme),
or immediately with `apollo-settings theme`.

**Optional: let a wallpaper change do it for you.** `wallpaper-switch.sh` tries
`sudo -n ~/.local/bin/apollo-sddm-sync` on every change, which does nothing unless that one
command is passwordless — a wallpaper keybind has nowhere to show a password
prompt. If you want the login screen to follow automatically, and you accept
what the rule means, add it:

```bash
echo "$USER ALL=(root) NOPASSWD: /home/$USER/.local/bin/apollo-sddm-sync" \
  | sudo tee /etc/sudoers.d/apollo-sddm-sync
sudo chmod 0440 /etc/sudoers.d/apollo-sddm-sync
```

Worth understanding before you do: that grants passwordless root to whatever
that path contains, so anyone who can write the file can run anything as root.
It is your own home directory, so that is you — but it does mean a symlink you
pull from this repo is running as root on every wallpaper change. Skipping this
costs nothing except running `sudo ~/.local/bin/apollo-sddm-sync` yourself.

### 4.2 Tailscale (optional)

The bar has a Tailscale widget. It runs `tailscale up`, `down` and `set`, and
all three write to the daemon — which belongs to root until this user is made
the **operator**. Without that the toggle only ever produces a permission
error, which reads as a broken switch rather than one that was never allowed:

```bash
sudo pacman -S tailscale
sudo systemctl enable --now tailscaled
sudo tailscale set --operator=$USER
```

That last line is the one the widget needs, and it is Tailscale's own
mechanism rather than a sudoers rule. The difference is the one that matters:
it hands over control of this one daemon, not the ability to run anything as
root. `apollo-doctor` reports whether it has been done.

If you would rather not grant it at all, the widget still shows your status,
peers and exit nodes — it just cannot change them, and it offers to copy the
command above when you try.

### 4.3 GTK

```bash
mkdir -p ~/.themes
curl -sL \
  "https://github.com/catppuccin/gtk/releases/download/v1.0.3/catppuccin-mocha-lavender-standard%2Bdefault.zip" \
  -o /tmp/catppuccin-gtk.zip
7z x -y /tmp/catppuccin-gtk.zip -o ~/.themes/
```

### 4.4 Cursors

Not vendored here — install the package:

```bash
yay -S bibata-cursor-theme
```

Then point `config/gtk-3.0/settings.ini` and `config/gtk-4.0/settings.ini` at
whatever you installed (they currently say `Nero-Cyber-Cyan`, inherited from
upstream).

---

## 5. Deploy

```bash
git clone https://github.com/Eluna007/RegolithDot ~/RegolithDot
cd ~/RegolithDot

mkdir -p ~/.config/quickshell ~/.local/share

ln -sfn ~/RegolithDot/config/hypr                  ~/.config/hypr
ln -sfn ~/RegolithDot/config/quickshell/apollo     ~/.config/quickshell/apollo
ln -sfn ~/RegolithDot/config/rofi                  ~/.config/rofi
ln -sfn ~/RegolithDot/config/kitty                 ~/.config/kitty
ln -sfn ~/RegolithDot/config/fish                  ~/.config/fish
ln -sfn ~/RegolithDot/config/nvim                  ~/.config/nvim
ln -sfn ~/RegolithDot/config/gtk-3.0               ~/.config/gtk-3.0
ln -sfn ~/RegolithDot/config/gtk-4.0               ~/.config/gtk-4.0
ln -sfn ~/RegolithDot/config/ranger                ~/.config/ranger
ln -sfn ~/RegolithDot/config/Thunar                ~/.config/Thunar
ln -sfn ~/RegolithDot/config/fastfetch             ~/.config/fastfetch
ln -sfn ~/RegolithDot/config/dgop                  ~/.config/dgop
ln -sfn ~/RegolithDot/config/xdg-desktop-portal    ~/.config/xdg-desktop-portal
ln -sfn ~/RegolithDot/config/hyprlock             ~/.config/hyprlock
ln -sfn ~/RegolithDot/config/matugen              ~/.config/matugen

ln -sfn ~/RegolithDot/local/share/icons/Apollo-Terminal ~/.local/share/icons/Apollo-Terminal
ln -sfn ~/RegolithDot/local/share/PrismLauncher         ~/.local/share/PrismLauncher

# Scripts the config calls by path: autostart.lua runs restore-wallpaper.sh,
# the keybinds run osd-report.sh, and the wallpaper picker runs
# wallpaper-switch.sh. Symlinked, so `git pull` updates them.
# apollo-lock-layout has no .sh suffix (it is meant to be typed), so it needs
# the second line.
mkdir -p ~/.local/bin
for s in ~/RegolithDot/local/bin/*.sh; do ln -sfn "$s" ~/.local/bin/"$(basename "$s")"; done
ln -sfn ~/RegolithDot/local/bin/apollo-lock-layout ~/.local/bin/apollo-lock-layout
ln -sfn ~/RegolithDot/local/bin/apollo-sddm-sync ~/.local/bin/apollo-sddm-sync
ln -sfn ~/RegolithDot/local/bin/apollo-paper-layout ~/.local/bin/apollo-paper-layout

# keyd is system-wide and needs a real copy, not a symlink
sudo cp config/keyd/default.conf /etc/keyd/default.conf
sudo keyd reload
```

The shell is a *named* Quickshell config, so it launches as `qs -c apollo`
(that's what `lua/autostart.lua` does, and what the `qs -c apollo ipc call`
binds target). Symlinking it anywhere other than
`~/.config/quickshell/apollo` will break those.

Wallpapers aren't vendored — put some in `~/Pictures/Wallpapers`.

---

## 6. Post-install

```bash
# Settings GUI (needs Go)
sudo pacman -S --needed go
# One line on purpose. A `\` line continuation with a trailing space after it
# is not a continuation at all — the space is what gets escaped, the command
# runs short, and the next line begins with a bare `&&`, which is a syntax
# error. That is easy to introduce when pasting into a terminal.
( cd apollo-settings && go build -o apollo-settings . && install -Dm755 apollo-settings ~/.local/bin/apollo-settings )

**Re-run this after every `git pull` that touched `apollo-settings/`.** The
binary is a build artifact, not a symlink like the rest of the repo, so it does
not update with a pull — and a stale one will not have subcommands that were
added since.

# Icons, resized from the bundled icon.png
mkdir -p ~/.local/share/icons/hicolor/{48x48,64x64,128x128,256x256}/apps
for sz in 48x48 64x64 128x128 256x256; do
  w="${sz%x*}"; ffmpeg -y -i apollo-settings/icon.png -vf "scale=$w:$w" \
    ~/.local/share/icons/hicolor/$sz/apps/apollo-settings.png -loglevel error
done

# .desktop entry (shows up in rofi)
mkdir -p ~/.local/share/applications
cp local/share/applications/apollo-settings.desktop ~/.local/share/applications/
update-desktop-database ~/.local/share/applications 2>/dev/null
gtk-update-icon-cache ~/.local/share/icons/hicolor 2>/dev/null

# Health check on PATH
# Symlink, not a copy: a copy goes stale the moment you `git pull`, and a
# doctor reporting checks that were fixed weeks ago is worse than none.
ln -sfn ~/RegolithDot/scripts/apollo-doctor ~/.local/bin/apollo-doctor

# First wallpaper, so hyprlock isn't staring at an empty cache
awww img ~/Pictures/Wallpapers/<your-wallpaper> -t none
echo ~/Pictures/Wallpapers/<your-wallpaper> > ~/.cache/wallpaper-current

# Neovim plugins
nvim --headless "+Lazy! sync" +qa

```

---

## 7. Verify

```bash
apollo-doctor ~/RegolithDot
systemctl reboot
```

`apollo-doctor` syntax-checks the Lua config if `lua` is installed — worth
running *before* you reboot, since a parse error takes the whole config down
and Hyprland falls back to a handful of emergency binds.

It also writes the palette files kitty, GTK and rofi read, copying each from
the committed `*.default.*` beside it. Those generated files are gitignored
machine state — `apollo-settings` rewrites them whenever you change a colour,
and `~/.config/kitty` and friends are symlinks into the repo, so tracking them
would put your palette in the way of every `git pull`. Run the doctor once
after cloning, or your terminal and file manager start unthemed.

**After reboot:**

| Component | Check |
|---|---|
| SDDM | Apollo's login screen, in your palette and on your wallpaper |
| Hyprland | Rotating gradient borders, frosted blur, workspaces sliding |
| Quickshell | Top bar: workspaces, stats, tray, clock |
| Keybinds | `SUPER+Space` launcher, `SUPER+,` settings, `SUPER+B` wallpaper, `SUPER+Q` kitty |
| Panels | Clock → calendar, gear → quick settings, power → power menu |
| Cheatsheet | `ALT+/` lists live binds (needs `jq`) |
| Hyprlock | Idle lock — wallpaper with frosted glass |
| Rofi | Catppuccin launcher, quicklinks (`>`), file search (`!`) |
| Thunar | Frosted, semi-transparent |
| Ranger | Miller columns, devicons, catppuccin |
| Neovim | Catppuccin transparent background |

If Hyprland won't start, the config is the first suspect:

```bash
luac -p ~/.config/hypr/hyprland.lua ~/.config/hypr/lua/*.lua
```
