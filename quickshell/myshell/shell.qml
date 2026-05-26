import "modules/bar"
import "modules/osd"
import "modules/dashboard"
import "modules/powermenu"
import "modules/quickcontrols"
import "modules/gestures"
import "modules/notifications"
import "modules/visualizer"
import Quickshell

ShellRoot {
    settings.watchFiles: true

    BarWrapper {}
    Osd {}
    Dashboard {}
    PowerMenu {}
    QuickControls {}
    EdgeSwipe {}
    NotificationPanel {}
    DesktopVisualizer {}
}
