import QtQuick
import Quickshell
import "../services" as Services

PanelWindow {
    id: root
    required property var modelData
    screen: modelData

    anchors { top: true; right: true }
    margins { top: 60; right: 10 }
    exclusiveZone: 0
    implicitWidth: 320
    implicitHeight: Math.max(col.implicitHeight, 1)
    color: "transparent"

    Column {
        id: col
        width: parent.width
        spacing: 8

        Repeater {
            model: Services.Notifications.toasts

            delegate: Rectangle {
                id: toast
                required property var modelData
                property bool entered: false

                width: col.width
                implicitHeight: toastCol.implicitHeight + 24
                radius: 16
                color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.98)
                border.width: 1
                border.color: Services.Theme.pillBorder
                opacity: entered ? 1 : 0
                x: entered ? 0 : width + 28

                Component.onCompleted: entered = true
                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.InCubic } }
                Behavior on opacity { NumberAnimation { duration: 220 } }

                Timer {
                    interval: 5000
                    running: true
                    onTriggered: {
                        toast.entered = false
                        dismissTimer.start()
                    }
                }
                Timer { id: dismissTimer; interval: 240; onTriggered: Services.Notifications.dismissToast(toast.modelData.nid) }

                Column {
                    id: toastCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                    spacing: 4

                    Row {
                        width: parent.width
                        Text {
                            text: toast.modelData.app
                            color: Services.Theme.foreground
                            opacity: 0.6
                            font.pixelSize: Services.Theme.fontSizeSmall - 3
                            font.family: Services.Theme.fontFamily
                        }
                        Item { width: parent.width - 90; height: 1 }
                        Text {
                            text: "now"
                            color: Services.Theme.foreground
                            opacity: 0.4
                            font.pixelSize: Services.Theme.fontSizeSmall - 3
                            font.family: Services.Theme.fontFamily
                        }
                    }
                    Text {
                        text: toast.modelData.title
                        color: Services.Theme.foreground
                        font.pixelSize: Services.Theme.fontSizeSmall
                        font.family: Services.Theme.fontFamily
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        visible: toast.modelData.body !== ""
                        text: toast.modelData.body
                        color: Services.Theme.foreground
                        opacity: 0.7
                        font.pixelSize: Services.Theme.fontSizeSmall - 2
                        font.family: Services.Theme.fontFamily
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.Notifications.dismissToast(toast.modelData.nid)
                }
            }
        }
    }
}
