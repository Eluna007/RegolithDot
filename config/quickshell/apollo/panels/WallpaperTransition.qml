import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../services"

// The wallpaper change, drawn by us instead of glimpsed between daemons.
//
// wallpaper-switch.sh already starts the incoming daemon before retiring the
// outgoing one, which removed most of the flash. What it cannot remove is the
// gap between a daemon *accepting* a wallpaper and actually drawing it:
// hyprpaper's IPC answers when the request is queued, not when the image is on
// screen, and mpvpaper has nothing to ask at all. For those few frames the
// background layer has nothing in it and the compositor's own default shows
// through.
//
// So this covers the whole screen with the outgoing wallpaper for the duration
// of the swap, and hands over with a circular grow instead of a cut. Whatever
// the daemons do underneath happens out of sight, and what you see is one
// deliberate transition rather than a blink of somebody else's wallpaper.
//
// It sits on Bottom, so it is above the wallpaper and below every window — a
// switch while you are working shows only in the gaps, which is where a
// wallpaper shows anyway. See panels/Desktop.qml for the other four properties
// a full-screen decorative layer needs and why.
PanelWindow {
    id: root

    // "idle" means the surface is never mapped at all: nothing to composite,
    // nothing to blur, no input region to get wrong.
    readonly property bool busy: root.phase !== "idle"
    visible: root.busy

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    // Not "quickshell": rules.lua blurs that namespace, and blurring a surface
    // that sits on the wallpaper would blur the wallpaper through it.
    WlrLayershell.namespace: "apollo-wallpaper-transition"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Decorative only: every click goes through to whatever is behind it.
    mask: Region {}

    // idle → covering (the old wallpaper, held) → revealing (the grow) → idle
    property string phase: "idle"
    property url fromArt: ""
    property url toArt: ""

    // How far the new wallpaper has grown over the old one, 0..1.
    property real grow: 0

    // begin(from, to) — art URLs, already resolved by WallpaperSource: a video
    // has no decodable frame of its own, so it arrives as its cached thumbnail.
    function begin(from, to) {
        if (!to)
            return
        root.fromArt = from
        root.toArt = to
        root.grow = 0
        root.phase = "covering"
        coverTimeout.restart()

        // Already loaded — either the same wallpaper again, or one Qt had in
        // hand. onStatusChanged only fires on a *change*, so waiting for it
        // here would hold the cover up until the timeout, which is a frozen
        // desktop for six seconds.
        if (toImg.status === Image.Ready)
            root.phase = "revealing"
    }

    function finish() {
        root.phase = "idle"
        root.grow = 0
        holdTimer.stop()
        coverTimeout.stop()
    }

    // ── The old wallpaper, held ──────────────────────────────────────────
    Image {
        id: fromImg
        anchors.fill: parent
        source: root.fromArt
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        // Until this has loaded there is nothing to cover with, and covering
        // with a blank surface would be the very thing this exists to prevent.
        visible: status === Image.Ready
    }

    // A wallpaper with nothing before it (the first change after login) has no
    // outgoing image. Rather than show the compositor through, hold the
    // palette's own background — it is one flat colour from the rice instead
    // of somebody else's default.
    Rectangle {
        anchors.fill: parent
        color: Config.base
        visible: fromImg.status !== Image.Ready
        z: -1
    }

    // ── The new wallpaper, growing in ────────────────────────────────────
    Image {
        id: toImg
        anchors.fill: parent
        source: root.toArt
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        visible: false
    }

    // A circle from the middle, out past the corners. The mask is what makes it
    // a shape rather than a fade — the same MultiEffect masking the wallpaper
    // tiles use, driven by a growing radius instead of a fixed rounded rect.
    Item {
        id: growMask
        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            // Far enough to reach the corners: the diagonal, not the width.
            readonly property real full: Math.sqrt(root.width * root.width
                                                   + root.height * root.height)
            width: full * root.grow
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: "black"
            antialiasing: true
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: toImg
        maskEnabled: true
        maskSource: growMask
        visible: toImg.status === Image.Ready
    }

    // ── Timing ───────────────────────────────────────────────────────────
    // The grow starts once the incoming art is ready, so it never animates to
    // an image that has not arrived.
    Connections {
        target: toImg
        function onStatusChanged() {
            if (toImg.status === Image.Ready && root.phase === "covering")
                root.phase = "revealing"
        }
    }

    NumberAnimation {
        target: root
        property: "grow"
        from: 0
        to: 1
        duration: Motion.slowSpatial
        easing.type: Easing.Bezier
        easing.bezierCurve: Motion.curveEmphasized
        running: root.phase === "revealing"
        onFinished: holdTimer.restart()
    }

    // Hold the finished picture a moment before unmapping. The daemon
    // underneath is still catching up — hyprpaper is decoding, or mpvpaper is
    // putting its surface up and waiting to be handed the screen — and
    // uncovering the instant the animation ends would show exactly the gap
    // this exists to hide.
    Timer {
        id: holdTimer
        interval: 900
        onTriggered: root.finish()
    }

    // Nothing arrived. A wallpaper that cannot be decoded, a path that has gone
    // — whatever the reason, an overlay that stays up forever would be a
    // desktop you cannot use, so it always has an end.
    Timer {
        id: coverTimeout
        interval: 6000
        onTriggered: root.finish()
    }
}
