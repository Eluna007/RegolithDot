import QtQuick
import Quickshell.Io
import "../components" as Components
import "../services" as Services

Components.AnchoredPopup {
    id: popup
    contentWidth: 320

    property int diskPct: 0
    property real netRx: 0
    property real netTx: 0
    property var prevNet: []
    property var processes: []
    property var processBuffer: []

    onVisibleChanged: {
        Services.SystemStats.fastPoll = visible
        if (visible) {
            processBuffer = []
            diskProc.running = true
            netProc.running = true
            procProc.running = true
        }
    }

    Item {
        Timer {
            interval: 2000
            running: popup.visible
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                diskProc.running = true
                netProc.running = true
                popup.processBuffer = []
                procProc.running = true
            }
        }

        Process {
            id: diskProc
            command: ["sh", "-c", "df / | awk 'NR==2{gsub(/%/,\"\",$5); print $5}'"]
            stdout: SplitParser { onRead: d => popup.diskPct = parseInt(d) || 0 }
        }

        // Same interface-detection approach as everywhere else tonight:
        // whatever carries the default route, falling back to the first
        // wireless device, so this isn't hardcoded to one machine.
        Process {
            id: netProc
            command: ["sh", "-c", "IF=$(ip route show default 2>/dev/null | awk '{print $5; exit}'); [ -z \"$IF\" ] && IF=$(ls /sys/class/net 2>/dev/null | grep -E '^wl' | head -1); [ -n \"$IF\" ] && awk -v p=\"$IF:\" '$1==p{print $2, $10}' /proc/net/dev"]
            stdout: SplitParser {
                onRead: data => {
                    var p = data.trim().split(" ").map(Number)
                    if (popup.prevNet.length === 2) {
                        popup.netRx = Math.max(0, (p[0] - popup.prevNet[0]) / 1024 / 5)
                        popup.netTx = Math.max(0, (p[1] - popup.prevNet[1]) / 1024 / 5)
                    }
                    popup.prevNet = p
                }
            }
        }

        Process {
            id: procProc
            command: ["sh", "-c", "NCPU=$(nproc); ps aux --sort=-%cpu | awk -v nc=$NCPU 'NR>1 && NR<=6{cpu=$3/nc; if(cpu>100)cpu=100; printf \"%s %.1f %.1f\\n\", $11, cpu, $4}'"]
            stdout: SplitParser {
                onRead: data => {
                    if (data.trim() === "") return
                    var p = data.trim().split(" ")
                    if (p.length >= 3) {
                        var name = p[0].split("/").pop()
                        popup.processBuffer.push({ name: name.substring(0, 18), cpu: parseFloat(p[1]).toFixed(1), mem: parseFloat(p[2]).toFixed(1) })
                    }
                }
            }
            onRunningChanged: {
                if (!running && popup.processBuffer.length > 0) {
                    popup.processes = popup.processBuffer
                    popup.processBuffer = []
                }
            }
        }
    }

    Text {
        text: "System Monitor"
        color: Services.Theme.foreground
        opacity: 0.7
        font.pixelSize: Services.Theme.fontSizeSmall
        font.family: Services.Theme.fontFamily
    }

    // ---- CPU card with sparkline ----
    Rectangle {
        width: parent.width
        height: 100
        radius: 14
        color: Services.Theme.pillColor

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            Row {
                width: parent.width
                Text {
                    text: "CPU"
                    color: Services.Theme.foreground
                    opacity: 0.7
                    font.pixelSize: Services.Theme.fontSizeSmall - 1
                    font.family: Services.Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item { width: parent.width - 130; height: 1 }
                Text {
                    text: Services.SystemStats.cpuPct + "%"
                    color: Services.Theme.pillAccent
                    font.pixelSize: Services.Theme.fontSizeSmall
                    font.family: Services.Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: Services.SystemStats.cpuTemp > 0 ? "  " + Services.SystemStats.cpuTemp.toFixed(0) + "\u00b0" : ""
                    color: Services.Theme.foreground
                    opacity: 0.5
                    font.pixelSize: Services.Theme.fontSizeSmall - 2
                    font.family: Services.Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Canvas {
                id: sparkline
                width: parent.width
                height: 48
                property var data: Services.SystemStats.cpuHistory
                property color lineColor: Services.Theme.pillAccent
                onDataChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var d = data
                    if (!d || d.length < 2) return
                    var step = width / (d.length - 1)

                    ctx.beginPath()
                    for (var i = 0; i < d.length; i++) {
                        var x = i * step
                        var y = height - (d[i] / 100) * height
                        i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
                    }
                    ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath()
                    var r = Math.round(lineColor.r * 255), g = Math.round(lineColor.g * 255), b = Math.round(lineColor.b * 255)
                    var grad = ctx.createLinearGradient(0, 0, 0, height)
                    grad.addColorStop(0, "rgba(" + r + "," + g + "," + b + ",0.35)")
                    grad.addColorStop(1, "rgba(" + r + "," + g + "," + b + ",0)")
                    ctx.fillStyle = grad
                    ctx.fill()

                    ctx.beginPath()
                    for (var j = 0; j < d.length; j++) {
                        var lx = j * step, ly = height - (d[j] / 100) * height
                        j === 0 ? ctx.moveTo(lx, ly) : ctx.lineTo(lx, ly)
                    }
                    ctx.strokeStyle = "rgb(" + r + "," + g + "," + b + ")"
                    ctx.lineWidth = 2
                    ctx.lineJoin = "round"; ctx.lineCap = "round"
                    ctx.stroke()
                }
            }
        }
    }

    // ---- RAM / Disk / Temp rings ----
    Rectangle {
        width: parent.width
        height: 92
        radius: 14
        color: Services.Theme.pillColor

        Row {
            anchors.centerIn: parent
            spacing: 0

            Repeater {
                model: [
                    { label: "RAM",  pct: Services.SystemStats.ramTotalMb > 0 ? Math.round(Services.SystemStats.ramUsedMb / Services.SystemStats.ramTotalMb * 100) : 0,
                      val: (Services.SystemStats.ramUsedMb / 1024).toFixed(1) + "G", color: Services.Theme.pillAccent },
                    { label: "DISK", pct: popup.diskPct,
                      val: popup.diskPct + "%", color: Services.Theme.pillSecondary },
                    { label: "TEMP", pct: Math.min(100, Math.round(Services.SystemStats.cpuTemp / 100 * 100)),
                      val: Services.SystemStats.cpuTemp.toFixed(0) + "\u00b0", color: Services.Theme.pillTertiary }
                ]
                delegate: Item {
                    required property var modelData
                    width: (320 - 24) / 3
                    height: 92

                    Canvas {
                        id: ring
                        anchors.centerIn: parent
                        width: 70; height: 70
                        property color ringColor: parent.modelData.color
                        property real pct: parent.modelData.pct / 100
                        onPctChanged: requestPaint()
                        onRingColorChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = width / 2, cy = height / 2, r = 26
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, Math.PI * 2)
                            ctx.strokeStyle = Qt.rgba(Services.Theme.foreground.r, Services.Theme.foreground.g, Services.Theme.foreground.b, 0.12)
                            ctx.lineWidth = 7
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * pct)
                            ctx.strokeStyle = ringColor
                            ctx.lineWidth = 7
                            ctx.lineCap = "round"
                            ctx.stroke()
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 0
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.parent.modelData.val
                            color: Services.Theme.foreground
                            font.pixelSize: Services.Theme.fontSizeSmall - 1
                            font.family: Services.Theme.fontFamily
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: parent.parent.modelData.label
                            color: Services.Theme.foreground
                            opacity: 0.5
                            font.pixelSize: Services.Theme.fontSizeSmall - 4
                            font.family: Services.Theme.fontFamily
                        }
                    }
                }
            }
        }
    }

    // ---- Network ----
    Rectangle {
        width: parent.width
        height: 40
        radius: 14
        color: Services.Theme.pillColor

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: "Network"
                color: Services.Theme.foreground
                opacity: 0.7
                font.pixelSize: Services.Theme.fontSizeSmall - 1
                font.family: Services.Theme.fontFamily
                anchors.verticalCenter: parent.verticalCenter
            }
            Item { width: parent.width - 220; height: 1 }
            Text {
                text: "\u2193 " + (popup.netRx < 1024 ? popup.netRx.toFixed(0) + " KB/s" : (popup.netRx / 1024).toFixed(1) + " MB/s")
                    + "  \u2191 " + (popup.netTx < 1024 ? popup.netTx.toFixed(0) + " KB/s" : (popup.netTx / 1024).toFixed(1) + " MB/s")
                color: Services.Theme.pillAccent
                font.pixelSize: Services.Theme.fontSizeSmall - 2
                font.family: Services.Theme.fontFamily
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ---- Top processes ----
    Column {
        width: parent.width
        spacing: 2

        Row {
            width: parent.width
            Text { text: "Process"; color: Services.Theme.foreground; opacity: 0.5; font.pixelSize: Services.Theme.fontSizeSmall - 3; font.family: Services.Theme.fontFamily; width: parent.width - 88 }
            Text { text: "CPU"; color: Services.Theme.foreground; opacity: 0.5; font.pixelSize: Services.Theme.fontSizeSmall - 3; font.family: Services.Theme.fontFamily; width: 44; horizontalAlignment: Text.AlignRight }
            Text { text: "MEM"; color: Services.Theme.foreground; opacity: 0.5; font.pixelSize: Services.Theme.fontSizeSmall - 3; font.family: Services.Theme.fontFamily; width: 44; horizontalAlignment: Text.AlignRight }
        }

        Repeater {
            model: popup.processes
            delegate: Item {
                required property var modelData
                width: parent.width
                height: 28

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: procMa.containsMouse ? Services.Theme.hoverBg : "transparent"
                }
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    Text { text: parent.parent.modelData.name; color: Services.Theme.foreground; font.pixelSize: Services.Theme.fontSizeSmall - 1; font.family: Services.Theme.fontFamily; width: parent.width - 88; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: parent.parent.modelData.cpu + "%"; color: Services.Theme.pillAccent; font.pixelSize: Services.Theme.fontSizeSmall - 1; font.family: Services.Theme.fontFamily; width: 44; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: parent.parent.modelData.mem + "%"; color: Services.Theme.pillSecondary; font.pixelSize: Services.Theme.fontSizeSmall - 1; font.family: Services.Theme.fontFamily; width: 44; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: procMa; anchors.fill: parent; hoverEnabled: true }
            }
        }
    }
}
