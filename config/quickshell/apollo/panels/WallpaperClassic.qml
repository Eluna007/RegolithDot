import QtQuick
import "../services"

// Classic: a plain vertical list, thumbnail and name per row, with a preview
// filling the rest of the screen. The lightest of the layouts on the GPU —
// nothing is scaled, sheared, fanned or reflected — which is upstream's own
// argument for it on weaker hardware.
//
// Ported from ujjalsigdel/hyprquickpaper's shell-classic.qml.
Item {
    id: layout

    required property var wallpapers
    signal close()

    property bool backdrop: true

    readonly property real listWidth: Math.max(240, Math.min(width * 0.32, 460))
    readonly property real rowHeight: 64

    WallpaperBackdrop {
        anchors.fill: parent
        wallpapers: layout.wallpapers
        index: list.currentIndex
        blurred: layout.backdrop
    }

    // ── The list ─────────────────────────────────────────────────────────
    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: layout.listWidth
        color: Qt.rgba(Config.crust.r, Config.crust.g, Config.crust.b, 0.55)

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 12
            clip: true
            spacing: 4
            model: layout.wallpapers.model
            // Floored: before the panel has geometry this is derived from a
            // width of zero, and QML rejects a negative cache buffer outright.
            cacheBuffer: Math.max(0, Math.round(layout.rowHeight * 8))

            delegate: Rectangle {
                id: row

                required property int index
                required property string fileName
                required property string filePath
                required property url fileUrl

                readonly property bool isCurrent: row.index === list.currentIndex

                width: list.width
                height: layout.rowHeight
                radius: 10
                color: row.isCurrent
                       ? Qt.rgba(Config.accent.r, Config.accent.g, Config.accent.b, 0.18)
                       : (rowArea.containsMouse
                          ? Qt.rgba(Config.surface0.r, Config.surface0.g, Config.surface0.b, 0.5)
                          : "transparent")
                Behavior on color { ColorAnimation { duration: Motion.fastEffects } }

                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    WallpaperTile {
                        width: 80
                        height: parent.height
                        wallpapers: layout.wallpapers
                        fileName: row.fileName
                        fileUrl: row.fileUrl
                        radius: 6
                        current: row.isCurrent
                        animate: false
                    }

                    Column {
                        width: parent.width - 80 - 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            elide: Text.ElideMiddle
                            textFormat: Text.PlainText
                            text: row.fileName
                            color: row.isCurrent ? Config.text : Config.subtext0
                            font { pixelSize: 12; bold: row.isCurrent; family: "JetBrainsMono Nerd Font Mono" }
                        }
                        Text {
                            visible: row.filePath === layout.wallpapers.appliedPath
                            text: "󰄬  in use"
                            color: Config.accent
                            font { pixelSize: 10; family: "JetBrainsMono Nerd Font Mono" }
                        }
                    }
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (list.currentIndex === row.index) {
                            layout.wallpapers.apply(row.filePath)
                            layout.close()
                        } else {
                            list.currentIndex = row.index
                        }
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
        }

        Column {
            anchors.centerIn: parent
            spacing: 16
            width: parent.width * 0.78

            Item {
                width: parent.width
                height: width * 9 / 16

                WallpaperTile {
                    anchors.fill: parent
                    wallpapers: layout.wallpapers
                    fileName: layout.wallpapers.nameAt(list.currentIndex)
                    fileUrl: {
                        var p = layout.wallpapers.pathAt(list.currentIndex)
                        return p ? "file://" + p : ""
                    }
                    radius: 18
                    current: true
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
                textFormat: Text.PlainText
                text: layout.wallpapers.count === 0
                      ? "No wallpapers in " + layout.wallpapers.wallDir
                      : (list.currentIndex + 1) + " of " + layout.wallpapers.count
                        + "   ·   enter to apply"
                color: Config.subtext0
                font { pixelSize: 11; family: "JetBrainsMono Nerd Font Mono" }
            }
        }
    }

    function next() { if (layout.wallpapers.count > 0) list.currentIndex = (list.currentIndex + 1) % layout.wallpapers.count }
    function prev() { if (layout.wallpapers.count > 0) list.currentIndex = (list.currentIndex - 1 + layout.wallpapers.count) % layout.wallpapers.count }
    // A list runs down the screen, so up and down are its natural axis — the
    // panel sends those here as well as left and right.
    function nextRow() { layout.next() }
    function prevRow() { layout.prev() }

    function activate() {
        var p = layout.wallpapers.pathAt(list.currentIndex)
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
            list.currentIndex = i >= 0 ? i : 0
            list.positionViewAtIndex(list.currentIndex, ListView.Center)
        }
    }

    Connections {
        target: layout.wallpapers.model
        function onCountChanged() { syncTimer.restart() }
    }
}
