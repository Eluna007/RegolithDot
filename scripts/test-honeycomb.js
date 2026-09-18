// The honeycomb fit search. Pure arithmetic, so it runs under node.
//
// Run: node scripts/test-honeycomb.js
const fs = require("fs");
const path = require("path");

const src = fs.readFileSync(
    path.join(__dirname, "../config/quickshell/apollo/panels/wallpaper/Honeycomb.js"),
    "utf8").replace(/^\.pragma library\s*/, "");
const H = {};
new Function("exports", src + "\nexports.dimsFor = dimsFor;"
    + "\nexports.computeLayout = computeLayout;"
    + "\nexports.tilePos = tilePos;\nexports.RATIO = RATIO;")(H);

let fails = 0;
function ok(label) { console.log("  ok   " + label); }
function fail(label, detail) {
    console.log("  FAIL " + label + (detail ? ": " + detail : ""));
    fails++;
}
function eq(label, got, want, tol) {
    if (Math.abs(got - want) <= (tol === undefined ? 1e-9 : tol)) ok(label);
    else fail(label, got + " != " + want);
}

const base = { cardW: 220, cardH: 220 * H.RATIO, hSpacing: 6, vSpacing: 6, maxScale: 2.5 };
const colStep = base.cardW * 0.75 + base.hSpacing;
const rowStep = base.cardH + base.vSpacing;

// The whole reason width is not columns × colStep: interlocking columns
// advance by 75% of a tile, but the last one still occupies its full width.
// Guessing 4 × colStep here under-measures by 55px and clips the right edge.
eq("four columns are three steps plus a whole tile",
   H.dimsFor(base.cardW, base.cardH, colStep, rowStep, 4, 8).width,
   3 * colStep + base.cardW);

// Fewer tiles than columns: the grid is as wide as the tiles, not the columns.
eq("two tiles in a five-column grid are two tiles wide",
   H.dimsFor(base.cardW, base.cardH, colStep, rowStep, 5, 2).width,
   colStep + base.cardW);

// A last row reaching an offset column hangs half a row lower.
const flush = H.dimsFor(base.cardW, base.cardH, colStep, rowStep, 3, 4);   // last row: 1 tile
const hangs = H.dimsFor(base.cardW, base.cardH, colStep, rowStep, 3, 5);   // last row: 2 tiles
eq("a last row that reaches column 1 is half a row taller",
   hangs.height - flush.height, rowStep / 2);

// Nothing at all has no footprint, rather than a negative one.
const none = H.dimsFor(base.cardW, base.cardH, colStep, rowStep, 3, 0);
if (none.width === 0 && none.height === 0) ok("an empty folder has no footprint");
else fail("an empty folder measured", JSON.stringify(none));

// An empty folder, or a screen with no size yet, must not divide by zero or
// return a scale of Infinity — this runs before the panel has geometry.
const degenerate = [
    H.computeLayout(0, 0, 0, base),
    H.computeLayout(1920, 1080, 0, base),
    H.computeLayout(0, 1080, 10, base),
];
let degenerateOk = true;
for (const r of degenerate) {
    if (!isFinite(r.scale) || r.scale <= 0 || r.columns < 3) degenerateOk = false;
}
if (degenerateOk) ok("no size and no tiles still give a usable answer");
else fail("a degenerate case produced", JSON.stringify(degenerate));

// The search should pick an arrangement that actually fits.
const r = H.computeLayout(1920, 1080, 24, base);
const d = H.dimsFor(base.cardW * r.scale, base.cardH * r.scale,
                    (base.cardW * r.scale) * 0.75 + base.hSpacing * r.scale,
                    base.cardH * r.scale + base.vSpacing * r.scale,
                    r.columns, 24);
if (d.width <= 1920 + 0.5 && d.height <= 1080 + 0.5)
    ok("24 wallpapers on 1920x1080 fit the screen at the chosen scale");
else
    fail("the chosen layout overflows", JSON.stringify({ r: r, d: d }));

// Never blown up past the cap, however few tiles there are.
const big = H.computeLayout(3840, 2160, 3, base);
if (big.scale <= base.maxScale + 1e-9) ok("scale is capped");
else fail("scale exceeded the cap", big.scale);

// Too many wallpapers to fit at minimum size: stay at 1.0 and scroll rather
// than shrinking the tiles into illegibility.
const many = H.computeLayout(1280, 720, 400, base);
eq("an unfittable count stays at minimum size", many.scale, 1.0);

// Odd columns sit in the notch between their neighbours.
const p0 = H.tilePos(0, 3, colStep, rowStep);
const p1 = H.tilePos(1, 3, colStep, rowStep);
const p3 = H.tilePos(3, 3, colStep, rowStep);
eq("column 0 starts at the top", p0.y, 0);
eq("column 1 drops half a row", p1.y, rowStep / 2);
eq("column 1 is three quarters of a tile along", p1.x, colStep);
eq("the second row is a whole row down", p3.y, rowStep);

if (fails > 0) {
    console.log("\n" + fails + " failure(s)");
    process.exit(1);
}
console.log("\nok - honeycomb layout");
