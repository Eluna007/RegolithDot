.pragma library

var GLYPH_BOARD  = "\uf04d3";
var GLYPH_SOLVED = "\uf012c";
var GLYPH_PAUSED = "\uf03e4";
var GLYPH_NOTES  = "\uf03eb";
var GLYPH_HINT   = "\uf0335";
var GLYPH_UNDO   = "\uf054c";
var GLYPH_NEW    = "\uf0450";

function glyph(state) {
  if (state === "solved") return GLYPH_SOLVED;
  if (state === "paused") return GLYPH_PAUSED;
  return GLYPH_BOARD;
}

function formatTime(ms) {
  var total = Math.max(0, Math.floor((Number(ms) || 0) / 1000));
  var s = total % 60;
  var m = Math.floor(total / 60) % 60;
  var h = Math.floor(total / 3600);
  var ss = s < 10 ? "0" + s : String(s);
  if (h > 0) {
    var mm = m < 10 ? "0" + m : String(m);
    return h + ":" + mm + ":" + ss;
  }
  return m + ":" + ss;
}

function tooltip(opts) {
  if (!opts.started) return "Apolloku — click to start";
  if (opts.state === "solved")
    return "Solved " + opts.difficulty.toLowerCase() + " in " + formatTime(opts.elapsedMs)
         + (opts.hintsUsed > 0 ? " · " + opts.hintsUsed + " hint" + (opts.hintsUsed === 1 ? "" : "s") : "");
  if (opts.state === "paused")
    return "Apolloku paused · " + formatTime(opts.elapsedMs);
  return opts.difficulty + " · " + opts.filled + "/81 · " + formatTime(opts.elapsedMs);
}

function statusText(opts) {
  if (opts.state === "idle") return "CHOOSE A DIFFICULTY";
  if (opts.state === "solved") {
    return opts.hintsUsed > 0
      ? "SOLVED WITH " + opts.hintsUsed + " HINT" + (opts.hintsUsed === 1 ? "" : "S")
      : "SOLVED";
  }
  if (opts.state === "paused") return "PAUSED";
  if (opts.notesMode) return "PENCIL MARKS";
  var left = 81 - opts.filled;
  if (left === 0) return "CHECK YOUR WORK";
  return left + " TO GO";
}

function isDifficulty(name) {
  return name === "Easy" || name === "Medium" || name === "Hard" || name === "Expert";
}

function normalizeDifficulty(name, fallback) {
  return isDifficulty(name) ? name : (isDifficulty(fallback) ? fallback : "Medium");
}

var SAVE_VERSION = 1;

function _isGrid(value) {
  if (!value || value.length !== 81) return false;
  for (var i = 0; i < 81; i++) {
    var v = value[i];
    if (typeof v !== "number" || v < 0 || v > 9 || (v | 0) !== v) return false;
  }
  return true;
}

function _isNotes(value) {
  if (!value || value.length !== 81) return false;
  for (var i = 0; i < 81; i++) {
    var v = value[i];
    if (typeof v !== "number" || v < 0 || v > 511 || (v | 0) !== v) return false;
  }
  return true;
}

function serialize(state) {
  return JSON.stringify({
    version: SAVE_VERSION,
    difficulty: state.difficulty,
    puzzle: state.puzzle,
    solution: state.solution,
    cells: state.cells,
    notes: state.notes,
    elapsedMs: Math.max(0, Math.round(state.elapsedMs)),
    hintsUsed: Math.max(0, state.hintsUsed | 0),
    selected: Math.min(80, Math.max(0, state.selected | 0)),
    notesMode: state.notesMode === true,
    solved: state.solved === true
  }, null, 2) + "\n";
}

function parse(text) {
  if (!text) return null;
  var raw;
  try {
    raw = JSON.parse(text);
  } catch (e) {
    return null;
  }
  if (!raw || raw.version !== SAVE_VERSION) return null;
  if (!_isGrid(raw.puzzle) || !_isGrid(raw.solution) || !_isGrid(raw.cells)) return null;
  if (!_isNotes(raw.notes)) return null;

  for (var i = 0; i < 81; i++) {
    if (raw.puzzle[i] !== 0 && raw.puzzle[i] !== raw.solution[i]) return null;
    if (raw.puzzle[i] !== 0 && raw.cells[i] !== raw.puzzle[i]) return null;
  }

  return {
    difficulty: normalizeDifficulty(raw.difficulty, "Medium"),
    puzzle: raw.puzzle,
    solution: raw.solution,
    cells: raw.cells,
    notes: raw.notes,
    elapsedMs: Math.max(0, Number(raw.elapsedMs) || 0),
    hintsUsed: Math.max(0, raw.hintsUsed | 0),
    selected: Math.min(80, Math.max(0, raw.selected | 0)),
    notesMode: raw.notesMode === true,
    solved: raw.solved === true
  };
}

var STATS_VERSION = 1;
var LEVELS = ["Easy", "Medium", "Hard", "Expert"];

function _int(value) {
  var n = Number(value);
  return isFinite(n) && n > 0 ? Math.floor(n) : 0;
}

function _emptyLevel() {
  return { started: 0, solved: 0, cleanSolved: 0, bestMs: 0, totalMs: 0 };
}

function emptyStats() {
  var byDifficulty = {};
  for (var i = 0; i < LEVELS.length; i++) byDifficulty[LEVELS[i]] = _emptyLevel();
  return {
    version: STATS_VERSION,
    started: 0,
    solved: 0,
    cleanSolved: 0,
    hints: 0,
    timeMs: 0,
    streak: 0,
    bestStreak: 0,
    byDifficulty: byDifficulty
  };
}

function _cloneStats(stats) {
  var source = stats || {};
  var out = emptyStats();
  out.started = _int(source.started);
  out.solved = _int(source.solved);
  out.cleanSolved = _int(source.cleanSolved);
  out.hints = _int(source.hints);
  out.timeMs = _int(source.timeMs);
  out.streak = _int(source.streak);
  out.bestStreak = _int(source.bestStreak);
  var by = source.byDifficulty || {};
  for (var i = 0; i < LEVELS.length; i++) {
    var name = LEVELS[i];
    var level = by[name] || {};
    out.byDifficulty[name] = {
      started: _int(level.started),
      solved: _int(level.solved),
      cleanSolved: _int(level.cleanSolved),
      bestMs: _int(level.bestMs),
      totalMs: _int(level.totalMs)
    };
  }
  return out;
}

function serializeStats(stats) {
  return JSON.stringify(_cloneStats(stats), null, 2) + "\n";
}

function parseStats(text) {
  if (!text) return emptyStats();
  var raw;
  try {
    raw = JSON.parse(text);
  } catch (e) {
    return emptyStats();
  }
  if (!raw || raw.version !== STATS_VERSION) return emptyStats();
  return _cloneStats(raw);
}

function recordStart(stats, difficulty, previousUnfinished) {
  var next = _cloneStats(stats);
  var level = normalizeDifficulty(difficulty, "Medium");
  next.started++;
  next.byDifficulty[level].started++;
  if (previousUnfinished) next.streak = 0;
  return next;
}

function recordSolve(stats, difficulty, elapsedMs, hintsUsed) {
  var next = _cloneStats(stats);
  var level = normalizeDifficulty(difficulty, "Medium");
  var ms = _int(elapsedMs);
  var hints = _int(hintsUsed);
  var bucket = next.byDifficulty[level];

  next.solved++;
  next.timeMs += ms;
  next.hints += hints;
  bucket.solved++;
  bucket.totalMs += ms;
  if (hints === 0) { next.cleanSolved++; bucket.cleanSolved++; }
  if (ms > 0 && (bucket.bestMs === 0 || ms < bucket.bestMs)) bucket.bestMs = ms;

  next.streak++;
  if (next.streak > next.bestStreak) next.bestStreak = next.streak;

  if (next.solved > next.started) next.started = next.solved;
  if (bucket.solved > bucket.started) bucket.started = bucket.solved;
  return next;
}

function recordAbandon(stats) {
  var next = _cloneStats(stats);
  next.streak = 0;
  return next;
}

function winRate(stats) {
  var s = _cloneStats(stats);
  if (s.started === 0) return 0;
  return Math.round((s.solved / s.started) * 100);
}

function averageMs(level) {
  if (!level || level.solved === 0) return 0;
  return Math.round(level.totalMs / level.solved);
}

function formatOrDash(ms) {
  return _int(ms) === 0 ? "—" : formatTime(ms);
}

function statsRows(stats) {
  var s = _cloneStats(stats);
  var rows = [];
  for (var i = 0; i < LEVELS.length; i++) {
    var name = LEVELS[i];
    var level = s.byDifficulty[name];
    rows.push({
      level: name,
      solved: String(level.solved),
      best: formatOrDash(level.bestMs),
      average: formatOrDash(averageMs(level))
    });
  }
  return rows;
}

function formatTotalTime(ms) {
  var total = Math.floor(_int(ms) / 1000);
  var hours = Math.floor(total / 3600);
  var minutes = Math.floor(total / 60) % 60;
  if (hours > 0) return hours + "h " + minutes + "m";
  if (minutes > 0) return minutes + "m";
  return total + "s";
}
