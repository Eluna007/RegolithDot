import QtQuick
import Quickshell.Io
import "../components" as Components
import "../services" as Services

Components.AnchoredPopup {
    id: popup
    contentWidth: 280

    property var networks: []
    property bool scanning: false
    property string connectingSsid: ""
    property string pwPromptSsid: ""
    property string errorText: ""

    // Same 5-band thresholds as Caelestia's getNetworkIcon: floor(pct/20)
    // clamped 0-4. Codepoints verified against independent MDI sources,
    // and the level-4 one already matches the plain wifi icon used
    // elsewhere in the shell.
    function signalIcon(pct) {
        var level = Math.max(0, Math.min(4, Math.floor(pct / 20)))
        var points = [0xf092f, 0xf091f, 0xf0922, 0xf0925, 0xf0928]
        return String.fromCodePoint(points[level])
    }

    function scan() {
        popup.scanning = true
        rescanProc.buf = ""
        rescanProc.running = true
    }

    function connectTo(ssid, password) {
        popup.errorText = ""
        popup.connectingSsid = ssid
        popup.pwPromptSsid = ""
        connectProc.targetSsid = ssid
        connectProc.errOut = ""
        connectProc.command = password
            ? ["nmcli", "device", "wifi", "connect", ssid, "password", password]
            : ["nmcli", "device", "wifi", "connect", ssid]
        connectProc.running = true
    }

    onVisibleChanged: if (visible) scan()

    Item {
        Process {
            id: rescanProc
            command: ["sh", "-c", "nmcli device wifi rescan >/dev/null 2>&1; nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE device wifi list"]
            property string buf: ""
            stdout: SplitParser {
                onRead: data => rescanProc.buf += data + "\n"
            }
            onExited: (code, status) => {
                popup.scanning = false
                var lines = rescanProc.buf.trim().split("\n")
                var seen = {}
                var list = []
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(":")
                    if (parts.length < 4) continue
                    var ssid = parts[0].trim()
                    if (!ssid || seen[ssid]) continue
                    seen[ssid] = true
                    list.push({
                        ssid: ssid,
                        signal: parseInt(parts[1]) || 0,
                        secured: parts[2].trim() !== "" && parts[2].trim() !== "--",
                        inUse: parts[3].trim() === "*"
                    })
                }
                list.sort((a, b) => b.signal - a.signal)
                popup.networks = list
            }
        }

        Process {
            id: connectProc
            property string targetSsid: ""
            property string errOut: ""
            stderr: SplitParser { onRead: data => connectProc.errOut += data + "\n" }
            onExited: (code, status) => {
                popup.connectingSsid = ""
                if (code === 0) {
                    popup.errorText = ""
                    popup.scan()
                } else if (/secrets|password|802-11-wireless-security/i.test(connectProc.errOut)) {
                    popup.pwPromptSsid = connectProc.targetSsid
                } else {
                    popup.errorText = "Couldn't connect to " + connectProc.targetSsid
                }
            }
        }
    }

    Row {
        width: parent.width
        Text {
            text: "Wi-Fi"
            color: Services.Theme.foreground
            opacity: 0.7
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
        Item { width: parent.width - 60; height: 1 }
        Text {
            text: popup.networks.length + " found"
            color: Services.Theme.foreground
            opacity: 0.5
            font.pixelSize: Services.Theme.fontSizeSmall - 3
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Text {
        visible: popup.errorText !== ""
        text: popup.errorText
        color: Services.Theme.errorColor
        font.pixelSize: Services.Theme.fontSizeSmall
        font.family: Services.Theme.fontFamily
        wrapMode: Text.WordWrap
        width: parent.width
    }

    Text {
        visible: !popup.scanning && popup.networks.length === 0
        text: "No networks found"
        color: Services.Theme.foreground
        opacity: 0.5
        font.pixelSize: Services.Theme.fontSizeSmall
        font.family: Services.Theme.fontFamily
    }

    Repeater {
        model: popup.networks

        delegate: Column {
            id: netRow
            required property var modelData
            width: parent.width
            spacing: 4

            Rectangle {
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
                        text: popup.signalIcon(netRow.modelData.signal)
                        color: netRow.modelData.inUse ? Services.Theme.pillAccent
                             : Qt.rgba(Services.Theme.foreground.r, Services.Theme.foreground.g, Services.Theme.foreground.b, 0.7)
                        font.pixelSize: Services.Theme.fontSizeSmall
                        font.family: Services.Theme.fontFamily
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: netRow.modelData.ssid
                        color: Services.Theme.foreground
                        font.pixelSize: Services.Theme.fontSizeSmall
                        font.family: Services.Theme.fontFamily
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 118
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: netRow.modelData.inUse
                        text: "connected"
                        color: Services.Theme.pillAccent
                        opacity: 0.8
                        font.pixelSize: Services.Theme.fontSizeSmall - 2
                        font.family: Services.Theme.fontFamily
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        visible: popup.connectingSsid === netRow.modelData.ssid
                        text: "\u2026"
                        color: Services.Theme.foreground
                        font.pixelSize: Services.Theme.fontSizeSmall
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        visible: netRow.modelData.secured
                        text: String.fromCodePoint(0xf033e)
                        color: Services.Theme.pillTertiary
                        font.pixelSize: Services.Theme.fontSizeSmall
                        font.family: Services.Theme.fontFamily
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !netRow.modelData.inUse && popup.connectingSsid === ""
                    onClicked: {
                        if (netRow.modelData.secured)
                            popup.pwPromptSsid = netRow.modelData.ssid
                        else
                            popup.connectTo(netRow.modelData.ssid, "")
                    }
                }
            }

            Row {
                visible: popup.pwPromptSsid === netRow.modelData.ssid
                width: parent.width
                spacing: 6

                Rectangle {
                    width: parent.width - 70
                    height: 28
                    radius: 8
                    color: Services.Theme.pillColor
                    border.width: 1
                    border.color: Services.Theme.pillBorder

                    TextInput {
                        id: pwField
                        anchors.fill: parent
                        anchors.margins: 6
                        color: Services.Theme.foreground
                        font.pixelSize: Services.Theme.fontSizeSmall
                        font.family: Services.Theme.fontFamily
                        echoMode: TextInput.Password
                        focus: popup.pwPromptSsid === netRow.modelData.ssid
                        onAccepted: popup.connectTo(netRow.modelData.ssid, text)
                    }
                }
                Text {
                    text: "Connect"
                    color: Services.Theme.pillAccent
                    font.pixelSize: Services.Theme.fontSizeSmall
                    font.family: Services.Theme.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.connectTo(netRow.modelData.ssid, pwField.text)
                    }
                }
            }
        }
    }

    // Moonlit's actual rescan button: full-width pill, spinning icon while
    // scanning, disabled meanwhile.
    Rectangle {
        width: parent.width
        height: 30
        radius: 999
        color: Services.Theme.pillColor
        border.width: 1
        border.color: Services.Theme.pillBorder

        Row {
            anchors.centerIn: parent
            spacing: 6
            Text {
                id: rescanIcon
                text: String.fromCodePoint(0xf0453)
                color: Services.Theme.foreground
                font.pixelSize: Services.Theme.fontSizeSmall
                font.family: Services.Theme.fontFamily
                anchors.verticalCenter: parent.verticalCenter
                RotationAnimation on rotation {
                    running: popup.scanning
                    loops: Animation.Infinite
                    from: 0; to: 360
                    duration: 900
                }
            }
            Text {
                text: popup.scanning ? "Scanning\u2026" : "Rescan networks"
                color: Services.Theme.foreground
                font.pixelSize: Services.Theme.fontSizeSmall
                font.family: Services.Theme.fontFamily
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !popup.scanning
            cursorShape: Qt.PointingHandCursor
            onClicked: popup.scan()
        }
    }
}
