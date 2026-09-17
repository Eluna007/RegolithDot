package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"time"
)

// HyprSettings are the "hard" knobs — they need `hyprctl reload` and can, in
// principle, change how the whole WM feels. Bounded to safe ranges by the UI.
type HyprSettings struct {
	Rounding        int     `json:"rounding"`        // 0 = sharp edges … 20 = very round
	ActiveOpacity   float64 `json:"activeOpacity"`   // 0.5 … 1.0
	InactiveOpacity float64 `json:"inactiveOpacity"` // 0.5 … 1.0
	GapsIn          int     `json:"gapsIn"`          // 0 … 30
	GapsOut         int     `json:"gapsOut"`         // 0 … 40
	BorderSize      int     `json:"borderSize"`      // 0 … 6
	BorderOverride  bool    `json:"borderOverride"`  // off = keep the base gradient border
	BorderActive    string  `json:"borderActive"`    // hex, used only when BorderOverride
	BorderInactive  string  `json:"borderInactive"`  // hex, used only when BorderOverride
	BlurEnabled     bool    `json:"blurEnabled"`
	BlurSize        int     `json:"blurSize"` // 0 … 12
	ShadowEnabled   bool    `json:"shadowEnabled"`
	AnimEnabled     bool    `json:"animEnabled"`
}

// Keybind is one rebindable action. Combo is "MODS, KEY" — the app's own UI
// form, which the keybind editor parses; hypr.go translates it to Hyprland's
// "MODS + KEY" when generating Lua. Dispatcher is the fixed action, written as
// a Lua dispatch expression and emitted verbatim. Default lets us unbind the
// original before binding the new combo, so overrides stay clean.
type Keybind struct {
	Combo      string `json:"combo"`
	Default    string `json:"-"`
	Dispatcher string `json:"-"`
	Label      string `json:"-"`
}

// Config is the app's full state. The shell reads `accent` and `barStyle`
// live; `hyprland` and `keybinds` are rendered into ~/.config/hypr/lua/generated.lua
// only when the user hits Apply.
type Config struct {
	Accent          string  `json:"accent"`
	ArchLogoColor   string  `json:"archLogoColor"` // bar's Arch logo — independent of accent
	Flavor          string  `json:"flavor"`        // mocha | macchiato | frappe | latte
	BarStyle        string  `json:"barStyle"`      // "islands" | "classic"
	BarPosition     string  `json:"barPosition"`   // "top" | "left" | "right"
	BarOpacity      float64 `json:"barOpacity"`
	Clock24h        bool    `json:"clock24h"`
	ShowUpdates     bool    `json:"showUpdates"`
	ShowTemp        bool    `json:"showTemp"`
	ShowBattery     bool    `json:"showBattery"`
	ShowRecording   bool    `json:"showRecording"`
	ShowDesktop     bool    `json:"showDesktop"`     // clock on the wallpaper, under the windows
	ShowNetworkName bool    `json:"showNetworkName"` // SSID next to the wifi icon

	// Set by hand (README, "Chess"), not by this app — but it has to exist
	// here all the same. saveConfig marshals this struct, so a key with no
	// field is dropped on the next save: set a chess handle, change any
	// setting, lose the handle.
	ChessUsername  string `json:"chessUsername"`
	ToastDuration  int    `json:"toastDuration"`  // ms, 1000-10000
	MaxToasts      int    `json:"maxToasts"`      // 1-10
	ToastPosition  string `json:"toastPosition"`  // "auto" | "top-right" | ...
	WallpaperDir   string `json:"wallpaperDir"`   // path, default ~/Pictures/Wallpapers
	PowerProfile   string `json:"powerProfile"`   // powersave | schedutil | performance
	PowerPersist   bool   `json:"powerPersist"`   // enable systemd service for reboot survival
	// Dynamic colours: derive the palette from the current wallpaper. The
	// engine is matugen, which already runs on every wallpaper change for the
	// lock screen — see dynamic.go. These were wallustEnabled/wallustMode; the
	// old keys are still read once, in loadConfig, so an existing config.json
	// keeps its setting.
	DynamicColors bool   `json:"dynamicColors"`
	DynamicMode   string `json:"dynamicMode"` // "accent" (accent only) | "full" (accent + tinted palette)
	RofiAccent    string `json:"rofiAccent"`  // rofi prompt icon + selected-item border
	// Palette is a neutral ramp (base…text) derived from the wallpaper.
	// Populated only in "full" dynamic mode; empty means the shell falls back
	// to the Flavor ramp. Keys mirror services/Config.qml (base, mantle,
	// crust, surface0-2, overlay0-2, subtext0-1, text).
	Palette  map[string]string  `json:"palette"`
	Hypr     HyprSettings       `json:"hyprland"`
	Keybinds map[string]Keybind `json:"keybinds"`
}

// curatedKeybinds is the safe, fixed set the app is willing to rebind. The
// dispatcher/label/default never change; only the user's combo does.
// curatedKeybinds MUST mirror lua/keybinds.lua. `Default` is the combo this
// app unbinds before applying a new one, so a Default that does not match the
// live config unbinds a key someone is actually using: these were Moonlit's
// (SUPER+Q terminal, SUPER+W close), and against Apollo's keybinds that meant
// editing the terminal bind silently deleted the SUPER+W wallpaper picker.
//
// If you rebind any of these five in lua/keybinds.lua, change them here too.
func curatedKeybinds() map[string]Keybind {
	return map[string]Keybind{
		"terminal":   {Label: "Terminal", Default: "SUPER, Return", Combo: "SUPER, Return", Dispatcher: `hl.dsp.exec_cmd("kitty")`},
		"launcher":   {Label: "App launcher", Default: "SUPER, Space", Combo: "SUPER, Space", Dispatcher: `hl.dsp.exec_cmd("qs -c apollo ipc call panel toggle launcher")`},
		"close":      {Label: "Close window", Default: "SUPER, Q", Combo: "SUPER, Q", Dispatcher: "hl.dsp.window.close()"},
		"fullscreen": {Label: "Fullscreen", Default: "SUPER, F", Combo: "SUPER, F", Dispatcher: `hl.dsp.window.fullscreen({ mode = "fullscreen" })`},
		"float":      {Label: "Toggle floating", Default: "SUPER, V", Combo: "SUPER, V", Dispatcher: "hl.dsp.window.float()"},
	}
}

func defaultConfig() Config {
	return Config{
		Accent:          "#cba6f7", // moonlight mauve
		ArchLogoColor:   "#eba0ac", // Catppuccin maroon (rose/red)
		RofiAccent:      "#f38ba8", // Catppuccin pink — matches the theme's current default
		Flavor:          "mocha",
		BarStyle:        "islands",
		BarPosition:     "top",
		BarOpacity:      0.72,
		Clock24h:        true,
		ShowUpdates:     true,
		ShowTemp:        true,
		ShowBattery:     true,
		ShowRecording:   true,
		ShowDesktop:     true,
		ShowNetworkName: true,
		ToastDuration:   4200,
		MaxToasts:       5,
		ToastPosition:   "auto",
		WallpaperDir:    "~/Pictures/Wallpapers",
		PowerProfile:    "schedutil",
		PowerPersist:    false,
		DynamicColors:   false,
		DynamicMode:     "accent",
		Palette:         map[string]string{},
		Hypr: HyprSettings{
			Rounding: 10, ActiveOpacity: 1.0, InactiveOpacity: 0.92,
			GapsIn: 3, GapsOut: 8, BorderSize: 2,
			BorderOverride: false, BorderActive: "#cba6f7", BorderInactive: "#45475a",
			BlurEnabled: true, BlurSize: 4, ShadowEnabled: true, AnimEnabled: true,
		},
		Keybinds: curatedKeybinds(),
	}
}

func configPath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "apollo", "config.json")
}

// isFirstRun is true until the config file exists — writing it (the wizard's
// "Get Started") is what ends the first-run state, so no separate flag file is
// needed.
func isFirstRun() bool {
	_, err := os.Stat(configPath())
	return os.IsNotExist(err)
}

// mergeKeybinds re-attaches the curated, non-persisted keybind metadata
// (label/dispatcher/default — all `json:"-"`) to whatever combos were loaded
// from JSON, whether from config.json or an imported file.
func mergeKeybinds(saved map[string]Keybind) map[string]Keybind {
	merged := curatedKeybinds()
	for id, def := range merged {
		if s, ok := saved[id]; ok && s.Combo != "" {
			def.Combo = s.Combo
		}
		merged[id] = def
	}
	return merged
}

// loadConfig merges the saved file over defaults, so new fields always have
// sane values and the curated keybind metadata (label/dispatcher) is restored.
func loadConfig() Config {
	c := defaultConfig()
	if data, err := os.ReadFile(configPath()); err == nil {
		_ = json.Unmarshal(data, &c)

		// The dynamic-colour switches used to be called wallustEnabled and
		// wallustMode, after the tool that read them. matugen does that job
		// now (dynamic.go), so the names were a lie. Carry the old keys over
		// when the new ones are absent — the next save writes the new names
		// and the old ones drop out on their own.
		var legacy struct {
			Enabled *bool   `json:"wallustEnabled"`
			Mode    *string `json:"wallustMode"`
			Dynamic *bool   `json:"dynamicColors"`
		}
		if json.Unmarshal(data, &legacy) == nil && legacy.Dynamic == nil {
			if legacy.Enabled != nil {
				c.DynamicColors = *legacy.Enabled
			}
			if legacy.Mode != nil && *legacy.Mode != "" {
				c.DynamicMode = *legacy.Mode
			}
		}
	}
	c.Keybinds = mergeKeybinds(c.Keybinds)
	return c
}

func saveConfig(c Config) error { return writeConfig(c, true) }

// writeConfig saves the config, optionally snapshotting the old one first.
//
// The snapshot is skipped for the wallpaper-driven palette (dynamic.go): that
// runs on every wallpaper change, and 50 backups of "the accent moved" would
// push every backup of a setting you actually chose out of the ring.
func writeConfig(c Config, backup bool) error {
	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}
	data = append(data, '\n')
	p := configPath()

	// Auto-backup: snapshot the current config.json before overwriting.
	if existing, err := os.ReadFile(p); err == nil && backup {
		backupDir := filepath.Join(filepath.Dir(p), "backups")
		os.MkdirAll(backupDir, 0o755)
		ts := time.Now().Format("20060102-150405")
		os.WriteFile(filepath.Join(backupDir, fmt.Sprintf("config-%s.json", ts)), existing, 0o644)

		// Prune: keep only the 50 most recent backups.
		if entries, e := os.ReadDir(backupDir); e == nil && len(entries) > 50 {
			sort.Slice(entries, func(i, j int) bool { return entries[i].Name() < entries[j].Name() })
			for i := 0; i < len(entries)-50; i++ {
				os.Remove(filepath.Join(backupDir, entries[i].Name()))
			}
		}
	}

	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	if err := os.WriteFile(p, data, 0o644); err != nil {
		return err
	}

	// Fan the palette out to the apps that draw beside the shell (see apps.go)
	// and stage the login screen's share of it (login.go). Both hang off the
	// write rather than off an Apply button because the Theme tab's controls
	// each call saveConfig directly and let the shell notice config.json
	// change — so anything else would be one control away from being
	// forgotten. config.json is already on disk by here: a failure to write
	// kitty's colours is reported, but never costs you the save.
	if err := applyApps(c); err != nil {
		return err
	}
	// Deliberately not conditional on dynamic colours. That switch decides
	// where the palette comes from, not who gets it: someone who picks a
	// flavour by hand still wants the login screen to match it, and gating
	// the staging on the switch meant apollo-sddm-sync could never find a
	// palette to install until you had turned dynamic colours on.
	return stageLoginColors(c)
}
