#!/usr/bin/env bash
# Enumerate desktop applications for the launcher, one per line:
#
#   name <TAB> exec <TAB> icon-path <TAB> comment
#
# icon-path is an absolute file or empty when nothing was found - the launcher
# draws a lettered tile in that case rather than a broken-image box.
#
# Parsing .desktop files rather than shelling out to a menu library keeps the
# launcher self-contained and, more to the point, testable: scripts/test-apps.sh
# points APPLICATION_DIRS at a fixture tree and checks the awkward cases.
set -uo pipefail

# Standard search order, later entries losing to earlier ones on a name clash
# the way the XDG spec says they should.
default_dirs() {
    local dirs="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    local d
    local IFS=:
    for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
        dirs="$dirs:$d/applications"
    done
    dirs="$dirs:/var/lib/flatpak/exports/share/applications"
    dirs="$dirs:${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/exports/share/applications"
    printf '%s' "$dirs"
}

APP_DIRS="${APPLICATION_DIRS:-$(default_dirs)}"

# `apps.sh --debug` says where it looked and what it found there. An empty
# launcher is silence otherwise, and the three reasons for it - no readable
# directories, no .desktop files, everything filtered out - look identical from
# the outside.
if [ "${1-}" = "--debug" ]; then
    echo "XDG_DATA_HOME = ${XDG_DATA_HOME:-<unset, using $HOME/.local/share>}"
    echo "XDG_DATA_DIRS = ${XDG_DATA_DIRS:-<unset, using /usr/local/share:/usr/share>}"
    echo
    echo "directories searched:"
    total=0
    while IFS= read -r d; do
        if [ ! -d "$d" ]; then
            printf '  %-55s (no such directory)\n' "$d"
        elif [ ! -r "$d" ]; then
            printf '  %-55s NOT READABLE\n' "$d"
        else
            n=$(find "$d" -maxdepth 1 -name '*.desktop' 2>/dev/null | wc -l)
            printf '  %-55s %s .desktop file(s)\n' "$d" "$n"
            total=$((total + n))
        fi
    done <<< "$(printf '%s' "$APP_DIRS" | tr ':' '\n')"
    echo
    echo "$total .desktop file(s) in total"
    echo "$("$0" | wc -l) entr(ies) after filtering (NoDisplay, Hidden, TryExec, duplicates)"
    exit 0
fi
ICON_DIRS="${APOLLO_ICON_DIRS:-${XDG_DATA_HOME:-$HOME/.local/share}/icons:$HOME/.icons:/usr/share/icons:/usr/share/pixmaps}"
# Theme is not consulted: the index ranks every icon by size across all of
# them, which finds an icon a theme-first search would miss entirely.

# Icon index: one find over the icon directories, reduced to the best file for
# each icon name. Resolving icons one at a time meant a stat storm per launch -
# a hundred and fifty apps against a hundred candidate paths each.
#
# Ranking prefers larger raster sizes (a 128 scaled down beats a 32 scaled up)
# and treats scalable as near-best.
icon_index() {
    local dir
    local dirs=()
    local IFS=:
    for dir in $ICON_DIRS; do
        [ -d "$dir" ] && dirs+=("$dir")
    done
    unset IFS
    [ ${#dirs[@]} -gt 0 ] || return 0

    # find takes its paths before the expression, so they are passed directly
    # rather than appended by xargs - which put them after -print and made
    # every invocation an error that 2>/dev/null then swallowed.
    find "${dirs[@]}" -type f \
        \( -name '*.png' -o -name '*.svg' -o -name '*.xpm' \) -print 2>/dev/null |
    awk -F/ '
    {
        path = $0
        file = $NF
        sub(/\.(png|svg|xpm)$/, "", file)

        rank = 1                                  # flat dirs like pixmaps
        if (path ~ /\/scalable\//) rank = 400
        else if (match(path, /\/[0-9]+x[0-9]+\//)) {
            size = substr(path, RSTART + 1, RLENGTH - 2)
            sub(/x.*/, "", size)
            rank = size + 0
        }
        if (rank > best[file]) { best[file] = rank; where[file] = path }
    }
    END { for (f in where) printf "%s\t%s\n", f, where[f] }'
}

# One awk pass over every .desktop file, rather than a handful of seds per
# file. This is the difference between the launcher opening instantly and
# taking three seconds on a normal machine.
parse_entries() {
    local dir f
    local files=()
    local IFS=:
    for dir in $APP_DIRS; do
        [ -d "$dir" ] || continue
        unset IFS
        for f in "$dir"/*.desktop; do
            [ -f "$f" ] && files+=("$f")
        done
        IFS=:
    done
    unset IFS
    [ ${#files[@]} -gt 0 ] || return 0

    # The files are awk's arguments, not its stdin. Piping the list in made awk
    # read the list of names as its input and never open a .desktop file at all.
    awk -v SEP="$SEP" '
    function flush() {
        # A duplicate basename in a later directory loses to the first, as the
        # XDG spec requires.
        if (base != "" && !(base in seen) &&
            type == "Application" && nodisplay != "true" && hidden != "true" &&
            name != "" && exec != "") {
            seen[base] = 1
            # Field codes are for callers passing files; launched bare they
            # would land on the command line as a literal %U.
            gsub(/%[fFuUdDnNickvm]/, "", exec)
            gsub(/^[ \t]+|[ \t]+$/, "", exec)
            gsub(/  +/, " ", exec)
            if (exec != "") {
                gsub(/\t/, " ", name); gsub(/\t/, " ", comment)
                # SEP, not a tab: tab is an IFS *whitespace* character, so
                # `read` collapses runs of them and drops empty fields - an
                # entry with no icon and no comment silently shifted TryExec
                # into the wrong variable.
                printf "%s%s%s%s%s%s%s%s%s\n",
                       name, SEP, exec, SEP, icon, SEP, substr(comment, 1, 120), SEP, tryexec
            }
        }
        type = name = exec = icon = comment = nodisplay = hidden = tryexec = ""
    }
    FNR == 1 {
        flush()
        base = FILENAME
        sub(/.*\//, "", base)
        in_entry = 0
    }
    /^\[/ {
        # Only [Desktop Entry]; a [Desktop Action] group has its own Name and
        # Exec and would otherwise overwrite the real ones.
        in_entry = ($0 ~ /^\[Desktop Entry\][ \t]*$/)
        next
    }
    !in_entry { next }
    {
        eq = index($0, "=")
        if (eq == 0) next
        key = substr($0, 1, eq - 1)
        val = substr($0, eq + 1)
        gsub(/[ \t]+$/, "", val)          # trailing space is common in the wild
        gsub(/[ \t]+$/, "", key)
        if (key == "Type" && type == "") type = val
        else if (key == "Name" && name == "") name = val
        else if (key == "Exec" && exec == "") exec = val
        else if (key == "Icon" && icon == "") icon = val
        else if (key == "Comment" && comment == "") comment = val
        else if (key == "NoDisplay" && nodisplay == "") nodisplay = val
        else if (key == "Hidden" && hidden == "") hidden = val
        else if (key == "TryExec" && tryexec == "") tryexec = val
    }
    END { flush() }' "${files[@]}"
}

# TryExec names the binary that must exist; an entry for an uninstalled app is
# a launcher row that does nothing when clicked.
have_tryexec() {
    case "$1" in
        "") return 0 ;;
        /*) [ -x "$1" ] && return 0 || return 1 ;;
        *)  command -v "$1" >/dev/null 2>&1 ;;
    esac
}

# ASCII unit separator: cannot appear in a .desktop value and, unlike tab, is
# not IFS whitespace, so empty fields survive `read`.
SEP="$(printf '\037')"

index_file="$(mktemp)"
trap 'rm -f "$index_file"' EXIT
icon_index > "$index_file"

# Join the icon index onto the entries in one awk rather than spawning one per
# app - two hundred apps meant two hundred processes, which was most of the
# runtime. TryExec is left for the shell loop below, since only a shell can
# answer "is this binary on PATH", and it is a builtin so the loop is cheap.
parse_entries | awk -F"$SEP" -v OFS="$SEP" -v idx="$index_file" '
BEGIN {
    while ((getline line < idx) > 0) {
        tab = index(line, "\t")
        if (tab > 0) icon[substr(line, 1, tab - 1)] = substr(line, tab + 1)
    }
}
{
    path = ""
    if ($3 != "") {
        if (substr($3, 1, 1) == "/") path = $3      # absolute, taken as given
        else if ($3 in icon) path = icon[$3]
    }
    print $1, $2, path, $4, $5
}' | while IFS="$SEP" read -r name exec icon comment tryexec; do
    have_tryexec "$tryexec" || continue
    # An absolute icon path that does not exist is worse than none: the
    # launcher would draw a broken image instead of a lettered tile.
    case "$icon" in
        /*) [ -f "$icon" ] || icon="" ;;
    esac
    printf '%s\t%s\t%s\t%s\n' "$name" "$exec" "$icon" "$comment"
done | sort -f
