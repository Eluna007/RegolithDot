import Quickshell
import Quickshell.Wayland
import QtQuick
import "../services"

// The wallpaper picker. This file is the surface and the wiring; what it looks
// like is whichever layout Config.paperLayout names.
//
// The split is the hyprlock layouts' one: a layout is only its look, and
// everything underneath — the folder, the thumbnails, the apply path, what is
// currently set — lives once, in WallpaperSource. Upstream
// (ujjalsigdel/hyprquickpaper) ships each of its fourteen layouts as a complete
// standalone shell, which is right for a drop-in config and would mean
// fourteen copies of that plumbing here.
//
// Layouts are expected to expose next(), prev(), activate() and
// syncToApplied(), and to emit close() when they have applied something.
PanelWindow {
    id: root
    signal close()

    // Hyprland output this picker belongs to (set per-screen from shell.qml).
    // Currently unused: wallpapers are applied through wallpaper-switch.sh,
    // which drives hyprpaper/mpvpaper across all monitors at once. Kept so
    // shell.qml's per-screen assignment stays valid, and as the hook to
    // reinstate per-monitor wallpapers if that script ever grows an output
    // argument.
    property string outputName: ""

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"

    // Grab the keyboard while open so Esc / arrows / Enter work
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // ── Opening ──────────────────────────────────────────────────────────
    // `running: visible`, not a NumberAnimation-on-property with
    // `running: true`. shell.qml creates every panel eagerly and toggles it
    // with `visible`, so an animation that starts on component completion
    // plays once at login, while the panel is hidden, and is never seen again.
    // Defaults to 1, so the panel is fully drawn even if this never runs.
    property real reveal: 1
    NumberAnimation {
        target: root
        property: "reveal"
        from: 0; to: 1
        duration: Motion.spatial
        easing.type: Easing.Bezier
        easing.bezierCurve: Motion.curveDefaultSpatial
        running: root.visible
    }

    onVisibleChanged: {
        if (visible) {
            keyHandler.forceActiveFocus()
            if (loader.item)
                loader.item.syncToApplied()
        }
    }

    WallpaperSource {
        id: wallpapers
        active: root.visible
    }

    // ── Background scrim (click outside to dismiss) ──────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Config.crust.r, Config.crust.g, Config.crust.b, 0.45)
        opacity: root.reveal
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ── The layout ───────────────────────────────────────────────────────
    Loader {
        id: loader
        anchors.fill: parent
        // Only built while the picker is open: a layout holds a view over
        // every wallpaper in the folder, and there is no reason for that to
        // exist for the whole session.
        active: root.visible
        source: {
            // Every layout is named, including the default one: `default:`
            // is only for a value nobody meant, and a layout reachable only
            // through it stops being reachable at all the day the default
            // changes.
            switch (Config.paperLayout) {
            case "coverflow": return "WallpaperCoverflow.qml"
            case "filmstrip": return "WallpaperFilmstrip.qml"
            default:          return "WallpaperFilmstrip.qml"
            }
        }

        onLoaded: {
            item.wallpapers = wallpapers
            item.close.connect(root.close)
            item.syncToApplied()
        }

        // Centred sheets grow from their own middle; coverflow takes the whole
        // screen and is revealed rather than scaled, so only the scale of a
        // card-shaped layout is animated here.
        opacity: Math.min(1, root.reveal * 2)
        transformOrigin: Item.Center
        scale: Config.paperLayout === "coverflow"
               ? 1
               : Motion.fromScale + (1 - Motion.fromScale) * root.reveal
    }

    // ── Keyboard ─────────────────────────────────────────────────────────
    Item {
        id: keyHandler
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: ev => {
            if (!loader.item) {
                if (ev.key === Qt.Key_Escape) root.close()
                return
            }
            switch (ev.key) {
                case Qt.Key_Escape: root.close(); break
                // h/l as well as the arrows: upstream's layouts are driven
                // that way and it costs nothing to keep.
                case Qt.Key_Left:
                case Qt.Key_H:      loader.item.prev(); break
                case Qt.Key_Right:
                case Qt.Key_L:      loader.item.next(); break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:  loader.item.activate(); break
            }
        }
    }
}
