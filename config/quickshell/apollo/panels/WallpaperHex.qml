import QtQuick
import QtQuick.Shapes
import "../services"
import "wallpaper/Honeycomb.js" as Honeycomb

// Hexcomb: the wallpapers as an interlocking honeycomb, sized so the comb
// fills the screen rather than sitting in a corner of it.
//
// Ported from ujjalsigdel/hyprquickpaper's shell-hexcomb.qml, and the only
// layout whose interesting part is arithmetic rather than bindings. That part
// lives in wallpaper/Honeycomb.js and is exercised by scripts/test-honeycomb.js
// under node, because the edge cases are real and none of them are visible
// until they are wrong: a last row that reaches an offset column hangs half a
// row lower, a grid with fewer tiles than columns is only as wide as its
// tiles, and the last column's hexagon sticks out its full width past where a
// naive `columns × step` would put the right edge.
//
// The tiles are flat-top regular hexagons, so they are wider than they are
// tall and their columns interlock — each column starts three quarters of a
// tile along from the last, with every odd one dropped half a row into the
// notch.
Item {
    id: layout

    required property var wallpapers
    signal close()

    property bool backdrop: true
    property bool widgets: true

    property int selectedIndex: 0

    readonly property var base: ({
        cardW: 220,
        cardH: 220 * Honeycomb.RATIO,
        hSpacing: 6,
        vSpacing: 6,
        maxScale: 2.5
    })

    WallpaperBackdrop {
        anchors.fill: parent
        wallpapers: layout.wallpapers
        index: layout.selectedIndex
        blurred: layout.backdrop
    }

    Item {
        id: field
        anchors.fill: parent
        anchors.margins: 40
        anchors.topMargin: layout.widgets ? 80 : 40
        anchors.bottomMargin: layout.widgets ? 70 : 40
        clip: true

        readonly property var fit: Honeycomb.computeLayout(
            field.width, field.height, layout.wallpapers.count, layout.base)

        readonly property int columns: fit.columns
        readonly property real scale: fit.scale

        readonly property real cardW: layout.base.cardW * scale
        readonly property real cardH: layout.base.cardH * scale
        readonly property real colStep: cardW * 0.75 + layout.base.hSpacing * scale
        readonly property real rowStep: cardH + layout.base.vSpacing * scale

        readonly property var dims: Honeycomb.dimsFor(
            cardW, cardH, colStep, rowStep, columns, layout.wallpapers.count)

        // Centred by its real footprint, so the comb has an equal gap on every
        // side instead of being pinned to the top-left.
        readonly property real originX: Math.max(0, (field.width - dims.width) / 2)
        readonly property real originY: Math.max(0, (field.height - dims.height) / 2)

        Repeater {
            model: layout.wallpapers.model

            delegate: Item {
                id: tile

                required property int index
                required property string fileName
                required property string filePath
                required property url fileUrl

                readonly property bool isCurrent: tile.index === layout.selectedIndex
                readonly property var pos: Honeycomb.tilePos(
                    tile.index, field.columns, field.colStep, field.rowStep)

                x: field.originX + pos.x
                y: field.originY + pos.y
                width: field.cardW
                height: field.cardH
                z: tile.isCurrent ? 10 : 0

                Behavior on x      { NumberAnimation { duration: Motion.normal; easing.type: Easing.OutQuart } }
                Behavior on y      { NumberAnimation { duration: Motion.normal; easing.type: Easing.OutQuart } }
                Behavior on width  { NumberAnimation { duration: Motion.normal; easing.type: Easing.OutQuart } }
                Behavior on height { NumberAnimation { duration: Motion.normal; easing.type: Easing.OutQuart } }

                scale: tile.isCurrent ? 1.06 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.fastSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Motion.curveDefaultSpatial
                    }
                }

                // The silhouette the tile is cut to. A flat-top hexagon: the
                // flat edges are top and bottom, the points left and right at
                // half height.
                //
                // A Component, handed to the tile, which builds it inside its
                // own layered mask — see WallpaperTile.shape. It is sized by
                // anchoring, so it needs to know nothing about this delegate.
                Component {
                    id: hexShape
                    Shape {
                        ShapePath {
                            fillColor: "black"
                            strokeWidth: -1
                            startX: width * 0.25; startY: 0
                            PathLine { x: width * 0.75; y: 0 }
                            PathLine { x: width;        y: height * 0.5 }
                            PathLine { x: width * 0.75; y: height }
                            PathLine { x: width * 0.25; y: height }
                            PathLine { x: 0;            y: height * 0.5 }
                            PathLine { x: width * 0.25; y: 0 }
                        }
                    }
                }

                WallpaperTile {
                    anchors.fill: parent
                    wallpapers: layout.wallpapers
                    fileName: tile.fileName
                    fileUrl: tile.fileUrl
                    // The hexagon, not a rounded rectangle.
                    shape: hexShape
                    current: tile.isCurrent
                    animate: tile.isCurrent
                }

                // The same outline, stroked rather than filled, so it traces
                // the edge of the tile under it exactly.
                Shape {
                    anchors.fill: parent
                    opacity: tile.isCurrent ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: Motion.fastEffects } }
                    ShapePath {
                        fillColor: "transparent"
                        strokeWidth: 4
                        strokeColor: tile.filePath === layout.wallpapers.appliedPath
                                     ? Config.accent : Config.maroon
                        startX: tile.width * 0.25; startY: 0
                        PathLine { x: tile.width * 0.75; y: 0 }
                        PathLine { x: tile.width;        y: tile.height * 0.5 }
                        PathLine { x: tile.width * 0.75; y: tile.height }
                        PathLine { x: tile.width * 0.25; y: tile.height }
                        PathLine { x: 0;                 y: tile.height * 0.5 }
                        PathLine { x: tile.width * 0.25; y: 0 }
                    }
                }

                Rectangle {
                    visible: tile.filePath === layout.wallpapers.appliedPath
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: tile.height * 0.28
                    width: 22; height: 22; radius: 11
                    color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.85)
                    Text {
                        anchors.centerIn: parent
                        text: "󰄬"
                        color: Config.accent
                        font { pixelSize: 12; family: "JetBrainsMono Nerd Font Mono" }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (tile.isCurrent) {
                            layout.wallpapers.apply(tile.filePath)
                            layout.close()
                        } else {
                            layout.selectedIndex = tile.index
                        }
                    }
                }
            }
        }
    }

    Text {
        visible: layout.widgets
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        textFormat: Text.PlainText
        text: layout.wallpapers.count === 0
              ? "No wallpapers in " + layout.wallpapers.wallDir
              : layout.wallpapers.nameAt(layout.selectedIndex)
        color: Config.text
        font { pixelSize: 14; family: "JetBrainsMono Nerd Font Mono" }
        style: Text.Outline
        styleColor: "#AA000000"
    }

    // A comb moves in two dimensions: left and right step along a column,
    // up and down cross to the next one.
    function next() { if (layout.wallpapers.count > 0) layout.selectedIndex = (layout.selectedIndex + 1) % layout.wallpapers.count }
    function prev() { if (layout.wallpapers.count > 0) layout.selectedIndex = (layout.selectedIndex - 1 + layout.wallpapers.count) % layout.wallpapers.count }
    function nextRow() { if (layout.wallpapers.count > 0) layout.selectedIndex = Math.min(layout.wallpapers.count - 1, layout.selectedIndex + field.columns) }
    function prevRow() { if (layout.wallpapers.count > 0) layout.selectedIndex = Math.max(0, layout.selectedIndex - field.columns) }

    function activate() {
        var p = layout.wallpapers.pathAt(layout.selectedIndex)
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
            layout.selectedIndex = i >= 0 ? i : 0
        }
    }

    Connections {
        target: layout.wallpapers.model
        function onCountChanged() { syncTimer.restart() }
    }
}
