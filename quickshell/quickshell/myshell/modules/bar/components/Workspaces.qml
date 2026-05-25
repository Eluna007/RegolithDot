import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../../../services" as Services

ColumnLayout {
    spacing: 6

    Repeater {
        model: ScriptModel {
            values: Array.from({length: 10}, (_, i) => i + 1)
        }

        delegate: Rectangle {
            required property int modelData

            readonly property bool isActive: modelData === Services.Hypr.activeWsId
            readonly property bool isOccupied: Services.Hypr.workspaces.values.some(ws => ws.id === modelData)

            implicitWidth: 8
            implicitHeight: isActive ? 18 : 8
            radius: 4
            Layout.alignment: Qt.AlignHCenter

            color: isActive   ? "white" :
                   isOccupied ? "#88ffffff" :
                                "#33ffffff"

            Behavior on implicitHeight {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Services.Hypr.dispatch("workspace " + parent.modelData)
            }
        }
    }
}
