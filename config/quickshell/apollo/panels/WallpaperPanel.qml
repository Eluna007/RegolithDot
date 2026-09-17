import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt.labs.folderlistmodel
import "../services"

// Visual wallpaper picker — a horizontal filmstrip of thumbnails read live
// from ~/Pictures/Wallpapers (auto-updates when files are added/removed).
// Wheel / arrows to browse, click or Enter to apply. Esc to close.
PanelWindow {
    id: root
    signal close()

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
    onVisibleChanged: {
        if (visible) {
            keyHandler.forceActiveFocus()
            strip.syncToCurrent()
        } else {
            strip.flickVel = 0
            inertia.acc = 0
            inertia.running = false
        }
    }

    readonly property string nfFont:  "JetBrainsMono Nerd Font Mono"
    readonly property color   text:     Config.text
    readonly property color   subtext0: Config.subtext0
    readonly property color   overlay0: Config.overlay0
    readonly property color   maroon:   Config.maroon
    readonly property color   mauve:    Config.accent

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string wallDir: Config.resolvedWallpaperDir

    // ── Apply a wallpaper through the machine's own pipeline ────────────────
    // wallpaper-switch.sh picks hyprpaper for stills and mpvpaper for gifs and
    // video (hyprpaper only ever shows one frame of a gif), records the choice
    // in ~/.config/hypr/last-wallpaper.txt so restore-wallpaper.sh can replay
    // it next session, and reruns matugen so the shell and lock screen
    // recolour to match.
    //
    // Moonlit applied wallpapers with awww and cached the pick under
    // ~/.cache/wallpaper-*. Neither is in use here, so both are gone — and
    // with them per-monitor wallpapers, which the script does not support.
    Process { id: applyProc }
    function apply(path) {
        if (!path) return
        applyProc.running = false
        // Path goes in as $1 rather than being interpolated, to dodge quoting.
        applyProc.command = ["sh", "-c",
            "\"$HOME/.local/bin/wallpaper-switch.sh\" \"$1\"", "sh", path]
        applyProc.running = true
        root.appliedPath = path
        root.close()            // dismiss the picker once a wallpaper is chosen
    }
    property string appliedPath: ""

    // Infinite scroll — wrap past the ends instead of clamping
    function nextWall() { if (wallModel.count > 0) strip.currentIndex = (strip.currentIndex + 1) % wallModel.count }
    function prevWall() { if (wallModel.count > 0) strip.currentIndex = (strip.currentIndex - 1 + wallModel.count) % wallModel.count }

    // Read the last pick on startup so the strip can highlight it. Same file
    // restore-wallpaper.sh reads on session start, so the picker and the boot
    // restore can never disagree about what is currently set.
    FileView {
        id: currentFile
        path: root.homeDir + "/.config/hypr/last-wallpaper.txt"
        onLoaded: root.appliedPath = text().trim()
    }

    // ── Background scrim (click outside the card to dismiss) ────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Config.crust.r, Config.crust.g, Config.crust.b, 0.45)
        opacity: root.reveal
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ── The picker card ─────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width - 96, 1320)
        height: 380
        radius: 26
        color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.70)
        border.width: 1
        border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)

        // swallow clicks so they don't fall through to the scrim
        MouseArea { anchors.fill: parent }

        // A centred sheet, so it grows from its own middle: no bar edge is
        // its own. See `reveal` on the root for why this is a binding.
        transformOrigin: Item.Center
        scale: Motion.fromScale + (1 - Motion.fromScale) * root.reveal
        opacity: Math.min(1, root.reveal * 2)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: "󰸉"
                    color: root.mauve
                    font { pixelSize: 22; family: root.nfFont }
                }
                Text {
                    text: "Wallpapers"
                    color: root.text
                    font { pixelSize: 18; bold: true; family: root.nfFont }
                }
                Rectangle {
                    radius: 999; color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.16)
                    implicitWidth: cntTxt.implicitWidth + 16; implicitHeight: 22
                    Text {
                        id: cntTxt; anchors.centerIn: parent
                        text: wallModel.count + " items"
                        color: root.mauve
                        font { pixelSize: 11; family: root.nfFont }
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "scroll · click to apply · esc"
                    color: root.overlay0
                    font { pixelSize: 11; family: root.nfFont }
                }
            }

            // Filmstrip — circular carousel: scrolling past the end flows
            // seamlessly back into the start (no rewind jump)
            PathView {
                id: strip
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                visible: root.visible
                enabled: root.visible

                pathItemCount: 5
                preferredHighlightBegin: 0.5
                preferredHighlightEnd:   0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 150
                snapMode: PathView.SnapToItem

                // straight horizontal track; center item scales up (coverflow feel)
                path: Path {
                    startX: 0; startY: strip.height / 2
                    PathAttribute { name: "iz";       value: 0 }
                    PathAttribute { name: "iscale";   value: 0.78 }
                    PathAttribute { name: "iopacity"; value: 0.45 }
                    PathLine { x: strip.width / 2; y: strip.height / 2 }
                    PathAttribute { name: "iz";       value: 10 }
                    PathAttribute { name: "iscale";   value: 1.15 }
                    PathAttribute { name: "iopacity"; value: 1.0 }
                    PathLine { x: strip.width; y: strip.height / 2 }
                    PathAttribute { name: "iz";       value: 0 }
                    PathAttribute { name: "iscale";   value: 0.78 }
                    PathAttribute { name: "iopacity"; value: 0.45 }
                }

                model: root.visible ? wallModel : null

                FolderListModel {
                    id: wallModel
                    folder: "file://" + root.wallDir
                    showDirs: false
                    sortField: FolderListModel.Name
                    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp", "*.bmp"]
                }

                // jump the highlight to the currently-applied wallpaper
                function syncToCurrent() {
                    if (!root.appliedPath) return
                    for (var i = 0; i < wallModel.count; i++) {
                        if (wallModel.get(i, "filePath") === root.appliedPath) {
                            positionViewAtIndex(i, PathView.Center)
                            currentIndex = i
                            return
                        }
                    }
                }

                // ── Momentum scrolling ──────────────────────────────────────
                // Each wheel notch injects velocity; the timer advances the
                // carousel and decays it, so a fast spin coasts a few wallpapers
                // and glides to a stop (a slow single notch ≈ one step).
                property real flickVel: 0          // items per tick (signed)

                Timer {
                    id: inertia
                    interval: 16; repeat: true; running: false
                    property real acc: 0
                    onTriggered: {
                        inertia.acc += strip.flickVel
                        while (inertia.acc >=  1) { root.nextWall(); inertia.acc -= 1 }
                        while (inertia.acc <= -1) { root.prevWall(); inertia.acc += 1 }
                        strip.flickVel *= 0.90     // friction
                        if (Math.abs(strip.flickVel) < 0.012) {
                            strip.flickVel = 0; inertia.acc = 0; inertia.running = false
                        }
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: e => {
                        var dir = (e.angleDelta.y < 0 || e.angleDelta.x < 0) ? 1 : -1
                        var mag = Math.min(Math.abs(e.angleDelta.y) || 120, 360) / 120
                        strip.flickVel += dir * mag * 0.10
                        strip.flickVel = Math.max(-0.8, Math.min(0.8, strip.flickVel))
                        inertia.running = true
                    }
                }

                delegate: Item {
                    id: cell
                    required property int index
                    required property url fileUrl
                    required property string filePath
                    required property string fileName

                    width: 248
                    height: strip.height
                    scale:   cell.PathView.iscale   ?? 0.78
                    opacity: cell.PathView.iopacity ?? 0.45
                    z:       cell.PathView.iz        ?? 0

                    Item {
                        id: frame
                        anchors.fill: parent
                        anchors.margins: 12

                        readonly property int rad: 16

                        // rounded dark backing (shows through any letterboxing)
                        Rectangle { anchors.fill: parent; radius: frame.rad; color: Config.mantle }

                        // wallpaper masked to rounded corners
                        Image {
                            id: wpImg
                            anchors.fill: parent
                            source: cell.fileUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize.width: 280
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: wpImg
                            maskEnabled: true
                            maskSource: wpMask
                        }
                        Item {
                            id: wpMask
                            anchors.fill: parent
                            layer.enabled: true
                            visible: false
                            Rectangle { anchors.fill: parent; radius: frame.rad; color: "black"; antialiasing: true }
                        }

                        // rounded border on top
                        Rectangle {
                            anchors.fill: parent
                            radius: frame.rad
                            color: "transparent"
                            antialiasing: true
                            border.width: cell.PathView.isCurrentItem ? 3 : 1
                            border.color: cell.PathView.isCurrentItem
                                          ? (cell.filePath === root.appliedPath ? root.mauve : root.maroon)
                                          : Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.10)
                            Behavior on border.color { ColorAnimation { duration: 160 } }
                        }

                        // "active" badge on the wallpaper that's currently set
                        Rectangle {
                            visible: cell.filePath === root.appliedPath
                            anchors { top: parent.top; right: parent.right; margins: 8 }
                            width: 26; height: 26; radius: 13
                            color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.85)
                            Text {
                                anchors.centerIn: parent; text: "󰄬"
                                color: root.mauve; font { pixelSize: 14; family: root.nfFont }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            strip.currentIndex = cell.index
                            root.apply(cell.filePath)
                        }
                    }
                }
            }

            // Footer — name of the centered wallpaper
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    if (wallModel.count === 0) return "No wallpapers in " + root.wallDir
                    var n = wallModel.get(strip.currentIndex, "fileName")
                    return n ? n : ""
                }
                color: root.subtext0
                font { pixelSize: 12; family: root.nfFont }
            }
        }
    }

    // ── Keyboard ─────────────────────────────────────────────────────────────
    Item {
        id: keyHandler
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: ev => {
            switch (ev.key) {
                case Qt.Key_Escape: root.close(); break
                case Qt.Key_Left:   root.prevWall(); break
                case Qt.Key_Right:  root.nextWall(); break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    root.apply(wallModel.get(strip.currentIndex, "filePath")); break
            }
        }
    }
}
