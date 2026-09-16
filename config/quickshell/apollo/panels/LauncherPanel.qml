import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services"
import "launcher/Match.js" as Match

// Spotlight-style app launcher: a floating glass card, type to filter, Enter
// to launch.
//
// Matching and ranking live in launcher/Match.js and are covered by
// scripts/test-launcher.js; the app list comes from scripts/apps.sh, covered
// by scripts/test-apps.sh. This file is presentation and input.
//
// The card is translucent rather than blurred in QML: rules.lua already blurs
// the whole `quickshell` layer namespace, so the compositor does the glass and
// this only has to let it through.
PanelWindow {
    id: root
    signal close()

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

    readonly property var results: Match.filter(query, apps)

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
        // The Exec line is a command line, so it goes through a shell. It comes
        // from the .desktop file, which is the same trust level as the binary
        // it names.
        Quickshell.execDetached(["sh", "-c", entry.exec])
        root.close()
    }

    function move(delta) {
        if (results.length === 0) return
        var n = selected + delta
        if (n < 0) n = results.length - 1
        if (n >= results.length) n = 0
        selected = n
        resultList.positionViewAtIndex(n, ListView.Contain)
    }

    // ── Scrim ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Config.crust.r, Config.crust.g, Config.crust.b, 0.35)
        NumberAnimation on opacity { from: 0; to: 1; duration: 140; running: true }
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

        // Rises slightly as it appears, rather than snapping in.
        NumberAnimation on opacity { from: 0; to: 1; duration: 160; running: true; easing.type: Easing.OutCubic }
        NumberAnimation on y {
            from: Math.round(root.height * 0.18) + 14
            to: Math.round(root.height * 0.18)
            duration: 200; running: true; easing.type: Easing.OutCubic
        }

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
                        text: "Search applications"
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
                                    text: Match.initial(modelData.name)
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
                    text: "No application matches “" + root.query + "”"
                    color: root.overlay0
                    font { pixelSize: 12; family: root.nfFont }
                }
            }
        }
    }
}
