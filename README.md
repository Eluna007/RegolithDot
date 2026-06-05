# RegolithDot

Personal Hyprland + caelestia (QuickShell) setup. CachyOS, Lenovo IdeaPad Slim 7.

## Layout
- config/hypr/                          Hyprland config (Lua-based)
- config/quickshell/caelestia/          caelestia shell
- config/quickshell/wallpaper-picker/   wallpaper picker
- config/caelestia/                     caelestia user settings (shell.json, monitors)
- update-qs-colors.py                   helper to sync colors into the shell

## Deploy on a machine
    git clone https://github.com/Eluna007/RegolithDot ~/RegolithDot
    ln -sfn ~/RegolithDot/config/hypr                      ~/.config/hypr
    ln -sfn ~/RegolithDot/config/quickshell/caelestia      ~/.config/quickshell/caelestia
    ln -sfn ~/RegolithDot/config/quickshell/wallpaper-picker ~/.config/quickshell/wallpaper-picker
    ln -sfn ~/RegolithDot/config/caelestia                 ~/.config/caelestia

## Update (configs are symlinked, so edits are live)
    cd ~/RegolithDot && git add -A && git commit -m "your message" && git push
