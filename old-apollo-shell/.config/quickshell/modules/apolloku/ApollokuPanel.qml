import QtQuick
import Quickshell
import Quickshell.Io
import "Sudoku.js" as Sudoku
import "Model.js" as Model
import "../../services" as Services

// The board itself, built as its own PopupWindow (needs real keyboard focus
// that the shared AnchoredPopup doesn't provide). Ported by hand from
// bhaveshsooka/omadoku (an Omarchy-shell plugin, host-specific and not
// directly runnable here) into a standalone Quickshell widget.
//
// STAGE 2: everything from stage 1 (engine, board, keyboard, undo/redo/hint,
// difficulty select, timer, save/load) plus confirm-before-losing-progress
// prompts, a lifetime stats tab, and the win-confetti celebration.
PopupWindow {
  id: root

  anchor.edges: Edges.Bottom
  anchor.gravity: Edges.Bottom | Edges.Left

  readonly property real cell: 30
  readonly property real boardSize: cell * 9
  implicitWidth: boardSize + 32
  implicitHeight: bg.implicitHeight
  color: "transparent"

  // ----------------------------------------------------------- game state
  property string difficulty: "Medium"
  property var puzzle: Sudoku.emptyGrid()
  property var solution: Sudoku.emptyGrid()
  property var cells: Sudoku.emptyGrid()
  property var notes: Sudoku.emptyNotes()
  property int selected: 40
  property bool notesMode: false
  property bool solved: false
  property bool paused: false
  property bool started: false
  property int hintsUsed: 0
  property var undoStack: []
  property var redoStack: []
  property string selectedDifficulty: "Medium"
  property bool saveLoaded: false
  property bool solveRecorded: false
  property var stats: Model.emptyStats()
  property string view: "board"                 // "board" | "stats"
  property string pendingAction: ""              // "" | "new" | "abandon" | "resetStats"
  property string pendingDifficulty: ""

  readonly property bool canUndo: undoStack.length > 0 && !solved
  readonly property bool canRedo: redoStack.length > 0
  readonly property bool hasProgress: {
    for (var i = 0; i < 81; i++) if (cells[i] !== puzzle[i]) return true
    return false
  }
  readonly property bool canClear: started && hasProgress && !solved
  readonly property bool canAbandon: started && !solved
  readonly property bool canTakeNotes: started && !solved && !paused
  readonly property var conflictMap: Sudoku.conflicts(cells)
  readonly property int filled: Sudoku.filledCount(cells)

  function editable(index) {
    return started && !solved && !paused && index >= 0 && index < 81 && puzzle[index] === 0
  }
  readonly property color fg: Services.Theme.foreground
  function shade(alpha) { return Qt.rgba(fg.r, fg.g, fg.b, alpha) }

  // -------------------------------------------------------------- clock
  property real accumulatedMs: 0
  property real runningSince: 0
  property int tick: 0
  readonly property bool clockRunning: started && !solved && !paused
  readonly property real elapsedMs: {
    var recomputeOn = root.tick
    return root.accumulatedMs + (root.runningSince > 0 ? Math.max(0, Date.now() - root.runningSince) : 0)
  }
  function startClock() { if (runningSince <= 0) runningSince = Date.now() }
  function stopClock() {
    if (runningSince > 0) {
      accumulatedMs += Math.max(0, Date.now() - runningSince)
      runningSince = 0
    }
  }
  onClockRunningChanged: clockRunning ? startClock() : stopClock()

  // --------------------------------------------------------------- undo
  function pushUndo() {
    var next = undoStack.slice()
    next.push({ cells: cells.slice(), notes: notes.slice(), hintsUsed: hintsUsed })
    if (next.length > 200) next.shift()
    undoStack = next
    redoStack = []
  }
  function undo() {
    if (!canUndo) return
    var stack = undoStack.slice()
    var entry = stack.pop()
    var redoNext = redoStack.slice()
    redoNext.push({ cells: cells.slice(), notes: notes.slice(), hintsUsed: hintsUsed })
    undoStack = stack
    redoStack = redoNext
    cells = entry.cells
    notes = entry.notes
    hintsUsed = entry.hintsUsed
    refreshSolved()
    scheduleSave()
  }
  function redo() {
    if (redoStack.length === 0) return
    var stack = redoStack.slice()
    var entry = stack.pop()
    var undoNext = undoStack.slice()
    undoNext.push({ cells: cells.slice(), notes: notes.slice(), hintsUsed: hintsUsed })
    redoStack = stack
    undoStack = undoNext
    cells = entry.cells
    notes = entry.notes
    hintsUsed = entry.hintsUsed
    refreshSolved()
    scheduleSave()
  }

  // --------------------------------------------------------------- moves
  function refreshSolved() { solved = Sudoku.isComplete(cells) }
  function firstEmptyCell() {
    for (var i = 0; i < 81; i++) if (cells[i] === 0) return i
    return 40
  }
  function setCell(index, digit) {
    if (!editable(index)) return
    if (cells[index] === digit) { clearCell(index); return }
    pushUndo()
    var next = cells.slice()
    next[index] = digit
    cells = next
    notes = Sudoku.clearPeerNotes(notes, index, digit)
    refreshSolved()
    scheduleSave()
  }
  function clearCell(index) {
    if (!editable(index)) return
    if (cells[index] === 0 && notes[index] === 0) return
    pushUndo()
    var next = cells.slice()
    next[index] = 0
    cells = next
    var n = notes.slice()
    n[index] = 0
    notes = n
    refreshSolved()
    scheduleSave()
  }
  function toggleNoteAt(index, digit) {
    if (!editable(index)) return
    if (cells[index] !== 0) return
    pushUndo()
    var n = notes.slice()
    n[index] = Sudoku.toggleNote(n[index], digit)
    notes = n
    scheduleSave()
  }
  function fillNotes() {
    if (!started || solved || paused) return
    pushUndo()
    notes = Sudoku.fillAllNotes(cells)
    scheduleSave()
  }
  function hint() {
    if (!started || solved || paused) return
    var index = selected
    if (puzzle[index] !== 0 || cells[index] === solution[index]) {
      var candidates = []
      for (var i = 0; i < 81; i++)
        if (puzzle[i] === 0 && cells[i] !== solution[i]) candidates.push(i)
      if (candidates.length === 0) return
      index = candidates[Math.floor(Math.random() * candidates.length)]
    }
    pushUndo()
    var next = cells.slice()
    next[index] = solution[index]
    cells = next
    notes = Sudoku.clearPeerNotes(notes, index, solution[index])
    hintsUsed = hintsUsed + 1
    selected = index
    refreshSolved()
    scheduleSave()
  }

  function newGame(requested) {
    saveLoaded = true
    var level = Model.normalizeDifficulty(requested || selectedDifficulty, "Medium")
    selectedDifficulty = level
    var previousUnfinished = started && !solved
    var game = Sudoku.generate(level, Math.random)
    stats = Model.recordStart(stats, level, previousUnfinished)
    saveStats()
    solveRecorded = false
    difficulty = level
    puzzle = game.puzzle
    solution = game.solution
    cells = game.puzzle.slice()
    notes = Sudoku.emptyNotes()
    undoStack = []
    redoStack = []
    hintsUsed = 0
    solved = false
    paused = false
    started = true
    view = "board"
    accumulatedMs = 0
    runningSince = 0
    selected = firstEmptyCell()
    if (clockRunning) startClock()
    saveNow()
  }
  function restart() {
    if (!canClear) return
    pushUndo()
    cells = puzzle.slice()
    notes = Sudoku.emptyNotes()
    solved = false
    selected = firstEmptyCell()
    scheduleSave()
  }
  function abandon() {
    if (!canAbandon) return
    stats = Model.recordAbandon(stats)
    saveStats()
    clearToIdle()
  }
  function finishBoard() {
    if (!started || !solved) return
    clearToIdle()
  }
  function clearToIdle() {
    puzzle = Sudoku.emptyGrid()
    solution = Sudoku.emptyGrid()
    cells = Sudoku.emptyGrid()
    notes = Sudoku.emptyNotes()
    undoStack = []
    redoStack = []
    hintsUsed = 0
    solved = false
    solveRecorded = false
    paused = false
    started = false
    view = "board"
    accumulatedMs = 0
    runningSince = 0
    selected = 40
    saveFile.setText("")
  }
  onSolvedChanged: {
    if (!solved) { endCelebration(); return }
    if (!started) return
    if (!solveRecorded) {
      solveRecorded = true
      stats = Model.recordSolve(stats, difficulty, elapsedMs, hintsUsed)
      saveStats()
      scheduleSave()
    }
    if (root.visible) startCelebration()
    else celebratePending = true
  }

  function toggleNotesMode() { if (canTakeNotes) notesMode = !notesMode }
  function togglePause() {
    if (!started || solved) return
    paused = !paused
    scheduleSave()
  }
  function moveCursor(dx, dy) {
    var r = (Math.floor(selected / 9) + dy + 9) % 9
    var c = (selected % 9 + dx + 9) % 9
    selected = r * 9 + c
  }

  // ------------------------------------------------------- confirmation
  function requestNewGame(level) {
    if (!level && started === false && selectedDifficulty === "") return
    if (started && !solved) {
      pendingDifficulty = Model.normalizeDifficulty(level, selectedDifficulty)
      pendingAction = "new"
      return
    }
    newGame(level)
  }
  function requestAbandon() {
    if (!canAbandon) return
    pendingAction = "abandon"
  }
  function requestResetStats() {
    if (stats.started === 0) return
    pendingAction = "resetStats"
  }
  function resetStats() {
    stats = Model.emptyStats()
    saveStats()
  }
  function confirmPending() {
    var action = pendingAction
    var level = pendingDifficulty
    cancelPending()
    if (action === "new") newGame(level)
    else if (action === "abandon") abandon()
    else if (action === "resetStats") resetStats()
  }
  function cancelPending() { pendingAction = ""; pendingDifficulty = "" }
  function confirmPrompt() {
    if (pendingAction === "abandon") return "Abandon this game?"
    if (pendingAction === "new") return "Start a new " + pendingDifficulty.toLowerCase() + " game?"
    if (pendingAction === "resetStats") return "Reset all statistics?"
    return ""
  }
  function confirmDetail() {
    if (pendingAction === "abandon") return "This board and its time are lost, and the streak resets."
    if (pendingAction === "new") return "The current board is lost, and the streak resets."
    if (pendingAction === "resetStats") return "Every solve, time and streak on record is erased. This cannot be undone."
    return ""
  }
  function confirmVerb() {
    if (pendingAction === "abandon") return "Abandon"
    if (pendingAction === "resetStats") return "Reset"
    return "New game"
  }

  // --------------------------------------------------------- win parade
  property bool celebrating: false
  property bool celebrateDone: false
  property real celebrateProgress: 0
  property var confetti: []
  property bool celebratePending: false
  readonly property real pieceLife: 0.28

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
      var cx = (index % 9) * root.cell + root.cell / 2
      var cy = Math.floor(index / 9) * root.cell + root.cell / 2
      for (var p = 0; p < 4; p++) {
        var angle = Math.random() * Math.PI * 2
        var speed = root.cell * (0.6 + Math.random() * 1.1)
        pieces.push({
          delay: delay, x0: cx, y0: cy,
          vx: Math.cos(angle) * speed,
          vy: Math.sin(angle) * speed - root.cell * 0.5,
          spin: (Math.random() * 2 - 1) * 540,
          size: Math.max(2, Math.round(root.cell * (0.10 + Math.random() * 0.09))),
          tone: 0.45 + Math.random() * 0.55
        })
      }
    }
    confetti = pieces
  }
  function startCelebration() {
    if (!started || !solved) return
    celebratePending = false
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
    celebratePending = false
    celebrateDone = false
    celebrateProgress = 0
    confetti = []
  }

  // -------------------------------------------------------- keyboard
  function handleTextKey(text) {
    if (celebrating) endCelebration()
    if (pendingAction !== "") {
      if (text === "y" || text === "Y") confirmPending()
      else if (text === "n" || text === "N") cancelPending()
      return
    }
    if (!started) {
      if (text >= "1" && text <= "4") selectedDifficulty = ["Easy","Medium","Hard","Expert"][parseInt(text,10)-1]
      else if (text === "g" || text === "G") requestNewGame(selectedDifficulty)
      else if (text === "s" || text === "S") view = "stats"
      return
    }
    if (view === "stats") {
      if (text === "s" || text === "S" || text === "b" || text === "B") view = "board"
      else if (text === "g" || text === "G") requestNewGame(selectedDifficulty)
      return
    }
    if (text >= "1" && text <= "9") {
      var digit = parseInt(text, 10)
      if (notesMode) toggleNoteAt(selected, digit)
      else setCell(selected, digit)
      return
    }
    if (text === "0" || text === ".") { clearCell(selected); return }
    switch (text) {
      case "n": case "N": toggleNotesMode(); break
      case "u": case "U": undo(); break
      case "r": case "R": redo(); break
      case "g": case "G": requestNewGame(selectedDifficulty); break
      case "a": case "A": fillNotes(); break
      case "p": case "P": togglePause(); break
      case "c": case "C": restart(); break
      case "s": case "S": view = "stats"; break
      case "?": hint(); break
    }
  }

  // ----------------------------------------------------------- persistence
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/apolloku/"
  readonly property string savePath: stateDir + "game.json"
  readonly property string statsPath: stateDir + "stats.json"

  function saveNow() {
    if (!saveLoaded || !started) return
    saveFile.setText(Model.serialize({
      difficulty: difficulty, puzzle: puzzle, solution: solution, cells: cells,
      notes: notes, elapsedMs: elapsedMs, hintsUsed: hintsUsed,
      selected: selected, notesMode: notesMode, solved: solved
    }))
  }
  function scheduleSave() { saveTimer.restart() }
  function saveStats() { statsSaveTimer.restart() }
  function loadSave(text) {
    var saved = Model.parse(text)
    saveLoaded = true
    if (!saved) return
    difficulty = saved.difficulty
    puzzle = saved.puzzle
    solution = saved.solution
    cells = saved.cells
    notes = saved.notes
    accumulatedMs = saved.elapsedMs
    runningSince = 0
    hintsUsed = saved.hintsUsed
    selected = saved.selected
    notesMode = saved.notesMode
    selectedDifficulty = saved.difficulty
    undoStack = []
    redoStack = []
    started = true
    solved = Sudoku.isComplete(saved.cells)
    solveRecorded = solved
    paused = true
  }

  function open() { root.visible = true; if (celebratePending) startCelebration() }
  function close() {
    if (started && !solved) paused = true
    saveNow()
    root.visible = false
  }
  function toggle() { root.visible ? close() : open() }
  onVisibleChanged: if (visible) Qt.callLater(function() { keyCatcher.forceActiveFocus() })

  Item {
    Timer { interval: 500; repeat: true; running: root.clockRunning; onTriggered: root.tick++ }
    Timer { interval: 15000; repeat: true; running: root.clockRunning; onTriggered: root.saveNow() }
    Timer { id: saveTimer; interval: 400; repeat: false; onTriggered: root.saveNow() }
    Timer { id: statsSaveTimer; interval: 400; repeat: false; onTriggered: statsFile.setText(Model.serializeStats(root.stats)) }

    NumberAnimation {
      id: popAnimation
      target: root
      property: "celebrateProgress"
      from: 0; to: 1; duration: 2600
      onFinished: { root.celebrateDone = true; holdTimer.restart() }
    }
    Timer { id: holdTimer; interval: 5000; onTriggered: root.endCelebration() }

    Process { id: ensureDirProc; command: ["mkdir", "-p", root.stateDir] }

    FileView {
      id: statsFile
      path: Qt.resolvedUrl(root.statsPath)
      watchChanges: false
      atomicWrites: true
      printErrors: false
      onLoaded: root.stats = Model.parseStats(text())
      onLoadFailed: root.stats = Model.parseStats("")
    }
    FileView {
      id: saveFile
      path: Qt.resolvedUrl(root.savePath)
      watchChanges: false
      atomicWrites: true
      printErrors: false
      onLoaded: root.loadSave(text())
      onLoadFailed: root.loadSave("")
    }
  }
  Component.onCompleted: {
    ensureDirProc.running = true
    Qt.callLater(function() { saveFile.reload(); statsFile.reload() })
  }

  // ------------------------------------------------------------------ UI
  Rectangle {
    id: bg
    anchors.fill: parent
    implicitHeight: col.implicitHeight + 24
    radius: 16
    color: Qt.rgba(Services.Theme.surface.r, Services.Theme.surface.g, Services.Theme.surface.b, 0.97)
    border.width: 1
    border.color: Services.Theme.pillBorder

    transformOrigin: Item.Top
    scale: root.visible ? 1 : 0.85
    opacity: root.visible ? 1 : 0
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }
    Behavior on opacity { NumberAnimation { duration: 150 } }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        if (root.celebrating) { root.endCelebration(); event.accepted = true; return }
        if (event.key === Qt.Key_Tab) {
          root.view = (root.view === "board") ? "stats" : "board"
          event.accepted = true; return
        }
        if (event.key === Qt.Key_Escape) {
          if (root.pendingAction !== "") root.cancelPending()
          else if (root.view !== "board") root.view = "board"
          else root.close()
          event.accepted = true; return
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          if (root.pendingAction !== "") root.confirmPending()
          else if (!root.started) root.newGame(root.selectedDifficulty)
          event.accepted = true; return
        }
        if (event.key === Qt.Key_Space) {
          if (root.pendingAction !== "") root.confirmPending()
          else if (!root.started) root.requestNewGame(root.selectedDifficulty)
          else if (root.view === "board") root.toggleNotesMode()
          event.accepted = true; return
        }
        if (event.key === Qt.Key_Left || event.text === "h")  { root.moveCursor(-1, 0); event.accepted = true; return }
        if (event.key === Qt.Key_Right || event.text === "l") { root.moveCursor(1, 0); event.accepted = true; return }
        if (event.key === Qt.Key_Up || event.text === "k")    { root.moveCursor(0, -1); event.accepted = true; return }
        if (event.key === Qt.Key_Down || event.text === "j")  { root.moveCursor(0, 1); event.accepted = true; return }
        if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) {
          if (root.pendingAction === "" && root.view === "board") root.clearCell(root.selected)
          event.accepted = true; return
        }
        if (event.text) { root.handleTextKey(event.text); event.accepted = true }
      }

      Column {
        id: col
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
        spacing: 8

        Row {
          width: parent.width
          Text {
            text: "Apolloku"
            color: Services.Theme.foreground
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
            opacity: 0.7
            anchors.verticalCenter: parent.verticalCenter
          }
          Item { width: 8; height: 1 }
          Text {
            visible: root.started
            text: root.view === "board" ? "Stats" : "Board"
            color: Services.Theme.pillAccent
            font.pixelSize: Services.Theme.fontSizeSmall - 2
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.view = (root.view === "board") ? "stats" : "board"
            }
          }
          Item { width: parent.width - 210; height: 1 }
          Text {
            visible: root.started
            text: Model.formatTime(root.elapsedMs)
            color: Services.Theme.foreground
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Text {
          visible: root.pendingAction === ""
          text: root.solved ? (root.hintsUsed > 0 ? "SOLVED WITH " + root.hintsUsed + " HINT" + (root.hintsUsed === 1 ? "" : "S") : "SOLVED")
              : root.paused ? "PAUSED"
              : !root.started ? "CHOOSE A DIFFICULTY"
              : root.view === "stats" ? "LIFETIME STATS"
              : root.notesMode ? "PENCIL MARKS"
              : (81 - root.filled) + " TO GO"
          color: Services.Theme.pillAccent
          font.pixelSize: Services.Theme.fontSizeSmall
          font.family: Services.Theme.fontFamily
        }

        // ---------- difficulty + start (idle) ----------
        Row {
          visible: !root.started && root.pendingAction === ""
          width: parent.width
          spacing: 6
          readonly property real cw: (width - spacing * 3) / 4
          Repeater {
            model: ["Easy", "Medium", "Hard", "Expert"]
            delegate: Rectangle {
              required property var modelData
              width: parent.cw
              height: 26
              radius: 8
              color: root.selectedDifficulty === modelData ? Services.Theme.pillAccent
                   : diffMa.containsMouse ? Services.Theme.hoverBg : Services.Theme.pillColor
              border.width: 1
              border.color: Services.Theme.pillBorder
              Text {
                anchors.centerIn: parent
                text: modelData
                color: root.selectedDifficulty === modelData ? Services.Theme.background : Services.Theme.foreground
                font.pixelSize: Services.Theme.fontSizeSmall - 1
                font.family: Services.Theme.fontFamily
              }
              MouseArea {
                id: diffMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.selectedDifficulty = modelData
              }
            }
          }
        }
        Rectangle {
          visible: !root.started && root.pendingAction === ""
          width: parent.width
          height: 30
          radius: 8
          color: Services.Theme.pillAccent
          Text {
            anchors.centerIn: parent
            text: "Start"
            color: Services.Theme.background
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.newGame(root.selectedDifficulty)
          }
        }

        // ---------- board ----------
        Item {
          visible: root.started && root.view === "board" && root.pendingAction === ""
          width: parent.width
          implicitHeight: root.boardSize

          Item {
            id: board
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.boardSize
            height: root.boardSize

            Repeater {
              model: 81
              delegate: Item {
                id: cellItem
                required property int index
                readonly property int value: root.cells[index]
                readonly property int noteMask: root.notes[index]
                readonly property bool given: root.puzzle[index] !== 0
                readonly property bool isSelected: root.selected === index
                readonly property bool isPeer: !isSelected
                  && (Sudoku.rowOf(index) === Sudoku.rowOf(root.selected)
                      || Sudoku.colOf(index) === Sudoku.colOf(root.selected)
                      || Sudoku.boxOf(index) === Sudoku.boxOf(root.selected))
                readonly property bool isSameDigit: !isSelected
                  && value !== 0 && value === root.cells[root.selected]
                readonly property bool isConflict: root.conflictMap.length === 81 && root.conflictMap[index]

                x: (index % 9) * root.cell
                y: Math.floor(index / 9) * root.cell
                width: root.cell
                height: root.cell

                Rectangle {
                  anchors.fill: parent
                  color: cellItem.isSelected ? root.shade(0.22)
                       : cellItem.isSameDigit ? root.shade(0.13)
                       : cellItem.isPeer ? root.shade(0.06)
                       : "transparent"
                  Behavior on color { ColorAnimation { duration: 110 } }
                }
                Text {
                  anchors.centerIn: parent
                  visible: cellItem.value !== 0
                  text: cellItem.value === 0 ? "" : String(cellItem.value)
                  color: cellItem.isConflict ? Services.Theme.errorColor : Services.Theme.foreground
                  font.bold: cellItem.given
                  opacity: cellItem.given ? 1.0 : 0.82
                  font.family: Services.Theme.fontFamily
                  font.pixelSize: Math.round(root.cell * 0.56)
                }
                Grid {
                  anchors.centerIn: parent
                  visible: cellItem.value === 0 && cellItem.noteMask !== 0
                  columns: 3
                  spacing: 0
                  Repeater {
                    model: 9
                    delegate: Text {
                      required property int index
                      width: Math.round(root.cell / 3)
                      height: Math.round(root.cell / 3)
                      horizontalAlignment: Text.AlignHCenter
                      verticalAlignment: Text.AlignVCenter
                      text: Sudoku.hasNote(cellItem.noteMask, index + 1) ? String(index + 1) : ""
                      color: Services.Theme.foreground
                      opacity: 0.5
                      font.family: Services.Theme.fontFamily
                      font.pixelSize: Math.round(root.cell * 0.24)
                    }
                  }
                }
                MouseArea {
                  anchors.fill: parent
                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                  cursorShape: Qt.PointingHandCursor
                  onClicked: function(mouse) {
                    root.selected = cellItem.index
                    keyCatcher.forceActiveFocus()
                    if (mouse.button === Qt.RightButton) root.clearCell(cellItem.index)
                  }
                }
              }
            }
            Repeater {
              model: 10
              delegate: Rectangle {
                required property int index
                readonly property real thickness: index % 3 === 0 ? 2 : 1
                width: thickness; height: board.height
                x: Math.min(Math.max(0, index * root.cell - thickness / 2), board.width - thickness)
                color: root.shade(index % 3 === 0 ? 0.55 : 0.16)
              }
            }
            Repeater {
              model: 10
              delegate: Rectangle {
                required property int index
                readonly property real thickness: index % 3 === 0 ? 2 : 1
                height: thickness; width: board.width
                y: Math.min(Math.max(0, index * root.cell - thickness / 2), board.height - thickness)
                color: root.shade(index % 3 === 0 ? 0.55 : 0.16)
              }
            }

            // Confetti — pure arithmetic on celebrateProgress, one animation
            // drives all ~324 pieces rather than each piece animating itself.
            Item {
              anchors.fill: parent
              visible: root.celebrating
              Repeater {
                model: root.confetti
                delegate: Rectangle {
                  required property var modelData
                  readonly property real t: Math.max(0, Math.min(1, (root.celebrateProgress - modelData.delay) / root.pieceLife))
                  visible: t > 0 && t < 1
                  width: modelData.size; height: modelData.size
                  radius: modelData.size > 4 ? 1 : 0
                  color: root.shade(modelData.tone)
                  opacity: 1 - t * t
                  rotation: modelData.spin * t
                  x: modelData.x0 + modelData.vx * t - width / 2
                  y: modelData.y0 + modelData.vy * t + root.cell * 3.2 * t * t - height / 2
                }
              }
            }
            Column {
              anchors.centerIn: parent
              visible: opacity > 0
              opacity: root.celebrateDone ? 1 : 0
              spacing: 4
              Behavior on opacity { NumberAnimation { duration: 260 } }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Congratulations"
                color: Services.Theme.foreground
                font.family: Services.Theme.fontFamily
                font.pixelSize: Services.Theme.fontSizeNormal + 2
                font.bold: true
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.difficulty + " solved in " + Model.formatTime(root.elapsedMs)
                color: Services.Theme.foreground
                opacity: 0.7
                font.family: Services.Theme.fontFamily
                font.pixelSize: Services.Theme.fontSizeSmall
              }
            }
            MouseArea {
              anchors.fill: parent
              visible: root.celebrating
              enabled: root.celebrating
              onClicked: root.endCelebration()
            }
          }
        }

        // ---------- stats tab ----------
        Column {
          visible: root.started && root.view === "stats" && root.pendingAction === ""
          width: parent.width
          spacing: 10

          Row {
            width: parent.width
            readonly property real cw: (width - 20) / 3
            Column { width: parent.cw; spacing: 2
              Text { text: String(root.stats.solved); color: Services.Theme.foreground; font.bold: true; font.pixelSize: Services.Theme.fontSizeNormal + 4; font.family: Services.Theme.fontFamily }
              Text { text: "SOLVED"; color: Services.Theme.foreground; opacity: 0.6; font.pixelSize: Services.Theme.fontSizeSmall - 3; font.family: Services.Theme.fontFamily }
            }
            Column { width: parent.cw; spacing: 2
              Text { text: root.stats.started > 0 ? Model.winRate(root.stats) + "%" : "\u2014"; color: Services.Theme.foreground; font.bold: true; font.pixelSize: Services.Theme.fontSizeNormal + 4; font.family: Services.Theme.fontFamily }
              Text { text: "WIN RATE"; color: Services.Theme.foreground; opacity: 0.6; font.pixelSize: Services.Theme.fontSizeSmall - 3; font.family: Services.Theme.fontFamily }
            }
            Column { width: parent.cw; spacing: 2
              Text { text: String(root.stats.streak); color: Services.Theme.foreground; font.bold: true; font.pixelSize: Services.Theme.fontSizeNormal + 4; font.family: Services.Theme.fontFamily }
              Text { text: "STREAK"; color: Services.Theme.foreground; opacity: 0.6; font.pixelSize: Services.Theme.fontSizeSmall - 3; font.family: Services.Theme.fontFamily }
            }
          }
          Rectangle { width: parent.width; height: 1; color: Services.Theme.pillBorder }

          Text { text: "BY DIFFICULTY"; color: Services.Theme.foreground; opacity: 0.6; font.pixelSize: Services.Theme.fontSizeSmall - 3; font.family: Services.Theme.fontFamily }
          Repeater {
            model: Model.statsRows(root.stats)
            delegate: Row {
              required property var modelData
              width: parent.width
              Text { width: parent.width * 0.32; text: modelData.level; color: Services.Theme.foreground; font.pixelSize: Services.Theme.fontSizeSmall - 1; font.family: Services.Theme.fontFamily }
              Text { width: parent.width * 0.22; text: modelData.solved; color: Services.Theme.foreground; opacity: 0.75; font.pixelSize: Services.Theme.fontSizeSmall - 1; font.family: Services.Theme.fontFamily }
              Text { width: parent.width * 0.23; text: modelData.best; color: Services.Theme.foreground; opacity: 0.75; font.pixelSize: Services.Theme.fontSizeSmall - 1; font.family: Services.Theme.fontFamily }
              Text { width: parent.width * 0.23; text: modelData.average; color: Services.Theme.foreground; opacity: 0.75; font.pixelSize: Services.Theme.fontSizeSmall - 1; font.family: Services.Theme.fontFamily }
            }
          }
          Rectangle { width: parent.width; height: 1; color: Services.Theme.pillBorder }

          Column {
            width: parent.width
            spacing: 3

            component TotalPair: Row {
              property string label: ""
              property string value: ""
              width: parent.width
              Text {
                text: parent.label
                color: Services.Theme.foreground
                opacity: 0.7
                font.pixelSize: Services.Theme.fontSizeSmall - 1
                font.family: Services.Theme.fontFamily
                width: parent.width - 40
              }
              Text {
                text: parent.value
                color: Services.Theme.foreground
                font.pixelSize: Services.Theme.fontSizeSmall - 1
                font.family: Services.Theme.fontFamily
              }
            }

            TotalPair { label: "Games played"; value: String(root.stats.started) }
            TotalPair { label: "Solved without hints"; value: String(root.stats.cleanSolved) }
            TotalPair { label: "Best streak"; value: String(root.stats.bestStreak) }
            TotalPair { label: "Hints used"; value: String(root.stats.hints) }
            TotalPair { label: "Time on solved games"; value: Model.formatTotalTime(root.stats.timeMs) }
          }

          Text {
            visible: root.stats.started === 0
            width: parent.width
            text: "No games finished yet. Solve a board and it lands here."
            color: Services.Theme.foreground
            opacity: 0.5
            font.pixelSize: Services.Theme.fontSizeSmall - 1
            font.family: Services.Theme.fontFamily
            wrapMode: Text.WordWrap
          }

          Rectangle {
            visible: root.pendingAction === "" && root.stats.started > 0
            width: parent.width
            height: 24
            radius: 7
            color: resetMa.containsMouse ? Services.Theme.hoverBg : Services.Theme.pillColor
            border.width: 1
            border.color: Services.Theme.pillBorder
            Text { anchors.centerIn: parent; text: "Reset statistics"; color: Services.Theme.foreground; opacity: 0.8; font.pixelSize: Services.Theme.fontSizeSmall - 2; font.family: Services.Theme.fontFamily }
            MouseArea { id: resetMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.requestResetStats() }
          }
        }

        // ---------- confirm prompt (replaces the action row) ----------
        Column {
          visible: root.pendingAction !== ""
          width: parent.width
          spacing: 6
          Text {
            width: parent.width
            text: root.confirmPrompt()
            color: Services.Theme.foreground
            font.bold: true
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
            wrapMode: Text.WordWrap
          }
          Text {
            width: parent.width
            text: root.confirmDetail()
            color: Services.Theme.foreground
            opacity: 0.65
            font.pixelSize: Services.Theme.fontSizeSmall - 2
            font.family: Services.Theme.fontFamily
            wrapMode: Text.WordWrap
          }
          Row {
            width: parent.width
            spacing: 6
            readonly property real cw: (width - spacing) / 2
            Rectangle {
              width: parent.cw; height: 26; radius: 8
              color: keepMa.containsMouse ? Services.Theme.hoverBg : Services.Theme.pillColor
              border.width: 1; border.color: Services.Theme.pillBorder
              Text { anchors.centerIn: parent; text: root.pendingAction === "resetStats" ? "Keep them" : "Keep playing"; color: Services.Theme.foreground; font.pixelSize: Services.Theme.fontSizeSmall - 1; font.family: Services.Theme.fontFamily }
              MouseArea { id: keepMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.cancelPending() }
            }
            Rectangle {
              width: parent.cw; height: 26; radius: 8
              color: Services.Theme.errorColor
              Text { anchors.centerIn: parent; text: root.confirmVerb(); color: Services.Theme.background; font.pixelSize: Services.Theme.fontSizeSmall - 1; font.family: Services.Theme.fontFamily }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.confirmPending() }
            }
          }
        }

        // ---------- action buttons ----------
        Flow {
          visible: root.started && root.view === "board" && root.pendingAction === ""
          width: parent.width
          spacing: 6

          component ActionBtn: Rectangle {
            property string label: ""
            property bool enabledHere: true
            signal clicked()
            width: label.length > 5 ? 62 : 44
            height: 24
            radius: 7
            color: btnMa.containsMouse && enabledHere ? Services.Theme.hoverBg : Services.Theme.pillColor
            opacity: enabledHere ? 1 : 0.4
            border.width: 1
            border.color: Services.Theme.pillBorder
            Text { anchors.centerIn: parent; text: parent.label; color: Services.Theme.foreground; font.pixelSize: Services.Theme.fontSizeSmall - 2; font.family: Services.Theme.fontFamily }
            MouseArea {
              id: btnMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              enabled: parent.enabledHere
              onClicked: parent.clicked()
            }
          }

          ActionBtn { label: "Undo"; enabledHere: root.canUndo; onClicked: root.undo() }
          ActionBtn { label: "Redo"; enabledHere: root.canRedo; onClicked: root.redo() }
          ActionBtn { label: "Hint"; enabledHere: root.started && !root.solved && !root.paused; onClicked: root.hint() }
          ActionBtn { label: root.notesMode ? "Notes\u2713" : "Notes"; enabledHere: root.canTakeNotes; onClicked: root.toggleNotesMode() }
          ActionBtn { label: root.paused ? "Resume" : "Pause"; enabledHere: root.started && !root.solved; onClicked: root.togglePause() }
          ActionBtn { label: "Clear"; enabledHere: root.canClear; onClicked: root.restart() }
          ActionBtn { label: "New"; enabledHere: true; onClicked: root.requestNewGame(root.selectedDifficulty) }
          ActionBtn { label: root.solved ? "Done" : "Abandon"; enabledHere: root.canAbandon || root.solved
            onClicked: root.solved ? root.finishBoard() : root.requestAbandon() }
        }
      }
    }
  }
}
