import QtQuick
import Quickshell.Bluetooth
import "../components" as Components
import "../services" as Services

Components.AnchoredPopup {
    id: popup
    contentWidth: 300

    readonly property var btAdapter: Bluetooth.defaultAdapter

    onVisibleChanged: if (visible) { Services.QuickToggles.refreshAirplane(); Services.QuickToggles.refreshWifiRadio() }

    Text {
        text: "Quick Settings"
        color: Services.Theme.foreground
        opacity: 0.7
        font.pixelSize: Services.Theme.fontSizeSmall
        font.family: Services.Theme.fontFamily
    }

    Grid {
        width: parent.width
        columns: 2
        columnSpacing: 8
        rowSpacing: 8

        component ToggleBtn: Rectangle {
            id: tbn
            property string icon: ""
            property string label: ""
            property string sub: ""
            property bool on: false
            signal toggled()

            width: (parent.width - 8) / 2
            height: 56
            radius: 14
            color: tbn.on ? Services.Theme.pillAccent : Services.Theme.pillColor
            border.width: 1
            border.color: tbn.on ? Services.Theme.pillAccent : Services.Theme.pillBorder
            Behavior on color { ColorAnimation { duration: 150 } }

            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Text {
                    text: tbn.icon
                    color: tbn.on ? Services.Theme.background : Services.Theme.foreground
                    font.pixelSize: 18
                    font.family: Services.Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    spacing: 1
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: tbn.label
                        color: tbn.on ? Services.Theme.background : Services.Theme.foreground
                        font.pixelSize: Services.Theme.fontSizeSmall - 1
                        font.family: Services.Theme.fontFamily
                    }
                    Text {
                        text: tbn.sub
                        color: tbn.on ? Qt.rgba(Services.Theme.background.r, Services.Theme.background.g, Services.Theme.background.b, 0.7)
                                      : Qt.rgba(Services.Theme.foreground.r, Services.Theme.foreground.g, Services.Theme.foreground.b, 0.55)
                        font.pixelSize: Services.Theme.fontSizeSmall - 4
                        font.family: Services.Theme.fontFamily
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: tbn.toggled()
            }
        }

        ToggleBtn {
            icon: String.fromCodePoint(0xf0928)
            label: "Wi-Fi"
            sub: Services.QuickToggles.wifiRadioOn ? "Enabled" : "Off"
            on: Services.QuickToggles.wifiRadioOn
            onToggled: Services.QuickToggles.toggleWifiRadio()
        }
        ToggleBtn {
            icon: String.fromCodePoint(0xf00af)
            label: "Bluetooth"
            sub: (popup.btAdapter?.enabled ?? false) ? "On" : "Off"
            on: popup.btAdapter?.enabled ?? false
            onToggled: if (popup.btAdapter) popup.btAdapter.enabled = !popup.btAdapter.enabled
        }
        ToggleBtn {
            icon: String.fromCodePoint(0xf02fc)
            label: "Do Not Disturb"
            sub: Services.QuickToggles.dnd ? "Silenced" : "Off"
            on: Services.QuickToggles.dnd
            onToggled: Services.QuickToggles.toggleDnd()
        }
        ToggleBtn {
            icon: String.fromCodePoint(0xf0594)
            label: "Night Light"
            sub: Services.QuickToggles.nightLight ? "Warm" : "Off"
            on: Services.QuickToggles.nightLight
            onToggled: Services.QuickToggles.toggleNightLight()
        }
        ToggleBtn {
            icon: String.fromCodePoint(0xf0176)
            label: "Caffeine"
            sub: Services.QuickToggles.caffeine ? "Awake" : "Off"
            on: Services.QuickToggles.caffeine
            onToggled: Services.QuickToggles.toggleCaffeine()
        }
        ToggleBtn {
            icon: String.fromCodePoint(0xf0117)
            label: "Airplane"
            sub: Services.QuickToggles.airplane ? "On" : "Off"
            on: Services.QuickToggles.airplane
            onToggled: Services.QuickToggles.toggleAirplane()
        }
    }

    Rectangle { width: parent.width; height: 1; color: Services.Theme.pillBorder }

    // Volume + brightness sliders, embedded directly (same slider pattern
    // already used elsewhere tonight — verified against yahr-shell's own
    // LevelSlider.qml, which uses the identical MouseArea approach).
    component InlineSlider: Row {
        property string icon: ""
        property real value: 0
        property color fillColor: Services.Theme.pillAccent
        signal moved(real pct)
        width: parent.width
        spacing: 8

        Text {
            text: parent.icon
            color: Services.Theme.foreground
            font.pixelSize: Services.Theme.fontSizeNormal
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
        Item {
            width: parent.width - 60
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            Rectangle { width: parent.width; height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: Services.Theme.pillBorder }
            Rectangle { width: parent.width * (parent.parent.value / 100); height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: parent.parent.fillColor }
            MouseArea {
                anchors.fill: parent
                function atX(mx) { parent.parent.moved(Math.max(0, Math.min(100, Math.round(mx / width * 100)))) }
                onPressed: mouse => atX(mouse.x)
                onPositionChanged: mouse => { if (pressed) atX(mouse.x) }
            }
        }
        Text {
            text: Math.round(parent.value) + "%"
            color: Services.Theme.foreground
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    InlineSlider {
        icon: Services.Audio.muted ? String.fromCodePoint(0xf0581) : String.fromCodePoint(0xf057e)
        value: Services.Audio.volume * 100
        onMoved: pct => Services.Audio.setVolume(pct / 100)
    }
    InlineSlider {
        icon: String.fromCodePoint(0xf05a8)
        value: Services.Brightness.level * 100
        fillColor: Services.Theme.pillSecondary
        onMoved: pct => Services.Brightness.setBrightness(pct / 100)
    }
}
