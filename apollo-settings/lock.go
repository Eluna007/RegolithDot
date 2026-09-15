package main

// The Lock tab picks which hyprlock layout the lock screen uses.
//
// Unlike every other tab, this one does NOT keep its state in config.json.
// The truth is ~/.config/hyprlock/layout.conf — a one-line `source` that
// hyprlock.conf pulls in — because `apollo-lock-layout` writes the same file
// from a terminal. Two copies of the answer would drift the moment someone
// used the CLI, so the tab reads and writes that file directly and config.json
// stays out of it.
//
// hyprlock re-reads its config on every launch, so there is nothing to reload
// and no Apply button: the next lock uses whatever is selected.

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/widget"
)

// lockLayout is one vendored layout. Number is what appears in the filename
// (layouts/layout12.conf) and what the CLI takes as its argument.
type lockLayout struct {
	Number string
	Desc   string
	Needs  string // extra binary beyond playerctl, "" if none
}

// lockLayouts MUST stay in step with config/hyprlock/layouts/*.conf and with
// apollo-lock-layout's describe(). CI cross-checks all three, so adding a
// layout means touching this list too.
var lockLayouts = []lockLayout{
	{"12", "Minimal, left-aligned: welcome, clock, username + password pills", ""},
	{"15", "Centred clock; right column of music, weather, battery, avatar", "curl"},
	{"18", "Music-first: album art, transport, progress, cava visualiser", "cava"},
	{"20", "Widget dashboard: login card, clock + uptime, music, wifi/bt, battery", ""},
}

const defaultLockLayout = "12"

// lockDir is ~/.config/hyprlock, honouring XDG_CONFIG_HOME like hyprDir does.
func lockDir() string {
	if xdg := os.Getenv("XDG_CONFIG_HOME"); xdg != "" {
		return filepath.Join(xdg, "hyprlock")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "hyprlock")
}

func lockLayoutPath() string { return filepath.Join(lockDir(), "layout.conf") }

var lockSourceRe = regexp.MustCompile(`/layouts/layout([0-9]+)\.conf`)

// readLockLayout returns the layout number layout.conf points at, or "" when
// the file is missing or names nothing recognisable.
func readLockLayout() string {
	data, err := os.ReadFile(lockLayoutPath())
	if err != nil {
		return ""
	}
	m := lockSourceRe.FindSubmatch(data)
	if m == nil {
		return ""
	}
	return string(m[1])
}

// installedLockLayouts is which of lockLayouts actually have a file on disk.
// A layout the machine does not have should not be offered — selecting it
// would leave the lock screen blank.
func installedLockLayouts() []lockLayout {
	var out []lockLayout
	for _, l := range lockLayouts {
		if _, err := os.Stat(filepath.Join(lockDir(), "layouts", "layout"+l.Number+".conf")); err == nil {
			out = append(out, l)
		}
	}
	return out
}

// writeLockLayout rewrites layout.conf. It writes to a temp file in the same
// directory and renames, so a lock starting mid-write never reads half a
// config. The body is byte-for-byte what apollo-lock-layout writes.
func writeLockLayout(number string) error {
	dir := lockDir()
	target := filepath.Join(dir, "layouts", "layout"+number+".conf")
	if _, err := os.Stat(target); err != nil {
		return fmt.Errorf("layout%s is not installed (%s)", number, target)
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	body := "# Written by apollo-settings. Gitignored machine state - not config.\n" +
		"# Change it with `apollo-lock-layout <number>` or apollo-settings' Lock tab.\n" +
		"source = $hyprlockDir/layouts/layout" + number + ".conf\n"

	tmp, err := os.CreateTemp(dir, "layout.conf.*")
	if err != nil {
		return err
	}
	name := tmp.Name()
	defer os.Remove(name) // no-op once the rename succeeds
	if _, err := tmp.WriteString(body); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	if err := os.Chmod(name, 0o644); err != nil {
		return err
	}
	return os.Rename(name, lockLayoutPath())
}

// missingLockDeps reports which of the named binaries are not on PATH, so the
// tab can warn that a layout will render with empty widgets rather than
// letting the user find out at the lock screen.
func missingLockDeps(names ...string) []string {
	var missing []string
	for _, n := range names {
		if n == "" {
			continue
		}
		if _, err := exec.LookPath(n); err != nil {
			missing = append(missing, n)
		}
	}
	sort.Strings(missing)
	return missing
}

// ── Lock tab ─────────────────────────────────────────────────────────────
func lockTab(w fyne.Window) fyne.CanvasObject {
	installed := installedLockLayouts()
	if len(installed) == 0 {
		body := container.NewVBox(widget.NewCard("No layouts found",
			filepath.Join(lockDir(), "layouts")+" is empty or missing",
			hintText("The hyprlock config does not look deployed. Run apollo-doctor, "+
				"which will tell you what is missing and how to link it.")))
		return container.NewBorder(nil, nil, nil, nil, container.NewPadded(body))
	}

	// Radio labels carry the description, so the choice is legible without a
	// separate preview pane. byLabel maps back to the number on selection.
	var opts []string
	byLabel := map[string]lockLayout{}
	for _, l := range installed {
		label := fmt.Sprintf("%s  —  %s", l.Number, l.Desc)
		opts = append(opts, label)
		byLabel[label] = l
	}

	status := widget.NewLabel("")
	status.Wrapping = fyne.TextWrapWord

	deps := widget.NewLabel("")
	deps.Wrapping = fyne.TextWrapWord
	deps.Importance = widget.WarningImportance

	// showFor updates the two lines under the radio for a given layout: what
	// is set, and whether anything it needs is missing.
	showFor := func(l lockLayout) {
		status.SetText(fmt.Sprintf("Lock screen is set to layout%s. It takes effect the next time the screen locks.", l.Number))
		if m := missingLockDeps("playerctl", l.Needs); len(m) > 0 {
			deps.SetText("⚠  Not installed: " + strings.Join(m, ", ") +
				" — the widgets that need them will render empty.")
			deps.Show()
		} else {
			deps.Hide()
		}
	}

	radio := widget.NewRadioGroup(opts, nil)
	radio.Required = true

	// SetSelected fires OnChanged, which would write layout.conf right back.
	// Every programmatic selection therefore detaches the handler and
	// reattaches it afterwards — forgetting the reattach leaves the radio
	// inert, so it lives in one place here rather than at each call site.
	var onPick func(string)
	setSelected := func(label string) {
		radio.OnChanged = nil
		radio.SetSelected(label)
		radio.OnChanged = onPick
	}

	// sync re-reads layout.conf, so the tab reflects a change made from the
	// terminal rather than overwriting it with a stale selection.
	sync := func() {
		cur := readLockLayout()
		for label, l := range byLabel {
			if l.Number == cur {
				setSelected(label)
				showFor(l)
				return
			}
		}
		// Unset, or pointing at a layout this machine does not have.
		setSelected("")
		status.SetText("No layout is set yet — pick one. Until you do, locking the screen shows the background and nothing else.")
		deps.Hide()
	}

	onPick = func(label string) {
		l, ok := byLabel[label]
		if !ok {
			return
		}
		if err := writeLockLayout(l.Number); err != nil {
			dialog.ShowError(err, w)
			sync()
			return
		}
		showFor(l)
	}
	sync()

	layoutCard := widget.NewCard("Layout", "Which lock screen hyprlock draws", container.NewVBox(
		radio, status, deps,
	))

	tryCard := widget.NewCard("Try it", "Lock now to see the layout you picked", container.NewVBox(
		widget.NewButton("Lock the screen", func() {
			dialog.ShowConfirm("Lock the screen?",
				"This locks your session immediately. You will need your password to get back in.",
				func(ok bool) {
					if !ok {
						return
					}
					cmd := exec.Command("hyprlock")
					if err := cmd.Start(); err != nil {
						dialog.ShowError(fmt.Errorf("could not start hyprlock: %w", err), w)
						return
					}
					go cmd.Wait() // reap it rather than leaving a zombie
				}, w)
		}),
		hintText("Colours come from the current wallpaper via matugen, so every layout "+
			"matches whatever is on screen. Switching layouts changes only "+
			lockLayoutPath()+", which is not tracked in the dotfiles repo."),
	))

	reset := resetButton(func() {
		if err := writeLockLayout(defaultLockLayout); err != nil {
			dialog.ShowError(err, w)
		}
		sync()
	})

	body := container.NewVBox(layoutCard, tryCard)
	return container.NewBorder(nil, footer(reset), nil, nil, container.NewPadded(body))
}
