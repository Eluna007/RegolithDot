import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../services" as Services
import "../../" as Root

PanelWindow {
    id: qcWin

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Keep window alive during slide-out animation
    property bool panelOpen: false
    visible: false

    Connections {
        target: Services.QuickControls
        function onVisibleChanged() {
            if (Services.QuickControls.visible) {
                qcWin.visible = true
                qcWin.panelOpen = true
            } else {
                qcWin.panelOpen = false
                closeDelay.start()
            }
        }
    }

    Timer { id: closeDelay; interval: 300; onTriggered: qcWin.visible = false }

    // Runners
    Process { id: volRunner }
    Process { id: briRunner }

    Timer {
        id: briDebounce
        interval: 80
        property int pending: Services.Brightness.percent
        onTriggered: {
            briRunner.command = ["brightnessctl", "-e4", "set", pending + "%"]
            briRunner.running = true
        }
    }

    function applyVolume(v) {
        volRunner.command = ["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", v + "%"]
        volRunner.running = true
    }

    Item {
        anchors.fill: parent

        // Backdrop — click outside panel to close
        Rectangle {
            anchors { fill: parent; rightMargin: 300 }
            color: "#66000000"
            opacity: qcWin.panelOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
            MouseArea {
                anchors.fill: parent
                onClicked: Services.QuickControls.close()
            }
        }

        // Side panel
        Rectangle {
            id: panel
            width: 300
            anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
            color: Root.Theme.pillBg

            opacity: qcWin.panelOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }

            transform: Translate {
                x: qcWin.panelOpen ? 0 : 320
                Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            }

            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 14

                // ── Header ─────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Quick Controls"
                        color: Root.Theme.textPrimary
                        font.pixelSize: 14
                        font.weight: Font.SemiBold
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: xHover ? Root.Theme.pillBgActive : Root.Theme.pillBgHover
                        property bool xHover: false
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: Root.Theme.textMuted
                            font.pixelSize: 13
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.xHover = true
                            onExited:  parent.xHover = false
                            onClicked: Services.QuickControls.close()
                        }
                    }
                }

                // ── Volume ─────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: volCard.implicitHeight + 24
                    radius: 14
                    color: Root.Theme.pillBgHover

                    ColumnLayout {
                        id: volCard
                        anchors { fill: parent; margins: 12 }
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: Services.Audio.icon
                                color: Services.Audio.muted ? "#f38ba8" : Root.Theme.textAccent
                                font.pixelSize: 16
                                MouseArea { anchors.fill: parent; onClicked: Services.Audio.toggleMute() }
                            }
                            Text { text: "Volume"; color: Root.Theme.textMuted; font.pixelSize: 12 }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Services.Audio.muted ? "Muted" : Services.Audio.percent + "%"
                                color: Services.Audio.muted ? "#f38ba8" : Root.Theme.textPrimary
                                font.pixelSize: 12; font.weight: Font.Medium
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            height: 44

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.15)

                                Rectangle {
                                    width: parent.width * (Services.Audio.percent / 100)
                                    height: parent.height; radius: parent.radius
                                    color: Services.Audio.muted ? "#88f38ba8" : Root.Theme.textAccent
                                    Behavior on width { NumberAnimation { duration: 80 } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: mouse => qcWin.applyVolume(Math.round((mouse.x / width) * 100))
                                onMouseXChanged: {
                                    if (pressed)
                                        qcWin.applyVolume(Math.round(Math.max(0, Math.min(mouseX, width)) / width * 100))
                                }
                            }
                        }
                    }
                }

                // ── Brightness ─────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: briCard.implicitHeight + 24
                    radius: 14
                    color: Root.Theme.pillBgHover

                    ColumnLayout {
                        id: briCard
                        anchors { fill: parent; margins: 12 }
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: Services.Brightness.icon; color: Root.Theme.tertiary; font.pixelSize: 16 }
                            Text { text: "Brightness"; color: Root.Theme.textMuted; font.pixelSize: 12 }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Services.Brightness.percent + "%"
                                color: Root.Theme.textPrimary
                                font.pixelSize: 12; font.weight: Font.Medium
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            height: 44

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: Qt.rgba(Root.Theme.tertiary.r, Root.Theme.tertiary.g, Root.Theme.tertiary.b, 0.15)

                                Rectangle {
                                    width: parent.width * (Services.Brightness.percent / 100)
                                    height: parent.height; radius: parent.radius
                                    color: Root.Theme.tertiary
                                    Behavior on width { NumberAnimation { duration: 80 } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: mouse => {
                                    briDebounce.pending = Math.round((mouse.x / width) * 100)
                                    briDebounce.triggered()
                                }
                                onMouseXChanged: {
                                    if (pressed) {
                                        briDebounce.pending = Math.round(Math.max(0, Math.min(mouseX, width)) / width * 100)
                                        briDebounce.restart()
                                    }
                                }
                                onReleased: { briDebounce.stop(); briDebounce.triggered() }
                            }
                        }
                    }
                }

                // ── Network + Battery ──────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true; height: 76
                        radius: 14; color: Root.Theme.pillBgHover

                        ColumnLayout {
                            anchors { fill: parent; margins: 12 }
                            spacing: 4

                            RowLayout {
                                spacing: 6
                                Text { text: Services.Network.icon; color: Services.Network.color; font.pixelSize: 15 }
                                Text { text: "Network"; color: Root.Theme.textMuted; font.pixelSize: 11 }
                            }
                            Text {
                                text: Services.Network.connected ? Services.Network.ssid : "Offline"
                                color: Services.Network.color
                                font.pixelSize: 11; font.weight: Font.Medium
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 76
                        radius: 14; color: Root.Theme.pillBgHover

                        ColumnLayout {
                            anchors { fill: parent; margins: 12 }
                            spacing: 4

                            RowLayout {
                                spacing: 6
                                Text { text: Services.Battery.icon; color: Services.Battery.color; font.pixelSize: 15 }
                                Text { text: "Battery"; color: Root.Theme.textMuted; font.pixelSize: 11 }
                            }
                            Text {
                                text: Services.Battery.percent + "%" + (Services.Battery.charging ? "  ⚡" : "")
                                color: Services.Battery.color
                                font.pixelSize: 11; font.weight: Font.Medium
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
