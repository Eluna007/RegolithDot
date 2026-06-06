import QtQuick
import Quickshell

QtObject {
    readonly property string homeDir: Quickshell.env("HOME")
    property string wallpaperDir: homeDir + "/Pictures/Wallpapers"
    readonly property string cacheDir: homeDir + "/.cache/wallpaper_picker"
    readonly property string thumbDir: homeDir + "/.cache/wallpaper_picker/thumbs"

    property bool uiAnimationsEnabled: true
    property real uiAnimationScale: 1.0
    property string wallpaperTransitionType: "wave"
    property real wallpaperTransitionDuration: 1.5
    property int wallpaperTransitionFps: 60
    property int closeDelayMs: 120
    property int scrollThrottleMs: 150
    property int filterAnimationMs: 800
    property int itemAnimationMs: 500

    property bool enableDynamicColors: false
    property bool enableMatugen: false
    property bool enableHyprReload: true
    property bool enableWaybarReload: false
    property bool enableKittyReload: false
    property bool enableCavaReload: false
    property bool enableSwayncReload: false
    property bool enableSwayosdReload: false

    property string hyprColorsPath: homeDir + "/.config/hypr/colors.conf"
    property string waybarColorsPath: ""
    property string waybarLaunchPath: ""
    property string kittySignalProcess: ".kitty-wrapped"
    property string extraReloadCommand: ""
}
