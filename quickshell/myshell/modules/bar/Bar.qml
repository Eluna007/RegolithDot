pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "components"
import "../../" as Root
import "../../services" as Services

Item {
    id: root

    required property ShellScreen screen

    anchors {
        fill: parent
        leftMargin: Root.Theme.barGap
        topMargin: Root.Theme.barGap
        bottomMargin: Root.Theme.barGap
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Root.Theme.pillSpacing

        // Launcher pill
        Pill {
            Layout.fillWidth: true
            implicitHeight: 42

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6

                OsIcon {}
            }
        }

        // Workspaces pill
        Pill {
            Layout.fillWidth: true
            implicitHeight: workspacesContent.implicitHeight + 16

            ColumnLayout {
                id: workspacesContent
                anchors.centerIn: parent
                spacing: 4
                Workspaces {}
            }
        }

        // Small spacer
        Item { Layout.fillHeight: true; Layout.maximumHeight: 40 }

        // Active window pill
        Rectangle {
            id: activeWindowPill
            Layout.fillWidth: true
            readonly property int charHeight: 8
            readonly property int minHeight: 40
            readonly property int maxHeight: 200
            implicitHeight: Math.min(maxHeight, Math.max(minHeight,
                Services.Hypr.activeWindowTitle.length * charHeight))
            Layout.preferredHeight: implicitHeight

            Behavior on implicitHeight {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            radius: Root.Theme.pillRadius
            color: Root.Theme.pillBg
            clip: true

            Text {
                x: (parent.width - height) / 2
                y: (parent.height + width) / 2
                text: Services.Hypr.activeWindowTitle
                color: "white"
                font.pixelSize: 11
                elide: Text.ElideRight
                width: activeWindowPill.height - 16
                rotation: -90
                transformOrigin: Item.TopLeft
            }
        }

        // Clock pill
        Pill {
            Layout.fillWidth: true
            implicitHeight: 70

            Clock {
                anchors.centerIn: parent
            }
        }

        // Fill remaining space
        Item { Layout.fillHeight: true }

        // Status pill
        Pill {
            Layout.fillWidth: true
            implicitHeight: statusContent.implicitHeight + 20

            ColumnLayout {
                id: statusContent
                anchors.centerIn: parent
                spacing: 6

                NotifIndicator {}
                Tray {}
                StatusIcons {}
            }
        }
    }
}
