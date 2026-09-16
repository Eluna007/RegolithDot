import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../services"
import "tailscale/Tailscale.js" as TS

// Tailscale from the bar: connect and disconnect, see the tailnet, pick an
// exit node, copy a peer's address.
//
// Parsing lives in tailscale/Tailscale.js and is covered by
// scripts/test-tailscale.js under node. This file runs the commands and draws
// the result.
//
// `tailscale up`, `down` and `set` normally need root. Rather than reach for a
// password prompt, the panel runs them as you and shows what the CLI said when
// it refuses - with the one-time fix, which is to make yourself the operator.
PanelWindow {
    id: root
    signal close()

    anchors.top: true
    anchors.left: Config.barPosition === "left"
    anchors.right: Config.barPosition !== "left"
    margins.top: Config.barPosition === "top" ? 42 : 10
    margins.left: Config.barPosition === "left" ? 52 : 0
    margins.right: Config.barPosition === "right" ? 52 : 0
    exclusiveZone: 0
    implicitWidth: 396
    implicitHeight: tsContent.implicitHeight + 10
    color: "transparent"

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"
    readonly property color surface0: Config.surface0
    readonly property color surface1: Config.surface1
    readonly property color overlay0: Config.overlay0
    readonly property color subtext0: Config.subtext0
    readonly property color text:     Config.text
    readonly property color accent:   Config.accent
    readonly property color maroon:   Config.maroon
    readonly property color teal:     Config.teal
    readonly property color peach:    Config.peach

    // ── State ───────────────────────────────────────────────────────────
    //
    // Polling lives in shell.qml, so the bar icon knows the connection state
    // while this panel is closed and the two can never disagree about it.
    required property var shared

    readonly property var status: shared.tsStatus
    readonly property bool installed: shared.tsInstalled
    readonly property bool connected: status.running

    property bool busy: false
    property string lastError: ""
    property bool showPeers: false

    function refresh() {
        if (!shared.tsProc.running) shared.tsProc.running = true
    }

    // Opening the panel should show current state, not whatever the 20-second
    // poll last saw.
    onVisibleChanged: if (visible) refresh()


    // ── Running commands ────────────────────────────────────────────────
    //
    // The result comes back tagged on stdout rather than from Process.exitCode,
    // which is used nowhere else in this shell - reading a property that does
    // not exist throws inside the handler, and would break this quietly.
    // Output and status arrive together, so a failure can be shown verbatim:
    // "permission denied" is the message that tells you what to do about it.
    property string actionOut: ""
    Process {
        id: actionProc
        stdout: SplitParser { onRead: chunk => root.actionOut += chunk + "\n" }
        onRunningChanged: {
            if (running) { root.actionOut = ""; return }
            root.busy = false
            var out = root.actionOut
            var marker = out.lastIndexOf("__RC__")
            var rc = marker === -1 ? 0 : parseInt(out.slice(marker + 6), 10)
            var msg = (marker === -1 ? out : out.slice(0, marker)).trim()
            root.lastError = (rc === 0 || isNaN(rc)) ? ""
                           : (msg === "" ? "Command failed" : msg)
            root.refresh()
        }
    }

    // args go in as argv entries after the wrapper, never spliced into the
    // command string, so a peer name cannot become a second command.
    function run(args) {
        if (actionProc.running) return
        root.busy = true
        root.lastError = ""
        actionProc.command = ["sh", "-c",
            "out=$(\"$@\" 2>&1); rc=$?; printf '%s\\n__RC__%s' \"$out\" \"$rc\"",
            "sh"].concat(args)
        actionProc.running = true
    }

    function goUp()   { run(["tailscale", "up"]) }
    function goDown() { run(["tailscale", "down"]) }

    function setExitNode(target) {
        if (target !== "" && !TS.validNodeTarget(target)) {
            root.lastError = "Refusing an unsafe exit-node name"
            return
        }
        run(["tailscale", "set", "--exit-node=" + target])
    }

    // wl-copy is what the clipboard panel already uses.
    Process { id: copyProc }
    function copy(value) {
        if (copyProc.running) return
        copyProc.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", value]
        copyProc.running = true
    }

    // ── Layout ──────────────────────────────────────────────────────────
    Rectangle {
        id: tsContent
        width: parent.width
        implicitHeight: tsCol.implicitHeight + 28
        radius: 22
        color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.70)
        border.width: 1
        border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)
        clip: true

        Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 22; height: 22; color: parent.color }
        // Grows out of the bar edge instead of fading in, so the edge
        // you clicked stays put while the rest of the card unfolds.
        // Curves are Caelestia's Material 3 expressive set; see
        // services/Motion.qml for the measured overshoot and why it cannot clip.
        transformOrigin: Motion.originFor(Config.barPosition)
        NumberAnimation on opacity {
            from: 0; to: 1; running: true
            duration: Motion.effects
            easing.type: Easing.Bezier; easing.bezierCurve: Motion.curveDefaultEffects
        }
        NumberAnimation on scale {
            from: Motion.fromScale; to: 1; running: true
            duration: Motion.spatial
            easing.type: Easing.Bezier; easing.bezierCurve: Motion.curveDefaultSpatial
        }

        ColumnLayout {
            id: tsCol
            width: parent.width - 28
            anchors { top: parent.top; left: parent.left }
            anchors.margins: 14
            spacing: 9

            // Header + master switch
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "TAILSCALE"
                    color: root.subtext0
                    font { pixelSize: 11; bold: true; family: root.nfFont; letterSpacing: 2 }
                }
                Item { Layout.fillWidth: true }

                // A switch, not a button: the state is the point.
                Rectangle {
                    visible: root.installed
                    implicitWidth: 44
                    implicitHeight: 24
                    radius: 12
                    opacity: root.busy ? 0.5 : 1
                    color: root.connected
                           ? Qt.rgba(root.teal.r, root.teal.g, root.teal.b, 0.45)
                           : root.surface1
                    Behavior on color { ColorAnimation { duration: 140 } }

                    Rectangle {
                        width: 18; height: 18; radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.connected ? parent.width - width - 3 : 3
                        color: root.connected ? root.teal : root.overlay0
                        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.busy
                        onClicked: root.connected ? root.goDown() : root.goUp()
                    }
                }
            }

            // Status line
            Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: !root.installed ? "TAILSCALE IS NOT INSTALLED"
                    : root.busy ? "WORKING…"
                    : TS.statusText(root.status)
                color: !root.installed ? root.overlay0
                     : root.connected ? root.teal
                     : root.status.needsLogin ? root.peach
                     : root.subtext0
                font { pixelSize: 10; bold: true; family: root.nfFont; letterSpacing: 1 }
            }

            // This machine
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: 12
                color: root.surface0
                visible: root.installed && root.status.self.ip !== ""

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 8

                    ColumnLayout {
                        spacing: 1
                        Text {
                            textFormat: Text.PlainText
                            text: root.status.self.name
                            color: root.text
                            font { pixelSize: 12; bold: true; family: root.nfFont }
                        }
                        Text {
                            textFormat: Text.PlainText
                            text: root.status.tailnet
                            visible: text !== ""
                            color: root.overlay0
                            font { pixelSize: 9; family: root.nfFont }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        textFormat: Text.PlainText
                        text: root.status.self.ip
                        color: root.accent
                        font { pixelSize: 11; family: root.nfFont }
                    }
                    TsButton {
                        glyph: "\u{f018f}"
                        tip: "Copy address"
                        onTriggered: root.copy(root.status.self.ip)
                    }
                }
            }

            // Sign-in prompt. Without this a fresh machine shows "disconnected"
            // and the switch does nothing visible, with the auth URL only in
            // the terminal where nobody is looking.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 44
                radius: 12
                color: Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.15)
                visible: root.installed && root.status.needsLogin

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        text: "This machine is not signed in. Run `tailscale up` in a terminal to get a login link."
                        color: root.peach
                        font { pixelSize: 10; family: root.nfFont }
                    }
                }
            }

            // Exit node
            Rectangle {
                Layout.fillWidth: true
                radius: 12
                color: root.surface0
                visible: root.installed && root.connected && exitRow.hasCandidates
                implicitHeight: exitCol.implicitHeight + 16

                ColumnLayout {
                    id: exitCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                    spacing: 4

                    Text {
                        text: "EXIT NODE"
                        color: root.overlay0
                        font { pixelSize: 9; bold: true; family: root.nfFont; letterSpacing: 1 }
                    }

                    Flow {
                        id: exitRow
                        Layout.fillWidth: true
                        spacing: 4
                        readonly property var candidates: TS.exitNodeCandidates(root.status)
                        readonly property bool hasCandidates: candidates.length > 0

                        // "None" first, so turning it off is never a hunt.
                        Rectangle {
                            implicitWidth: noneText.implicitWidth + 16
                            implicitHeight: 24
                            radius: 8
                            color: root.status.exitNodeName === ""
                                   ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.28)
                                   : root.surface1
                            Text {
                                id: noneText
                                anchors.centerIn: parent
                                text: "None"
                                color: root.status.exitNodeName === "" ? root.accent : root.subtext0
                                font { pixelSize: 10; family: root.nfFont }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.busy
                                onClicked: root.setExitNode("")
                            }
                        }

                        Repeater {
                            model: exitRow.candidates
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: root.status.exitNodeName === modelData.name
                                implicitWidth: exitLabel.implicitWidth + 16
                                implicitHeight: 24
                                radius: 8
                                color: active ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.28)
                                     : root.surface1
                                Text {
                                    id: exitLabel
                                    anchors.centerIn: parent
                                    textFormat: Text.PlainText
                                    text: modelData.name
                                    color: active ? root.accent : root.subtext0
                                    font { pixelSize: 10; family: root.nfFont }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: !root.busy
                                    onClicked: root.setExitNode(active ? "" : modelData.dnsName)
                                }
                            }
                        }
                    }
                }
            }

            // Peers
            RowLayout {
                Layout.fillWidth: true
                visible: root.installed && root.status.peers.length > 0
                Text {
                    textFormat: Text.PlainText
                    text: TS.onlineCount(root.status) + " of " + root.status.peers.length + " online"
                    color: root.overlay0
                    font { pixelSize: 10; family: root.nfFont }
                }
                Item { Layout.fillWidth: true }
                TsButton {
                    glyph: root.showPeers ? "\u{f0140}" : "\u{f0143}"
                    tip: root.showPeers ? "Hide devices" : "Show devices"
                    onTriggered: root.showPeers = !root.showPeers
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 12
                color: root.surface0
                visible: root.showPeers && root.status.peers.length > 0
                implicitHeight: Math.min(peerList.contentHeight, 176) + 12

                ListView {
                    id: peerList
                    anchors { fill: parent; margins: 6 }
                    clip: true
                    spacing: 1
                    model: root.status.peers

                    delegate: Rectangle {
                        required property var modelData
                        width: peerList.width
                        height: 30
                        radius: 8
                        color: peerHov.containsMouse ? root.surface1 : "transparent"

                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            spacing: 8

                            Rectangle {
                                width: 7; height: 7; radius: 3.5
                                color: modelData.online ? root.teal : root.overlay0
                            }
                            Text {
                                textFormat: Text.PlainText
                                text: modelData.name
                                color: modelData.online ? root.text : root.overlay0
                                font { pixelSize: 11; family: root.nfFont }
                            }
                            Text {
                                textFormat: Text.PlainText
                                text: TS.osLabel(modelData.os)
                                color: root.overlay0
                                font { pixelSize: 9; family: root.nfFont }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                textFormat: Text.PlainText
                                // Offline peers show how long ago, which is the
                                // only useful thing left to say about them.
                                text: modelData.online ? modelData.ip
                                                       : TS.relativeAge(modelData.lastSeen)
                                color: root.overlay0
                                font { pixelSize: 9; family: root.nfFont }
                            }
                        }

                        MouseArea {
                            id: peerHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.copy(modelData.ip)
                        }
                    }
                }
            }

            // Errors. `tailscale up` needs root unless you are the operator,
            // so say that rather than leaving a switch that does nothing.
            Rectangle {
                Layout.fillWidth: true
                radius: 12
                color: Qt.rgba(root.maroon.r, root.maroon.g, root.maroon.b, 0.15)
                visible: root.lastError !== ""
                implicitHeight: errCol.implicitHeight + 16

                ColumnLayout {
                    id: errCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                    spacing: 3
                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        text: root.lastError
                        color: root.maroon
                        font { pixelSize: 10; family: root.nfFont }
                    }
                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        visible: root.lastError.toLowerCase().indexOf("permission") !== -1
                                 || root.lastError.toLowerCase().indexOf("access denied") !== -1
                                 || root.lastError.toLowerCase().indexOf("root") !== -1
                        text: "One-time fix: sudo tailscale set --operator=$USER"
                        color: root.overlay0
                        font { pixelSize: 9; family: root.nfFont }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !root.installed
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                text: "Install it with: sudo pacman -S tailscale, then enable tailscaled."
                color: root.overlay0
                font { pixelSize: 10; family: root.nfFont }
            }
        }
    }

    component TsButton: Rectangle {
        id: btn
        property string glyph: ""
        property string tip: ""
        signal triggered()

        implicitWidth: 26
        implicitHeight: 24
        radius: 7
        color: btnHov.containsMouse ? root.surface1 : "transparent"
        Behavior on color { ColorAnimation { duration: 90 } }

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: root.subtext0
            font { pixelSize: 13; family: root.nfFont }
        }
        MouseArea {
            id: btnHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.triggered()
        }
    }
}
