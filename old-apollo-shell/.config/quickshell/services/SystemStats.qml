pragma Singleton
import Quickshell.Io
import QtQuick

// Shell-polled system stats — all /proc + sysfs reads, no external service
// dependencies (UPower, etc.), so nothing here is Hyprland-version-specific.
Item {
    id: root
    visible: false

    property int    cpuPct:     0
    property int    ramUsedMb:  0
    property int    ramTotalMb: 1
    property real   cpuTemp:    0
    property int    wifiSignal: 0
    property string wifiSsid:   ""
    property var    _prevCpu:   []
    property var    cpuHistory: []   // last 40 samples, for the sparkline

    property real   battPct:       100
    property bool   battCharging:  false

    Process {
        id: cpuProc
        command: ["sh", "-c", "awk '/^cpu /{print $2,$3,$4,$5,$6,$7,$8}' /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                var f = data.trim().split(" ").map(Number)
                if (root._prevCpu.length === 7) {
                    var idle = f[3], total = f.reduce((a,b)=>a+b,0)
                    var pIdle = root._prevCpu[3], pTotal = root._prevCpu.reduce((a,b)=>a+b,0)
                    var dt = total - pTotal
                    root.cpuPct = dt > 0 ? Math.round((1-(idle-pIdle)/dt)*100) : 0
                    var hist = root.cpuHistory.slice()
                    hist.push(root.cpuPct)
                    if (hist.length > 40) hist.shift()
                    root.cpuHistory = hist
                }
                root._prevCpu = f
            }
        }
    }

    Process {
        id: ramProc
        command: ["sh", "-c", "free -m | awk 'NR==2{print $3, $2}'"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(" ")
                root.ramUsedMb  = parseInt(p[0]) || 0
                root.ramTotalMb = parseInt(p[1]) || 1
            }
        }
    }

    Process {
        id: tempProc
        command: ["sh", "-c", 'for n in k10temp coretemp cpu_thermal soc_thermal thinkpad acpitz; do for h in /sys/class/hwmon/*; do read -r hn < "$h/name" 2>/dev/null || continue; [ "$hn" = "$n" ] || continue; read -r t < "$h/temp1_input" 2>/dev/null || continue; [ -n "$t" ] && [ "$t" -gt 0 ] && { echo $((t/1000)); exit 0; }; done; done; for z in /sys/class/thermal/thermal_zone*; do read -r ty < "$z/type" 2>/dev/null || continue; case "$ty" in x86_pkg_temp|*cpu*|*CPU*|*pkg*|*soc*) read -r t < "$z/temp" 2>/dev/null || continue; [ -n "$t" ] && [ "$t" -gt 0 ] && { echo $((t/1000)); exit 0; }; ;; esac; done; read -r t < /sys/class/thermal/thermal_zone0/temp 2>/dev/null && [ -n "$t" ] && [ "$t" -gt 0 ] && echo $((t/1000))']
        stdout: SplitParser {
            onRead: data => { var v = parseFloat(data); if (v > 0) root.cpuTemp = v }
        }
    }

    Process {
        id: wifiSigProc
        command: ["sh", "-c", "awk 'NR==3{gsub(/\\./,\"\",$3); v=int($3*100/70); print (v>100?100:v)}' /proc/net/wireless 2>/dev/null || echo 0"]
        stdout: SplitParser { onRead: data => root.wifiSignal = parseInt(data) || 0 }
    }

    Process {
        id: wifiSsidProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '/^yes/{print $2; exit}'"]
        stdout: SplitParser { onRead: data => root.wifiSsid = data.trim() }
    }

    // Battery: which BAT device varies by hardware, so try BAT0 then BAT1.
    Process {
        id: battProc
        command: ["sh", "-c", "for b in BAT0 BAT1; do d=/sys/class/power_supply/$b; [ -d \"$d\" ] && paste <(cat $d/capacity 2>/dev/null) <(cat $d/status 2>/dev/null) && exit 0; done; echo -e '100\\tUnknown'"]
        stdout: SplitParser {
            onRead: d => {
                var p = d.trim().split("\t")
                if (p.length >= 2) {
                    var n = parseInt(p[0])
                    if (!isNaN(n)) root.battPct = n
                    var s = p[1].trim()
                    root.battCharging = (s === "Charging" || s === "Full")
                }
            }
        }
    }

    function refreshFast() {
        cpuProc.running = true
        ramProc.running = true
        tempProc.running = true
        wifiSigProc.running = true
        battProc.running = true
    }
    function refresh() {
        refreshFast()
        wifiSsidProc.running = true
    }

    // Bumped to 1s while something (the System Monitor popup) actually
    // wants live-feeling data — the 5s timer above still runs regardless,
    // this just adds extra samples on top while anyone's watching.
    property bool fastPoll: false

    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refreshFast() }
    Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: wifiSsidProc.running = true }
    Timer { interval: 1000; running: root.fastPoll; repeat: true; onTriggered: root.refreshFast() }
}
