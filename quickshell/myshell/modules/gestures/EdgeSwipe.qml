pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services" as Services

// Invisible edge strips that detect touch/mouse swipes to open panels.
// Left edge  → swipe right → Notification Panel
// Right edge → swipe left  → Quick Controls
// Bottom edge → swipe up   → Dashboard

Variants {
    model: Quickshell.screens

    Item {
        required property ShellScreen modelData

        // Left edge strip
        PanelWindow {
            id: leftStrip
            screen: parent.modelData

            anchors { top: true; left: true; bottom: true }
            implicitWidth: 20
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            visible: !Services.NotifPanel.visible

            Item {
                anchors.fill: parent
                DragHandler {
                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onActiveChanged: {
                        if (!active && translation.x > 40)
                            Services.NotifPanel.open()
                    }
                }
            }
        }

        // Right edge strip
        PanelWindow {
            id: rightStrip
            screen: parent.modelData

            anchors { top: true; right: true; bottom: true }
            implicitWidth: 20
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            visible: !Services.QuickControls.visible

            Item {
                anchors.fill: parent
                DragHandler {
                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onActiveChanged: {
                        if (!active && translation.x < -40)
                            Services.QuickControls.open()
                    }
                }
            }
        }

        // Bottom edge strip
        PanelWindow {
            id: bottomStrip
            screen: parent.modelData

            anchors { left: true; right: true; bottom: true }
            implicitHeight: 20
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            visible: !Services.Dashboard.visible

            Item {
                anchors.fill: parent
                DragHandler {
                    target: null
                    yAxis.enabled: true
                    xAxis.enabled: false
                    onActiveChanged: {
                        if (!active && translation.y < -40)
                            Services.Dashboard.open()
                    }
                }
            }
        }
    }
}
