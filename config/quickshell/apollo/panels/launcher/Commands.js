.pragma library

// Everything the launcher can offer besides an installed application: a
// calculator, the windows that are open right now, and the actions the shell
// can carry out itself.
//
// Pure functions over strings and plain objects, like Match.js, so
// scripts/test-launcher.js can exercise them under node. An arithmetic
// evaluator is exactly the kind of code that looks right and is wrong at the
// third precedence level, and there is no way to notice that by typing a sum
// into a launcher once.
//
// Entries share the shape apps.sh produces - name, comment, icon - plus a
// `kind` and whatever that kind needs to act. LauncherPanel.qml switches on
// `kind`; nothing here runs anything.

// ── Calculator ───────────────────────────────────────────────────────────
//
// A tokenizer and a recursive-descent parser rather than eval(). eval is not
// something to point at a text field, and QML's JS engine is not node's: the
// only way to be sure of what runs is to write the arithmetic out.

var FUNCTIONS = {
    sqrt: Math.sqrt, abs: Math.abs, floor: Math.floor, ceil: Math.ceil,
    round: Math.round, ln: Math.log, log: function (x) { return Math.log(x) / Math.LN10; },
    sin: Math.sin, cos: Math.cos, tan: Math.tan
};

var CONSTANTS = { pi: Math.PI, e: Math.E };

function tokenize(src) {
    var out = [];
    var i = 0;
    while (i < src.length) {
        var c = src.charAt(i);
        if (c === " " || c === "\t" || c === ",") { i++; continue; }
        if (c >= "0" && c <= "9" || c === ".") {
            var start = i;
            while (i < src.length && (src.charAt(i) >= "0" && src.charAt(i) <= "9" || src.charAt(i) === ".")) i++;
            var text = src.substring(start, i);
            // "1.2.3" is not a number, and parseFloat would quietly read 1.2.
            if (text.split(".").length > 2) return null;
            out.push({ t: "num", v: parseFloat(text) });
            continue;
        }
        if (/[a-z]/i.test(c)) {
            var s2 = i;
            while (i < src.length && /[a-z]/i.test(src.charAt(i))) i++;
            var word = src.substring(s2, i).toLowerCase();
            // A lone "x" between operands is the multiplication sign people
            // actually type ("3 x 4"). It has to be decided here rather than
            // in a branch below, because the identifier scan above would
            // otherwise have eaten it already.
            if (word === "x") out.push({ t: "*" });
            else out.push({ t: "name", v: word });
            continue;
        }
        if ("+-*/%^()".indexOf(c) !== -1) { out.push({ t: c }); i++; continue; }
        return null;                      // anything else is not arithmetic
    }
    return out;
}

// expr := term (('+'|'-') term)*
// term := unary (('*'|'/'|'%') unary)*
// unary := ('-'|'+') unary | power
// power := atom ('^' unary)?            right-associative: 2^3^2 is 512
// atom := num | name | name '(' expr ')' | '(' expr ')'
function parse(tokens) {
    var pos = 0;
    var failed = false;

    function peek() { return pos < tokens.length ? tokens[pos] : null; }
    function bail() { failed = true; return 0; }

    function expr() {
        var v = term();
        while (!failed) {
            var t = peek();
            if (!t || (t.t !== "+" && t.t !== "-")) break;
            pos++;
            var r = term();
            v = t.t === "+" ? v + r : v - r;
        }
        return v;
    }

    function term() {
        var v = unary();
        while (!failed) {
            var t = peek();
            if (!t || (t.t !== "*" && t.t !== "/" && t.t !== "%")) break;
            pos++;
            var r = unary();
            // Division by zero yields Infinity in JS, which is not an answer
            // anyone typed a sum to get.
            if (r === 0 && (t.t === "/" || t.t === "%")) return bail();
            v = t.t === "*" ? v * r : t.t === "/" ? v / r : v % r;
        }
        return v;
    }

    function unary() {
        var t = peek();
        if (t && t.t === "-") { pos++; return -unary(); }
        if (t && t.t === "+") { pos++; return unary(); }
        return power();
    }

    function power() {
        var base = atom();
        var t = peek();
        if (t && t.t === "^") { pos++; return Math.pow(base, unary()); }
        return base;
    }

    function atom() {
        var t = peek();
        if (!t) return bail();
        if (t.t === "num") { pos++; return t.v; }
        if (t.t === "(") {
            pos++;
            var v = expr();
            var close = peek();
            if (!close || close.t !== ")") return bail();
            pos++;
            return v;
        }
        if (t.t === "name") {
            pos++;
            if (CONSTANTS[t.v] !== undefined) return CONSTANTS[t.v];
            var fn = FUNCTIONS[t.v];
            if (!fn) return bail();
            var open = peek();
            if (!open || open.t !== "(") return bail();
            pos++;
            var arg = expr();
            var c2 = peek();
            if (!c2 || c2.t !== ")") return bail();
            pos++;
            return fn(arg);
        }
        return bail();
    }

    var value = expr();
    if (failed || pos !== tokens.length) return null;
    return value;
}

// Trim floating-point noise without lying about the value: 0.1 + 0.2 should
// read 0.3, but 1/3 must not read 0.33.
function formatNumber(n) {
    if (typeof n !== "number" || !isFinite(n)) return null;
    if (Math.abs(n) >= 1e15 || (n !== 0 && Math.abs(n) < 1e-10)) {
        return n.toExponential(6).replace(/\.?0+e/, "e");
    }
    var s = n.toPrecision(12);
    if (s.indexOf(".") !== -1) s = s.replace(/\.?0+$/, "");
    // toPrecision can hand back exponent form for large values.
    return s.indexOf("e") === -1 ? String(parseFloat(s)) : s;
}

// A query is a calculation when it parses AND actually computes something.
// A bare "3" parses; offering "3 = 3" above your applications does not help
// anyone, and "e" is a constant that would otherwise shadow every app whose
// name starts with one.
function calc(query) {
    if (!query) return null;
    var src = query.charAt(0) === "=" ? query.substring(1) : query;
    var explicit = query.charAt(0) === "=";
    // Without a leading "=", a query has to look like arithmetic before it is
    // treated as arithmetic - a digit, or a call to one of the functions by
    // name, so that "ln(e)" works while "e" alone stays out of the way of
    // every app whose name starts with one.
    var named = /^\s*([a-z]+)\s*\(/i.exec(src);
    if (!explicit && !/[0-9]/.test(src) &&
        !(named && FUNCTIONS[named[1].toLowerCase()])) return null;
    if (!explicit && !/[-+*/%^()]/.test(src) && !/[a-z]/i.test(src)) return null;
    var tokens = tokenize(src);
    if (!tokens || tokens.length === 0) return null;
    // Requiring an operator or a call keeps plain numbers out.
    var interesting = false;
    for (var i = 0; i < tokens.length; i++) {
        if (tokens[i].t !== "num") { interesting = true; break; }
    }
    if (!interesting && query.charAt(0) !== "=") return null;
    var value = parse(tokens);
    if (value === null) return null;
    var text = formatNumber(value);
    if (text === null) return null;
    return { name: text, comment: src.trim() + " =", icon: "", kind: "calc", value: text };
}

// ── Actions ──────────────────────────────────────────────────────────────
//
// `panel` entries open one of the shell's own panels; `exec` entries are the
// same command strings PowerPanel.qml uses, so there is one spelling of
// "log out" in the shell rather than two that can drift.

function actionEntries() {
    return [
        { name: "Lock screen",     comment: "hyprlock",        icon: "", kind: "action", exec: "hyprlock" },
        { name: "Log out",         comment: "End the session", icon: "", kind: "action", exec: "hyprctl dispatch 'hl.dsp.exit()'" },
        { name: "Suspend",         comment: "Sleep",           icon: "", kind: "action", exec: "systemctl suspend" },
        { name: "Reboot",          comment: "Restart",         icon: "", kind: "action", exec: "systemctl reboot" },
        { name: "Shut down",       comment: "Power off",       icon: "", kind: "action", exec: "systemctl poweroff" },
        { name: "Apollo Settings", comment: "Theme, bar, keybinds", icon: "", kind: "action", exec: "apollo-settings" },
        { name: "Wallpaper",       comment: "Pick a wallpaper", icon: "", kind: "action", panel: "wallpaper" },
        { name: "Clipboard",       comment: "Clipboard history", icon: "", kind: "action", panel: "clip" },
        { name: "System monitor",  comment: "CPU, memory, battery", icon: "", kind: "action", panel: "sysmon" },
        { name: "Window overview", comment: "All open windows", icon: "", kind: "action", panel: "overview" },
        { name: "Keybinds",        comment: "Every shortcut",  icon: "", kind: "action", panel: "keys" },
        { name: "Wi-Fi",           comment: "Networks",        icon: "", kind: "action", panel: "net" },
        { name: "Bluetooth",       comment: "Devices",         icon: "", kind: "action", panel: "bt" },
        { name: "Tailscale",       comment: "Mesh peers",      icon: "", kind: "action", panel: "tailscale" },
        { name: "Audio",           comment: "Outputs and volume", icon: "", kind: "action", panel: "audio" },
        { name: "Calendar",        comment: "Date and notifications", icon: "", kind: "action", panel: "cal" },
        { name: "Sudoku",          comment: "Apolloku",        icon: "", kind: "action", panel: "apolloku" },
        { name: "Chess",           comment: "Play the engine", icon: "", kind: "action", panel: "chess" },
        { name: "Power",           comment: "Lock, log out, shut down", icon: "", kind: "action", panel: "power" }
    ];
}

// ── Open windows ─────────────────────────────────────────────────────────
//
// Fed from Hyprland.toplevels, the same live list WindowOverview.qml uses, so
// this costs no process. A toplevel on a negative workspace id is on a
// special workspace - deliberately hidden, and listing it here would undo
// that.

function windowEntries(toplevels) {
    var out = [];
    if (!toplevels) return out;
    for (var i = 0; i < toplevels.length; i++) {
        var t = toplevels[i];
        if (!t) continue;
        if (t.workspace && t.workspace.id < 0) continue;
        var title = (t.title || "").trim();
        if (title === "") continue;
        out.push({
            name: title,
            comment: t.workspace ? "Workspace " + t.workspace.id : "Open window",
            icon: "",
            kind: "window",
            address: t.address,
            toplevel: t
        });
    }
    return out;
}

// ── One list ─────────────────────────────────────────────────────────────

// COMMAND_PREFIX lists the actions on their own, the way a command palette
// does. Without it actions still match by name, so "lock" finds Lock screen -
// the prefix is for when you want to see what there is.
var COMMAND_PREFIX = ">";

function isCommandQuery(query) {
    return !!query && query.charAt(0) === COMMAND_PREFIX;
}

// With no query the launcher is an app list, full stop. That is what opening a
// launcher is for, and with two hundred apps in the list anything appended
// after them is unreachable anyway. Windows and actions join in as soon as you
// type, where ranking decides the order rather than concatenation.
//
// Past the empty case the order here only breaks ties: Match.filter sorts by
// score and is stable, so an exact app name still beats a window whose title
// happens to contain the same word.
function sources(query, apps, windows) {
    if (isCommandQuery(query)) return actionEntries();
    if (!query) return (apps || []).slice();
    return windowEntries(windows).concat(apps || [], actionEntries());
}

// The query the sources are matched against, with the command prefix removed.
function searchTerm(query) {
    return isCommandQuery(query) ? query.substring(1).trim() : (query || "");
}

// ── Paging ───────────────────────────────────────────────────────────────
//
// The grid is paginated the way Launchpad is, and off-by-ones here are the
// kind that hide: a last page that is one short, or an empty trailing page
// when the count divides exactly, both look plausible until you count.

function pageCount(total, perPage) {
    if (!perPage || perPage < 1) return 1;
    if (!total || total < 1) return 1;
    return Math.ceil(total / perPage);
}

// The entries on one page. Never returns a short page by padding, and never
// runs off the end.
function pageSlice(entries, page, perPage) {
    if (!entries || !perPage || perPage < 1) return [];
    var start = page * perPage;
    if (start >= entries.length) return [];
    return entries.slice(start, Math.min(start + perPage, entries.length));
}

// Where an index lands once the grid is laid out, and the reverse. Keyboard
// navigation moves within the whole list, not within a page, so that pressing
// Right on the last tile of a page steps onto the next page instead of
// stopping.
function pageOf(index, perPage) {
    if (!perPage || perPage < 1) return 0;
    return Math.floor(Math.max(0, index) / perPage);
}

// Move `index` by a whole row, clamped to the list. Returns the original index
// when the move would fall off either end, so the selection never wraps into a
// different page by surprise.
function moveByRow(index, delta, columns, total) {
    if (total < 1) return 0;
    var next = index + delta * columns;
    if (next < 0 || next >= total) return index;
    return next;
}
