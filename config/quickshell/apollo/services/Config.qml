pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Single source of truth for the two widgets.
//
// Live-reads ~/.config/apollo/config.json (watchChanges), so editing that file
// restyles the panels without restarting the shell. It is machine state, not
// part of this repo: with no file at all every key below falls back to the
// default written next to it, which is a working Catppuccin Mocha.
//
// This used to carry the whole rice — bar layout, wallpaper dir, toasts,
// battery glyphs, a dynamic palette written by matugen. All of that went with
// the bar. What is left is the palette the panels paint with, where they sit,
// and the one chess.com handle.
Singleton {
    id: root

    // Drives active/hover states in both panels.
    readonly property color accent: adapter.accent

    // Which screen edge the panels anchor to: "top" | "left" | "right".
    // They used to hang off the bar's painted edge; with no bar this is just
    // where you want them.
    readonly property string panelEdge: adapter.panelEdge
    // Gap between that edge and the panel, in pixels.
    readonly property int panelMargin: adapter.panelMargin

    // chess.com handle for the chess widget's ratings. Empty means the widget
    // simply does not show that section — it is never required to play.
    readonly property string chessUsername: adapter.chessUsername

    // ── Palette (Catppuccin flavor) ──────────────────────────────────────
    // flavor picks the WHOLE palette — the neutral ramp (base…text) *and* the
    // accent family (blue, teal, green, red, …), so every flavor is fully
    // realised rather than Mocha with a different background. The `accent`
    // knob above stays separate on top.
    readonly property string flavor: adapter.flavor

    readonly property var _flavors: ({
        "mocha":     { base:"#1e1e2e", mantle:"#181825", crust:"#11111b", surface0:"#313244", surface1:"#45475a", surface2:"#585b70", overlay0:"#6c7086", overlay1:"#7f849c", overlay2:"#9399b2", subtext0:"#a6adc8", subtext1:"#bac2de", text:"#cdd6f4", rosewater:"#f5e0dc", flamingo:"#f2cdcd", pink:"#f5c2e7", mauve:"#cba6f7", red:"#f38ba8", maroon:"#eba0ac", peach:"#fab387", yellow:"#f9e2af", green:"#a6e3a1", teal:"#94e2d5", sky:"#89dceb", sapphire:"#74c7ec", blue:"#89b4fa", lavender:"#b4befe" },
        "macchiato": { base:"#24273a", mantle:"#1e2030", crust:"#181926", surface0:"#363a4f", surface1:"#494d64", surface2:"#5b6078", overlay0:"#6e738d", overlay1:"#8087a2", overlay2:"#939ab7", subtext0:"#a5adcb", subtext1:"#b8c0e0", text:"#cad3f5", rosewater:"#f4dbd6", flamingo:"#f0c6c6", pink:"#f5bde6", mauve:"#c6a0f6", red:"#ed8796", maroon:"#ee99a0", peach:"#f5a97f", yellow:"#eed49f", green:"#a6da95", teal:"#8bd5ca", sky:"#91d7e3", sapphire:"#7dc4e4", blue:"#8aadf4", lavender:"#b7bdf8" },
        "frappe":    { base:"#303446", mantle:"#292c3c", crust:"#232634", surface0:"#414559", surface1:"#51576d", surface2:"#626880", overlay0:"#737994", overlay1:"#838ba7", overlay2:"#949cbb", subtext0:"#a5adce", subtext1:"#b5bfe2", text:"#c6d0f5", rosewater:"#f2d5cf", flamingo:"#eebebe", pink:"#f4b8e4", mauve:"#ca9ee6", red:"#e78284", maroon:"#ea999c", peach:"#ef9f76", yellow:"#e5c890", green:"#a6d189", teal:"#81c8be", sky:"#99d1db", sapphire:"#85c1dc", blue:"#8caaee", lavender:"#babbf1" },
        "latte":     { base:"#eff1f5", mantle:"#e6e9ef", crust:"#dce0e8", surface0:"#ccd0da", surface1:"#bcc0cc", surface2:"#acb0be", overlay0:"#9ca0b0", overlay1:"#8c8fa1", overlay2:"#7c7f93", subtext0:"#6c6f85", subtext1:"#5c5f77", text:"#4c4f69", rosewater:"#dc8a78", flamingo:"#dd7878", pink:"#ea76cb", mauve:"#8839ef", red:"#d20f39", maroon:"#e64553", peach:"#fe640b", yellow:"#df8e1d", green:"#40a02b", teal:"#179299", sky:"#04a5e5", sapphire:"#209fb5", blue:"#1e66f5", lavender:"#7287fd" }
    })
    readonly property var _p: _flavors[flavor] !== undefined ? _flavors[flavor] : _flavors["mocha"]

    readonly property color base:     _p.base
    readonly property color mantle:   _p.mantle
    readonly property color crust:    _p.crust
    readonly property color surface0: _p.surface0
    readonly property color surface1: _p.surface1
    readonly property color surface2: _p.surface2
    readonly property color overlay0: _p.overlay0
    readonly property color overlay1: _p.overlay1
    readonly property color overlay2: _p.overlay2
    readonly property color subtext0: _p.subtext0
    readonly property color subtext1: _p.subtext1
    readonly property color text:     _p.text

    // Accent family — follows the flavor (Latte's are darker and more
    // saturated, for a light background). Bind semantic colors in the panels
    // to these instead of hardcoding Mocha hexes.
    readonly property color rosewater: _p.rosewater
    readonly property color flamingo:  _p.flamingo
    readonly property color pink:      _p.pink
    readonly property color mauve:     _p.mauve
    readonly property color red:       _p.red
    readonly property color maroon:    _p.maroon
    readonly property color peach:     _p.peach
    readonly property color yellow:    _p.yellow
    readonly property color green:     _p.green
    readonly property color teal:      _p.teal
    readonly property color sky:       _p.sky
    readonly property color sapphire:  _p.sapphire
    readonly property color blue:      _p.blue
    readonly property color lavender:  _p.lavender

    FileView {
        id: cfg
        path: Quickshell.env("HOME") + "/.config/apollo/config.json"
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            id: adapter
            property string accent: "#cba6f7"
            property string flavor: "mocha"
            property string panelEdge: "top"
            property int    panelMargin: 10
            property string chessUsername: ""
        }
    }
}
