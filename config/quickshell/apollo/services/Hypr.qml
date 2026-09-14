pragma Singleton

import QtQuick
import Quickshell

// Bridge to a Lua-configured Hyprland.
//
// Hyprland's config language moved from hyprlang to Lua, and its dispatch IPC
// moved with it. `dispatch workspace 3` is no longer a thing — you send the
// Lua expression `hl.dsp.focus({ workspace = 3 })` instead. Every place in the
// shell that used to shell out a hyprlang dispatcher goes through here now.
//
// Calls are handed to `hyprctl` as a plain argv array, never as a shell
// string, so the braces, parentheses and quotes that Lua expressions are full
// of don't get re-tokenized by a shell on the way.
Singleton {
    id: root

    // Run a raw Lua dispatch expression, e.g. "hl.dsp.exit()".
    function dispatch(lua) {
        Quickshell.execDetached(["hyprctl", "dispatch", lua])
    }

    function focusWorkspace(id) {
        root.dispatch("hl.dsp.focus({ workspace = " + id + " })")
    }

    // `address` is the raw hex Quickshell reports, without Hyprland's own
    // "0x" prefix (e.g. "557d...", not "0x557d..."). Dispatch fails silently
    // with "No such window found" if the prefix is missing, so add it here.
    function focusWindow(address) {
        root.dispatch('hl.dsp.focus({ window = "address:0x' + address + '" })')
    }

    // Spawn a command with Hyprland's environment rather than the shell's.
    function exec(cmd) {
        root.dispatch("hl.dsp.exec_cmd(" + JSON.stringify(cmd) + ")")
    }

    function exit() {
        root.dispatch("hl.dsp.exit()")
    }
}
