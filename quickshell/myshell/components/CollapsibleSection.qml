import QtQuick
import QtQuick.Layouts
import "../" as Root

ColumnLayout {
    id: root
    property string title: ""
    property bool expanded: false
    spacing: 0
    Layout.fillWidth: true
    default property alias content: _inner.data

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 38
        radius: Root.Theme.pillRadius
        color: "transparent"

        RowLayout {
            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
            spacing: 8
            Text {
                text: root.title
                color: Root.Theme.textMuted
                font.pixelSize: 11; font.weight: Font.Medium
                font.letterSpacing: 0.5
                Layout.fillWidth: true
            }
            Text {
                text: root.expanded ? "󰅃" : "󰅀"
                color: Root.Theme.textMuted
                font.pixelSize: 14
            }
        }
        StateLayer {
            anchors.fill: parent
            radius: Root.Theme.pillRadius
            onClicked: root.expanded = !root.expanded
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: root.expanded ? _inner.implicitHeight + 10 : 0
        clip: true
        Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: _inner
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 6 }
            spacing: 8
            opacity: root.expanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }
}
