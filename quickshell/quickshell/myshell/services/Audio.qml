pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property real volume: parseFloat(raw.replace("Volume: ", "")) || 0
    readonly property bool muted: raw.includes("[MUTED]")
    readonly property int percent: Math.round(volume * 100)

    readonly property string icon: {
        if (muted || percent === 0) return "󰝟"
        if (percent < 33)           return "󰕿"
        if (percent < 66)           return "󰖀"
        return "󰕾"
    }

    property string raw: ""

    function increment(): void {
        runner.command = ["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", "5%+"]
        runner.running = true
    }
    function decrement(): void {
        runner.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]
        runner.running = true
    }
    function toggleMute(): void {
        runner.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        runner.running = true
    }

    onPercentChanged: Osd.show("volume", percent)

    Process {
        id: poller
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: true
        stdout: SplitParser {
            onRead: data => root.raw = data
        }
    }

    Process {
        id: runner
        onExited: poller.running = true
    }

    // Subscribe to pulseaudio events for instant updates
    Process {
        id: subscriber
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (data.includes("sink") || data.includes("server"))
                    poller.running = true
            }
        }
    }
}
