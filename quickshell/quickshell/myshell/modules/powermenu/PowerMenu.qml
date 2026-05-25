import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../services" as Services
import "../../" as Root

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: Services.PowerMenu.visible
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    visible: Services.PowerMenu.visible

    function triggerAction(cmd) {
        Services.PowerMenu.close()
        runner.command = ["bash", "-c", cmd]
        runner.running = true
    }

    Item {
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
                case Qt.Key_Escape: Services.PowerMenu.close();                                                                    event.accepted = true; break
                case Qt.Key_L:      root.triggerAction("bash -c 'bash ~/.config/hypr/scripts/lockscreen-weather.sh & hyprlock'"); event.accepted = true; break
                case Qt.Key_E:      root.triggerAction("hyprctl dispatch exit");  event.accepted = true; break
                case Qt.Key_S:      root.triggerAction("systemctl suspend");       event.accepted = true; break
                case Qt.Key_R:      root.triggerAction("systemctl reboot");        event.accepted = true; break
                case Qt.Key_P:      root.triggerAction("systemctl poweroff");      event.accepted = true; break
                case Qt.Key_H:      root.triggerAction("systemctl hibernate");     event.accepted = true; break
            }
        }

        // Dim backdrop
        Rectangle {
            anchors.fill: parent
            color: "#aa000000"
            opacity: Services.PowerMenu.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
            MouseArea {
                anchors.fill: parent
                onClicked: Services.PowerMenu.close()
            }
        }

        // Panel
        Rectangle {
            id: menu
            anchors.centerIn: parent
            width: 300
            height: menuCol.implicitHeight + 40
            radius: 24
            color: Root.Theme.pillBg

            opacity: Services.PowerMenu.visible ? 1 : 0
            scale:   Services.PowerMenu.visible ? 1 : 0.88
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: menuCol
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 20 }
                spacing: 16

                Item { height: 4 }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Services.Time.hourStr + ":" + Services.Time.minuteStr
                    color: Root.Theme.textPrimary
                    font.pixelSize: 40
                    font.weight: Font.Light
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(new Date(), "dddd, MMMM d yyyy")
                    color: Root.Theme.textMuted
                    font.pixelSize: 11
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Root.Theme.pillBgHover
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 12
                    columnSpacing: 12

                    Repeater {
                        model: [
                            { icon: "󰌾", label: "Lock",      key: "l", cmd: "bash -c 'bash ~/.config/hypr/scripts/lockscreen-weather.sh & hyprlock'" },
                            { icon: "󰍃", label: "Logout",    key: "e", cmd: "hyprctl dispatch exit" },
                            { icon: "󰒲", label: "Sleep",     key: "s", cmd: "systemctl suspend" },
                            { icon: "󰑐", label: "Restart",   key: "r", cmd: "systemctl reboot" },
                            { icon: "󰐥", label: "Shutdown",  key: "p", cmd: "systemctl poweroff" },
                            { icon: "󰏸", label: "Hibernate", key: "h", cmd: "systemctl hibernate" }
                        ]

                        delegate: ColumnLayout {
                            id: btn
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 6
                            Layout.alignment: Qt.AlignHCenter

                            property bool hovered: false

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 64; height: 64; radius: 32
                                color: btn.hovered ? Root.Theme.pillBgActive : Root.Theme.pillBgHover
                                scale: btn.hovered ? 1.08 : 1.0
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                                Text {
                                    anchors.centerIn: parent
                                    text: btn.modelData.icon
                                    color: btn.hovered ? Root.Theme.textAccent : Root.Theme.textPrimary
                                    font.pixelSize: 24
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: btn.hovered = true
                                    onExited:  btn.hovered = false
                                    onClicked: root.triggerAction(btn.modelData.cmd)
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: btn.modelData.label
                                color: btn.hovered ? Root.Theme.textAccent : Root.Theme.textPrimary
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: btn.modelData.key
                                color: Root.Theme.textMuted
                                font.pixelSize: 9
                            }
                        }
                    }
                }

                Item { height: 4 }
            }
        }
    }

    Process { id: runner }
}
