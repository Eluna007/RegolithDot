#!/usr/bin/env node
// Tests for the Apolloku puzzle logic.
//
// Sudoku.js and Model.js are QML `.pragma library` files, but they are plain
// ECMAScript underneath - so node can load and exercise them for real. That
// matters: a generator that occasionally emits a puzzle with two solutions,
// or a difficulty rating that is decorative rather than measured, would look
// completely fine in the UI and be wrong.
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const DIR = path.join(__dirname, "..", "config", "quickshell", "apollo", "panels", "apolloku");

function load(name) {
    const src = fs.readFileSync(path.join(DIR, name), "utf8").replace(/^\.pragma library\s*$/m, "");
    const sandbox = { console };
    vm.createContext(sandbox);
    new vm.Script(src, { filename: name }).runInContext(sandbox);
    return sandbox;
}

const S = load("Sudoku.js");
const M = load("Model.js");

let failures = 0;
function ok(label, cond, detail) {
    if (cond) { console.log("  ok   " + label); }
    else { console.log("  FAIL " + label + (detail ? ": " + detail : "")); failures++; }
}

// Deterministic RNG, so a failure is reproducible rather than a puzzle nobody
// can get back. mulberry32.
function rng(seed) {
    let a = seed >>> 0;
    return function () {
        a |= 0; a = (a + 0x6D2B79F5) | 0;
        let t = Math.imul(a ^ (a >>> 15), 1 | a);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

function isValidSolution(g) {
    if (g.length !== 81) return false;
    for (let u = 0; u < 9; u++) {
        const row = new Set(), col = new Set(), box = new Set();
        for (let i = 0; i < 9; i++) {
            row.add(g[u * 9 + i]);
            col.add(g[i * 9 + u]);
            box.add(g[((u / 3) | 0) * 27 + (u % 3) * 3 + ((i / 3) | 0) * 9 + (i % 3)]);
        }
        if (row.size !== 9 || col.size !== 9 || box.size !== 9) return false;
    }
    return g.every(v => v >= 1 && v <= 9);
}

console.log("solved grids:");
for (const seed of [1, 2, 7, 42, 1337]) {
    const g = S.generateSolution(rng(seed));
    ok(`seed ${seed} produces a legal complete grid`, isValidSolution(g));
}
{
    const a = S.generateSolution(rng(1)).join("");
    const b = S.generateSolution(rng(2)).join("");
    ok("different seeds give different grids", a !== b);
    ok("same seed is reproducible", a === S.generateSolution(rng(1)).join(""));
}

console.log("solver:");
{
    // 41 holes can admit many solutions, so the contract is "returns *a*
    // valid solution consistent with the clues", not "returns the original".
    const sol = S.generateSolution(rng(3));
    const holes = sol.slice();
    for (let i = 0; i < 81; i += 2) holes[i] = 0;
    const solved = S.solve(holes);
    const consistent = solved !== null && holes.every((v, i) => v === 0 || v === solved[i]);
    ok("solves a half-empty grid", solved !== null && isValidSolution(solved) && consistent);

    // With a unique puzzle it must return exactly the original.
    const g = S.generate("Easy", rng(3));
    const one = S.solve(g.puzzle);
    ok("a unique puzzle solves back to its own solution",
       one !== null && one.join("") === g.solution.join(""));
}
{
    // Two 1s in the same row: no solutions at all, and no crash.
    const bad = S.emptyGrid();
    bad[0] = 1; bad[1] = 1;
    ok("contradictory grid has no solution", S.solve(bad) === null);
    ok("contradictory grid counts zero", S.countSolutions(bad, 2) === 0);
}
{
    const empty = S.emptyGrid();
    ok("empty grid has many solutions", S.countSolutions(empty, 2) >= 2);
}

console.log("generation — uniqueness is the property that matters:");
for (const level of ["Easy", "Medium", "Hard", "Expert"]) {
    let allUnique = true, allConsistent = true, worst = null;
    for (let seed = 1; seed <= 8; seed++) {
        const g = S.generate(level, rng(seed * 97 + level.length));
        if (!S.hasUniqueSolution(g.puzzle)) { allUnique = false; worst = seed; }
        if (!isValidSolution(g.solution)) allConsistent = false;
        for (let i = 0; i < 81; i++) {
            if (g.puzzle[i] !== 0 && g.puzzle[i] !== g.solution[i]) allConsistent = false;
        }
    }
    ok(`${level}: 8 puzzles all have exactly one solution`, allUnique, worst && `seed ${worst}`);
    ok(`${level}: clues always agree with the solution`, allConsistent);
}

console.log("difficulty rating — measured, not decorative:");
{
    // A puzzle solvable by naked singles alone must not be called Expert just
    // because it is sparse. This is the flaw the clue-count version had.
    const sol = S.generateSolution(rng(11));
    const easy = sol.slice();
    for (let i = 0; i < 12; i++) easy[i * 7 % 81] = 0;
    ok("a nearly-full grid rates Easy", S.rate(easy) === "Easy", S.rate(easy));

    ok("a solved grid rates Easy (nothing to do)", S.rate(sol) === "Easy", S.rate(sol));

    const empty = S.emptyGrid();
    ok("an empty grid rates Expert (not logically solvable)", S.rate(empty) === "Expert");
}
{
    const seen = {};
    for (let seed = 1; seed <= 12; seed++) {
        for (const level of ["Easy", "Medium", "Hard", "Expert"]) {
            const g = S.generate(level, rng(seed * 31 + level.charCodeAt(0)));
            const r = S.rate(g.puzzle);
            seen[r] = (seen[r] || 0) + 1;
            if (r !== "Expert" && !S.hasUniqueSolution(g.puzzle)) {
                ok("rated puzzle is still unique", false);
            }
        }
    }
    ok("rating produces more than one class across 48 puzzles",
       Object.keys(seen).length > 1, JSON.stringify(seen));
    console.log("       distribution: " + JSON.stringify(seen));
}

console.log("incremental generation — the UI thread must stay responsive:");
{
    const gen = S.createGenerator("Hard", rng(77));
    let steps = 0;
    ok("a fresh generator is not done", gen.done === false);
    ok("progress starts at zero", S.progress(gen) === 0);
    while (!S.step(gen)) {
        steps++;
        if (steps > 100) break;
    }
    ok("terminates", gen.done === true && steps <= 100);
    ok("never exceeds its attempt budget", gen.attempt <= 24, String(gen.attempt));
    ok("produces a result", gen.result !== null);
    ok("result has a measured rating", S.RATING_ORDER.indexOf(gen.result.rating) >= 0);
    ok("result is unique", S.hasUniqueSolution(gen.result.puzzle));
    ok("progress ends at one", S.progress(gen) === 1);
    ok("stepping past done is harmless", S.step(gen) === true);

    // Stepping must give the same answer as the blocking call for one seed.
    const a = S.generate("Medium", rng(5));
    const g2 = S.createGenerator("Medium", rng(5));
    while (!S.step(g2)) { /* run it out */ }
    ok("incremental matches blocking for the same seed",
       a.puzzle.join("") === g2.result.puzzle.join(""));

    // A budget of 1 must still return a usable puzzle, not null.
    const tiny = S.generate("Expert", rng(9), 1);
    ok("a one-attempt budget still yields a puzzle",
       tiny !== null && S.hasUniqueSolution(tiny.puzzle));
}

console.log("requested difficulty is actually delivered:");
{
    for (const level of ["Easy", "Medium", "Hard", "Expert"]) {
        let exact = 0;
        const n = 10;
        for (let seed = 1; seed <= n; seed++) {
            const g = S.generate(level, rng(seed * 641 + level.length));
            if (g.rating === level) exact++;
        }
        ok(`${level}: rating matches the request at least 7/10`, exact >= 7, `${exact}/10`);
    }
}

console.log("pencil marks:");
{
    const sol = S.generateSolution(rng(5));
    const g = sol.slice();
    g[0] = 0; g[1] = 0;
    const cands = S.candidatesFor(g, 0);
    ok("candidates include the true digit", (cands & (1 << (sol[0] - 1))) !== 0);
    let notes = S.emptyNotes();
    notes[1] = 0x1FF;
    const after = S.clearPeerNotes(notes, 0, sol[0]);
    ok("placing a digit clears that mark from peers",
       (after[1] & (1 << (sol[0] - 1))) === 0);
    ok("clearPeerNotes does not mutate its input", notes[1] === 0x1FF);
}

console.log("conflicts and completion:");
{
    const sol = S.generateSolution(rng(9));
    ok("a solved grid is complete", S.isComplete(sol));
    const dup = sol.slice();
    dup[1] = dup[0];
    ok("a duplicate breaks completion", !S.isComplete(dup));
    const bad = S.conflicts(dup);
    ok("both duplicated cells are flagged", bad[0] && bad[1]);
}

console.log("save/load round-trip:");
{
    const g = S.generate("Medium", rng(4));
    const state = {
        difficulty: "Medium", puzzle: g.puzzle, solution: g.solution,
        cells: g.puzzle.slice(), notes: S.emptyNotes(),
        elapsedMs: 12345, hintsUsed: 2, selected: 40, notesMode: true, solved: false
    };
    const back = M.parse(M.serialize(state));
    ok("round-trips", back !== null);
    ok("keeps elapsed time", back && back.elapsedMs === 12345);
    ok("keeps hint count", back && back.hintsUsed === 2);
    ok("keeps notes mode", back && back.notesMode === true);

    ok("rejects junk", M.parse("not json") === null);
    ok("rejects an empty string", M.parse("") === null);

    // A save whose clues disagree with its solution is corrupt, and loading it
    // would present an unsolvable board as if it were fine.
    const tampered = JSON.parse(M.serialize(state));
    for (let i = 0; i < 81; i++) {
        if (tampered.puzzle[i] !== 0) { tampered.solution[i] = (tampered.puzzle[i] % 9) + 1; break; }
    }
    ok("rejects a save whose clues contradict its solution",
       M.parse(JSON.stringify(tampered)) === null);

    const shortGrid = JSON.parse(M.serialize(state));
    shortGrid.cells = shortGrid.cells.slice(0, 80);
    ok("rejects a grid of the wrong length", M.parse(JSON.stringify(shortGrid)) === null);
}

console.log("stats:");
{
    let st = M.emptyStats();
    st = M.recordStart(st, "Hard", false);
    st = M.recordSolve(st, "Hard", 60000, 0);
    ok("counts a solve", st.solved === 1);
    ok("counts a clean solve", st.cleanSolved === 1);
    ok("records a best time", st.byDifficulty.Hard.bestMs === 60000);
    ok("streak advances", st.streak === 1);

    st = M.recordStart(st, "Hard", false);
    st = M.recordSolve(st, "Hard", 30000, 1);
    ok("faster time replaces best", st.byDifficulty.Hard.bestMs === 30000);
    ok("a hinted solve is not clean", st.cleanSolved === 1);
    ok("streak keeps advancing", st.streak === 2);

    st = M.recordStart(st, "Hard", true);
    ok("abandoning resets the streak", st.streak === 0);
    ok("best streak is remembered", st.bestStreak === 2);

    ok("stats survive a round-trip",
       M.parseStats(M.serializeStats(st)).bestStreak === 2);
    ok("junk stats fall back to empty", M.parseStats("{{{").solved === 0);
}

console.log("time formatting:");
ok("under a minute", M.formatTime(45000) === "0:45", M.formatTime(45000));
ok("minutes and seconds", M.formatTime(125000) === "2:05", M.formatTime(125000));
ok("hours", M.formatTime(3725000) === "1:02:05", M.formatTime(3725000));
ok("negative clamps to zero", M.formatTime(-5) === "0:00", M.formatTime(-5));

if (failures > 0) {
    console.log(`\n${failures} failure(s)`);
    process.exit(1);
}
console.log("\nok - apolloku logic: generation unique, ratings measured, saves validated");
