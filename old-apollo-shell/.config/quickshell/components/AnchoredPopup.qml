import Quickshell
import QtQuick
import "../services" as Services

// A popup that visually "grows" out of whatever bar item anchors it.
// Also grabs keyboard focus while open and re-emits raw key events via
// keyPressed, so any popup built on this can add shortcuts (e.g. the power
// menu's L/E/S/R/P) without each one reinventing focus handling.
PopupWindow {
    id: popup
    default property alias content: inner.children
    property int contentWidth: 260
    signal keyPressed(var event)

    implicitWidth: contentWidth
    implicitHeight: bg.implicitHeight
    color: "transparent"
    visible: false

    onVisibleChanged: if (visible) Qt.callLater(function() { keyCatcher.forceActiveFocus() })

    Rectangle {
        id: bg
        anchors.fill: parent
        implicitHeight: inner.implicitHeight + 24
        radius: 16
        color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.97)
        border.width: 1
        border.color: Services.Theme.pillBorder

        transformOrigin: Item.Top
        scale: popup.visible ? 1 : 0.85
        opacity: popup.visible ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Item {
            id: keyCatcher
            anchors.fill: parent
            focus: true
            Keys.onPressed: function(event) { popup.keyPressed(event) }
        }

        Column {
            id: inner
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
            spacing: 8
        }
    }
}
