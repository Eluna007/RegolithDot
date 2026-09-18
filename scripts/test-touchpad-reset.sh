#!/usr/bin/env bash
# apollo-touchpad-reset finds the touchpad and its driver by walking the same
# files the kernel exposes, so both can be faked and the whole thing driven
# without a touchpad.
#
# The parts worth pinning are the ones that would be wrong silently: picking
# the touchpad rather than the touchscreen sitting next to it on the same
# controller, and finding the driver several levels above the input node
# rather than on it.
#
# Run: scripts/test-touchpad-reset.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/local/bin/apollo-touchpad-reset"
fails=0

ok()   { echo "  ok   $1"; }
fail() { echo "  FAIL $1${2:+: $2}"; fails=$((fails + 1)); }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
bin="$work/bin"; mkdir -p "$bin"

# This laptop's real arrangement: an ELAN touchscreen and an ELAN touchpad on
# separate i2c controllers, with three nodes for the touchscreen. Picking the
# wrong one reloads the wrong driver and leaves the touchpad exactly as dead.
cat > "$work/devices" <<'DEVS'
I: Bus=0018 Vendor=04f3 Product=2a8a Version=0100
N: Name="ELAN901C:00 04F3:2A8A"
P: Phys=i2c-ELAN901C:00
S: Sysfs=/devices/pci0000:00/0000:00:15.0/i2c_designware.0/i2c-0/i2c-ELAN901C:00/0018:04F3:2A8A.0001/input/input14
H: Handlers=event8 mouse1

I: Bus=0018 Vendor=04f3 Product=2a8a Version=0100
N: Name="ELAN901C:00 04F3:2A8A UNKNOWN"
P: Phys=i2c-ELAN901C:00
S: Sysfs=/devices/pci0000:00/0000:00:15.0/i2c_designware.0/i2c-0/i2c-ELAN901C:00/0018:04F3:2A8A.0001/input/input15
H: Handlers=event9

I: Bus=0018 Vendor=04f3 Product=0007 Version=0000
N: Name="Elan Touchpad"
P: Phys=
S: Sysfs=/devices/pci0000:00/0000:00:15.1/i2c_designware.1/i2c-1/i2c-ELAN0000:00/input/input23
H: Handlers=event11 mouse0
DEVS

# A sysfs where the driver is bound to the i2c device, four levels above the
# input node — which is where it really is, and why this walks up.
sysfs="$work/sys"
tp="$sysfs/devices/pci0000:00/0000:00:15.1/i2c_designware.1/i2c-1/i2c-ELAN0000:00"
mkdir -p "$tp/input/input23" "$sysfs/bus/i2c/drivers/elan_i2c"
ln -s "$sysfs/bus/i2c/drivers/elan_i2c" "$tp/driver"

# The touchscreen's driver, so picking the wrong device is a visible mistake
# rather than an identical answer.
ts="$sysfs/devices/pci0000:00/0000:00:15.0/i2c_designware.0/i2c-0/i2c-ELAN901C:00"
mkdir -p "$ts/0018:04F3:2A8A.0001/input/input14" "$sysfs/bus/i2c/drivers/i2c_hid_acpi"
ln -s "$sysfs/bus/i2c/drivers/i2c_hid_acpi" "$ts/driver"

cat > "$bin/modprobe" <<'STUB'
#!/bin/sh
echo "modprobe $*" >> "$MODPROBE_LOG"
exit 0
STUB
chmod +x "$bin/modprobe"
export MODPROBE_LOG="$work/modprobe.log"
: > "$MODPROBE_LOG"

run() {
    PATH="$bin:$PATH" APOLLO_INPUT_DEVICES="$work/devices" APOLLO_SYSFS="$sysfs" \
        "$SCRIPT" "$@" 2>&1
}

# ── What it would do ─────────────────────────────────────────────────────
out="$(run --what)"
if echo "$out" | grep -q "Elan Touchpad"; then
    ok "picks the touchpad, not the touchscreen beside it"
else
    fail "identified the wrong device" "$out"
fi
if echo "$out" | grep -q "driver   : elan_i2c"; then
    ok "finds the driver four levels above the input node"
else
    fail "did not find the driver" "$out"
fi
if echo "$out" | grep -q "i2c_hid_acpi"; then
    fail "found the touchscreen's driver" "$out"
else
    ok "does not confuse it with the touchscreen's driver"
fi

# --what must not need root, or you cannot ask what it would do first.
if [ "$(id -u)" -ne 0 ]; then
    if run --what >/dev/null 2>&1; then ok "--what works without root"; else fail "--what demanded root"; fi
fi

# ── Actually reloading ───────────────────────────────────────────────────
if [ "$(id -u)" -eq 0 ]; then
    : > "$MODPROBE_LOG"
    out="$(run)"
    if grep -q "modprobe -r elan_i2c" "$MODPROBE_LOG" && grep -q "^modprobe elan_i2c" "$MODPROBE_LOG"; then
        ok "unloads and reloads the driver"
    else
        fail "did not reload the driver" "$(cat "$MODPROBE_LOG")"
    fi
    # Order matters: loading before unloading does nothing at all.
    if [ "$(grep -n 'modprobe -r' "$MODPROBE_LOG" | cut -d: -f1)" -lt \
         "$(grep -n '^modprobe elan_i2c' "$MODPROBE_LOG" | cut -d: -f1)" ]; then
        ok "unloads before loading"
    else
        fail "reloaded in the wrong order" "$(cat "$MODPROBE_LOG")"
    fi
else
    out="$(run)"
    if echo "$out" | grep -q "needs root"; then
        ok "says it needs root rather than failing obscurely"
    else
        fail "did not ask for root" "$out"
    fi
fi

# ── A machine with no touchpad ───────────────────────────────────────────
printf 'I: Bus=0003\nN: Name="Some Keyboard"\nS: Sysfs=/devices/x/input/input1\n' > "$work/nopad"
out="$(PATH="$bin:$PATH" APOLLO_INPUT_DEVICES="$work/nopad" APOLLO_SYSFS="$sysfs" "$SCRIPT" --what 2>&1)"
rc=$?
if [ $rc -ne 0 ] && echo "$out" | grep -q "no touchpad found"; then
    ok "says so on a machine with no touchpad"
else
    fail "a missing touchpad was not reported" "$out"
fi

# ── A touchpad whose driver is built in ──────────────────────────────────
rm "$tp/driver"
out="$(run --what 2>&1)"; rc=$?
if [ $rc -ne 0 ] && echo "$out" | grep -q "nothing on that path has a driver"; then
    ok "says so when no driver is bound"
else
    fail "an unbound driver was not reported" "$out"
fi
ln -s "$sysfs/bus/i2c/drivers/elan_i2c" "$tp/driver"

if [ $fails -gt 0 ]; then echo; echo "$fails failure(s)"; exit 1; fi
echo; echo "ok - apollo-touchpad-reset"
