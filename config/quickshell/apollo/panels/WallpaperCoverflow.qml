import QtQuick
import QtQuick.Effects
import "../services"

// Coverflow: sheared cards fanning out from the focused one, over a blurred,
// darkened copy of whatever is selected.
//
// Ported from ujjalsigdel/hyprquickpaper's shell-coverflow.qml. What is theirs
// is the geometry — the per-offset scale ramp, the parallelogram shear, and
// cumulativeOffset(), which spaces the cards by their *drawn* widths so the gap
// between every pair is the same however much they differ in scale. Laying them
// out at a fixed pitch instead leaves the small cards adrift and the big ones
// overlapping.
//
// What is ours is everything underneath: the model, the thumbnails and the
// apply path all come from WallpaperSource, and the colours are the palette
// rather than the single border_color their config.json carries — so this
// follows your accent and flavour like the rest of the shell.
Item {
    id: layout

    required property var wallpapers
    // The panel owns dismissal; a layout only ever asks for it.
    signal close()

    property alias currentIndex: view.currentIndex

    // ── Geometry (theirs) ────────────────────────────────────────────────
    readonly property real cardW: 190
    readonly property real cardH: 340
    readonly property real centerScale: 1.15
    readonly property real edgeScale: 0.55
    readonly property real gapPx: 20
    readonly property real skewFactor: -0.18

    function scaleForOffset(offset) {
        var a = Math.abs(offset)
        if (a === 0) return layout.centerScale
        if (a === 1) return 0.9
        if (a === 2) return 0.75
        if (a === 3) return 0.7
        if (a === 4) return 0.62
        return layout.edgeScale
    }

    // The distance between the card at offset o and the one after it: half of
    // each card's drawn width, plus what the shear adds when their scales
    // differ, plus a constant gap.
    function stepBetween(o) {
        var sA = layout.scaleForOffset(o)
        var sB = layout.scaleForOffset(o + 1)
        var widthTerm = (sA + sB) * layout.cardW / 2
        var shearTerm = Math.abs(layout.skewFactor) * layout.cardH * Math.abs(sA - sB) / 2
        return widthTerm + shearTerm + layout.gapPx
    }

    function cumulativeOffset(n) {
        var steps = Math.abs(n)
        var sum = 0
        for (var i = 0; i < steps; i++)
            sum += layout.stepBetween(i)
        return n < 0 ? -sum : sum
    }

    // ── Variants ─────────────────────────────────────────────────────────
    // Upstream ships coverflow, coverflow-clear and coverflow-minimal as three
    // near-identical shell.qml files — 531, 553 and 406 lines differing by
    // about ninety. Here they are the same layout with two switches, passed in
    // by the panel's Loader. The blur is the expensive one, and turning it off
    // is upstream's own advice for a GPU that cannot keep it smooth.
    property bool backdrop: true
    property bool widgets: true

    WallpaperBackdrop {
        anchors.fill: parent
        wallpapers: layout.wallpapers
        index: view.currentIndex
        blurred: layout.backdrop
    }

    // ── Cards ────────────────────────────────────────────────────────────
    PathView {
        id: view
        anchors.fill: parent
        interactive: false

        model: layout.wallpapers.model
        pathItemCount: 11
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        // 150ms made the cards jump rather than travel — at this size the
        // movement is most of what the layout is, so it gets the slower step.
        highlightMoveDuration: Motion.slowEffects
        // Keep delegates alive off the path: it otherwise destroys and
        // recreates — and re-decodes — the same cards on the way past.
        cacheItemCount: 6

        path: Path {
            startX: view.width / 2 + layout.cumulativeOffset(-5)
            startY: view.height / 2
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(-5) }
            PathAttribute { name: "iOpacity"; value: 0.0 }
            PathAttribute { name: "iZ";       value: 0 }
            PathPercent { value: 0.0 }

            PathLine { x: view.width / 2 + layout.cumulativeOffset(-4); y: view.height / 2 }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(-4) }
            PathAttribute { name: "iOpacity"; value: 0.4 }
            PathAttribute { name: "iZ";       value: 20 }
            PathPercent { value: 0.1 }

            PathLine { x: view.width / 2 + layout.cumulativeOffset(-3); y: view.height / 2 }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(-3) }
            PathAttribute { name: "iOpacity"; value: 0.65 }
            PathAttribute { name: "iZ";       value: 40 }
            PathPercent { value: 0.2 }

            PathLine { x: view.width / 2 + layout.cumulativeOffset(-2); y: view.height / 2 }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(-2) }
            PathAttribute { name: "iOpacity"; value: 0.85 }
            PathAttribute { name: "iZ";       value: 60 }
            PathPercent { value: 0.3 }

            PathLine { x: view.width / 2 + layout.cumulativeOffset(-1); y: view.height / 2 }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(-1) }
            PathAttribute { name: "iOpacity"; value: 1.0 }
            PathAttribute { name: "iZ";       value: 80 }
            PathPercent { value: 0.4 }

            PathLine { x: view.width / 2; y: view.height / 2 }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(0) }
            PathAttribute { name: "iOpacity"; value: 1.0 }
            PathAttribute { name: "iZ";       value: 100 }
            PathPercent { value: 0.5 }

            PathLine { x: view.width / 2 + layout.cumulativeOffset(1); y: view.height / 2 }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(1) }
            PathAttribute { name: "iOpacity"; value: 1.0 }
            PathAttribute { name: "iZ";       value: 80 }
            PathPercent { value: 0.6 }

            PathLine { x: view.width / 2 + layout.cumulativeOffset(2); y: view.height / 2 }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(2) }
            PathAttribute { name: "iOpacity"; value: 0.85 }
            PathAttribute { name: "iZ";       value: 60 }
            PathPercent { value: 0.7 }

            PathLine { x: view.width / 2 + layout.cumulativeOffset(3); y: view.height / 2 }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(3) }
            PathAttribute { name: "iOpacity"; value: 0.65 }
            PathAttribute { name: "iZ";       value: 40 }
            PathPercent { value: 0.8 }

            PathLine { x: view.width / 2 + layout.cumulativeOffset(4); y: view.height / 2 }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(4) }
            PathAttribute { name: "iOpacity"; value: 0.4 }
            PathAttribute { name: "iZ";       value: 20 }
            PathPercent { value: 0.9 }

            PathLine { x: view.width / 2 + layout.cumulativeOffset(5); y: view.height / 2 }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(5) }
            PathAttribute { name: "iOpacity"; value: 0.0 }
            PathAttribute { name: "iZ";       value: 0 }
            PathPercent { value: 1.0 }
        }

        delegate: Item {
            id: card

            required property int index
            required property string fileName
            required property string filePath
            required property url fileUrl

            width: layout.cardW
            height: layout.cardH

            // Read on the delegate root, then passed down. PathView's attached
            // properties only exist on the root of a delegate — referenced
            // from a child they silently create a fresh, unattached object and
            // read as undefined, so the focused card would never highlight.
            readonly property bool isCurrent: card.PathView.isCurrentItem

            scale:   card.PathView.iScale   ?? layout.edgeScale
            opacity: card.PathView.iOpacity ?? 0.0
            z:       card.PathView.iZ       ?? 0

            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(
                    1, layout.skewFactor, 0, -layout.skewFactor * layout.cardH / 2,
                    0, 1, 0, 0,
                    0, 0, 1, 0,
                    0, 0, 0, 1)
            }

            WallpaperTile {
                anchors.fill: parent
                wallpapers: layout.wallpapers
                fileName: card.fileName
                fileUrl: card.fileUrl
                radius: 8
                current: card.isCurrent
                animate: card.isCurrent
            }

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: "transparent"
                antialiasing: true
                border.width: card.isCurrent ? 3 : 1
                border.color: card.isCurrent
                              ? (card.filePath === layout.wallpapers.appliedPath
                                 ? Config.accent : Config.maroon)
                              : Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.12)
                Behavior on border.color { ColorAnimation { duration: Motion.fastEffects } }
            }

            // The wallpaper that is actually set, marked so the picker is not
            // just a list of files you have to remember your way around.
            Rectangle {
                visible: card.filePath === layout.wallpapers.appliedPath
                anchors { top: parent.top; right: parent.right; margins: 8 }
                width: 26; height: 26; radius: 13
                color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.85)
                Text {
                    anchors.centerIn: parent
                    text: "󰄬"
                    color: Config.accent
                    font { pixelSize: 14; family: "JetBrainsMono Nerd Font Mono" }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (view.currentIndex === card.index) {
                        layout.wallpapers.apply(card.filePath)
                        layout.close()
                    } else {
                        view.currentIndex = card.index
                    }
                }
            }
        }
    }

    // The name of the focused wallpaper. Upstream puts this in a widget layer
    // that only some layouts carry; here it is the one bit of chrome coverflow
    // has, so it lives with the layout rather than in the panel.
    Text {
        visible: layout.widgets
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(parent.height * 0.10)
        text: layout.wallpapers.count === 0
              ? "No wallpapers in " + layout.wallpapers.wallDir
              : layout.wallpapers.nameAt(view.currentIndex)
        color: Config.text
        font { pixelSize: 13; family: "JetBrainsMono Nerd Font Mono" }
        style: Text.Outline
        styleColor: "#AA000000"
    }

    // Opening on the wallpaper you are using, not at the start of the list.
    // A Timer, because FolderListModel reports its count before the rows are
    // actually addressable and positionViewAtIndex on an empty view is a no-op.
    Timer {
        id: syncTimer
        interval: 50
        onTriggered: {
            if (layout.wallpapers.count === 0)
                return
            var i = layout.wallpapers.indexOfApplied()
            view.currentIndex = i >= 0 ? i : 0
            view.positionViewAtIndex(view.currentIndex, PathView.Center)
        }
    }

    Connections {
        target: layout.wallpapers.model
        function onCountChanged() { syncTimer.restart() }
    }

    function syncToApplied() { syncTimer.restart() }

    function next() { view.incrementCurrentIndex() }
    function prev() { view.decrementCurrentIndex() }
    function activate() {
        var p = layout.wallpapers.pathAt(view.currentIndex)
        if (p) {
            layout.wallpapers.apply(p)
            layout.close()
        }
    }
}
