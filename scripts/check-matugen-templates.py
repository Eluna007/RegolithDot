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

    print(f"\n{len(blocks)} template(s), {failed} problem(s)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
