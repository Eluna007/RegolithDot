.pragma library

// Pure sudoku logic: no QML, no I/O, no side effects on anything the caller
// did not hand in. Everything here is a plain function over a flat 81-cell
// array of 0..9, where 0 means empty. Keeping it a `.pragma library` means
// every importer shares one parsed copy rather than one per instance.

// ---------------------------------------------------------------- geometry

var ROW = [];
var COL = [];
var BOX = [];
var PEERS = [];

(function buildGeometry() {
  var i, b;
  for (i = 0; i < 81; i++) {
    ROW[i] = (i / 9) | 0;
    COL[i] = i % 9;
    BOX[i] = (((i / 9) | 0) / 3 | 0) * 3 + ((i % 9) / 3 | 0);
  }
  for (i = 0; i < 81; i++) {
    var list = [];
    for (b = 0; b < 81; b++) {
      if (b === i) continue;
      if (ROW[b] === ROW[i] || COL[b] === COL[i] || BOX[b] === BOX[i]) list.push(b);
    }
    PEERS[i] = list;
  }
})();

function rowOf(i) { return ROW[i]; }
function colOf(i) { return COL[i]; }
function boxOf(i) { return BOX[i]; }
function peersOf(i) { return PEERS[i]; }

// ------------------------------------------------------------------ solver
//
// Bitmask + minimum-remaining-values backtracking. `_count` stops as soon as
// it has found `cap` solutions, so the uniqueness test the generator leans on
// ("is there exactly one?") costs a cap of 2 rather than a full enumeration.

function _popcount(mask) {
  var n = 0;
  while (mask) { mask &= mask - 1; n++; }
  return n;
}

function _masksFor(grid) {
  var rm = [0, 0, 0, 0, 0, 0, 0, 0, 0];
  var cm = [0, 0, 0, 0, 0, 0, 0, 0, 0];
  var bm = [0, 0, 0, 0, 0, 0, 0, 0, 0];
  for (var i = 0; i < 81; i++) {
    var v = grid[i];
    if (!v) continue;
    var bit = 1 << (v - 1);
    // A grid that already contradicts itself has no solutions at all; report
    // that to the caller rather than silently double-counting a digit.
    if ((rm[ROW[i]] & bit) || (cm[COL[i]] & bit) || (bm[BOX[i]] & bit)) return null;
    rm[ROW[i]] |= bit; cm[COL[i]] |= bit; bm[BOX[i]] |= bit;
  }
  return { rm: rm, cm: cm, bm: bm };
}

// `budget` bounds the search so a pathological grid cannot freeze the shell
// process every widget shares. Running out returns `cap`, i.e. the
// pessimistic "more than one" answer — the generator then keeps the clue it
// was about to remove, so exhaustion costs an easier puzzle, never a broken one.
function _count(g, rm, cm, bm, cap, budget) {
  if (--budget.n < 0) return cap;

  var best = -1, bestMask = 0, bestCount = 10;
  for (var i = 0; i < 81; i++) {
    if (g[i] !== 0) continue;
    var free = ~(rm[ROW[i]] | cm[COL[i]] | bm[BOX[i]]) & 0x1FF;
    var c = _popcount(free);
    if (c === 0) return 0;
    if (c < bestCount) {
      bestCount = c; best = i; bestMask = free;
      if (c === 1) break;
    }
  }
  if (best === -1) return 1;

  var total = 0;
  for (var d = 0; d < 9; d++) {
    var bit = 1 << d;
    if (!(bestMask & bit)) continue;
    g[best] = d + 1;
    rm[ROW[best]] |= bit; cm[COL[best]] |= bit; bm[BOX[best]] |= bit;
    total += _count(g, rm, cm, bm, cap - total, budget);
    g[best] = 0;
    rm[ROW[best]] &= ~bit; cm[COL[best]] &= ~bit; bm[BOX[best]] &= ~bit;
    if (total >= cap) return total;
  }
  return total;
}

// Number of solutions, counted no further than `cap` (default 2).
function countSolutions(grid, cap, budget) {
  var m = _masksFor(grid);
  if (!m) return 0;
  return _count(grid.slice(), m.rm, m.cm, m.bm, cap === undefined ? 2 : cap,
                { n: budget === undefined ? 400000 : budget });
}

function hasUniqueSolution(grid) {
  return countSolutions(grid, 2) === 1;
}

function _firstSolution(g, rm, cm, bm, budget) {
  if (--budget.n < 0) return null;

  var best = -1, bestMask = 0, bestCount = 10;
  for (var i = 0; i < 81; i++) {
    if (g[i] !== 0) continue;
    var free = ~(rm[ROW[i]] | cm[COL[i]] | bm[BOX[i]]) & 0x1FF;
    var c = _popcount(free);
    if (c === 0) return null;
    if (c < bestCount) {
      bestCount = c; best = i; bestMask = free;
      if (c === 1) break;
    }
  }
  if (best === -1) return g.slice();

  for (var d = 0; d < 9; d++) {
    var bit = 1 << d;
    if (!(bestMask & bit)) continue;
    g[best] = d + 1;
    rm[ROW[best]] |= bit; cm[COL[best]] |= bit; bm[BOX[best]] |= bit;
    var found = _firstSolution(g, rm, cm, bm, budget);
    g[best] = 0;
    rm[ROW[best]] &= ~bit; cm[COL[best]] &= ~bit; bm[BOX[best]] &= ~bit;
    if (found) return found;
  }
  return null;
}

// Solved grid, or null when the puzzle contradicts itself / the budget runs out.
function solve(grid) {
  var m = _masksFor(grid);
  if (!m) return null;
  return _firstSolution(grid.slice(), m.rm, m.cm, m.bm, { n: 400000 });
}

// -------------------------------------------------------------- generation

function _shuffle(list, rng) {
  for (var i = list.length - 1; i > 0; i--) {
    var j = (rng() * (i + 1)) | 0;
    var t = list[i]; list[i] = list[j]; list[j] = t;
  }
  return list;
}

// A solved grid, built by relabelling and permuting the canonical pattern
// rather than by searching. Those transformations are exactly the ones that
// preserve sudoku validity, so the result is always legal and always instant —
// which matters because this runs inside the shell's UI thread.
function generateSolution(rng) {
  var base = new Array(81);
  var r, c;
  for (r = 0; r < 9; r++)
    for (c = 0; c < 9; c++)
      base[r * 9 + c] = (3 * (r % 3) + ((r / 3) | 0) + c) % 9 + 1;

  var digits = _shuffle([1, 2, 3, 4, 5, 6, 7, 8, 9], rng);

  var rows = [], cols = [], band, i;
  var bands = _shuffle([0, 1, 2], rng);
  for (i = 0; i < 3; i++) {
    band = _shuffle([0, 1, 2], rng);
    for (var j = 0; j < 3; j++) rows.push(bands[i] * 3 + band[j]);
  }
  var stacks = _shuffle([0, 1, 2], rng);
  for (i = 0; i < 3; i++) {
    band = _shuffle([0, 1, 2], rng);
    for (var k = 0; k < 3; k++) cols.push(stacks[i] * 3 + band[k]);
  }

  var transpose = rng() < 0.5;
  var out = new Array(81);
  for (r = 0; r < 9; r++) {
    for (c = 0; c < 9; c++) {
      var v = digits[base[rows[r] * 9 + cols[c]] - 1];
      if (transpose) out[c * 9 + r] = v; else out[r * 9 + c] = v;
    }
  }
  return out;
}

var DIFFICULTIES = ["Easy", "Medium", "Hard", "Expert"];

// Clue counts are only a starting point for carving. The original version
// stopped here and named the result after its clue count, and noted the flaw
// in doing so: clue count correlates with difficulty but does not determine
// it. A 26-clue grid solvable by naked singles alone is an easy puzzle with a
// sparse board, and calling it "Expert" is simply wrong.
//
// So carving picks the target, and `rate` below decides what the puzzle
// actually is, by solving it the way a person would and recording the hardest
// technique that was needed.
function givensFor(difficulty) {
  switch (difficulty) {
    case "Easy":   return 45;
    case "Hard":   return 28;
    case "Expert": return 26;
    default:       return 36;
  }
}

// ------------------------------------------------------- difficulty rating
//
// A logical solver. It never guesses: it applies human techniques in
// increasing order of difficulty, and the hardest one it had to reach is the
// puzzle's rating. A puzzle it cannot finish needs more than these techniques
// (or trial and error), which is what "Expert" means here.

var UNITS = [];
(function buildUnits() {
  var u, i;
  for (u = 0; u < 9; u++) {
    var row = [], col = [], box = [];
    for (i = 0; i < 9; i++) {
      row.push(u * 9 + i);
      col.push(i * 9 + u);
      box.push(((u / 3) | 0) * 27 + (u % 3) * 3 + ((i / 3) | 0) * 9 + (i % 3));
    }
    UNITS.push(row); UNITS.push(col); UNITS.push(box);
  }
})();

// Candidate masks for every empty cell; null if some empty cell has none,
// which means the grid is already broken.
function _candidates(grid) {
  var cand = new Array(81);
  for (var i = 0; i < 81; i++) {
    if (grid[i]) { cand[i] = 0; continue; }
    cand[i] = candidatesFor(grid, i);
    if (cand[i] === 0) return null;
  }
  return cand;
}

function _place(grid, cand, i, digit) {
  grid[i] = digit;
  cand[i] = 0;
  var bit = 1 << (digit - 1);
  var p = PEERS[i];
  for (var n = 0; n < p.length; n++) {
    if (!grid[p[n]]) {
      cand[p[n]] &= ~bit;
      if (cand[p[n]] === 0) return false;
    }
  }
  return true;
}

function _onlyDigit(mask) {
  for (var d = 0; d < 9; d++) if (mask === (1 << d)) return d + 1;
  return 0;
}

// A cell with exactly one remaining candidate.
function _nakedSingle(grid, cand) {
  for (var i = 0; i < 81; i++) {
    if (grid[i]) continue;
    var d = _onlyDigit(cand[i]);
    if (d) return { index: i, digit: d };
  }
  return null;
}

// A digit with exactly one possible home in some row, column or box.
function _hiddenSingle(grid, cand) {
  for (var u = 0; u < UNITS.length; u++) {
    var unit = UNITS[u];
    for (var d = 0; d < 9; d++) {
      var bit = 1 << d, seen = -1, count = 0;
      for (var n = 0; n < 9; n++) {
        var i = unit[n];
        if (grid[i] === d + 1) { count = 0; break; }
        if (!grid[i] && (cand[i] & bit)) { count++; seen = i; if (count > 1) break; }
      }
      if (count === 1) return { index: seen, digit: d + 1 };
    }
  }
  return null;
}

// Locked candidates: a digit confined to one box within a row/column (or to
// one row/column within a box) can be eliminated from the rest of that unit.
// Eliminations only - no placement - so the caller loops again afterwards.
function _lockedCandidates(grid, cand) {
  var changed = false;
  for (var b = 0; b < 9; b++) {
    var box = UNITS[b * 3 + 2];
    for (var d = 0; d < 9; d++) {
      var bit = 1 << d;
      var rows = {}, cols = {}, any = false;
      for (var n = 0; n < 9; n++) {
        var i = box[n];
        if (grid[i] || !(cand[i] & bit)) continue;
        any = true;
        rows[ROW[i]] = true;
        cols[COL[i]] = true;
      }
      if (!any) continue;
      var rk = Object.keys(rows), ck = Object.keys(cols);
      if (rk.length === 1) {
        var r = parseInt(rk[0], 10);
        for (var c = 0; c < 9; c++) {
          var idx = r * 9 + c;
          if (BOX[idx] === b || grid[idx] || !(cand[idx] & bit)) continue;
          cand[idx] &= ~bit; changed = true;
        }
      }
      if (ck.length === 1) {
        var cc = parseInt(ck[0], 10);
        for (var rr = 0; rr < 9; rr++) {
          var jdx = rr * 9 + cc;
          if (BOX[jdx] === b || grid[jdx] || !(cand[jdx] & bit)) continue;
          cand[jdx] &= ~bit; changed = true;
        }
      }
    }
  }
  return changed;
}

// Naked pair: two cells in a unit sharing the same two candidates lock those
// digits out of every other cell in that unit.
function _nakedPair(grid, cand) {
  var changed = false;
  for (var u = 0; u < UNITS.length; u++) {
    var unit = UNITS[u];
    for (var a = 0; a < 9; a++) {
      var ia = unit[a];
      if (grid[ia] || _popcount(cand[ia]) !== 2) continue;
      for (var b = a + 1; b < 9; b++) {
        var ib = unit[b];
        if (grid[ib] || cand[ib] !== cand[ia]) continue;
        for (var n = 0; n < 9; n++) {
          var i = unit[n];
          if (i === ia || i === ib || grid[i]) continue;
          if (cand[i] & cand[ia]) { cand[i] &= ~cand[ia]; changed = true; }
        }
      }
    }
  }
  return changed;
}

var RATING_ORDER = ["Easy", "Medium", "Hard", "Expert"];

// The hardest technique a human needs to finish this puzzle:
//
//   Easy    naked singles alone
//   Medium  hidden singles too
//   Hard    locked candidates / naked pairs
//   Expert  more than the above
//
// Returns "Expert" for a puzzle this solver cannot finish, which is the
// honest answer: it is beyond the techniques being rated for.
function rate(puzzle) {
  var grid = puzzle.slice();
  var cand = _candidates(grid);
  if (!cand) return "Expert";

  var hardest = 0;   // index into RATING_ORDER
  for (;;) {
    if (filledCount(grid) === 81) return RATING_ORDER[hardest];

    var move = _nakedSingle(grid, cand);
    if (move) {
      if (!_place(grid, cand, move.index, move.digit)) return "Expert";
      continue;
    }

    move = _hiddenSingle(grid, cand);
    if (move) {
      if (hardest < 1) hardest = 1;
      if (!_place(grid, cand, move.index, move.digit)) return "Expert";
      continue;
    }

    // Elimination-only techniques: they open the board up rather than
    // filling a cell, so on success go round again and look for a placement.
    if (_lockedCandidates(grid, cand) || _nakedPair(grid, cand)) {
      if (hardest < 2) hardest = 2;
      continue;
    }

    return "Expert";
  }
}

// Carve clues out of a solved grid in 180-degree-symmetric pairs, keeping only
// removals that leave the solution unique. Returns the actual clue count,
// which can land above the target when uniqueness blocks further removal.
function _carve(difficulty, rng) {
  var random = rng || Math.random;
  var solution = generateSolution(random);
  var target = givensFor(difficulty);
  var puzzle = solution.slice();
  var givens = 81;

  var order = [];
  for (var i = 0; i <= 40; i++) order.push(i);
  _shuffle(order, random);

  for (var n = 0; n < order.length && givens > target; n++) {
    var a = order[n];
    var b = 80 - a;
    if (puzzle[a] === 0) continue;

    var keptA = puzzle[a];
    var keptB = puzzle[b];
    puzzle[a] = 0;
    var removed = 1;
    if (b !== a && puzzle[b] !== 0) { puzzle[b] = 0; removed = 2; }

    if (hasUniqueSolution(puzzle)) {
      givens -= removed;
    } else {
      puzzle[a] = keptA;
      if (removed === 2) puzzle[b] = keptB;
    }
  }

  return { puzzle: puzzle, solution: solution, givens: givens, difficulty: difficulty };
}

// Carve until the puzzle actually rates as what was asked for.
//
// Carving to a clue count gives a board of roughly the right shape, but its
// real difficulty varies a lot run to run - sparse boards are often still
// solvable by naked singles alone. So carve repeatedly and rate each result,
// returning the first exact match and otherwise the closest one found.
//
// `attempts` is a hard bound because this runs on the shell's UI thread: a
// puzzle one step off the requested difficulty is a far better outcome than a
// panel that stops responding. `rating` on the result is the measured value, so
// the UI can show what the puzzle is rather than what was requested.
// Generation is incremental because it runs on the shell's UI thread, which
// also draws the panel. Carving once takes a few milliseconds typically but can
// reach ~100ms, and doing all 24 attempts in one call froze everything for a
// third of a second. `createGenerator` / `step` do one attempt per call, so
// the panel can drive it from a Timer and stay responsive.
//
//   var gen = Sudoku.createGenerator("Hard")
//   while (!Sudoku.step(gen)) { /* one attempt per frame */ }
//   gen.result   // { puzzle, solution, givens, difficulty, rating }
//
function createGenerator(difficulty, rng, attempts) {
  var want = normalizeName(difficulty);
  return {
    want: want,
    wantIdx: RATING_ORDER.indexOf(want),
    random: rng || Math.random,
    tries: attempts === undefined ? 24 : attempts,
    attempt: 0,
    best: null,
    bestDist: 99,
    done: false,
    result: null
  };
}

// One carve-and-rate attempt. Returns true when `gen.result` is ready, either
// because the rating matched exactly or because the attempt budget ran out -
// in which case the closest puzzle found is used. A puzzle one step off the
// requested difficulty is a much better outcome than a stalled shell.
function step(gen) {
  if (gen.done) return true;

  var cand = _carve(gen.want, gen.random);
  var rating = rate(cand.puzzle);
  var dist = Math.abs(RATING_ORDER.indexOf(rating) - gen.wantIdx);
  cand.rating = rating;
  cand.difficulty = gen.want;

  if (dist < gen.bestDist) { gen.bestDist = dist; gen.best = cand; }
  gen.attempt++;

  if (dist === 0 || gen.attempt >= gen.tries) {
    gen.done = true;
    gen.result = gen.best;
  }
  return gen.done;
}

// How far along a run is, 0..1, for a progress indicator. An exact match can
// land on the first attempt, so this is a bound rather than a prediction.
function progress(gen) {
  return gen.done ? 1 : Math.min(1, gen.attempt / gen.tries);
}

// Blocking convenience: the whole run in one call. Used by the tests, and
// fine anywhere that is not the UI thread.
function generate(difficulty, rng, attempts) {
  var gen = createGenerator(difficulty, rng, attempts);
  while (!step(gen)) { /* keep carving */ }
  return gen.result;
}

function normalizeName(name) {
  for (var i = 0; i < RATING_ORDER.length; i++) {
    if (RATING_ORDER[i] === name) return name;
  }
  return "Medium";
}

// ------------------------------------------------------------------- state

function emptyGrid() {
  var g = new Array(81);
  for (var i = 0; i < 81; i++) g[i] = 0;
  return g;
}

// Indices holding a digit that repeats somewhere in their row, column, or box.
function conflicts(grid) {
  var bad = new Array(81);
  var i;
  for (i = 0; i < 81; i++) bad[i] = false;
  for (i = 0; i < 81; i++) {
    var v = grid[i];
    if (!v) continue;
    var p = PEERS[i];
    for (var n = 0; n < p.length; n++) {
      if (grid[p[n]] === v) { bad[i] = true; break; }
    }
  }
  return bad;
}

function isComplete(grid) {
  for (var i = 0; i < 81; i++) if (!grid[i]) return false;
  var bad = conflicts(grid);
  for (i = 0; i < 81; i++) if (bad[i]) return false;
  return true;
}

function filledCount(grid) {
  var n = 0;
  for (var i = 0; i < 81; i++) if (grid[i]) n++;
  return n;
}

// Digits that already appear nine times, so the pad can grey them out.
function digitCounts(grid) {
  var counts = [0, 0, 0, 0, 0, 0, 0, 0, 0];
  for (var i = 0; i < 81; i++) if (grid[i]) counts[grid[i] - 1]++;
  return counts;
}

// ------------------------------------------------------------- pencil marks

function hasNote(mask, digit) { return (mask & (1 << (digit - 1))) !== 0; }
function toggleNote(mask, digit) { return mask ^ (1 << (digit - 1)); }

function emptyNotes() {
  var n = new Array(81);
  for (var i = 0; i < 81; i++) n[i] = 0;
  return n;
}

// Placing a digit invalidates that pencil mark everywhere it can still see.
// Returns a fresh array; callers reassign so QML bindings notice the change.
function clearPeerNotes(notes, index, digit) {
  var next = notes.slice();
  var bit = 1 << (digit - 1);
  var p = PEERS[index];
  for (var n = 0; n < p.length; n++) next[p[n]] &= ~bit;
  next[index] = 0;
  return next;
}

// A cell's remaining legal digits, for the auto-fill-notes convenience.
function candidatesFor(grid, index) {
  if (grid[index]) return 0;
  var used = 0;
  var p = PEERS[index];
  for (var n = 0; n < p.length; n++) if (grid[p[n]]) used |= 1 << (grid[p[n]] - 1);
  return ~used & 0x1FF;
}

function fillAllNotes(grid) {
  var notes = new Array(81);
  for (var i = 0; i < 81; i++) notes[i] = candidatesFor(grid, i);
  return notes;
}
