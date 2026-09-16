#!/usr/bin/env node
// Tests for the keybind cheatsheet's data layer.
//
// A cheatsheet that is wrong is worse than no cheatsheet: you look a shortcut
// up precisely when you do not know it, so you have no way to notice. The
// modmask decoding is a bitfield, the ordering has a natural-sort case that
// looks broken when it is missing, and `hyprctl binds -j` reports the same
// combo several times. None of that is visible by opening the panel once.
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");

const SRC = path.join(__dirname, "..", "config", "quickshell", "apollo", "panels", "keys");
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), "apollo-keys-"));
process.on("exit", () => fs.rmSync(TMP, { recursive: true, force: true }));

let src = fs.readFileSync(path.join(SRC, "Keys.js"), "utf8").replace(/^\.pragma library\s*$/m, "");
const names = new Set((src.match(/^function (\w+)/gm) || []).map(s => s.slice(9)));
src += `\nmodule.exports = {${[...names].join(",")}};\n`;
fs.writeFileSync(path.join(TMP, "Keys.js"), src);
const K = require(path.join(TMP, "Keys.js"));

let failures = 0;
function ok(label, cond, detail) {
    if (cond) console.log("  ok   " + label);
    else { console.log("  FAIL " + label + (detail ? ": " + detail : "")); failures++; }
}
const eq = (a, b) => JSON.stringify(a) === JSON.stringify(b);

console.log("the modmask bitfield decodes:");
ok("no modifiers", eq(K.modNames(0), []));
ok("Super alone", eq(K.modNames(64), ["Super"]));
ok("Super+Shift", eq(K.modNames(65), ["Super", "Shift"]));
ok("Super+Ctrl", eq(K.modNames(68), ["Super", "Ctrl"]));
ok("Super+Alt", eq(K.modNames(72), ["Super", "Alt"]));
ok("all four", eq(K.modNames(77), ["Super", "Ctrl", "Alt", "Shift"]));
ok("Ctrl+Alt without Super", eq(K.modNames(12), ["Ctrl", "Alt"]));
// CAPS (2), MOD2 (16), MOD3 (32) and MOD5 (128) are real bits nobody binds.
// They must not be read as one of the four we do name.
ok("CAPS is ignored, not mistaken for Shift", eq(K.modNames(2), []));
ok("MOD2 is ignored", eq(K.modNames(16), []));
ok("NumLock alongside Super still reads as Super", eq(K.modNames(80), ["Super"]));
ok("a missing modmask is no modifiers", eq(K.modNames(undefined), []));

console.log("keys get readable labels:");
ok("a letter is capitalised", K.keyLabel("q") === "Q");
ok("a named key is left alone", K.keyLabel("Escape") === "Escape");
ok("punctuation is spelled out", K.keyLabel("comma") === ",");
ok("media keys are readable", K.keyLabel("XF86AudioRaiseVolume") === "Volume Up");
ok("an unknown key passes through", K.keyLabel("F13") === "F13");
ok("an empty key is empty", K.keyLabel("") === "");

console.log("combos read the way you say them:");
ok("Super + Q", K.comboOf({ modmask: 64, key: "q" }) === "Super + Q");
ok("Super + Shift + Q", K.comboOf({ modmask: 65, key: "q" }) === "Super + Shift + Q");
ok("a bare media key has no modifier half",
   K.comboOf({ modmask: 0, key: "XF86AudioMute" }) === "Mute");
ok("a keycode-only bind still gets a combo",
   K.comboOf({ modmask: 64, key: "", keycode: 39 }) === "Super + code:39",
   K.comboOf({ modmask: 64, key: "", keycode: 39 }));
ok("a bind with neither is refused", K.comboOf({ modmask: 64, key: "" }) === "");

console.log("a bind's own description wins over its dispatcher:");
ok("description", K.describe({ description: "Close window", dispatcher: "killactive" }) === "Close window");
ok("dispatcher as fallback", K.describe({ dispatcher: "killactive" }) === "killactive");
ok("an empty description falls through",
   K.describe({ description: "", dispatcher: "exec" }) === "exec");
ok("neither yields a placeholder, not a blank", K.describe({}) === "?");

console.log("hyprctl output becomes rows:");
{
    const json = JSON.stringify([
        { modmask: 64, key: "1", description: "Workspace 1" },
        { modmask: 64, key: "10", description: "Workspace 10" },
        { modmask: 64, key: "2", description: "Workspace 2" },
        { modmask: 64, key: "1", description: "Workspace 1" },   // a duplicate
        { modmask: 0, key: "XF86AudioMute", dispatcher: "exec" },
        { modmask: 65, key: "q", description: "Close window" },
        { modmask: 64, key: "" },                                 // unbindable
        { modmask: 64, key: "1", description: "Something else" }  // same key, other action
    ]);
    const rows = K.parseBinds(json);
    ok("the unbindable row is dropped", !rows.some(r => r.combo === "Super"));
    ok("an identical bind appears once",
       rows.filter(r => r.combo === "Super + 1" && r.action === "Workspace 1").length === 1);
    ok("the same key with a different action is kept",
       rows.filter(r => r.combo === "Super + 1").length === 2,
       String(rows.filter(r => r.combo === "Super + 1").length));
    ok("six rows survive", rows.length === 6, String(rows.length));
}

console.log("bad input leaves an empty sheet rather than throwing:");
ok("empty", eq(K.parseBinds(""), []));
ok("not JSON at all", eq(K.parseBinds("hyprctl: command not found"), []));
ok("JSON that is not an array", eq(K.parseBinds('{"error":"no"}'), []));
ok("a JSON string", eq(K.parseBinds('"nope"'), []));
ok("null", eq(K.parseBinds("null"), []));
ok("an empty array", eq(K.parseBinds("[]"), []));

console.log("the sheet is ordered the way a sheet should be:");
{
    const rows = K.parseBinds(JSON.stringify([
        { modmask: 65, key: "q", description: "Close" },
        { modmask: 64, key: "10", description: "Workspace 10" },
        { modmask: 64, key: "2", description: "Workspace 2" },
        { modmask: 64, key: "1", description: "Workspace 1" },
        { modmask: 64, key: "b", description: "Wallpaper" },
        { modmask: 0, key: "XF86AudioMute", dispatcher: "exec" },
        { modmask: 77, key: "x", description: "Everything" }
    ]));
    const groups = K.groupRows(rows);
    ok("fewer modifiers first", groups[0].mods === "Super", groups[0].mods);
    ok("no modifier last", groups[groups.length - 1].mods === "No modifier",
       groups[groups.length - 1].mods);
    ok("the four-modifier group is next to last",
       groups[groups.length - 2].mods === "Super + Ctrl + Alt + Shift",
       groups[groups.length - 2].mods);
    const superKeys = groups[0].rows.map(r => r.key);
    ok("numbers sort numerically, not as text",
       eq(superKeys, ["1", "2", "10", "B"]), JSON.stringify(superKeys));
    ok("every row is kept", K.countRows(groups) === rows.length,
       `${K.countRows(groups)} vs ${rows.length}`);
    ok("no group is empty", groups.every(g => g.rows.length > 0));
}

console.log("search finds what you half-remember:");
{
    const rows = K.parseBinds(JSON.stringify([
        { modmask: 64, key: "q", description: "Close window" },
        { modmask: 64, key: "return", description: "Terminal" },
        { modmask: 65, key: "s", description: "Screenshot a region" }
    ]));
    ok("by action", K.filterRows("screenshot", rows).length === 1);
    ok("case does not matter", K.filterRows("SCREENSHOT", rows).length === 1);
    ok("by combo", K.filterRows("super + q", rows).length === 1);
    ok("by modifier alone", K.filterRows("shift", rows).length === 1);
    ok("an empty query keeps everything", K.filterRows("", rows).length === 3);
    ok("whitespace is an empty query", K.filterRows("   ", rows).length === 3);
    ok("no match is empty, not everything", K.filterRows("zzz", rows).length === 0);
    ok("filtering does not mutate the sheet", rows.length === 3);
}

console.log("a combo splits into key caps:");
ok("three caps", eq(K.caps("Super + Shift + Q"), ["Super", "Shift", "Q"]));
ok("one cap", eq(K.caps("Mute"), ["Mute"]));

if (failures > 0) {
    console.log(`\n${failures} failure(s)`);
    process.exit(1);
}
console.log("\nok - keybinds: the sheet says what is actually bound");
