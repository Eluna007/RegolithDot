pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int percent: 0
    property string status: "Unknown"

    readonly property bool charging: status === "Charging" || status === "Full"

    readonly property string icon: {
        if (charging) return "󰂄"
        if (percent >= 90) return "󰁹"
        if (percent >= 70) return "󰂁"
        if (percent >= 50) return "󰁾"
        if (percent >= 30) return "󰁼"
        if (percent >= 10) return "󰁺"
        return "󰂃"
    }

    readonly property color color: {
        if (charging)      return "#a6e3a1"
        if (percent > 20)  return "white"
        return "#f38ba8"
    }

    Process {
        id: capacityPoller
        command: ["cat", "/sys/class/power_supply/BAT1/capacity"]
        running: true
        stdout: SplitParser {
            onRead: data => root.percent = parseInt(data.trim()) || 0
        }
    }

    Process {
        id: statusPoller
        command: ["cat", "/sys/class/power_supply/BAT1/status"]
        running: true
        stdout: SplitParser {
            onRead: data => root.status = data.trim()
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            capacityPoller.running = true
            statusPoller.running = true
        }
    }
}
