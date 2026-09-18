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

    // Forwarded from the source so shell.qml can put the transition layer in
    // front of the swap without reaching inside this panel.
    signal switching(url fromArt, url toArt)

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
        onSwitching: (fromArt, toArt) => root.switching(fromArt, toArt)
    }

    // ── Background scrim (click outside to dismiss) ──────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Config.crust.r, Config.crust.g, Config.crust.b, 0.45)
        opacity: root.reveal
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ── The layout ───────────────────────────────────────────────────────
    // Name → file plus the properties that make it that variant.
    //
    // Upstream ships every variant as its own complete shell.qml — coverflow,
    // coverflow-clear and coverflow-minimal are 531, 553 and 406 lines
    // differing by about ninety. A variant is not a different layout, it is
    // the same one with the blur off or the caption hidden, so here it is the
    // same file and a couple of properties. That is what keeps fourteen names
    // from meaning fourteen copies of the same delegate.
    //
    // `props` goes to Loader.setSource, which is the only place a required
    // property can be supplied — see the long comment on loadLayout below.
    readonly property var layouts: ({
        "filmstrip":         { file: "WallpaperFilmstrip.qml", props: {} },

        "coverflow":         { file: "WallpaperCoverflow.qml", props: { backdrop: true,  widgets: true  } },
        "coverflow-clear":   { file: "WallpaperCoverflow.qml", props: { backdrop: false, widgets: true  } },
        "coverflow-minimal": { file: "WallpaperCoverflow.qml", props: { backdrop: true,  widgets: false } },

        "dock":              { file: "WallpaperDock.qml",      props: { backdrop: true,  widgets: true  } },
        "dock-clear":        { file: "WallpaperDock.qml",      props: { backdrop: false, widgets: true  } },

        "grid":              { file: "WallpaperGrid.qml",      props: { backdrop: true  } },
        "grid-clear":        { file: "WallpaperGrid.qml",      props: { backdrop: false } },

        "classic":           { file: "WallpaperClassic.qml",   props: { backdrop: true  } },

        // Upstream's six floating shell.qml files, which differ only in these
        // three answers.
        "floating":                { file: "WallpaperFloating.qml", props: { backdrop: true,  widgets: true,  reflections: "all"    } },
        "floating-center":         { file: "WallpaperFloating.qml", props: { backdrop: true,  widgets: true,  reflections: "center" } },
        "floating-clean":          { file: "WallpaperFloating.qml", props: { backdrop: true,  widgets: true,  reflections: "none"   } },
        "floating-clear":          { file: "WallpaperFloating.qml", props: { backdrop: false, widgets: true,  reflections: "all"    } },
        "floating-clear-clean":    { file: "WallpaperFloating.qml", props: { backdrop: false, widgets: true,  reflections: "none"   } },
        "floating-minimal":        { file: "WallpaperFloating.qml", props: { backdrop: true,  widgets: false, reflections: "none"   } }
    })

    readonly property string defaultLayout: "filmstrip"

    readonly property var layoutSpec: {
        var l = root.layouts[Config.paperLayout]
        // A name nobody meant — a typo in paper-layout.conf, or a layout that
        // has since been removed. Falling back beats an empty screen.
        return l ? l : root.layouts[root.defaultLayout]
    }

    // setSource with initial properties, not a `source` binding plus an
    // assignment in onLoaded.
    //
    // A layout's `wallpapers` is a *required* property, and a required property
    // has to be supplied when the object is created. Assigning it in onLoaded
    // is too late by definition: the component never gets built, `item` is
    // null, onLoaded never runs, and the picker is a dimmed screen with
    // nothing on it. QML says so — "Required property wallpapers was not
    // initialized" — into a log nobody is reading while looking at the empty
    // panel.
    //
    // Loader records the source and its properties even while inactive, and
    // reuses them every time `active` goes true again, so toggling with the
    // panel's visibility needs nothing further. Both of those are verified in
    // scripts/qml-tests/tst_loader_required.qml.
    function loadLayout() {
        var spec = root.layoutSpec
        var props = { "wallpapers": wallpapers }
        for (var k in spec.props)
            props[k] = spec.props[k]
        loader.setSource(spec.file, props)
    }
    onLayoutSpecChanged: loadLayout()
    Component.onCompleted: loadLayout()

    Loader {
        id: loader
        anchors.fill: parent
        // Only built while the picker is open: a layout holds a view over
        // every wallpaper in the folder, and there is no reason for that to
        // exist for the whole session.
        active: root.visible

        onLoaded: {
            item.close.connect(root.close)
            item.syncToApplied()
        }

        // Centred sheets grow from their own middle; coverflow takes the whole
        // screen and is revealed rather than scaled, so only the scale of a
        // card-shaped layout is animated here.
        //
        // The two also want different fades. A card should be solid before it
        // has finished growing, so it reaches full opacity halfway through; a
        // full-screen blur that snaps to opaque that fast reads as a flash, so
        // it takes the whole reveal.
        transformOrigin: Item.Center
        // Only the filmstrip is a card; everything else takes the screen.
        readonly property bool sheet: Config.paperLayout === "filmstrip"
        opacity: sheet ? Math.min(1, root.reveal * 2) : root.reveal
        scale: sheet ? Motion.fromScale + (1 - Motion.fromScale) * root.reveal : 1
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
                // A grid moves in two dimensions; the carousels do not, and
                // say so by not having these.
                case Qt.Key_Up:
                case Qt.Key_K:      if (loader.item.prevRow) loader.item.prevRow(); break
                case Qt.Key_Down:
                case Qt.Key_J:      if (loader.item.nextRow) loader.item.nextRow(); break
            }
        }
    }
}
