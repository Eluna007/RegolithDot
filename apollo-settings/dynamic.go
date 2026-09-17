package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// Dynamic colours — the wallpaper drives the whole rice.
//
// The chain, in order, all of it inside one wallpaper-switch.sh run:
//
//	wallpaper-switch.sh   applies the image
//	matugen               extracts a source colour and renders its templates,
//	                      among them ~/.cache/apollo/theme/source.sh
//	apollo-settings theme reads that colour and fans it out — config.json (the
//	                      shell), kitty, GTK 3/4, rofi, and the staged copy the
//	                      login screen is synced from
//
// Only the *hue* is taken from the wallpaper. Each palette slot keeps the
// Catppuccin flavour's own lightness (tintedPalette, palette.go), which is what
// guarantees the result is readable rather than low-contrast mud — and the
// flavour's accent family (red, green, yellow…) is never touched, because a
// terminal whose red, green and yellow are all one wallpaper hue cannot show a
// diff. The accent family is the one thing dynamic colours deliberately leave
// alone.
//
// This replaces a wallust integration that could never have worked: it read the
// current wallpaper from ~/.cache/wallpaper-current, a file nothing in Apollo
// has ever written, so it returned false before doing anything and the Dynamic
// colors toggle silently did nothing. matugen is already a hard dependency and
// already runs on every wallpaper change, so using it here means one extractor
// for the whole rice — the lock screen and the shell cannot disagree about what
// colour the wallpaper is, because they are handed the same number.

func cacheHome() string {
	if x := os.Getenv("XDG_CACHE_HOME"); x != "" {
		return x
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".cache")
}

// stagedSourcePath is where matugen leaves the colour it pulled out of the
// current wallpaper. Staged in the cache rather than written into place because
// matugen renders unconditionally while the fan-out is a user setting.
func stagedSourcePath() string {
	return filepath.Join(cacheHome(), "apollo", "theme", "source.sh")
}

var sourceColorRe = regexp.MustCompile(`APOLLO_SOURCE="(#[0-9a-fA-F]{6})"`)

// stagedSource returns the wallpaper's source colour as "#rrggbb".
func stagedSource() (string, error) {
	data, err := os.ReadFile(stagedSourcePath())
	if err != nil {
		return "", fmt.Errorf("no wallpaper palette staged yet at %s — set a wallpaper (SUPER+W) to generate one", stagedSourcePath())
	}
	m := sourceColorRe.FindStringSubmatch(string(data))
	if m == nil {
		return "", fmt.Errorf("%s does not name a colour", stagedSourcePath())
	}
	return strings.ToLower(m[1]), nil
}

// withDynamicColors returns cfg recoloured from source. Pure: no I/O, so the
// mapping from one wallpaper colour to a whole config is testable on its own.
func withDynamicColors(cfg Config, source string) Config {
	cfg.Accent = source
	cfg.RofiAccent = source
	if cfg.DynamicMode == "full" {
		hue, _, _ := rgbToHSL(hexToColor(source))
		cfg.Palette = tintedPalette(cfg.Flavor, hue)
	} else {
		// Accent-only: clear any previous full palette so the shell reverts to
		// the plain flavour ramp instead of keeping the last wallpaper's.
		cfg.Palette = map[string]string{}
	}
	return cfg
}

// applyDynamicColors is `apollo-settings theme`. Returns whether it changed
// anything, so the caller can tell "switched off" from "failed".
func applyDynamicColors() (bool, error) {
	cfg := loadConfig()
	if !cfg.DynamicColors {
		return false, nil
	}
	source, err := stagedSource()
	if err != nil {
		return false, err
	}
	cfg = withDynamicColors(cfg, source)

	// writeConfig fans out to kitty and GTK on its way (see applyApps); rofi
	// has its own file. No backup: this runs on every wallpaper change.
	if err := writeConfig(cfg, false); err != nil {
		return false, err
	}
	if err := applyRofi(cfg); err != nil {
		return false, err
	}
	return true, stageLoginColors(cfg)
}
