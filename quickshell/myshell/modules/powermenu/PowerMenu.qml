import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../services" as Services
import "../../" as Root

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    visible: Services.PowerMenu.visible

    Item {
        anchors.fill: parent

        // Dim background
        Rectangle {
            anchors.fill: parent
            color: "#88000000"
            opacity: Services.PowerMenu.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            MouseArea {
                anchors.fill: parent
                onClicked: Services.PowerMenu.close()
            }
        }

        // Menu
        Rectangle {
            anchors.centerIn: parent
            width: 320
            height: menuContent.implicitHeight + 32
            radius: 20
            color: Root.Theme.pillBg

            opacity: Services.PowerMenu.visible ? 1 : 0
            scale: Services.PowerMenu.visible ? 1 : 0.9

            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            ColumnLayout {
                id: menuContent
                anchors {
                    fill: parent
                    margins: 16
                }
                spacing: 8

                Text {
                    text: "Session"
                    color: Root.Theme.textMuted
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    Layout.alignment: Qt.AlignHCenter
                }

                Repeater {
                    model: [
                        { icon: "󰤄", label: "Suspend",  color: "#89b4fa", cmd: "systemctl suspend" },
                        { icon: "󰜉", label: "Reboot",   color: "#fab387", cmd: "systemctl reboot" },
                        { icon: "󰐥", label: "Shutdown", color: "#f38ba8", cmd: "systemctl poweroff" },
                        { icon: "󰍃", label: "Logout",   color: "#a6e3a1", cmd: "hyprctl dispatch exit" },
                        { icon: "󰌾", label: "Lock",     color: "#cba6f7", cmd: "bash -c 'bash ~/.config/hypr/scripts/lockscreen-weather.sh & hyprlock'" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: 12
                        color: hovered ? Root.Theme.pillBgHover : Root.Theme.pillBgActive

                        property bool hovered: false

                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors { fill: parent; margins: 14 }
                            spacing: 14

                            Text {
                                text: modelData.icon
                                color: modelData.color
                                font.pixelSize: 20
                            }

                            Text {
                                text: modelData.label
                                color: Root.Theme.textPrimary
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.hovered = true
                            onExited: parent.hovered = false
                            onClicked: {
                                Services.PowerMenu.close()
                                runner.command = ["bash", "-c", modelData.cmd]
                                runner.running = true
                            }
                        }
                    }
                }

                // Cancel
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 12
                    color: cancelHover ? Root.Theme.pillBgHover : "transparent"
                    property bool cancelHover: false

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: Root.Theme.textMuted
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.cancelHover = true
                        onExited: parent.cancelHover = false
                        onClicked: Services.PowerMenu.close()
                    }
                }
            }
        }
    }

    Process {
        id: runner
    }
}
