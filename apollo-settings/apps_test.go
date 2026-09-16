package main

import (
	"strings"
	"testing"
)

func kv(t *testing.T, body string) map[string]string {
	t.Helper()
	out := map[string]string{}
	for _, line := range strings.Split(body, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		f := strings.Fields(line)
		if len(f) >= 2 {
			out[f[0]] = f[1]
		}
	}
	return out
}

// Every flavor has to define the same slots, or a flavor switch leaves some
// colour rendering as the empty string — which kitty rejects at parse time,
// taking the whole colour file with it.
func TestFlavorAccentsAreComplete(t *testing.T) {
	for flavor := range flavorRamps {
		accents, ok := flavorAccents[flavor]
		if !ok {
			t.Fatalf("%s has a neutral ramp but no accent family", flavor)
		}
		for _, want := range []string{"rosewater", "flamingo", "pink", "mauve", "red",
			"maroon", "peach", "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender"} {
			if accents[want] == "" {
				t.Errorf("%s is missing accent %q", flavor, want)
			}
		}
	}
	for flavor := range flavorAccents {
		if _, ok := flavorRamps[flavor]; !ok {
			t.Errorf("%s has accents but no neutral ramp", flavor)
		}
	}
}

func TestEffectivePaletteFollowsFlavor(t *testing.T) {
	mocha := effectivePalette(Config{Flavor: "mocha"})
	latte := effectivePalette(Config{Flavor: "latte"})
	if mocha["base"] != "#1e1e2e" || latte["base"] != "#eff1f5" {
		t.Fatalf("flavor not honoured: mocha=%s latte=%s", mocha["base"], latte["base"])
	}
	// Latte is a light flavor: its "base" must be lighter than its "text", or
	// every surface below has the contrast inverted. Compared by lightness,
	// not by hex string — "#eff1f5" > "#4c4f69" happens to sort correctly, but
	// only by accident of the leading digit.
	_, _, baseL := rgbToHSL(hexToColor(latte["base"]))
	_, _, textL := rgbToHSL(hexToColor(latte["text"]))
	if baseL <= textL {
		t.Errorf("latte base %s (L=%.2f) should be lighter than text %s (L=%.2f)",
			latte["base"], baseL, latte["text"], textL)
	}
	// An unknown flavor falls back rather than yielding empty slots.
	if effectivePalette(Config{Flavor: "nonesuch"})["base"] != mocha["base"] {
		t.Error("unknown flavor did not fall back to mocha")
	}
}

// The wallust "full palette" mode overrides neutrals only. If it ever reached
// the accents, a terminal's red and green would collapse to one hue.
func TestWallustPaletteOverridesNeutralsOnly(t *testing.T) {
	// "red" is in here deliberately: nothing writes an accent into Palette
	// today, but the loop that applies it must key off the neutral ramp, not
	// off whatever the map happens to carry, or a future wallust mode that
	// emitted accents would silently flatten the terminal's hues.
	c := Config{Flavor: "mocha", Palette: map[string]string{
		"base": "#101010", "text": "#f0f0f0", "red": "#00ff00",
	}}
	p := effectivePalette(c)
	if p["base"] != "#101010" || p["text"] != "#f0f0f0" {
		t.Errorf("custom neutrals not applied: %v", p)
	}
	if p["surface0"] != flavorRamps["mocha"]["surface0"] {
		t.Errorf("unset neutral should fall back to the flavor, got %s", p["surface0"])
	}
	if p["red"] != flavorAccents["mocha"]["red"] {
		t.Errorf("accent was overridden by the wallust palette: %s", p["red"])
	}
	// A palette of empty strings means "no custom palette", same as Config.qml.
	empty := effectivePalette(Config{Flavor: "mocha", Palette: map[string]string{"base": ""}})
	if empty["base"] != flavorRamps["mocha"]["base"] {
		t.Errorf("empty base should mean no custom palette, got %s", empty["base"])
	}
}

func TestKittyColorsAreComplete(t *testing.T) {
	got := kv(t, renderKittyColors(Config{Flavor: "mocha", Accent: "#cba6f7"}))
	for i := 0; i < 16; i++ {
		k := "color" + itoa(i)
		if got[k] == "" {
			t.Errorf("%s is undefined", k)
		}
	}
	for _, k := range []string{"background", "foreground", "cursor", "selection_background",
		"selection_foreground", "active_tab_background", "inactive_tab_background", "url_color"} {
		if got[k] == "" {
			t.Errorf("%s is undefined", k)
		}
	}
	// color0 must not be the background: black-on-black is invisible, which is
	// exactly what mapping the ANSI blacks to base/text would produce.
	if got["color0"] == got["background"] {
		t.Errorf("color0 %s equals the background", got["color0"])
	}
	if got["color7"] == got["background"] {
		t.Errorf("color7 %s equals the background", got["color7"])
	}
	// The six hues have to stay distinguishable from each other.
	seen := map[string]string{}
	for _, k := range []string{"color1", "color2", "color3", "color4", "color5", "color6"} {
		if prev, dup := seen[got[k]]; dup {
			t.Errorf("%s and %s are both %s", prev, k, got[k])
		}
		seen[got[k]] = k
	}
	if got["active_border_color"] != "#cba6f7" || got["active_tab_background"] != "#cba6f7" {
		t.Errorf("the border and active tab should follow the accent, got %s / %s",
			got["active_border_color"], got["active_tab_background"])
	}
}

// An unset or malformed accent must fall back to the flavor's own mauve, not
// to a Mocha literal — otherwise Latte gets a dark purple cursor.
func TestAccentFallsBackToTheFlavor(t *testing.T) {
	for _, bad := range []string{"", "cba6f7", "#cba", "not a colour"} {
		got := kv(t, renderKittyColors(Config{Flavor: "latte", Accent: bad}))
		if got["active_border_color"] != flavorAccents["latte"]["mauve"] {
			t.Errorf("accent %q: border %s, want latte mauve %s",
				bad, got["active_border_color"], flavorAccents["latte"]["mauve"])
		}
	}
}

func TestGtkColorsDefineEveryNameTheStylesheetUses(t *testing.T) {
	body := renderGtkColors(Config{Flavor: "mocha", Accent: "#cba6f7"})
	for _, name := range []string{"moon_bg", "moon_panel", "moon_panel_alt", "moon_line",
		"moon_text", "moon_muted", "moon_green", "moon_cyan", "moon_mauve"} {
		if !strings.Contains(body, "@define-color "+name+" ") {
			t.Errorf("%s is undefined", name)
		}
	}
	// The translucent slots keep the hand-written stylesheet's alphas.
	for _, want := range []string{"0.14", "0.24", "0.22", "0.26"} {
		if !strings.Contains(body, want+")") {
			t.Errorf("alpha %s is missing", want)
		}
	}
	if strings.Contains(body, "rgba(0, 0, 0,") {
		t.Error("a colour failed to parse and came out black")
	}
}

func TestRgbaOf(t *testing.T) {
	if got := rgbaOf("#112233", 0.5); got != "rgba(17, 34, 51, 0.50)" {
		t.Errorf("got %s", got)
	}
}

func itoa(i int) string {
	if i < 10 {
		return string(rune('0' + i))
	}
	return string(rune('0'+i/10)) + string(rune('0'+i%10))
}
