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

    // idle → covering (the old wallpaper, held) → revealing → idle
    property string phase: "idle"
    property url fromArt: ""
    property url toArt: ""

    // How far the new wallpaper has taken over from the old one, 0..1. Every
    // style is a different reading of this one number, so the timing, the
    // guards and the teardown are shared and only the shape differs.
    property real grow: 0

    // ── Styles ───────────────────────────────────────────────────────────
    // A different one each time, because a transition you see twenty times a
    // day stops being a transition and starts being a delay.
    //
    //   grow   a circle out of the middle, past the corners
    //   wipe   a hard diagonal edge sweeping across
    //   push   the new wallpaper shoves the old one off the screen
    //
    // Deliberately not a fade: a fade through a half-drawn background is the
    // thing this whole surface exists to hide.
    readonly property var styles: ["grow", "wipe", "push"]
    property string style: "grow"

    // Never the same one twice running — with three of them, pure chance
    // repeats often enough to look like it is stuck.
    function pickStyle() {
        var next = root.styles[Math.floor(Math.random() * root.styles.length)]
        if (next === root.style)
            next = root.styles[(root.styles.indexOf(next) + 1) % root.styles.length]
        root.style = next
    }

    // begin(from, to) — art URLs, already resolved by WallpaperSource: a video
    // has no decodable frame of its own, so it arrives as its cached thumbnail.
    function begin(from, to) {
        if (!to)
            return
        root.fromArt = from
        root.toArt = to
        root.grow = 0
        root.pickStyle()
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
        width: root.width
        height: root.height
        // Only "push" moves it; the other two leave it still and uncover it.
        x: root.style === "push" ? -root.width * root.grow : 0
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
        width: root.width
        height: root.height
        x: root.style === "push" ? root.width * (1 - root.grow) : 0
        source: root.toArt
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        // "push" draws this directly — there is nothing to mask, the image
        // simply arrives from the right. The other two draw it through the
        // mask below instead.
        visible: root.style === "push" && status === Image.Ready
    }

    // The shape the new wallpaper arrives in. The mask is what makes it a
    // shape rather than a fade — the same MultiEffect masking the wallpaper
    // tiles use, driven by a growing geometry instead of a fixed rounded rect.
    Item {
        id: shapeMask
        anchors.fill: parent
        layer.enabled: true
        visible: false

        // The diagonal, not the width: a circle from the middle has to reach
        // the corners, and a diagonal wipe has to cross them.
        readonly property real span: Math.sqrt(root.width * root.width
                                               + root.height * root.height)

        // grow — a circle out of the middle.
        Rectangle {
            visible: root.style === "grow"
            width: shapeMask.span * root.grow
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: "black"
            antialiasing: true
        }

        // wipe — a hard edge crossing the screen at an angle. Oversized on
        // every side so the rotation cannot pull a corner out of the mask.
        Rectangle {
            visible: root.style === "wipe"
            height: shapeMask.span * 2
            width: shapeMask.span * 2 * root.grow
            // Anchored to where the sweep starts, off the left edge, so the
            // leading edge travels rather than the rectangle growing in place.
            x: -shapeMask.span / 2
            y: (root.height - height) / 2
            transformOrigin: Item.Left
            rotation: -12
            color: "black"
            antialiasing: true
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: toImg
        maskEnabled: true
        maskSource: shapeMask
        visible: root.style !== "push" && toImg.status === Image.Ready
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
