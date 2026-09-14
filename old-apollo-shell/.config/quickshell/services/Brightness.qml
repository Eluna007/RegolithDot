pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property real level: 0.5   // 0.0-1.0

    function setBrightness(v) {
        var pct = Math.round(Math.max(0, Math.min(1, v)) * 100)
        root.level = pct / 100
        setProc.command = ["brightnessctl", "s", pct + "%"]
        setProc.running = true
    }

    property Process setProc: Process {}

    property Process initProc: Process {
        command: ["sh", "-c", "echo $(brightnessctl g) $(brightnessctl m)"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(" ")
                var cur = parseInt(p[0]), max = parseInt(p[1])
                if (max > 0) root.level = cur / max
            }
        }
    }
    Component.onCompleted: initProc.running = true
}
