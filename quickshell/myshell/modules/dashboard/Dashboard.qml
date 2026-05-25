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

                            Rectangle {
                                Layout.fillHeight: true
                                Layout.preferredWidth: height
                                radius: height / 2
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
                                    font.pixelSize: 48
                                    visible: Services.Media.artUrl === ""
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
                                    { label: "CPU Temp", value: Services.SystemStats.cpuTemp, max: 100, unit: "°C", color: "#ff6b9d", icon: "󰻠", sublabel: "" },
                                    { label: "NVMe Temp", value: Services.SystemStats.nvmeTemp, max: 85, unit: "°C", color: "#89b4fa", icon: "󰋊", sublabel: "" },
                                    { label: "Memory", value: Services.SystemStats.ramPercent, max: 100, unit: "%", color: "#a6e3a1", icon: "󰍛", sublabel: Services.SystemStats.ramStr },
                                    { label: "Storage", value: Services.SystemStats.diskPercent, max: 100, unit: "%", color: "#efbd94", icon: "󰋊", sublabel: Services.SystemStats.diskStr }
                                ]

                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 12
                                    color: Root.Theme.pillBgHover

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Item {
                                            width: 80; height: 80
                                            Layout.alignment: Qt.AlignHCenter

                                            Canvas {
                                                id: canvas
                                                anchors.fill: parent
                                                property real progress: modelData.value / modelData.max
                                                property color arcColor: modelData.color

                                                onPaint: {
                                                    const ctx = getContext("2d")
                                                    const cx = width / 2
                                                    const cy = height / 2
                                                    const r = 34
                                                    const start = -Math.PI / 2
                                                    const end = start + (2 * Math.PI * progress)
                                                    ctx.clearRect(0, 0, width, height)
                                                    ctx.beginPath()
                                                    ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                                                    ctx.strokeStyle = "#44ffffff"
                                                    ctx.lineWidth = 6
                                                    ctx.stroke()
                                                    ctx.beginPath()
                                                    ctx.arc(cx, cy, r, start, end)
                                                    ctx.strokeStyle = arcColor
                                                    ctx.lineWidth = 6
                                                    ctx.lineCap = "round"
                                                    ctx.stroke()
                                                }

                                                onProgressChanged: requestPaint()
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: Math.round(modelData.value) + modelData.unit
                                                color: Root.Theme.textPrimary
                                                font.pixelSize: 13
                                                font.weight: Font.Bold
                                            }
                                        }

                                        Text {
                                            text: modelData.icon + "  " + modelData.label
                                            color: Root.Theme.textMuted
                                            font.pixelSize: 10
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        Text {
                                            text: modelData.sublabel
                                            color: Root.Theme.textMuted
                                            font.pixelSize: 9
                                            Layout.alignment: Qt.AlignHCenter
                                            visible: modelData.sublabel !== ""
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
