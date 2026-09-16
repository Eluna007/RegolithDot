#!/usr/bin/env bash
# Clipboard history for the bar panel, via copyq.
#
# The panel used to run `cliphist list`. autostart.lua runs copyq and says in
# its own comment that cliphist is deliberately absent - so the panel queried a
# tool that was not running and showed an empty list forever, next to a copyq
# that was catching everything. Two clipboards, one of them a ghost.
#
#   clipboard.sh --list        rows as "index<TAB>one-line preview"
#   clipboard.sh --use N       put row N on the clipboard
#   clipboard.sh --clear       empty the history
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
    --list|--use|--clear) ;;
    *)
        echo "usage: clipboard.sh --list | --use N | --clear" >&2
        exit 1
        ;;
esac

# No copyq: nothing to report, and that is not an error. The panel renders an
# empty history, which is the truth.
command -v "$COPYQ" >/dev/null 2>&1 || exit 0

case "${1-}" in
--list)
    # One line per row: tabs and newlines inside an item would otherwise break
    # the parser, so they collapse to spaces before printing.
    "$COPYQ" eval -- "
        var n = Math.min($LIMIT, size());
        for (var i = 0; i < n; ++i) {
            var s = str(read(i)).replace(/[\r\n\t]+/g, ' ').trim();
            if (s.length > 160) s = s.substr(0, 160);
            if (s.length > 0) print(i + '\t' + s + '\n');
        }
    " 2>/dev/null
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
