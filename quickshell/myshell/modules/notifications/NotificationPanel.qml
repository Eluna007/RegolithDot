import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../services" as Services
import "../../" as Root
import "../../components"

PanelWindow {
    id: npWin

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property bool panelOpen: false
    visible: false

    Connections {
        target: Services.NotifPanel
        function onVisibleChanged() {
            if (Services.NotifPanel.visible) {
                npWin.visible = true
                npWin.panelOpen = true
            } else {
                npWin.panelOpen = false
                _closeDelay.start()
            }
        }
    }
    Timer { id: _closeDelay; interval: 300; onTriggered: npWin.visible = false }

    Item {
        anchors.fill: parent

        Rectangle {
            anchors { fill: parent; leftMargin: 320 }
            color: "#66000000"
            opacity: npWin.panelOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
            MouseArea { anchors.fill: parent; onClicked: Services.NotifPanel.close() }
        }

        Rectangle {
            id: _panel
            width: 320
            anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
            color: Root.Theme.pillBg

            opacity: npWin.panelOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
            transform: Translate {
                x: npWin.panelOpen ? 0 : -340
                Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            }

            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Notifications"
                        color: Root.Theme.textPrimary
                        font.pixelSize: 14; font.weight: Font.SemiBold
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: _clearHov ? Root.Theme.pillBgActive : Root.Theme.pillBgHover
                        property bool _clearHov: false
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text { anchors.centerIn: parent; text: "󰆴"; color: Root.Theme.textMuted; font.pixelSize: 12 }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onEntered: parent._clearHov = true; onExited: parent._clearHov = false
                            onClicked: Services.NotificationService.dismissAll()
                        }
                    }
                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: _xHov ? Root.Theme.pillBgActive : Root.Theme.pillBgHover
                        property bool _xHov: false
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text { anchors.centerIn: parent; text: "󰅖"; color: Root.Theme.textMuted; font.pixelSize: 13 }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true
                            onEntered: parent._xHov = true; onExited: parent._xHov = false
                            onClicked: Services.NotifPanel.close()
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true

                    // Empty state
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: Services.NotificationService.count === 0
                        Text { Layout.alignment: Qt.AlignHCenter; text: "󰂜"; color: Root.Theme.textMuted; font.pixelSize: 40 }
                        Text { Layout.alignment: Qt.AlignHCenter; text: "No notifications"; color: Root.Theme.textMuted; font.pixelSize: 12 }
                    }

                    // Notification list
                    Flickable {
                        anchors.fill: parent
                        contentHeight: _notifCol.implicitHeight
                        clip: true
                        visible: Services.NotificationService.count > 0

                        ColumnLayout {
                            id: _notifCol
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: Services.NotificationService.notifications
                                delegate: NotifItem {}
                            }
                        }
                    }
                }
            }
        }
    }
}
