import QtQuick
import QtQuick.Layouts
import "../services"

// Filmstrip: a centred card holding a horizontal strip of thumbnails, the
// focused one scaled up. Apollo's own layout, and the default — it is the one
// that looks like the rest of the shell rather than taking the screen over.
Item {
    id: layout

    required property var wallpapers
    signal close()

    property alias currentIndex: strip.currentIndex

    function next() { if (layout.wallpapers.count > 0) strip.currentIndex = (strip.currentIndex + 1) % layout.wallpapers.count }
    function prev() { if (layout.wallpapers.count > 0) strip.currentIndex = (strip.currentIndex - 1 + layout.wallpapers.count) % layout.wallpapers.count }

    function activate() {
        var p = layout.wallpapers.pathAt(strip.currentIndex)
        if (p) {
            layout.wallpapers.apply(p)
            layout.close()
        }
    }

    function syncToApplied() {
        var i = layout.wallpapers.indexOfApplied()
        if (i >= 0) {
            strip.positionViewAtIndex(i, PathView.Center)
            strip.currentIndex = i
        }
    }

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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: "󰸉"
                    color: Config.accent
                    font { pixelSize: 22; family: "JetBrainsMono Nerd Font Mono" }
                }
                Text {
                    text: "Wallpapers"
                    color: Config.text
                    font { pixelSize: 18; bold: true; family: "JetBrainsMono Nerd Font Mono" }
                }
                Rectangle {
                    radius: 999
                    color: Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.16)
                    implicitWidth: cntTxt.implicitWidth + 16
                    implicitHeight: 22
                    Text {
                        id: cntTxt
                        anchors.centerIn: parent
                        text: layout.wallpapers.count + " items"
                        color: Config.accent
                        font { pixelSize: 11; family: "JetBrainsMono Nerd Font Mono" }
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "scroll · click to apply · esc"
                    color: Config.overlay0
                    font { pixelSize: 11; family: "JetBrainsMono Nerd Font Mono" }
                }
            }

            PathView {
                id: strip
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                model: layout.wallpapers.model
                pathItemCount: 5
                // Keep delegates alive off the path: it otherwise destroys and
                // recreates — and re-decodes — the same tiles on the way past.
                cacheItemCount: 8
                preferredHighlightBegin: 0.5
                preferredHighlightEnd:   0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 150
                snapMode: PathView.SnapToItem

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

                // ── Momentum scrolling ──────────────────────────────────
                // Each wheel notch injects velocity; the timer advances the
                // carousel and decays it, so a fast spin coasts a few
                // wallpapers and glides to a stop.
                property real flickVel: 0

                function stopFlick() {
                    strip.flickVel = 0
                    inertia.acc = 0
                    inertia.running = false
                }

                Timer {
                    id: inertia
                    interval: 16; repeat: true; running: false
                    property real acc: 0
                    onTriggered: {
                        inertia.acc += strip.flickVel
                        while (inertia.acc >=  1) { layout.next(); inertia.acc -= 1 }
                        while (inertia.acc <= -1) { layout.prev(); inertia.acc += 1 }
                        strip.flickVel *= 0.90
                        if (Math.abs(strip.flickVel) < 0.012)
                            strip.stopFlick()
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

                    readonly property bool isCurrent: cell.PathView.isCurrentItem

                    width: 248
                    height: strip.height
                    scale:   cell.PathView.iscale   ?? 0.78
                    opacity: cell.PathView.iopacity ?? 0.45
                    z:       cell.PathView.iz       ?? 0

                    Item {
                        anchors.fill: parent
                        anchors.margins: 12

                        WallpaperTile {
                            anchors.fill: parent
                            wallpapers: layout.wallpapers
                            fileName: cell.fileName
                            fileUrl: cell.fileUrl
                            radius: 16
                            current: cell.isCurrent
                            animate: cell.isCurrent
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 16
                            color: "transparent"
                            antialiasing: true
                            border.width: cell.isCurrent ? 3 : 1
                            border.color: cell.isCurrent
                                          ? (cell.filePath === layout.wallpapers.appliedPath
                                             ? Config.accent : Config.maroon)
                                          : Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.10)
                            Behavior on border.color { ColorAnimation { duration: 160 } }
                        }

                        Rectangle {
                            visible: cell.filePath === layout.wallpapers.appliedPath
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
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            strip.currentIndex = cell.index
                            layout.wallpapers.apply(cell.filePath)
                            layout.close()
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: layout.wallpapers.count === 0
                      ? "No wallpapers in " + layout.wallpapers.wallDir
                      : layout.wallpapers.nameAt(strip.currentIndex)
                color: Config.subtext0
                font { pixelSize: 12; family: "JetBrainsMono Nerd Font Mono" }
            }
        }
    }

    // Stopping the coast when the picker closes is the layout's job, since it
    // is the only thing that knows a coast is running.
    onVisibleChanged: if (!visible) strip.stopFlick()
}
