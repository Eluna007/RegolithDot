import QtQuick
import Quickshell.Io
import "../components" as Components
import "../services" as Services

// Backed by copyq (already running in autostart.lua) rather than cliphist —
// copyq's `eval` subcommand is a small scripting language, used here just
// to dump "index<TAB>text" lines, matching the same simple list format
// most clipboard-manager popups use.
Components.AnchoredPopup {
    id: popup
    contentWidth: 300

    property var items: []
    property int copiedIndex: -1

    function refresh() {
        listProc.buf = ""
        listProc.running = true
    }
    function copyItem(index) {
        popup.copiedIndex = index
        selectProc.command = ["copyq", "select", String(index)]
        selectProc.running = true
        copiedTimer.restart()
    }
    function clearAll() {
        popup.items = []
        clearProc.running = true
    }

    onVisibleChanged: if (visible) refresh()

    Item {
        Process {
            id: listProc
            command: ["copyq", "eval",
                "for (var i = 0; i < Math.min(count(), 20); ++i) { print(i + '\\t' + str(read(i)).replace(/\\n/g, ' ').substring(0, 120) + '\\n') }"]
            property string buf: ""
            stdout: SplitParser { onRead: data => listProc.buf += data + "\n" }
            onExited: (code, status) => {
                var lines = listProc.buf.split("\n")
                var list = []
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i]
                    if (line.trim() === "") continue
                    var tab = line.indexOf("\t")
                    if (tab < 0) continue
                    list.push({ index: parseInt(line.substring(0, tab)), text: line.substring(tab + 1) })
                }
                popup.items = list
            }
        }
        Process { id: selectProc }
        Process { id: clearProc; command: ["copyq", "eval", "while (count() > 0) remove(0)"] }
        Timer { id: copiedTimer; interval: 900; onTriggered: popup.copiedIndex = -1 }
    }

    Row {
        width: parent.width
        Text {
            text: "Clipboard"
            color: Services.Theme.foreground
            opacity: 0.7
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
        Item { width: parent.width - 150; height: 1 }
        Text {
            visible: popup.items.length > 0
            text: "Clear"
            color: Services.Theme.pillAccent
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: popup.clearAll()
            }
        }
    }

    Text {
        visible: popup.items.length === 0
        text: "Clipboard is empty"
        color: Services.Theme.foreground
        opacity: 0.5
        font.pixelSize: Services.Theme.fontSizeSmall
        font.family: Services.Theme.fontFamily
    }

    Repeater {
        model: popup.items

        delegate: Rectangle {
            id: row
            required property var modelData
            width: parent.width
            height: 34
            radius: 8
            color: rowMa.containsMouse ? Services.Theme.hoverBg : "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                spacing: 8

                Text {
                    text: row.modelData.text
                    color: Services.Theme.foreground
                    font.pixelSize: Services.Theme.fontSizeSmall
                    font.family: Services.Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 28
                    elide: Text.ElideRight
                }
                Text {
                    text: popup.copiedIndex === row.modelData.index ? "\u2713" : "\u29c9"
                    color: popup.copiedIndex === row.modelData.index ? Services.Theme.pillAccent
                         : Qt.rgba(Services.Theme.foreground.r, Services.Theme.foreground.g, Services.Theme.foreground.b, 0.5)
                    font.pixelSize: Services.Theme.fontSizeSmall
                    font.family: Services.Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            MouseArea {
                id: rowMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: popup.copyItem(row.modelData.index)
            }
        }
    }
}
