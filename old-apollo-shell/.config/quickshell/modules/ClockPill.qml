import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../components" as Components
import "../services" as Services

Components.Pill {
    id: root

    property bool grabActive: false
    property double lastDismiss: 0
    readonly property bool vertical: Services.BarSettings.vertical
    readonly property color tint: (ma.containsMouse || calPopup.visible) ? Services.Theme.pillAccent : Services.Theme.foreground

    Item {
        id: content
        implicitWidth: root.vertical ? timeLine.implicitWidth : clock.implicitWidth
        implicitHeight: root.vertical ? (timeLine.implicitHeight + dateLine.implicitHeight + 2) : clock.implicitHeight

        // Horizontal (top bar): one line, full date + time.
        Text {
            id: clock
            visible: !root.vertical
            color: root.tint
            font.pixelSize: 13
            font.family: Services.Theme.fontFamily
            text: Qt.formatDateTime(new Date(), "ddd d MMM  \u2022  HH:mm")
        }

        // Vertical (left/right bar): stacked, narrow — time on top,
        // short date below. Column, not Row, so it stays narrow.
        Column {
            visible: root.vertical
            anchors.centerIn: parent
            spacing: 2
            Text {
                id: timeLine
                anchors.horizontalCenter: parent.horizontalCenter
                color: root.tint
                font.pixelSize: 13
                font.family: Services.Theme.fontFamily
                text: Qt.formatDateTime(new Date(), "HH:mm")
            }
            Text {
                id: dateLine
                anchors.horizontalCenter: parent.horizontalCenter
                color: root.tint
                opacity: 0.7
                font.pixelSize: 10
                font.family: Services.Theme.fontFamily
                text: Qt.formatDateTime(new Date(), "d MMM")
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                clock.text = Qt.formatDateTime(new Date(), "ddd d MMM  \u2022  HH:mm")
                timeLine.text = Qt.formatDateTime(new Date(), "HH:mm")
                dateLine.text = Qt.formatDateTime(new Date(), "d MMM")
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (calPopup.visible || Date.now() - root.lastDismiss < 250) {
                    calPopup.visible = false
                    root.grabActive = false
                    root.lastDismiss = Date.now()
                } else {
                    calPopup.anchor.item = root
                    calPopup.visible = true
                    grabDelay.restart()
                }
            }
        }
    }

    Item {
        Timer { id: grabDelay; interval: 90; onTriggered: root.grabActive = true }

        CalendarPopup {
            id: calPopup
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom | Edges.Left
        }
        HyprlandFocusGrab {
            windows: [calPopup]
            active: root.grabActive && calPopup.visible
            onCleared: { calPopup.visible = false; root.grabActive = false; root.lastDismiss = Date.now() }
        }
    }
}
