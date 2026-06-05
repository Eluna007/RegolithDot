import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "."

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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Shortcut {
        sequence: "Escape"
        onActivated: Qt.quit()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Qt.quit()
    }
    WallpaperPicker {
        x: (parent.width - width) / 2 + 22
        anchors.verticalCenter: parent.verticalCenter
        width: 1460
        height: 288
        focus: true
    }
}
