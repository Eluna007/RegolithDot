pragma Singleton

import QtQuick
import Quickshell
import "services" as Services

Singleton {
    readonly property color pillBg:       Qt.rgba(
        Services.Colors.surface.r,
        Services.Colors.surface.g,
        Services.Colors.surface.b, 0.85)

    readonly property color pillBgHover:  Qt.rgba(
        Services.Colors.surfaceVariant.r,
        Services.Colors.surfaceVariant.g,
        Services.Colors.surfaceVariant.b, 0.85)

    readonly property color pillBgActive: Qt.rgba(
        Services.Colors.primaryContainer.r,
        Services.Colors.primaryContainer.g,
        Services.Colors.primaryContainer.b, 0.95)

    readonly property color textPrimary:  Services.Colors.foreground
    readonly property color textMuted:    Qt.rgba(
        Services.Colors.foreground.r,
        Services.Colors.foreground.g,
        Services.Colors.foreground.b, 0.6)
    readonly property color textAccent:   Services.Colors.primary

    readonly property int pillRadius:   16
    readonly property int pillPadding:  8
    readonly property int barWidth:     28
    readonly property int barGap:       6
    readonly property int pillSpacing:  4
}
