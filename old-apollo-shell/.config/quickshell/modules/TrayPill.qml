import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "../components" as Components
import "../services" as Services
import "." as Modules

Components.Pill {
    id: root
    property int iconSize: 18
    readonly property bool vertical: Services.BarSettings.vertical

    // Grid (not Row) so rows/columns can swap by orientation — same
    // technique WorkspacesPill uses, and for the same reason: Grid's
    // direct children never carry anchors themselves (that restriction
    // is what broke the earlier Flow-based attempt), only the content
    // one level inside each delegate does.
    Grid {
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        rowSpacing: 6
        columnSpacing: 6

        Repeater {
            id: trayRepeater
            model: SystemTray.items

            delegate: Item {
                id: entry
                required property var modelData

                implicitWidth: root.iconSize + 10
                implicitHeight: root.iconSize + 10

                property double lastDismiss: 0
                property bool grabActive: false

                function closeMenu() {
                    trayMenu.visible = false
                    entry.grabActive = false
                    entry.lastDismiss = Date.now()
                }

                Timer { id: grabDelay; interval: 90; onTriggered: entry.grabActive = true }

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: (hov.containsMouse || trayMenu.visible) ? Services.Theme.hoverBg : "transparent"
                    Behavior on color { ColorAnimation { duration: 140 } }
                }

                IconImage {
                    anchors.centerIn: parent
                    asynchronous: true
                    implicitSize: root.iconSize
                    source: entry.modelData.icon
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !parent.children[1].visible
                    text: ""
                    color: Services.Theme.foreground
                    opacity: 0.7
                    font.pixelSize: root.iconSize - 2
                }

                MouseArea {
                    id: hov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            entry.modelData.activate()
                            return
                        }
                        if (trayMenu.visible || Date.now() - entry.lastDismiss < 250) {
                            entry.closeMenu()
                            return
                        }
                        if (entry.modelData.hasMenu) {
                            trayMenu.visible = true
                            grabDelay.restart()
                        } else {
                            entry.modelData.activate()
                        }
                    }
                }

                Modules.TrayMenu {
                    id: trayMenu
                    handle: entry.modelData.menu
                    anchor.item: entry
                    anchor.edges: Edges.Bottom
                    anchor.gravity: Edges.Bottom | Edges.Left
                    onCloseAll: entry.closeMenu()
                }

                HyprlandFocusGrab {
                    windows: [trayMenu]
                    active: entry.grabActive && trayMenu.visible
                    onCleared: entry.closeMenu()
                }
            }
        }

        Text {
            visible: trayRepeater.count === 0
            text: "Tray"
            color: Services.Theme.foreground
            opacity: 0.5
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
        }
    }
}
