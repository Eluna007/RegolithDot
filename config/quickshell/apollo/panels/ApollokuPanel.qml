import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../services"
import "apolloku/Sudoku.js" as Sudoku
import "apolloku/Model.js" as Model

// Apolloku — sudoku in the bar.
//
// The puzzle logic lives in apolloku/Sudoku.js and apolloku/Model.js, which
// are plain ECMAScript and are covered by scripts/test-apolloku.js under node.
// This file is only presentation and input: anything worth asserting about
// belongs next door where it can be tested.
PanelWindow {
    id: root
    signal close()

    // ── Opening ──────────────────────────────────────────────────────────
    // The card unrolls out of the bar edge: its own clip does the masking, so
    // the text is uncovered at full size rather than scaled up out of a blur.
    // This is how Caelestia's popouts read, and why they look attached to the
    // bar instead of appearing next to it.
    //
    // `running: visible` rather than a NumberAnimation-on-property with
    // `running: true`. shell.qml creates every panel eagerly and toggles it
    // with `visible`, so an animation that starts on component completion
    // fires once, at login, while the panel is hidden — and is never seen
    // again. That is why the old fade was invisible.
    //
    // Defaults to 1, so a panel is fully drawn even if this never runs.
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

    anchors.top: true
    anchors.left: Config.barPosition === "left"
    anchors.right: Config.barPosition !== "left"
    // Flush with the bar, not floating beside it — see Config.barEdge.
    margins.top: Config.barPosition === "top" ? Config.barEdge : 10
    margins.left: Config.barPosition === "left" ? Config.barEdge : 0
    margins.right: Config.barPosition === "right" ? Config.barEdge : 0
    exclusiveZone: 0
    implicitWidth: 372
    implicitHeight: akContent.implicitHeight + 10
    color: "transparent"

    // Digits and arrows have to reach the board rather than the focused window.
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
    property string difficulty: "Medium"
    property string rating: ""          // what the puzzle measured as
    property var puzzle:   Sudoku.emptyGrid()
    property var solution: Sudoku.emptyGrid()
    property var cells:    Sudoku.emptyGrid()
    property var notes:    Sudoku.emptyNotes()
    property int selected: 40
    property bool notesMode: false
    property bool solved: false
    property bool paused: false
    property bool started: false
    property int hintsUsed: 0
    property var undoStack: []
    property var redoStack: []
    property var stats: Model.emptyStats()
    property bool statsLoaded: false
    property bool saveLoaded: false

    // Cell edge in pixels. The board delegates, the 3x3 rules and the
    // confetti launch points all derive from this, so it lives in one place.
    readonly property real cellPx: 36

    readonly property var conflicts: Sudoku.conflicts(cells)
    readonly property var digitCounts: Sudoku.digitCounts(cells)
    readonly property int filled: Sudoku.filledCount(cells)
    readonly property bool playable: started && !solved && !paused && !generating

    function isGiven(i) { return puzzle[i] !== 0 }

    // ── Clock ───────────────────────────────────────────────────────────
    property real accumulatedMs: 0
    property real runningSince: 0
    property int tick: 0
    // `tick` is referenced so the binding re-evaluates every half second;
    // Date.now() is not a property and would otherwise never invalidate it.
    readonly property real elapsedMs: {
        tick
        return accumulatedMs + (runningSince > 0 ? (Date.now() - runningSince) : 0)
    }

    Timer {
        interval: 500; running: root.runningSince > 0 && root.visible; repeat: true
        onTriggered: root.tick++
    }
    function startClock() { if (runningSince <= 0) runningSince = Date.now() }
    function stopClock() {
        if (runningSince > 0) { accumulatedMs += Date.now() - runningSince; runningSince = 0 }
    }

    // ── Celebration ─────────────────────────────────────────────────────
    //
    // One NumberAnimation drives every piece through arithmetic on a single
    // progress value, rather than ~320 Rectangles each animating themselves.
    // Ported from the pre-apollo version, which got this right.
    property bool celebrating: false
    property bool celebrateDone: false
    property real celebrateProgress: 0
    property var confetti: []
    readonly property real pieceLife: 0.28

    // Confetti takes its colours from the palette, so it recolours with the
    // wallpaper like everything else rather than being permanently festive.
    readonly property var confettiColors: [accent, teal, peach, Config.blue, Config.green]

    function buildCelebration() {
        var order = []
        for (var i = 0; i < 81; i++) order.push(i)
        for (var j = order.length - 1; j > 0; j--) {
            var k = Math.floor(Math.random() * (j + 1))
            var swap = order[j]; order[j] = order[k]; order[k] = swap
        }
        var pieces = []
        var window = 1.0 - pieceLife
        for (var n = 0; n < 81; n++) {
            var index = order[n]
            var delay = window * (n / 80)
            var cx = (index % 9) * (cellPx + 1) + cellPx / 2
            var cy = Math.floor(index / 9) * (cellPx + 1) + cellPx / 2
            for (var q = 0; q < 4; q++) {
                var angle = Math.random() * Math.PI * 2
                var speed = cellPx * (0.6 + Math.random() * 1.1)
                pieces.push({
                    delay: delay, x0: cx, y0: cy,
                    vx: Math.cos(angle) * speed,
                    vy: Math.sin(angle) * speed - cellPx * 0.5,
                    spin: (Math.random() * 2 - 1) * 540,
                    size: Math.max(2, Math.round(cellPx * (0.10 + Math.random() * 0.09))),
                    hue: Math.floor(Math.random() * confettiColors.length)
                })
            }
        }
        confetti = pieces
    }

    function startCelebration() {
        if (!started || !solved) return
        buildCelebration()
        celebrateDone = false
        celebrateProgress = 0
        celebrating = true
        popAnimation.restart()
    }

    function endCelebration() {
        holdTimer.stop()
        popAnimation.stop()
        celebrating = false
        celebrateDone = false
        celebrateProgress = 0
        confetti = []          // let ~320 delegates go rather than keep them alive
    }

    NumberAnimation {
        id: popAnimation
        target: root
        property: "celebrateProgress"
        from: 0; to: 1; duration: 2600
        onFinished: { root.celebrateDone = true; holdTimer.restart() }
    }
    Timer { id: holdTimer; interval: 5000; onTriggered: root.endCelebration() }

    // ── Generation, one attempt per frame ───────────────────────────────
    //
    // Carving a rated puzzle can take a few hundred milliseconds in total, and
    // this runs on the thread that draws the bar. Sudoku.js exposes the run as
    // discrete attempts so the work can be spread across frames instead of
    // freezing everything at the moment you ask for a new game.
    property var generator: null
    property bool generating: false
    property real genProgress: 0

    Timer {
        id: genTimer
        interval: 16; repeat: true; running: root.generating
        onTriggered: {
            if (!root.generator) { root.generating = false; return }
            if (Sudoku.step(root.generator)) {
                root.applyGenerated(root.generator.result)
                root.generator = null
                root.generating = false
                root.genProgress = 1
            } else {
                root.genProgress = Sudoku.progress(root.generator)
            }
        }
    }

    function newGame(level) {
        endCelebration()
        var want = Model.normalizeDifficulty(level, difficulty)
        // Abandoning a game in progress breaks the streak; starting from an
        // idle or finished board does not.
        if (started && !solved) stats = Model.recordAbandon(stats)
        difficulty = want
        rating = ""
        generator = Sudoku.createGenerator(want)
        genProgress = 0
        generating = true
        stopClock()
        accumulatedMs = 0
        runningSince = 0
    }

    function applyGenerated(g) {
        puzzle = g.puzzle
        solution = g.solution
        cells = g.puzzle.slice()
        notes = Sudoku.emptyNotes()
        rating = g.rating || g.difficulty
        selected = firstEmptyCell()
        notesMode = false
        solved = false
        paused = false
        started = true
        hintsUsed = 0
        undoStack = []
        redoStack = []
        stats = Model.recordStart(stats, difficulty, false)
        saveStats()
        accumulatedMs = 0
        startClock()
        persist()
    }

    function firstEmptyCell() {
        for (var i = 0; i < 81; i++) if (cells[i] === 0) return i
        return 40
    }

    // ── Moves ───────────────────────────────────────────────────────────
    function snapshot() {
        return { cells: cells.slice(), notes: notes.slice(), selected: selected }
    }
    function pushUndo() {
        var stack = undoStack.slice()
        stack.push(snapshot())
        if (stack.length > 200) stack.shift()
        undoStack = stack
        redoStack = []
    }
    function undo() {
        if (undoStack.length === 0) return
        var stack = undoStack.slice()
        var prev = stack.pop()
        var redo = redoStack.slice()
        redo.push(snapshot())
        undoStack = stack
        redoStack = redo
        cells = prev.cells
        notes = prev.notes
        selected = prev.selected
        solved = Sudoku.isComplete(cells)
        persist()
    }
    function redo() {
        if (redoStack.length === 0) return
        var redoS = redoStack.slice()
        var next = redoS.pop()
        var stack = undoStack.slice()
        stack.push(snapshot())
        redoStack = redoS
        undoStack = stack
        cells = next.cells
        notes = next.notes
        selected = next.selected
        solved = Sudoku.isComplete(cells)
        persist()
    }

    function setDigit(digit) {
        if (!playable || isGiven(selected)) return
        if (notesMode) { toggleNote(selected, digit); return }
        pushUndo()
        var next = cells.slice()
        // Tapping the digit already in the cell clears it, so the pad can both
        // place and erase without reaching for a separate key.
        next[selected] = (next[selected] === digit) ? 0 : digit
        cells = next
        if (next[selected] !== 0) notes = Sudoku.clearPeerNotes(notes, selected, digit)
        refreshSolved()
        persist()
    }

    function clearCell() {
        if (!playable || isGiven(selected)) return
        pushUndo()
        var next = cells.slice()
        next[selected] = 0
        cells = next
        var n = notes.slice()
        n[selected] = 0
        notes = n
        solved = false
        persist()
    }

    function toggleNote(index, digit) {
        if (!playable || isGiven(index) || cells[index] !== 0) return
        pushUndo()
        var n = notes.slice()
        n[index] = Sudoku.toggleNote(n[index], digit)
        notes = n
        persist()
    }

    function fillNotes() {
        if (!playable) return
        pushUndo()
        notes = Sudoku.fillAllNotes(cells)
        persist()
    }

    function hint() {
        if (!playable) return
        // Fill the selected cell when it is wrong or empty, otherwise the
        // first cell that needs help — so a hint is never a no-op.
        var target = -1
        if (!isGiven(selected) && cells[selected] !== solution[selected]) target = selected
        if (target === -1) {
            for (var i = 0; i < 81; i++) {
                if (cells[i] !== solution[i]) { target = i; break }
            }
        }
        if (target === -1) return
        pushUndo()
        var next = cells.slice()
        next[target] = solution[target]
        cells = next
        notes = Sudoku.clearPeerNotes(notes, target, solution[target])
        selected = target
        hintsUsed++
        refreshSolved()
        persist()
    }

    function refreshSolved() {
        var done = Sudoku.isComplete(cells)
        var newlySolved = done && !solved
        if (newlySolved) {
            stopClock()
            stats = Model.recordSolve(stats, difficulty, elapsedMs, hintsUsed)
            saveStats()
        }
        solved = done
        // After `solved` is set, not before: startCelebration checks it.
        if (newlySolved) startCelebration()
    }

    function moveCursor(dx, dy) {
        var r = Math.floor(selected / 9) + dy
        var c = (selected % 9) + dx
        if (r < 0 || r > 8 || c < 0 || c > 8) return
        selected = r * 9 + c
    }

    function togglePause() {
        if (!started || solved || generating) return
        paused = !paused
        if (paused) stopClock(); else startClock()
        persist()
    }

    // ── Persistence ─────────────────────────────────────────────────────
    //
    // Reads go through FileView, which this shell already uses elsewhere.
    // Writes go through Process, because FileView's write API is not used
    // anywhere in this codebase and an unknown property or signal in QML is a
    // load-time error that would take the whole bar down, not just this panel.
    //
    // The JSON travels as an argv entry rather than on stdin: `command` is the
    // Process API this shell already relies on, and a save is a couple of KB,
    // far inside any argv limit.
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string saveDir: homeDir + "/.config/apollo"

    FileView {
        id: saveFile
        path: root.saveDir + "/apolloku.json"
        onLoaded: {
            if (root.saveLoaded) return
            root.saveLoaded = true
            var st = Model.parse(text())
            if (!st) return
            root.difficulty = st.difficulty
            root.puzzle = st.puzzle
            root.solution = st.solution
            root.cells = st.cells
            root.notes = st.notes
            root.selected = st.selected
            root.notesMode = st.notesMode
            root.solved = st.solved
            root.hintsUsed = st.hintsUsed
            root.accumulatedMs = st.elapsedMs
            root.started = true
            // Resume paused. The clock should not have been running while the
            // shell was closed, and silently adding that time would poison
            // every best-time in the stats.
            root.paused = !st.solved
        }
    }

    FileView {
        id: statsFile
        path: root.saveDir + "/apolloku-stats.json"
        onLoaded: {
            if (root.statsLoaded) return
            root.statsLoaded = true
            root.stats = Model.parseStats(text())
        }
    }

    // One writer, queued. Setting `running` on a Process that is already
    // running does nothing, so a save landing mid-write would otherwise be
    // silently dropped - which for a save file means losing the last move.
    property var pendingWrites: ({})
    // onRunningChanged, not onExited: that is the Process idiom this shell
    // already uses (BtPanel, WifiPanel). Process has no `exited` signal here.
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
        if (!started) return
        queueWrite(saveFile.path, Model.serialize({
            difficulty: difficulty, puzzle: puzzle, solution: solution,
            cells: cells, notes: notes, elapsedMs: elapsedMs,
            hintsUsed: hintsUsed, selected: selected,
            notesMode: notesMode, solved: solved
        }))
    }
    function saveStats() { queueWrite(statsFile.path, Model.serializeStats(stats)) }

    // Persist on close rather than on every keystroke: the elapsed time is the
    // only thing that changes continuously, and losing a few seconds of it is
    // not worth a file write per frame.
    onVisibleChanged: {
        if (visible) {
            if (started && !solved && paused) { /* stay paused until resumed */ }
        } else {
            endCelebration()
            stopClock()
            persist()
        }
    }

    // ── Layout ──────────────────────────────────────────────────────────
    Rectangle {
        id: akContent
        width: parent.width
        // + 2 * the column's margin, or the inset costs height off the bottom
        implicitHeight: akCol.implicitHeight + 28
        radius: 22
        color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.70)
        border.width: 1
        border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)
        clip: true

        Rectangle { anchors.top: parent.top; anchors.right: parent.right; width: 22; height: 22; color: parent.color }
        // Revealed rather than faded: see `reveal` on the root.
        height: Math.max(1, Math.round(implicitHeight * root.reveal))
        opacity: Math.min(1, root.reveal * 2)

        focus: true
        Keys.onPressed: ev => {
            if (ev.key === Qt.Key_Escape) {
                if (root.celebrating) root.endCelebration()
                else root.close()
                ev.accepted = true; return
            }
            if (ev.key >= Qt.Key_1 && ev.key <= Qt.Key_9) {
                root.setDigit(ev.key - Qt.Key_0); ev.accepted = true; return
            }
            if (ev.key === Qt.Key_0 || ev.key === Qt.Key_Delete || ev.key === Qt.Key_Backspace) {
                root.clearCell(); ev.accepted = true; return
            }
            if (ev.key === Qt.Key_Left)  { root.moveCursor(-1, 0); ev.accepted = true; return }
            if (ev.key === Qt.Key_Right) { root.moveCursor(1, 0);  ev.accepted = true; return }
            if (ev.key === Qt.Key_Up)    { root.moveCursor(0, -1); ev.accepted = true; return }
            if (ev.key === Qt.Key_Down)  { root.moveCursor(0, 1);  ev.accepted = true; return }
            if (ev.key === Qt.Key_N)     { root.notesMode = !root.notesMode; ev.accepted = true; return }
            if (ev.key === Qt.Key_H)     { root.hint(); ev.accepted = true; return }
            if (ev.key === Qt.Key_U)     { root.undo(); ev.accepted = true; return }
            if (ev.key === Qt.Key_R)     { root.redo(); ev.accepted = true; return }
            if (ev.key === Qt.Key_F)     { root.fillNotes(); ev.accepted = true; return }
            if (ev.key === Qt.Key_Space) { root.togglePause(); ev.accepted = true; return }
        }

        ColumnLayout {
            id: akCol
            // parent.width minus both margins: anchoring top-left with a
            // margin does not shrink an explicit width, it just pushes the
            // right edge outside the card.
            width: parent.width - 28
            anchors { top: parent.top; left: parent.left }
            anchors.margins: 14
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "APOLLOKU"
                    color: root.subtext0
                    font { pixelSize: 11; bold: true; family: root.nfFont; letterSpacing: 2 }
                }
                Item { Layout.fillWidth: true }
                Text {
                    // Show what the puzzle measured as. When that differs from
                    // what was asked for, say so rather than quietly lying:
                    // the generator gets within one step, not always exact.
                    text: !root.started ? ""
                        : root.rating !== "" && root.rating !== root.difficulty
                          ? root.difficulty + " → " + root.rating
                          : root.difficulty
                    color: root.overlay0
                    font { pixelSize: 10; family: root.nfFont }
                }
                Text {
                    text: root.started ? Model.formatTime(root.elapsedMs) : ""
                    color: root.paused ? root.overlay0 : root.accent
                    font { pixelSize: 12; bold: true; family: root.nfFont }
                }
            }

            // Status line
            Text {
                Layout.fillWidth: true
                text: root.generating ? "GENERATING " + Math.round(root.genProgress * 100) + "%"
                    : Model.statusText({
                        state: !root.started ? "idle" : root.solved ? "solved" : root.paused ? "paused" : "playing",
                        filled: root.filled, notesMode: root.notesMode, hintsUsed: root.hintsUsed
                      })
                color: root.solved ? root.teal : root.subtext0
                font { pixelSize: 10; bold: true; family: root.nfFont; letterSpacing: 1 }
            }

            // ── Board ───────────────────────────────────────────────────
            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: board.width
                implicitHeight: board.height


                Grid {
                    id: board
                    columns: 9
                    spacing: 1

                    Repeater {
                        model: 81
                        delegate: Rectangle {
                            id: cell
                            required property int index

                            width: root.cellPx; height: root.cellPx
                            radius: 4

                            readonly property int value: root.cells[index]
                            readonly property bool given: root.isGiven(index)
                            readonly property bool isSelected: root.selected === index
                            readonly property bool bad: root.conflicts[index]
                            readonly property bool peer:
                                !isSelected &&
                                (Sudoku.rowOf(index) === Sudoku.rowOf(root.selected) ||
                                 Sudoku.colOf(index) === Sudoku.colOf(root.selected) ||
                                 Sudoku.boxOf(index) === Sudoku.boxOf(root.selected))
                            readonly property bool sameDigit:
                                value !== 0 && value === root.cells[root.selected] && !isSelected

                            color: root.paused ? root.surface0
                                 : bad ? Qt.rgba(root.maroon.r, root.maroon.g, root.maroon.b, 0.28)
                                 : isSelected ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.30)
                                 : sameDigit ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)
                                 : peer ? root.surface1
                                 : root.surface0
                            Behavior on color { ColorAnimation { duration: 90 } }

                            // The placed digit.
                            Text {
                                anchors.centerIn: parent
                                visible: cell.value !== 0 && !root.paused
                                text: cell.value
                                color: cell.bad ? root.maroon
                                     : cell.given ? root.text
                                     : root.accent
                                font {
                                    pixelSize: 17
                                    bold: cell.given
                                    family: root.nfFont
                                }
                            }

                            // Pencil marks, in their natural 3x3 positions so a
                            // 5 always sits in the middle.
                            Grid {
                                anchors.centerIn: parent
                                columns: 3
                                visible: cell.value === 0 && root.notes[cell.index] !== 0 && !root.paused
                                Repeater {
                                    model: 9
                                    delegate: Text {
                                        required property int index
                                        width: 11; height: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        text: Sudoku.hasNote(root.notes[cell.index], index + 1) ? String(index + 1) : ""
                                        color: root.overlay0
                                        font { pixelSize: 8; family: root.nfFont }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.paused || root.generating) return
                                    root.selected = cell.index
                                }
                            }
                        }
                    }
                }

                // The 3x3 box separators, drawn over the cells. Doing it this
                // way keeps the grid a plain uniform Grid rather than nine
                // nested ones.
                Repeater {
                    model: 2
                    delegate: Rectangle {
                        required property int index
                        x: (index + 1) * ((root.cellPx + 1) * 3) - 2
                        y: 0
                        width: 2
                        height: board.height
                        color: Qt.rgba(root.text.r, root.text.g, root.text.b, 0.25)
                    }
                }
                Repeater {
                    model: 2
                    delegate: Rectangle {
                        required property int index
                        x: 0
                        y: (index + 1) * ((root.cellPx + 1) * 3) - 2
                        width: board.width
                        height: 2
                        color: Qt.rgba(root.text.r, root.text.g, root.text.b, 0.25)
                    }
                }

                // Confetti. Every piece is pure arithmetic on celebrateProgress,
                // so one animation drives all ~320 of them.
                Item {
                    anchors.fill: parent
                    visible: root.celebrating
                    z: 10

                    Repeater {
                        model: root.confetti
                        delegate: Rectangle {
                            required property var modelData
                            readonly property real t: Math.max(0, Math.min(1,
                                (root.celebrateProgress - modelData.delay) / root.pieceLife))

                            visible: t > 0 && t < 1
                            width: modelData.size
                            height: modelData.size
                            radius: modelData.size > 4 ? 1 : 0
                            color: root.confettiColors[modelData.hue]
                            opacity: 1 - t * t
                            rotation: modelData.spin * t
                            x: modelData.x0 + modelData.vx * t - width / 2
                            // t² is gravity: the pieces arc rather than drift.
                            y: modelData.y0 + modelData.vy * t + root.cellPx * 3.2 * t * t - height / 2
                        }
                    }
                }

                // The result, once the confetti has settled.
                Item {
                    anchors.fill: parent
                    visible: root.celebrating
                    z: 11

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.86
                        height: card.implicitHeight + 24
                        radius: 16
                        color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.88)
                        border.width: 1
                        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
                        opacity: root.celebrateDone ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 260 } }

                        Column {
                            id: card
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.hintsUsed > 0 ? "Solved" : "Solved clean"
                                color: root.teal
                                font { pixelSize: 16; bold: true; family: root.nfFont }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (root.rating !== "" ? root.rating : root.difficulty)
                                      + " in " + Model.formatTime(root.elapsedMs)
                                color: root.subtext0
                                font { pixelSize: 11; family: root.nfFont }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    var b = root.stats.byDifficulty[root.difficulty]
                                    if (!b || b.bestMs <= 0) return ""
                                    if (Math.round(root.elapsedMs) <= b.bestMs) return "new personal best"
                                    return "best " + Model.formatTime(b.bestMs)
                                }
                                visible: text !== ""
                                color: text === "new personal best" ? root.peach : root.overlay0
                                font { pixelSize: 10; family: root.nfFont }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.hintsUsed > 0
                                      ? root.hintsUsed + (root.hintsUsed === 1 ? " hint" : " hints") : ""
                                visible: text !== ""
                                color: root.overlay0
                                font { pixelSize: 10; family: root.nfFont }
                            }
                        }
                    }

                    // Click anywhere to dismiss rather than waiting it out.
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.celebrating
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.endCelebration()
                    }
                }

                // Paused / idle veil
                Rectangle {
                    anchors.fill: parent
                    visible: root.paused || !root.started || root.generating
                    color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.82)
                    radius: 6
                    Text {
                        anchors.centerIn: parent
                        text: root.generating ? "…"
                            : root.paused ? "\u{f03e4}"
                            : "\u{f04d3}"
                        color: root.overlay0
                        font { pixelSize: 30; family: root.nfFont }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: root.generating ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: {
                            if (root.generating) return
                            if (root.paused) root.togglePause()
                            else if (!root.started) root.newGame(root.difficulty)
                        }
                    }
                }
            }

            // ── Number pad ──────────────────────────────────────────────
            Grid {
                Layout.alignment: Qt.AlignHCenter
                columns: 9
                spacing: 3

                Repeater {
                    model: 9
                    delegate: Rectangle {
                        id: padKey
                        required property int index
                        readonly property int digit: index + 1
                        // A digit placed nine times is finished; greying it out
                        // saves counting the board by eye.
                        readonly property bool exhausted: root.digitCounts[index] >= 9

                        width: 34; height: 32; radius: 8
                        color: padHov.containsMouse && root.playable
                               ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                               : root.surface0
                        Behavior on color { ColorAnimation { duration: 90 } }

                        Text {
                            anchors.centerIn: parent
                            text: padKey.digit
                            color: padKey.exhausted ? root.overlay0
                                 : root.notesMode ? root.peach : root.text
                            font { pixelSize: 15; bold: true; family: root.nfFont }
                        }
                        MouseArea {
                            id: padHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setDigit(padKey.digit)
                        }
                    }
                }
            }

            // ── Actions ─────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                AkButton {
                    glyph: "\u{f03eb}"; tip: "Pencil marks (N)"
                    on: root.notesMode
                    usable: root.playable
                    onTriggered: root.notesMode = !root.notesMode
                }
                AkButton {
                    glyph: "\u{f054c}"; tip: "Undo (U)"
                    usable: root.playable && root.undoStack.length > 0
                    onTriggered: root.undo()
                }
                AkButton {
                    glyph: "\u{f0335}"; tip: "Hint (H)"
                    usable: root.playable
                    onTriggered: root.hint()
                }
                AkButton {
                    glyph: "\u{f03e4}"; tip: "Pause (Space)"
                    on: root.paused
                    usable: root.started && !root.solved && !root.generating
                    onTriggered: root.togglePause()
                }

                Item { Layout.fillWidth: true }

                Repeater {
                    model: ["Easy", "Medium", "Hard", "Expert"]
                    delegate: Rectangle {
                        id: lvl
                        required property string modelData
                        readonly property bool current: root.difficulty === modelData

                        implicitWidth: lvlText.implicitWidth + 12
                        implicitHeight: 24
                        radius: 8
                        color: lvl.current ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
                             : lvlHov.containsMouse ? root.surface1 : "transparent"
                        Behavior on color { ColorAnimation { duration: 90 } }

                        Text {
                            id: lvlText
                            anchors.centerIn: parent
                            text: lvl.modelData.charAt(0)
                            color: lvl.current ? root.accent : root.overlay0
                            font { pixelSize: 11; bold: true; family: root.nfFont }
                        }
                        MouseArea {
                            id: lvlHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.newGame(lvl.modelData)
                        }
                    }
                }
            }

            // ── Personal bests ──────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 34
                radius: 12
                color: root.surface0
                visible: root.stats.solved > 0

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10

                    Text {
                        text: root.stats.solved + " solved"
                        color: root.subtext0
                        font { pixelSize: 10; family: root.nfFont }
                    }
                    Text {
                        text: root.stats.streak > 1 ? root.stats.streak + " streak" : ""
                        visible: text !== ""
                        color: root.teal
                        font { pixelSize: 10; family: root.nfFont }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: {
                            var b = root.stats.byDifficulty[root.difficulty]
                            return b && b.bestMs > 0 ? "best " + Model.formatTime(b.bestMs) : ""
                        }
                        visible: text !== ""
                        color: root.overlay0
                        font { pixelSize: 10; family: root.nfFont }
                    }
                }
            }
        }
    }

    // A small square action button. Declared once here rather than repeated
    // four times above.
    component AkButton: Rectangle {
        id: btn
        property string glyph: ""
        property string tip: ""
        property bool on: false
        // Not `enabled`: Item already has one, and redeclaring a built-in
        // property is a load-time error.
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
