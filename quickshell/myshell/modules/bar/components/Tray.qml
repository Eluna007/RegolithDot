import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

ColumnLayout {
    spacing: 6
    Layout.alignment: Qt.AlignHCenter

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayItem
            required property SystemTrayItem modelData

            implicitWidth: 18
            implicitHeight: 18
            Layout.alignment: Qt.AlignHCenter

            Image {
                anchors.fill: parent
                source: trayItem.modelData.icon
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            QsMenuAnchor {
                id: menuAnchor
                menu: trayItem.modelData.menuHandle ?? null
                anchor.window: trayItem.QsWindow.window
                anchor.rect: Qt.rect(trayItem.x, trayItem.y, trayItem.width, trayItem.height)
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        if (trayItem.modelData.menuHandle)
                            menuAnchor.open()
                    } else {
                        trayItem.modelData.activate()
                    }
                }
            }
        }
    }
}
