import QtQuick
import Quickshell.Hyprland
import "../components" as Components
import "../services" as Services

Components.Pill {
    id: root
    property int maxWidth: 280

    Text {
        text: Hyprland.activeToplevel?.title ?? "Desktop"
        color: Services.Theme.foreground
        font.pixelSize: Services.Theme.fontSizeSmall
        font.family: Services.Theme.fontFamily
        elide: Text.ElideRight
        width: Math.min(implicitWidth, root.maxWidth - Services.Theme.pillPaddingH * 2)
    }
}
