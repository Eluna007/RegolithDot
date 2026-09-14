pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // "top" | "left" | "right" — only "top" is functional in Stage 1;
    // left/right are wired up in Stage 2 once every pill's internal
    // layout is orientation-aware.
    property string dockPosition: "top"
    // "islands" | "classic"
    property string style: "islands"

    readonly property bool vertical: dockPosition !== "top"

    function setDockPosition(pos) { dockPosition = pos; save() }
    function setStyle(s) { style = s; save() }

    function save() {
        saveFile.setText(JSON.stringify({ dockPosition: root.dockPosition, style: root.style }, null, 2) + "\n")
    }

    property FileView saveFile: FileView {
        path: Qt.resolvedUrl(Quickshell.env("HOME") + "/.config/quickshell/bar-settings.json")
        watchChanges: false
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                var data = JSON.parse(text())
                if (data.dockPosition) root.dockPosition = data.dockPosition
                if (data.style) root.style = data.style
            } catch (e) {}
        }
        onLoadFailed: {}
    }
    Component.onCompleted: Qt.callLater(() => saveFile.reload())
}
