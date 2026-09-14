import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../components" as Components
import "../services" as Services
import "." as Modules

Components.Pill {
    id: root
    readonly property bool vertical: Services.BarSettings.vertical

    property var activeAnchor: null
    property bool grabActive: false
    property double lastDismiss: 0

    function openControls(triggerItem) {
        if (controlsPopup.visible || Date.now() - root.lastDismiss < 250) {
            closeControls()
            return
        }
        controlsPopup.anchor.item = triggerItem
        controlsPopup.visible = true
        grabDelay.restart()
    }
    function closeControls() {
        controlsPopup.visible = false
        root.grabActive = false
        root.lastDismiss = Date.now()
    }

    function toggleAudio() {
        if (audioPopup.visible || Date.now() - root.lastDismiss < 250) {
            audioPopup.visible = false
            root.grabActive = false
            root.lastDismiss = Date.now()
        } else {
            audioPopup.anchor.item = volTrigger
            audioPopup.visible = true
            grabDelay.restart()
        }
    }
    function toggleBt() {
        if (btPopup.visible || Date.now() - root.lastDismiss < 250) {
            btPopup.visible = false
            root.grabActive = false
            root.lastDismiss = Date.now()
        } else {
            btPopup.anchor.item = btTrigger
            btPopup.visible = true
            grabDelay.restart()
        }
    }
    function toggleNet() {
        if (netPopup.visible || Date.now() - root.lastDismiss < 250) {
            netPopup.visible = false
            root.grabActive = false
            root.lastDismiss = Date.now()
        } else {
            netPopup.anchor.item = wifiTrigger
            netPopup.visible = true
            grabDelay.restart()
        }
    }
    function togglePower() {
        if (powerPopup.visible || Date.now() - root.lastDismiss < 250) {
            powerPopup.visible = false
            root.grabActive = false
            root.lastDismiss = Date.now()
        } else {
            powerPopup.anchor.item = powerTrigger
            powerPopup.visible = true
            grabDelay.restart()
        }
    }
    function toggleClip() {
        if (clipPopup.visible || Date.now() - root.lastDismiss < 250) {
            clipPopup.visible = false
            root.grabActive = false
            root.lastDismiss = Date.now()
        } else {
            clipPopup.anchor.item = clipTrigger
            clipPopup.visible = true
            grabDelay.restart()
        }
    }
    function toggleQuickToggles() {
        if (togglesPopup.visible || Date.now() - root.lastDismiss < 250) {
            togglesPopup.visible = false
            root.grabActive = false
            root.lastDismiss = Date.now()
        } else {
            togglesPopup.anchor.item = togglesTrigger
            togglesPopup.visible = true
            grabDelay.restart()
        }
    }
    function toggleSysMon() {
        if (sysMonPopup.visible || Date.now() - root.lastDismiss < 250) {
            sysMonPopup.visible = false
            root.grabActive = false
            root.lastDismiss = Date.now()
        } else {
            sysMonPopup.anchor.item = cpuTrigger
            sysMonPopup.visible = true
            grabDelay.restart()
        }
    }
    function toggleSettings() {
        if (settingsPopup.visible || Date.now() - root.lastDismiss < 250) {
            settingsPopup.visible = false
            root.grabActive = false
            root.lastDismiss = Date.now()
        } else {
            settingsPopup.anchor.item = settingsTrigger
            settingsPopup.visible = true
            grabDelay.restart()
        }
    }

    // Grid, not Row — same technique as WorkspacesPill/TrayPill/
    // ApollokuTrigger. rows/columns: -1 means "auto," confirmed working
    // on this Quickshell version via TrayPill's test earlier.
    Grid {
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        rowSpacing: 10
        columnSpacing: 10

        StatItem {
            icon: "\ue266"                       // RAM
            value: (Services.SystemStats.ramUsedMb / 1024).toFixed(1) + "G"
        }

        Item {
            id: cpuTrigger
            width: cpuRow.implicitWidth
            height: cpuRow.implicitHeight

            StatItem {
                id: cpuRow
                icon: "\uf4bc"
                value: Services.SystemStats.cpuPct + "%"
                iconColor: (cpuMa.containsMouse || sysMonPopup.visible)
                           ? Services.Theme.pillAccent
                           : Qt.rgba(Services.Theme.foreground.r, Services.Theme.foreground.g, Services.Theme.foreground.b, 0.7)
            }
            MouseArea {
                id: cpuMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleSysMon()
            }
        }

        StatItem {
            icon: String.fromCodePoint(0xf050f)   // temp
            value: Math.round(Services.SystemStats.cpuTemp) + "\u00b0"
            visible: Services.SystemStats.cpuTemp >= 75
            iconColor: Services.Theme.errorColor
        }
        StatItem {
            icon: Services.SystemStats.battCharging
                  ? String.fromCodePoint(0xf0084)
                  : (Services.SystemStats.battPct > 20 ? String.fromCodePoint(0xf0079) : String.fromCodePoint(0xf007a))
            iconColor: Services.SystemStats.battCharging
                       ? Services.Theme.pillAccent
                       : (Services.SystemStats.battPct <= 20
                          ? Services.Theme.errorColor
                          : Qt.rgba(Services.Theme.foreground.r, Services.Theme.foreground.g, Services.Theme.foreground.b, 0.7))
            value: Services.SystemStats.battPct + "%"
        }

        Item {
            id: wifiTrigger
            width: wifiRow.implicitWidth
            height: wifiRow.implicitHeight

            StatItem {
                id: wifiRow
                icon: String.fromCodePoint(0xf0928)
                value: (Services.SystemStats.wifiSsid !== "") ? Services.SystemStats.wifiSsid : (Services.SystemStats.wifiSignal + "%")
                iconColor: (wifiMa.containsMouse || netPopup.visible)
                           ? Services.Theme.pillAccent
                           : Qt.rgba(Services.Theme.foreground.r, Services.Theme.foreground.g, Services.Theme.foreground.b, 0.7)
            }
            MouseArea {
                id: wifiMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleNet()
            }
        }

        TriggerIcon {
            id: togglesTrigger
            icon: String.fromCodePoint(0xf0493)
            active: togglesPopup.visible
                    || Services.QuickToggles.caffeine
                    || Services.QuickToggles.dnd
                    || Services.QuickToggles.nightLight
                    || Services.QuickToggles.airplane
            onClicked: root.toggleQuickToggles()
        }
        TriggerIcon {
            id: volTrigger
            icon: Services.Audio.muted ? String.fromCodePoint(0xf0581) : String.fromCodePoint(0xf057e)
            active: audioPopup.visible
            onClicked: root.toggleAudio()
        }
        TriggerIcon {
            id: brightTrigger
            icon: String.fromCodePoint(0xf05a8)
            active: controlsPopup.visible
            onClicked: root.openControls(brightTrigger)
        }
        TriggerIcon {
            id: btTrigger
            icon: String.fromCodePoint(0xf00af)
            active: btPopup.visible
            onClicked: root.toggleBt()
        }
        TriggerIcon {
            id: clipTrigger
            icon: String.fromCodePoint(0xf328)
            active: clipPopup.visible
            onClicked: root.toggleClip()
        }
        TriggerIcon {
            id: settingsTrigger
            icon: String.fromCodePoint(0xf013)
            active: settingsPopup.visible
            onClicked: root.toggleSettings()
        }
        TriggerIcon {
            id: powerTrigger
            icon: String.fromCodePoint(0xf0425)
            active: powerPopup.visible
            onClicked: root.togglePower()
        }
    }

    Item {
        Timer { id: grabDelay; interval: 90; onTriggered: root.grabActive = true }

        Modules.SystemMonitorPopup {
            id: sysMonPopup
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom | Edges.Left
        }
        HyprlandFocusGrab {
            windows: [sysMonPopup]
            active: root.grabActive && sysMonPopup.visible
            onCleared: { sysMonPopup.visible = false; root.grabActive = false; root.lastDismiss = Date.now() }
        }

        Modules.QuickTogglesPopup {
            id: togglesPopup
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom | Edges.Left
        }
        HyprlandFocusGrab {
            windows: [togglesPopup]
            active: root.grabActive && togglesPopup.visible
            onCleared: { togglesPopup.visible = false; root.grabActive = false; root.lastDismiss = Date.now() }
        }

        Modules.AudioPopup {
            id: audioPopup
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom | Edges.Left
        }
        HyprlandFocusGrab {
            windows: [audioPopup]
            active: root.grabActive && audioPopup.visible
            onCleared: { audioPopup.visible = false; root.grabActive = false; root.lastDismiss = Date.now() }
        }

        Modules.ControlsPopup {
            id: controlsPopup
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom | Edges.Left
        }
        HyprlandFocusGrab {
            windows: [controlsPopup]
            active: root.grabActive && controlsPopup.visible
            onCleared: root.closeControls()
        }

        Modules.BluetoothPopup {
            id: btPopup
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom | Edges.Left
        }
        HyprlandFocusGrab {
            windows: [btPopup]
            active: root.grabActive && btPopup.visible
            onCleared: { btPopup.visible = false; root.grabActive = false; root.lastDismiss = Date.now() }
        }

        Modules.NetworkPopup {
            id: netPopup
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom | Edges.Left
        }
        HyprlandFocusGrab {
            windows: [netPopup]
            active: root.grabActive && netPopup.visible
            onCleared: { netPopup.visible = false; root.grabActive = false; root.lastDismiss = Date.now() }
        }

        Modules.PowerPopup {
            id: powerPopup
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom | Edges.Left
        }
        HyprlandFocusGrab {
            windows: [powerPopup]
            active: root.grabActive && powerPopup.visible
            onCleared: { powerPopup.visible = false; root.grabActive = false; root.lastDismiss = Date.now() }
        }

        Modules.ClipboardPopup {
            id: clipPopup
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom | Edges.Left
        }
        HyprlandFocusGrab {
            windows: [clipPopup]
            active: root.grabActive && clipPopup.visible
            onCleared: { clipPopup.visible = false; root.grabActive = false; root.lastDismiss = Date.now() }
        }

        Modules.SettingsPopup {
            id: settingsPopup
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom | Edges.Left
        }
        HyprlandFocusGrab {
            windows: [settingsPopup]
            active: root.grabActive && settingsPopup.visible
            onCleared: { settingsPopup.visible = false; root.grabActive = false; root.lastDismiss = Date.now() }
        }
    }

    // Row (icon beside text) when horizontal; Column (icon above text,
    // both horizontally centered) when vertical. Column permits cross-axis
    // anchors just like Row does (it only manages the Y axis), so this
    // avoids the Grid/Flow anchor restriction entirely — two real
    // positioners swapped via visibility, not a Flow/Grid workaround.
    component StatItem: Item {
        id: statItemRoot
        property string icon: ""
        property string value: ""
        property color iconColor: Qt.rgba(Services.Theme.foreground.r, Services.Theme.foreground.g, Services.Theme.foreground.b, 0.7)
        readonly property bool vertical: Services.BarSettings.vertical

        implicitWidth: vertical ? colLayout.implicitWidth : rowLayout.implicitWidth
        implicitHeight: vertical ? colLayout.implicitHeight : rowLayout.implicitHeight

        Row {
            id: rowLayout
            visible: !statItemRoot.vertical
            spacing: 4
            Text {
                text: statItemRoot.icon
                color: statItemRoot.iconColor
                font.pixelSize: Services.Theme.fontSizeNormal
                font.family: Services.Theme.fontFamily
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: statItemRoot.value
                color: Services.Theme.foreground
                font.pixelSize: Services.Theme.fontSizeSmall
                font.family: Services.Theme.fontFamily
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Column {
            id: colLayout
            visible: statItemRoot.vertical
            spacing: 1
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: statItemRoot.icon
                color: statItemRoot.iconColor
                font.pixelSize: Services.Theme.fontSizeNormal
                font.family: Services.Theme.fontFamily
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: statItemRoot.value
                color: Services.Theme.foreground
                font.pixelSize: Services.Theme.fontSizeSmall - 3
                font.family: Services.Theme.fontFamily
            }
        }
    }

    component TriggerIcon: Item {
        id: trig
        property string icon: ""
        property bool active: false
        signal clicked()
        width: icn.implicitWidth + 4
        // Fixed height, not parent.height — in vertical/Grid mode with
        // columns:1, Grid's own height is the SUM of every stacked
        // child's height, so deriving this item's height from that same
        // sum would be a circular binding.
        height: 20

        Text {
            id: icn
            anchors.verticalCenter: parent.verticalCenter
            text: trig.icon
            color: (ma.containsMouse || trig.active)
                   ? Services.Theme.pillAccent
                   : Qt.rgba(Services.Theme.foreground.r, Services.Theme.foreground.g, Services.Theme.foreground.b, 0.7)
            font.pixelSize: Services.Theme.fontSizeNormal
            font.family: Services.Theme.fontFamily
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: trig.clicked()
        }
    }
}
