pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string ssid: ssidOutput.trim()
    readonly property bool connected: ssid.length > 0 && ssid !== "--"

    readonly property string icon: connected ? "󰤨" : "󰤭"
    readonly property color color: connected ? "white" : "#f38ba8"

    property string ssidOutput: ""

    Process {
        id: poller
        command: ["nmcli", "-t", "-f", "active,ssid", "dev", "wifi"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.startsWith("yes:"))
                    root.ssidOutput = data.slice(4)
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: poller.running = true
    }
}
