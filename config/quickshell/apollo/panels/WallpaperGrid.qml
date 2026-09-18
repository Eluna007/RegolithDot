import QtQuick
import "../services"

// Grid: a wall of thumbnails on the left, a large preview of the selection on
// the right. The fastest of the layouts to scan when the folder is big, and
// the lightest on the GPU — nothing is scaled, sheared or fanned.
//
// Ported from ujjalsigdel/hyprquickpaper's shell-grid-view.qml: the split, the
// three columns of 16:9 cells, and the preview panel are theirs. It is also
// the layout that proves the shared base is not PathView-shaped — everything
// underneath is the same WallpaperSource the carousels use, driving a GridView
// instead.
Item {
    id: layout

    required property var wallpapers
    signal close()

    property bool backdrop: true

    readonly property real listWidth: width * 0.40
    readonly property real outerMargin: 32
    readonly property int columns: 3
    readonly property real cellW: Math.floor((layout.listWidth - outerMargin * 2) / columns)
    readonly property real cellH: cellW * 9 / 16

    WallpaperBackdrop {
        anchors.fill: parent
        wallpapers: layout.wallpapers
        index: grid.currentIndex
        blurred: layout.backdrop
    }

    // ── The wall ─────────────────────────────────────────────────────────
    GridView {
        id: grid
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
            margins: layout.outerMargin
        }
        width: layout.listWidth - layout.outerMargin * 2
        clip: true

        cellWidth: layout.cellW
        cellHeight: layout.cellH
        model: layout.wallpapers.model
        // Keep a screenful either side alive rather than rebuilding — and
        // re-decoding — them on every scroll.
        cacheBuffer: Math.round(layout.cellH * 6)

        delegate: Item {
            id: cell

            required property int index
            required property string fileName
            required property string filePath
            required property url fileUrl

            readonly property bool isCurrent: cell.index === grid.currentIndex

            width: grid.cellWidth
            height: grid.cellHeight

            Item {
                anchors.fill: parent
                anchors.margins: 5

                WallpaperTile {
                    anchors.fill: parent
                    wallpapers: layout.wallpapers
                    fileName: cell.fileName
                    fileUrl: cell.fileUrl
                    radius: 10
                    current: cell.isCurrent
                    animate: cell.isCurrent
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: "transparent"
                    antialiasing: true
                    border.width: cell.isCurrent ? 3 : 1
                    border.color: cell.isCurrent
                                  ? (cell.filePath === layout.wallpapers.appliedPath
                                     ? Config.accent : Config.maroon)
                                  : Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.12)
                    Behavior on border.color { ColorAnimation { duration: Motion.fastEffects } }
                }

                Rectangle {
                    visible: cell.filePath === layout.wallpapers.appliedPath
                    anchors { top: parent.top; right: parent.right; margins: 5 }
                    width: 20; height: 20; radius: 10
                    color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.85)
                    Text {
                        anchors.centerIn: parent
                        text: "󰄬"
                        color: Config.accent
                        font { pixelSize: 11; family: "JetBrainsMono Nerd Font Mono" }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (grid.currentIndex === cell.index) {
                        layout.wallpapers.apply(cell.filePath)
                        layout.close()
                    } else {
                        grid.currentIndex = cell.index
                    }
                }
            }
        }
    }

    // ── The preview ──────────────────────────────────────────────────────
    Item {
        anchors {
            left: parent.left
            leftMargin: layout.listWidth
            right: parent.right
            top: parent.top
            bottom: parent.bottom
            margins: 0
        }

        Column {
            anchors.centerIn: parent
            spacing: 18
            width: parent.width * 0.8

            Item {
                width: parent.width
                height: width * 9 / 16

                WallpaperTile {
                    id: preview
                    anchors.fill: parent
                    wallpapers: layout.wallpapers
                    fileName: layout.wallpapers.nameAt(grid.currentIndex)
                    fileUrl: {
                        var p = layout.wallpapers.pathAt(grid.currentIndex)
                        return p ? "file://" + p : ""
                    }
                    radius: 18
                    current: true
                    // The preview is the one place a gif should play: it is
                    // large, it is what you are deciding about, and there is
                    // exactly one of it.
                    animate: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    color: "transparent"
                    antialiasing: true
                    border.width: 1
                    border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.15)
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                textFormat: Text.PlainText
                text: layout.wallpapers.count === 0
                      ? "No wallpapers in " + layout.wallpapers.wallDir
                      : layout.wallpapers.nameAt(grid.currentIndex)
                color: Config.text
                font { pixelSize: 15; bold: true; family: "JetBrainsMono Nerd Font Mono" }
                style: Text.Outline
                styleColor: "#AA000000"
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: (grid.currentIndex + 1) + " of " + layout.wallpapers.count
                      + "   ·   enter to apply"
                color: Config.subtext0
                font { pixelSize: 11; family: "JetBrainsMono Nerd Font Mono" }
            }
        }
    }

    // ── The contract every layout keeps ──────────────────────────────────
    // A grid moves in two dimensions, so next/prev step by one and the panel's
    // up/down reach the row above and below.
    function next() { if (layout.wallpapers.count > 0) grid.currentIndex = (grid.currentIndex + 1) % layout.wallpapers.count }
    function prev() { if (layout.wallpapers.count > 0) grid.currentIndex = (grid.currentIndex - 1 + layout.wallpapers.count) % layout.wallpapers.count }
    function nextRow() { if (layout.wallpapers.count > 0) grid.currentIndex = Math.min(layout.wallpapers.count - 1, grid.currentIndex + layout.columns) }
    function prevRow() { if (layout.wallpapers.count > 0) grid.currentIndex = Math.max(0, grid.currentIndex - layout.columns) }

    function activate() {
        var p = layout.wallpapers.pathAt(grid.currentIndex)
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
            grid.currentIndex = i >= 0 ? i : 0
            grid.positionViewAtIndex(grid.currentIndex, GridView.Center)
        }
    }

    Connections {
        target: layout.wallpapers.model
        function onCountChanged() { syncTimer.restart() }
    }
}
