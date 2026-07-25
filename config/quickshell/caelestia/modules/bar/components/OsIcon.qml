import QtQuick
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    implicitWidth: Math.round(Tokens.font.size.large * 1.2)
    implicitHeight: Math.round(Tokens.font.size.large * 1.2)

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const visibilities = Visibilities.getForActive();
            visibilities.launcher = !visibilities.launcher;
        }
    }

    AnimatedImage {
        anchors.centerIn: parent
        source: "/home/edgarlr/Pictures/gifs/frieren.gif"
        width: Math.round(Tokens.font.size.large * 1.6)
        height: Math.round(Tokens.font.size.large * 1.6)
        fillMode: Image.PreserveAspectCrop
        playing: true
    }

    Component {
        id: caelestiaLogo

        Logo {
            implicitWidth: Math.round(Tokens.font.size.large * 1.6)
            implicitHeight: Math.round(Tokens.font.size.large * 1.6)
        }
    }

    Component {
        id: distroIcon

        ColouredIcon {
            source: SysInfo.osLogo
            implicitSize: Math.round(Tokens.font.size.large * 1.2)
            colour: Colours.palette.m3tertiary
        }
    }
}
