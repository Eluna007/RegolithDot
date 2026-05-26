import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../services" as Services
import "../../" as Root
import "../../components"

PanelWindow {
    id: qcWin

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Keep window alive during slide-out animation
    property bool panelOpen: false
    visible: false

    // Dragging state for slider handles
    property bool volDragging: false
    property bool briDragging: false
    Timer { id: volDragTimer; interval: 500; onTriggered: qcWin.volDragging = false }
    Timer { id: briDragTimer; interval: 500; onTriggered: qcWin.briDragging = false }

    // WiFi / Bluetooth state
    property bool wifiEnabled: true
    property bool bluetoothEnabled: false

    Process { id: wifiPoller; command: ["bash", "-c", "nmcli radio wifi"]; running: true
        stdout: SplitParser { onRead: data => qcWin.wifiEnabled = data.trim() === "enabled" }
    }
    Process { id: btPoller; command: ["bash", "-c", "bluetoothctl show 2>/dev/null | grep 'Powered:' | awk '{print $2}'"]; running: true
        stdout: SplitParser { onRead: data => qcWin.bluetoothEnabled = data.trim() === "yes" }
    }
    Process { id: wifiToggleRunner }
    Process { id: btToggleRunner }

    function toggleWifi() {
        wifiEnabled = !wifiEnabled
        wifiToggleRunner.command = ["nmcli", "radio", "wifi", wifiEnabled ? "on" : "off"]
        wifiToggleRunner.running = true
    }
    function toggleBt() {
        bluetoothEnabled = !bluetoothEnabled
        btToggleRunner.command = ["bash", "-c", "bluetoothctl power " + (bluetoothEnabled ? "on" : "off")]
        btToggleRunner.running = true
    }

    Connections {
        target: Services.QuickControls
        function onVisibleChanged() {
            if (Services.QuickControls.visible) {
                qcWin.visible = true
                qcWin.panelOpen = true
                wifiPoller.running = true   // refresh state on open
                btPoller.running = true
            } else {
                qcWin.panelOpen = false
                closeDelay.start()
            }
        }
    }

    Timer { id: closeDelay; interval: 300; onTriggered: qcWin.visible = false }

    // Runners
    Process { id: volRunner }
    Process { id: briRunner }

    Timer {
        id: briDebounce
        interval: 80
        property int pending: Services.Brightness.percent
        onTriggered: {
            briRunner.command = ["brightnessctl", "-e4", "set", pending + "%"]
            briRunner.running = true
        }
    }

    function applyVolume(v) {
        volRunner.command = ["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", v + "%"]
        volRunner.running = true
    }

    Item {
        anchors.fill: parent

        // Backdrop — click outside panel to close
        Rectangle {
            anchors { fill: parent; rightMargin: 300 }
            color: "#66000000"
            opacity: qcWin.panelOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
            MouseArea {
                anchors.fill: parent
                onClicked: Services.QuickControls.close()
            }
        }

        // Side panel
        Rectangle {
            id: panel
            width: 300
            anchors { top: parent.top; right: parent.right; bottom: parent.bottom }
            color: Root.Theme.pillBg

            opacity: qcWin.panelOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }

            transform: Translate {
                x: qcWin.panelOpen ? 0 : 320
                Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            }

            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 14

                // ── Header ─────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Quick Controls"
                        color: Root.Theme.textPrimary
                        font.pixelSize: 14
                        font.weight: Font.SemiBold
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 28; height: 28; radius: 14
                        color: xHover ? Root.Theme.pillBgActive : Root.Theme.pillBgHover
                        property bool xHover: false
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: Root.Theme.textMuted
                            font.pixelSize: 13
                        }
                        StateLayer {
                            anchors.fill: parent; radius: 14
                            onClicked: Services.QuickControls.close()
                        }
                        MouseArea {
                            anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
                            onEntered: parent.xHover = true; onExited: parent.xHover = false
                        }
                    }
                }

                // ── Volume ─────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: volCard.implicitHeight + 24
                    radius: 14
                    color: Root.Theme.pillBgHover

                    ColumnLayout {
                        id: volCard
                        anchors { fill: parent; margins: 12 }
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: Services.Audio.icon
                                color: Services.Audio.muted ? "#f38ba8" : Root.Theme.textAccent
                                font.pixelSize: 16
                                MouseArea { anchors.fill: parent; onClicked: Services.Audio.toggleMute() }
                            }
                            Text { text: "Volume"; color: Root.Theme.textMuted; font.pixelSize: 12 }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Services.Audio.muted ? "Muted" : Services.Audio.percent + "%"
                                color: Services.Audio.muted ? "#f38ba8" : Root.Theme.textPrimary
                                font.pixelSize: 12; font.weight: Font.Medium
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            height: 44

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: Qt.rgba(Root.Theme.textAccent.r, Root.Theme.textAccent.g, Root.Theme.textAccent.b, 0.15)

                                // Fill bar
                                Rectangle {
                                    width: parent.width * (Services.Audio.percent / 100)
                                    height: parent.height; radius: parent.radius
                                    color: Services.Audio.muted ? "#88f38ba8" : Root.Theme.textAccent
                                    Behavior on width { NumberAnimation { duration: 80 } }
                                }

                                // Handle
                                Rectangle {
                                    id: volHandle
                                    width: 36; height: 36; radius: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.max(4, Math.min(parent.width - width - 4,
                                        parent.width * (Services.Audio.percent / 100) - width / 2))
                                    color: Qt.rgba(0, 0, 0, 0.3)
                                    Behavior on x { NumberAnimation { duration: 80 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: Services.Audio.icon
                                        color: "white"; font.pixelSize: 14
                                        opacity: qcWin.volDragging ? 0 : 1
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: Services.Audio.percent + ""
                                        color: "white"; font.pixelSize: 10; font.weight: Font.Bold
                                        opacity: qcWin.volDragging ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: mouse => {
                                    qcWin.applyVolume(Math.round((mouse.x / width) * 100))
                                    qcWin.volDragging = true; volDragTimer.restart()
                                }
                                onMouseXChanged: {
                                    if (pressed) {
                                        qcWin.applyVolume(Math.round(Math.max(0, Math.min(mouseX, width)) / width * 100))
                                        qcWin.volDragging = true; volDragTimer.restart()
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Brightness ─────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: briCard.implicitHeight + 24
                    radius: 14
                    color: Root.Theme.pillBgHover

                    ColumnLayout {
                        id: briCard
                        anchors { fill: parent; margins: 12 }
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: Services.Brightness.icon; color: Root.Theme.tertiary; font.pixelSize: 16 }
                            Text { text: "Brightness"; color: Root.Theme.textMuted; font.pixelSize: 12 }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Services.Brightness.percent + "%"
                                color: Root.Theme.textPrimary
                                font.pixelSize: 12; font.weight: Font.Medium
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            height: 44

                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: Qt.rgba(Root.Theme.tertiary.r, Root.Theme.tertiary.g, Root.Theme.tertiary.b, 0.15)

                                // Fill bar
                                Rectangle {
                                    width: parent.width * (Services.Brightness.percent / 100)
                                    height: parent.height; radius: parent.radius
                                    color: Root.Theme.tertiary
                                    Behavior on width { NumberAnimation { duration: 80 } }
                                }

                                // Handle
                                Rectangle {
                                    id: briHandle
                                    width: 36; height: 36; radius: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.max(4, Math.min(parent.width - width - 4,
                                        parent.width * (Services.Brightness.percent / 100) - width / 2))
                                    color: Qt.rgba(0, 0, 0, 0.3)
                                    Behavior on x { NumberAnimation { duration: 80 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: Services.Brightness.icon
                                        color: "white"; font.pixelSize: 14
                                        opacity: qcWin.briDragging ? 0 : 1
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: Services.Brightness.percent + ""
                                        color: "white"; font.pixelSize: 10; font.weight: Font.Bold
                                        opacity: qcWin.briDragging ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: mouse => {
                                    briDebounce.pending = Math.round((mouse.x / width) * 100)
                                    briDebounce.triggered()
                                    qcWin.briDragging = true; briDragTimer.restart()
                                }
                                onMouseXChanged: {
                                    if (pressed) {
                                        briDebounce.pending = Math.round(Math.max(0, Math.min(mouseX, width)) / width * 100)
                                        briDebounce.restart()
                                        qcWin.briDragging = true; briDragTimer.restart()
                                    }
                                }
                                onReleased: { briDebounce.stop(); briDebounce.triggered() }
                            }
                        }
                    }
                }

                // ── Connectivity Toggles ──────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 60
                    radius: 14
                    color: Root.Theme.pillBgHover

                    RowLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 12

                        // WiFi
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: qcWin.wifiEnabled ? "󰤨" : "󰤭"; color: qcWin.wifiEnabled ? Root.Theme.textAccent : Root.Theme.textMuted; font.pixelSize: 18 }
                            ColumnLayout {
                                spacing: 0
                                Text { text: "Wi-Fi"; color: Root.Theme.textMuted; font.pixelSize: 11 }
                                Text { text: qcWin.wifiEnabled ? Services.Network.ssid || "On" : "Off"; color: qcWin.wifiEnabled ? Root.Theme.textPrimary : Root.Theme.textMuted; font.pixelSize: 10; elide: Text.ElideRight }
                            }
                            Item { Layout.fillWidth: true }
                            ToggleSwitch {
                                checked: qcWin.wifiEnabled
                                onToggled: qcWin.toggleWifi()
                            }
                        }

                        Rectangle { width: 1; height: 36; color: Root.Theme.pillBgActive }

                        // Bluetooth
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text { text: "󰂯"; color: qcWin.bluetoothEnabled ? Root.Theme.textAccent : Root.Theme.textMuted; font.pixelSize: 18 }
                            ColumnLayout {
                                spacing: 0
                                Text { text: "Bluetooth"; color: Root.Theme.textMuted; font.pixelSize: 11 }
                                Text { text: qcWin.bluetoothEnabled ? "On" : "Off"; color: qcWin.bluetoothEnabled ? Root.Theme.textPrimary : Root.Theme.textMuted; font.pixelSize: 10 }
                            }
                            Item { Layout.fillWidth: true }
                            ToggleSwitch {
                                checked: qcWin.bluetoothEnabled
                                onToggled: qcWin.toggleBt()
                            }
                        }
                    }
                }

                // ── Network + Battery ──────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.fillWidth: true; height: 76
                        radius: 14; color: Root.Theme.pillBgHover

                        ColumnLayout {
                            anchors { fill: parent; margins: 12 }
                            spacing: 4

                            RowLayout {
                                spacing: 6
                                Text { text: Services.Network.icon; color: Services.Network.color; font.pixelSize: 15 }
                                Text { text: "Network"; color: Root.Theme.textMuted; font.pixelSize: 11 }
                            }
                            Text {
                                text: Services.Network.connected ? Services.Network.ssid : "Offline"
                                color: Services.Network.color
                                font.pixelSize: 11; font.weight: Font.Medium
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 76
                        radius: 14; color: Root.Theme.pillBgHover

                        ColumnLayout {
                            anchors { fill: parent; margins: 12 }
                            spacing: 4

                            RowLayout {
                                spacing: 6
                                Text { text: Services.Battery.icon; color: Services.Battery.color; font.pixelSize: 15 }
                                Text { text: "Battery"; color: Root.Theme.textMuted; font.pixelSize: 11 }
                            }
                            Text {
                                text: Services.Battery.percent + "%" + (Services.Battery.charging ? "  ⚡" : "")
                                color: Services.Battery.color
                                font.pixelSize: 11; font.weight: Font.Medium
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
