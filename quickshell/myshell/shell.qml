import "modules/bar"
import "modules/osd"
import "modules/dashboard"
import "modules/powermenu"
import Quickshell

ShellRoot {
    settings.watchFiles: true

    BarWrapper {}
    Osd {}
    Dashboard {}
    PowerMenu {}
}
