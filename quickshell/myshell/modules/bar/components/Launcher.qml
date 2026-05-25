import QtQuick
import Quickshell.Io

Text {
    text: "󰍜"
    color: "#88ffffff"
    font.pixelSize: 16

    MouseArea {
        anchors.fill: parent
        onClicked: launcher.running = true
    }

    Process {
        id: launcher
        command: ["rofi", "-show", "drun"]
    }
}
