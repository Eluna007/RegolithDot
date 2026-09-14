import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../services" as Services

// Lays out horizontally on a top bar, vertically on a left/right one —
// same axis-swap pattern as Moonlit's own Workspaces.qml: Grid's
// rows/columns swap, and each dot's "grow along the primary axis when
// active" effect swaps which dimension it grows.
Item {
    id: root

    readonly property bool vertical: Services.BarSettings.vertical
    readonly property int focusedId: Hyprland.focusedWorkspace?.id ?? 1
    readonly property int maxId: Math.max(Services.Theme.workspaceCount, focusedId)

    function isOccupied(id) {
        for (var i = 0; i < Hyprland.workspaces.values.length; i++) {
            if ((Hyprland.workspaces.values[i]?.id ?? 0) === id) return true
        }
        return false
    }

    implicitWidth: pill.implicitWidth
    implicitHeight: pill.implicitHeight

    Rectangle {
        id: pill
        anchors.centerIn: parent
        implicitWidth: root.vertical ? 28 : (wsGrid.implicitWidth + 18)
        implicitHeight: root.vertical ? (wsGrid.implicitHeight + 18) : 28
        radius: 999
        color: Services.Theme.pillColor
        border.width: 1
        border.color: Services.Theme.pillBorder

        Grid {
            id: wsGrid
            anchors.centerIn: parent
            rows: root.vertical ? root.maxId : 1
            columns: root.vertical ? 1 : root.maxId
            columnSpacing: 5
            rowSpacing: 5

            Repeater {
                model: root.maxId
                delegate: Item {
                    id: dot
                    required property int index
                    readonly property int wsId: index + 1
                    readonly property bool active: wsId === root.focusedId
                    readonly property bool occupied: root.isOccupied(wsId)

                    implicitWidth: root.vertical ? 28 : (active ? 26 : 10)
                    implicitHeight: root.vertical ? (active ? 26 : 10) : 28

                    Behavior on implicitWidth {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on implicitHeight {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.vertical ? 9 : (dot.active ? 26 : 9)
                        height: root.vertical ? (dot.active ? 26 : 9) : 9
                        radius: 999
                        color: dot.active
                               ? Services.Theme.pillAccent
                               : dot.occupied
                                 ? Services.Theme.pillSecondary
                                 : Qt.rgba(Services.Theme.foreground.r, Services.Theme.foreground.g, Services.Theme.foreground.b, 0.25)
                        opacity: dot.active ? 1 : dot.occupied ? 1 : 0.45

                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${dot.wsId} })`)
                    }
                }
            }
        }
    }
}
