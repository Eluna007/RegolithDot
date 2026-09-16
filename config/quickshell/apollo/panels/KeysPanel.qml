import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../services"
// Imported as Binds, not as Keys: `Keys` is QtQuick's attached property for
// key handling, and an import alias shadows it — `Keys.onPressed` below would
// resolve to this file instead, and the panel would stop responding to Escape.
import "keys/Keys.js" as Binds

// The keybind cheatsheet. SUPER+/ , or "Keybinds" in the launcher.
//
// This was a rofi mode. It asked `hyprctl binds -j` rather than parsing the
// config, and that part is kept: binds are Lua function calls now, their
// arguments are tables, and a `for i = 1, 4` loop registers four binds that
// appear nowhere in the file as text. What the compositor reports is what is
// actually bound, apollo-settings' overrides included.
//
// Decoding, grouping and search live in keys/Keys.js and are covered by
// scripts/test-keys.js. This file is presentation and input.
PanelWindow {
    id: root
    signal close()

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"
    readonly property color text:     Config.text
    readonly property color overlay0: Config.overlay0
    readonly property color subtext0: Config.subtext0
    readonly property color accent:   Config.accent

    property string query: ""
    property var rows: []
    // Set when hyprctl produced nothing usable, so the empty state can say
    // which of the two it was rather than reading as "you have no keybinds".
    property bool loadFailed: false

    readonly property var groups: Binds.groupRows(Binds.filterRows(query, rows))
    readonly property int shown: Binds.countRows(groups)

    // ── Reading the binds ────────────────────────────────────────────────
    // hyprctl's JSON has to arrive whole before it can be parsed, so the lines
    // are accumulated and parsed when the process ends — the same shape
    // TailscalePanel.qml uses.
    property string buffer: ""
    Process {
        id: bindsProc
        command: ["hyprctl", "binds", "-j"]
        stdout: SplitParser { onRead: line => root.buffer += line + "\n" }
        onRunningChanged: {
            if (running) { root.buffer = ""; return }
            var parsed = Binds.parseBinds(root.buffer)
            root.rows = parsed
            root.loadFailed = parsed.length === 0
        }
    }

    // Re-read on every open. Binds change when apollo-settings writes them, and
    // a cheatsheet showing the previous set is the one failure that matters.
    onVisibleChanged: {
        if (visible) {
            query = ""
            if (!bindsProc.running) bindsProc.running = true
            input.forceActiveFocus()
        }
    }

    function copyCombo(combo) {
        if (!combo) return
        Quickshell.execDetached(["wl-copy", "--", combo])
        root.close()
    }

    function copyFirst() {
        if (groups.length === 0 || groups[0].rows.length === 0) return
        root.copyCombo(groups[0].rows[0].combo)
    }

    // ── Scrim ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Config.crust.r, Config.crust.g, Config.crust.b, 0.35)
        NumberAnimation on opacity {
            from: 0; to: 1; running: true
            duration: Motion.fastEffects
            easing.type: Easing.Bezier; easing.bezierCurve: Motion.curveDefaultEffects
        }
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ── The card ────────────────────────────────────────────────────────
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.10)
        width: Math.min(820, parent.width - 80)
        height: Math.min(cardCol.implicitHeight, Math.round(parent.height * 0.80))
        radius: 20
        color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.62)
        border.width: 1
        border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.10)
        clip: true

        // A centred sheet: it grows from its own middle, since it is not
        // attached to any bar edge.
        // Curves are Caelestia's Material 3 expressive set; see
        // services/Motion.qml for the measured overshoot and why it cannot clip.
        transformOrigin: Item.Center
        NumberAnimation on opacity {
            from: 0; to: 1; running: true
            duration: Motion.effects
            easing.type: Easing.Bezier; easing.bezierCurve: Motion.curveDefaultEffects
        }
        NumberAnimation on scale {
            from: Motion.fromScale; to: 1; running: true
            duration: Motion.spatial
            easing.type: Easing.Bezier; easing.bezierCurve: Motion.curveDefaultSpatial
        }

        ColumnLayout {
            id: cardCol
            width: parent.width
            height: parent.height
            spacing: 0

            // Search row
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 18
                spacing: 12

                Text {
                    text: "\u{f0349}"
                    color: root.overlay0
                    font { pixelSize: 18; family: root.nfFont }
                }

                TextInput {
                    id: input
                    Layout.fillWidth: true
                    focus: true
                    color: root.text
                    font { pixelSize: 19; family: root.nfFont }
                    selectionColor: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.4)
                    selectedTextColor: root.text
                    clip: true
                    onTextChanged: root.query = text

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: "Search shortcuts"
                        color: root.overlay0
                        font { pixelSize: 19; family: root.nfFont }
                    }

                    Keys.onPressed: ev => {
                        if (ev.key === Qt.Key_Escape) { root.close(); ev.accepted = true }
                        else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                            root.copyFirst(); ev.accepted = true
                        }
                    }
                }

                Text {
                    textFormat: Text.PlainText
                    text: root.shown + (root.shown === 1 ? " shortcut" : " shortcuts")
                    color: root.overlay0
                    font { pixelSize: 11; family: root.nfFont }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)
            }

            // ── The sheet ───────────────────────────────────────────────
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 6
                Layout.bottomMargin: 10
                clip: true
                contentHeight: sheet.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                visible: root.groups.length > 0

                Column {
                    id: sheet
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: root.groups

                        Column {
                            required property var modelData
                            width: sheet.width
                            spacing: 0

                            // Group header: the modifier half, which is how you
                            // look a shortcut up ("what does Super+Shift do").
                            Item {
                                width: parent.width
                                height: 34
                                Text {
                                    anchors {
                                        left: parent.left; leftMargin: 20
                                        verticalCenter: parent.verticalCenter
                                    }
                                    textFormat: Text.PlainText
                                    text: modelData.mods
                                    color: root.accent
                                    font { pixelSize: 11; bold: true; family: root.nfFont }
                                }
                            }

                            Repeater {
                                model: modelData.rows

                                Rectangle {
                                    required property var modelData
                                    width: sheet.width
                                    height: 32
                                    color: rowHov.containsMouse
                                           ? Qt.rgba(root.text.r, root.text.g, root.text.b, 0.06)
                                           : "transparent"
                                    Behavior on color { ColorAnimation { duration: 90 } }

                                    RowLayout {
                                        anchors {
                                            fill: parent
                                            leftMargin: 20; rightMargin: 20
                                        }
                                        spacing: 14

                                        // Key caps, one per piece of the combo.
                                        Row {
                                            spacing: 5
                                            Layout.preferredWidth: 250

                                            Repeater {
                                                model: Binds.caps(modelData.combo)

                                                Rectangle {
                                                    required property string modelData
                                                    implicitWidth: capText.implicitWidth + 14
                                                    implicitHeight: 21
                                                    radius: 5
                                                    color: Qt.rgba(Config.surface1.r, Config.surface1.g,
                                                                   Config.surface1.b, 0.55)
                                                    border.width: 1
                                                    border.color: Qt.rgba(Config.text.r, Config.text.g,
                                                                          Config.text.b, 0.08)
                                                    Text {
                                                        id: capText
                                                        anchors.centerIn: parent
                                                        textFormat: Text.PlainText
                                                        text: modelData
                                                        color: root.text
                                                        font { pixelSize: 11; family: root.nfFont }
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            textFormat: Text.PlainText
                                            elide: Text.ElideRight
                                            text: modelData.action
                                            color: root.subtext0
                                            font { pixelSize: 12; family: root.nfFont }
                                        }
                                    }

                                    MouseArea {
                                        id: rowHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.copyCombo(modelData.combo)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Empty state. Says which of the two things happened: hyprctl gave
            // us nothing, or your search matched nothing.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.groups.length === 0
                Text {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    text: root.loadFailed
                          ? "Could not read the keybinds.\nNeeds hyprctl, from a running Hyprland."
                          : "No shortcut matches “" + root.query + "”"
                    color: root.overlay0
                    font { pixelSize: 12; family: root.nfFont }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)
            }

            Text {
                Layout.fillWidth: true
                Layout.margins: 12
                textFormat: Text.PlainText
                text: "Click a shortcut to copy it · Enter copies the first match · Esc closes"
                color: root.overlay0
                font { pixelSize: 10; family: root.nfFont }
            }
        }
    }
}
