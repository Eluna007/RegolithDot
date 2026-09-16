import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../services"
import "chess/Chess.js" as Chess
import "chess/Engine.js" as Engine
import "chess/Model.js" as Model

// Chess in the bar: play a local opponent or the built-in engine, with your
// chess.com ratings alongside when a username is configured.
//
// Rules, search and parsing are in chess/*.js, covered by
// scripts/test-chess.js under node - including perft against the published
// node counts. This file is presentation and input only.
PanelWindow {
    id: root
    signal close()

    anchors.top: true
    anchors.left: Config.barPosition === "left"
    anchors.right: Config.barPosition !== "left"
    margins.top: Config.barPosition === "top" ? 42 : 10
    margins.left: Config.barPosition === "left" ? 52 : 0
    margins.right: Config.barPosition === "right" ? 52 : 0
    exclusiveZone: 0
    implicitWidth: 396
    implicitHeight: chContent.implicitHeight + 10
    color: "transparent"

    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"
    readonly property color surface0: Config.surface0
    readonly property color surface1: Config.surface1
    readonly property color surface2: Config.surface2
    readonly property color overlay0: Config.overlay0
    readonly property color subtext0: Config.subtext0
    readonly property color text:     Config.text
    readonly property color accent:   Config.accent
    readonly property color maroon:   Config.maroon
    readonly property color teal:     Config.teal
    readonly property color peach:    Config.peach

    // ── Game state ──────────────────────────────────────────────────────
    property var pos: Chess.startPosition()
    property string startFen: Chess.START_FEN
    property var sans: []
    property var moveLog: []          // {from, to, promotion}, for replay on load
    property var keys: []             // position keys, for threefold repetition
    property int selected: -1
    property var destinations: []
    property int lastFrom: -1
    property int lastTo: -1
    property bool flipped: false
    property string mode: "engine"    // "engine" | "human"
    property int engineColor: Chess.BLACK
    property int level: 3
    property string outcome: ""
    property bool loaded: false
    property var stats: Model.emptyStats()
    property bool statsLoaded: false
    property bool resultRecorded: false

    // Promotion needs an answer before the move can be made, so the move is
    // held here while the picker is up.
    property int promoFrom: -1
    property int promoTo: -1
    readonly property bool promoting: promoFrom >= 0

    readonly property real cellPx: 41
    readonly property bool humanToMove:
        outcome === "" && !thinking && (mode === "human" || pos.turn !== engineColor)

    function pieceAt(sq) { return pos.board[sq] }
    function isOurs(sq) {
        var p = pos.board[sq]
        return p !== Chess.EMPTY && Chess.colorOf(p) === pos.turn
    }

    // Board index for a visual cell, honouring the flip.
    function squareFor(cellIndex) {
        var file = cellIndex % 8
        var rank = 7 - Math.floor(cellIndex / 8)
        if (flipped) { file = 7 - file; rank = 7 - rank }
        return rank * 16 + file
    }

    // ── Moves ───────────────────────────────────────────────────────────
    function selectSquare(sq) {
        if (!humanToMove || promoting) return

        if (selected >= 0 && destinations.indexOf(sq) !== -1) {
            // A pawn reaching the last rank needs a piece chosen first.
            var moving = pos.board[selected]
            var lastRank = Chess.colorOf(moving) === Chess.WHITE ? 7 : 0
            if (Chess.typeOf(moving) === Chess.PAWN && Math.floor(sq / 16) === lastRank) {
                promoFrom = selected
                promoTo = sq
                return
            }
            applyMove(selected, sq, 0)
            return
        }

        if (isOurs(sq)) {
            selected = sq
            destinations = Chess.destinations(pos, sq)
        } else {
            selected = -1
            destinations = []
        }
    }

    function applyMove(from, to, promotion) {
        var m = Chess.findMove(pos, from, to, promotion || 0)
        if (!m) return
        sans = sans.concat([Chess.toSan(pos, m)])
        Chess.make(pos, m)
        moveLog = moveLog.concat([{ from: from, to: to, promotion: m.promotion || 0 }])
        keys = keys.concat([Chess.positionKey(pos)])
        lastFrom = from
        lastTo = to
        selected = -1
        destinations = []
        promoFrom = -1
        promoTo = -1
        // Reassigning pos is what makes every binding on the board re-evaluate;
        // Chess.make mutates in place and QML cannot see that.
        pos = pos
        refreshOutcome()
        persist()
        maybeStartEngine()
    }

    function refreshOutcome() {
        outcome = Chess.outcome(pos, keys)
        if (outcome !== "" && !resultRecorded) {
            resultRecorded = true
            if (mode === "engine") {
                var result = Model.isDraw(outcome) ? "drawn"
                           : (pos.turn === engineColor ? "won" : "lost")
                stats = Model.recordResult(stats, level, result)
                saveStats()
            }
        }
    }

    function undo() {
        if (thinking) stopEngine()
        if (moveLog.length === 0) return
        // Undoing a single ply against the engine would just hand the move
        // back to it, so take the pair.
        var drop = (mode === "engine" && moveLog.length >= 2) ? 2 : 1
        var replay = moveLog.slice(0, moveLog.length - drop)
        rebuild(startFen, replay)
        persist()
    }

    // Replay from the start rather than unmaking: the move list is the record,
    // and this keeps SAN, repetition keys and the board in step by construction.
    function rebuild(fen, replay) {
        var p = Chess.loadFen(fen) || Chess.startPosition()
        var newSans = [], newKeys = [], applied = []
        for (var i = 0; i < replay.length; i++) {
            var r = replay[i]
            var m = Chess.findMove(p, r.from, r.to, r.promotion || 0)
            if (!m) break          // a corrupt save stops here rather than throwing
            newSans.push(Chess.toSan(p, m))
            Chess.make(p, m)
            newKeys.push(Chess.positionKey(p))
            applied.push({ from: r.from, to: r.to, promotion: m.promotion || 0 })
        }
        pos = p
        sans = newSans
        keys = newKeys
        moveLog = applied
        var last = applied.length > 0 ? applied[applied.length - 1] : null
        lastFrom = last ? last.from : -1
        lastTo = last ? last.to : -1
        selected = -1
        destinations = []
        promoFrom = -1
        promoTo = -1
        resultRecorded = false
        refreshOutcome()
    }

    function newGame() {
        stopEngine()
        startFen = Chess.START_FEN
        rebuild(startFen, [])
        persist()
        maybeStartEngine()
    }

    // ── Engine ──────────────────────────────────────────────────────────
    property var searchState: null
    property bool thinking: false

    function maybeStartEngine() {
        if (mode !== "engine" || outcome !== "") return
        if (pos.turn !== engineColor) return
        searchState = Engine.createSearch(pos, level)
        thinking = true
    }

    function stopEngine() {
        thinking = false
        searchState = null
    }

    // One bounded slice per tick. The search shares the thread that draws the
    // bar, so it is never allowed to run to completion in one go.
    Timer {
        id: engineTimer
        interval: 16
        repeat: true
        running: root.thinking
        onTriggered: {
            if (!root.searchState) { root.thinking = false; return }
            if (Engine.step(root.searchState, 6000)) {
                var best = root.searchState.best
                root.thinking = false
                root.searchState = null
                if (best) root.applyMove(best.from, best.to, best.promotion || 0)
            }
        }
    }

    // ── Persistence ─────────────────────────────────────────────────────
    readonly property string saveDir: Quickshell.env("HOME") + "/.config/apollo"

    FileView {
        id: saveFile
        path: root.saveDir + "/chess.json"
        onLoaded: {
            if (root.loaded) return
            root.loaded = true
            var st = Model.parse(text())
            if (!st) return
            root.mode = st.mode
            root.engineColor = st.engineColor
            root.level = st.level
            root.flipped = st.flipped
            root.startFen = st.startFen || Chess.START_FEN
            root.rebuild(root.startFen, st.moves)
            // Deliberately not resuming the engine here: coming back to a
            // board that immediately moves on its own is startling.
        }
    }

    FileView {
        id: statsFile
        path: root.saveDir + "/chess-stats.json"
        onLoaded: {
            if (root.statsLoaded) return
            root.statsLoaded = true
            root.stats = Model.parseStats(text())
        }
    }

    // Writes go through Process, matching the Apolloku panel: FileView's write
    // API is not used anywhere in this shell, and an unknown property in QML
    // is a load-time error that takes the whole bar down.
    property var pendingWrites: ({})
    Process {
        id: writeProc
        onRunningChanged: if (!running) root.flushWrites()
    }

    function queueWrite(path, content) {
        var q = pendingWrites
        q[path] = content
        pendingWrites = q
        flushWrites()
    }

    function flushWrites() {
        if (writeProc.running) return
        var q = pendingWrites
        for (var path in q) {
            var content = q[path]
            delete q[path]
            pendingWrites = q
            writeProc.command = ["sh", "-c",
                "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"",
                "sh", path, content]
            writeProc.running = true
            return
        }
    }

    function persist() {
        queueWrite(saveFile.path, Model.serialize({
            fen: Chess.toFen(pos), startFen: startFen,
            sans: sans, moves: moveLog, keys: keys,
            mode: mode, engineColor: engineColor, level: level,
            flipped: flipped, elapsedMs: 0
        }))
    }
    function saveStats() { queueWrite(statsFile.path, Model.serializeStats(stats)) }

    onVisibleChanged: if (!visible) { stopEngine(); persist() }

    // ── chess.com ratings ───────────────────────────────────────────────
    property var chessStats: Model.emptyChessStats()
    property bool ratingsTried: false
    readonly property bool ratingsEnabled: Model.validUsername(Config.chessUsername)

    // The username is validated before it is ever passed to curl, and goes in
    // as an argv entry rather than being pasted into the URL string, so a
    // hostile value cannot become a second shell word or a different endpoint.
    // SplitParser plus onRunningChanged, not StdioCollector: SplitParser is the
    // only stdout API this shell uses anywhere, and an unknown QML type is a
    // load-time error that takes the bar and every panel down with it. The
    // response arrives in newline-delimited chunks, so they are accumulated
    // and parsed once the process exits.
    property string ratingsBuffer: ""
    Process {
        id: ratingsProc
        stdout: SplitParser {
            onRead: chunk => root.ratingsBuffer += chunk
        }
        onRunningChanged: {
            if (running) { root.ratingsBuffer = ""; return }
            root.chessStats = Model.parseChessStats(root.ratingsBuffer)
            root.ratingsTried = true
        }
    }

    function fetchRatings() {
        if (!ratingsEnabled || ratingsProc.running) return
        ratingsProc.command = ["sh", "-c",
            "curl -fsS --max-time 8 \"https://api.chess.com/pub/player/$1/stats\"",
            "sh", Config.chessUsername]
        ratingsProc.running = true
    }

    onRatingsEnabledChanged: if (ratingsEnabled) fetchRatings()
    Timer {
        interval: 300000          // five minutes, as omachess uses
        repeat: true
        running: root.visible && root.ratingsEnabled
        triggeredOnStart: true
        onTriggered: root.fetchRatings()
    }

    // ── Layout ──────────────────────────────────────────────────────────
    Rectangle {
        id: chContent
        width: parent.width
        implicitHeight: chCol.implicitHeight + 28
        radius: 22
        color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.70)
        border.width: 1
        border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)
        clip: true

        Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 22; height: 22; color: parent.color }
        NumberAnimation on opacity { from: 0; to: 1; duration: 200; running: true; easing.type: Easing.OutCubic }

        focus: true
        Keys.onPressed: ev => {
            if (ev.key === Qt.Key_Escape) { root.close(); ev.accepted = true }
            else if (ev.key === Qt.Key_U) { root.undo(); ev.accepted = true }
            else if (ev.key === Qt.Key_F) { root.flipped = !root.flipped; ev.accepted = true }
            else if (ev.key === Qt.Key_N) { root.newGame(); ev.accepted = true }
        }

        ColumnLayout {
            id: chCol
            width: parent.width - 28
            anchors { top: parent.top; left: parent.left }
            anchors.margins: 14
            spacing: 9

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: "CHESS"
                    color: root.subtext0
                    font { pixelSize: 11; bold: true; family: root.nfFont; letterSpacing: 2 }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.mode === "engine" ? Model.levelName(root.level) : "Two players"
                    color: root.overlay0
                    font { pixelSize: 10; family: root.nfFont }
                }
            }

            // Status
            Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: root.outcome !== ""
                        ? Model.outcomeText(root.outcome, root.pos.turn === Chess.WHITE)
                      : root.thinking ? "THINKING…"
                      : root.promoting ? "CHOOSE A PIECE"
                      : (Chess.inCheck(root.pos) ? "CHECK — " : "")
                        + (root.pos.turn === Chess.WHITE ? "WHITE TO MOVE" : "BLACK TO MOVE")
                color: root.outcome !== "" ? root.teal
                     : Chess.inCheck(root.pos) ? root.maroon : root.subtext0
                font { pixelSize: 10; bold: true; family: root.nfFont; letterSpacing: 1 }
            }

            // ── Board ───────────────────────────────────────────────────
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: root.cellPx * 8
                implicitHeight: root.cellPx * 8

                Grid {
                    id: boardGrid
                    columns: 8
                    Repeater {
                        model: 64
                        delegate: Rectangle {
                            id: cell
                            required property int index
                            readonly property int sq: root.squareFor(index)
                            readonly property int piece: root.pos.board[sq]
                            readonly property bool light: ((index % 8) + Math.floor(index / 8)) % 2 === 0
                            readonly property bool isSelected: root.selected === sq
                            readonly property bool isTarget: root.destinations.indexOf(sq) !== -1
                            readonly property bool isLast: sq === root.lastFrom || sq === root.lastTo

                            width: root.cellPx
                            height: root.cellPx

                            color: isSelected ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
                                 : isLast ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                                 : light ? root.surface1 : root.surface0
                            Behavior on color { ColorAnimation { duration: 90 } }

                            // White uses the outline glyphs and Black the solid
                            // ones, both drawn in the foreground colour. That
                            // stays legible whatever the palette does, where
                            // colouring two identical glyphs does not.
                            Text {
                                anchors.centerIn: parent
                                visible: cell.piece !== Chess.EMPTY
                                textFormat: Text.PlainText
                                text: {
                                    if (cell.piece === Chess.EMPTY) return ""
                                    var t = Chess.typeOf(cell.piece)
                                    var base = Chess.colorOf(cell.piece) === Chess.WHITE ? 0x2654 : 0x265A
                                    // King=6 maps to offset 0, Pawn=1 to offset 5
                                    return String.fromCodePoint(base + (6 - t))
                                }
                                color: root.text
                                font { pixelSize: Math.round(root.cellPx * 0.72); family: "DejaVu Sans" }
                            }

                            // A dot for a quiet move, a ring for a capture.
                            Rectangle {
                                anchors.centerIn: parent
                                visible: cell.isTarget && cell.piece === Chess.EMPTY
                                width: root.cellPx * 0.26
                                height: width
                                radius: width / 2
                                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55)
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: cell.isTarget && cell.piece !== Chess.EMPTY
                                color: "transparent"
                                border.width: 3
                                border.color: Qt.rgba(root.maroon.r, root.maroon.g, root.maroon.b, 0.75)
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: root.humanToMove ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.selectSquare(cell.sq)
                            }
                        }
                    }
                }

                // Promotion picker, over the board so the choice is unmissable.
                Rectangle {
                    anchors.fill: parent
                    visible: root.promoting
                    color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.88)

                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Repeater {
                            model: [Chess.QUEEN, Chess.ROOK, Chess.BISHOP, Chess.KNIGHT]
                            delegate: Rectangle {
                                required property int modelData
                                width: 52; height: 52; radius: 10
                                color: promoHov.containsMouse ? root.surface2 : root.surface1
                                Text {
                                    anchors.centerIn: parent
                                    textFormat: Text.PlainText
                                    text: {
                                        var base = root.pos.turn === Chess.WHITE ? 0x2654 : 0x265A
                                        return String.fromCodePoint(base + (6 - modelData))
                                    }
                                    color: root.text
                                    font { pixelSize: 30; family: "DejaVu Sans" }
                                }
                                MouseArea {
                                    id: promoHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.applyMove(root.promoFrom, root.promoTo, modelData)
                                }
                            }
                        }
                    }
                }
            }

            // ── Move list ───────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 54
                radius: 12
                color: root.surface0
                visible: root.sans.length > 0

                ListView {
                    id: moveList
                    anchors { fill: parent; margins: 8 }
                    orientation: ListView.Horizontal
                    spacing: 10
                    clip: true
                    model: Model.movePairs(root.sans)
                    // Follow the game rather than making you scroll for it.
                    onCountChanged: positionViewAtEnd()

                    delegate: Row {
                        required property var modelData
                        spacing: 4
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                        Text {
                            text: modelData.number + "."
                            color: root.overlay0
                            font { pixelSize: 11; family: root.nfFont }
                        }
                        Text {
                            textFormat: Text.PlainText
                            text: modelData.white
                            color: root.text
                            font { pixelSize: 11; family: root.nfFont }
                        }
                        Text {
                            textFormat: Text.PlainText
                            text: modelData.black
                            color: root.subtext0
                            font { pixelSize: 11; family: root.nfFont }
                        }
                    }
                }
            }

            // ── Controls ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                ChessButton { glyph: "\u{f0450}"; onTriggered: root.newGame() }
                ChessButton {
                    glyph: "\u{f054c}"
                    usable: root.moveLog.length > 0
                    onTriggered: root.undo()
                }
                ChessButton {
                    glyph: "\u{f04e1}"
                    on: root.flipped
                    onTriggered: root.flipped = !root.flipped
                }
                ChessButton {
                    glyph: root.mode === "engine" ? "\u{f0331}" : "\u{f0849}"
                    on: root.mode === "human"
                    onTriggered: {
                        root.stopEngine()
                        root.mode = root.mode === "engine" ? "human" : "engine"
                        root.persist()
                        root.maybeStartEngine()
                    }
                }

                Item { Layout.fillWidth: true }

                Repeater {
                    model: 5
                    delegate: Rectangle {
                        required property int index
                        readonly property int lv: index + 1
                        visible: root.mode === "engine"
                        implicitWidth: 22
                        implicitHeight: 24
                        radius: 7
                        color: root.level === lv ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.28)
                             : lvHov.containsMouse ? root.surface1 : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: lv
                            color: root.level === lv ? root.accent : root.overlay0
                            font { pixelSize: 11; bold: true; family: root.nfFont }
                        }
                        MouseArea {
                            id: lvHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.level = lv; root.persist() }
                        }
                    }
                }
            }

            // ── Record against the engine ───────────────────────────────
            Text {
                Layout.fillWidth: true
                visible: root.stats.played > 0
                textFormat: Text.PlainText
                text: root.stats.won + "W " + root.stats.lost + "L " + root.stats.drawn + "D"
                      + " vs the engine"
                color: root.overlay0
                font { pixelSize: 10; family: root.nfFont }
            }

            // ── chess.com ratings ───────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                radius: 12
                color: root.surface0
                visible: root.ratingsEnabled && root.chessStats.ok
                implicitHeight: ratingsCol.implicitHeight + 16

                ColumnLayout {
                    id: ratingsCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            textFormat: Text.PlainText
                            text: Config.chessUsername + " on chess.com"
                            color: root.subtext0
                            font { pixelSize: 10; bold: true; family: root.nfFont }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            visible: root.chessStats.puzzleRating > 0
                            textFormat: Text.PlainText
                            text: "puzzles " + root.chessStats.puzzleRating
                            color: root.overlay0
                            font { pixelSize: 10; family: root.nfFont }
                        }
                    }

                    Repeater {
                        model: Model.ratingRows(root.chessStats)
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Text {
                                textFormat: Text.PlainText
                                text: modelData.label
                                color: root.overlay0
                                font { pixelSize: 10; family: root.nfFont }
                                Layout.preferredWidth: 46
                            }
                            Text {
                                textFormat: Text.PlainText
                                text: modelData.rating
                                color: root.accent
                                font { pixelSize: 11; bold: true; family: root.nfFont }
                                Layout.preferredWidth: 42
                            }
                            Text {
                                textFormat: Text.PlainText
                                text: modelData.record + "  " + modelData.winRate + "%"
                                color: root.overlay0
                                font { pixelSize: 10; family: root.nfFont }
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }

            // Only shown when a username is set but nothing came back, so a
            // network failure is visible rather than looking like no account.
            Text {
                Layout.fillWidth: true
                visible: root.ratingsEnabled && root.ratingsTried && !root.chessStats.ok
                textFormat: Text.PlainText
                text: "Could not reach chess.com for " + Config.chessUsername
                color: root.overlay0
                font { pixelSize: 10; family: root.nfFont }
            }
        }
    }

    component ChessButton: Rectangle {
        id: btn
        property string glyph: ""
        property bool on: false
        property bool usable: true
        signal triggered()

        implicitWidth: 30
        implicitHeight: 28
        radius: 8
        opacity: btn.usable ? 1 : 0.35
        color: btn.on ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
             : btnHov.containsMouse && btn.usable ? root.surface1
             : root.surface0
        Behavior on color { ColorAnimation { duration: 90 } }

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: btn.on ? root.accent : root.subtext0
            font { pixelSize: 14; family: root.nfFont }
        }
        MouseArea {
            id: btnHov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (btn.usable) btn.triggered()
        }
    }
}
