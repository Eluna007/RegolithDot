import QtQuick
import QtQuick.Effects
import "../services"

// One wallpaper, drawn. Shared by every picker layout so the awkward parts —
// which of three types this file is, whether its thumbnail exists yet, and
// what to show while it does not — are solved once.
Item {
    id: tile

    required property var wallpapers   // the WallpaperSource
    required property string fileName
    required property url fileUrl

    property int radius: 16

    // An alternative silhouette. A layout that is not made of rectangles —
    // the honeycomb — hands in its own mask item and gets the wallpaper cut to
    // that shape instead. Left unset, the rounded rectangle below is used, so
    // every other layout is unaffected.
    property Item shape: null
    property bool current: false
    // Only the focused tile animates its gif: decoding several at once is real
    // work for tiles nobody is looking at.
    property bool animate: false

    readonly property bool isVideo: tile.wallpapers.isVideo(tile.fileName)
    readonly property bool isGif:   tile.wallpapers.isGif(tile.fileName)

    // Thumbnails are made in the background, so the first time the picker opens
    // on a new folder there may be none yet. Falling back to the original means
    // a tile is never *worse* than it was before the cache existed — just
    // slower, until it catches up.
    property bool thumbFailed: false
    Connections {
        target: tile.wallpapers
        // A new batch has landed: give the thumbnail another go rather than
        // staying on the original until the panel is next opened.
        function onThumbsRevChanged() { tile.thumbFailed = false }
    }

    readonly property url thumbUrl: {
        tile.wallpapers.thumbsRev   // re-read once the thumbnails have been made
        return tile.wallpapers.thumbFor(tile.fileName)
    }

    readonly property int artStatus: tile.isGif ? gif.status : still.status

    // Shows through any letterboxing, and is what a tile looks like before its
    // picture arrives.
    // Shows through any letterboxing, and is what a tile looks like before its
    // picture arrives. Hidden when the layout supplies its own shape, since a
    // rounded rectangle behind a hexagon is a rounded rectangle you can see.
    Rectangle {
        anchors.fill: parent
        radius: tile.radius
        color: Config.mantle
        visible: !tile.shape
    }

    Image {
        id: still
        anchors.fill: parent
        // A gif is drawn by the AnimatedImage below, so this is given nothing
        // to load. A video has only its cached frame — Image cannot decode the
        // file itself, so there is nothing to fall back to. A still image
        // prefers its thumbnail and falls back to the original.
        source: {
            if (tile.isGif) return ""
            if (tile.isVideo) return tile.thumbUrl
            return tile.thumbFailed ? tile.fileUrl : tile.thumbUrl
        }
        onStatusChanged: {
            if (status === Image.Error && !tile.isVideo && !tile.thumbFailed)
                tile.thumbFailed = true
        }
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        // sourceSize bounds what is kept, not what is read: a 4K PNG or WebP is
        // decoded whole (eight million pixels, 32 MB) before being scaled down
        // to this. Only JPEG can decode at a reduced scale. That is why the
        // cached thumbnails exist at all, and why this is a safety net rather
        // than the fix.
        sourceSize.width: 400
        visible: false
    }

    // Image renders exactly one frame of a gif, which is why they looked like
    // stills that would not play.
    AnimatedImage {
        id: gif
        anchors.fill: parent
        source: tile.isGif ? tile.fileUrl : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        playing: tile.isGif && tile.animate
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: tile.isGif ? gif : still
        maskEnabled: true
        maskSource: tile.shape ? tile.shape : mask
        // Nothing to mask until there is something to draw, and an effect over
        // an unloaded source paints a grey rectangle that reads as a broken
        // wallpaper.
        visible: tile.artStatus === Image.Ready
    }

    Item {
        id: mask
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle { anchors.fill: parent; radius: tile.radius; color: "black"; antialiasing: true }
    }

    // What a tile shows when the picture is not there: still loading, or
    // genuinely unreadable. Without this the two are indistinguishable — both
    // are an empty frame, and a wallpaper that never appears looks like a
    // picker that is still working.
    Column {
        anchors.centerIn: parent
        spacing: 6
        visible: tile.artStatus !== Image.Ready

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.isVideo ? "󰕧" : "󰋩"
            color: Config.overlay0
            font { pixelSize: 26; family: "JetBrainsMono Nerd Font Mono" }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            // Only once it has actually failed: saying "no frame yet" at every
            // tile while they load would be its own kind of wrong.
            visible: tile.artStatus === Image.Error
            text: tile.isVideo ? "no frame yet" : "can't preview"
            color: Config.overlay0
            font { pixelSize: 10; family: "JetBrainsMono Nerd Font Mono" }
        }
    }
}
