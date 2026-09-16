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

if (failures > 0) {
    console.log(`\n${failures} failure(s)`);
    process.exit(1);
}
console.log("\nok - launcher: ranking is what it claims, and stable");
