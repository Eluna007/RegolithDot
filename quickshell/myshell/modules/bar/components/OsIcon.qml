import QtQuick
import "../../../services" as Services

Item {
    implicitWidth: 28
    implicitHeight: 28

    Rectangle {
        id: glow
        anchors.centerIn: parent
        width: 32
        height: 32
        radius: 16
        color: Services.PowerMenu.visible ? "#44ffffff" : "transparent"
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    AnimatedImage {
        id: icon
        anchors.centerIn: parent
        width: 26
        height: 26
        source: "file:///home/edgarlr/.config/quickshell/myshell/assets/osicon.gif"
        fillMode: Image.PreserveAspectCrop
        playing: true
        smooth: true

        layer.enabled: true
        layer.effect: null

        scale: hoverArea.containsMouse ? 1.15 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.width / 2
            color: "transparent"
            border.color: hoverArea.containsMouse ? "#88ffffff" : "transparent"
            border.width: 2
            Behavior on border.color { ColorAnimation { duration: 150 } }
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Services.PowerMenu.toggle()
    }
}
