pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services" as Services

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: vizWin
        required property ShellScreen modelData
        screen: modelData

        anchors { left: true; right: true; bottom: true }
        implicitHeight: 80
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        readonly property bool active: {
            const b = Services.CavaAudio.bars
            return b.some(v => v > 0)
        }

        opacity: active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

        Row {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.height
            spacing: 2
            anchors.leftMargin: 48  // leave space for the sidebar bar

            Repeater {
                model: Services.CavaAudio.bars

                Rectangle {
                    required property real modelData
                    required property int index
                    width: (vizWin.width - 48 - (Services.CavaAudio.barCount - 1) * 2) / Services.CavaAudio.barCount
                    height: Math.max(2, (modelData / 100) * vizWin.height)
                    anchors.bottom: parent.bottom
                    radius: 2

                    readonly property real hue: index / Services.CavaAudio.barCount
                    color: Qt.rgba(
                        Services.Colors.primary.r * (1 - hue) + Services.Colors.tertiary.r * hue,
                        Services.Colors.primary.g * (1 - hue) + Services.Colors.tertiary.g * hue,
                        Services.Colors.primary.b * (1 - hue) + Services.Colors.tertiary.b * hue,
                        0.7
                    )

                    Behavior on height { NumberAnimation { duration: 60 } }
                }
            }
        }
    }
}
