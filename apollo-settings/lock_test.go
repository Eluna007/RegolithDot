package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"testing"
)

// layoutsFixture builds a throwaway ~/.config/hyprlock with the given layouts
// installed, and points lockDir() at it for the duration of the test.
func layoutsFixture(t *testing.T, numbers ...string) string {
	t.Helper()
	root := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", root)
	dir := filepath.Join(root, "hyprlock", "layouts")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	for _, n := range numbers {
		if err := os.WriteFile(filepath.Join(dir, "layout"+n+".conf"), []byte("# stub\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return root
}

func TestWriteThenReadLockLayout(t *testing.T) {
	layoutsFixture(t, "12", "18")

	if got := readLockLayout(); got != "" {
		t.Fatalf("with no layout.conf, want %q, got %q", "", got)
	}
	if err := writeLockLayout("18"); err != nil {
		t.Fatal(err)
	}
	if got := readLockLayout(); got != "18" {
		t.Fatalf("want 18, got %q", got)
	}
	// Switching must replace the source line, not accumulate a second one:
	// hyprlock would draw both layouts on top of each other.
	if err := writeLockLayout("12"); err != nil {
		t.Fatal(err)
	}
	body, err := os.ReadFile(lockLayoutPath())
	if err != nil {
		t.Fatal(err)
	}
	if n := len(regexp.MustCompile(`(?m)^source =`).FindAll(body, -1)); n != 1 {
		t.Fatalf("want exactly 1 source line, got %d:\n%s", n, body)
	}
	if got := readLockLayout(); got != "12" {
		t.Fatalf("want 12, got %q", got)
	}
}

// A layout that is not installed must be refused rather than written: the
// resulting `source` would point at nothing, and hyprlock would lock to a
// bare background with no diagnostic.
func TestWriteLockLayoutRefusesMissing(t *testing.T) {
	layoutsFixture(t, "12")

	if err := writeLockLayout("12"); err != nil {
		t.Fatal(err)
	}
	if err := writeLockLayout("99"); err == nil {
		t.Fatal("writing an uninstalled layout should fail")
	}
	if got := readLockLayout(); got != "12" {
		t.Fatalf("a refused write must leave the old layout in place, got %q", got)
	}
}

func TestInstalledLockLayouts(t *testing.T) {
	layoutsFixture(t, "12", "20")

	got := installedLockLayouts()
	if len(got) != 2 || got[0].Number != "12" || got[1].Number != "20" {
		t.Fatalf("want [12 20] in declared order, got %v", got)
	}
	// An empty install must not panic — the tab renders a "deploy this" card.
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	if got := installedLockLayouts(); len(got) != 0 {
		t.Fatalf("want none, got %v", got)
	}
}

func TestDefaultLockLayoutIsListed(t *testing.T) {
	for _, l := range lockLayouts {
		if l.Number == defaultLockLayout {
			return
		}
	}
	t.Fatalf("defaultLockLayout %q is not in lockLayouts", defaultLockLayout)
}

// The Lock tab and `apollo-lock-layout` both write layout.conf. If they
// disagree about its contents, switching in one place and then the other
// produces a file the first cannot read back. Rather than trust that, run the
// script and diff its output against the Go writer's.
func TestGoAndShellWritersAgree(t *testing.T) {
	script, err := filepath.Abs(filepath.Join("..", "local", "bin", "apollo-lock-layout"))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(script); err != nil {
		t.Skipf("apollo-lock-layout not found: %v", err)
	}
	if _, err := exec.LookPath("bash"); err != nil {
		t.Skip("bash not available")
	}

	root := layoutsFixture(t, "12", "15", "18", "20")

	for _, n := range []string{"12", "15", "18", "20"} {
		if err := writeLockLayout(n); err != nil {
			t.Fatal(err)
		}
		fromGo, err := os.ReadFile(lockLayoutPath())
		if err != nil {
			t.Fatal(err)
		}

		cmd := exec.Command("bash", script, n)
		cmd.Env = append(os.Environ(), "XDG_CONFIG_HOME="+root)
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("apollo-lock-layout %s: %v\n%s", n, err, out)
		}
		fromShell, err := os.ReadFile(lockLayoutPath())
		if err != nil {
			t.Fatal(err)
		}

		// The banner comment names whichever tool wrote it; the line that
		// matters is the source, and each must read the other's back.
		src := regexp.MustCompile(`(?m)^source = .*$`)
		g, s := src.Find(fromGo), src.Find(fromShell)
		if string(g) != string(s) {
			t.Fatalf("layout %s: Go writes %q, apollo-lock-layout writes %q", n, g, s)
		}
		if got := readLockLayout(); got != n {
			t.Fatalf("layout %s: Go cannot read back what the script wrote, got %q", n, got)
		}
	}
}
