import QtQuick
import QtQuick.Layouts
import "../../../services" as Services

ColumnLayout {
    spacing: 2
    Layout.alignment: Qt.AlignHCenter

    Text {
        text: Services.Time.hourStr + ":" + Services.Time.minuteStr
        color: "white"
        font.pixelSize: 10
        font.weight: Font.Medium
        Layout.alignment: Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
    }

    Text {
        text: Services.Time.amPmStr
        color: "#88ffffff"
        font.pixelSize: 9
        Layout.alignment: Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
    }

    Text {
        text: Qt.formatDateTime(new Date(), "MMM d")
        color: "#88ffffff"
        font.pixelSize: 9
        Layout.alignment: Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
    }

    TapHandler {
        onTapped: Services.Dashboard.toggle()
    }
}
