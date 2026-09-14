import Quickshell
import QtQuick
import "../services" as Services

// Transient volume/brightness/mic popup, shown briefly whenever the value
// changes from any source (keys, sliders, scripts) — not just clicking a
// bar icon. Ported from Moonlit's OSD.qml.
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    property string kind: ""
    property real value: 0
    property bool osdVisible: false
    visible: osdVisible

    anchors { bottom: true; left: true; right: true }
    margins.bottom: 70
    exclusiveZone: 0
    implicitHeight: 60
    color: "transparent"

    function iconFor() {
        if (kind === "volume") return value === 0 ? String.fromCodePoint(0xf0581) : String.fromCodePoint(0xf057e)
        if (kind === "mic") return value === 0 ? String.fromCodePoint(0xf0131) : String.fromCodePoint(0xf0130)
        return String.fromCodePoint(0xf05a8)   // brightness
    }
    function tintFor() {
        if (kind === "mic") return Services.Theme.pillSecondary
        return Services.Theme.pillAccent
    }

    Item {
        anchors.centerIn: parent
        width: 300; height: 52

        Rectangle {
            anchors.fill: parent
            radius: 999
            color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.94)
            border.width: 1
            border.color: Services.Theme.pillBorder

            Row {
                anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
                spacing: 14

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.iconFor()
                    color: root.tintFor()
                    font.pixelSize: 22
                    font.family: Services.Theme.fontFamily
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 22 - 14 - 40
                    height: 8
                    radius: 999
                    color: Services.Theme.pillBorder

                    Rectangle {
                        width: parent.width * (root.value / 100)
                        height: 8
                        radius: 999
                        color: root.tintFor()
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.value)
                    color: Services.Theme.foreground
                    font.pixelSize: 14
                    font.bold: true
                    font.family: Services.Theme.fontFamily
                    width: 34
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        NumberAnimation on opacity { from: 0; to: 1; duration: 200; running: true; easing.type: Easing.OutCubic }
    }
}
