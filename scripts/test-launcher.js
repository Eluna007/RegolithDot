#!/usr/bin/env node
// Tests for the launcher's matching and ranking.
//
// Ranking is the whole product of a launcher: the difference between a good
// one and a bad one is whether the thing you meant is first. "It felt right
// when I tried it" is not something a later change can be checked against, so
// the orderings that matter are written down here.
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");

const SRC = path.join(__dirname, "..", "config", "quickshell", "apollo", "panels", "launcher");
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), "apollo-launch-"));
process.on("exit", () => fs.rmSync(TMP, { recursive: true, force: true }));

let src = fs.readFileSync(path.join(SRC, "Match.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
const names = new Set((src.match(/^function (\w+)/gm) || []).map(s => s.slice(9)));
src += `\nmodule.exports = {${[...names].join(",")}};\n`;
fs.writeFileSync(path.join(TMP, "Match.js"), src);
const M = require(path.join(TMP, "Match.js"));

let csrc = fs.readFileSync(path.join(SRC, "Commands.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
const cnames = new Set((csrc.match(/^function (\w+)/gm) || []).map(s => s.slice(9)));
csrc += `\nmodule.exports = {${[...cnames].join(",")}};\n`;
fs.writeFileSync(path.join(TMP, "Commands.js"), csrc);
const C = require(path.join(TMP, "Commands.js"));

let failures = 0;
function ok(label, cond, detail) {
    if (cond) console.log("  ok   " + label);
    else { console.log("  FAIL " + label + (detail ? ": " + detail : "")); failures++; }
}

const APPS = [
    "Firefox", "Files", "Visual Studio Code", "GNU Image Manipulation Program",
    "Calculator", "Calendar", "Terminal", "Settings", "Steam", "Signal",
    "Text Editor", "Disk Usage Analyzer", "Software", "Mail"
].map(n => ({ name: n, exec: n.toLowerCase(), comment: "" }));

function top(q, n) { return M.filter(q, APPS).slice(0, n || 1).map(a => a.name); }

console.log("the thing you meant comes first:");
ok("exact name", top("Steam")[0] === "Steam", top("Steam")[0]);
ok("prefix", top("fire")[0] === "Firefox", top("fire")[0]);
ok("initials find a multi-word app", top("vsc")[0] === "Visual Studio Code", top("vsc")[0]);
ok("initials again", top("dua")[0] === "Disk Usage Analyzer", top("dua")[0]);
ok("subsequence", top("gimp")[0] === "GNU Image Manipulation Program", top("gimp")[0]);
ok("a short prefix beats a longer one", top("cal")[0] === "Calendar" || top("cal")[0] === "Calculator", top("cal")[0]);
ok("case does not matter", top("STEAM")[0] === "Steam", top("STEAM")[0]);

console.log("what must not match:");
ok("letters out of order do not match",
   M.filter("pmig", APPS).every(a => a.name !== "GNU Image Manipulation Program"));
ok("nonsense matches nothing", M.filter("zzzz", APPS).length === 0);
ok("a query longer than any name matches nothing",
   M.filter("x".repeat(80), APPS).length === 0);

console.log("no query:");
{
    const all = M.filter("", APPS);
    ok("returns everything", all.length === APPS.length);
    ok("in the original order", all[0].name === APPS[0].name && all[3].name === APPS[3].name);
    ok("does not alias the input", all !== APPS);
}

console.log("comments are a weak signal, not a loud one:");
{
    const withComments = [
        { name: "Firefox", exec: "firefox", comment: "Browse the web" },
        { name: "Browser Chooser", exec: "bc", comment: "Pick a default" }
    ];
    ok("a name match outranks a comment match",
       M.filter("browser", withComments)[0].name === "Browser Chooser",
       M.filter("browser", withComments)[0].name);
    ok("but a comment still finds an app",
       M.filter("web", withComments).some(a => a.name === "Firefox"));
}

console.log("stability:");
{
    // Two apps that score identically must keep alphabetical order rather than
    // shuffling between keystrokes - a list that reorders under the cursor is
    // how you launch the wrong thing.
    const tied = [{ name: "Alpha App", exec: "a", comment: "" },
                  { name: "Alpha Box", exec: "b", comment: "" }];
    const r1 = M.filter("alpha", tied).map(a => a.name).join(",");
    const r2 = M.filter("alpha", tied).map(a => a.name).join(",");
    ok("repeated filtering is identical", r1 === r2, r1 + " vs " + r2);
    ok("ties keep input order", r1 === "Alpha App,Alpha Box", r1);
}

console.log("parsing apps.sh output:");
{
    const e = M.parseLine("Firefox \t firefox \t /icons/ff.png \t Browse the web".replace(/ \t /g, "\t"));
    ok("all four fields", e && e.name === "Firefox" && e.exec === "firefox" &&
       e.icon === "/icons/ff.png" && e.comment === "Browse the web");
    const bare = M.parseLine("Thing" + "\t" + "thing");
    ok("missing icon and comment are empty", bare && bare.icon === "" && bare.comment === "");
    ok("a line with no exec is rejected", M.parseLine("OnlyAName") === null);
    ok("an empty line is rejected", M.parseLine("") === null);
    ok("a blank name is rejected", M.parseLine("\texec") === null);
}

console.log("fallback tile letters:");
ok("first letter", M.initial("Firefox") === "F");
ok("digits are fine", M.initial("7zip") === "7");
ok("punctuation falls back", M.initial("!odd") === "?");
ok("an empty name falls back", M.initial("") === "?");


// ── Calculator ───────────────────────────────────────────────────────────
// Precedence is the part that looks right and is wrong. Each of these is a
// case where a plausible-looking evaluator gives a different answer.
console.log("the calculator gets arithmetic right:");
function val(q) { const r = C.calc(q); return r ? r.name : null; }
ok("addition", val("2+2") === "4", val("2+2"));
ok("times binds tighter than plus", val("2 + 2 * 3") === "8", val("2 + 2 * 3"));
ok("parens override precedence", val("(2 + 2) * 3") === "12", val("(2 + 2) * 3"));
ok("power binds tighter than times", val("2*3^2") === "18", val("2*3^2"));
ok("power is right-associative", val("2^3^2") === "512", val("2^3^2"));
ok("unary minus", val("-3 + 1") === "-2", val("-3 + 1"));
ok("minus after an operator", val("2 * -3") === "-6", val("2 * -3"));
ok("subtraction is left-associative", val("10 - 3 - 2") === "5", val("10 - 3 - 2"));
ok("modulo", val("10 % 3") === "1", val("10 % 3"));
ok("x means times", val("3 x 4") === "12", val("3 x 4"));
ok("functions", val("sqrt(16)") === "4", val("sqrt(16)"));
ok("constants", val("ln(e)") === "1", val("ln(e)"));
ok("nesting", val("sqrt(sqrt(16))") === "2", val("sqrt(sqrt(16))"));

console.log("the calculator does not lie about floats:");
ok("binary noise is trimmed", val("0.1 + 0.2") === "0.3", val("0.1 + 0.2"));
ok("a real repeating decimal is not", val("1/3").startsWith("0.3333"), val("1/3"));
ok("integers stay integers", val("6/3") === "2", val("6/3"));

console.log("the calculator stays out of the way:");
ok("a bare number is not a calculation", val("5") === null, val("5"));
ok("...unless you ask with =", val("=5") === "5", val("=5"));
ok("an app name is not a calculation", val("firefox") === null, val("firefox"));
ok("a constant alone is not either", val("e") === null, val("e"));
ok("an unknown function is refused", val("frobnicate(2)") === null, val("frobnicate(2)"));
ok("a malformed number is refused", val("1.2.3") === null, val("1.2.3"));
ok("an unbalanced paren is refused", val("(2+3") === null, val("(2+3"));
ok("a trailing operator is refused", val("2+") === null, val("2+"));
ok("division by zero is refused", val("5/0") === null, val("5/0"));
ok("modulo by zero is refused", val("5%0") === null, val("5%0"));
ok("an empty query is refused", C.calc("") === null);

// ── Windows ──────────────────────────────────────────────────────────────
console.log("open windows become entries:");
{
    const tops = [
        { title: "README.md - nvim", address: "5a1", workspace: { id: 2 } },
        { title: "", address: "5a2", workspace: { id: 1 } },
        { title: "Scratch", address: "5a3", workspace: { id: -99 } },
        { title: "Firefox", address: "5a4", workspace: null },
        null
    ];
    const w = C.windowEntries(tops);
    ok("titled windows are listed", w.length === 2, JSON.stringify(w.map(e => e.name)));
    ok("the special workspace stays hidden", !w.some(e => e.name === "Scratch"));
    ok("an untitled window is skipped", !w.some(e => e.name === ""));
    ok("the address is carried through", w[0].address === "5a1", w[0].address);
    ok("the workspace is shown", w[0].comment === "Workspace 2", w[0].comment);
    ok("no workspace does not crash", w[1].comment === "Open window", w[1].comment);
    ok("a null toplevel is skipped", C.windowEntries([null, undefined]).length === 0);
    ok("no toplevels at all is fine", C.windowEntries(null).length === 0);
}

// ── One list ─────────────────────────────────────────────────────────────
console.log("everything lands in one ranked list:");
{
    const tops = [{ title: "Steam - Library", address: "b1", workspace: { id: 3 } }];
    const all = C.sources("steam", APPS, tops);
    const ranked = M.filter("steam", all);
    ok("the app beats a window that merely mentions it",
       ranked[0].name === "Steam", ranked[0].name);
    ok("the window is still offered",
       ranked.some(e => e.kind === "window"), JSON.stringify(ranked.map(e => e.name)));

    const locked = M.filter("lock", C.sources("lock", APPS, tops));
    ok("an action matches by name", locked[0] && locked[0].name === "Lock screen",
       locked[0] && locked[0].name);

    ok("with no query, windows come first",
       C.sources("", APPS, tops)[0].kind === "window");
    ok("with no query, actions stay out",
       !C.sources("", APPS, tops).some(e => e.kind === "action"));

    ok("> lists the actions alone",
       C.sources(">", APPS, tops).every(e => e.kind === "action"));
    ok("> strips the prefix from the search",
       C.searchTerm("> wifi") === "wifi", C.searchTerm("> wifi"));
    ok("a plain query is unchanged", C.searchTerm("wifi") === "wifi");
    ok("> filters the actions", M.filter(C.searchTerm(">blue"),
       C.sources(">blue", APPS, tops))[0].name === "Bluetooth");
}

console.log("every action can actually be carried out:");
{
    const acts = C.actionEntries();
    ok("there are some", acts.length > 0);
    const bad = acts.filter(a => !a.exec && !a.panel);
    ok("each has an exec or a panel", bad.length === 0, JSON.stringify(bad));
    const both = acts.filter(a => a.exec && a.panel);
    ok("none has both", both.length === 0, JSON.stringify(both));
    const names = acts.map(a => a.name);
    ok("names are unique", new Set(names).size === names.length);
    ok("every action is tagged", acts.every(a => a.kind === "action"));
}

if (failures > 0) {
    console.log(`\n${failures} failure(s)`);
    process.exit(1);
}
console.log("\nok - launcher: ranking is what it claims, and stable");
