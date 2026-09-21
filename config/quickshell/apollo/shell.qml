import Quickshell
import Quickshell.Io
import QtQuick
import "panels"

// Apollo — the sudoku and chess widgets, and nothing else.
//
// There is no bar. The two panels are opened over IPC, so the compositor's
// own keybind config is the only entry point:
//
//   qs -c apollo ipc call panel toggle apolloku
//   qs -c apollo ipc call panel toggle chess
//
// Nothing here imports Quickshell.Hyprland (or any other compositor module),
// which is what makes it run unchanged under niri. The cost is that the shell
// cannot ask which output has focus: the panels are single instances, so on a
// multi-monitor setup they land on the first screen rather than following the
// pointer. Making them follow focus means querying the compositor — `niri msg
// --json focused-output` — and passing the name down to `screen`.
ShellRoot {
    id: rootShell

    // Which panel is open, or "" for none. Toggling the panel that is already
    // open closes it; opening the other one replaces it, so the two never
    // overlap.
    property string activePanel: ""

    function toggle(name) {
        activePanel = (activePanel === name ? "" : name)
    }

    IpcHandler {
        target: "panel"

        function toggle(name: string): void {
            rootShell.toggle(name)
        }

        // For a keybind that should only ever close whatever is up.
        function close(): void {
            rootShell.activePanel = ""
        }
    }

    ApollokuPanel {
        visible: rootShell.activePanel === "apolloku"
        onClose: rootShell.activePanel = ""
    }

    ChessPanel {
        visible: rootShell.activePanel === "chess"
        onClose: rootShell.activePanel = ""
    }
}
