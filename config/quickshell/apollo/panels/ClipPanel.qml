import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
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

    anchors.top: true
    anchors.left: Config.barPosition === "left"
    anchors.right: Config.barPosition !== "left"
    margins.top: Config.barPosition === "top" ? 42 : 10
    margins.left: Config.barPosition === "left" ? 52 : 0
    margins.right: Config.barPosition === "right" ? 52 : 0
    exclusiveZone: 0
    implicitWidth: 360
    implicitHeight: Math.min(clipContent.implicitHeight + 10, 500)
    color: "transparent"

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"
    readonly property color surface0: Config.surface0
    readonly property color surface1: Config.surface1
    readonly property color surface2: Config.surface2
    readonly property color overlay0: Config.overlay0
    readonly property color overlay1: Config.overlay1
    readonly property color subtext0: Config.subtext0
    readonly property color text:     Config.text
    readonly property color accent:     Config.accent
    readonly property color green:    Config.green

    ListModel { id: clipModel }
    property int copiedIdx: -1

    // What --list reported on its status line: "ok", "missing" (no copyq
    // binary) or "noserver" (copyq is there but its server would not answer).
    // Empty until the first read.
    property string clipStatus: ""

    // copyq, not cliphist. autostart.lua runs copyq and says cliphist is
    // deliberately absent, so querying cliphist here showed an empty list
    // forever beside a copyq that was catching everything.
    //
    // Absolute path under the shell's own config dir, so the script cannot
    // drift from this file and nothing depends on PATH.
    readonly property string clipScript: Config.shellScript("clipboard.sh")

    Process {
        id: clipProc
        command: [root.clipScript, "--list"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim() === "") return
                // "row<TAB>preview", or "!<TAB>status" for the one status line
                // the script always prints first.
                var tab = data.indexOf("\t")
                var id = tab >= 0 ? data.substring(0, tab) : ""
                var txt = tab >= 0 ? data.substring(tab + 1) : data
                if (id === "!") { root.clipStatus = txt.trim(); return }
                clipModel.append({ clipId: id, text: txt.trim().substring(0, 120) })
            }
        }
    }

    onVisibleChanged: if (visible) {
        clipModel.clear()
        copiedIdx = -1
        clipStatus = ""
        clipProc.running = true
    }

    Rectangle {
        id: clipContent
        width: parent.width
        implicitHeight: Math.min(clipCol.implicitHeight + 10, 490)
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
            id: clipCol
            width: parent.width
            anchors { top: parent.top; left: parent.left }
            spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 18
                Layout.bottomMargin: 6

                Text { text: "CLIPBOARD"; color: root.subtext0; font { pixelSize: 11; bold: true; family: root.nfFont } }
                Item { Layout.fillWidth: true }
                Text {
                    text: "Clear"
                    color: root.accent
                    font { pixelSize: 11; family: root.nfFont }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached([root.clipScript, "--clear"])
                            clipModel.clear()
                        }
                    }
                }
            }

            // Empty state
            Item {
                Layout.fillWidth: true
                implicitHeight: 80
                visible: clipModel.count === 0 && !clipProc.running

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { Layout.alignment: Qt.AlignHCenter; text: "󰅬"; color: root.overlay0; font { pixelSize: 28; family: root.nfFont } opacity: 0.6 }
                    // Three different things produce zero rows, and saying
                    // "empty" to all three is how a broken clipboard looks
                    // exactly like an unused one.
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        textFormat: Text.PlainText
                        text: root.clipStatus === "missing"
                              ? "copyq is not installed"
                              : root.clipStatus === "noserver"
                              ? "copyq is installed but not running"
                              : "Clipboard is empty"
                        color: root.overlay0
                        font { pixelSize: 12; family: root.nfFont }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        textFormat: Text.PlainText
                        visible: root.clipStatus === "missing" || root.clipStatus === "noserver"
                        text: root.clipStatus === "missing"
                              ? "sudo pacman -S copyq"
                              : "copyq &   ·   or run clipboard.sh --doctor"
                        color: root.overlay0
                        font { pixelSize: 10; family: root.nfFont }
                        opacity: 0.8
                    }
                }
            }

            // Clip list
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.bottomMargin: 8
                spacing: 2
                visible: clipModel.count > 0

                Repeater {
                    model: clipModel
                    delegate: Item {
                        required property var model
                        required property int index
                        Layout.fillWidth: true
                        height: 44

                        Rectangle {
                            anchors.fill: parent; radius: 11
                            color: clipHov.containsMouse ? root.surface0 : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            spacing: 11

                            Text {
                                text: "󰅬"
                                color: root.overlay1
                                font { pixelSize: 15; family: root.nfFont }
                            }

                            Text {
                                text: model.text
                                color: root.text
                                font { pixelSize: 12; family: root.nfFont }
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.copiedIdx === parent.parent.parent.index ? "󰄬" : "󰆎"
                                color: root.copiedIdx === parent.parent.parent.index ? root.green : root.overlay0
                                font { pixelSize: 15; family: root.nfFont }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        MouseArea {
                            id: clipHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.copiedIdx = parent.index
                                var id = parent.model.clipId
                                Quickshell.execDetached([root.clipScript, "--use", String(id)])
                                copiedTimer.restart()
                            }
                        }
                    }
                }
            }
        }
    }

    Timer { id: copiedTimer; interval: 900; onTriggered: root.copiedIdx = -1 }
}
