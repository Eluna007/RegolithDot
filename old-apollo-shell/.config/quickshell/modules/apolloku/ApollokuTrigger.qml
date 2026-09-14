import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../components" as Components
import "../../services" as Services
import "Model.js" as Model

Components.Pill {
    id: root

    property bool grabActive: false
    property double lastDismiss: 0
    readonly property bool vertical: Services.BarSettings.vertical
    readonly property color tint: (ma.containsMouse || panel.visible) ? Services.Theme.pillAccent : Services.Theme.foreground

    Item {
        id: content
        implicitWidth: contentGrid.implicitWidth
        implicitHeight: contentGrid.implicitHeight

        // Grid, not Row — its direct children (gridIcon, the Text below)
        // can't carry their own anchors, same restriction/fix as
        // TrayPill and WorkspacesPill.
        Grid {
            id: contentGrid
            anchors.centerIn: parent
            rows: root.vertical ? -1 : 1
            columns: root.vertical ? 1 : -1
            rowSpacing: 8
            columnSpacing: 8

            Item {
                id: gridIcon
                width: 18
                height: 18

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: root.tint
                }
                Rectangle { width: 1; height: 18; x: 6;  color: root.tint; opacity: 0.8 }
                Rectangle { width: 1; height: 18; x: 12; color: root.tint; opacity: 0.8 }
                Rectangle { height: 1; width: 18; y: 6;  color: root.tint; opacity: 0.8 }
                Rectangle { height: 1; width: 18; y: 12; color: root.tint; opacity: 0.8 }
            }

            Text {
                visible: panel.started
                text: (panel.paused ? "\u23f8 " : "") + Model.formatTime(panel.elapsedMs)
                color: Services.Theme.foreground
                opacity: 0.7
                font.pixelSize: Services.Theme.fontSizeSmall
                font.family: Services.Theme.fontFamily
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    panel.togglePause()
                    return
                }
                if (panel.visible || Date.now() - root.lastDismiss < 250) {
                    panel.close()
                    root.grabActive = false
                    root.lastDismiss = Date.now()
                } else {
                    panel.anchor.item = root
                    panel.open()
                    grabDelay.restart()
                }
            }
        }
    }

    Item {
        Timer { id: grabDelay; interval: 90; onTriggered: root.grabActive = true }

        ApollokuPanel {
            id: panel
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom | Edges.Left
        }
        HyprlandFocusGrab {
            windows: [panel]
            active: root.grabActive && panel.visible
            onCleared: {
                panel.close()
                root.grabActive = false
                root.lastDismiss = Date.now()
            }
        }
    }
}
