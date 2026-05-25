pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real cpuPercent: 0
    property real ramUsed: 0
    property real ramTotal: 0
    property real diskUsed: 0
    property real diskTotal: 0
    property real cpuTemp: 0
    property real nvmeTemp: 0

    readonly property int ramPercent: ramTotal > 0 ? Math.round((ramUsed / ramTotal) * 100) : 0
    readonly property int diskPercent: diskTotal > 0 ? Math.round((diskUsed / diskTotal) * 100) : 0

    readonly property string ramStr: Math.round(ramUsed) + " / " + Math.round(ramTotal) + " GB"
    readonly property string diskStr: Math.round(diskUsed) + " / " + Math.round(diskTotal) + " GB"

    Process {
        id: cpuPoller
        command: ["bash", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print $2}'"]
        running: true
        stdout: SplitParser { onRead: data => root.cpuPercent = parseFloat(data) || 0 }
    }

    Process {
        id: ramPoller
        command: ["bash", "-c", "free -g | awk '/Mem:/ {print $3, $2}'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(" ")
                root.ramUsed  = parseFloat(parts[0]) || 0
                root.ramTotal = parseFloat(parts[1]) || 0
            }
        }
    }

    Process {
        id: diskPoller
        command: ["bash", "-c", "df -BG / | awk 'NR==2 {gsub(/G/,\"\",$3); gsub(/G/,\"\",$2); print $3, $2}'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(" ")
                root.diskUsed  = parseFloat(parts[0]) || 0
                root.diskTotal = parseFloat(parts[1]) || 0
            }
        }
    }

    Process {
        id: cpuTempPoller
        command: ["bash", "-c", "sensors | grep 'Package id 0' | awk '{print $4}' | tr -d '+°C'"]
        running: true
        stdout: SplitParser { onRead: data => root.cpuTemp = parseFloat(data) || 0 }
    }

    Process {
        id: nvmeTempPoller
        command: ["bash", "-c", "sensors | grep 'Composite' | head -1 | awk '{print $2}' | tr -d '+°C'"]
        running: true
        stdout: SplitParser { onRead: data => root.nvmeTemp = parseFloat(data) || 0 }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            cpuPoller.running = true
            ramPoller.running = true
            diskPoller.running = true
            cpuTempPoller.running = true
            nvmeTempPoller.running = true
        }
    }
}
