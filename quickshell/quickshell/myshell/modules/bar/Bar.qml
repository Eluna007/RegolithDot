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

        // Clock pill (height grows to fit time + date + weather)
        Pill {
            Layout.fillWidth: true
            implicitHeight: 88

            Clock {
                anchors.centerIn: parent
            }
        }

        // Media pill — slides in when a player is active
        Rectangle {
            id: mediaPill
            Layout.fillWidth: true
            readonly property bool active: !Services.Media.stopped
            implicitHeight: active ? 90 : 0
            Layout.preferredHeight: implicitHeight
            clip: true

            Behavior on implicitHeight {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }

            radius: Root.Theme.pillRadius
            color: Services.Media.playing ? Root.Theme.pillBgActive : Root.Theme.pillBg

            Behavior on color { ColorAnimation { duration: 300 } }

            TapHandler {
                onTapped: Services.Media.playPause()
            }

            // Play / pause icon
            Text {
                anchors.top: parent.top
                anchors.topMargin: 6
                anchors.horizontalCenter: parent.horizontalCenter
                text: Services.Media.playing ? "󰏤" : "󰐊"
                color: Root.Theme.textAccent
                font.pixelSize: 11
                opacity: mediaPill.active ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            // Artist · Title, rotated to fit the narrow bar
            Text {
                x: (parent.width - height) / 2
                y: mediaPill.height - 10
                text: (Services.Media.artist !== "" ? Services.Media.artist + " · " : "") + Services.Media.title
                color: "white"
                font.pixelSize: 9
                elide: Text.ElideRight
                width: mediaPill.implicitHeight - 26
                rotation: -90
                transformOrigin: Item.TopLeft
                opacity: mediaPill.active ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            // Progress bar
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                height: 2
                radius: 1
                color: Root.Theme.pillBgHover
                opacity: mediaPill.active ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Rectangle {
                    width: parent.width * Services.Media.progress
                    height: parent.height
                    radius: parent.radius
                    color: Root.Theme.textAccent
                    Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.Linear } }
                }
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
