import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services"
import "launcher/Match.js" as Match
import "launcher/Commands.js" as Commands

// Spotlight-style launcher: a floating glass card, type to filter, Enter to
// act. It searches installed applications, the windows that are open right
// now, a calculator, and the things the shell can do itself - one list, one
// ranking. Typing ">" on its own lists the actions, the way a command palette
// does.
//
// Matching and ranking live in launcher/Match.js, and everything that is not
// an installed application in launcher/Commands.js; both are covered by
// scripts/test-launcher.js. The app list comes from scripts/apps.sh, covered
// by scripts/test-apps.sh. This file is presentation and input.
//
// The card is translucent rather than blurred in QML: rules.lua already blurs
// the whole `quickshell` layer namespace, so the compositor does the glass and
// this only has to let it through.
PanelWindow {
    id: root
    signal close()

    // ── Opening ──────────────────────────────────────────────────────────
    // `running: visible`, not a NumberAnimation-on-property with
    // `running: true`. shell.qml creates every panel eagerly and toggles it
    // with `visible`, so an animation that starts on component completion
    // plays once at login, while the panel is hidden, and is never seen again.
    // Defaults to 1, so the panel is fully drawn even if this never runs.
    property real reveal: 1
    NumberAnimation {
        target: root
        property: "reveal"
        from: 0; to: 1
        duration: Motion.spatial
        easing.type: Easing.Bezier
        easing.bezierCurve: Motion.curveDefaultSpatial
        running: root.visible
    }
    // Panel actions hand back to shell.qml, which owns which panel is open.
    // The launcher does not close itself afterwards: opening another panel
    // already makes `activePanel === "launcher"` false.
    signal openPanel(string name)

    // Full-screen: the launcher owns the screen while it is up, which is what
    // makes click-anywhere-to-dismiss and keyboard capture work.
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"
    readonly property color surface0: Config.surface0
    readonly property color surface1: Config.surface1
    readonly property color overlay0: Config.overlay0
    readonly property color subtext0: Config.subtext0
    readonly property color text:     Config.text
    readonly property color accent:   Config.accent

    // ── App list ────────────────────────────────────────────────────────
    property var apps: []
    property string query: ""
    property int selected: 0

    // Windows come from the same live list WindowOverview.qml uses, so a
    // keystroke costs no process. A calculation is pinned above the ranking
    // rather than scored into it - when a sum parses, it is what you meant.
    readonly property var results: {
        var ranked = Match.filter(Commands.searchTerm(query),
                                  Commands.sources(query, apps, Hyprland.toplevels.values))
        var sum = Commands.calc(query)
        return sum ? [sum].concat(ranked) : ranked
    }

    readonly property string appsScript:
        (Quickshell.env("XDG_CONFIG_HOME") !== ""
            ? Quickshell.env("XDG_CONFIG_HOME")
            : Quickshell.env("HOME") + "/.config")
        + "/quickshell/apollo/scripts/apps.sh"

    property var appBuffer: []
    Process {
        id: scanProc
        command: [root.appsScript]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var e = Match.parseLine(line)
                if (e) root.appBuffer.push(e)
            }
        }
        onRunningChanged: {
            if (running) { root.appBuffer = []; return }
            root.apps = root.appBuffer
        }
    }

    // Rescan on open. It costs ~30ms for two hundred apps, which is cheaper
    // than showing a list that is missing something installed five minutes ago.
    onVisibleChanged: {
        if (visible) {
            query = ""
            selected = 0
            if (!scanProc.running) scanProc.running = true
            input.forceActiveFocus()
        }
    }

    function launch(entry) {
        if (!entry) return

        if (entry.kind === "calc") {
            // Argv, not a shell string: the result is a number, but it reaches
            // wl-copy without a shell either way.
            Quickshell.execDetached(["wl-copy", "--", entry.value])
            root.close()
            return
        }
        if (entry.kind === "window") {
            // Toplevel.activate() only requests surface activation and does not
            // reliably bring the workspace with it - see WindowOverview.qml.
            Hypr.focusWindow(entry.address)
            root.close()
            return
        }
        if (entry.kind === "action" && entry.panel) {
            root.openPanel(entry.panel)
            return
        }

        // Applications, and the actions that are a command. The Exec line is a
        // command line, so it goes through a shell. It comes from the .desktop
        // file, which is the same trust level as the binary it names.
        Quickshell.execDetached(["sh", "-c", entry.exec])
        root.close()
    }

    function move(delta) {
        if (results.length === 0) return
        var n = selected + delta
        if (n < 0) n = results.length - 1
        if (n >= results.length) n = 0
        selected = n
        // Stop any wheel glide first: it and positionViewAtIndex both write
        // contentY, and the animation would otherwise drag the view back off
        // the row that was just selected.
        glide.stop()
        resultList.positionViewAtIndex(n, ListView.Contain)
    }

    // ── Scrim ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Config.crust.r, Config.crust.g, Config.crust.b, 0.35)
        opacity: root.reveal
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    // ── The card ────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        // Sits above centre, the way Spotlight does - a centred box drifts down
        // as the list grows and the search field moves under your eyes.
        y: Math.round(parent.height * 0.18)

        width: Math.min(620, parent.width - 80)
        implicitHeight: cardCol.implicitHeight
        height: implicitHeight
        radius: 20
        color: Qt.rgba(Config.base.r, Config.base.g, Config.base.b, 0.62)
        border.width: 1
        border.color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.10)
        clip: true

        // A centred sheet, so it grows from its own middle: no bar edge is
        // its own. See `reveal` on the root for why this is a binding.
        transformOrigin: Item.Center
        scale: Motion.fromScale + (1 - Motion.fromScale) * root.reveal
        opacity: Math.min(1, root.reveal * 2)

        ColumnLayout {
            id: cardCol
            width: parent.width
            spacing: 0

            // Search row
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 18
                spacing: 12

                Text {
                    text: "\u{f0349}"
                    color: root.overlay0
                    font { pixelSize: 20; family: root.nfFont }
                }

                TextInput {
                    id: input
                    Layout.fillWidth: true
                    focus: true
                    color: root.text
                    font { pixelSize: 21; family: root.nfFont }
                    selectionColor: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.4)
                    selectedTextColor: root.text
                    clip: true
                    onTextChanged: { root.query = text; root.selected = 0 }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: "Search apps, windows, actions — or do a sum"
                        color: root.overlay0
                        font { pixelSize: 21; family: root.nfFont }
                    }

                    Keys.onPressed: ev => {
                        if (ev.key === Qt.Key_Escape) { root.close(); ev.accepted = true }
                        else if (ev.key === Qt.Key_Down) { root.move(1); ev.accepted = true }
                        else if (ev.key === Qt.Key_Up) { root.move(-1); ev.accepted = true }
                        else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                            root.launch(root.results[root.selected]); ev.accepted = true
                        }
                        else if (ev.key === Qt.Key_Tab) { root.move(1); ev.accepted = true }
                    }
                }

                Text {
                    text: root.results.length + ""
                    visible: root.query !== ""
                    color: root.overlay0
                    font { pixelSize: 12; family: root.nfFont }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.rgba(Config.text.r, Config.text.g, Config.text.b, 0.08)
                visible: root.results.length > 0
            }

            // Results
            ListView {
                id: resultList
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 372)
                Layout.bottomMargin: root.results.length > 0 ? 8 : 0
                Layout.topMargin: root.results.length > 0 ? 8 : 0
                clip: true
                model: root.results
                currentIndex: root.selected

                // A trackpad two-finger drag is the Flickable's own physics;
                // a lower deceleration lets it coast the way a Mac does rather
                // than stopping the moment you lift off.
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 900
                maximumFlickVelocity: 4000

                // A mouse wheel is the other half, and Flickable jumps a notch
                // at a time for it. Each notch glides to its destination
                // instead, and notches spun in quick succession retarget the
                // same animation rather than fighting over contentY.
                property real glideTarget: 0
                NumberAnimation {
                    id: glide
                    target: resultList
                    property: "contentY"
                    duration: Motion.slowEffects
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Motion.curveDefaultEffects
                }
                function glideBy(dy) {
                    var maxY = Math.max(0, contentHeight - height)
                    if (maxY <= 0) return
                    var from = glide.running ? glideTarget : contentY
                    glideTarget = Math.max(0, Math.min(maxY, from + dy))
                    glide.stop()
                    glide.from = contentY
                    glide.to = glideTarget
                    glide.start()
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse
                    onWheel: e => {
                        var notches = (e.angleDelta.y || 0) / 120
                        if (notches === 0) return
                        resultList.glideBy(-notches * 104)   // two rows a notch
                    }
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: resultList.width
                    height: 52
                    color: index === root.selected
                           ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                           : rowHov.containsMouse ? Qt.rgba(root.text.r, root.text.g, root.text.b, 0.06)
                           : "transparent"
                    Behavior on color { ColorAnimation { duration: 90 } }

                    RowLayout {
                        anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                        spacing: 14

                        // Icon, or a lettered tile when the .desktop file named
                        // an icon that is not installed.
                        Item {
                            implicitWidth: 34
                            implicitHeight: 34

                            Image {
                                id: appIcon
                                anchors.fill: parent
                                source: modelData.icon !== "" ? "file://" + modelData.icon : ""
                                sourceSize.width: 68
                                sourceSize.height: 68
                                fillMode: Image.PreserveAspectFit
                                visible: modelData.icon !== "" && status === Image.Ready
                                asynchronous: true
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: !appIcon.visible
                                radius: 9
                                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.kind === "calc"
                                          ? "=" : Match.initial(modelData.name)
                                    color: root.accent
                                    font { pixelSize: 16; bold: true; family: root.nfFont }
                                }
                            }
                        }

                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                text: modelData.name
                                color: root.text
                                font { pixelSize: 14; family: root.nfFont }
                            }
                            Text {
                                Layout.fillWidth: true
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                visible: modelData.comment !== ""
                                text: modelData.comment
                                color: root.overlay0
                                font { pixelSize: 10; family: root.nfFont }
                            }
                        }

                        Text {
                            visible: index === root.selected
                            text: "\u{f0311}"
                            color: root.overlay0
                            font { pixelSize: 13; family: root.nfFont }
                        }
                    }

                    MouseArea {
                        id: rowHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selected = index
                        onClicked: root.launch(modelData)
                    }
                }
            }

            // Nothing matched. Says which query found nothing, rather than
            // leaving a blank card that looks like it is still loading.
            Item {
                Layout.fillWidth: true
                implicitHeight: 56
                visible: root.query !== "" && root.results.length === 0
                Text {
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: "Nothing matches “" + root.query + "”"
                    color: root.overlay0
                    font { pixelSize: 12; family: root.nfFont }
                }
            }
        }
    }
}
