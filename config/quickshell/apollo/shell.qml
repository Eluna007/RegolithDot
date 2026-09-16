import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick
import "bar"
import "panels"
import "panels/tailscale/Tailscale.js" as TS

ShellRoot {
    // Global notification list (shared across all screen instances)
    ListModel { id: notifModel }
    property var notifItems: []

    Timer {
        id: clearNotifTimer
        interval: 300
        repeat: false
        onTriggered: {
            notifModel.clear()
            notifItems = []
        }
    }

    function pushNotification(app, title, body) {
        var item = {
            nid: Date.now(),
            app: app || "Apollo",
            title: title || "",
            body: body || "",
            time: Qt.formatDateTime(new Date(), "hh:mm"),
            closing: false
        }
        notifModel.insert(0, item)
        var next = notifItems.slice()
        next.unshift(item)
        while (next.length > 50)
            next.pop()
        notifItems = next
        while (notifModel.count > 50)
            notifModel.remove(notifModel.count - 1)
    }

    function setNotificationClosing(nid) {
        var next = notifItems.slice()
        for (var i = 0; i < next.length; i++) {
            if (next[i].nid === nid) {
                var item = {}
                for (var key in next[i])
                    item[key] = next[i][key]
                item.closing = true
                next[i] = item
                notifItems = next
                for (var j = 0; j < notifModel.count; j++) {
                    if (notifModel.get(j).nid === nid) {
                        notifModel.setProperty(j, "closing", true)
                        break
                    }
                }
                break
            }
        }
    }

    function removeNotification(nid) {
        var next = []
        for (var i = 0; i < notifItems.length; i++) {
            if (notifItems[i].nid !== nid)
                next.push(notifItems[i])
        }
        notifItems = next
        for (var j = 0; j < notifModel.count; j++) {
            if (notifModel.get(j).nid === nid) {
                notifModel.remove(j)
                break
            }
        }
    }

    NotificationServer {
        keepOnReload: true
        onNotification: notif => {
            pushNotification(notif.appName, notif.summary, notif.body)
            // Forward to toast stacks unless Do Not Disturb is on
            // (notification still lands in the center via notifModel above)
            if (!sys.dnd)
                toastRelay.notify(notif.appName, notif.summary, notif.body)
        }
    }

    // Global quick-settings state, shared across every screen
    QtObject {
        id: sys
        property bool dnd:        false   // suppress notification pop-ups
        property bool caffeine:   false   // inhibit idle / keep awake
        property bool nightLight: false   // warm color filter
    }

    // Warm "night light" filter — quickshell runs/stops hyprsunset with the toggle
    Process {
        id: nightProc
        command: ["hyprsunset", "-t", "4500"]
        running: sys.nightLight
    }

    // ── Shared, machine-wide stats + status pollers ──────────────────────
    // These used to live inside Bar.qml, so every monitor ran its own battery /
    // update / recording polls and could fire duplicate toasts. Hoisted here so
    // they run exactly once; each screen's Bar binds to these values via its
    // `shared` property.
    QtObject {
        id: sharedSys

        // -1 means "no reading yet". It started as 100, which is a plausible
        // value: a bar stuck on a fake full battery is indistinguishable from
        // a real one, and that is exactly how a stale shell instance drawing a
        // pre-fix battery went unnoticed. An impossible sentinel makes the
        // absence of data visible instead.
        property real   battPct:           -1
        property bool   battCharging:       false
        property string battStatus:         ""
        property real   battSecs:           -1   // to empty, or to full when charging
        property real   battHealth:         -1   // % of design capacity remaining
        readonly property bool battKnown:   battPct >= 0
        property int    updateCount:        0
        property int    pacmanUpdateCount:  0
        property int    aurUpdateCount:     0
        property string aurHelper:          ""
        property bool   recordingActive:    false
        property bool   tempWarned:         false

        // Tailscale. Polled here rather than in the panel so the bar icon can
        // show the connection state while the panel is closed, and so the two
        // cannot disagree about it. The panel binds to this and pokes
        // tsProc.running after an action to refresh immediately.
        property string tsRaw:      ""
        property bool   tsInstalled: true
        property var    tsStatus:   TS.emptyStatus()

        // CPU/RAM/WiFi/temp — one instance for the whole shell.
        property var stats: SystemStats { }

        // Battery. The reading comes from scripts/battery.sh next to this
        // file - one implementation, shared with the system-monitor panel and
        // covered by scripts/test-shell-battery.sh, rather than a sysfs loop
        // inlined here where nothing can test it.
        //
        // Absolute path under the shell's own config dir: that directory is
        // where this very file was loaded from, so the script can never be out
        // of step with it, and nothing depends on PATH or an install step.
        property var battProc: Process {
            command: ["sh", "-c",
                "exec \"${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/apollo/scripts/battery.sh\""]
            stdout: SplitParser {
                onRead: d => {
                    // Do not trim before splitting: an empty leading field is
                    // meaningful (no battery on this machine) and trim would
                    // collapse it into the next one.
                    var p = d.replace(/\n+$/, "").split("\t")
                    if (p.length < 2) return
                    var n = parseInt(p[0])
                    sharedSys.battPct = isNaN(n) ? -1 : n
                    var st = p[1].trim()
                    sharedSys.battStatus = st
                    sharedSys.battCharging = (st === "Charging" || st === "Full")
                    var secs = parseInt(p[2])
                    sharedSys.battSecs = isNaN(secs) ? -1 : secs
                    var health = parseInt(p[3])
                    sharedSys.battHealth = isNaN(health) ? -1 : health
                }
            }
            running: true
        }
        property string tsBuffer: ""
        property var tsProc: Process {
            command: ["sh", "-c",
                "command -v tailscale >/dev/null 2>&1 || { printf '__NOTS__'; exit 0; }; " +
                "tailscale status --json 2>/dev/null"]
            stdout: SplitParser { onRead: chunk => sharedSys.tsBuffer += chunk }
            onRunningChanged: {
                if (running) { sharedSys.tsBuffer = ""; return }
                if (sharedSys.tsBuffer.indexOf("__NOTS__") !== -1) {
                    sharedSys.tsInstalled = false
                    sharedSys.tsStatus = TS.emptyStatus()
                    return
                }
                sharedSys.tsInstalled = true
                sharedSys.tsRaw = sharedSys.tsBuffer
                sharedSys.tsStatus = TS.parseStatus(sharedSys.tsBuffer)
            }
        }
        property var tsTimer: Timer {
            interval: 20000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: if (!sharedSys.tsProc.running) sharedSys.tsProc.running = true
        }

        property var battTimer: Timer { interval: 30000; running: true; repeat: true; onTriggered: sharedSys.battProc.running = true }

        // Pending updates (pacman + AUR helper).
        property var updateProc: Process {
            command: ["sh", "-c", "if command -v checkupdates >/dev/null 2>&1; then p=$(checkupdates 2>/dev/null | wc -l); else p=$(pacman -Qu 2>/dev/null | wc -l); fi; if command -v paru >/dev/null 2>&1; then h=paru; a=$(paru -Qua 2>/dev/null | wc -l); elif command -v yay >/dev/null 2>&1; then h=yay; a=$(yay -Qua 2>/dev/null | wc -l); else h=; a=0; fi; printf '%s %s %s\\n' \"$p\" \"$a\" \"$h\""]
            stdout: SplitParser {
                onRead: d => {
                    var p = d.trim().split(/\s+/)
                    sharedSys.pacmanUpdateCount = parseInt(p[0]) || 0
                    sharedSys.aurUpdateCount = parseInt(p[1]) || 0
                    sharedSys.aurHelper = p.length >= 3 ? p[2] : ""
                    sharedSys.updateCount = sharedSys.pacmanUpdateCount + sharedSys.aurUpdateCount
                }
            }
        }
        property var updateTimer: Timer {
            interval: 1800000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: sharedSys.updateProc.running = true
        }
        // Debounce: re-check a few seconds after a pacman transaction settles.
        property var updateRecheck: Timer {
            interval: 4000; repeat: false
            onTriggered: sharedSys.updateProc.running = true
        }
        // Re-run the check whenever pacman writes to its log.
        property var pacmanLog: FileView {
            path: "/var/log/pacman.log"
            watchChanges: true
            onFileChanged: sharedSys.updateRecheck.restart()
        }

        // Screen-recording indicator.
        property var recordingProc: Process {
            command: ["sh", "-c", "pgrep -x 'obs|wf-recorder|gpu-screen-recorder|kooha|simplescreenrecorder' >/dev/null && echo 1 || echo 0"]
            stdout: SplitParser { onRead: d => sharedSys.recordingActive = d.trim() === "1" }
        }
        property var recordingTimer: Timer {
            interval: 10000; running: true; repeat: true; triggeredOnStart: true
            onTriggered: sharedSys.recordingProc.running = true
        }

        // Wake detector: QML timers pause during suspend, so on resume the
        // wall-clock jumps far more than the tick interval. When it does, the
        // machine just woke -> refresh everything immediately.
        property var wakeTimer: Timer {
            property double last: Date.now()
            interval: 30000; running: true; repeat: true
            onTriggered: {
                var now = Date.now()
                if (now - last > interval * 3) {
                    sharedSys.battProc.running = true
                    sharedSys.recordingProc.running = true
                    if (!sharedSys.tsProc.running) sharedSys.tsProc.running = true
                    sharedSys.stats.refresh()
                    sharedSys.updateRecheck.restart()
                }
                last = now
            }
        }

        // CPU-temp warning — one toast for the machine, not one per monitor.
        property var tempTimer: Timer {
            interval: 10000; running: true; repeat: true
            onTriggered: {
                if (sharedSys.stats.cpuTemp >= 75 && !sharedSys.tempWarned) {
                    var msg = "CPU is " + Math.round(sharedSys.stats.cpuTemp) + "C"
                    pushNotification("Apollo", "Temperature warning", msg)
                    if (!sys.dnd) toastRelay.notify("Apollo", "Temperature warning", msg)
                    sharedSys.tempWarned = true
                } else if (sharedSys.stats.cpuTemp < 68) {
                    sharedSys.tempWarned = false
                }
            }
        }
    }

    QtObject {
        id: toastRelay
        signal notify(string app, string title, string body)
    }

    // Relay so external triggers (e.g. brightness keys via IPC) reach every screen's OSD
    QtObject {
        id: osdRelay
        signal fire(string kind, real value)
    }

    // `qs -c apollo ipc call osd set brightness 50`  (don't name it `show` — collides with `qs ipc show`)
    IpcHandler {
        target: "osd"
        function set(kind: string, value: real): void {
            osdRelay.fire(kind, value)
        }
    }

    // `qs -c apollo ipc call notify send Apollo "Title" "Body"` for internal shell messages.
    IpcHandler {
        target: "notify"
        function send(app: string, title: string, body: string): void {
            pushNotification(app, title, body)
            if (!sys.dnd)
                toastRelay.notify(app, title, body)
        }
    }

    // Relay so a keybind can open/toggle a panel on every screen's scope
    QtObject {
        id: panelRelay
        signal toggle(string name)
    }

    // `qs -c apollo ipc call panel toggle wallpaper`
    IpcHandler {
        target: "panel"
        function toggle(name: string): void {
            panelRelay.toggle(name)
        }
    }

    Variants {
        model: Quickshell.screens

        delegate: QtObject {
            id: scope
            required property var modelData

            property string activePanel: ""
            property real   osdValue:   0
            property string osdKind:    ""
            property bool   osdVisible: false

            function open(p) { activePanel = (activePanel === p ? "" : p) }
            function closeAll() { activePanel = "" }
            function showOsd(kind, val) {
                osdKind = kind; osdValue = val; osdVisible = true
                osdTimer.restart()
            }

            property var osdTimer: Timer { interval: 1300; onTriggered: scope.osdVisible = false }

            property var osdRelayConn: Connections {
                target: osdRelay
                function onFire(kind, value) { scope.showOsd(kind, value) }
            }

            property var panelRelayConn: Connections {
                target: panelRelay
                // Open keybind-triggered panels (e.g. the wallpaper picker)
                // only on the monitor that currently has focus, so it shows
                // up where you're looking instead of on every screen.
                function onToggle(name) {
                    var fm = Hyprland.focusedMonitor
                    if (!fm || fm.name === scope.modelData.name) scope.open(name)
                }
            }

            // ── Bar ──────────────────────────────────────────────────────
            property var bar: Bar {
                screen:      scope.modelData
                shared:      sharedSys
                activePanel: scope.activePanel
                onOpenPanel: p  => scope.open(p)
                onShowOsd:  (k,v) => scope.showOsd(k, v)
                onShowToast: (a,t,b) => {
                    pushNotification(a, t, b)
                    toastRelay.notify(a, t, b)
                }
            }

            // Caffeine — inhibits compositor idle while enabled (attached to the
            // always-visible bar so it persists after the panel closes)
            property var idleInhibit: IdleInhibitor {
                window:  scope.bar
                enabled: sys.caffeine
            }

            // ── Click-outside catcher ────────────────────────────────────
            property var catcher: PanelWindow {
                screen: scope.modelData
                anchors { top: true; bottom: true; left: true; right: true }
                margins.top: 42
                exclusiveZone: 0
                color: "transparent"
                visible: scope.activePanel !== "" &&
                         scope.activePanel !== "power" &&
                         scope.activePanel !== "wallpaper" &&
                         scope.activePanel !== "launcher" &&
                         scope.activePanel !== "overview"
                MouseArea { anchors.fill: parent; onClicked: scope.closeAll() }
            }

            // ── Panels ───────────────────────────────────────────────────
            property var calPanel: CalendarPanel {
                screen:        scope.modelData
                visible:       scope.activePanel === "cal"
                notifications: notifItems
                removeNotifFunc: removeNotification
                onClose:       scope.closeAll()
                onClearNotifs: {
                    var next = []
                    for (var i = 0; i < notifItems.length; i++) {
                        var item = {}
                        for (var key in notifItems[i])
                            item[key] = notifItems[i][key]
                        item.closing = true
                        next.push(item)
                    }
                    notifItems = next
                    for (var j = 0; j < notifModel.count; j++)
                        notifModel.setProperty(j, "closing", true)
                    clearNotifTimer.restart()
                }
                onDismissNotif: nid => setNotificationClosing(nid)
            }

            property var qsPanel: QuickSettingsPanel {
                screen:      scope.modelData
                visible:     scope.activePanel === "qs"
                onClose:     scope.closeAll()
                onShowOsd:  (k,v) => scope.showOsd(k, v)
                onOpenPanel: p    => scope.open(p)

                dndOn:        sys.dnd
                caffeineOn:   sys.caffeine
                nightOn:      sys.nightLight
                onToggleDnd:      sys.dnd        = !sys.dnd
                onToggleCaffeine: sys.caffeine   = !sys.caffeine
                onToggleNight:    sys.nightLight = !sys.nightLight
            }

            property var sysPanel: SysMonPanel {
                screen:  scope.modelData
                shared:  sharedSys
                visible: scope.activePanel === "sysmon"
                onClose: scope.closeAll()
            }

            property var wifiPanelWin: WifiPanel {
                screen:  scope.modelData
                visible: scope.activePanel === "net"
                onClose: scope.closeAll()
            }

            property var btPanelWin: BtPanel {
                screen:  scope.modelData
                visible: scope.activePanel === "bt"
                onClose: scope.closeAll()
            }

            property var audioPanel: AudioPanel {
                screen:      scope.modelData
                visible:     scope.activePanel === "audio"
                onClose:     scope.closeAll()
                onShowOsd:  (k,v) => scope.showOsd(k, v)
            }

            property var clipPanel: ClipPanel {
                screen:  scope.modelData
                visible: scope.activePanel === "clip"
                onClose: scope.closeAll()
            }

            property var apollokuPanel: ApollokuPanel {
                screen:  scope.modelData
                visible: scope.activePanel === "apolloku"
                onClose: scope.closeAll()
            }

            property var chessPanel: ChessPanel {
                screen:  scope.modelData
                visible: scope.activePanel === "chess"
                onClose: scope.closeAll()
            }

            property var tailscalePanel: TailscalePanel {
                screen:  scope.modelData
                shared:  sharedSys
                visible: scope.activePanel === "tailscale"
                onClose: scope.closeAll()
            }

            property var powerPanel: PowerPanel {
                screen:  scope.modelData
                visible: scope.activePanel === "power"
                onClose: scope.closeAll()
            }

            property var wallpaperPanel: WallpaperPanel {
                screen:     scope.modelData
                outputName: scope.modelData.name   // apply only to this monitor
                visible:    scope.activePanel === "wallpaper"
                onClose:    scope.closeAll()
            }

            property var overviewPanel: WindowOverview {
                screen:  scope.modelData
                visible: scope.activePanel === "overview"
                onClose: scope.closeAll()
            }

            property var osdWin: OSD {
                screen:  scope.modelData
                visible: scope.osdVisible
                kind:    scope.osdKind
                value:   scope.osdValue
            }

            property var toastWin: ToastStack {
                screen: scope.modelData
                relay:  toastRelay
            }
        }
    }
}
