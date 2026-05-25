pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int current: parseInt(currentFile.text()) || 0
    readonly property int max: parseInt(maxFile.text()) || 1
    readonly property int percent: Math.round((current / max) * 100)

    readonly property string icon: {
        if (percent < 33) return "󰃞"
        if (percent < 66) return "󰃟"
        return "󰃠"
    }

    onPercentChanged: Osd.show("brightness", percent)

    FileView {
        id: currentFile
        path: "/sys/class/backlight/intel_backlight/brightness"
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: maxFile
        path: "/sys/class/backlight/intel_backlight/max_brightness"
    }
}
