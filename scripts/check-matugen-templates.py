#!/usr/bin/env python3
"""Every template matugen is told to render must exist in the repo.

MANUAL-INSTALL.md symlinks the whole `config/matugen` directory to
`~/.config/matugen`, so an `input_path` under `~/.config/matugen/templates/`
resolves straight back into this tree. A block naming a file that was never
committed is not a quiet no-op: matugen errors on it on every wallpaper change.

That is exactly what happened to `[templates.quickshell]`, which pointed at a
`colors.json.template` with no commit anywhere in the history.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "config" / "matugen" / "config.toml"
PREFIX = "~/.config/matugen/"

# Deliberately not tomllib: this has to run on the Python in CI without
# depending on a 3.11+ standard library, and the file is a flat key = "value".
FIELD = re.compile(r'^\s*(input_path|output_path)\s*=\s*"([^"]*)"', re.M)
BLOCK = re.compile(r'^\s*\[templates\.([^\]]+)\]', re.M)


def main() -> int:
    if not CONFIG.is_file():
        print(f"FAIL  {CONFIG} is missing")
        return 1

    text = CONFIG.read_text()
    blocks = BLOCK.findall(text)
    inputs = [(k, v) for k, v in FIELD.findall(text) if k == "input_path"]

    if len(inputs) != len(blocks):
        print(f"FAIL  {len(blocks)} [templates.*] blocks but {len(inputs)} input_path lines")
        return 1
    if not blocks:
        print("FAIL  config.toml declares no templates at all")
        return 1

    failed = 0
    for name, (_, raw) in zip(blocks, inputs):
        if not raw.startswith(PREFIX):
            print(f"FAIL  [templates.{name}] input_path {raw!r} is outside {PREFIX}")
            failed += 1
            continue
        path = ROOT / "config" / "matugen" / raw[len(PREFIX):]
        if path.is_file():
            print(f"ok    [templates.{name}] -> {path.relative_to(ROOT)}")
        else:
            print(f"FAIL  [templates.{name}] -> {path.relative_to(ROOT)} does not exist")
            failed += 1

    # A template on disk that no block renders is dead weight, and the reverse
    # of the bug above: it looks wired up from the file tree alone.
    declared = {raw[len(PREFIX):] for _, raw in inputs if raw.startswith(PREFIX)}
    for path in sorted((ROOT / "config" / "matugen" / "templates").glob("*")):
        rel = f"templates/{path.name}"
        if path.is_file() and rel not in declared:
            print(f"FAIL  {path.relative_to(ROOT)} is rendered by no [templates.*] block")
            failed += 1

    failed += check_invocations()

    print(f"\n{len(blocks)} template(s), {failed} problem(s)")
    return 1 if failed else 0



def check_invocations() -> int:
    """matugen is now run from two places; they must ask for the same colour.

    wallpaper-switch.sh runs it on every wallpaper change. apollo-settings runs
    it too, when dynamic colours are switched on and nothing is staged yet
    (dynamic.go, ensureStagedSource). A different --source-color-index in one of
    them would mean the lock screen and the shell were built from different
    colours out of the same wallpaper, which is the one thing having a single
    extractor was supposed to rule out.
    """
    callers = {
        "local/bin/wallpaper-switch.sh":
            r'matugen image "\$still" --source-color-index (\d+)',
        "apollo-settings/dynamic.go":
            r'"matugen", "image", still, "--source-color-index", "(\d+)"',
    }
    failed = 0
    seen = {}
    for rel, pattern in callers.items():
        m = re.search(pattern, (ROOT / rel).read_text())
        if not m:
            print(f"FAIL  {rel} does not run matugen the expected way")
            failed += 1
            continue
        seen[rel] = m.group(1)

    if len(set(seen.values())) > 1:
        print("FAIL  the two matugen calls disagree: " +
              ", ".join(f"{k} uses {v}" for k, v in seen.items()))
        failed += 1
    elif seen and not failed:
        print(f"ok    both matugen callers use --source-color-index "
              f"{next(iter(seen.values()))}")
    return failed


if __name__ == "__main__":
    sys.exit(main())
