#!/usr/bin/env bash
# Clipboard history for the bar panel, via copyq.
#
# The panel used to run `cliphist list`. autostart.lua runs copyq and says in
# its own comment that cliphist is deliberately absent - so the panel queried a
# tool that was not running and showed an empty list forever, next to a copyq
# that was catching everything. Two clipboards, one of them a ghost.
#
#   clipboard.sh --list        a status line, then rows as "index<TAB>preview"
#   clipboard.sh --use N       put row N on the clipboard
#   clipboard.sh --clear       empty the history
#   clipboard.sh --doctor      why the history is empty, in prose
#
# --list always prints exactly one status line first, "!<TAB>ok|missing|
# noserver". Without it, "copyq is not installed", "copyq is installed but its
# server is not answering" and "you have not copied anything yet" all reach the
# panel as zero rows, and it says "Clipboard is empty" to all three. That is
# the same lie the wifi widget told when `iw` was missing.
#
# `copyq read` and `copyq eval` are the two verbs used here; both are core and
# have been stable across copyq versions, unlike `select`.
set -uo pipefail

COPYQ="${APOLLO_COPYQ:-copyq}"
LIMIT="${APOLLO_CLIP_LIMIT:-20}"

# Validate the mode before checking for copyq. The other way round, a typo'd
# mode exits 0 on any machine without copyq installed - a usage error that
# reports success is a bug waiting to hide a caller's mistake.
case "${1-}" in
    --list|--use|--clear|--doctor) ;;
    *)
        echo "usage: clipboard.sh --list | --use N | --clear" >&2
        exit 1
        ;;
esac

# No copyq. Not an error to the caller, but the panel has to be able to say so
# rather than claiming the history is empty.
if ! command -v "$COPYQ" >/dev/null 2>&1; then
    case "${1-}" in
        --list)   printf '!\tmissing\n' ;;
        --doctor) echo "copyq is not installed. Install it: sudo pacman -S copyq" ;;
    esac
    exit 0
fi

case "${1-}" in
--list)
    # One line per row: tabs and newlines inside an item would otherwise break
    # the parser, so they collapse to spaces before printing.
    #
    # stderr is captured rather than discarded, and the exit status is checked.
    # A copyq whose server will not start fails here, and the panel needs to
    # hear about that instead of being handed an empty list.
    if ! out=$("$COPYQ" eval -- "
        var n = Math.min($LIMIT, size());
        for (var i = 0; i < n; ++i) {
            var s = str(read(i)).replace(/[\r\n\t]+/g, ' ').trim();
            if (s.length > 160) s = s.substr(0, 160);
            if (s.length > 0) print(i + '\t' + s + '\n');
        }
    " 2>/dev/null); then
        printf '!\tnoserver\n'
        exit 0
    fi
    printf '!\tok\n'
    # An `[ -n ... ] && printf` here would leave the script exiting 1 on an
    # empty history, which is the most ordinary case there is.
    if [ -n "$out" ]; then
        printf '%s\n' "$out"
    fi
    ;;
--doctor)
    # For a human to run when the panel says the history is empty and it is
    # not. Every line is a fact, not a guess.
    echo "copyq binary:  $(command -v "$COPYQ")"
    if pgrep -x copyq >/dev/null 2>&1; then
        echo "copyq process: running (pid $(pgrep -x copyq | tr '\n' ' '))"
    else
        echo "copyq process: NOT running - autostart.lua starts it at login;"
        echo "               start it now with: copyq &"
    fi
    if n=$("$COPYQ" eval -- 'print(size())' 2>&1); then
        echo "server:        answering, $n item(s) stored"
    else
        echo "server:        NOT answering - copyq said: $n"
    fi
    echo
    echo "copyq only records a copy while it is running. If the count above"
    echo "stays at 0 after you copy something, monitoring is off:"
    echo "  copyq config check_clipboard true"
    echo "  copyq config check_selection false"
    ;;
--use)
    row="${2-}"
    # Only a plain row number is ever passed through; anything else is a bug or
    # worse, and copyq would happily evaluate it.
    case "$row" in
        ''|*[!0-9]*) echo "clipboard.sh: row must be a number" >&2; exit 1 ;;
    esac
    "$COPYQ" read "$row" 2>/dev/null | wl-copy
    ;;
--clear)
    "$COPYQ" eval -- 'var n = size(); for (var i = n - 1; i >= 0; --i) remove(i);' >/dev/null 2>&1
    ;;
esac
