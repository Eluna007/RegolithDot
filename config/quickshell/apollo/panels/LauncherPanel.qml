import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../services"
import "launcher/Match.js" as Match
import "launcher/Commands.js" as Commands

// The app launcher: a full-screen page of large icons, the way Launchpad is,
// rather than a list. Type to filter, arrows to move, Enter to launch.
//
// Typing also reaches the things that are not installed applications - the
// windows that are open right now, a calculator, and the actions the shell can
// carry out itself. Those live in launcher/Commands.js; ranking lives in
// launcher/Match.js; both are covered by scripts/test-launcher.js. The app
// list comes from scripts/apps.sh, covered by scripts/test-apps.sh.
//
// There is no card. The whole screen is the surface, translucent over the blur
// rules.lua already applies to the `quickshell` layer namespace - which is what
// makes the wallpaper show through the way it does on a Mac.
PanelWindow {
    id: root
    signal close()
    // A launcher action that opens a panel hands the name back to shell.qml,
    // which owns which panel is open. It must not also close(): opening
    // another panel already makes `activePanel === "launcher"` false.
    signal openPanel(string name)

    // ── Opening ──────────────────────────────────────────────────────────
    // `running: visible`, not a NumberAnimation-on-property with
    // `running: true`. shell.qml creates every panel eagerly and toggles it
    // with `visible`, so an animation that starts on component completion
    // plays once at login, while the panel is hidden, and is never seen again.
    property real reveal: 1
    NumberAnimation {
        target: root
        property: "reveal"
        from: 0; to: 1
        // Emphasized rather than spatial: at 75% of the screen an overshoot
        // reads as a wobble rather than a spring. This curve never passes its
        // target, and the longer duration is what makes it feel unhurried.
        duration: Motion.slowSpatial
        easing.type: Easing.Bezier
        easing.bezierCurve: Motion.curveEmphasized
        running: root.visible
    }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"
    readonly property color overlay0: Config.overlay0
    readonly property color subtext0: Config.subtext0
    readonly property color text:     Config.text
    readonly property color accent:   Config.accent

    // ── State ────────────────────────────────────────────────────────────
    property var apps: []
    property string query: ""
    property int selected: 0
    property int page: 0
    // Set once the first scan has finished, so an empty grid can say whether
    // apps.sh found nothing or the query matched nothing. Those are different
    // problems and they look identical.
    property bool scanned: false

    readonly property var results: {
        var ranked = Match.filter(Commands.searchTerm(query),
                                  Commands.sources(query, apps, Hyprland.toplevels.values))
        var sum = Commands.calc(query)
        return sum ? [sum].concat(ranked) : ranked
    }

    // ── Geometry ─────────────────────────────────────────────────────────
    // A centred card at 75% of the screen, with a fixed 5x5 page. Fixed rather
    // than derived: "how many fit" gave a different page size per monitor, so
    // the same app was on page 1 on the laptop and page 2 plugged in.
    readonly property int columns: 6
    readonly property int rows:    5
    readonly property int perPage: columns * rows

    readonly property int cardW: Math.round(width * 0.75)
    readonly property int cardH: Math.round(height * 0.75)
    readonly property int cardPad: 28
    // What is left for the grid once the search field and the page dots have
    // taken their share.
    readonly property int gridW: cardW - cardPad * 2
    readonly property int gridH: cardH - cardPad * 2 - 64 - 32
    // The grid spans the card's full width. Six columns of a 16:9 card are
    // wider than they are tall, which is what Launchpad's own cells are — the
    // horizontal air between icons is the look, not a gap to be closed.
    readonly property int cellW: Math.floor(gridW / columns)
    readonly property int cellH: Math.floor(gridH / rows)

    // The icon leads and the plate follows it, rather than the other way round.
    // Sizing the plate off the cell first put a 285px square behind a 104px
    // icon on a 4K screen — correct arithmetic, absurd proportion. The icon
    // comes off the row height, and the plate is a fixed ratio of the icon,
    // clamped so it can never overflow a short row.
    readonly property int iconSize: Math.max(32, Math.min(112, Math.round(cellH * 0.45)))
    readonly property int tileSize: Math.min(Math.min(cellW, cellH) - 8,
                                             Math.round(iconSize * 1.95))
    readonly property int pages:   Commands.pageCount(results.length, perPage)
    readonly property var pageItems: Commands.pageSlice(results, page, perPage)

    // The selection drives the page, not the other way round: moving off the
    // end of a page steps onto the next one.
    onSelectedChanged: page = Commands.pageOf(selected, perPage)
    onResultsChanged: { selected = 0; page = 0 }

    readonly property string appsScript: Config.shellScript("apps.sh")

    property var appBuffer: []
    Process {
        id: scanProc
        command: [root.appsScript]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var e = Match.parseLine(line)
                if (e) root.appBuffer.push(e)
            }
        }
        onRunningChanged: {
            if (running) { root.appBuffer = []; return }
            root.apps = root.appBuffer
            root.scanned = true
            // apps.sh working on the command line while the launcher stays
            // empty means the two are not the same thing - a stale shell
            // running older QML, a lost execute bit, a different environment.
            // Say so on stderr, where `qs -c apollo` in a terminal shows it.
            if (root.apps.length === 0)
                console.warn("launcher: apps.sh produced no entries. Run it directly:",
                             root.appsScript, "--debug")
        }
    }

    // Rescan on open. It costs ~30ms for two hundred apps, which is cheaper
    // than showing a list that is missing something installed five minutes ago.
    onVisibleChanged: {
        if (visible) {
            query = ""
            selected = 0
            page = 0
            if (!scanProc.running) scanProc.running = true
            input.forceActiveFocus()
        }
    }

    function launch(entry) {
        if (!entry) return

        if (entry.kind === "calc") {
            Quickshell.execDetached(["wl-copy", "--", entry.value])
            root.close()
            return
        }
        if (entry.kind === "window") {
            // Toplevel.activate() only requests surface activation and does not
            // reliably bring the workspace with it - see WindowOverview.qml.
            Hypr.focusWindow(entry.address)
            root.close()
            return
        }
        if (entry.kind === "action" && entry.panel) {
            root.openPanel(entry.panel)
            return
        }

        // Applications, and the actions that are a command. The Exec line is a
        // command line, so it goes through a shell. It comes from the .desktop
        // file, which is the same trust level as the binary it names.
        Quickshell.execDetached(["sh", "-c", entry.exec])
        root.close()
    }

    function move(delta) {
        if (results.length === 0) return
        var n = selected + delta
        if (n < 0) n = results.length - 1
        if (n >= results.length) n = 0
        selected = n
    }

    function moveRow(delta) {
        if (results.length === 0) return
        selected = Commands.moveByRow(selected, delta, columns, results.length)
    }

    function turnPage(delta) {
        var p = page + delta
        if (p < 0 || p >= pages) return
        page = p
        // Keep the selection on the page you are looking at, in the same slot.
        selected = Math.min(results.length - 1, p * perPage + (selected % perPage))
    }

    // ── Backdrop ────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Config.crust.r, Config.crust.g, Config.crust.b, 0.55)
        opacity: root.reveal
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
            onWheel: wheel => root.turnPage(wheel.angleDelta.y < 0 ? 1 : -1)
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: root.cardW
        height: root.cardH
        radius: 28
        color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.55)
        border.width: 1
        border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.10)

        // The whole card settles in together, from slightly small. A centred
        // sheet has no bar edge of its own, so it grows from its middle.
        opacity: Math.min(1, root.reveal * 1.4)
        scale: Motion.fromScale + (1 - Motion.fromScale) * root.reveal
        transformOrigin: Item.Center

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.cardPad
            spacing: 0

            // ── Search ──────────────────────────────────────────────────────
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 420
                Layout.preferredHeight: 40
                radius: 20
                color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.55)
                border.width: 1
                border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.10)

                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                    spacing: 10

                    Text {
                        text: "\u{f0349}"
                        color: root.overlay0
                        font { pixelSize: 15; family: root.nfFont }
                    }

                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        focus: true
                        color: root.text
                        font { pixelSize: 15; family: root.nfFont }
                        selectionColor: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.4)
                        selectedTextColor: root.text
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: root.query = text

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: "Search"
                            color: root.overlay0
                            font { pixelSize: 15; family: root.nfFont }
                        }

                        Keys.onPressed: ev => {
                            if (ev.key === Qt.Key_Escape) { root.close(); ev.accepted = true }
                            else if (ev.key === Qt.Key_Right) { root.move(1); ev.accepted = true }
                            else if (ev.key === Qt.Key_Left)  { root.move(-1); ev.accepted = true }
                            else if (ev.key === Qt.Key_Down)  { root.moveRow(1); ev.accepted = true }
                            else if (ev.key === Qt.Key_Up)    { root.moveRow(-1); ev.accepted = true }
                            else if (ev.key === Qt.Key_Tab)   { root.move(1); ev.accepted = true }
                            else if (ev.key === Qt.Key_PageDown) { root.turnPage(1); ev.accepted = true }
                            else if (ev.key === Qt.Key_PageUp)   { root.turnPage(-1); ev.accepted = true }
                            else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                                root.launch(root.results[root.selected]); ev.accepted = true
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 24 }

            // ── The page of icons ───────────────────────────────────────────
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                Layout.preferredWidth: root.columns * root.cellW

                Grid {
                    id: pageGrid
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: root.columns
                    spacing: 0

                    // Tiles slide to their new slot when the filter changes
                    // rather than snapping, which is most of what makes typing
                    // in a grid feel smooth instead of strobing.
                    move: Transition {
                        NumberAnimation {
                            properties: "x,y"
                            duration: Motion.fastSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Motion.curveDefaultSpatial
                        }
                    }
                    add: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0; to: 1
                            duration: Motion.effects
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Motion.curveDefaultEffects
                        }
                    }

                    Repeater {
                        model: root.pageItems

                        Item {
                            id: tile
                            required property var modelData
                            required property int index

                            // Its place in the whole result list, not in the page:
                            // the selection is a list index so that arrows can walk
                            // off the end of a page.
                            readonly property int absIndex: root.page * root.perPage + index
                            readonly property bool current: absIndex === root.selected

                            width: root.cellW
                            height: root.cellH

                            Rectangle {
                                anchors.centerIn: parent
                                width: root.tileSize
                                height: root.tileSize
                                radius: 18
                                color: tile.current
                                       ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.20)
                                       : tileHov.containsMouse
                                       ? Qt.rgba(root.text.r, root.text.g, root.text.b, 0.08)
                                       : "transparent"
                                Behavior on color { ColorAnimation { duration: Motion.fastEffects } }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                width: root.cellW - 16
                                spacing: 8

                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: root.iconSize
                                    implicitHeight: root.iconSize

                                    Image {
                                        id: tileIcon
                                        anchors.fill: parent
                                        source: tile.modelData.icon !== "" ? "file://" + tile.modelData.icon : ""
                                        sourceSize.width: root.iconSize * 2
                                        sourceSize.height: root.iconSize * 2
                                        fillMode: Image.PreserveAspectFit
                                        visible: tile.modelData.icon !== "" && status === Image.Ready
                                        asynchronous: true
                                    }
                                    // A lettered tile when the .desktop file named
                                    // an icon that is not installed - and the one
                                    // the calculator result gets.
                                    Rectangle {
                                        anchors.fill: parent
                                        visible: !tileIcon.visible
                                        radius: 14
                                        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                                        Text {
                                            anchors.centerIn: parent
                                            text: tile.modelData.kind === "calc"
                                                  ? "=" : Match.initial(tile.modelData.name)
                                            color: root.accent
                                            font { pixelSize: Math.round(root.iconSize * 0.42); bold: true; family: root.nfFont }
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                    wrapMode: Text.Wrap
                                    text: tile.modelData.name
                                    color: tile.current ? root.text : root.subtext0
                                    font { pixelSize: 11; family: root.nfFont }
                                }
                            }

                            MouseArea {
                                id: tileHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.selected = tile.absIndex
                                onClicked: root.launch(tile.modelData)
                            }
                        }
                    }
                }
            }

            // ── Empty state ─────────────────────────────────────────────────
            // Three things produce an empty grid and they are not the same
            // problem: the scan has not finished, apps.sh found nothing at all, or
            // the query matched nothing. Saying "no results" to all three is how a
            // broken scanner looks exactly like a bad search.
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 80
                Layout.preferredWidth: 520
                visible: root.results.length === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        textFormat: Text.PlainText
                        text: !root.scanned ? "Scanning applications…"
                            : root.apps.length === 0 ? "No applications found"
                            : "Nothing matches “" + root.query + "”"
                        color: root.overlay0
                        font { pixelSize: 13; family: root.nfFont }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        textFormat: Text.PlainText
                        visible: root.scanned && root.apps.length === 0
                        text: "scripts/apps.sh returned nothing — run it directly to see why"
                        color: root.overlay0
                        font { pixelSize: 10; family: root.nfFont }
                        opacity: 0.8
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // ── Page dots ───────────────────────────────────────────────────
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 9
                visible: root.pages > 1

                Repeater {
                    model: root.pages

                    Rectangle {
                        required property int index
                        width: 8
                        height: 8
                        radius: 4
                        color: index === root.page
                               ? root.accent
                               : Qt.rgba(root.text.r, root.text.g, root.text.b, 0.25)
                        Behavior on color { ColorAnimation { duration: Motion.fastEffects } }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.turnPage(index - root.page)
                        }
                    }
                }
            }
        }
    }
}
