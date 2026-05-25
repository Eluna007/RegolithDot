import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../services" as Services

PanelWindow {
    readonly property int _brightnessInit: Services.Brightness.percent
    id: root

    anchors {
        right: true
        bottom: true
    }

    margins.right: 20
    margins.bottom: 60
    implicitWidth: 220
    implicitHeight: 60
    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Item {
        anchors.fill: parent
        opacity: Services.Osd.visible ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: "#cc3b0056"

            RowLayout {
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 10

                Text {
                    text: Services.Osd.icon
                    color: "white"
                    font.pixelSize: 20
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 6
                    radius: 3
                    color: "#44ffffff"

                    Rectangle {
                        width: parent.width * (Services.Osd.value / 100)
                        height: parent.height
                        radius: parent.radius
                        color: "white"

                        Behavior on width {
                            NumberAnimation { duration: 100 }
                        }
                    }
                }

                Text {
                    text: Math.round(Services.Osd.value) + "%"
                    color: "white"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
        }
    }
}
