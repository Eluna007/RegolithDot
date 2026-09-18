import QtQuick
import QtQuick.Effects
import "../services"

// Floating: cards suspended at tiered depths around the focused one, which
// hangs largest and lowest. The showiest of the layouts, and the only one that
// is not a view at all — every card is positioned absolutely from its distance
// to the selection, and Behaviors carry it to its new place when that changes.
//
// Ported from ujjalsigdel/hyprquickpaper's floating family, which ships as six
// complete shell.qml files: floating, -clean, -clear, -clear-clean, -minimal
// and -minimal-clean, between 364 and 559 lines. They differ in three yes/no
// choices, so here they are three properties.
//
//   backdrop     the blurred copy of the selection behind everything
//   widgets      the clock and the caption
//   reflections  "all" | "center" | "none"
Item {
    id: layout

    required property var wallpapers
    signal close()

    property bool backdrop: true
    property bool widgets: true
    property string reflections: "all"

    property int selectedIndex: 0

    WallpaperBackdrop {
        anchors.fill: parent
        wallpapers: layout.wallpapers
        index: layout.selectedIndex
        blurred: layout.backdrop
    }

    // ── Widgets ──────────────────────────────────────────────────────────
    // Upstream's glassmorphic date and time, top centre. Ours takes the
    // palette and the shell's own 24-hour setting rather than carrying a
    // second opinion about either.
    Rectangle {
        visible: layout.widgets
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(parent.height * 0.07)
        width: clockCol.implicitWidth + 44
        height: clockCol.implicitHeight + 24
        radius: 20
        color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.35)
        border.width: 1
        border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.12)

        Column {
            id: clockCol
            anchors.centerIn: parent
            spacing: 2

            Text {
                id: clockText
                anchors.horizontalCenter: parent.horizontalCenter
                color: Config.text
                font { pixelSize: 30; bold: true; family: "JetBrainsMono Nerd Font Mono" }
                text: Qt.formatDateTime(new Date(), Config.clock24h ? "HH:mm" : "h:mm AP")
            }
            Text {
                id: dateText
                anchors.horizontalCenter: parent.horizontalCenter
                color: Config.subtext0
                font { pixelSize: 12; family: "JetBrainsMono Nerd Font Mono" }
                text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
            }
        }

        // One timer, not a binding on `new Date()`: a binding would never
        // re-evaluate, so the clock would show the time the picker opened and
        // then stop.
        Timer {
            interval: 1000
            running: layout.widgets
            repeat: true
            onTriggered: {
                var now = new Date()
                clockText.text = Qt.formatDateTime(now, Config.clock24h ? "HH:mm" : "h:mm AP")
                dateText.text = Qt.formatDateTime(now, "dddd, d MMMM")
            }
        }
    }

    // ── The cards ────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        Repeater {
            model: layout.wallpapers.model

            delegate: Item {
                id: card

                required property int index
                required property string fileName
                required property string filePath
                required property url fileUrl

                // Distance to the selection, the short way round: a folder is
                // a ring here, so the card one before the first is the last.
                readonly property int diff: {
                    var d = card.index - layout.selectedIndex
                    var half = layout.wallpapers.count / 2
                    if (d > half) d -= layout.wallpapers.count
                    if (d < -half) d += layout.wallpapers.count
                    return d
                }
                readonly property real absDiff: Math.abs(card.diff)
                readonly property bool isCurrent: card.diff === 0

                // Past the third tier there is nothing to see and everything
                // to pay for.
                visible: card.absDiff <= 3

                readonly property real tierW: card.absDiff === 0 ? 640
                                            : card.absDiff === 1 ? 420
                                            : card.absDiff === 2 ? 280 : 180
                readonly property real tierH: card.absDiff === 0 ? 360
                                            : card.absDiff === 1 ? 236
                                            : card.absDiff === 2 ? 157 : 101

                width: card.tierW
                height: card.tierH
                z: 100 - card.absDiff
                opacity: card.absDiff === 0 ? 1.0
                       : card.absDiff === 1 ? 0.75
                       : card.absDiff === 2 ? 0.40 : 0.25

                x: {
                    if (card.diff === 0) return (layout.width - card.tierW) / 2
                    if (card.absDiff === 1) return layout.width / 2 + card.diff * 460 - card.tierW / 2
                    if (card.absDiff === 2) return layout.width / 2 + Math.sign(card.diff) * 740 - card.tierW / 2
                    return layout.width / 2 + card.diff * 200 - card.tierW / 2
                }
                y: {
                    if (card.absDiff === 0) return layout.height * 0.42
                    if (card.absDiff === 1) return layout.height * 0.33
                    if (card.absDiff === 2) return layout.height * 0.26
                    return layout.height * 0.05
                }

                // The whole layout's motion lives in these four. Nothing is
                // scrolled: the cards simply find out they belong somewhere
                // else and travel there.
                Behavior on x       { NumberAnimation { duration: Motion.normal; easing.type: Easing.OutQuart } }
                Behavior on y       { NumberAnimation { duration: Motion.normal; easing.type: Easing.OutQuart } }
                Behavior on width   { NumberAnimation { duration: Motion.normal; easing.type: Easing.OutQuart } }
                Behavior on height  { NumberAnimation { duration: Motion.normal; easing.type: Easing.OutQuart } }
                Behavior on opacity { NumberAnimation { duration: Motion.slowEffects } }

                WallpaperTile {
                    id: art
                    anchors.fill: parent
                    wallpapers: layout.wallpapers
                    fileName: card.fileName
                    fileUrl: card.fileUrl
                    radius: 14
                    current: card.isCurrent
                    animate: card.isCurrent
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"
                    antialiasing: true
                    border.width: card.isCurrent ? 3 : 1
                    border.color: card.isCurrent
                                  ? (card.filePath === layout.wallpapers.appliedPath
                                     ? Config.accent : Config.maroon)
                                  : Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.12)
                    Behavior on border.color { ColorAnimation { duration: Motion.fastEffects } }
                }

                Rectangle {
                    visible: card.filePath === layout.wallpapers.appliedPath
                    anchors { top: parent.top; right: parent.right; margins: 8 }
                    width: 24; height: 24; radius: 12
                    color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.85)
                    Text {
                        anchors.centerIn: parent
                        text: "󰄬"
                        color: Config.accent
                        font { pixelSize: 13; family: "JetBrainsMono Nerd Font Mono" }
                    }
                }

                // ── Reflection ───────────────────────────────────────────
                // A mirrored copy under the card, fading out downwards. The
                // fade is a gradient used as a mask — the same MultiEffect
                // masking every other rounded thing in this shell, given an
                // alpha ramp instead of a rounded rectangle.
                Item {
                    id: mirror
                    visible: layout.reflections === "all"
                             || (layout.reflections === "center" && card.isCurrent)
                    anchors.top: parent.bottom
                    anchors.topMargin: 6
                    width: parent.width
                    height: parent.height * 0.45
                    clip: true

                    Item {
                        id: flipped
                        width: mirror.width
                        height: card.height
                        visible: false
                        layer.enabled: true
                        transform: Scale { origin.y: card.height / 2; yScale: -1 }

                        WallpaperTile {
                            anchors.fill: parent
                            wallpapers: layout.wallpapers
                            fileName: card.fileName
                            fileUrl: card.fileUrl
                            radius: 14
                            // Never animated: a reflection of a playing gif is
                            // a second decode of it for a sixth of the detail.
                            animate: false
                        }
                    }

                    Item {
                        id: fadeMask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: "#59000000" }
                                GradientStop { position: 1.0; color: "#00000000" }
                            }
                        }
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: flipped
                        maskEnabled: true
                        maskSource: fadeMask
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (card.isCurrent) {
                            layout.wallpapers.apply(card.filePath)
                            layout.close()
                        } else {
                            layout.selectedIndex = card.index
                        }
                    }
                }
            }
        }
    }

    // The name of the focused wallpaper, under the deck.
    Text {
        visible: layout.widgets
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(parent.height * 0.06)
        textFormat: Text.PlainText
        text: layout.wallpapers.count === 0
              ? "No wallpapers in " + layout.wallpapers.wallDir
              : layout.wallpapers.nameAt(layout.selectedIndex)
        color: Config.text
        font { pixelSize: 14; family: "JetBrainsMono Nerd Font Mono" }
        style: Text.Outline
        styleColor: "#AA000000"
    }

    function next() { if (layout.wallpapers.count > 0) layout.selectedIndex = (layout.selectedIndex + 1) % layout.wallpapers.count }
    function prev() { if (layout.wallpapers.count > 0) layout.selectedIndex = (layout.selectedIndex - 1 + layout.wallpapers.count) % layout.wallpapers.count }

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
