import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../bar"
import "../services"

PanelWindow {
    id: root
    signal close()

    // ── Opening ──────────────────────────────────────────────────────────
    // The card unrolls out of the bar edge: its own clip does the masking, so
    // the text is uncovered at full size rather than scaled up out of a blur.
    // This is how Caelestia's popouts read, and why they look attached to the
    // bar instead of appearing next to it.
    //
    // `running: visible` rather than a NumberAnimation-on-property with
    // `running: true`. shell.qml creates every panel eagerly and toggles it
    // with `visible`, so an animation that starts on component completion
    // fires once, at login, while the panel is hidden — and is never seen
    // again. That is why the old fade was invisible.
    //
    // Defaults to 1, so a panel is fully drawn even if this never runs.
    property real reveal: 1
    NumberAnimation {
        target: root
        property: "reveal"
        from: 0; to: 1
        duration: Motion.spatial
        easing.type: Easing.Bezier
        easing.bezierCurve: Motion.curveDefaultSpatial
        running: root.visible
    }

    // Battery values come from shell.qml's single poller rather than a second
    // one here: the bar pill and this card must never disagree about the
    // charge, and polling twice to show the same number is waste.
    required property var shared

    readonly property real battPct:     shared.battPct
    readonly property bool battCharging: shared.battCharging
    readonly property string battStatus: shared.battStatus
    readonly property real battSecs:    shared.battSecs
    readonly property real battHealth:  shared.battHealth
    readonly property bool battKnown:   shared.battPct >= 0

    // "2h 40m". Empty when there is no estimate - which is the honest answer
    // while idle or full, not "0m".
    function battEta(secs) {
        if (secs === undefined || secs < 0) return ""
        var h = Math.floor(secs / 3600)
        var m = Math.floor(secs / 60) % 60
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    anchors.top: true
    anchors.left: Config.barPosition === "left"
    anchors.right: Config.barPosition !== "left"
    margins.top: Config.barPosition === "top" ? 42 : 10
    margins.left: Config.barPosition === "left" ? 52 : 0
    margins.right: Config.barPosition === "right" ? 52 : 0
    exclusiveZone: 0
    implicitWidth: 396
    implicitHeight: smContent.implicitHeight + 10
    color: "transparent"

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"
    readonly property color surface0: Config.surface0
    readonly property color surface1: Config.surface1
    readonly property color surface2: Config.surface2
    readonly property color overlay0: Config.overlay0
    readonly property color subtext0: Config.subtext0
    readonly property color text:     Config.text
    readonly property color accent:     Config.accent
    readonly property color blue:     Config.blue
    readonly property color mauve:    Config.mauve
    readonly property color teal:     Config.teal
    readonly property color peach:    Config.peach
    readonly property color maroon:   Config.maroon

    // Stats
    SystemStats { id: sysStats; enabled: root.visible }

    // Disk usage
    property int diskPct: 0
    Process {
        id: diskProc
        command: ["sh", "-c", "df / | awk 'NR==2{gsub(/%/,\"\",$5); print $5}'"]
        stdout: SplitParser { onRead: d => root.diskPct = parseInt(d) || 0 }
    }

    // Process list — buffer then swap atomically (no flicker)
    ListModel { id: procModel }
    property var procBuffer: []
    Process {
        id: procProc
        command: ["sh", "-c", "NCPU=$(nproc); ps aux --sort=-%cpu | awk -v nc=$NCPU 'NR>1 && NR<=7{cpu=$3/nc; if(cpu>100)cpu=100; printf \"%s %.1f %.1f\\n\", $11, cpu, $4}'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim() === "") return
                var p = data.trim().split(" ")
                if (p.length >= 3) {
                    var name = p[0].split("/").pop()
                    root.procBuffer.push({ name: name.substring(0,18), cpu: parseFloat(p[1]).toFixed(1), mem: parseFloat(p[2]).toFixed(1) })
                }
            }
        }
        onRunningChanged: {
            if (!running && root.procBuffer.length > 0) {
                procModel.clear()
                for (var i = 0; i < root.procBuffer.length; i++) procModel.append(root.procBuffer[i])
                root.procBuffer = []
            }
        }
    }

    // Net speed
    property real netRx: 0
    property real netTx: 0
    property var  _prevNet: []
    Process {
        id: netProc
        // Track whichever interface actually carries the default route (wifi or
        // ethernet), falling back to the first wireless device — never a
        // hardcoded name, so the readout works on any machine, not just this one.
        command: ["sh", "-c", "IF=$(ip route show default 2>/dev/null | awk '{print $5; exit}'); [ -z \"$IF\" ] && IF=$(ls /sys/class/net 2>/dev/null | grep -E '^wl' | head -1); [ -n \"$IF\" ] && awk -v p=\"$IF:\" '$1==p{print $2, $10}' /proc/net/dev"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(" ").map(Number)
                if (root._prevNet.length === 2) {
                    root.netRx = Math.max(0, (p[0] - root._prevNet[0]) / 1024 / 3)
                    root.netTx = Math.max(0, (p[1] - root._prevNet[1]) / 1024 / 3)
                }
                root._prevNet = p
            }
        }
    }

    onVisibleChanged: if (visible) {
        root.procBuffer = []
        diskProc.running = true
        netProc.running = true
        procProc.running = true
    }

    Timer {
        interval: 5000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: {
            diskProc.running = true
            netProc.running = true
            if (root.visible) { root.procBuffer = []; procProc.running = true }
        }
    }

    Rectangle {
        id: smContent
        width: parent.width
        implicitHeight: smCol.implicitHeight + 10
        radius: 22
        color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.70)
        border.width: 1
        border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)
        clip: true

        Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 22; height: 22; color: parent.color }
        // Revealed rather than faded: see `reveal` on the root.
        height: Math.max(1, Math.round(implicitHeight * root.reveal))
        opacity: Math.min(1, root.reveal * 2)

        ColumnLayout {
            id: smCol
            width: parent.width
            anchors { top: parent.top; left: parent.left }
            spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 18
                Layout.bottomMargin: 6

                Text { text: "SYSTEM MONITOR"; color: root.subtext0; font { pixelSize: 11; bold: true; family: root.nfFont } }
                Item { Layout.fillWidth: true }
                Text { text: ""; color: root.accent; font { pixelSize: 18; family: root.nfFont } }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                spacing: 11

                // CPU card with sparkline
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 110; radius: 16; color: root.surface0

                    ColumnLayout {
                        anchors { fill: parent; margins: 15 }
                        spacing: 8

                        RowLayout {
                            Text { text: ""; color: root.subtext0; font { pixelSize: 14; family: root.nfFont } }
                            Text { text: "CPU"; color: root.subtext0; font { pixelSize: 12; family: root.nfFont } }
                            Item { Layout.fillWidth: true }
                            Text { text: sysStats.cpuPct + "%"; color: root.accent; font { pixelSize: 14; bold: true; family: root.nfFont } }
                            Text { text: sysStats.cpuTemp > 0 ? sysStats.cpuTemp.toFixed(0) + "°C" : ""; color: root.overlay0; font { pixelSize: 11; family: root.nfFont } }
                        }

                        // Sparkline
                        Canvas {
                            Layout.fillWidth: true; height: 48
                            property var data: sysStats.cpuHistory
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
                                // Area fill
                                ctx.lineTo(width, height); ctx.lineTo(0, height); ctx.closePath()
                                var ar = Math.round(root.accent.r*255), ag = Math.round(root.accent.g*255), ab = Math.round(root.accent.b*255)
                                var grad = ctx.createLinearGradient(0, 0, 0, height)
                                grad.addColorStop(0, "rgba("+ar+","+ag+","+ab+",0.35)")
                                grad.addColorStop(1, "rgba("+ar+","+ag+","+ab+",0)")
                                ctx.fillStyle = grad; ctx.fill()
                                // Line
                                ctx.beginPath()
                                for (var j = 0; j < d.length; j++) {
                                    var lx = j * step, ly = height - (d[j] / 100) * height
                                    j === 0 ? ctx.moveTo(lx, ly) : ctx.lineTo(lx, ly)
                                }
                                ctx.strokeStyle = "rgb("+ar+","+ag+","+ab+")"; ctx.lineWidth = 2; ctx.lineJoin = "round"; ctx.lineCap = "round"
                                ctx.stroke()
                            }
                        }
                    }
                }

                // Rings: RAM / DISK / TEMP
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 100; radius: 16; color: root.surface0

                    Row {
                        anchors.centerIn: parent
                        spacing: 0

                        Repeater {
                            model: [
                                { label: "RAM",  pct: sysStats.ramTotalMb > 0 ? Math.round(sysStats.ramUsedMb / sysStats.ramTotalMb * 100) : 0,
                                  val: (sysStats.ramUsedMb/1024).toFixed(1)+"G", color: root.blue },
                                { label: "DISK", pct: root.diskPct,
                                  val: root.diskPct + "%", color: root.teal },
                                { label: "TEMP", pct: Math.min(100, Math.round(sysStats.cpuTemp / 100 * 100)),
                                  val: sysStats.cpuTemp.toFixed(0) + "°", color: root.peach },
                            ]
                            delegate: Item {
                                required property var modelData
                                width: (396 - 32) / 3; height: 100

                                Canvas {
                                    id: ringCanvas
                                    anchors.centerIn: parent
                                    width: 80; height: 80
                                    property color col: parent.modelData.color
                                    property real  pct: parent.modelData.pct / 100
                                    onPctChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0,0,width,height)
                                        var cx = width/2, cy = height/2, r = 30
                                        // Track
                                        ctx.beginPath(); ctx.arc(cx,cy,r,0,Math.PI*2)
                                        ctx.strokeStyle = root.surface0; ctx.lineWidth = 8; ctx.stroke()
                                        // Progress
                                        ctx.beginPath()
                                        ctx.arc(cx,cy,r,-Math.PI/2,-Math.PI/2+Math.PI*2*pct)
                                        ctx.strokeStyle = col; ctx.lineWidth = 8
                                        ctx.lineCap = "round"; ctx.stroke()
                                    }
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 1

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: parent.parent.modelData.val
                                        color: root.text
                                        font { pixelSize: 13; bold: true; family: root.nfFont }
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: parent.parent.modelData.label
                                        color: root.overlay0
                                        font { pixelSize: 9; family: root.nfFont }
                                    }
                                }
                            }
                        }
                    }
                }

                // Battery. The pill in the bar opens this panel, and until now
                // this panel said nothing whatsoever about the battery.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 74
                    radius: 16
                    color: root.surface0
                    visible: root.battKnown

                    RowLayout {
                        anchors { fill: parent; leftMargin: 15; rightMargin: 15 }
                        spacing: 14

                        // Charge ring. Canvas rather than QtQuick.Shapes: it is
                        // part of QtQuick itself, so this adds no import that
                        // could fail to resolve and take the shell down.
                        Item {
                            implicitWidth: 46
                            implicitHeight: 46
                            Layout.alignment: Qt.AlignVCenter

                            readonly property color ringColor:
                                  root.battCharging ? root.teal
                                : root.battPct <= 20 ? root.maroon
                                : root.accent

                            Canvas {
                                id: ring
                                anchors.fill: parent
                                // Repaint whenever anything it draws changes;
                                // a Canvas does not track bindings by itself.
                                property real pct: Math.max(0, Math.min(100, root.battPct))
                                property color arcColor: parent.ringColor
                                property color trackColor: root.surface2
                                onPctChanged: requestPaint()
                                onArcColorChanged: requestPaint()
                                onTrackColorChanged: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    var w = width, h = height
                                    var r = Math.min(w, h) / 2 - 3
                                    var cx = w / 2, cy = h / 2
                                    var start = -Math.PI / 2

                                    ctx.lineWidth = 4
                                    ctx.lineCap = "round"

                                    ctx.beginPath()
                                    ctx.strokeStyle = trackColor
                                    ctx.arc(cx, cy, r, 0, Math.PI * 2)
                                    ctx.stroke()

                                    if (pct > 0) {
                                        ctx.beginPath()
                                        ctx.strokeStyle = arcColor
                                        ctx.arc(cx, cy, r, start, start + Math.PI * 2 * (pct / 100))
                                        ctx.stroke()
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Math.round(root.battPct)
                                color: parent.ringColor
                                font { pixelSize: 14; bold: true; family: root.nfFont }
                            }
                        }

                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true

                            RowLayout {
                                spacing: 6
                                Text {
                                    text: Config.batteryIcon(root.battPct, root.battCharging)
                                    color: root.battCharging ? root.teal
                                         : root.battPct <= 20 ? root.maroon : root.subtext0
                                    font { pixelSize: 14; family: root.nfFont }
                                }
                                Text {
                                    text: "Battery"
                                    color: root.subtext0
                                    font { pixelSize: 12; family: root.nfFont }
                                }
                                Item { Layout.fillWidth: true }
                            }

                            Text {
                                text: {
                                    var eta = root.battEta(root.battSecs)
                                    if (eta !== "") return eta + (root.battCharging ? " until full" : " remaining")
                                    // No estimate is the honest answer while
                                    // idle or full - do not invent "0m".
                                    return root.battStatus === "Full" ? "Fully charged"
                                         : root.battCharging ? "Charging"
                                         : "Estimating…"
                                }
                                color: root.overlay0
                                font { pixelSize: 10; family: root.nfFont }
                            }

                            // Health is only worth the space once the pack has
                            // measurably aged; a healthy battery says nothing.
                            Text {
                                text: root.battHealth >= 0 && root.battHealth < 90
                                      ? root.battHealth + "% of design capacity" : ""
                                visible: text !== ""
                                color: root.battHealth < 75 ? root.peach : root.overlay0
                                font { pixelSize: 10; family: root.nfFont }
                            }
                        }
                    }
                }

                // Network
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 52; radius: 16; color: root.surface0

                    RowLayout {
                        anchors { fill: parent; leftMargin: 15; rightMargin: 15 }

                        Text { text: "󰜂"; color: root.subtext0; font { pixelSize: 14; family: root.nfFont } }
                        Text { text: "Network"; color: root.subtext0; font { pixelSize: 12; family: root.nfFont } }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "↓ " + (root.netRx < 1024 ? root.netRx.toFixed(0) + " KB/s" : (root.netRx/1024).toFixed(1) + " MB/s") +
                                  "  ↑ " + (root.netTx < 1024 ? root.netTx.toFixed(0) + " KB/s" : (root.netTx/1024).toFixed(1) + " MB/s")
                            color: root.blue
                            font { pixelSize: 11; bold: true; family: root.nfFont }
                        }
                    }
                }

                // Process list
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true; Layout.leftMargin: 4
                        Text { text: "Process"; color: root.subtext0; font { pixelSize: 10; bold: true; family: root.nfFont } Layout.fillWidth: true }
                        Text { text: "CPU"; color: root.subtext0; font { pixelSize: 10; bold: true; family: root.nfFont } width: 44; horizontalAlignment: Text.AlignRight }
                        Text { text: "MEM"; color: root.subtext0; font { pixelSize: 10; bold: true; family: root.nfFont } width: 44; horizontalAlignment: Text.AlignRight }
                    }

                    Repeater {
                        model: procModel
                        delegate: Item {
                            required property var model
                            Layout.fillWidth: true; height: 34

                            Rectangle {
                                anchors.fill: parent; radius: 10
                                color: procHov.containsMouse ? root.surface0 : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                Text { text: model.name; color: root.text; font { pixelSize: 12; family: root.nfFont } Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: model.cpu + "%"; color: root.accent; font { pixelSize: 12; bold: true; family: root.nfFont } width: 44; horizontalAlignment: Text.AlignRight }
                                Text { text: model.mem + "%"; color: root.blue; font { pixelSize: 12; bold: true; family: root.nfFont } width: 44; horizontalAlignment: Text.AlignRight }
                            }

                            MouseArea { id: procHov; anchors.fill: parent; hoverEnabled: true }
                        }
                    }
                }

                Item { implicitHeight: 4 }
            }
        }
    }
}
