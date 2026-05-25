pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string title: ""
    property string artist: ""
    property string album: ""
    property string status: "Stopped"
    property string artUrl: ""
    property real position: 0
    property real length: 0

    readonly property bool playing: status === "Playing"
    readonly property bool stopped: title === ""
    readonly property real progress: length > 0 ? position / length : 0

    readonly property string positionStr: formatTime(position / 1000000)
    readonly property string lengthStr: formatTime(length / 1000000)

    function formatTime(secs: real): string {
        const s = Math.floor(secs)
        const m = Math.floor(s / 60)
        const sec = s % 60
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }

    function next(): void     { runner.command = ["playerctl", "next"];        runner.running = true }
    function previous(): void { runner.command = ["playerctl", "previous"];    runner.running = true }
    function playPause(): void { runner.command = ["playerctl", "play-pause"]; runner.running = true }

    Process { id: runner }

    Process {
        id: titlePoller
        command: ["playerctl", "metadata", "--format", "{{title}}"]
        running: true
        stdout: SplitParser { onRead: data => root.title = data.trim() }
        onExited: function(code) { if (code !== 0) root.title = "" }
    }

    Process {
        id: artistPoller
        command: ["playerctl", "metadata", "--format", "{{artist}}"]
        running: true
        stdout: SplitParser { onRead: data => root.artist = data.trim() }
        onExited: function(code) { if (code !== 0) root.artist = "" }
    }

    Process {
        id: albumPoller
        command: ["playerctl", "metadata", "--format", "{{album}}"]
        running: true
        stdout: SplitParser { onRead: data => root.album = data.trim() }
        onExited: function(code) { if (code !== 0) root.album = "" }
    }

    Process {
        id: statusPoller
        command: ["playerctl", "status"]
        running: true
        stdout: SplitParser { onRead: data => root.status = data.trim() }
        onExited: function(code) { if (code !== 0) root.status = "Stopped" }
    }

    Process {
        id: artPoller
        command: ["playerctl", "metadata", "--format", "{{mpris:artUrl}}"]
        running: true
        stdout: SplitParser { onRead: data => root.artUrl = data.trim() }
        onExited: function(code) { if (code !== 0) root.artUrl = "" }
    }

    Process {
        id: positionPoller
        command: ["playerctl", "metadata", "--format", "{{position}}"]
        running: true
        stdout: SplitParser { onRead: data => root.position = parseFloat(data.trim()) || 0 }
        onExited: function(code) { if (code !== 0) root.position = 0 }
    }

    Process {
        id: lengthPoller
        command: ["playerctl", "metadata", "--format", "{{mpris:length}}"]
        running: true
        stdout: SplitParser { onRead: data => root.length = parseFloat(data.trim()) || 0 }
        onExited: function(code) { if (code !== 0) root.length = 0 }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            titlePoller.running = true
            artistPoller.running = true
            albumPoller.running = true
            statusPoller.running = true
            artPoller.running = true
            positionPoller.running = true
            lengthPoller.running = true
        }
    }

    Timer {
        interval: 1000
        running: root.playing
        repeat: true
        onTriggered: root.position += 1000000
    }
}
