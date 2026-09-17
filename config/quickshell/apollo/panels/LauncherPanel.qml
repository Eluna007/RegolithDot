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
        duration: Motion.spatial
        easing.type: Easing.Bezier
        easing.bezierCurve: Motion.curveDefaultSpatial
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

    // ── Grid geometry ────────────────────────────────────────────────────
    // Sized from the screen rather than fixed, so this is a page of icons on a
    // laptop and on a monitor, not seven columns of whitespace on one of them.
    readonly property int cellW: 124
    readonly property int cellH: 132
    readonly property int columns: Math.max(3, Math.min(8, Math.floor((width - 200) / cellW)))
    readonly property int rows:    Math.max(2, Math.min(5, Math.floor((height - 320) / cellH)))
    readonly property int perPage: columns * rows
    readonly property int pages:   Commands.pageCount(results.length, perPage)
    readonly property var pageItems: Commands.pageSlice(results, page, perPage)

    // The selection drives the page, not the other way round: moving off the
    // end of a page steps onto the next one.
    onSelectedChanged: page = Commands.pageOf(selected, perPage)
    onResultsChanged: { selected = 0; page = 0 }

    readonly property string appsScript:
        (Quickshell.env("XDG_CONFIG_HOME") !== ""
            ? Quickshell.env("XDG_CONFIG_HOME")
            : Quickshell.env("HOME") + "/.config")
        + "/quickshell/apollo/scripts/apps.sh"

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

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Math.round(root.height * 0.10)
        anchors.bottomMargin: 40
        spacing: 0
        opacity: root.reveal
        // The whole page settles in together, from slightly small, the way
        // Launchpad does. See `reveal` on the root.
        scale: Motion.fromScale + (1 - Motion.fromScale) * root.reveal
        transformOrigin: Item.Center

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

        Item { Layout.fillHeight: true; Layout.preferredHeight: 28 }

        // ── The page of icons ───────────────────────────────────────────
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.columns * root.cellW
            Layout.preferredHeight: root.rows * root.cellH

            Grid {
                id: pageGrid
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                columns: root.columns
                spacing: 0

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
                            anchors.fill: parent
                            anchors.margins: 6
                            radius: 16
                            color: tile.current
                                   ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.20)
                                   : tileHov.containsMouse
                                   ? Qt.rgba(root.text.r, root.text.g, root.text.b, 0.08)
                                   : "transparent"
                            Behavior on color { ColorAnimation { duration: 110 } }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: root.cellW - 16
                            spacing: 8

                            Item {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 56
                                implicitHeight: 56

                                Image {
                                    id: tileIcon
                                    anchors.fill: parent
                                    source: tile.modelData.icon !== "" ? "file://" + tile.modelData.icon : ""
                                    sourceSize.width: 112
                                    sourceSize.height: 112
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
                                        font { pixelSize: 24; bold: true; family: root.nfFont }
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
                    Behavior on color { ColorAnimation { duration: 140 } }

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
