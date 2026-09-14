import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../services" as Services

// Mission-Control-style Alt+Tab, workspace-grouped: each grid cell is one
// workspace, showing every window inside it at its real proportional
// position/size (via lastIpcObject.at/.size — the raw hyprctl clients JSON,
// same as tiled layouts actually look on screen) rather than one cell per
// window.
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    property bool overviewVisible: false
    signal close()
    visible: overviewVisible

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    onVisibleChanged: if (visible) {
        keyHandler.forceActiveFocus()
        selectedIndex = Math.max(0, indexOfActiveWs())
    }

    property int selectedIndex: 0

    readonly property var validToplevels: Hyprland.toplevels.values.filter(t => {
        var ipc = t.lastIpcObject
        return t.workspace && t.workspace.id >= 0 && ipc && ipc.mapped !== false
    })

    // Group by workspace id, sorted ascending.
    readonly property var workspaceGroups: {
        var byWs = {}
        for (var i = 0; i < validToplevels.length; i++) {
            var t = validToplevels[i]
            var wid = t.workspace.id
            if (!byWs[wid]) byWs[wid] = []
            byWs[wid].push(t)
        }
        var ids = Object.keys(byWs).map(Number).sort((a, b) => a - b)
        return ids.map(id => ({ wsId: id, windows: byWs[id] }))
    }

    function indexOfActiveWs() {
        for (var i = 0; i < workspaceGroups.length; i++) {
            if (workspaceGroups[i].windows.some(t => t.activated)) return i
        }
        return 0
    }

    function focusWindow(toplevel) {
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${toplevel.address}" })`)
        root.close()
    }
    function focusWorkspace(wsId) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${wsId} })`)
        root.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Services.Theme.background.r, Services.Theme.background.g, Services.Theme.background.b, 0.82)
        NumberAnimation on opacity { from: 0; to: 1; duration: 180; running: true; easing.type: Easing.OutCubic }

        MouseArea { anchors.fill: parent; onClicked: root.close() }

        Column {
            anchors.centerIn: parent
            spacing: 20

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.workspaceGroups.length > 0 ? "Workspaces" : "No windows open"
                color: Services.Theme.pillAccent
                font.pixelSize: 17
                font.bold: true
                font.family: Services.Theme.fontFamily
            }

            GridView {
                id: grid
                readonly property int columns: 3
                width: columns * cellWidth
                height: Math.min(Math.ceil(root.workspaceGroups.length / columns) * cellHeight, root.height - 170)

                cellWidth: 360
                cellHeight: 270
                interactive: false
                model: root.workspaceGroups

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    property bool hov: false
                    readonly property bool selected: root.selectedIndex === index
                    readonly property bool picked: cell.hov || cell.selected
                    readonly property bool wsActive: cell.modelData.windows.some(t => t.activated)

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        anchors.margins: 12
                        radius: 16
                        color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.97)
                        border.width: cell.picked ? 2 : 1
                        border.color: cell.picked ? Services.Theme.pillAccent : Services.Theme.pillBorder
                        opacity: cell.picked ? 1.0 : 0.82
                        scale: cell.picked ? 1.0 : 0.97
                        y: cell.picked ? -4 : 0
                        Behavior on y { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 130 } }
                        Behavior on border.color { ColorAnimation { duration: 130 } }
                        clip: true

                        // Click anywhere on the card background (not on a
                        // specific window) switches to this workspace.
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: { cell.hov = true; root.selectedIndex = cell.index }
                            onExited: cell.hov = false
                            onClicked: root.focusWorkspace(cell.modelData.wsId)
                        }

                        // Mini-map area: each window rendered at its real
                        // proportional position/size within the monitor.
                        Item {
                            id: miniMap
                            anchors.fill: parent
                            anchors.margins: 9
                            anchors.bottomMargin: 32

                            Repeater {
                                model: cell.modelData.windows
                                delegate: Rectangle {
                                    id: winTile
                                    required property var modelData
                                    readonly property var ipc: modelData.lastIpcObject
                                    readonly property real sx: ipc?.at?.[0] ?? 0
                                    readonly property real sy: ipc?.at?.[1] ?? 0
                                    readonly property real sw: Math.max(1, ipc?.size?.[0] ?? root.screen.width)
                                    readonly property real sh: Math.max(1, ipc?.size?.[1] ?? root.screen.height)

                                    x: (sx / root.screen.width) * miniMap.width
                                    y: (sy / root.screen.height) * miniMap.height
                                    width: (sw / root.screen.width) * miniMap.width
                                    height: (sh / root.screen.height) * miniMap.height
                                    radius: 6
                                    color: Services.Theme.background
                                    border.width: 1
                                    border.color: Services.Theme.pillBorder
                                    clip: true

                                    ScreencopyView {
                                        anchors.fill: parent
                                        captureSource: winTile.modelData.wayland
                                        live: root.visible
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => { root.focusWindow(winTile.modelData); mouse.accepted = true }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            anchors { top: parent.top; left: parent.left; margins: 9 }
                            width: wsLabel.implicitWidth + 10
                            height: 18
                            radius: 6
                            color: Qt.rgba(Services.Theme.background.r, Services.Theme.background.g, Services.Theme.background.b, 0.85)
                            Text {
                                id: wsLabel
                                anchors.centerIn: parent
                                text: cell.modelData.wsId + (cell.modelData.windows.length > 1 ? " \u00b7 " + cell.modelData.windows.length : "")
                                color: Services.Theme.foreground
                                opacity: 0.7
                                font.pixelSize: 10
                                font.family: Services.Theme.fontFamily
                            }
                        }

                        Rectangle {
                            visible: cell.wsActive
                            anchors { top: parent.top; right: parent.right; margins: 12 }
                            width: 7; height: 7; radius: 3.5
                            color: Services.Theme.pillAccent
                        }

                        Rectangle {
                            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                            height: 26
                            color: Qt.rgba(Services.Theme.background.r, Services.Theme.background.g, Services.Theme.background.b, 0.85)
                            Text {
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 8 }
                                text: {
                                    var active = cell.modelData.windows.find(t => t.activated) || cell.modelData.windows[0]
                                    return active ? active.title : ""
                                }
                                color: Services.Theme.foreground
                                opacity: 0.8
                                font.pixelSize: 11
                                font.family: Services.Theme.fontFamily
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "esc to cancel  \u00b7  click a window to switch  \u00b7  click empty space for the workspace"
                color: Services.Theme.foreground
                opacity: 0.5
                font.pixelSize: 11
                font.family: Services.Theme.fontFamily
            }
        }
    }

    Item {
        id: keyHandler
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: ev => {
            var cols = grid.columns
            var count = root.workspaceGroups.length
            switch (ev.key) {
                case Qt.Key_Escape:
                    root.close()
                    break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    if (count > 0) root.focusWorkspace(root.workspaceGroups[root.selectedIndex].wsId)
                    break
                case Qt.Key_Right:
                    if (count > 0) root.selectedIndex = (root.selectedIndex + 1) % count
                    break
                case Qt.Key_Left:
                    if (count > 0) root.selectedIndex = (root.selectedIndex - 1 + count) % count
                    break
                case Qt.Key_Down:
                    if (count > 0) root.selectedIndex = Math.min(root.selectedIndex + cols, count - 1)
                    break
                case Qt.Key_Up:
                    if (count > 0) root.selectedIndex = Math.max(root.selectedIndex - cols, 0)
                    break
                case Qt.Key_Tab:
                    if (count > 0) root.selectedIndex = (root.selectedIndex + 1) % count
                    break
            }
        }
    }
}
