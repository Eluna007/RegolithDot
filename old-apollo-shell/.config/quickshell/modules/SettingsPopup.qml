import QtQuick
import "../components" as Components
import "../services" as Services

Components.AnchoredPopup {
    id: popup
    contentWidth: 280

    Text {
        text: "Bar Settings"
        color: Services.Theme.foreground
        opacity: 0.7
        font.pixelSize: Services.Theme.fontSizeSmall
        font.family: Services.Theme.fontFamily
    }

    Text {
        text: "Style"
        color: Services.Theme.foreground
        opacity: 0.6
        font.pixelSize: Services.Theme.fontSizeSmall - 3
        font.family: Services.Theme.fontFamily
    }
    Row {
        width: parent.width
        spacing: 8
        readonly property real bw: (width - spacing) / 2

        component OptBtn: Rectangle {
            property string label: ""
            property bool active: false
            signal clicked()
            width: parent.bw
            height: 34
            radius: 10
            color: active ? Services.Theme.pillAccent : (ma.containsMouse ? Services.Theme.hoverBg : Services.Theme.pillColor)
            border.width: 1
            border.color: active ? Services.Theme.pillAccent : Services.Theme.pillBorder
            Text {
                anchors.centerIn: parent
                text: parent.label
                color: parent.active ? Services.Theme.background : Services.Theme.foreground
                font.pixelSize: Services.Theme.fontSizeSmall - 1
                font.family: Services.Theme.fontFamily
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
        }

        OptBtn {
            label: "Islands"
            active: Services.BarSettings.style === "islands"
            onClicked: Services.BarSettings.setStyle("islands")
        }
        OptBtn {
            label: "Classic"
            active: Services.BarSettings.style === "classic"
            onClicked: Services.BarSettings.setStyle("classic")
        }
    }

    Text {
        text: "Position"
        color: Services.Theme.foreground
        opacity: 0.6
        font.pixelSize: Services.Theme.fontSizeSmall - 3
        font.family: Services.Theme.fontFamily
    }
    Row {
        width: parent.width
        spacing: 8
        readonly property real bw: (width - spacing * 2) / 3

        component PosBtn: Rectangle {
            property string label: ""
            property bool active: false
            property bool enabledHere: true
            signal clicked()
            width: parent.bw
            height: 34
            radius: 10
            opacity: enabledHere ? 1 : 0.35
            color: active ? Services.Theme.pillAccent : (ma.containsMouse && enabledHere ? Services.Theme.hoverBg : Services.Theme.pillColor)
            border.width: 1
            border.color: active ? Services.Theme.pillAccent : Services.Theme.pillBorder
            Text {
                anchors.centerIn: parent
                text: parent.label
                color: parent.active ? Services.Theme.background : Services.Theme.foreground
                font.pixelSize: Services.Theme.fontSizeSmall - 1
                font.family: Services.Theme.fontFamily
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: parent.enabledHere; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
        }

        PosBtn {
            label: "Top"
            active: Services.BarSettings.dockPosition === "top"
            onClicked: Services.BarSettings.setDockPosition("top")
        }
        PosBtn {
            label: "Left"
            active: Services.BarSettings.dockPosition === "left"
            onClicked: Services.BarSettings.setDockPosition("left")
        }
        PosBtn {
            label: "Right"
            active: Services.BarSettings.dockPosition === "right"
            onClicked: Services.BarSettings.setDockPosition("right")
        }
    }
}
