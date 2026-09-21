.pragma library

// Chess rules: move generation, legality, SAN, FEN. No QML, no I/O.
//
// 0x88 board. Squares are 0..127, but only those with (sq & 0x88) === 0 are on
// the real board; the off-board bits make bounds checking a single AND instead
// of two comparisons, and they make "did this slide leave the board" free.
//
// Correctness here is not a matter of opinion: perft against the published
// node counts for the standard test positions settles it. A move generator
// that mishandles en passant, castling through check, or a pinned piece will
// not match them.

// ------------------------------------------------------------------ pieces

var EMPTY = 0;
var PAWN = 1, KNIGHT = 2, BISHOP = 3, ROOK = 4, QUEEN = 5, KING = 6;
var WHITE = 0, BLACK = 1;

function pieceOf(color, type) { return type | (color << 3); }
function typeOf(p) { return p & 7; }
function colorOf(p) { return (p >> 3) & 1; }

var SYMBOLS = " PNBRQK  pnbrqk";

// ---------------------------------------------------------------- geometry

function fileOf(sq) { return sq & 15; }
function rankOf(sq) { return sq >> 4; }
function onBoard(sq) { return (sq & 0x88) === 0; }
function square(file, rank) { return rank * 16 + file; }

// Algebraic <-> 0x88. Rank 0 is White's back rank, so rank 7 prints as "8".
function algebraic(sq) {
  return "abcdefgh".charAt(fileOf(sq)) + String(rankOf(sq) + 1);
}
function fromAlgebraic(s) {
  if (typeof s !== "string" || s.length < 2) return -1;
  var f = "abcdefgh".indexOf(s.charAt(0));
  var r = parseInt(s.charAt(1), 10) - 1;
  if (f < 0 || isNaN(r) || r < 0 || r > 7) return -1;
  return square(f, r);
}

var KNIGHT_DELTAS = [33, 31, 18, 14, -33, -31, -18, -14];
var BISHOP_DELTAS = [17, 15, -17, -15];
var ROOK_DELTAS   = [16, -16, 1, -1];
var KING_DELTAS   = [17, 16, 15, 1, -1, -15, -16, -17];
// Hoisted, not built per call. BISHOP_DELTAS.concat(ROOK_DELTAS) allocated a
// fresh array for every queen on the board, and the pawn tables allocated one
// per pawn - together most of the cost of generating a position's moves.
var QUEEN_DELTAS  = [17, 15, -17, -15, 16, -16, 1, -1];
var WHITE_PAWN_CAPS = [15, 17];
var BLACK_PAWN_CAPS = [-15, -17];
var WHITE_PAWN_ATTACKERS = [-17, -15];
var BLACK_PAWN_ATTACKERS = [17, 15];

// Castling rights, one bit each.
var WK = 1, WQ = 2, BK = 4, BQ = 8;

// --------------------------------------------------------------- positions

function emptyPosition() {
  return {
    board: new Array(128),
    turn: WHITE,
    castling: 0,
    ep: -1,           // en-passant target square, -1 when there is none
    halfmove: 0,      // plies since a pawn move or capture, for the 50-move rule
    fullmove: 1,
    kings: [-1, -1]
  };
}

function clone(pos) {
  return {
    board: pos.board.slice(),
    turn: pos.turn,
    castling: pos.castling,
    ep: pos.ep,
    halfmove: pos.halfmove,
    fullmove: pos.fullmove,
    kings: pos.kings.slice()
  };
}

var START_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

function loadFen(fen) {
  var pos = emptyPosition();
  for (var i = 0; i < 128; i++) pos.board[i] = EMPTY;

  var parts = String(fen).trim().split(/\s+/);
  if (parts.length < 4) return null;

  var rows = parts[0].split("/");
  if (rows.length !== 8) return null;

  for (var r = 0; r < 8; r++) {
    var rank = 7 - r;       // FEN starts at rank 8
    var file = 0;
    var row = rows[r];
    for (var c = 0; c < row.length; c++) {
      var ch = row.charAt(c);
      if (ch >= "1" && ch <= "8") { file += parseInt(ch, 10); continue; }
      var idx = SYMBOLS.indexOf(ch);
      if (idx < 1 || file > 7) return null;
      var color = idx > 8 ? BLACK : WHITE;
      var type = idx > 8 ? idx - 8 : idx;
      var sq = square(file, rank);
      pos.board[sq] = pieceOf(color, type);
      if (type === KING) pos.kings[color] = sq;
      file++;
    }
    if (file !== 8) return null;
  }

  pos.turn = parts[1] === "b" ? BLACK : WHITE;

  var rights = parts[2];
  if (rights.indexOf("K") !== -1) pos.castling |= WK;
  if (rights.indexOf("Q") !== -1) pos.castling |= WQ;
  if (rights.indexOf("k") !== -1) pos.castling |= BK;
  if (rights.indexOf("q") !== -1) pos.castling |= BQ;

  pos.ep = parts[3] === "-" ? -1 : fromAlgebraic(parts[3]);
  pos.halfmove = parts.length > 4 ? (parseInt(parts[4], 10) || 0) : 0;
  pos.fullmove = parts.length > 5 ? (parseInt(parts[5], 10) || 1) : 1;

  if (pos.kings[WHITE] === -1 || pos.kings[BLACK] === -1) return null;
  return pos;
}

function toFen(pos) {
  var out = "";
  for (var rank = 7; rank >= 0; rank--) {
    var run = 0;
    for (var file = 0; file < 8; file++) {
      var p = pos.board[square(file, rank)];
      if (p === EMPTY) { run++; continue; }
      if (run > 0) { out += run; run = 0; }
      var type = typeOf(p);
      out += colorOf(p) === WHITE ? SYMBOLS.charAt(type) : SYMBOLS.charAt(type + 8);
    }
    if (run > 0) out += run;
    if (rank > 0) out += "/";
  }
  var rights = "";
  if (pos.castling & WK) rights += "K";
  if (pos.castling & WQ) rights += "Q";
  if (pos.castling & BK) rights += "k";
  if (pos.castling & BQ) rights += "q";
  return out + " " + (pos.turn === WHITE ? "w" : "b")
             + " " + (rights === "" ? "-" : rights)
             + " " + (pos.ep === -1 ? "-" : algebraic(pos.ep))
             + " " + pos.halfmove + " " + pos.fullmove;
}

function startPosition() { return loadFen(START_FEN); }

// ----------------------------------------------------------------- attacks

// Is `sq` attacked by any piece of `byColor`? Used for check detection and for
// castling, which may not pass through an attacked square.
function attacked(pos, sq, byColor) {
  var i, d, t, p;

  // Pawns. A white pawn on x attacks x+15 and x+17, so to find white pawns
  // attacking sq we look back down those diagonals.
  var pawnDirs = byColor === WHITE ? WHITE_PAWN_ATTACKERS : BLACK_PAWN_ATTACKERS;
  for (i = 0; i < 2; i++) {
    t = sq + pawnDirs[i];
    if (onBoard(t)) {
      p = pos.board[t];
      if (p !== EMPTY && colorOf(p) === byColor && typeOf(p) === PAWN) return true;
    }
  }

  for (i = 0; i < 8; i++) {
    t = sq + KNIGHT_DELTAS[i];
    if (!onBoard(t)) continue;
    p = pos.board[t];
    if (p !== EMPTY && colorOf(p) === byColor && typeOf(p) === KNIGHT) return true;
  }

  for (i = 0; i < 8; i++) {
    t = sq + KING_DELTAS[i];
    if (!onBoard(t)) continue;
    p = pos.board[t];
    if (p !== EMPTY && colorOf(p) === byColor && typeOf(p) === KING) return true;
  }

  for (i = 0; i < 4; i++) {
    d = BISHOP_DELTAS[i];
    t = sq + d;
    while (onBoard(t)) {
      p = pos.board[t];
      if (p !== EMPTY) {
        if (colorOf(p) === byColor && (typeOf(p) === BISHOP || typeOf(p) === QUEEN)) return true;
        break;
      }
      t += d;
    }
  }

  for (i = 0; i < 4; i++) {
    d = ROOK_DELTAS[i];
    t = sq + d;
    while (onBoard(t)) {
      p = pos.board[t];
      if (p !== EMPTY) {
        if (colorOf(p) === byColor && (typeOf(p) === ROOK || typeOf(p) === QUEEN)) return true;
        break;
      }
      t += d;
    }
  }

  return false;
}

function inCheck(pos, color) {
  var c = color === undefined ? pos.turn : color;
  return attacked(pos, pos.kings[c], c ^ 1);
}

// -------------------------------------------------------- move generation

// Flags on a move, so the UI and SAN do not have to re-derive them.
var FLAG_CAPTURE = 1, FLAG_EP = 2, FLAG_DOUBLE = 4,
    FLAG_KCASTLE = 8, FLAG_QCASTLE = 16, FLAG_PROMO = 32;

function makeMove(from, to, piece, captured, flags, promotion) {
  return {
    from: from, to: to, piece: piece, captured: captured || EMPTY,
    flags: flags || 0, promotion: promotion || 0
  };
}

var PROMOTION_PIECES = [QUEEN, ROOK, BISHOP, KNIGHT];

// Pseudo-legal moves: shape is correct, but they may leave the king in check.
// `legalMoves` filters those out.
//
// `capturesOnly` generates just captures and promotions. Quiescence searches
// only those, and it is the majority of all nodes - generating every quiet
// move there and filtering them away afterwards cost about two thirds of the
// engine's speed.
function generateMoves(pos, onlySquare, capturesOnly) {
  var moves = [];
  var us = pos.turn, them = us ^ 1;

  for (var sq = 0; sq < 128; sq++) {
    if (sq & 0x88) { sq += 7; continue; }      // skip the off-board half of the row
    var p = pos.board[sq];
    if (p === EMPTY || ((p >> 3) & 1) !== us) continue;
    if (onlySquare !== undefined && onlySquare >= 0 && sq !== onlySquare) continue;

    var type = typeOf(p), i, d, t, target;

    if (type === PAWN) {
      var forward = us === WHITE ? 16 : -16;
      var startRank = us === WHITE ? 1 : 6;
      var promoRank = us === WHITE ? 7 : 0;

      t = sq + forward;
      if (onBoard(t) && pos.board[t] === EMPTY) {
        if (rankOf(t) === promoRank) {
          // A promotion changes material, so quiescence wants it even though
          // it is not a capture.
          for (i = 0; i < 4; i++)
            moves.push(makeMove(sq, t, p, EMPTY, FLAG_PROMO, PROMOTION_PIECES[i]));
        } else if (!capturesOnly) {
          moves.push(makeMove(sq, t, p, EMPTY, 0));
          // Two squares, only from the home rank and only through an empty one.
          if (rankOf(sq) === startRank) {
            var t2 = sq + forward * 2;
            if (pos.board[t2] === EMPTY)
              moves.push(makeMove(sq, t2, p, EMPTY, FLAG_DOUBLE));
          }
        }
      }

      var caps = us === WHITE ? WHITE_PAWN_CAPS : BLACK_PAWN_CAPS;
      for (i = 0; i < 2; i++) {
        t = sq + caps[i];
        if (!onBoard(t)) continue;
        target = pos.board[t];
        if (target !== EMPTY && colorOf(target) === them) {
          if (rankOf(t) === promoRank) {
            for (var q = 0; q < 4; q++)
              moves.push(makeMove(sq, t, p, target, FLAG_CAPTURE | FLAG_PROMO, PROMOTION_PIECES[q]));
          } else {
            moves.push(makeMove(sq, t, p, target, FLAG_CAPTURE));
          }
        } else if (t === pos.ep) {
          // The captured pawn is beside the moving pawn, not on the target.
          var victim = pos.board[pos.ep - forward];
          moves.push(makeMove(sq, t, p, victim, FLAG_CAPTURE | FLAG_EP));
        }
      }
      continue;
    }

    if (type === KNIGHT || type === KING) {
      var deltas = type === KNIGHT ? KNIGHT_DELTAS : KING_DELTAS;
      for (i = 0; i < 8; i++) {
        t = sq + deltas[i];
        if (!onBoard(t)) continue;
        target = pos.board[t];
        if (target === EMPTY) { if (!capturesOnly) moves.push(makeMove(sq, t, p, EMPTY, 0)); }
        else if (colorOf(target) === them) moves.push(makeMove(sq, t, p, target, FLAG_CAPTURE));
      }
      continue;
    }

    var slides = type === BISHOP ? BISHOP_DELTAS
               : type === ROOK ? ROOK_DELTAS
               : QUEEN_DELTAS;
    for (i = 0; i < slides.length; i++) {
      d = slides[i];
      t = sq + d;
      while (onBoard(t)) {
        target = pos.board[t];
        if (target === EMPTY) {
          if (!capturesOnly) moves.push(makeMove(sq, t, p, EMPTY, 0));
          t += d; continue;
        }
        if (colorOf(target) === them) moves.push(makeMove(sq, t, p, target, FLAG_CAPTURE));
        break;
      }
    }
  }

  // Castling. Generated only when the whole king path is clear and unattacked;
  // a king may not castle out of, through, or into check.
  if (!capturesOnly && (onlySquare === undefined || onlySquare < 0 || onlySquare === pos.kings[us])) {
    var k = pos.kings[us];
    var kingSide = us === WHITE ? WK : BK;
    var queenSide = us === WHITE ? WQ : BQ;

    if ((pos.castling & kingSide) && pos.board[k + 1] === EMPTY && pos.board[k + 2] === EMPTY) {
      if (!attacked(pos, k, them) && !attacked(pos, k + 1, them) && !attacked(pos, k + 2, them))
        moves.push(makeMove(k, k + 2, pos.board[k], EMPTY, FLAG_KCASTLE));
    }
    if ((pos.castling & queenSide) &&
        pos.board[k - 1] === EMPTY && pos.board[k - 2] === EMPTY && pos.board[k - 3] === EMPTY) {
      if (!attacked(pos, k, them) && !attacked(pos, k - 1, them) && !attacked(pos, k - 2, them))
        moves.push(makeMove(k, k - 2, pos.board[k], EMPTY, FLAG_QCASTLE));
    }
  }

  return moves;
}

// Castling rights are lost when a king or rook leaves its home square, and
// also when a rook is captured on its home square.
var CASTLE_MASK = {};
(function buildCastleMask() {
  CASTLE_MASK[square(4, 0)] = WK | WQ;   // e1
  CASTLE_MASK[square(0, 0)] = WQ;        // a1
  CASTLE_MASK[square(7, 0)] = WK;        // h1
  CASTLE_MASK[square(4, 7)] = BK | BQ;   // e8
  CASTLE_MASK[square(0, 7)] = BQ;        // a8
  CASTLE_MASK[square(7, 7)] = BK;        // h8
})();

// Apply a move in place. Returns an undo record for `unmake`.
function make(pos, m) {
  var undo = {
    castling: pos.castling, ep: pos.ep,
    halfmove: pos.halfmove, fullmove: pos.fullmove,
    captured: m.captured, capturedSquare: -1
  };

  var us = pos.turn, forward = us === WHITE ? 16 : -16;

  pos.board[m.to] = (m.flags & FLAG_PROMO) ? pieceOf(us, m.promotion) : m.piece;
  pos.board[m.from] = EMPTY;

  if (m.flags & FLAG_EP) {
    var victimSq = m.to - forward;
    undo.capturedSquare = victimSq;
    pos.board[victimSq] = EMPTY;
  } else if (m.flags & FLAG_CAPTURE) {
    undo.capturedSquare = m.to;
  }

  if (typeOf(m.piece) === KING) {
    pos.kings[us] = m.to;
    if (m.flags & FLAG_KCASTLE) {
      pos.board[m.to - 1] = pos.board[m.to + 1];
      pos.board[m.to + 1] = EMPTY;
    } else if (m.flags & FLAG_QCASTLE) {
      pos.board[m.to + 1] = pos.board[m.to - 2];
      pos.board[m.to - 2] = EMPTY;
    }
  }

  if (CASTLE_MASK[m.from] !== undefined) pos.castling &= ~CASTLE_MASK[m.from];
  if (CASTLE_MASK[m.to] !== undefined) pos.castling &= ~CASTLE_MASK[m.to];

  pos.ep = (m.flags & FLAG_DOUBLE) ? m.from + forward : -1;

  if (typeOf(m.piece) === PAWN || (m.flags & FLAG_CAPTURE)) pos.halfmove = 0;
  else pos.halfmove++;

  if (us === BLACK) pos.fullmove++;
  pos.turn = us ^ 1;

  return undo;
}

function unmake(pos, m, undo) {
  var us = pos.turn ^ 1;     // the side that moved
  pos.turn = us;
  pos.castling = undo.castling;
  pos.ep = undo.ep;
  pos.halfmove = undo.halfmove;
  pos.fullmove = undo.fullmove;

  pos.board[m.from] = m.piece;
  pos.board[m.to] = EMPTY;

  if (typeOf(m.piece) === KING) {
    pos.kings[us] = m.from;
    if (m.flags & FLAG_KCASTLE) {
      pos.board[m.to + 1] = pos.board[m.to - 1];
      pos.board[m.to - 1] = EMPTY;
    } else if (m.flags & FLAG_QCASTLE) {
      pos.board[m.to - 2] = pos.board[m.to + 1];
      pos.board[m.to + 1] = EMPTY;
    }
  }

  if (undo.capturedSquare !== -1) pos.board[undo.capturedSquare] = undo.captured;
}

// Pseudo-legal moves minus the ones that leave our own king attacked. This is
// where pins and "castling into check" are actually resolved.
function legalMoves(pos, onlySquare) {
  var out = [];
  var pseudo = generateMoves(pos, onlySquare);
  var us = pos.turn;
  for (var i = 0; i < pseudo.length; i++) {
    var m = pseudo[i];
    var undo = make(pos, m);
    if (!attacked(pos, pos.kings[us], us ^ 1)) out.push(m);
    unmake(pos, m, undo);
  }
  return out;
}

// ------------------------------------------------------------------ perft
//
// Leaf-node count to a given depth. The published counts for the standard
// positions are the test: a generator that mishandles en passant, castling
// rights or a pin will not reproduce them.
function perft(pos, depth) {
  if (depth === 0) return 1;
  var moves = generateMoves(pos);
  var us = pos.turn;
  var nodes = 0;
  for (var i = 0; i < moves.length; i++) {
    var undo = make(pos, moves[i]);
    if (!attacked(pos, pos.kings[us], us ^ 1)) {
      nodes += depth === 1 ? 1 : perft(pos, depth - 1);
    }
    unmake(pos, moves[i], undo);
  }
  return nodes;
}

// -------------------------------------------------------------------- SAN
//
// Standard algebraic notation, with only as much disambiguation as the
// position actually requires: Nf3 unless another knight can also reach f3,
// then Ngf3, then N1f3, then Ng1f3.
function toSan(pos, move) {
  if (move.flags & FLAG_KCASTLE) return withCheck(pos, move, "O-O");
  if (move.flags & FLAG_QCASTLE) return withCheck(pos, move, "O-O-O");

  var type = typeOf(move.piece);
  var san = "";

  if (type === PAWN) {
    if (move.flags & FLAG_CAPTURE) san += "abcdefgh".charAt(fileOf(move.from)) + "x";
    san += algebraic(move.to);
    if (move.flags & FLAG_PROMO) san += "=" + SYMBOLS.charAt(move.promotion);
    return withCheck(pos, move, san);
  }

  san += SYMBOLS.charAt(type);

  var others = legalMoves(pos).filter(function (m) {
    return m.to === move.to && m.from !== move.from && typeOf(m.piece) === type;
  });
  if (others.length > 0) {
    var sameFile = others.some(function (m) { return fileOf(m.from) === fileOf(move.from); });
    var sameRank = others.some(function (m) { return rankOf(m.from) === rankOf(move.from); });
    if (!sameFile) san += "abcdefgh".charAt(fileOf(move.from));
    else if (!sameRank) san += String(rankOf(move.from) + 1);
    else san += algebraic(move.from);
  }

  if (move.flags & FLAG_CAPTURE) san += "x";
  san += algebraic(move.to);
  return withCheck(pos, move, san);
}

// "+" for check, "#" for mate. Requires playing the move, so it is done once
// here rather than by every caller.
function withCheck(pos, move, san) {
  var work = clone(pos);
  make(work, move);
  if (!inCheck(work)) return san;
  return legalMoves(work).length === 0 ? san + "#" : san + "+";
}

// --------------------------------------------------------------- outcomes

// Neither side can force mate with what is left: K v K, K+minor v K, and
// K+B v K+B with both bishops on the same colour.
function insufficientMaterial(pos) {
  var bishops = [], knights = 0, others = 0;
  for (var sq = 0; sq < 128; sq++) {
    if (!onBoard(sq)) { sq += 7; continue; }
    var p = pos.board[sq];
    if (p === EMPTY) continue;
    var t = typeOf(p);
    if (t === KING) continue;
    if (t === BISHOP) bishops.push((fileOf(sq) + rankOf(sq)) & 1);
    else if (t === KNIGHT) knights++;
    else others++;
  }
  if (others > 0) return false;
  if (knights === 0 && bishops.length === 0) return true;            // K v K
  if (knights === 1 && bishops.length === 0) return true;            // K+N v K
  if (knights === 0 && bishops.length === 1) return true;            // K+B v K
  if (knights === 0 && bishops.length === 2 && bishops[0] === bishops[1]) return true;
  return false;
}

// The position's identity for repetition purposes: placement, side to move,
// castling rights and en-passant target. Move counters are deliberately left
// out - they are not part of the position under the threefold rule.
function positionKey(pos) {
  var fen = toFen(pos).split(" ");
  return fen[0] + " " + fen[1] + " " + fen[2] + " " + fen[3];
}

// `history` is an array of position keys already seen, including the current
// one. Returns one of: "checkmate", "stalemate", "fifty", "repetition",
// "insufficient", or "" when the game is still on.
function outcome(pos, history) {
  if (legalMoves(pos).length === 0) return inCheck(pos) ? "checkmate" : "stalemate";
  if (insufficientMaterial(pos)) return "insufficient";
  if (pos.halfmove >= 100) return "fifty";
  if (history && history.length > 0) {
    var key = positionKey(pos);
    var seen = 0;
    for (var i = 0; i < history.length; i++) if (history[i] === key) seen++;
    if (seen >= 3) return "repetition";
  }
  return "";
}

// Find the legal move matching a from/to (plus promotion choice), or null.
// The UI works in squares; this is the boundary where that becomes a move.
function findMove(pos, from, to, promotion) {
  var moves = legalMoves(pos, from);
  for (var i = 0; i < moves.length; i++) {
    var m = moves[i];
    if (m.from !== from || m.to !== to) continue;
    if (m.flags & FLAG_PROMO) {
      if (promotion && m.promotion !== promotion) continue;
      if (!promotion && m.promotion !== QUEEN) continue;
    }
    return m;
  }
  return null;
}

// Does moving from this square have any legal destination? Used to grey out
// pieces that cannot move, and to decide whether a click starts a drag.
function destinations(pos, from) {
  var moves = legalMoves(pos, from);
  var out = [];
  for (var i = 0; i < moves.length; i++) out.push(moves[i].to);
  return out;
}
