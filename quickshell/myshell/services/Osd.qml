pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property string type: ""
    property real value: 0
    property bool visible: false

    readonly property string icon: {
        if (type === "volume") {
            if (value === 0) return "󰝟"
            if (value < 33)  return "󰕿"
            if (value < 66)  return "󰖀"
            return "󰕾"
        } else {
            if (value < 33) return "󰃞"
            if (value < 66) return "󰃟"
            return "󰃠"
        }
    }

    function show(t: string, v: real): void {
        type = t
        value = v
        visible = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.visible = false
    }
}
