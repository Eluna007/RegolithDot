import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import "../../" as Root
import "../../components"
import "../../services" as Services

Rectangle {
    id: root

    required property var modelData
    required property int index

    Layout.fillWidth: true
    implicitHeight: _col.implicitHeight + 20
    radius: 14
    color: modelData.urgency === NotificationUrgency.Critical
        ? Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.25)
        : Root.Theme.pillBgHover

    property real _slideX: 0

    Behavior on _slideX { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    transform: Translate { x: root._slideX }

    ColumnLayout {
        id: _col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: modelData.urgency === NotificationUrgency.Critical ? "󰀦" : "󰂞"
                color: modelData.urgency === NotificationUrgency.Critical ? "#f38ba8" : Root.Theme.textAccent
                font.pixelSize: 13
            }
            Text {
                text: modelData.appName
                color: Root.Theme.textMuted
                font.pixelSize: 11; font.weight: Font.Medium
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Text {
                text: modelData.time
                color: Root.Theme.textMuted
                font.pixelSize: 9
            }
            Rectangle {
                width: 20; height: 20; radius: 10
                color: _closeHover ? Root.Theme.pillBgActive : "transparent"
                property bool _closeHover: false
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    anchors.centerIn: parent
                    text: "󰅖"; color: Root.Theme.textMuted; font.pixelSize: 10
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: parent._closeHover = true
                    onExited:  parent._closeHover = false
                    onClicked: {
                        root._slideX = root.width + 40
                        Qt.callLater(() => Services.NotificationService.dismiss(modelData.id))
                    }
                }
            }
        }

        Text {
            text: modelData.summary
            color: Root.Theme.textPrimary
            font.pixelSize: 12; font.weight: Font.SemiBold
            Layout.fillWidth: true
            elide: Text.ElideRight
            visible: modelData.summary !== ""
        }

        Text {
            text: modelData.body
            color: Root.Theme.textMuted
            font.pixelSize: 11
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            visible: modelData.body !== ""
        }

        RowLayout {
            spacing: 6
            visible: modelData.actions && modelData.actions.length > 0
            Repeater {
                model: modelData.actions
                delegate: Rectangle {
                    required property var modelData
                    radius: 8; color: Root.Theme.pillBgActive
                    implicitWidth: _aLabel.implicitWidth + 16
                    implicitHeight: _aLabel.implicitHeight + 8
                    Text {
                        id: _aLabel
                        anchors.centerIn: parent
                        text: modelData.label ?? modelData.identifier ?? ""
                        color: Root.Theme.textAccent
                        font.pixelSize: 10
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { modelData.invoke(); Services.NotificationService.dismiss(root.modelData.id) }
                    }
                }
            }
        }
    }

    // Swipe-to-dismiss
    DragHandler {
        target: null
        xAxis.enabled: true; yAxis.enabled: false
        onActiveChanged: {
            if (!active) {
                if (translation.x < -60 || translation.x > 60)
                    Services.NotificationService.dismiss(root.modelData.id)
            }
        }
    }
}
