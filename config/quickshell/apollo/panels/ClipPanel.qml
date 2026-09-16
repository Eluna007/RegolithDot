import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../services"

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

    // copyq, not cliphist. autostart.lua runs copyq and says cliphist is
    // deliberately absent, so querying cliphist here showed an empty list
    // forever beside a copyq that was catching everything.
    //
    // Absolute path under the shell's own config dir, so the script cannot
    // drift from this file and nothing depends on PATH.
    readonly property string clipScript:
        (Quickshell.env("XDG_CONFIG_HOME") !== ""
            ? Quickshell.env("XDG_CONFIG_HOME")
            : Quickshell.env("HOME") + "/.config")
        + "/quickshell/apollo/scripts/clipboard.sh"

    Process {
        id: clipProc
        command: [root.clipScript, "--list"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim() !== "") {
                    // "row<TAB>preview"
                    var tab = data.indexOf("\t")
                    var id = tab >= 0 ? data.substring(0, tab) : ""
                    var txt = tab >= 0 ? data.substring(tab + 1) : data
                    clipModel.append({ clipId: id, text: txt.trim().substring(0, 120) })
                }
            }
        }
    }

    onVisibleChanged: if (visible) {
        clipModel.clear()
        copiedIdx = -1
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
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Clipboard is empty"; color: root.overlay0; font { pixelSize: 12; family: root.nfFont } }
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
