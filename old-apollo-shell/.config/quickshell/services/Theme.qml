pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme

    property color background: "#14141c"
    property color surface: "#1e1e28"
    property color accent: "#8ab4f8"
    property color secondary: "#f2b8b5"
    property color tertiary: "#c9c2ea"
    property color errorColor: "#f2b8b5"
    property color foreground: "#e8e8f0"

    property color pillColor: Qt.rgba(surface.r, surface.g, surface.b, 0.55)
    property color pillBorder: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.45)
    property color pillAccent: Qt.rgba(accent.r, accent.g, accent.b, 0.9)
    property color pillSecondary: Qt.rgba(secondary.r, secondary.g, secondary.b, 0.9)
    property color pillTertiary: Qt.rgba(tertiary.r, tertiary.g, tertiary.b, 0.9)

    property color hoverBg: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
    property color pressedBg: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.20)

    property string fontFamily: "JetBrainsMono Nerd Font Mono"
    property int fontSizeNormal: 13
    property int fontSizeSmall: 12

    property int pillPaddingH: 16
    property int pillPaddingV: 8

    property int workspaceCount: 5

    property FileView colorsFile: FileView {
        path: Qt.resolvedUrl(Quickshell.env("HOME") + "/.config/quickshell/colors.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text())
                if (data.surface) { theme.background = data.surface; theme.surface = data.surface }
                if (data.primary) theme.accent = data.primary
                if (data.secondary) theme.secondary = data.secondary
                if (data.tertiary) theme.tertiary = data.tertiary
                if (data.error) theme.errorColor = data.error
                if (data.on_surface) theme.foreground = data.on_surface
            } catch (e) {
                console.warn("Theme: colors.json not valid yet, using defaults:", e)
            }
        }
    }
}
