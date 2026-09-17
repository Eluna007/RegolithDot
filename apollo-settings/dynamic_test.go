package main

import (
	"math"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func hueOf(t *testing.T, hex string) float64 {
	t.Helper()
	h, _, _ := rgbToHSL(hexToColor(hex))
	return h
}

// hueGap is the angle between two hues, the short way round the circle: 359°
// and 1° are two degrees apart, not 358.
func hueGap(a, b float64) float64 {
	d := math.Abs(a - b)
	if d > 180 {
		d = 360 - d
	}
	return d
}

func lightnessOf(t *testing.T, hex string) float64 {
	t.Helper()
	_, _, l := rgbToHSL(hexToColor(hex))
	return l
}

// Accent-only mode must clear any palette a previous "full" run left behind —
// otherwise turning the mode down leaves the shell on the last wallpaper's
// surfaces forever, with no control that looks like it would fix it.
func TestAccentOnlyClearsThePalette(t *testing.T) {
	cfg := defaultConfig()
	cfg.DynamicMode = "accent"
	cfg.Palette = map[string]string{"base": "#123456"}

	got := withDynamicColors(cfg, "#89b4fa")
	if len(got.Palette) != 0 {
		t.Errorf("accent-only kept a palette: %v", got.Palette)
	}
	if got.Accent != "#89b4fa" {
		t.Errorf("accent = %s, want #89b4fa", got.Accent)
	}
	if got.RofiAccent != "#89b4fa" {
		t.Errorf("rofi accent = %s, want #89b4fa", got.RofiAccent)
	}
}

// Full mode re-tints the neutrals toward the wallpaper — and nothing else.
// The accent family has to survive, because a terminal whose red, green and
// yellow are all one hue cannot show a diff. This is the same guarantee
// apps_test.go makes of effectivePalette, asserted one layer earlier.
func TestFullModeTintsNeutralsOnly(t *testing.T) {
	cfg := defaultConfig()
	cfg.Flavor = "mocha"
	cfg.DynamicMode = "full"

	const source = "#a6e3a1" // a green wallpaper
	got := withDynamicColors(cfg, source)

	for _, slot := range []string{"base", "mantle", "crust", "surface0", "text"} {
		if got.Palette[slot] == "" {
			t.Fatalf("full mode left %s empty", slot)
		}
		// 4°, not 0: the ramp round-trips through 8-bit RGB, and hue
		// resolution is coarsest exactly where this palette spends most of
		// its slots — the near-black, barely-saturated surfaces. Measured
		// worst case across five source colours is 2.2°, on crust. An
		// untinted slot would be out by tens of degrees, so this still fails
		// for the thing it is watching for.
		if d := hueGap(hueOf(t, got.Palette[slot]), hueOf(t, source)); d > 4 {
			t.Errorf("%s hue %.0f is not the wallpaper's %.0f",
				slot, hueOf(t, got.Palette[slot]), hueOf(t, source))
		}
	}
	for _, slot := range []string{"red", "green", "blue", "yellow", "mauve"} {
		if got.Palette[slot] != "" {
			t.Errorf("full mode wrote the accent %s (%s); it must stay the flavour's",
				slot, got.Palette[slot])
		}
	}
}

// The readability guarantee: only the hue moves. If a tint ever changed a
// slot's lightness, text could land on a surface of its own brightness and the
// whole rice would go unreadable for one unlucky wallpaper.
func TestTintPreservesEachSlotsLightness(t *testing.T) {
	cfg := defaultConfig()
	cfg.Flavor = "mocha"
	cfg.DynamicMode = "full"
	got := withDynamicColors(cfg, "#f38ba8")

	for slot, original := range flavorRamps["mocha"] {
		want := lightnessOf(t, original)
		have := lightnessOf(t, got.Palette[slot])
		if math.Abs(want-have) > 0.01 {
			t.Errorf("%s: lightness %.3f became %.3f", slot, want, have)
		}
	}
}

// The login screen draws its own text on the accent, so the accent cannot be
// assumed dark or light — the wallpaper decides.
func TestReadableOnPicksContrast(t *testing.T) {
	p := flavorRamps["mocha"]
	if got := readableOn("#f9e2af", p); got != p["crust"] { // light accent
		t.Errorf("on a light accent got %s, want crust %s", got, p["crust"])
	}
	if got := readableOn("#1e1e2e", p); got != p["text"] { // dark accent
		t.Errorf("on a dark accent got %s, want text %s", got, p["text"])
	}
}

// Every key Main.qml reads has to be in the block, spelled the same. An SDDM
// theme asking for a key theme.conf does not define gets an empty string, and
// an empty colour draws as black — on a login screen, that is a black
// rectangle with nothing on it and no way to find out why.
func TestLoginColorsCoverEveryKeyTheThemeReads(t *testing.T) {
	out := renderLoginColors(defaultConfig())
	have := map[string]bool{}
	for _, line := range strings.Split(out, "\n") {
		if k, _, ok := strings.Cut(line, "="); ok && !strings.HasPrefix(line, "#") {
			have[k] = true
		}
	}
	for _, key := range []string{"base", "mantle", "crust", "surface0", "surface1",
		"overlay1", "subtext0", "text", "accent", "onAccent", "error"} {
		if !have[key] {
			t.Errorf("theme.conf is missing %s", key)
		}
	}
	if strings.Contains(out, "=\n") {
		t.Error("theme.conf has an empty value; an empty colour draws as black")
	}
}

func TestStagedSourceParsing(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", dir)
	path := stagedSourcePath()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}

	if _, err := stagedSource(); err == nil {
		t.Error("a missing staged file should be an error, not an empty colour")
	}

	os.WriteFile(path, []byte("# a comment\nAPOLLO_SOURCE=\"#CBA6F7\"\n"), 0o644)
	got, err := stagedSource()
	if err != nil {
		t.Fatal(err)
	}
	if got != "#cba6f7" {
		t.Errorf("got %q, want #cba6f7", got)
	}

	os.WriteFile(path, []byte("APOLLO_SOURCE=\"\"\n"), 0o644)
	if _, err := stagedSource(); err == nil {
		t.Error("an empty colour should be an error; it would paint the shell black")
	}
}

// The switches were renamed from wallustEnabled/wallustMode. An existing
// config.json must not silently lose the setting — the symptom would be a rice
// that quietly stops following the wallpaper after an update.
func TestLegacyWallustKeysMigrate(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	dir := filepath.Join(home, ".config", "apollo")
	os.MkdirAll(dir, 0o755)
	write := func(body string) {
		if err := os.WriteFile(filepath.Join(dir, "config.json"), []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	write(`{"wallustEnabled": true, "wallustMode": "full"}`)
	c := loadConfig()
	if !c.DynamicColors || c.DynamicMode != "full" {
		t.Errorf("old keys did not carry over: enabled=%v mode=%q", c.DynamicColors, c.DynamicMode)
	}

	// Once the new key is present it is the answer, even when it disagrees.
	write(`{"wallustEnabled": true, "dynamicColors": false, "dynamicMode": "accent"}`)
	if c := loadConfig(); c.DynamicColors {
		t.Error("the old key overrode the new one")
	}
}

// The login screen must get a palette even with dynamic colours off. That
// switch decides where the colours come from, not who receives them — and
// gating the staging on it meant apollo-sddm-sync had nothing to install
// until you had turned dynamic colours on, which is not a relationship
// anything in the UI suggests.
func TestLoginColorsAreStagedWithDynamicColorsOff(t *testing.T) {
	home := t.TempDir()
	cache := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CACHE_HOME", cache)
	if err := os.MkdirAll(filepath.Join(home, ".config", "apollo"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, ".config", "apollo", "config.json"),
		[]byte(`{"dynamicColors": false, "flavor": "latte", "accent": "#8839ef"}`), 0o644); err != nil {
		t.Fatal(err)
	}

	changed, err := applyDynamicColors()
	if err != nil {
		t.Fatal(err)
	}
	if changed {
		t.Error("reported a change with dynamic colours off")
	}

	body, err := os.ReadFile(stagedLoginColorsPath())
	if err != nil {
		t.Fatalf("nothing staged for the login screen: %v", err)
	}
	// Latte's own ramp, not Mocha's: the flavour picked by hand is the answer
	// when the wallpaper is not.
	if !strings.Contains(string(body), "base=#eff1f5") {
		t.Errorf("staged the wrong flavour's palette:\n%s", body)
	}
	if !strings.Contains(string(body), "accent=#8839ef") {
		t.Errorf("staged palette lost the accent:\n%s", body)
	}
}

// Nothing staged, but the session has a wallpaper on record: the colour must
// be extracted rather than refused. "Set a wallpaper to generate one" is what
// you get told *after* setting a wallpaper, if anything in that chain went
// wrong, and it names no way to find out what.
func TestStagedSourceIsExtractedOnDemand(t *testing.T) {
	home := t.TempDir()
	cache := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CACHE_HOME", cache)

	// A stub matugen on PATH, writing what the real one's template renders.
	bin := filepath.Join(home, "bin")
	if err := os.MkdirAll(bin, 0o755); err != nil {
		t.Fatal(err)
	}
	script := "#!/bin/sh\nmkdir -p " + filepath.Dir(stagedSourcePath()) +
		"\nprintf 'APOLLO_SOURCE=\"#a6e3a1\"\\n' > " + stagedSourcePath() + "\n"
	if err := os.WriteFile(filepath.Join(bin, "matugen"), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+":"+os.Getenv("PATH"))

	wall := filepath.Join(home, "moon.png")
	if err := os.WriteFile(wall, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	hypr := filepath.Join(home, ".config", "hypr")
	os.MkdirAll(hypr, 0o755)
	if err := os.WriteFile(filepath.Join(hypr, "last-wallpaper.txt"),
		[]byte(wall+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	got, err := ensureStagedSource()
	if err != nil {
		t.Fatalf("did not extract a colour: %v", err)
	}
	if got != "#a6e3a1" {
		t.Errorf("got %q, want #a6e3a1", got)
	}

	// And through the path the failure was actually reported from: ticking
	// "Follow the wallpaper" in the settings app, which is applyDynamicColors.
	// Testing ensureStagedSource alone leaves that call site free to go on
	// refusing, which is the whole bug.
	os.Remove(stagedSourcePath())
	os.MkdirAll(filepath.Join(home, ".config", "apollo"), 0o755)
	if err := os.WriteFile(filepath.Join(home, ".config", "apollo", "config.json"),
		[]byte(`{"dynamicColors": true, "dynamicMode": "full", "flavor": "mocha"}`), 0o644); err != nil {
		t.Fatal(err)
	}

	changed, err := applyDynamicColors()
	if err != nil {
		t.Fatalf("applyDynamicColors refused instead of extracting: %v", err)
	}
	if !changed {
		t.Fatal("applyDynamicColors reported no change")
	}
	if c := loadConfig(); c.Accent != "#a6e3a1" {
		t.Errorf("accent = %s, want the extracted #a6e3a1", c.Accent)
	}
}

// A video wallpaper cannot be handed to matugen, and the error has to say so
// — otherwise it reads as "matugen is broken" rather than "this one needs a
// frame pulling out of it first, which a wallpaper change does".
func TestVideoWallpaperWithNoFrameIsExplained(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CACHE_HOME", t.TempDir())

	wall := filepath.Join(home, "clip.mp4")
	os.WriteFile(wall, []byte("x"), 0o644)
	hypr := filepath.Join(home, ".config", "hypr")
	os.MkdirAll(hypr, 0o755)
	os.WriteFile(filepath.Join(hypr, "last-wallpaper.txt"), []byte(wall+"\n"), 0o644)

	_, err := currentStill()
	if err == nil {
		t.Fatal("handed a video to matugen")
	}
	if !strings.Contains(err.Error(), "video") {
		t.Errorf("error does not mention the video: %v", err)
	}
}
