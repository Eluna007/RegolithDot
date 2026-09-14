import Quickshell
import Quickshell.Widgets
import QtQuick
import "../services" as Services

// Popup rendering a tray item's DBus menu. Submenus drill down in-place
// (with a Back row) rather than recursively instantiating popups.
PopupWindow {
    id: pop
    required property var handle
    signal closeAll()

    property var stack: []
    property var current: handle
    function enter(h) { stack = stack.concat([h]); current = h }
    function back()    { stack = stack.slice(0, -1); current = stack.length ? stack[stack.length - 1] : pop.handle }
    function reset()   { stack = []; current = pop.handle }
    onVisibleChanged: if (!visible) reset()

    QsMenuOpener { id: opener; menu: pop.current }

    implicitWidth: 240
    implicitHeight: bg.implicitHeight
    color: "transparent"

    Rectangle {
        id: bg
        anchors.fill: parent
        implicitHeight: col.implicitHeight + 12
        radius: 14
        color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.97)
        border.width: 1
        border.color: Services.Theme.pillBorder

        Column {
            id: col
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 6 }
            spacing: 1

            Rectangle {
                visible: pop.stack.length > 0
                width: col.width; height: 30; radius: 8
                color: backMa.containsMouse ? Services.Theme.hoverBg : "transparent"
                Row {
                    anchors.fill: parent; anchors.leftMargin: 10; spacing: 9
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        color: Services.Theme.accent
                        font.pixelSize: 14
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Back"
                        color: Services.Theme.foreground
                        opacity: 0.75
                        font.pixelSize: Services.Theme.fontSizeSmall
                    }
                }
                MouseArea {
                    id: backMa
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pop.back()
                }
            }

            Repeater {
                model: opener.children

                delegate: Item {
                    id: entryItem
                    required property var modelData
                    width: col.width
                    height: modelData.isSeparator ? 9 : 32

                    Rectangle {
                        visible: entryItem.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 14; height: 1
                        color: Services.Theme.pillBorder
                    }

                    Rectangle {
                        visible: !entryItem.modelData.isSeparator
                        anchors.fill: parent
                        radius: 8
                        color: ma.containsMouse && entryItem.modelData.enabled
                               ? Services.Theme.hoverBg : "transparent"

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 9

                            Item {
                                width: 16; height: parent.height
                                Text {
                                    anchors.centerIn: parent
                                    visible: entryItem.modelData.buttonType !== 0
                                    text: entryItem.modelData.checkState !== 0 ? "✓" : "○"
                                    color: Services.Theme.accent
                                    font.pixelSize: 12
                                }
                                IconImage {
                                    anchors.centerIn: parent
                                    visible: entryItem.modelData.buttonType === 0 && entryItem.modelData.icon !== ""
                                    implicitSize: 16
                                    source: entryItem.modelData.icon
                                }
                            }

                            Text {
                                width: parent.width - 16 - 9 - (entryItem.modelData.hasChildren ? 18 : 0)
                                anchors.verticalCenter: parent.verticalCenter
                                text: (entryItem.modelData.text || "").replace(/_(.)/g, "$1")
                                color: entryItem.modelData.enabled ? Services.Theme.foreground : Qt.rgba(Services.Theme.foreground.r, Services.Theme.foreground.g, Services.Theme.foreground.b, 0.4)
                                font.pixelSize: Services.Theme.fontSizeSmall
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: entryItem.modelData.hasChildren
                                anchors.verticalCenter: parent.verticalCenter
                                text: ""
                                color: Services.Theme.foreground
                                opacity: 0.6
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entryItem.modelData.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entryItem.modelData.hasChildren) {
                                    pop.enter(entryItem.modelData)
                                } else {
                                    entryItem.modelData.triggered()
                                    pop.closeAll()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
