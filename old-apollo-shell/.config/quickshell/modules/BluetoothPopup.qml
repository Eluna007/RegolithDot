import QtQuick
import Quickshell.Bluetooth
import "../components" as Components
import "../services" as Services

Components.AnchoredPopup {
    id: popup
    contentWidth: 260

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var sortedDevices: [...Bluetooth.devices.values].sort(
        (a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name)
    ).slice(0, 6)

    // Real mechanism, confirmed from Caelestia's source: discovery is a
    // property you set, not a one-shot command. Bounded to ~8s here so it
    // reads as a "scan" button rather than a persistent toggle switch.
    function scan() {
        if (!popup.adapter || popup.adapter.discovering) return
        popup.adapter.discovering = true
        scanTimer.restart()
    }
    Item {
        Timer { id: scanTimer; interval: 8000; onTriggered: if (popup.adapter) popup.adapter.discovering = false }
    }

    Row {
        width: parent.width
        Text {
            text: "Bluetooth"
            color: Services.Theme.foreground
            opacity: 0.7
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
        Item { width: parent.width - 130; height: 1 }
        Text {
            text: (popup.adapter?.discovering ?? false) ? "\u2026" : String.fromCodePoint(0xf0453)
            color: Services.Theme.foreground
            opacity: 0.7
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                anchors.fill: parent
                enabled: popup.adapter?.enabled ?? false
                cursorShape: Qt.PointingHandCursor
                onClicked: popup.scan()
            }
        }
        Rectangle {
            width: 34; height: 18; radius: 9
            anchors.verticalCenter: parent.verticalCenter
            color: (popup.adapter?.enabled ?? false) ? Services.Theme.pillAccent : Services.Theme.pillBorder
            Rectangle {
                width: 14; height: 14; radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: (popup.adapter?.enabled ?? false) ? parent.width - width - 2 : 2
                color: "white"
                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (popup.adapter) popup.adapter.enabled = !popup.adapter.enabled
            }
        }
    }

    Text {
        visible: !(popup.adapter?.enabled ?? false)
        text: "Bluetooth is off"
        color: Services.Theme.foreground
        opacity: 0.5
        font.pixelSize: Services.Theme.fontSizeSmall
        font.family: Services.Theme.fontFamily
    }

    Text {
        visible: (popup.adapter?.enabled ?? false) && popup.sortedDevices.length === 0
        text: "No devices found"
        color: Services.Theme.foreground
        opacity: 0.5
        font.pixelSize: Services.Theme.fontSizeSmall
        font.family: Services.Theme.fontFamily
    }

    Repeater {
        model: popup.sortedDevices

        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property bool connected: modelData.state === BluetoothDeviceState.Connected
            readonly property bool loading: modelData.state === BluetoothDeviceState.Connecting
                                          || modelData.state === BluetoothDeviceState.Disconnecting

            width: parent.width
            height: 34
            radius: 8
            color: ma.containsMouse ? Services.Theme.hoverBg : "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                spacing: 8

                Text {
                    text: row.modelData.name
                    color: Services.Theme.foreground
                    font.pixelSize: Services.Theme.fontSizeSmall
                    font.family: Services.Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 70
                    elide: Text.ElideRight
                }
                Text {
                    visible: row.connected && row.modelData.batteryAvailable
                    text: Math.round((row.modelData.battery ?? 0) * 100) + "%"
                    color: Qt.rgba(Services.Theme.foreground.r, Services.Theme.foreground.g, Services.Theme.foreground.b, 0.6)
                    font.pixelSize: Services.Theme.fontSizeSmall
                    font.family: Services.Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: row.loading ? "\u2026" : (row.connected ? String.fromCodePoint(0xf00b1) : String.fromCodePoint(0xf00b2))
                    color: row.connected ? Services.Theme.pillAccent : Services.Theme.foreground
                    opacity: row.connected ? 1 : 0.5
                    font.pixelSize: Services.Theme.fontSizeSmall
                    font.family: Services.Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !row.loading
                onClicked: row.modelData.connected = !row.modelData.connected
            }
        }
    }
}
