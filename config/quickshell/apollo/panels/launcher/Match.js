.pragma library

// Fuzzy matching for the launcher. Pure functions over strings and plain
// objects, so scripts/test-launcher.js can exercise the ranking under node -
// ranking is the whole product here, and "it felt right when I tried it" is
// not something a future change can be checked against.

// Score a candidate against a query. Higher is better; -1 means no match.
//
// The query must appear as a subsequence of the target, which is what makes
// "gimp" find "GNU Image Manipulation Program" only if the letters are in
// order. Everything else is about which of several matches a person meant.
function score(query, target) {
    if (!query) return 0;
    if (!target) return -1;

    var q = query.toLowerCase();
    var t = target.toLowerCase();

    // An exact name, or a clean prefix, always wins. Typing "ma" should offer
    // Mail before Immature Manuscript Editor, whatever the letters do.
    if (t === q) return 10000;
    if (t.indexOf(q) === 0) return 9000 - t.length;

    // A match at a word boundary beats one buried mid-word.
    var wordStart = t.indexOf(" " + q);
    if (wordStart !== -1) return 8000 - t.length;

    // Initials: "vsc" for "Visual Studio Code".
    var initials = "";
    for (var w = 0; w < t.length; w++) {
        if (w === 0 || t.charAt(w - 1) === " " || t.charAt(w - 1) === "-") {
            initials += t.charAt(w);
        }
    }
    if (initials.indexOf(q) === 0) return 7000 - t.length;

    // Plain substring.
    var at = t.indexOf(q);
    if (at !== -1) return 6000 - at * 10 - t.length;

    // Subsequence, scored by how tightly packed the letters are. A run of
    // consecutive hits is worth far more than the same letters scattered.
    var ti = 0, hits = 0, run = 0, packed = 0, firstHit = -1;
    for (var qi = 0; qi < q.length; qi++) {
        var found = -1;
        for (var k = ti; k < t.length; k++) {
            if (t.charAt(k) === q.charAt(qi)) { found = k; break; }
        }
        if (found === -1) return -1;
        if (firstHit === -1) firstHit = found;
        if (found === ti && qi > 0) { run++; packed += run * 2; }
        else { run = 0; }
        // A letter landing at the start of a word is a strong signal.
        if (found === 0 || t.charAt(found - 1) === " " || t.charAt(found - 1) === "-") packed += 3;
        hits++;
        ti = found + 1;
    }
    if (hits !== q.length) return -1;
    return 1000 + packed * 10 - firstHit - t.length;
}

// Best score across the name and the comment. The comment is worth much less:
// it is there so "browser" finds Firefox, not so a long description can
// outrank an app whose name you typed exactly.
function scoreEntry(query, entry) {
    if (!query) return 0;
    var byName = score(query, entry.name);
    if (byName >= 0) return byName;
    var byComment = score(query, entry.comment || "");
    return byComment < 0 ? -1 : Math.floor(byComment / 4);
}

// Filter and rank. With no query the list is returned in its original order,
// which apps.sh has already sorted alphabetically.
function filter(query, entries) {
    if (!query) return entries.slice();

    var scored = [];
    for (var i = 0; i < entries.length; i++) {
        var s = scoreEntry(query, entries[i]);
        if (s < 0) continue;
        scored.push({ entry: entries[i], score: s, index: i });
    }
    scored.sort(function (a, b) {
        if (b.score !== a.score) return b.score - a.score;
        return a.index - b.index;          // stable: keeps alphabetical order
    });
    var out = [];
    for (var j = 0; j < scored.length; j++) out.push(scored[j].entry);
    return out;
}

// Parse one line of apps.sh output.
function parseLine(line) {
    if (!line) return null;
    var parts = line.split("\t");
    if (parts.length < 2) return null;
    var name = parts[0].trim();
    var exec = parts[1].trim();
    if (name === "" || exec === "") return null;
    return {
        name: name,
        exec: exec,
        icon: (parts[2] || "").trim(),
        comment: (parts[3] || "").trim()
    };
}

// The first letter, for the tile drawn when an app has no icon.
function initial(name) {
    if (!name) return "?";
    var c = name.charAt(0).toUpperCase();
    return /[A-Z0-9]/.test(c) ? c : "?";
}
