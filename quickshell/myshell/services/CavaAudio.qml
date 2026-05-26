pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int barCount: 16
    property var bars: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    property bool fullscreen: false

    onFullscreenChanged: {
        if (fullscreen) {
            cavaProc.running = false
            root.bars = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
        } else if (!cavaProc.running) {
            cavaProc.running = true
        }
    }

    Process {
        id: configWriter
        command: ["bash", "-c", "printf '[general]\\nbars=16\\nframerate=25\\n[input]\\nmethod=pipewire\\n[output]\\nmethod=raw\\nraw_target=/dev/stdout\\ndata_format=ascii\\nascii_max_value=100\\n' > /tmp/qs-cava.conf"]
        running: true
        onExited: if (!root.fullscreen) cavaProc.running = true
    }

    Process {
        id: cavaProc
        command: ["cava", "-p", "/tmp/qs-cava.conf"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const vals = data.trim().split(";").filter(v => v.length > 0).map(v => parseInt(v) || 0)
                if (vals.length >= root.barCount)
                    root.bars = vals.slice(0, root.barCount)
            }
        }
        onExited: {
            root.bars = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
            if (!root.fullscreen) restartTimer.start()
        }
    }

    Process {
        id: fsChecker
        command: ["bash", "-c", "hyprctl activewindow -j 2>/dev/null | grep -o '\"fullscreen\":[0-9]*' | grep -v ':0' | wc -l"]
        stdout: SplitParser {
            onRead: data => root.fullscreen = parseInt(data.trim()) > 0
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: if (!cavaProc.running && !root.fullscreen) cavaProc.running = true
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: fsChecker.running = true
    }
}
