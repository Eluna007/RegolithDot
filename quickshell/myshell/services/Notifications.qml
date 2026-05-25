pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int count: parseInt(data.text) || 0
    readonly property bool dnd: data.class === "dnd" || data.class === "dnd-notification"
    readonly property bool hasNotifs: count > 0

    readonly property string icon: {
        if (dnd)           return "󰂛"
        if (hasNotifs)     return "󰂚"
        return "󰂜"
    }

    readonly property color color: {
        if (dnd)       return "#88ffffff"
        if (hasNotifs) return "#fab387"
        return "white"
    }

    property var data: ({ text: "0", alt: "", tooltip: "", class: "" })

    function toggle(): void {
        toggler.running = true
    }

    function toggleDnd(): void {
        dndToggler.running = true
    }

    Process {
        id: subscriber
        command: ["swaync-client", "--subscribe-waybar"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.data = JSON.parse(data)
                } catch (e) {}
            }
        }
    }

    Process {
        id: toggler
        command: ["swaync-client", "--toggle-panel"]
    }

    Process {
        id: dndToggler
        command: ["swaync-client", "--toggle-dnd"]
        onExited: subscriber.running = true
    }
}
