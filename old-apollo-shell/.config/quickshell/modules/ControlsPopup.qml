import QtQuick
import "../components" as Components
import "../services" as Services

Components.AnchoredPopup {
    id: popup
    contentWidth: 260

    Text {
        text: "Brightness"
        color: Services.Theme.foreground
        opacity: 0.7
        font.pixelSize: Services.Theme.fontSizeSmall
        font.family: Services.Theme.fontFamily
    }
    Row {
        width: parent.width
        spacing: 8
        Text {
            text: String.fromCodePoint(0xf05a8)
            color: Services.Theme.foreground
            font.pixelSize: Services.Theme.fontSizeNormal
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
        Item {
            width: parent.width - 60
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                width: parent.width; height: 4; radius: 2
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.pillBorder
            }
            Rectangle {
                width: parent.width * Services.Brightness.level; height: 4; radius: 2
                anchors.verticalCenter: parent.verticalCenter
                color: Services.Theme.pillSecondary
            }
            MouseArea {
                anchors.fill: parent
                onPressed: mouse => Services.Brightness.setBrightness(mouse.x / width)
                onPositionChanged: mouse => { if (pressed) Services.Brightness.setBrightness(mouse.x / width) }
            }
        }
        Text {
            text: Math.round(Services.Brightness.level * 100) + "%"
            color: Services.Theme.foreground
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
