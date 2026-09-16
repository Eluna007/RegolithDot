.pragma library

// The keybind cheatsheet's data layer: `hyprctl binds -j` in, rows out.
//
// This was a rofi mode (config/rofi/scripts/keybinds.sh), and it asked the
// compositor rather than parsing the config for a reason worth keeping: binds
// are Lua function calls now, their arguments are tables, and a `for i = 1, 4`
// loop registers four binds that appear nowhere in the file as text. What
// hyprctl reports is what is actually bound.
//
// Pure functions over plain objects, so scripts/test-keys.js can exercise the
// bitfield decoding and the ordering under node. A cheatsheet that is wrong is
// worse than no cheatsheet.

// Hyprland's modmask is a bitfield: SHIFT 1, CAPS 2, CTRL 4, ALT 8, MOD2 16,
// MOD3 32, SUPER 64, MOD5 128. Listed in the order people say them out loud,
// not in bit order.
var MOD_BITS = [
    { bit: 64, name: "Super" },
    { bit: 4,  name: "Ctrl" },
    { bit: 8,  name: "Alt" },
    { bit: 1,  name: "Shift" }
];

var KEY_LABELS = {
    "comma": ",", "period": ".", "slash": "/", "minus": "-", "equal": "=",
    "bracketleft": "[", "bracketright": "]", "semicolon": ";", "grave": "`",
    "apostrophe": "'", "backslash": "\\", "space": "Space",
    "mouse:272": "Mouse Left", "mouse:273": "Mouse Right",
    "mouse:274": "Mouse Middle",
    "mouse_up": "Scroll Up", "mouse_down": "Scroll Down",
    "XF86MonBrightnessUp": "Brightness Up",
    "XF86MonBrightnessDown": "Brightness Down",
    "XF86AudioRaiseVolume": "Volume Up",
    "XF86AudioLowerVolume": "Volume Down",
    "XF86AudioMute": "Mute",
    "XF86AudioMicMute": "Mic Mute",
    "XF86SelectiveScreenshot": "Screenshot Key",
    "XF86AudioPlay": "Play/Pause",
    "XF86AudioNext": "Next Track",
    "XF86AudioPrev": "Previous Track"
};

function modNames(modmask) {
    var m = typeof modmask === "number" ? modmask : 0;
    var out = [];
    for (var i = 0; i < MOD_BITS.length; i++) {
        if (Math.floor(m / MOD_BITS[i].bit) % 2 === 1) out.push(MOD_BITS[i].name);
    }
    return out;
}

function keyLabel(key) {
    if (!key) return "";
    if (KEY_LABELS[key] !== undefined) return KEY_LABELS[key];
    // A single letter reads better capitalised; a named key already arrives in
    // the case Hyprland uses ("Escape", "Return").
    return key.length === 1 ? key.toUpperCase() : key;
}

// The modifier half on its own, which is how the rows are grouped. "What does
// Super+Shift do" is how people actually look a shortcut up, and unlike a
// guessed category ("window", "media") it is a fact about the bind.
function modLabel(bind) {
    var mods = modNames(bind ? bind.modmask : 0);
    return mods.length === 0 ? "No modifier" : mods.join(" + ");
}

function keyOf(bind) {
    if (!bind) return "";
    if (bind.key && bind.key !== "") return bind.key;
    return bind.keycode ? "code:" + bind.keycode : "";
}

function comboOf(bind) {
    var key = keyOf(bind);
    if (key === "") return "";
    return modNames(bind.modmask).concat([keyLabel(key)]).join(" + ");
}

// A bind's `description` when it set one, its dispatcher otherwise. Neither is
// guaranteed, so "?" rather than a row with an empty right-hand side.
function describe(bind) {
    if (!bind) return "?";
    if (bind.description && bind.description !== "") return bind.description;
    if (bind.dispatcher && bind.dispatcher !== "") return bind.dispatcher;
    return "?";
}

// Parse `hyprctl binds -j`. Returns [] rather than throwing on anything that
// is not the array we expect: hyprctl missing, or a version that changed its
// output, should leave an empty sheet that says so, not a panel that fails to
// open.
function parseBinds(text) {
    if (!text) return [];
    var data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return [];
    }
    if (!data || data.length === undefined || typeof data === "string") return [];

    var rows = [];
    var seen = {};
    for (var i = 0; i < data.length; i++) {
        var b = data[i];
        var combo = comboOf(b);
        if (combo === "") continue;
        var action = describe(b);
        // Hyprland reports a bind per submap and per repeat flag, so the same
        // combo arrives more than once. A cheatsheet should show it once.
        // Newline is the separator because neither half can contain one.
        var dedup = combo + "\n" + action;
        if (seen[dedup]) continue;
        seen[dedup] = true;
        rows.push({
            combo: combo,
            mods: modLabel(b),
            key: keyLabel(keyOf(b)),
            action: action
        });
    }
    return rows;
}

// Groups are ordered by how many modifiers they hold, so the plain Super block
// comes first; "No modifier" (the media keys) is last whatever it holds.
function groupWeight(mods) {
    if (mods === "No modifier") return 100;
    return mods.split(" + ").length;
}

// Natural order inside a group: 1, 2, 10 rather than 1, 10, 2. The workspace
// binds are the reason — a sheet listing 1, 10, 2, 3 looks broken.
function compareKeys(a, b) {
    var na = /^\d+$/.test(a), nb = /^\d+$/.test(b);
    if (na && nb) return parseInt(a, 10) - parseInt(b, 10);
    if (na !== nb) return na ? -1 : 1;
    return a < b ? -1 : a > b ? 1 : 0;
}

function groupRows(rows) {
    var byMods = {};
    var order = [];
    for (var i = 0; i < rows.length; i++) {
        var m = rows[i].mods;
        if (!byMods[m]) { byMods[m] = []; order.push(m); }
        byMods[m].push(rows[i]);
    }
    order.sort(function (a, b) {
        var wa = groupWeight(a), wb = groupWeight(b);
        if (wa !== wb) return wa - wb;
        return a < b ? -1 : a > b ? 1 : 0;
    });
    var out = [];
    for (var j = 0; j < order.length; j++) {
        var group = byMods[order[j]].slice();
        group.sort(function (x, y) {
            var c = compareKeys(x.key, y.key);
            return c !== 0 ? c : (x.action < y.action ? -1 : x.action > y.action ? 1 : 0);
        });
        out.push({ mods: order[j], rows: group });
    }
    return out;
}

// Plain case-insensitive substring over both halves. Deliberately not the
// launcher's fuzzy ranking: looking up a shortcut you half-remember wants
// every row containing what you typed, in the order the sheet already has,
// rather than a re-ranked list that moves under the cursor.
function filterRows(query, rows) {
    var q = (query || "").toLowerCase().trim();
    if (q === "") return rows.slice();
    var out = [];
    for (var i = 0; i < rows.length; i++) {
        var r = rows[i];
        if (r.combo.toLowerCase().indexOf(q) !== -1 ||
            r.action.toLowerCase().indexOf(q) !== -1) out.push(r);
    }
    return out;
}

// The pieces of a combo, so each one can be drawn as its own key cap.
function caps(combo) {
    return (combo || "").split(" + ");
}

// How many rows a grouping holds, for the "N shortcuts" count in the header.
function countRows(groups) {
    var n = 0;
    for (var i = 0; i < groups.length; i++) n += groups[i].rows.length;
    return n;
}
