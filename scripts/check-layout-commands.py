"""Every external command a lock screen layout runs must be declared here.

The layouts are vendored from a machine that is not this one, and they shell
out constantly. Twice now a command has turned out not to exist on a base Arch
install - `hostname` (it lives in inetutils) and a hardcoded BAT0 path - and
both times the only symptom was an error in hyprlock's log, on a locked screen,
where nobody is reading logs.

So: extract the commands at command position out of every cmd[...] block, and
fail on anything not in DECLARED below. Adding a command means adding it here,
which is the prompt to also add it to apollo-doctor and the README dependency
list.

The extraction is deliberately conservative. It looks only at command
positions - the start of a command string and whatever follows a pipe,
semicolon, &&, ||, or $( - so words that merely appear as arguments are not
mistaken for commands.
"""
import pathlib, re, sys

# Shell builtins, keywords and syntax: always available, nothing to install.
BUILTIN = {
    "if", "then", "else", "elif", "fi", "for", "in", "do", "done", "case",
    "esac", "while", "until", "function", "return", "exit", "echo", "printf",
    "test", "read", "set", "unset", "export", "local", "shift", "eval",
    "true", "false", "cd", "pwd", "break", "continue",
}

# Everything else the layouts invoke. Keep in step with apollo-doctor's
# check_cmd/check_optional_cmd calls and the README's dependency paragraph.
DECLARED = {
    # coreutils / util-linux / procps-ng - part of a base install
    "date": "coreutils",
    "cut": "coreutils",
    "head": "coreutils",
    "tr": "coreutils",
    "sed": "sed",
    "uname": "coreutils",
    "uptime": "procps-ng",
    # real dependencies - apollo-doctor checks each of these
    "playerctl": "playerctl (music widgets)",
}

# A command position: the start of the string, or just after one of these.
SPLIT = re.compile(r'(?:^|\||;|&&|\|\||\$\(|`|\bthen\b|\belse\b|\bdo\b)\s*')
WORD = re.compile(r'^([A-Za-z_][A-Za-z0-9_.-]*)')

bad, seen = [], set()
for f in sorted(pathlib.Path("config/hyprlock/layouts").glob("*.conf")):
    for i, line in enumerate(f.read_text().split("\n"), 1):
        if line.lstrip().startswith("#"):
            continue
        m = re.search(r'cmd\[[^\]]*\]\s*(.*)$', line)
        if not m:
            continue
        body = m.group(1)
        for seg in SPLIT.split(body):
            seg = seg.strip()
            if not seg:
                continue
            # skip variable expansions ($music, ${USER:0:1}) and assignments
            if seg.startswith("$") or re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', seg):
                continue
            w = WORD.match(seg)
            if not w:
                continue
            cmd = w.group(1)
            if cmd in BUILTIN:
                continue
            seen.add(cmd)
            if cmd not in DECLARED:
                bad.append(f"{f}:{i}: `{cmd}` is not declared in "
                           f"scripts/check-layout-commands.py")

# The reverse: a declaration nothing uses is a stale claim about what the
# layouts need, and it would silently re-permit a command someone removed on
# purpose. iw and bluetoothctl were both declared here until their widgets
# moved into network.sh.
for cmd in sorted(set(DECLARED) - seen):
    bad.append(f"scripts/check-layout-commands.py: `{cmd}` is declared but no "
               f"layout uses it; remove it")

if bad:
    print("\n".join(sorted(set(bad))))
    print("\nIf it is a real dependency, declare it here and add it to "
          "apollo-doctor and the README.")
    sys.exit(1)

print(f"ok - {len(seen)} commands across 4 layouts, all declared: "
      f"{', '.join(sorted(seen))}")
