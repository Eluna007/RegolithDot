import QtQuick
import QtQuick.Layouts
import "../../../services" as Services

ColumnLayout {
    spacing: 2
    Layout.alignment: Qt.AlignHCenter

    Text {
        text: Services.Notifications.icon
        color: Services.Notifications.color
        font.pixelSize: 14
        Layout.alignment: Qt.AlignHCenter

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    Services.Notifications.toggleDnd()
                else
                    Services.Notifications.toggle()
            }
        }
    }

    Text {
        visible: Services.Notifications.hasNotifs
        text: Services.Notifications.count
        color: Services.Notifications.color
        font.pixelSize: 10
        Layout.alignment: Qt.AlignHCenter
    }
}
