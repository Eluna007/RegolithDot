import QtQuick
import Quickshell

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property ShellScreen modelData

        Component.onCompleted: screen = modelData

        anchors {
            left: true
            top: true
            bottom: true
        }

        implicitWidth: 36
        color: "transparent"
        exclusiveZone: 36

        Bar {
            screen: win.modelData
        }
    }
}
