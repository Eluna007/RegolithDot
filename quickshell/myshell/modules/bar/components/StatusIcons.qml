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

        Text {
            text: Services.Audio.percent + "%"
            color: Services.Audio.muted ? "#f38ba8" : "white"
            font.pixelSize: 10
            Layout.alignment: Qt.AlignHCenter
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

        Text {
            text: Services.Battery.percent + "%"
            color: Services.Battery.color
            font.pixelSize: 10
            Layout.alignment: Qt.AlignHCenter
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

        Text {
            text: Services.Network.connected ? Services.Network.ssid : "off"
            color: Services.Network.color
            font.pixelSize: 9
            Layout.alignment: Qt.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
