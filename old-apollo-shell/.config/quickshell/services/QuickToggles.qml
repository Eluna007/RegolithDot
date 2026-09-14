pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    // Caffeine and Night Light are driven for real from shell.qml (one
    // needs a window reference for IdleInhibitor, the other owns the
    // hyprsunset process) — this singleton just holds the shared on/off
    // state so any popup can read/flip it without owning the process itself.
    property bool caffeine: false
    property bool nightLight: false
    property bool dnd: false
    property bool airplane: false
    property bool wifiRadioOn: true

    function toggleCaffeine() { caffeine = !caffeine }
    function toggleNightLight() { nightLight = !nightLight }

    // Notifications.qml checks this directly to decide whether to show a
    // toast, so DND no longer needs to shell out to swaync-client.
    function toggleDnd() { dnd = !dnd }

    function toggleAirplane() {
        airplane = !airplane
        airplaneProc.command = ["rfkill", airplane ? "block" : "unblock", "all"]
        airplaneProc.running = true
        // rfkill block all also kills wifi/bt radios; reflect that locally
        // rather than waiting on a poll.
        if (airplane) { wifiRadioOn = false }
    }

    function toggleWifiRadio() {
        if (airplane) return  // airplane mode already has it off
        wifiRadioOn = !wifiRadioOn
        wifiProc.command = ["nmcli", "radio", "wifi", wifiRadioOn ? "on" : "off"]
        wifiProc.running = true
    }

    function refreshAirplane() { airProbe.running = true }
    function refreshWifiRadio() { wifiProbe.running = true }

    property Process dndProc: Process {}
    property Process airplaneProc: Process {}
    property Process wifiProc: Process {}

    // Airplane state derived from real rfkill status rather than trusted
    // purely from our own toggle, so it can't drift from reality (matches
    // Moonlit's approach exactly, for the same reason).
    property Process airProbe: Process {
        command: ["sh", "-c", "rfkill list 2>/dev/null | grep -q 'Soft blocked: no' && echo 0 || echo 1"]
        stdout: SplitParser { onRead: d => root.airplane = d.trim() === "1" }
    }
    property Process wifiProbe: Process {
        command: ["sh", "-c", "nmcli radio wifi"]
        stdout: SplitParser { onRead: d => root.wifiRadioOn = d.trim() === "enabled" }
    }

    Component.onCompleted: { refreshAirplane(); refreshWifiRadio() }
}
