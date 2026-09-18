import QtQuick
import QtQuick.Effects
import "../services"

// The selected wallpaper, blurred and darkened behind a picker layout.
//
// Shared rather than copied because the interesting part is not the blur, it
// is the crossfade: load into whichever image is hidden and only swap once it
// reports Ready. Flipping straight away is what made the backdrop lag behind
// the cards — the fade begins against an Image that has not finished loading,
// so for its first few hundred milliseconds it is fading to nothing.
Item {
    id: backdrop

    required property var wallpapers
    // The index to show. A layout passes its own current item.
    property int index: -1
    // Off for the "clear" variants, which show the desktop through instead.
    property bool blurred: true

    property bool toggle: false

    function refresh() {
        if (backdrop.index < 0 || backdrop.wallpapers.count === 0)
            return
        var name = backdrop.wallpapers.nameAt(backdrop.index)
        if (!name)
            return
        // The cached thumbnail, not the original: this is blurred to
        // unrecognisable anyway, and decoding a 4K wallpaper on every arrow key
        // is exactly the cost the thumbnails exist to avoid.
        var url = backdrop.wallpapers.thumbFor(name)
        var incoming = backdrop.toggle ? imgA : imgB
        if (incoming.source !== url)
            incoming.source = url
    }

    onIndexChanged: backdrop.refresh()

    Image {
        id: imgA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // Cached and bounded to the thumbnail's own width, so going back to a
        // wallpaper you have already passed costs nothing — which is most of
        // what browsing a carousel is.
        cache: true
        sourceSize.width: 640
        smooth: true
        visible: false
        opacity: backdrop.toggle ? 0.0 : 1.0
        // Whichever image just finished loading is the one that was being
        // loaded into, so it is the one to show.
        onStatusChanged: if (status === Image.Ready) backdrop.toggle = false
        Behavior on opacity {
            NumberAnimation { duration: Motion.slowEffects; easing.type: Easing.InOutQuad }
        }
    }
    Image {
        id: imgB
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: 640
        smooth: true
        visible: false
        opacity: backdrop.toggle ? 1.0 : 0.0
        onStatusChanged: if (status === Image.Ready) backdrop.toggle = true
        Behavior on opacity {
            NumberAnimation { duration: Motion.slowEffects; easing.type: Easing.InOutQuad }
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: imgA
        opacity: imgA.opacity
        visible: backdrop.blurred
        blurEnabled: true
        blur: 1.0
        blurMax: 72
        brightness: -0.25
        saturation: 0.05
    }
    MultiEffect {
        anchors.fill: parent
        source: imgB
        opacity: imgB.opacity
        visible: backdrop.blurred
        blurEnabled: true
        blur: 1.0
        blurMax: 72
        brightness: -0.25
        saturation: 0.05
    }

    // A soft wash of the accent behind the cards. Upstream used the single
    // border_color from its config.json; ours follows the palette.
    Rectangle {
        width: parent.width * 0.5
        height: parent.height * 0.9
        anchors.centerIn: parent
        radius: width * 0.5
        color: Config.accent
        opacity: backdrop.blurred ? 0.18 : 0.10
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 90
        }
    }

    // Vignettes. Black whatever the palette, like every other shadow in the
    // shell: these darken the wallpaper, they are not a colour. Without the
    // blur they are what keeps the cards legible over a bright wallpaper.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#33000000" }
            GradientStop { position: 0.5; color: "#00000000" }
            GradientStop { position: 1.0; color: "#AA000000" }
        }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#77000000" }
            GradientStop { position: 0.5; color: "#00000000" }
            GradientStop { position: 1.0; color: "#77000000" }
        }
    }
}
