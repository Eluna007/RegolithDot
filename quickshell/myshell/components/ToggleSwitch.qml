import QtQuick
import "../" as Root

Item {
    id: root
    property bool checked: false
    property color activeColor: Root.Theme.textAccent
    signal toggled(bool value)

    implicitWidth: 46
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.activeColor : Qt.rgba(1,1,1,0.15)
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    Rectangle {
        id: _thumb
        width: _ma.pressed ? 22 : 18
        height: width; radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3
        color: "white"
        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: _ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { root.checked = !root.checked; root.toggled(root.checked) }
    }
}
