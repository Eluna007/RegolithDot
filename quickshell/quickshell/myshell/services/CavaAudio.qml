pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int barCount: 16
    property var bars: [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

    Process {
        id: configWriter
        command: ["bash", "-c", "printf '[general]\\nbars=16\\nframerate=25\\n[input]\\nmethod=pipewire\\n[output]\\nmethod=raw\\nraw_target=/dev/stdout\\ndata_format=ascii\\nascii_max_value=100\\n' > /tmp/qs-cava.conf"]
        running: true
        onExited: cavaProc.running = true
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
            restartTimer.start()
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: if (!cavaProc.running) cavaProc.running = true
    }
}
