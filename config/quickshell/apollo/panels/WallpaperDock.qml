import QtQuick
import "../services"

// Dock: a deck of sheared cards along the bottom edge, the focused one scaled
// up. Leaves the top three-quarters of the screen showing the wallpaper you
// are choosing, which is the argument for it.
//
// Ported from ujjalsigdel/hyprquickpaper's shell-bottom-dock.qml. The shear and
// the uniform card height are theirs; the spacing is the same drawn-width
// arithmetic coverflow uses, so cards at different scales still sit an equal
// gap apart.
Item {
    id: layout

    required property var wallpapers
    signal close()

    property bool backdrop: true
    property bool widgets: true

    readonly property real cardW: 210
    readonly property real cardH: 130
    readonly property real centerScale: 1.25
    readonly property real edgeScale: 0.8
    readonly property real gapPx: 16
    readonly property real skewFactor: -0.22

    function scaleForOffset(offset) {
        var a = Math.abs(offset)
        if (a === 0) return layout.centerScale
        if (a === 1) return 1.0
        if (a === 2) return 0.92
        return layout.edgeScale
    }

    // Same arithmetic as coverflow: half of each card's drawn width, plus what
    // the shear adds where their scales differ, plus a constant gap. A fixed
    // pitch instead leaves the small cards adrift and the big ones overlapping.
    function stepBetween(o) {
        var sA = layout.scaleForOffset(o)
        var sB = layout.scaleForOffset(o + 1)
        return (sA + sB) * layout.cardW / 2
             + Math.abs(layout.skewFactor) * layout.cardH * Math.abs(sA - sB) / 2
             + layout.gapPx
    }

    function cumulativeOffset(n) {
        var sum = 0
        for (var i = 0; i < Math.abs(n); i++)
            sum += layout.stepBetween(i)
        return n < 0 ? -sum : sum
    }

    WallpaperBackdrop {
        anchors.fill: parent
        wallpapers: layout.wallpapers
        index: view.currentIndex
        blurred: layout.backdrop
    }

    // The name of the focused wallpaper, above the deck.
    Text {
        visible: layout.widgets
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(parent.height * 0.30)
        textFormat: Text.PlainText
        text: layout.wallpapers.count === 0
              ? "No wallpapers in " + layout.wallpapers.wallDir
              : layout.wallpapers.nameAt(view.currentIndex)
        color: Config.text
        font { pixelSize: 16; bold: true; family: "JetBrainsMono Nerd Font Mono" }
        style: Text.Outline
        styleColor: "#AA000000"
    }

    PathView {
        id: view
        anchors.fill: parent
        interactive: false

        model: layout.wallpapers.model
        pathItemCount: 9
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        highlightMoveDuration: Motion.slowEffects
        cacheItemCount: 6

        // Sat low, so the wallpaper above it is what you are looking at.
        readonly property real deckY: view.height * 0.80

        path: Path {
            startX: view.width / 2 + layout.cumulativeOffset(-4)
            startY: view.deckY
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(-4) }
            PathAttribute { name: "iOpacity"; value: 0.0 }
            PathAttribute { name: "iZ";       value: 0 }
            PathPercent { value: 0.0 }

            PathLine { x: view.width / 2 + layout.cumulativeOffset(-3); y: view.deckY }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(-3) }
            PathAttribute { name: "iOpacity"; value: 0.5 }
            PathAttribute { name: "iZ";       value: 20 }
            PathPercent { value: 0.125 }

            PathLine { x: view.width / 2 + layout.cumulativeOffset(-2); y: view.deckY }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(-2) }
            PathAttribute { name: "iOpacity"; value: 0.8 }
            PathAttribute { name: "iZ";       value: 40 }
            PathPercent { value: 0.25 }

            PathLine { x: view.width / 2 + layout.cumulativeOffset(-1); y: view.deckY }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(-1) }
            PathAttribute { name: "iOpacity"; value: 1.0 }
            PathAttribute { name: "iZ";       value: 60 }
            PathPercent { value: 0.375 }

            PathLine { x: view.width / 2; y: view.deckY }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(0) }
            PathAttribute { name: "iOpacity"; value: 1.0 }
            PathAttribute { name: "iZ";       value: 100 }
            PathPercent { value: 0.5 }

            PathLine { x: view.width / 2 + layout.cumulativeOffset(1); y: view.deckY }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(1) }
            PathAttribute { name: "iOpacity"; value: 1.0 }
            PathAttribute { name: "iZ";       value: 60 }
            PathPercent { value: 0.625 }

            PathLine { x: view.width / 2 + layout.cumulativeOffset(2); y: view.deckY }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(2) }
            PathAttribute { name: "iOpacity"; value: 0.8 }
            PathAttribute { name: "iZ";       value: 40 }
            PathPercent { value: 0.75 }

            PathLine { x: view.width / 2 + layout.cumulativeOffset(3); y: view.deckY }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(3) }
            PathAttribute { name: "iOpacity"; value: 0.5 }
            PathAttribute { name: "iZ";       value: 20 }
            PathPercent { value: 0.875 }

            PathLine { x: view.width / 2 + layout.cumulativeOffset(4); y: view.deckY }
            PathAttribute { name: "iScale";   value: layout.scaleForOffset(4) }
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

            // Read on the delegate root: PathView's attached properties only
            // exist there, and from a child they read as undefined.
            readonly property bool isCurrent: card.PathView.isCurrentItem

            width: layout.cardW
            height: layout.cardH

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
                radius: 6
                current: card.isCurrent
                animate: card.isCurrent
            }

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: "transparent"
                antialiasing: true
                border.width: card.isCurrent ? 3 : 1
                border.color: card.isCurrent
                              ? (card.filePath === layout.wallpapers.appliedPath
                                 ? Config.accent : Config.maroon)
                              : Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.12)
                Behavior on border.color { ColorAnimation { duration: Motion.fastEffects } }
            }

            Rectangle {
                visible: card.filePath === layout.wallpapers.appliedPath
                anchors { top: parent.top; right: parent.right; margins: 6 }
                width: 20; height: 20; radius: 10
                color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.85)
                Text {
                    anchors.centerIn: parent
                    text: "󰄬"
                    color: Config.accent
                    font { pixelSize: 11; family: "JetBrainsMono Nerd Font Mono" }
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

    function next() { view.incrementCurrentIndex() }
    function prev() { view.decrementCurrentIndex() }
    function activate() {
        var p = layout.wallpapers.pathAt(view.currentIndex)
        if (p) {
            layout.wallpapers.apply(p)
            layout.close()
        }
    }

    function syncToApplied() { syncTimer.restart() }

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
}
