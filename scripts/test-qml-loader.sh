#!/usr/bin/env bash
# Pins the Loader behaviour WallpaperPanel.qml depends on. See the long comment
# at the top of scripts/qml-tests/tst_loader_required.qml for why.
#
# Needs Qt 6's qmltestrunner plus the QtQuick and QtTest QML modules. Skips
# rather than fails when they are absent: this checks a property of Qt, not of
# this repo, so a machine without Qt's test tooling has nothing to say about it.
#
# Run: scripts/test-qml-loader.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

runner=""
for c in qmltestrunner qmltestrunner6 /usr/lib/qt6/bin/qmltestrunner; do
    if command -v "$c" >/dev/null 2>&1; then runner="$c"; break; fi
done

if [ -z "$runner" ]; then
    echo "skipped - qmltestrunner not installed (Qt 6 declarative tools)"
    exit 0
fi

# Offscreen: there is no display in CI, and this tests object construction
# rather than anything drawn.
#
# "Required property dep was not initialized" is filtered out because it is the
# expected output of the very case being tested, and printing it above a row of
# PASS lines reads like something went wrong.
out="$(QT_QPA_PLATFORM=offscreen "$runner" \
        -input "$ROOT/scripts/qml-tests/tst_loader_required.qml" 2>&1)"
rc=$?

echo "$out" | grep -vE "XDG_RUNTIME_DIR|Required property dep was not initialized"

if [ $rc -ne 0 ]; then
    echo "FAIL - the Loader contract WallpaperPanel.qml relies on does not hold"
    exit 1
fi
echo "ok - Loader required-property contract"
