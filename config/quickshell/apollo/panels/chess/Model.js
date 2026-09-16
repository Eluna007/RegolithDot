.pragma library

// Presentation and persistence for the chess widget. No rules, no search -
// those are Chess.js and Engine.js. Everything here is a pure function over
// plain data, so scripts/test-chess-model.js can exercise it under node.

// ------------------------------------------------------------- formatting

function formatClock(ms) {
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

// Moves as numbered pairs: 1. e4 e5 / 2. Nf3 Nc6. `sans` is the flat list.
function movePairs(sans) {
  var rows = [];
  for (var i = 0; i < sans.length; i += 2) {
    rows.push({ number: (i / 2) + 1, white: sans[i] || "", black: sans[i + 1] || "" });
  }
  return rows;
}

var OUTCOME_TEXT = {
  stalemate: "Stalemate",
  fifty: "Draw by the fifty-move rule",
  repetition: "Draw by threefold repetition",
  insufficient: "Draw by insufficient material"
};

// `outcome` comes from Chess.outcome; `loserIsWhite` says who is to move, and
// so who has been mated when the outcome is checkmate.
function outcomeText(outcome, loserIsWhite) {
  if (!outcome) return "";
  if (outcome === "checkmate") return (loserIsWhite ? "Black" : "White") + " wins by checkmate";
  return OUTCOME_TEXT[outcome] || "";
}

function isDraw(outcome) {
  return outcome === "stalemate" || outcome === "fifty" ||
         outcome === "repetition" || outcome === "insufficient";
}

var LEVEL_NAMES = ["", "Beginner", "Casual", "Club", "Strong", "Best"];
function levelName(n) { return LEVEL_NAMES[Math.max(1, Math.min(5, n | 0))]; }

// ------------------------------------------------------------ persistence

var SAVE_VERSION = 1;

function serialize(state) {
  return JSON.stringify({
    version: SAVE_VERSION,
    fen: String(state.fen || ""),
    startFen: String(state.startFen || ""),
    sans: (state.sans || []).map(String),
    moves: (state.moves || []).map(function (m) {
      return { from: m.from | 0, to: m.to | 0, promotion: m.promotion | 0 };
    }),
    keys: (state.keys || []).map(String),
    mode: state.mode === "human" ? "human" : "engine",
    engineColor: state.engineColor === 0 ? 0 : 1,
    level: Math.max(1, Math.min(5, state.level | 0)) || 3,
    flipped: state.flipped === true,
    elapsedMs: Math.max(0, Math.round(Number(state.elapsedMs) || 0))
  }, null, 2) + "\n";
}

function parse(text) {
  if (!text) return null;
  var raw;
  try { raw = JSON.parse(text); } catch (e) { return null; }
  if (!raw || raw.version !== SAVE_VERSION) return null;
  if (typeof raw.fen !== "string" || raw.fen === "") return null;
  if (!Array.isArray(raw.sans) || !Array.isArray(raw.moves)) return null;
  // A save whose notation and move list disagree is corrupt, and loading it
  // would show a move list that does not describe the board.
  if (raw.sans.length !== raw.moves.length) return null;
  for (var i = 0; i < raw.moves.length; i++) {
    var m = raw.moves[i];
    if (!m || typeof m.from !== "number" || typeof m.to !== "number") return null;
    if (m.from < 0 || m.from > 127 || m.to < 0 || m.to > 127) return null;
  }
  return {
    fen: raw.fen,
    startFen: typeof raw.startFen === "string" ? raw.startFen : "",
    sans: raw.sans.map(String),
    moves: raw.moves.map(function (m) {
      return { from: m.from | 0, to: m.to | 0, promotion: m.promotion | 0 };
    }),
    keys: Array.isArray(raw.keys) ? raw.keys.map(String) : [],
    mode: raw.mode === "human" ? "human" : "engine",
    engineColor: raw.engineColor === 0 ? 0 : 1,
    level: Math.max(1, Math.min(5, raw.level | 0)) || 3,
    flipped: raw.flipped === true,
    elapsedMs: Math.max(0, Number(raw.elapsedMs) || 0)
  };
}

// ------------------------------------------------------------------ stats

var STATS_VERSION = 1;

function emptyStats() {
  var byLevel = {};
  for (var i = 1; i <= 5; i++) byLevel[i] = { played: 0, won: 0, lost: 0, drawn: 0 };
  return { version: STATS_VERSION, played: 0, won: 0, lost: 0, drawn: 0, byLevel: byLevel };
}

function _int(v) {
  var n = Number(v);
  return isFinite(n) && n > 0 ? Math.floor(n) : 0;
}

function _cloneStats(stats) {
  var src = stats || {};
  var out = emptyStats();
  out.played = _int(src.played);
  out.won = _int(src.won);
  out.lost = _int(src.lost);
  out.drawn = _int(src.drawn);
  var by = src.byLevel || {};
  for (var i = 1; i <= 5; i++) {
    var lv = by[i] || by[String(i)] || {};
    out.byLevel[i] = {
      played: _int(lv.played), won: _int(lv.won),
      lost: _int(lv.lost), drawn: _int(lv.drawn)
    };
  }
  return out;
}

function serializeStats(stats) { return JSON.stringify(_cloneStats(stats), null, 2) + "\n"; }

function parseStats(text) {
  if (!text) return emptyStats();
  var raw;
  try { raw = JSON.parse(text); } catch (e) { return emptyStats(); }
  if (!raw || raw.version !== STATS_VERSION) return emptyStats();
  return _cloneStats(raw);
}

// `result` is "won", "lost" or "drawn", from the human's point of view.
function recordResult(stats, level, result) {
  var next = _cloneStats(stats);
  var lv = Math.max(1, Math.min(5, level | 0)) || 3;
  if (result !== "won" && result !== "lost" && result !== "drawn") return next;
  next.played++;
  next[result]++;
  next.byLevel[lv].played++;
  next.byLevel[lv][result]++;
  return next;
}

// ------------------------------------------------------- chess.com parsing
//
// Everything below parses data fetched over the network from an API this
// widget does not control, so it is treated as untrusted: every field is
// checked for type and range, strings are stripped of control characters and
// clamped, and nothing is ever returned as markup. The QML side renders all of
// it with textFormat: Text.PlainText.

function _num(v, lo, hi) {
  var n = Number(v);
  if (!isFinite(n)) return 0;
  n = Math.floor(n);
  if (lo !== undefined && n < lo) return 0;
  if (hi !== undefined && n > hi) return 0;
  return n;
}

function _str(v, max) {
  if (typeof v !== "string") return "";
  var limit = max || 64;
  var s = v.replace(/[\u0000-\u001f\u007f]/g, "").trim();
  return s.length > limit ? s.slice(0, limit) : s;
}

function _record(r) {
  var o = r || {};
  return {
    win: _num(o.win, 0, 1000000),
    loss: _num(o.loss, 0, 1000000),
    draw: _num(o.draw, 0, 1000000)
  };
}

function _timeClass(entry) {
  var e = entry || {};
  var last = e.last || {};
  return { rating: _num(last.rating, 0, 4000), record: _record(e.record) };
}

function emptyChessStats() {
  return {
    ok: false,
    bullet: _timeClass(null), blitz: _timeClass(null),
    rapid: _timeClass(null), daily: _timeClass(null),
    puzzleRating: 0, puzzleRushBest: 0
  };
}

// api.chess.com/pub/player/<user>/stats
function parseChessStats(text) {
  var raw;
  try { raw = JSON.parse(text); } catch (e) { return emptyChessStats(); }
  if (!raw || typeof raw !== "object") return emptyChessStats();
  var out = emptyChessStats();
  out.bullet = _timeClass(raw.chess_bullet);
  out.blitz = _timeClass(raw.chess_blitz);
  out.rapid = _timeClass(raw.chess_rapid);
  out.daily = _timeClass(raw.chess_daily);
  out.puzzleRating = raw.tactics && raw.tactics.highest
      ? _num(raw.tactics.highest.rating, 0, 4000) : 0;
  out.puzzleRushBest = raw.puzzle_rush && raw.puzzle_rush.best
      ? _num(raw.puzzle_rush.best.score, 0, 1000) : 0;
  out.ok = out.bullet.rating > 0 || out.blitz.rating > 0 ||
           out.rapid.rating > 0 || out.daily.rating > 0;
  return out;
}

// Rows for the ratings table, skipping formats never played.
function ratingRows(stats) {
  var order = [["Bullet", "bullet"], ["Blitz", "blitz"],
               ["Rapid", "rapid"], ["Daily", "daily"]];
  var rows = [];
  for (var i = 0; i < order.length; i++) {
    var e = stats[order[i][1]];
    if (!e || e.rating <= 0) continue;
    var total = e.record.win + e.record.loss + e.record.draw;
    rows.push({
      label: order[i][0],
      rating: e.rating,
      record: e.record.win + "/" + e.record.loss + "/" + e.record.draw,
      winRate: total > 0 ? Math.round((e.record.win / total) * 100) : 0
    });
  }
  return rows;
}

// A chess.com username: letters, digits, underscore and hyphen, 3-25 chars.
// Anything else is refused rather than interpolated into a URL - this string
// comes from a config file and goes into a curl argument.
function validUsername(name) {
  return typeof name === "string" && /^[A-Za-z0-9_-]{3,25}$/.test(name);
}
