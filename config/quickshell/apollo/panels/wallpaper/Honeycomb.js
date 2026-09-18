.pragma library

// Laying out a honeycomb so it fills the screen.
//
// Ported from ujjalsigdel/hyprquickpaper's shell-hexcomb.qml. It is here as a
// library rather than inline in the QML because it is arithmetic with real
// edge cases — no tiles, fewer tiles than columns, a last row that does or does
// not reach an offset column — and arithmetic can be tested. The rest of that
// layout is bindings that cannot.
//
// The tiles are flat-top regular hexagons. Two things about them drive
// everything here:
//
//   * A flat-top hexagon is wider than it is tall: height = width × √3/2.
//   * Columns interlock, so each one starts only 75% of a tile further along
//     than the last, and every odd column is pushed down half a row to sit in
//     the notch.
//
// That 75% is why the width of a grid is not `columns × colStep`: the last
// column's tile still sticks out its full width, and a naive guess clips it.

var RATIO = Math.sqrt(3) / 2;   // 0.866…, the flat-top hexagon's aspect

// dimsFor — the exact footprint of `count` tiles over `cols` columns.
function dimsFor(cardW, cardH, colStep, rowStep, cols, count) {
    if (count <= 0 || cols <= 0)
        return { width: 0, height: 0 };

    // Fewer tiles than columns: the grid is only as wide as it needs to be.
    var maxCol = Math.min(cols, count) - 1;
    var width = maxCol * colStep + cardW;

    var rows = Math.ceil(count / cols);
    var lastRowCount = count - (rows - 1) * cols;
    // Column index 1 is the first offset one, so a last row that reaches it
    // hangs half a row lower than the rest.
    var lastRowHasOdd = lastRowCount > 1;
    var height = (rows - 1) * rowStep + (lastRowHasOdd ? rowStep / 2 : 0) + cardH;

    return { width: width, height: height };
}

// computeLayout — how many columns, and at what scale, fills `w`×`h` best.
//
// Fewer columns is taller and narrower, more is shorter and wider. Every count
// from three upwards is tried and the one that can be drawn largest wins.
function computeLayout(w, h, count, base) {
    var colStep = base.cardW * 0.75 + base.hSpacing;
    var rowStep = base.cardH + base.vSpacing;

    // Stating the degenerate case rather than leaving it to fall out: with no
    // tiles or no screen the loop below would reach the same answer through
    // its own fallback, so this is belt and braces, and no test can tell the
    // difference. It is here because "what happens before the panel has
    // geometry" is a question worth answering where it is asked.
    if (count <= 0 || w <= 0 || h <= 0)
        return { columns: 3, scale: 1.0 };

    var widest = Math.max(3, Math.floor(w / colStep));
    var bestColumns = widest;
    var bestScale = 1.0;
    var found = false;

    for (var c = 3; c <= widest; c++) {
        var d = dimsFor(base.cardW, base.cardH, colStep, rowStep, c, count);
        if (d.width <= 0 || d.height <= 0)
            continue;
        var scale = Math.min(w / d.width, h / d.height);

        // Only arrangements that fit at full size or larger are candidates:
        // below 1.0 the tiles would be smaller than their base size, which is
        // already the minimum worth showing.
        if (scale >= 1.0) {
            var capped = Math.min(scale, base.maxScale);
            if (!found || capped > bestScale) {
                found = true;
                bestScale = capped;
                bestColumns = c;
            }
        }
    }

    // Nothing fits even at minimum size — too many wallpapers for the screen.
    // Stay at minimum and let the grid scroll rather than shrinking the tiles
    // into illegibility.
    if (!found)
        return { columns: widest, scale: 1.0 };

    return { columns: bestColumns, scale: bestScale };
}

// Where tile `i` sits, in the grid's own coordinates.
function tilePos(i, cols, colStep, rowStep) {
    var col = i % cols;
    var row = Math.floor(i / cols);
    return {
        x: col * colStep,
        // Odd columns drop half a row into the notch between their neighbours.
        y: row * rowStep + (col % 2 === 1 ? rowStep / 2 : 0)
    };
}
