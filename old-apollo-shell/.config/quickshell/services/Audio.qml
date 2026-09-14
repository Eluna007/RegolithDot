pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire

QtObject {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool muted: !!sink?.audio?.muted
    readonly property real volume: sink?.audio?.volume ?? 0

    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool micMuted: !!source?.audio?.muted
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool hasMic: source !== null

    function setVolume(v) {
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false
            sink.audio.volume = Math.max(0, Math.min(1, v))
        }
    }
    function toggleMute() {
        if (sink?.ready && sink?.audio) sink.audio.muted = !sink.audio.muted
    }

    // No `source?.ready` guard here (unlike the sink) — a suspended
    // PipeWire source node apparently never reports ready, even though
    // pactl can set its volume fine. Confirmed by testing: the guard was
    // silently blocking every drag on the mic slider.
    function setMicVolume(v) {
        if (source?.audio) source.audio.volume = Math.max(0, Math.min(1, v))
    }
    function toggleMicMute() {
        if (source?.audio) source.audio.muted = !source.audio.muted
    }

    property PwObjectTracker tracker: PwObjectTracker {
        objects: {
            var objs = []
            if (root.sink) objs.push(root.sink)
            if (root.source) objs.push(root.source)
            return objs
        }
    }
}
