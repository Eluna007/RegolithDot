import "modules/bar"
import "modules/osd"
import "modules/dashboard"
import "modules/powermenu"
import "modules/quickcontrols"
import "modules/gestures"
import Quickshell

ShellRoot {
    settings.watchFiles: true

    BarWrapper {}
    Osd {}
    Dashboard {}
    PowerMenu {}
    QuickControls {}
    EdgeSwipe {}
}
