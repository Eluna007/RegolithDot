import QtQuick
import Quickshell
import "../components" as Components
import "../services" as Services

Components.AnchoredPopup {
    id: popup
    contentWidth: 300

    function run(cmd) {
        Quickshell.execDetached(cmd)
        popup.visible = false
    }

    onKeyPressed: event => {
        switch (event.key) {
            case Qt.Key_Escape: popup.visible = false; break
            case Qt.Key_L: popup.run(["hyprlock"]); break
            case Qt.Key_E: popup.run(["hyprctl", "dispatch", "hl.dsp.exit()"]); break
            case Qt.Key_S: popup.run(["systemctl", "suspend"]); break
            case Qt.Key_R: popup.run(["systemctl", "reboot"]); break
            case Qt.Key_P: popup.run(["systemctl", "poweroff"]); break
        }
    }

    Text {
        text: "Power"
        color: Services.Theme.foreground
        opacity: 0.7
        font.pixelSize: Services.Theme.fontSizeSmall
        font.family: Services.Theme.fontFamily
    }

    Row {
        width: parent.width
        spacing: 6
        readonly property real bw: (width - spacing * 4) / 5

        Repeater {
            model: [
                { label: "Lock",     icon: String.fromCodePoint(0xf033e), danger: false, cmd: ["hyprlock"], key: "L" },
                { label: "Logout",   icon: String.fromCodePoint(0xf0343), danger: false, cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"], key: "E" },
                { label: "Sleep",    icon: String.fromCodePoint(0xf0332), danger: false, cmd: ["systemctl", "suspend"], key: "S" },
                { label: "Reboot",   icon: String.fromCodePoint(0xf0709), danger: true,  cmd: ["systemctl", "reboot"], key: "R" },
                { label: "Shutdown", icon: String.fromCodePoint(0xf0425), danger: true,  cmd: ["systemctl", "poweroff"], key: "P" }
            ]

            delegate: Rectangle {
                id: btn
                required property var modelData
                width: parent.bw
                height: 68
                radius: 12
                color: pwMa.containsMouse ? Services.Theme.hoverBg : Services.Theme.pillColor
                border.width: 1
                border.color: pwMa.containsMouse
                    ? (btn.modelData.danger ? Services.Theme.errorColor : Services.Theme.pillAccent)
                    : Services.Theme.pillBorder
                Behavior on border.color { ColorAnimation { duration: 140 } }

                // Small key-hint chip, matching Moonlit's visual cue that
                // the popup is keyboard-navigable.
                Rectangle {
                    anchors { top: parent.top; right: parent.right; margins: 6 }
                    width: 14; height: 14; radius: 4
                    color: Services.Theme.pillColor
                    border.width: 1
                    border.color: Services.Theme.pillBorder
                    Text {
                        anchors.centerIn: parent
                        text: btn.modelData.key
                        color: Services.Theme.foreground
                        opacity: 0.6
                        font.pixelSize: Services.Theme.fontSizeSmall - 4
                        font.family: Services.Theme.fontFamily
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: btn.modelData.icon
                        color: btn.modelData.danger ? Services.Theme.errorColor : Services.Theme.foreground
                        font.pixelSize: 20
                        font.family: Services.Theme.fontFamily
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: btn.modelData.label
                        color: Services.Theme.foreground
                        opacity: 0.75
                        font.pixelSize: Services.Theme.fontSizeSmall - 3
                        font.family: Services.Theme.fontFamily
                    }
                }

                MouseArea {
                    id: pwMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: popup.run(btn.modelData.cmd)
                }
            }
        }
    }
}
