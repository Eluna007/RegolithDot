import QtQuick
import QtQuick.Layouts
import "../../../services" as Services

ColumnLayout {
    spacing: 8
    Layout.alignment: Qt.AlignHCenter

    // Volume
    ColumnLayout {
        spacing: 2
        Layout.alignment: Qt.AlignHCenter

        Text {
            text: Services.Audio.icon
            color: Services.Audio.muted ? "#f38ba8" : "white"
            font.pixelSize: 14
            Layout.alignment: Qt.AlignHCenter

            MouseArea {
                anchors.fill: parent
                onClicked: Services.Audio.toggleMute()
                onWheel: event => {
                    if (event.angleDelta.y > 0)
                        Services.Audio.increment()
                    else
                        Services.Audio.decrement()
                }
            }
        }

        // Show volume % only when muted or very low
        Text {
            property bool shown: Services.Audio.muted || Services.Audio.percent <= 15
            text: Services.Audio.percent + "%"
            color: Services.Audio.muted ? "#f38ba8" : "white"
            font.pixelSize: 10
            Layout.alignment: Qt.AlignHCenter
            opacity: shown ? 1 : 0
            Layout.maximumHeight: shown ? implicitHeight : 0
            clip: true
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on Layout.maximumHeight { NumberAnimation { duration: 200 } }
        }
    }

    // Battery
    ColumnLayout {
        spacing: 2
        Layout.alignment: Qt.AlignHCenter

        Text {
            text: Services.Battery.icon
            color: Services.Battery.color
            font.pixelSize: 14
            Layout.alignment: Qt.AlignHCenter
        }

        // Show battery % only when charging or low
        Text {
            property bool shown: Services.Battery.charging || Services.Battery.percent <= 30
            text: Services.Battery.percent + "%"
            color: Services.Battery.color
            font.pixelSize: 10
            Layout.alignment: Qt.AlignHCenter
            opacity: shown ? 1 : 0
            Layout.maximumHeight: shown ? implicitHeight : 0
            clip: true
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on Layout.maximumHeight { NumberAnimation { duration: 200 } }
        }
    }

    // Network
    ColumnLayout {
        spacing: 2
        Layout.alignment: Qt.AlignHCenter

        Text {
            text: Services.Network.icon
            color: Services.Network.color
            font.pixelSize: 14
            Layout.alignment: Qt.AlignHCenter
        }

        // Show SSID only when connected
        Text {
            property bool shown: Services.Network.connected
            text: Services.Network.ssid
            color: Services.Network.color
            font.pixelSize: 9
            Layout.alignment: Qt.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            opacity: shown ? 1 : 0
            Layout.maximumHeight: shown ? implicitHeight : 0
            clip: true
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on Layout.maximumHeight { NumberAnimation { duration: 200 } }
        }
    }
}
