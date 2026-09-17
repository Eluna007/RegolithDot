#!/usr/bin/env python3
"""Every relative link between the markdown files has to resolve.

The README was one 529-line file until its detail moved into docs/. That kind
of split is exactly where links rot: a path that was right at the top level is
wrong one directory down, and nothing complains until someone clicks it on
GitHub.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LINK = re.compile(r'\[[^\]]*\]\((?!https?:|mailto:)([^)#]*)(#[^)]*)?\)')

def main() -> int:
    files = sorted(ROOT.glob("*.md")) + sorted(ROOT.glob("docs/*.md"))
    if not files:
        print("FAIL  no markdown files found")
        return 1
    fails = 0
    checked = 0
    for f in files:
        for m in LINK.finditer(f.read_text()):
            target = m.group(1).strip()
            if target == "":
                continue          # a bare #anchor within the same file
            checked += 1
            if not (f.parent / target).resolve().exists():
                print(f"FAIL  {f.relative_to(ROOT)} -> {target} does not exist")
                fails += 1
    print(f"\n{len(files)} file(s), {checked} relative link(s), {fails} broken")
    return 1 if fails else 0

if __name__ == "__main__":
    sys.exit(main())
