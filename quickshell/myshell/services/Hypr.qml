pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    readonly property var workspaces:      Hyprland.workspaces
    readonly property var monitors:        Hyprland.monitors
    readonly property var toplevels:       Hyprland.toplevels
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property HyprlandMonitor   focusedMonitor:   Hyprland.focusedMonitor
    readonly property int activeWsId: focusedWorkspace?.id ?? 1

    readonly property string activeWindowTitle: {
        const t = Hyprland.activeToplevel;
        return t ? t.title : "";
    }

    function dispatch(request: string): void {
        Hyprland.dispatch(request);
    }

    function monitorFor(screen: ShellScreen): HyprlandMonitor {
        return Hyprland.monitorFor(screen);
    }
}
