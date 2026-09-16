.pragma library
.import "Chess.js" as Chess

// A small chess engine: alpha-beta with quiescence, iterative deepening and
// MVV-LVA move ordering. Club strength at best, and deliberately so - the
// point is an opponent that is self-contained and testable, not a strong one.
//
// Stockfish would play far better, but it is a separate process and a
// dependency the shell would have to find, launch and talk UCI to. This is a
// few hundred lines of ECMAScript that node can test directly.
//
// The search runs in slices. It shares the thread that draws the bar, and a
// depth-4 search is comfortably long enough to drop frames, so `step` does a
// bounded number of nodes per call and the panel drives it from a Timer.

var PIECE_VALUE = [0, 100, 320, 330, 500, 900, 20000];

// Piece-square tables, from White's point of view, a8 first. They are what
// give the engine any positional sense at all: without them it develops
// nothing and shuffles pieces on the back rank.
var PST_PAWN = [
   0,  0,  0,  0,  0,  0,  0,  0,
  50, 50, 50, 50, 50, 50, 50, 50,
  10, 10, 20, 30, 30, 20, 10, 10,
   5,  5, 10, 25, 25, 10,  5,  5,
   0,  0,  0, 20, 20,  0,  0,  0,
   5, -5,-10,  0,  0,-10, -5,  5,
   5, 10, 10,-20,-20, 10, 10,  5,
   0,  0,  0,  0,  0,  0,  0,  0];
var PST_KNIGHT = [
 -50,-40,-30,-30,-30,-30,-40,-50,
 -40,-20,  0,  0,  0,  0,-20,-40,
 -30,  0, 10, 15, 15, 10,  0,-30,
 -30,  5, 15, 20, 20, 15,  5,-30,
 -30,  0, 15, 20, 20, 15,  0,-30,
 -30,  5, 10, 15, 15, 10,  5,-30,
 -40,-20,  0,  5,  5,  0,-20,-40,
 -50,-40,-30,-30,-30,-30,-40,-50];
var PST_BISHOP = [
 -20,-10,-10,-10,-10,-10,-10,-20,
 -10,  0,  0,  0,  0,  0,  0,-10,
 -10,  0,  5, 10, 10,  5,  0,-10,
 -10,  5,  5, 10, 10,  5,  5,-10,
 -10,  0, 10, 10, 10, 10,  0,-10,
 -10, 10, 10, 10, 10, 10, 10,-10,
 -10,  5,  0,  0,  0,  0,  5,-10,
 -20,-10,-10,-10,-10,-10,-10,-20];
var PST_ROOK = [
   0,  0,  0,  0,  0,  0,  0,  0,
   5, 10, 10, 10, 10, 10, 10,  5,
  -5,  0,  0,  0,  0,  0,  0, -5,
  -5,  0,  0,  0,  0,  0,  0, -5,
  -5,  0,  0,  0,  0,  0,  0, -5,
  -5,  0,  0,  0,  0,  0,  0, -5,
  -5,  0,  0,  0,  0,  0,  0, -5,
   0,  0,  0,  5,  5,  0,  0,  0];
var PST_QUEEN = [
 -20,-10,-10, -5, -5,-10,-10,-20,
 -10,  0,  0,  0,  0,  0,  0,-10,
 -10,  0,  5,  5,  5,  5,  0,-10,
  -5,  0,  5,  5,  5,  5,  0, -5,
   0,  0,  5,  5,  5,  5,  0, -5,
 -10,  5,  5,  5,  5,  5,  0,-10,
 -10,  0,  5,  0,  0,  0,  0,-10,
 -20,-10,-10, -5, -5,-10,-10,-20];
var PST_KING_MID = [
 -30,-40,-40,-50,-50,-40,-40,-30,
 -30,-40,-40,-50,-50,-40,-40,-30,
 -30,-40,-40,-50,-50,-40,-40,-30,
 -30,-40,-40,-50,-50,-40,-40,-30,
 -20,-30,-30,-40,-40,-30,-30,-20,
 -10,-20,-20,-20,-20,-20,-20,-10,
  20, 20,  0,  0,  0,  0, 20, 20,
  20, 30, 10,  0,  0, 10, 30, 20];
var PST_KING_END = [
 -50,-40,-30,-20,-20,-30,-40,-50,
 -30,-20,-10,  0,  0,-10,-20,-30,
 -30,-10, 20, 30, 30, 20,-10,-30,
 -30,-10, 30, 40, 40, 30,-10,-30,
 -30,-10, 30, 40, 40, 30,-10,-30,
 -30,-10, 20, 30, 30, 20,-10,-30,
 -30,-30,  0,  0,  0,  0,-30,-30,
 -50,-30,-30,-30,-30,-30,-30,-50];

var PST = [null, PST_PAWN, PST_KNIGHT, PST_BISHOP, PST_ROOK, PST_QUEEN, null];

// 0x88 square -> index into the tables above, flipped for Black.
function pstIndex(sq, color) {
  var file = sq & 15;
  var rank = sq >> 4;
  var r = color === Chess.WHITE ? 7 - rank : rank;
  return r * 8 + file;
}

var MATE = 100000;

// Score from the side-to-move's point of view.
//
// One pass, no allocation. This is called at every node of both the main
// search and quiescence, so its cost sets the engine's speed outright: the
// first version built an array of every piece and rescanned the board for the
// endgame test, and spent ~1.3s on what should be a 15ms slice.
function evaluate(pos) {
  var score = 0;       // from White's point of view
  var material = 0;    // non-king material, for the endgame test
  var whiteKing = -1, blackKing = -1;

  for (var sq = 0; sq < 128; sq++) {
    if (sq & 0x88) { sq += 7; continue; }
    var p = pos.board[sq];
    if (p === Chess.EMPTY) continue;

    var type = p & 7;
    var color = (p >> 3) & 1;

    if (type === Chess.KING) {
      if (color === Chess.WHITE) whiteKing = sq; else blackKing = sq;
      continue;                               // scored below, once we know the phase
    }

    material += PIECE_VALUE[type];
    var v = PIECE_VALUE[type] + PST[type][pstIndex(sq, color)];
    score += color === Chess.WHITE ? v : -v;
  }

  // Below roughly a queen and a rook each, the king belongs in the centre
  // rather than tucked away, so the king table is swapped out.
  var kingTable = material < 1800 ? PST_KING_END : PST_KING_MID;
  if (whiteKing !== -1) score += kingTable[pstIndex(whiteKing, Chess.WHITE)];
  if (blackKing !== -1) score -= kingTable[pstIndex(blackKing, Chess.BLACK)];

  return pos.turn === Chess.WHITE ? score : -score;
}

// Most Valuable Victim / Least Valuable Attacker: try QxP-style blunders last
// and PxQ first. Ordering is most of what makes alpha-beta cut anything.
function scoreMove(m) {
  if (m.flags & Chess.FLAG_CAPTURE) {
    var victim = m.captured ? PIECE_VALUE[m.captured & 7] : PIECE_VALUE[Chess.PAWN];
    var attacker = PIECE_VALUE[m.piece & 7];
    return 10000 + victim * 10 - attacker;
  }
  if (m.flags & Chess.FLAG_PROMO) return 9000 + PIECE_VALUE[m.promotion];
  return 0;
}

function orderMoves(moves) {
  moves.sort(function (a, b) { return scoreMove(b) - scoreMove(a); });
  return moves;
}

// Search only captures until the position is quiet. Without this the engine
// happily "wins" a queen on the last ply of its search and never sees the
// recapture that follows.
function quiesce(state, pos, alpha, beta) {
  if (state.nodes >= state.budget) { state.aborted = true; return alpha; }
  state.nodes++;

  var stand = evaluate(pos);
  if (stand >= beta) return beta;
  if (stand > alpha) alpha = stand;

  var moves = orderMoves(Chess.generateMoves(pos, -1, true));

  var us = pos.turn;
  for (var i = 0; i < moves.length; i++) {
    var undo = Chess.make(pos, moves[i]);
    if (Chess.attacked(pos, pos.kings[us], us ^ 1)) { Chess.unmake(pos, moves[i], undo); continue; }
    var score = -quiesce(state, pos, -beta, -alpha);
    Chess.unmake(pos, moves[i], undo);
    if (state.aborted) return alpha;
    if (score >= beta) return beta;
    if (score > alpha) alpha = score;
  }
  return alpha;
}

function search(state, pos, depth, alpha, beta, ply) {
  if (state.nodes >= state.budget) { state.aborted = true; return alpha; }
  if (depth === 0) return quiesce(state, pos, alpha, beta);
  state.nodes++;

  var us = pos.turn;
  var moves = orderMoves(Chess.generateMoves(pos));
  var legal = 0;
  var best = -MATE * 2;
  var bestMove = null;

  for (var i = 0; i < moves.length; i++) {
    var undo = Chess.make(pos, moves[i]);
    if (Chess.attacked(pos, pos.kings[us], us ^ 1)) { Chess.unmake(pos, moves[i], undo); continue; }
    legal++;
    var score = -search(state, pos, depth - 1, -beta, -alpha, ply + 1);
    Chess.unmake(pos, moves[i], undo);
    if (state.aborted) return alpha;

    if (score > best) { best = score; bestMove = moves[i]; }
    if (score > alpha) alpha = score;
    if (alpha >= beta) break;
  }

  if (legal === 0) {
    // Mate scores count from the root, so a mate in 1 beats a mate in 3.
    return Chess.inCheck(pos) ? -MATE + ply : 0;
  }

  if (ply === 0 && bestMove) state.rootBest = bestMove;
  return best;
}

// ---------------------------------------------------------------- slicing

// `level` 1..5. Lower levels look shallower and are allowed to pick a move
// that is merely close to best, so the engine is beatable without being
// obviously broken.
var LEVELS = [
  null,
  { depth: 1, slack: 120 },
  { depth: 2, slack: 70 },
  { depth: 3, slack: 30 },
  { depth: 4, slack: 0 },
  { depth: 5, slack: 0 }
];

function createSearch(pos, level, rng) {
  var lv = LEVELS[Math.max(1, Math.min(5, level | 0))] || LEVELS[3];
  return {
    pos: Chess.clone(pos),
    maxDepth: lv.depth,
    slack: lv.slack,
    rng: rng || Math.random,
    depth: 1,
    best: null,
    bestScore: 0,
    nodes: 0,
    budget: 0,
    aborted: false,
    rootBest: null,
    done: false,
    // Every legal move, scored once the first iteration completes, so a
    // weaker level can choose among near-best moves.
    rootMoves: Chess.legalMoves(pos)
  };
}

// One iteration of iterative deepening, bounded to `nodeBudget` nodes. If the
// budget runs out mid-iteration the partial result is discarded and whatever
// the last completed depth found is used - that is why this is safe to
// interrupt at all.
function step(gen, nodeBudget) {
  if (gen.done) return true;

  if (gen.rootMoves.length === 0) { gen.done = true; gen.best = null; return true; }
  if (gen.rootMoves.length === 1) { gen.best = gen.rootMoves[0]; gen.done = true; return true; }

  gen.nodes = 0;
  gen.budget = nodeBudget || 20000;
  gen.aborted = false;
  gen.rootBest = null;

  var score = search(gen, gen.pos, gen.depth, -MATE * 2, MATE * 2, 0);

  if (!gen.aborted && gen.rootBest) {
    gen.best = gen.rootBest;
    gen.bestScore = score;
    gen.depth++;
    if (gen.depth > gen.maxDepth) gen.done = true;
  } else if (gen.aborted) {
    // Out of budget at this depth. Keep the last completed result rather than
    // a half-searched one; searching deeper would only cost more.
    gen.done = gen.best !== null;
    if (!gen.best) {
      // Not even depth 1 finished. Take the best-ordered legal move so the
      // engine always answers rather than hanging.
      gen.best = orderMoves(gen.rootMoves.slice())[0];
      gen.done = true;
    }
  }

  if (gen.done) applySlack(gen);
  return gen.done;
}

// At easier levels, pick randomly among moves close to the best score rather
// than always the top one. Playing the single best move every time is what
// makes a weak engine feel unbeatable in the openings and stupid later.
function applySlack(gen) {
  if (gen.slack <= 0 || !gen.best || gen.rootMoves.length < 2) return;
  var pos = gen.pos;
  var scored = [];
  var us = pos.turn;
  for (var i = 0; i < gen.rootMoves.length; i++) {
    var m = gen.rootMoves[i];
    var undo = Chess.make(pos, m);
    var s = -evaluate(pos);
    Chess.unmake(pos, m, undo);
    scored.push({ move: m, score: s });
  }
  scored.sort(function (a, b) { return b.score - a.score; });
  var cut = scored[0].score - gen.slack;
  var pool = scored.filter(function (e) { return e.score >= cut; });
  if (pool.length === 0) return;
  gen.best = pool[Math.floor(gen.rng() * pool.length)].move;
}

// Blocking convenience for tests.
function bestMove(pos, level, rng) {
  var gen = createSearch(pos, level, rng);
  var guard = 0;
  while (!step(gen, 1000000) && guard++ < 64) { /* run it out */ }
  return gen.best;
}
