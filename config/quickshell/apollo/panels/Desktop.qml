import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"

// The desktop layer: a clock on the wallpaper, under the windows.
//
// On a tiling compositor this is only visible on an empty workspace, which is
// exactly when a screen has nothing else to say. It takes no input and never
// wants the keyboard.
//
// Four properties here have no other user in this shell, and an unknown QML
// property is a load-time error that takes the whole shell down with it — so,
// for the record, what each one is for:
//
//   WlrLayershell.layer: WlrLayer.Bottom   above the wallpaper, below windows.
//                                          Background is where hyprpaper draws.
//   WlrLayershell.namespace                deliberately NOT "quickshell".
//                                          rules.lua blurs `^(quickshell)$`,
//                                          and blurring a surface that sits
//                                          directly on the wallpaper would blur
//                                          the wallpaper through it. A distinct
//                                          namespace opts this one out, and
//                                          `hyprctl layers` names it.
//   mask: Region {}                        an empty input region. Without it a
//                                          full-screen Bottom surface eats every
//                                          click on the desktop.
//   exclusiveZone: 0                       reserves no space, so windows tile
//                                          over it (same as every other panel).
PanelWindow {
    id: root

    // Off means the surface is never mapped at all, not merely transparent.
    visible: Config.showDesktop

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "apollo-desktop"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Decorative only: every click goes to whatever is behind it.
    mask: Region {}

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"

    property string timeText: ""
    property string dateText: ""

    // One second, the same as the bar's clocks. Formatting a date once a second
    // costs nothing, and matching them means they can never disagree about
    // which minute it is.
    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            root.timeText = Qt.formatDateTime(now, Config.clock24h ? "HH:mm" : "h:mm")
            root.dateText = Qt.formatDateTime(now, "dddd, d MMMM")
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.30)
        spacing: 10

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: root.timeText
            color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.82)
            font { pixelSize: 128; family: root.nfFont; weight: Font.Light }
        }

        // A short accent rule rather than a second heavy line of type — it ties
        // the block to whatever the palette currently is without competing
        // with the clock.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 56
            height: 2
            radius: 1
            color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.7)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: root.dateText
            color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.55)
            font { pixelSize: 17; family: root.nfFont }
        }
    }
}
