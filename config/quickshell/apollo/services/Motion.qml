pragma Singleton

import QtQuick
import Quickshell

// One motion vocabulary for the shell.
//
// Every panel used to open with the same line — opacity 0→1, 200ms, OutCubic —
// which is a fade, and a fade says nothing about where the thing came from.
// These are Material 3 expressive durations and curves as Caelestia's shell
// spells them (caelestia-dots/shell, Config/tokens.hpp), so a panel grows out
// of the bar edge you clicked and settles.
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

    // ── Where a panel grows from ─────────────────────────────────────────
    // The edge the bar is on, so a popout looks like it unfolded from the icon
    // that was clicked rather than appearing in the middle of itself. That edge
    // then stays put for the whole animation, which is the part that sells it.
    //
    // Takes the position rather than reading Config itself: no singleton here
    // reaches for another one today, and every caller already has Config in
    // scope. Callers pass Config.barPosition.
    function originFor(barPosition) {
        if (barPosition === "left")  return Item.Left
        if (barPosition === "right") return Item.Right
        return Item.Top
    }

    // How small a card starts. Far enough to read as growth, near enough that
    // text is never scaled down to the point of shimmering.
    readonly property real fromScale: 0.90
}
