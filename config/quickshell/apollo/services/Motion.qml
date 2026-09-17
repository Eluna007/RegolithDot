pragma Singleton

import QtQuick
import Quickshell

// One motion vocabulary for the shell.
//
// Every panel used to open with the same line — `NumberAnimation on opacity
// { from: 0; to: 1; duration: 200; running: true }`. Two things were wrong
// with it. A fade says nothing about where the thing came from; and a
// NumberAnimation-on-property starts at component completion, so since
// shell.qml creates every panel eagerly and toggles it with `visible`, all of
// them played once at login to a hidden surface and were never seen again.
//
// These are Material 3 expressive durations and curves as Caelestia's shell
// spells them (caelestia-dots/shell, Config/tokens.hpp). Each panel now carries
// a `reveal` property animated `running: root.visible`, and a bar popout binds
// its card height to it: the card is *uncovered* out of the bar edge by its own
// clip, so the text arrives at full size rather than scaled up out of a blur.
// That is what makes it look attached to the bar rather than next to it.
//
// The reveal is vertical whatever edge the bar is on. A horizontal wipe would
// animate the card's width, and every ColumnLayout inside is `width:
// parent.width` — the text would re-wrap on every frame.
//
// The spatial curves overshoot their target. Measured peaks, sampling the
// cubic at 4001 points:
//
//   curveStandard          1.0000   no overshoot
//   curveDefaultEffects    1.0000   no overshoot
//   curveDefaultSpatial    1.0139   +1.4%, peaking at 56% of the way through
//   curveFastSpatial       1.0921   +9.2%, peaking at 39%
//
// That matters for clipping: the overshoot applies to the animated *range*,
// not to the final value. A scale running 0.90 → 1.00 on curveDefaultSpatial
// peaks at 0.90 + 0.10 × 1.0139 = 1.0014 — half a pixel on a 360px card — so
// a panel card can spring inside its existing surface without any of it being
// cut off. Swapping in curveFastSpatial would make that 1.009, about 3px, and
// would want checking against each panel's spare room first.
Singleton {
    id: root

    // ── Durations ────────────────────────────────────────────────────────
    readonly property int fastEffects: 150
    readonly property int effects: 200
    readonly property int slowEffects: 300
    readonly property int fastSpatial: 350
    readonly property int spatial: 500
    readonly property int slowSpatial: 650
    readonly property int small: 200
    readonly property int normal: 400

    // ── Curves ───────────────────────────────────────────────────────────
    // easing.type must be Easing.Bezier for these to be read.
    readonly property var curveStandard: [0.2, 0, 0, 1, 1, 1]
    readonly property var curveEmphasized: [0.05, 0, 0.133333, 0.06, 0.166667, 0.4,
                                            0.208333, 0.82, 0.25, 1, 1, 1]
    readonly property var curveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var curveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var curveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
    readonly property var curveFastEffects: [0.31, 0.94, 0.34, 1, 1, 1]
    readonly property var curveDefaultEffects: [0.34, 0.8, 0.34, 1, 1, 1]
    readonly property var curveSlowEffects: [0.34, 0.88, 0.34, 1, 1, 1]

    // How small a centred sheet starts — the launcher, the cheatsheet, the
    // wallpaper picker. Far enough to read as growth, near enough that text is
    // never scaled down to the point of shimmering. Bar popouts do not use it:
    // they are revealed, not scaled.
    //
    // There was an originFor(barPosition) here returning Item.Left/Right/Top
    // for a scale transform. The reveal replaced it, and an unused helper in a
    // singleton is just a thing to keep true.
    readonly property real fromScale: 0.90
}
