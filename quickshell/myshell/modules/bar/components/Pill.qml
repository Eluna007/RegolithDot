import QtQuick
import "../../../" as Root

Rectangle {
    id: root

    property alias content: contentItem.data
    property bool hovered: mouseArea.containsMouse

    radius: Root.Theme.pillRadius
    color: hovered ? Root.Theme.pillBgHover : Root.Theme.pillBg
    width: Root.Theme.barWidth

    Behavior on color {
        ColorAnimation { duration: 200 }
    }

    Item {
        id: contentItem
        anchors {
            fill: parent
            margins: Root.Theme.pillPadding
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        onClicked: mouse => mouse.accepted = false
        onPressed: mouse => mouse.accepted = false
        onReleased: mouse => mouse.accepted = false
    }
}
