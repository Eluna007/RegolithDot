import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../services" as Services

// Full-screen wallpaper carousel. Circular + momentum scrolling, ported
// from Moonlit's real WallpaperPanel.qml: PathView (wraps seamlessly,
// unlike ListView) on a coverflow-style path, with a friction-based
// inertia timer driven by wheel input. Our own scan/thumbnail/apply
// pipeline underneath (verified working) instead of their FolderListModel
// + awww.
PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    property bool pickerVisible: false
    signal close()
    visible: pickerVisible

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    onVisibleChanged: if (visible) { keyHandler.forceActiveFocus(); scanProc.running = true }

    property var wallpapers: []
    property string applyingPath: ""
    property int thumbGeneration: 0

    readonly property real cellWidth: 320
    readonly property real cellHeight: 460

    function isVideo(path) { return /\.(mp4|webm|mkv)$/i.test(path) }

    readonly property string thumbCacheDir: Quickshell.env("HOME") + "/.cache/apollo-wallpaper-thumbs"
    function thumbPathFor(videoPath) { return "file://" + root.thumbCacheDir + "/" + Qt.md5(videoPath) + ".png" }

    Item {
        Process {
            id: scanProc
            command: ["sh", "-c", 'find "$HOME/Pictures/Wallpapers" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" \\) | sort']
            property string buf: ""
            onStarted: buf = ""
            stdout: SplitParser { onRead: d => scanProc.buf += d + "\n" }
            onExited: (code, status) => {
                var list = scanProc.buf.trim().split("\n").filter(l => l !== "")
                root.wallpapers = list
                var videos = list.filter(p => root.isVideo(p))
                if (videos.length > 0) thumbProc.generate(videos)
            }
        }

        Process {
            id: thumbProc
            function generate(paths) {
                thumbProc.command = ["sh", "-c",
                    'cache="$1"; shift; mkdir -p "$cache"; ' +
                    'for f in "$@"; do ' +
                    'h=$(printf "%s" "$f" | md5sum | cut -d" " -f1); ' +
                    'out="$cache/$h.png"; ' +
                    '[ -f "$out" ] || ffmpeg -y -ss 00:00:01 -i "$f" -frames:v 1 -vf scale=320:-1 "$out" -loglevel error; ' +
                    'done',
                    "sh", root.thumbCacheDir].concat(paths)
                thumbProc.running = true
            }
            onExited: (code, status) => root.thumbGeneration++
        }

        Timer { id: applyClearTimer; interval: 900; onTriggered: root.applyingPath = "" }
        Timer { id: closeTimer; interval: 500; onTriggered: root.close() }
    }

    function apply(path) {
        root.applyingPath = path
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/wallpaper-switch.sh", path])
        applyClearTimer.restart()
        closeTimer.restart()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Services.Theme.background.r, Services.Theme.background.g, Services.Theme.background.b, 0.82)
        NumberAnimation on opacity { from: 0; to: 1; duration: 180; running: true; easing.type: Easing.OutCubic }

        MouseArea { anchors.fill: parent; onClicked: root.close() }

        Column {
            anchors.fill: parent
            anchors.topMargin: 60
            anchors.bottomMargin: 50
            spacing: 16

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Wallpaper"
                color: Services.Theme.pillAccent
                font.pixelSize: 17
                font.bold: true
                font.family: Services.Theme.fontFamily
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.wallpapers.length === 0
                text: "No wallpapers found in ~/Pictures/Wallpapers"
                color: Services.Theme.foreground
                opacity: 0.5
                font.pixelSize: 13
                font.family: Services.Theme.fontFamily
            }

            PathView {
                id: strip
                width: parent.width
                height: parent.height - 70
                visible: root.wallpapers.length > 0
                model: root.wallpapers

                pathItemCount: 5
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 180
                snapMode: PathView.SnapToItem

                // Coverflow track: side items small/dim, center item full
                // size/opacity.
                path: Path {
                    startX: 0; startY: strip.height / 2
                    PathAttribute { name: "iscale"; value: 0.55 }
                    PathAttribute { name: "iopacity"; value: 0.4 }
                    PathAttribute { name: "iz"; value: 0 }
                    PathLine { x: strip.width / 2; y: strip.height / 2 }
                    PathAttribute { name: "iscale"; value: 1.0 }
                    PathAttribute { name: "iopacity"; value: 1.0 }
                    PathAttribute { name: "iz"; value: 10 }
                    PathLine { x: strip.width; y: strip.height / 2 }
                    PathAttribute { name: "iscale"; value: 0.55 }
                    PathAttribute { name: "iopacity"; value: 0.4 }
                    PathAttribute { name: "iz"; value: 0 }
                }

                // Momentum: each wheel notch injects velocity, a 16ms timer
                // advances the carousel and applies friction until it
                // settles — a fast spin coasts several wallpapers, a slow
                // single notch moves about one.
                property real flickVel: 0

                Timer {
                    id: inertia
                    interval: 16; repeat: true; running: false
                    property real acc: 0
                    onTriggered: {
                        inertia.acc += strip.flickVel
                        while (inertia.acc >= 1) {
                            strip.currentIndex = (strip.currentIndex + 1) % root.wallpapers.length
                            inertia.acc -= 1
                        }
                        while (inertia.acc <= -1) {
                            strip.currentIndex = (strip.currentIndex - 1 + root.wallpapers.length) % root.wallpapers.length
                            inertia.acc += 1
                        }
                        strip.flickVel *= 0.90
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
                    id: tile
                    required property string modelData
                    required property int index
                    readonly property bool current: PathView.isCurrentItem
                    readonly property bool video: root.isVideo(modelData)
                    readonly property bool applying: root.applyingPath === modelData

                    width: root.cellWidth
                    height: root.cellHeight
                    scale: tile.PathView.iscale ?? 0.55
                    opacity: tile.PathView.iopacity ?? 0.4
                    z: tile.PathView.iz ?? 0

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        radius: 20
                        color: Services.Theme.pillColor
                        border.width: tile.current ? 2 : 1
                        border.color: tile.current ? Services.Theme.pillAccent : Services.Theme.pillBorder
                        clip: true
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        Image {
                            id: thumbImg
                            anchors.fill: parent
                            visible: !tile.video || status === Image.Ready
                            readonly property int _gen: root.thumbGeneration
                            source: tile.video ? root.thumbPathFor(tile.modelData) : ("file://" + tile.modelData)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 600
                            cache: false
                        }
                        Rectangle {
                            visible: tile.video && thumbImg.status === Image.Ready
                            anchors { bottom: parent.bottom; right: parent.right; margins: 10 }
                            width: 28; height: 28; radius: 14
                            color: Qt.rgba(Services.Theme.background.r, Services.Theme.background.g, Services.Theme.background.b, 0.7)
                            Text {
                                anchors.centerIn: parent
                                text: "\u25b6"
                                color: Services.Theme.foreground
                                font.pixelSize: 12
                                font.family: Services.Theme.fontFamily
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: tile.video && thumbImg.status !== Image.Ready
                            text: "\u25b6"
                            color: Qt.rgba(Services.Theme.foreground.r, Services.Theme.foreground.g, Services.Theme.foreground.b, 0.6)
                            font.pixelSize: 32
                            font.family: Services.Theme.fontFamily
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: tile.applying
                            text: "\u2026"
                            color: Services.Theme.pillAccent
                            font.pixelSize: 24
                            font.family: Services.Theme.fontFamily
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (tile.current) root.apply(tile.modelData)
                                else strip.currentIndex = tile.index
                            }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "esc to cancel  \u00b7  scroll to browse  \u00b7  enter or click to apply"
                color: Services.Theme.foreground
                opacity: 0.5
                font.pixelSize: 11
                font.family: Services.Theme.fontFamily
            }
        }
    }

    Item {
        id: keyHandler
        focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: ev => {
            if (root.wallpapers.length === 0) { if (ev.key === Qt.Key_Escape) root.close(); return }
            switch (ev.key) {
                case Qt.Key_Escape:
                    root.close()
                    break
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.apply(root.wallpapers[strip.currentIndex])
                    break
                case Qt.Key_Right:
                    strip.currentIndex = (strip.currentIndex + 1) % root.wallpapers.length
                    break
                case Qt.Key_Left:
                    strip.currentIndex = (strip.currentIndex - 1 + root.wallpapers.length) % root.wallpapers.length
                    break
            }
        }
    }
}
