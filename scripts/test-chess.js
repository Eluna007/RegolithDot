#!/usr/bin/env node
// Tests for the Apollo chess widget's logic.
//
// The centrepiece is perft: count leaf nodes to depth N from positions whose
// counts are published and agreed on. A move generator that mishandles en
// passant, castling through check, promotion or a pinned piece cannot match
// them by accident. Everything else here is a sanity check by comparison.
//
// The QML .js files are loaded by rewriting them into CommonJS modules in a
// temp dir and require()ing them. Running them through vm.createContext
// instead - which is what the Apolloku tests do - makes them about 60x slower,
// because V8 will not optimise property access against a sandbox object. That
// is the difference between this suite taking two seconds and taking minutes.
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");

const SRC = path.join(__dirname, "..", "config", "quickshell", "apollo", "panels", "chess");
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), "apollo-chess-"));
process.on("exit", () => fs.rmSync(TMP, { recursive: true, force: true }));

function shim(name) {
    let src = fs.readFileSync(path.join(SRC, name), "utf8")
        .replace(/^\.pragma library\s*$/m, "")
        .replace(/^\.import\s+"Chess\.js"\s+as\s+Chess\s*$/m, 'const Chess = require("./Chess.js");');
    const names = new Set(src.match(/^function (\w+)/gm)?.map(s => s.slice(9)) ?? []);
    for (const decl of src.match(/^var [^;]+;/gm) ?? []) {
        for (const part of decl.slice(4, -1).split(",")) {
            const m = part.match(/^\s*(\w+)\s*=/);
            if (m) names.add(m[1]);
        }
    }
    src += `\nmodule.exports = {${[...names].sort().join(",")}};\n`;
    fs.writeFileSync(path.join(TMP, name), src);
}
shim("Chess.js");
shim("Engine.js");
const C = require(path.join(TMP, "Chess.js"));
const E = require(path.join(TMP, "Engine.js"));

let failures = 0;
function ok(label, cond, detail) {
    if (cond) console.log("  ok   " + label);
    else { console.log("  FAIL " + label + (detail ? ": " + detail : "")); failures++; }
}

// ── perft ───────────────────────────────────────────────────────────────
// The standard positions. Counts are the published ones.
console.log("perft — move generation is either exactly right or it is wrong:");
const PERFT = [
    ["startpos", "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        [20, 400, 8902, 197281]],
    ["kiwipete", "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
        [48, 2039, 97862, 4085603]],
    ["position 3", "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
        [14, 191, 2812, 43238, 674624]],
    ["position 4", "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
        [6, 264, 9467, 422333]],
    ["position 5", "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",
        [44, 1486, 62379, 2103487]],
    ["position 6", "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10",
        [46, 2079, 89890, 3894594]],
];
let totalNodes = 0;
const perftStart = Date.now();
for (const [name, fen, counts] of PERFT) {
    const got = counts.map((_, i) => C.perft(C.loadFen(fen), i + 1));
    totalNodes += got.reduce((a, b) => a + b, 0);
    ok(`${name} to depth ${counts.length}`,
       got.every((g, i) => g === counts[i]),
       `got ${JSON.stringify(got)} want ${JSON.stringify(counts)}`);
}
console.log(`       ${totalNodes.toLocaleString()} nodes in ${Date.now() - perftStart}ms`);

// ── FEN ─────────────────────────────────────────────────────────────────
console.log("FEN:");
ok("start position round-trips", C.toFen(C.startPosition()) === C.START_FEN);
for (const [, fen] of PERFT) {
    if (C.toFen(C.loadFen(fen)) !== fen) { ok("round-trips " + fen, false); break; }
}
ok("every test position round-trips", PERFT.every(([, f]) => C.toFen(C.loadFen(f)) === f));
ok("rejects nonsense", C.loadFen("not a fen") === null);
ok("rejects a short board", C.loadFen("8/8/8/8 w - - 0 1") === null);
ok("rejects a position with no king", C.loadFen("8/8/8/8/8/8/8/8 w - - 0 1") === null);
ok("rejects a row that is too long", C.loadFen("ppppppppp/8/8/8/8/8/8/K6k w - - 0 1") === null);

// ── SAN ─────────────────────────────────────────────────────────────────
console.log("notation:");
function play(fen, pairs) {
    const pos = fen ? C.loadFen(fen) : C.startPosition();
    const sans = [];
    for (const [from, to, promo] of pairs) {
        const m = C.findMove(pos, C.fromAlgebraic(from), C.fromAlgebraic(to), promo);
        if (!m) return { pos, sans, failed: from + to };
        sans.push(C.toSan(pos, m));
        C.make(pos, m);
    }
    return { pos, sans };
}
{
    const r = play(null, [["e2","e4"],["e7","e5"],["f1","c4"],["b8","c6"],
                          ["d1","h5"],["g8","f6"],["h5","f7"]]);
    ok("scholar's mate reads correctly",
       r.sans.join(" ") === "e4 e5 Bc4 Nc6 Qh5 Nf6 Qxf7#", r.sans.join(" "));
    ok("and it is mate", C.outcome(r.pos, []) === "checkmate");
}
{
    // Knights on b1 and f3 can both reach d2, and d2 has to be empty for that
    // to be true - the first version of this test put a pawn there.
    const r = play("8/8/8/8/8/5N2/8/1N2K2k w - - 0 1", [["b1","d2"]]);
    ok("disambiguates by file", r.sans[0] === "Nbd2", r.sans[0] || r.failed);
}
{
    // Rooks on a1 and a8, both can reach a4: rank disambiguates.
    const r = play("r6k/8/8/8/8/8/8/R5K1 w - - 0 1", [["a1","a4"]]);
    ok("no disambiguation when only one can reach", r.sans[0] === "Ra4", r.sans[0]);
}
{
    // No promotion argument: findMove should default to a queen.
    const r = play("8/P6k/8/8/8/8/8/K7 w - - 0 1", [["a7","a8"]]);
    ok("promotion to queen by default", r.sans[0] === "a8=Q", r.sans[0]);
}
{
    const r = play("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", [["e1","g1"]]);
    ok("kingside castling", r.sans[0] === "O-O", r.sans[0]);
    const r2 = play("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", [["e1","c1"]]);
    ok("queenside castling", r2.sans[0] === "O-O-O", r2.sans[0]);
}

// ── legality ────────────────────────────────────────────────────────────
console.log("legality:");
{
    // A knight pinned along the e-file by the rook on e8. The first version of
    // this put the rook on h1, which is a check the knight can block - so it
    // had a legal move and the test was measuring the wrong thing.
    const pos = C.loadFen("4r2k/8/8/8/8/8/4N3/4K3 w - - 0 1");
    const dests = C.destinations(pos, C.fromAlgebraic("e2"));
    ok("a pinned piece has no moves", dests.length === 0, JSON.stringify(dests.map(C.algebraic)));
}
{
    // Black rook covers f1/g1, so White may not castle through it.
    const pos = C.loadFen("4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1");
    const through = C.loadFen("4k3/8/8/8/8/8/5r2/R3K2R w KQ - 0 1");
    ok("castling is legal when the path is clear",
       C.findMove(pos, C.fromAlgebraic("e1"), C.fromAlgebraic("g1")) !== null);
    ok("castling through an attacked square is refused",
       C.findMove(through, C.fromAlgebraic("e1"), C.fromAlgebraic("g1")) === null);
}
{
    const pos = C.loadFen("4k3/8/8/8/8/8/8/4K2R w K - 0 1");
    ok("cannot castle while in check",
       C.findMove(C.loadFen("4k3/8/8/8/4r3/8/8/4K2R w K - 0 1"),
                  C.fromAlgebraic("e1"), C.fromAlgebraic("g1")) === null);
}

// ── outcomes ────────────────────────────────────────────────────────────
console.log("outcomes:");
ok("stalemate is not checkmate",
   C.outcome(C.loadFen("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1"), []) === "stalemate");
ok("checkmate is checkmate",
   C.outcome(C.loadFen("6rk/5Npp/8/8/8/8/8/6K1 b - - 0 1"), []) === "checkmate");
ok("K vs K is insufficient",
   C.outcome(C.loadFen("4k3/8/8/8/8/8/8/4K3 w - - 0 1"), []) === "insufficient");
ok("K+N vs K is insufficient",
   C.outcome(C.loadFen("4k3/8/8/8/8/8/8/3NK3 w - - 0 1"), []) === "insufficient");
ok("K+R vs K is not",
   C.outcome(C.loadFen("4k3/8/8/8/8/8/8/3RK3 w - - 0 1"), []) === "");
ok("fifty-move rule",
   C.outcome(C.loadFen("4k3/8/8/8/8/8/4R3/4K3 w - - 100 80"), []) === "fifty");
{
    const pos = C.loadFen("4k3/8/8/8/8/8/4R3/4K3 w - - 0 1");
    const key = C.positionKey(pos);
    ok("threefold repetition", C.outcome(pos, [key, key, key]) === "repetition");
    ok("twice is not threefold", C.outcome(pos, [key, key]) === "");
}

// ── make/unmake ─────────────────────────────────────────────────────────
console.log("make/unmake restores the position exactly:");
{
    let clean = true, where = "";
    for (const [name, fen] of PERFT) {
        const pos = C.loadFen(fen);
        const before = C.toFen(pos);
        for (const m of C.generateMoves(pos)) {
            const undo = C.make(pos, m);
            C.unmake(pos, m, undo);
            if (C.toFen(pos) !== before) { clean = false; where = name + " " + C.algebraic(m.from) + C.algebraic(m.to); break; }
        }
        if (!clean) break;
    }
    ok("every move in every test position", clean, where);
}

// ── engine ──────────────────────────────────────────────────────────────
console.log("engine:");
{
    const fen = "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 0 1";
    const pos = C.loadFen(fen);
    const m = E.bestMove(C.loadFen(fen), 4);
    ok("finds mate in one", m && C.toSan(pos, m) === "Qxf7#", m ? C.toSan(pos, m) : "none");
}
{
    const fen = "rnb1kbnr/pppp1ppp/8/4p3/6q1/5P2/PPPPP1PP/RNBQKBNR w KQkq - 0 1";
    const m = E.bestMove(C.loadFen(fen), 3);
    ok("takes a hanging queen", m && C.algebraic(m.to) === "g4", m ? C.algebraic(m.to) : "none");
}
{
    // Exactly one legal move: Kxg2. With the queen on f2 instead the king has
    // none at all, which is stalemate, not a forced move.
    const fen = "7k/8/8/8/8/8/6q1/7K w - - 0 1";
    const pos = C.loadFen(fen);
    const legal = C.legalMoves(pos);
    const m = E.bestMove(C.loadFen(fen), 5);
    ok("plays the only legal move", legal.length === 1 && m && m.to === legal[0].to,
       `${legal.length} legal`);
}
{
    // Never returns an illegal move, at any level, from any test position.
    let clean = true, detail = "";
    for (const [name, fen] of PERFT) {
        for (let lv = 1; lv <= 5; lv++) {
            const pos = C.loadFen(fen);
            const m = E.bestMove(C.loadFen(fen), lv);
            if (!m) { clean = false; detail = `${name} level ${lv}: no move`; break; }
            const legal = C.legalMoves(pos);
            if (!legal.some(l => l.from === m.from && l.to === m.to && l.promotion === m.promotion)) {
                clean = false;
                detail = `${name} level ${lv}: ${C.algebraic(m.from)}${C.algebraic(m.to)} is not legal`;
                break;
            }
        }
        if (!clean) break;
    }
    ok("only ever returns legal moves", clean, detail);
}
{
    // Sliced search must agree with the blocking one and stay bounded.
    const fen = "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 1";
    const gen = E.createSearch(C.loadFen(fen), 4);
    let slices = 0;
    while (!E.step(gen, 6000) && slices < 200) slices++;
    ok("sliced search terminates", gen.done && slices < 200, `${slices} slices`);
    ok("sliced search produces a legal move",
       gen.best && C.legalMoves(C.loadFen(fen)).some(l => l.from === gen.best.from && l.to === gen.best.to));
    ok("a one-node budget still returns a move",
       (() => { const g = E.createSearch(C.loadFen(fen), 4);
                let n = 0; while (!E.step(g, 1) && n++ < 200) {}
                return g.best !== null; })());
}
{
    // A mated side has nothing to play; the engine must say so, not crash.
    const g = E.createSearch(C.loadFen("6rk/5Npp/8/8/8/8/8/6K1 b - - 0 1"), 3);
    while (!E.step(g, 20000)) { /* run out */ }
    ok("no move when checkmated", g.done && g.best === null);
}

if (failures > 0) {
    console.log(`\n${failures} failure(s)`);
    process.exit(1);
}
console.log("\nok - chess: perft exact on 6 positions, engine legal at every level");
