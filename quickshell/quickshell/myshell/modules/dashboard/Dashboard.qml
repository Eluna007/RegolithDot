pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../services" as Services
import "../../" as Root

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Services.Dashboard.visible ? 420 : 1
    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None


    QtObject {
        id: calendarModel
        property var days: {
            const now = new Date()
            const year = now.getFullYear()
            const month = now.getMonth()
            const today = now.getDate()
            const firstDay = new Date(year, month, 1).getDay()
            const daysInMonth = new Date(year, month + 1, 0).getDate()
            const daysInPrevMonth = new Date(year, month, 0).getDate()
            const startOffset = (firstDay + 6) % 7
            const result = []
            for (let i = startOffset - 1; i >= 0; i--)
                result.push({ day: daysInPrevMonth - i, isCurrentMonth: false, isToday: false })
            for (let d = 1; d <= daysInMonth; d++)
                result.push({ day: d, isCurrentMonth: true, isToday: d === today })
            const remaining = 42 - result.length
            for (let n = 1; n <= remaining; n++)
                result.push({ day: n, isCurrentMonth: false, isToday: false })
            return result
        }
    }

    Item {
        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: Services.Dashboard.close()
        }

        Item {
            id: panel
            property int currentTab: 0

            width: 720
            height: 380
            anchors.horizontalCenter: parent.horizontalCenter

            y: Services.Dashboard.visible ? 8 : -height - 10
            opacity: Services.Dashboard.visible ? 1 : 0

            Behavior on y {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.fill: parent
                radius: 20
                color: Root.Theme.pillBg

                ColumnLayout {
                    anchors { fill: parent; margins: 16 }
                    spacing: 12

                    // Tabs
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Repeater {
                            model: [
                                { icon: "󰕰", label: "Dashboard" },
                                { icon: "󰝚", label: "Media" },
                                { icon: "󰻠", label: "Performance" },
                                { icon: "󰙀", label: "Workspaces" }
                            ]

                            delegate: Item {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                implicitHeight: 36

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 6

                                        Text {
                                            text: modelData.icon
                                            color: panel.currentTab === index ? Root.Theme.textAccent : Root.Theme.textMuted
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: modelData.label
                                            color: panel.currentTab === index ? Root.Theme.textAccent : Root.Theme.textMuted
                                            font.pixelSize: 12
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 2
                                        radius: 1
                                        color: Root.Theme.textAccent
                                        opacity: panel.currentTab === index ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: panel.currentTab = index
                                }
                            }
                        }
                    }

                    // Content
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // Dashboard tab
                        RowLayout {
                            anchors.fill: parent
                            spacing: 10
                            visible: panel.currentTab === 0
                            opacity: visible ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            // Calendar
                            Rectangle {
                                Layout.fillHeight: true
                                Layout.preferredWidth: 200
                                radius: 12
                                color: Root.Theme.pillBgHover

                                ColumnLayout {
                                    anchors { fill: parent; margins: 12 }
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: Qt.formatDateTime(new Date(), "MMMM yyyy")
                                            color: Root.Theme.textPrimary
                                            font.pixelSize: 12
                                            font.weight: Font.Bold
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: Qt.formatDateTime(new Date(), "d")
                                            color: Root.Theme.textAccent
                                            font.pixelSize: 20
                                            font.weight: Font.Bold
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Repeater {
                                            model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                                            delegate: Text {
                                                required property string modelData
                                                Layout.fillWidth: true
                                                text: modelData
                                                color: Root.Theme.textMuted
                                                font.pixelSize: 9
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 7
                                        rowSpacing: 2
                                        columnSpacing: 0

                                        Repeater {
                                            model: calendarModel.days
                                            delegate: Rectangle {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                implicitHeight: 22
                                                radius: 5
                                                color: modelData.isToday ? Root.Theme.textAccent : "transparent"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.day > 0 ? modelData.day : ""
                                                    color: modelData.isToday ? "white" :
                                                           modelData.isCurrentMonth ? Root.Theme.textPrimary : Root.Theme.textMuted
                                                    font.pixelSize: 9
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillHeight: true }
                                }
                            }

                            // Weather
                            Rectangle {
                                Layout.fillHeight: true
                                Layout.fillWidth: true
                                radius: 12
                                color: Root.Theme.pillBgHover

                                ColumnLayout {
                                    anchors { fill: parent; margins: 12 }
                                    spacing: 8

                                    RowLayout {
                                        spacing: 10
                                        Text { text: Services.Weather.icon; color: Root.Theme.textPrimary; font.pixelSize: 28 }
                                        ColumnLayout {
                                            spacing: 2
                                            Text { text: Services.Weather.temperature; color: Root.Theme.textPrimary; font.pixelSize: 22; font.weight: Font.Bold }
                                            Text { text: Services.Weather.description; color: Root.Theme.textMuted; font.pixelSize: 11 }
                                        }
                                    }

                                    Text { text: "Feels like " + Services.Weather.feelsLike; color: Root.Theme.textMuted; font.pixelSize: 10 }
                                    Text { text: "Humidity " + Services.Weather.humidity; color: Root.Theme.textMuted; font.pixelSize: 10 }

                                    Item { Layout.fillHeight: true }

                                    Text { text: Services.Weather.city; color: Root.Theme.textAccent; font.pixelSize: 10 }
                                }
                            }

                            // Media preview
                            Rectangle {
                                Layout.fillHeight: true
                                Layout.fillWidth: true
                                radius: 12
                                color: Root.Theme.pillBgHover

                                ColumnLayout {
                                    anchors { fill: parent; margins: 12 }
                                    spacing: 8

                                    Rectangle {
                                        Layout.alignment: Qt.AlignHCenter
                                        width: 80; height: 80
                                        radius: 40
                                        color: Root.Theme.pillBgActive
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: Services.Media.artUrl
                                            fillMode: Image.PreserveAspectCrop
                                            visible: Services.Media.artUrl !== ""
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰝚"
                                            color: Root.Theme.textMuted
                                            font.pixelSize: 24
                                            visible: Services.Media.artUrl === ""
                                        }
                                    }

                                    Text {
                                        text: Services.Media.stopped ? "Nothing playing" : Services.Media.title
                                        color: Root.Theme.textPrimary
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Text {
                                        text: Services.Media.artist
                                        color: Root.Theme.textMuted
                                        font.pixelSize: 10
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    RowLayout {
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 16
                                        Text { text: "󰒮"; color: Root.Theme.textPrimary; font.pixelSize: 16; MouseArea { anchors.fill: parent; onClicked: Services.Media.previous() } }
                                        Text { text: Services.Media.playing ? "󰏤" : "󰐊"; color: Root.Theme.textAccent; font.pixelSize: 20; MouseArea { anchors.fill: parent; onClicked: Services.Media.playPause() } }
                                        Text { text: "󰒭"; color: Root.Theme.textPrimary; font.pixelSize: 16; MouseArea { anchors.fill: parent; onClicked: Services.Media.next() } }
                                    }
                                }
                            }
                        }

                        // Media tab
                        RowLayout {
                            anchors.fill: parent
                            spacing: 12
                            visible: panel.currentTab === 1
                            opacity: visible ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            Item {
                                Layout.fillHeight: true
                                Layout.preferredWidth: height

                                Canvas {
                                    id: eqCanvas
                                    anchors.fill: parent
                                    property var barData: Services.CavaAudio.bars
                                    property color accent: Root.Theme.textAccent
                                    readonly property real artRadius: (height - 64) / 2
                                    onBarDataChanged: requestPaint()
                                    onAccentChanged: requestPaint()
                                    onPaint: {
                                        const ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        const cx = width / 2, cy = height / 2
                                        const innerR = artRadius + 6
                                        const maxBarH = 24
                                        const bars = barData, n = bars.length
                                        if (n === 0) return
                                        const barW = Math.max(2, (2 * Math.PI * innerR / n) * 0.55)
                                        for (let i = 0; i < n; i++) {
                                            const angle = (i / n) * 2 * Math.PI - Math.PI / 2
                                            const h = (bars[i] / 100) * maxBarH
                                            if (h < 1.5) continue
                                            ctx.beginPath()
                                            ctx.strokeStyle = Qt.rgba(accent.r, accent.g, accent.b, 1)
                                            ctx.lineWidth = barW
                                            ctx.lineCap = "round"
                                            ctx.globalAlpha = 0.7 + 0.3 * (bars[i] / 100)
                                            ctx.moveTo(cx + Math.cos(angle) * (innerR + 1), cy + Math.sin(angle) * (innerR + 1))
                                            ctx.lineTo(cx + Math.cos(angle) * (innerR + h), cy + Math.sin(angle) * (innerR + h))
                                            ctx.stroke()
                                        }
                                        ctx.globalAlpha = 1
                                    }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.height - 64
                                    height: parent.height - 64
                                    radius: height / 2
                                    color: Root.Theme.pillBgActive
                                    clip: true

                                    NumberAnimation on rotation {
                                        from: 0; to: 360
                                        duration: 14000
                                        loops: Animation.Infinite
                                        running: Services.Media.playing
                                    }

                                    Image {
                                        anchors.fill: parent
                                        source: Services.Media.artUrl
                                        fillMode: Image.PreserveAspectCrop
                                        visible: Services.Media.artUrl !== ""
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰝚"
                                        color: Root.Theme.textMuted
                                        font.pixelSize: 40
                                        visible: Services.Media.artUrl === ""
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 8

                                Item { Layout.fillHeight: true }

                                Text {
                                    text: Services.Media.stopped ? "Nothing playing" : Services.Media.title
                                    color: Root.Theme.textPrimary
                                    font.pixelSize: 18
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: Services.Media.artist
                                    color: Root.Theme.textMuted
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: Services.Media.album
                                    color: Root.Theme.textMuted
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 4; radius: 2; color: "#44ffffff"
                                        Rectangle {
                                            width: parent.width * Services.Media.progress
                                            height: parent.height; radius: parent.radius
                                            color: Root.Theme.textAccent
                                            Behavior on width { NumberAnimation { duration: 500 } }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: Services.Media.positionStr; color: Root.Theme.textMuted; font.pixelSize: 10 }
                                        Item { Layout.fillWidth: true }
                                        Text { text: Services.Media.lengthStr; color: Root.Theme.textMuted; font.pixelSize: 10 }
                                    }
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 28
                                    Text { text: "󰒮"; color: Root.Theme.textPrimary; font.pixelSize: 22; MouseArea { anchors.fill: parent; onClicked: Services.Media.previous() } }
                                    Text { text: Services.Media.playing ? "󰏤" : "󰐊"; color: Root.Theme.textAccent; font.pixelSize: 30; MouseArea { anchors.fill: parent; onClicked: Services.Media.playPause() } }
                                    Text { text: "󰒭"; color: Root.Theme.textPrimary; font.pixelSize: 22; MouseArea { anchors.fill: parent; onClicked: Services.Media.next() } }
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }

                        // Performance tab
                        RowLayout {
                            anchors.fill: parent
                            spacing: 10
                            visible: panel.currentTab === 2
                            opacity: visible ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            Repeater {
                                model: [
                                    { label: "CPU",  unit: "%", useAccent: true  },
                                    { label: "GPU",  unit: "%", useAccent: false },
                                    { label: "RAM",  unit: "%", useAccent: true  },
                                    { label: "Disk", unit: "%", useAccent: false }
                                ]

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 12
                                    color: Root.Theme.pillBgHover

                                    property real gaugeValue: {
                                        if (index === 0) return Services.SystemStats.cpuPercent
                                        if (index === 1) return Services.SystemStats.gpuPercent
                                        if (index === 2) return Services.SystemStats.ramPercent
                                        return Services.SystemStats.diskPercent
                                    }

                                    property string sublabelText: {
                                        if (index === 0) return Services.SystemStats.cpuTemp + "°C"
                                        if (index === 1) return Services.SystemStats.gpuFreqCur + " MHz"
                                        if (index === 2) return Services.SystemStats.ramStr
                                        return Services.SystemStats.diskStr
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Item {
                                            width: 110; height: 110
                                            Layout.alignment: Qt.AlignHCenter

                                            Canvas {
                                                id: gaugeCanvas
                                                anchors.fill: parent
                                                property real progress: Math.min(1, Math.max(0, gaugeValue / 100))
                                                property color fillColor: modelData.useAccent ? Root.Theme.textAccent : Root.Theme.tertiary
                                                onProgressChanged: requestPaint()
                                                onFillColorChanged: requestPaint()
                                                onPaint: {
                                                    const ctx = getContext("2d")
                                                    ctx.clearRect(0, 0, width, height)
                                                    const cx = width / 2, cy = height / 2 + 6, r = 44
                                                    const segs = 24
                                                    const startA = (215 / 180) * Math.PI
                                                    const sweep = (300 / 180) * Math.PI
                                                    const segA = sweep / segs
                                                    const gap = segA * 0.18
                                                    const filled = Math.round(progress * segs)
                                                    const fc = Qt.rgba(fillColor.r, fillColor.g, fillColor.b, 1)
                                                    for (let i = 0; i < segs; i++) {
                                                        const sa = startA + i * segA
                                                        const ea = sa + segA - gap
                                                        const active = i < filled
                                                        if (active) {
                                                            ctx.beginPath()
                                                            ctx.arc(cx, cy, r, sa, ea)
                                                            ctx.strokeStyle = fc
                                                            ctx.lineWidth = 16
                                                            ctx.globalAlpha = 0.08
                                                            ctx.lineCap = "butt"
                                                            ctx.stroke()
                                                        }
                                                        ctx.beginPath()
                                                        ctx.arc(cx, cy, r, sa, ea)
                                                        ctx.strokeStyle = active ? fc : "#ffffff"
                                                        ctx.lineWidth = 7
                                                        ctx.globalAlpha = active ? 0.9 : 0.1
                                                        ctx.lineCap = "butt"
                                                        ctx.stroke()
                                                    }
                                                    ctx.globalAlpha = 0.28
                                                    ctx.strokeStyle = "#ffffff"
                                                    ctx.lineWidth = 1.5
                                                    ;[0, 0.25, 0.5, 0.75, 1.0].forEach(p => {
                                                        const a = startA + p * sweep
                                                        ctx.beginPath()
                                                        ctx.moveTo(cx + Math.cos(a) * (r - 11), cy + Math.sin(a) * (r - 11))
                                                        ctx.lineTo(cx + Math.cos(a) * (r + 14), cy + Math.sin(a) * (r + 14))
                                                        ctx.stroke()
                                                    })
                                                    ctx.globalAlpha = 1
                                                }
                                            }

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                anchors.verticalCenterOffset: 6
                                                spacing: 1
                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: Math.round(gaugeValue) + modelData.unit
                                                    color: Root.Theme.textPrimary
                                                    font.pixelSize: 15
                                                    font.weight: Font.Bold
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: modelData.label
                                            color: modelData.useAccent ? Root.Theme.textAccent : Root.Theme.tertiary
                                            font.pixelSize: 10
                                            font.weight: Font.SemiBold
                                            font.letterSpacing: 1
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: sublabelText
                                            color: Root.Theme.textMuted
                                            font.pixelSize: 9
                                        }
                                    }
                                }
                            }
                        }

                        // Workspaces tab
                        GridLayout {
                            anchors.fill: parent
                            columns: 5
                            rowSpacing: 8
                            columnSpacing: 8
                            visible: panel.currentTab === 3
                            opacity: visible ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            Repeater {
                                model: 10

                                delegate: Rectangle {
                                    required property int index
                                    readonly property int wsId: index + 1
                                    readonly property bool isActive: wsId === Services.Hypr.activeWsId
                                    readonly property bool isOccupied: Services.Hypr.workspaces.values.some(ws => ws.id === wsId)

                                    Layout.fillWidth: true
                                    implicitHeight: 60
                                    radius: 12
                                    color: isActive ? Root.Theme.pillBgActive :
                                           isOccupied ? Root.Theme.pillBgHover :
                                                        Root.Theme.pillBg

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 2

                                        Text {
                                            text: wsId
                                            color: isActive ? Root.Theme.textAccent : Root.Theme.textPrimary
                                            font.pixelSize: 16
                                            font.weight: Font.Bold
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        Text {
                                            text: isOccupied ? "●" : "○"
                                            color: isActive ? Root.Theme.textAccent : Root.Theme.textMuted
                                            font.pixelSize: 8
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: Services.Hypr.dispatch("workspace " + parent.wsId)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
