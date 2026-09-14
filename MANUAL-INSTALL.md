# Apollo — Install Guide

Fresh Arch → riced desktop. Steps 1–7 in order.

There is no `install.sh`. Configs are deployed as symlinks into `~/.config`, so
edits in the repo are live and `git diff` shows what you changed.

---

## 1. Prerequisites

```bash
# An AUR helper. If you don't have one:
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay && makepkg -si
```

---

## 2. Packages

### 2.1 Core desktop

```bash
sudo pacman -S --needed \
  hyprland hypridle hyprlock hyprsunset \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  sddm qt6-wayland
```

Hyprland must be new enough to read `hyprland.lua`. Check with
`hyprctl version`; if it only knows `hyprland.conf`, Apollo won't load.

### 2.2 Shell

```bash
yay -S quickshell
```

### 2.3 Audio, network, bluetooth

```bash
sudo pacman -S pipewire wireplumber pipewire-pulse pipewire-alsa
sudo pacman -S networkmanager network-manager-applet bluez bluez-utils
```

### 2.4 Wallpaper, screenshots, clipboard

```bash
yay -S awww cliphist
sudo pacman -S grim slurp wl-clipboard
```

### 2.5 Terminal, launcher, file manager

```bash
sudo pacman -S \
  kitty rofi thunar tumbler ffmpegthumbnailer \
  gvfs gnome-themes-extra xdg-utils
```

### 2.6 Shell and editor

```bash
sudo pacman -S fish neovim git
```

### 2.7 Fonts and icons

```bash
sudo pacman -S ttf-jetbrains-mono-nerd papirus-icon-theme noto-fonts-emoji
```

### 2.8 System utilities

```bash
sudo pacman -S brightnessctl keyd htop pacman-contrib jq
# pacman-contrib provides `checkupdates` (bar update count) and `paccache`
# jq drives the keybind cheatsheet's `hyprctl binds -j` parsing
```

### 2.9 Apps, media, system info

```bash
sudo pacman -S firefox discord steam code mpv imv fastfetch
sudo pacman -S ranger 7zip zip wget openssh
yay -S spotify-launcher dgop
# ranger_devicons is vendored in this repo — nothing to install
```

### 2.10 Optional

```bash
# CPU temp in the bar — read from sysfs. To guarantee the module on boot:
grep -q AuthenticAMD /proc/cpuinfo && M=k10temp || M=coretemp
echo "$M" | sudo tee /etc/modules-load.d/apollo-temp.conf

sudo pacman -S upower            # battery stats in the system monitor panel
sudo pacman -S w3m python-pillow # ranger image previews
sudo pacman -S atool unrar unzip # ranger archive handling
sudo pacman -S lua               # lets apollo-doctor syntax-check the config
```

Airplane mode uses `rfkill`, already in `util-linux`.

---

## 3. Services

```bash
sudo systemctl enable --now NetworkManager bluetooth
sudo systemctl enable --now keyd
sudo systemctl enable --now paccache.timer
sudo systemctl enable sddm
```

---

## 4. Themes

### 4.1 SDDM

```bash
git clone https://github.com/catppuccin/sddm.git /tmp/catppuccin-sddm
sudo cp -r /tmp/catppuccin-sddm/src /usr/share/sddm/themes/catppuccin-mocha-mauve
sudo cp sddm/sddm.conf /etc/sddm.conf.d/10-theme.conf

# Background — copy, don't symlink; the sddm user can't follow into your home.
sudo cp "$(cat ~/.cache/wallpaper-current 2>/dev/null || echo '/usr/share/sddm/themes/catppuccin-mocha-mauve/backgrounds/wall.png')" \
  /usr/share/sddm/themes/catppuccin-mocha-mauve/backgrounds/wall.png
```

### 4.2 GTK

```bash
mkdir -p ~/.themes
curl -sL \
  "https://github.com/catppuccin/gtk/releases/download/v1.0.3/catppuccin-mocha-lavender-standard%2Bdefault.zip" \
  -o /tmp/catppuccin-gtk.zip
7z x -y /tmp/catppuccin-gtk.zip -o ~/.themes/
```

### 4.3 Cursors

Not vendored here — install the package:

```bash
yay -S bibata-cursor-theme
```

Then point `config/gtk-3.0/settings.ini` and `config/gtk-4.0/settings.ini` at
whatever you installed (they currently say `Nero-Cyber-Cyan`, inherited from
upstream).

---

## 5. Deploy

```bash
git clone https://github.com/Eluna007/RegolithDot ~/RegolithDot
cd ~/RegolithDot

mkdir -p ~/.config/quickshell ~/.local/share

ln -sfn ~/RegolithDot/config/hypr                  ~/.config/hypr
ln -sfn ~/RegolithDot/config/quickshell/apollo     ~/.config/quickshell/apollo
ln -sfn ~/RegolithDot/config/rofi                  ~/.config/rofi
ln -sfn ~/RegolithDot/config/kitty                 ~/.config/kitty
ln -sfn ~/RegolithDot/config/fish                  ~/.config/fish
ln -sfn ~/RegolithDot/config/nvim                  ~/.config/nvim
ln -sfn ~/RegolithDot/config/gtk-3.0               ~/.config/gtk-3.0
ln -sfn ~/RegolithDot/config/gtk-4.0               ~/.config/gtk-4.0
ln -sfn ~/RegolithDot/config/ranger                ~/.config/ranger
ln -sfn ~/RegolithDot/config/Thunar                ~/.config/Thunar
ln -sfn ~/RegolithDot/config/fastfetch             ~/.config/fastfetch
ln -sfn ~/RegolithDot/config/dgop                  ~/.config/dgop
ln -sfn ~/RegolithDot/config/xdg-desktop-portal    ~/.config/xdg-desktop-portal

ln -sfn ~/RegolithDot/local/share/icons/Apollo-Terminal ~/.local/share/icons/Apollo-Terminal
ln -sfn ~/RegolithDot/local/share/PrismLauncher         ~/.local/share/PrismLauncher

# keyd is system-wide and needs a real copy, not a symlink
sudo cp config/keyd/default.conf /etc/keyd/default.conf
sudo keyd reload
```

The shell is a *named* Quickshell config, so it launches as `qs -c apollo`
(that's what `lua/autostart.lua` does, and what the `qs -c apollo ipc call`
binds target). Symlinking it anywhere other than
`~/.config/quickshell/apollo` will break those.

Wallpapers aren't vendored — put some in `~/Pictures/Wallpapers`.

---

## 6. Post-install

```bash
# Settings GUI (needs Go)
sudo pacman -S --needed go
( cd apollo-settings && go build -o apollo-settings . && \
  install -Dm755 apollo-settings ~/.local/bin/apollo-settings )

# Icons, resized from the bundled icon.png
mkdir -p ~/.local/share/icons/hicolor/{48x48,64x64,128x128,256x256}/apps
for sz in 48x48 64x64 128x128 256x256; do
  w="${sz%x*}"; ffmpeg -y -i apollo-settings/icon.png -vf "scale=$w:$w" \
    ~/.local/share/icons/hicolor/$sz/apps/apollo-settings.png -loglevel error
done

# .desktop entry (shows up in rofi)
mkdir -p ~/.local/share/applications
cp local/share/applications/apollo-settings.desktop ~/.local/share/applications/
update-desktop-database ~/.local/share/applications 2>/dev/null
gtk-update-icon-cache ~/.local/share/icons/hicolor 2>/dev/null

# Health check on PATH
install -Dm755 scripts/apollo-doctor ~/.local/bin/apollo-doctor

# First wallpaper, so hyprlock isn't staring at an empty cache
awww img ~/Pictures/Wallpapers/<your-wallpaper> -t none
echo ~/Pictures/Wallpapers/<your-wallpaper> > ~/.cache/wallpaper-current

# Neovim plugins
nvim --headless "+Lazy! sync" +qa

```

---

## 7. Verify

```bash
apollo-doctor ~/RegolithDot
systemctl reboot
```

`apollo-doctor` syntax-checks the Lua config if `lua` is installed — worth
running *before* you reboot, since a parse error takes the whole config down
and Hyprland falls back to a handful of emergency binds.

**After reboot:**

| Component | Check |
|---|---|
| SDDM | Catppuccin login screen with your wallpaper |
| Hyprland | Rotating gradient borders, frosted blur, workspaces sliding |
| Quickshell | Top bar: workspaces, stats, tray, clock |
| Keybinds | `SUPER+Space` rofi, `SUPER+,` settings, `SUPER+B` wallpaper, `SUPER+Q` kitty |
| Panels | Clock → calendar, gear → quick settings, power → power menu |
| Cheatsheet | `ALT+/` lists live binds (needs `jq`) |
| Hyprlock | Idle lock — wallpaper with frosted glass |
| Rofi | Catppuccin launcher, quicklinks (`>`), file search (`!`) |
| Thunar | Frosted, semi-transparent |
| Ranger | Miller columns, devicons, catppuccin |
| Neovim | Catppuccin transparent background |

If Hyprland won't start, the config is the first suspect:

```bash
luac -p ~/.config/hypr/hyprland.lua ~/.config/hypr/lua/*.lua
```
