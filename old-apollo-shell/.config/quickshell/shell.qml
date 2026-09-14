import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "modules"
import "modules/apolloku" as Apolloku
import "services" as Services

ShellRoot {
    id: root

    property int edgeMargin: 10
    property int panelHeight: 40
    property int panelWidth: 40
    property int pillSpacing: 10
    property bool overviewVisible: false
    property bool wallpaperPickerVisible: false
    readonly property bool vert: Services.BarSettings.vertical

    IpcHandler {
        target: "overview"
        function toggle(): void { root.overviewVisible = !root.overviewVisible }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { root.wallpaperPickerVisible = !root.wallpaperPickerVisible }
    }

    QtObject {
        id: osdRelay
        signal fire(string kind, real value)
    }
    IpcHandler {
        target: "osd"
        function set(kind: string, value: real): void { osdRelay.fire(kind, value) }
    }

    Item {
        Process {
            command: ["hyprsunset", "-t", "4500"]
            running: Services.QuickToggles.nightLight
        }
    }

    Variants {
        model: Quickshell.screens
        ToastStack {}
    }

    Variants {
        model: Quickshell.screens
        WindowOverviewPanel {
            overviewVisible: root.overviewVisible
            onClose: root.overviewVisible = false
        }
    }

    Variants {
        model: Quickshell.screens
        WallpaperPopup {
            pickerVisible: root.wallpaperPickerVisible
            onClose: root.wallpaperPickerVisible = false
        }
    }

    Variants {
        model: Quickshell.screens
        QtObject {
            id: osdScope
            required property var modelData

            property string osdKind: ""
            property real osdValue: 0
            property bool osdVisible: false

            property Timer osdTimer: Timer { interval: 1300; onTriggered: osdScope.osdVisible = false }
            property Connections osdConn: Connections {
                target: osdRelay
                function onFire(kind, value) {
                    osdScope.osdKind = kind
                    osdScope.osdValue = value
                    osdScope.osdVisible = true
                    osdScope.osdTimer.restart()
                }
            }

            property var win: OSDPanel {
                modelData: osdScope.modelData
                kind: osdScope.osdKind
                value: osdScope.osdValue
                osdVisible: osdScope.osdVisible
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: root.vert
                left: Services.BarSettings.dockPosition !== "right"
                right: Services.BarSettings.dockPosition !== "left"
            }
            implicitHeight: root.vert ? 1 : (root.panelHeight + root.edgeMargin)
            implicitWidth: root.vert ? (root.panelWidth + root.edgeMargin) : 1
            color: "transparent"

            IdleInhibitor {
                window: bar
                enabled: Services.QuickToggles.caffeine
            }

            Rectangle {
                visible: Services.BarSettings.style === "classic"
                anchors.fill: parent
                color: Services.Theme.pillColor
                Behavior on color { ColorAnimation { duration: 300 } }
            }

            // Two separately-written layouts, swapped via Loader, rather
            // than one shared layout with ternary-anchors on every pill —
            // that approach (tried first) produced real overlap bugs.
            // Matches the proven pattern from Moonlit's own Bar.qml.
            Loader {
                anchors.fill: parent
                sourceComponent: root.vert ? verticalLayout : horizontalLayout
            }

            Component {
                id: horizontalLayout
                Item {
                    anchors.fill: parent

                    WorkspacesPill {
                        id: workspacesPill
                        anchors.left: parent.left
                        anchors.leftMargin: root.edgeMargin
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    WindowTitlePill {
                        anchors.left: workspacesPill.right
                        anchors.leftMargin: root.pillSpacing
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    ClockPill {
                        id: clockPill
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    TrayPill {
                        id: trayPill
                        anchors.right: parent.right
                        anchors.rightMargin: root.edgeMargin
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StatsPill {
                        id: statsPill
                        anchors.right: trayPill.left
                        anchors.rightMargin: root.pillSpacing
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Apolloku.ApollokuTrigger {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(
                            clockPill.x + clockPill.width + root.pillSpacing,
                            statsPill.x - root.pillSpacing - width
                        )
                    }
                }
            }

            Component {
                id: verticalLayout
                Item {
                    anchors.fill: parent

                    WorkspacesPill {
                        id: workspacesPillV
                        anchors.top: parent.top
                        anchors.topMargin: root.edgeMargin
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    WindowTitlePill {
                        // Narrowed to fit the vertical bar's actual width —
                        // its default 280px would overflow sideways here.
                        maxWidth: root.panelWidth + root.edgeMargin - 6
                        anchors.top: workspacesPillV.bottom
                        anchors.topMargin: root.pillSpacing
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    ClockPill {
                        id: clockPillV
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    TrayPill {
                        id: trayPillV
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: root.edgeMargin
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    // Known rough edge: StatsPill has ~10 items in one Row
                    // and isn't reflowed for narrow widths yet — it will
                    // visibly overflow sideways here. Left as-is for now
                    // rather than rebuilding its internal layout tonight.
                    StatsPill {
                        id: statsPillV
                        anchors.bottom: trayPillV.top
                        anchors.bottomMargin: root.pillSpacing
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Apolloku.ApollokuTrigger {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: Math.max(
                            clockPillV.y + clockPillV.height + root.pillSpacing,
                            statsPillV.y - root.pillSpacing - height
                        )
                    }
                }
            }
        }
    }
}
