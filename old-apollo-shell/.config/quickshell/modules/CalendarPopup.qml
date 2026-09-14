import QtQuick
import Quickshell.Services.Mpris
import "../components" as Components
import "../services" as Services

Components.AnchoredPopup {
    id: popup
    contentWidth: 300

    property var calDate: new Date()

    Item {
        Timer {
            interval: 1000
            running: popup.visible
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                var now = new Date()
                bigClock.text = Qt.formatDateTime(now, "hh:mm:ss")
                dateLabel.text = Qt.formatDateTime(now, "dddd, MMMM d")
                if (now.getDate() !== popup.calDate.getDate() ||
                    now.getMonth() !== popup.calDate.getMonth() ||
                    now.getFullYear() !== popup.calDate.getFullYear())
                    popup.calDate = now
            }
        }
    }

    // ---- Big clock header ----
    Column {
        width: parent.width
        spacing: 2
        Text {
            id: bigClock
            color: Services.Theme.foreground
            font.pixelSize: 30
            font.bold: true
            font.family: Services.Theme.fontFamily
        }
        Text {
            id: dateLabel
            color: Services.Theme.foreground
            opacity: 0.6
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
        }
    }

    // ---- Month grid ----
    Column {
        width: parent.width
        spacing: 4

        Row {
            width: parent.width
            Repeater {
                model: ["M","T","W","T","F","S","S"]
                delegate: Text {
                    required property var modelData
                    width: parent.parent.width / 7
                    text: modelData
                    horizontalAlignment: Text.AlignHCenter
                    color: Services.Theme.foreground
                    opacity: 0.5
                    font.pixelSize: Services.Theme.fontSizeSmall - 4
                    font.family: Services.Theme.fontFamily
                }
            }
        }

        Grid {
            id: dayGrid
            width: parent.width
            columns: 7

            readonly property int today: popup.calDate.getDate()
            readonly property int totalDays: new Date(popup.calDate.getFullYear(), popup.calDate.getMonth() + 1, 0).getDate()
            readonly property int firstDay: (new Date(popup.calDate.getFullYear(), popup.calDate.getMonth(), 1).getDay() + 6) % 7

            Repeater {
                model: dayGrid.firstDay + dayGrid.totalDays
                delegate: Item {
                    required property int index
                    readonly property int day: index - dayGrid.firstDay + 1
                    readonly property bool valid: day >= 1
                    readonly property bool isToday: day === dayGrid.today

                    width: dayGrid.width / 7
                    height: 30

                    Rectangle {
                        anchors.centerIn: parent
                        width: 24; height: 24; radius: 8
                        visible: parent.valid
                        color: parent.isToday ? Services.Theme.pillAccent : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: parent.parent.day
                            color: parent.parent.isToday ? Services.Theme.background : Services.Theme.foreground
                            opacity: parent.parent.isToday ? 1 : 0.8
                            font.pixelSize: Services.Theme.fontSizeSmall - 2
                            font.family: Services.Theme.fontFamily
                        }
                    }
                }
            }
        }
    }

    Rectangle { width: parent.width; height: 1; color: Services.Theme.pillBorder }

    // ---- Now playing (compact) ----
    Row {
        width: parent.width
        spacing: 10
        visible: Mpris.players.values.length > 0

        readonly property MprisPlayer player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

        Rectangle {
            width: 36; height: 36; radius: 8
            color: Services.Theme.pillColor
            clip: true
            Image {
                anchors.fill: parent
                source: parent.parent.player ? (parent.parent.player.trackArtUrl ?? "") : ""
                fillMode: Image.PreserveAspectCrop
                visible: parent.parent.player && (parent.parent.player.trackArtUrl ?? "") !== ""
                asynchronous: true
            }
            Text {
                anchors.centerIn: parent
                visible: !(parent.parent.player && (parent.parent.player.trackArtUrl ?? "") !== "")
                text: String.fromCodePoint(0xf0388)
                color: Qt.rgba(Services.Theme.foreground.r, Services.Theme.foreground.g, Services.Theme.foreground.b, 0.5)
                font.pixelSize: 15
                font.family: Services.Theme.fontFamily
            }
        }

        Column {
            width: parent.width - 36 - 110
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: parent.parent.player ? (parent.parent.player.trackTitle || parent.parent.player.identity || "") : ""
                color: Services.Theme.foreground
                font.pixelSize: Services.Theme.fontSizeSmall
                font.family: Services.Theme.fontFamily
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: parent.parent.player ? (parent.parent.player.trackArtist || "") : ""
                color: Services.Theme.foreground
                opacity: 0.6
                font.pixelSize: Services.Theme.fontSizeSmall - 3
                font.family: Services.Theme.fontFamily
                elide: Text.ElideRight
                width: parent.width
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            component MiniBtn: Rectangle {
                property string icon: ""
                property bool enabledHere: true
                signal clicked()
                width: 26; height: 26; radius: 8
                color: mbMa.containsMouse ? Services.Theme.hoverBg : "transparent"
                opacity: enabledHere ? 1 : 0.3
                Text {
                    anchors.centerIn: parent
                    text: parent.icon
                    color: Services.Theme.foreground
                    font.pixelSize: 12
                    font.family: Services.Theme.fontFamily
                }
                MouseArea {
                    id: mbMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: parent.enabledHere
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.clicked()
                }
            }

            MiniBtn {
                icon: String.fromCodePoint(0xf04ae)
                enabledHere: parent.parent.player ? parent.parent.player.canGoPrevious : false
                onClicked: parent.parent.player.previous()
            }
            MiniBtn {
                icon: parent.parent.player && parent.parent.player.isPlaying ? String.fromCodePoint(0xf03e4) : String.fromCodePoint(0xf040a)
                enabledHere: parent.parent.player ? parent.parent.player.canTogglePlaying : false
                onClicked: parent.parent.player.togglePlaying()
            }
            MiniBtn {
                icon: String.fromCodePoint(0xf04ad)
                enabledHere: parent.parent.player ? parent.parent.player.canGoNext : false
                onClicked: parent.parent.player.next()
            }
        }
    }

    Rectangle { width: parent.width; height: 1; color: Services.Theme.pillBorder; visible: Mpris.players.values.length > 0 }

    // ---- Notification history ----
    Row {
        width: parent.width
        Text {
            text: "Notifications"
            color: Services.Theme.foreground
            opacity: 0.7
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
        Item { width: parent.width - 150; height: 1 }
        Text {
            visible: Services.Notifications.history.length > 0
            text: "Clear"
            color: Services.Theme.pillAccent
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.Notifications.clearHistory()
            }
        }
    }

    Column {
        width: parent.width
        spacing: 6
        visible: Services.Notifications.history.length === 0
        Text {
            text: "You're all caught up"
            color: Services.Theme.foreground
            opacity: 0.5
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
        }
    }

    Repeater {
        model: Services.Notifications.history

        delegate: Rectangle {
            id: row
            required property var modelData
            width: parent.width
            height: bodyCol.implicitHeight + 20
            radius: 12
            color: Services.Theme.pillColor
            border.width: 1
            border.color: Services.Theme.pillBorder

            Column {
                id: bodyCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                spacing: 2

                Row {
                    width: parent.width
                    Text {
                        text: row.modelData.app
                        color: Services.Theme.foreground
                        opacity: 0.6
                        font.pixelSize: Services.Theme.fontSizeSmall - 3
                        font.family: Services.Theme.fontFamily
                    }
                    Item { width: parent.width - 100; height: 1 }
                    Text {
                        text: row.modelData.time
                        color: Services.Theme.foreground
                        opacity: 0.4
                        font.pixelSize: Services.Theme.fontSizeSmall - 3
                        font.family: Services.Theme.fontFamily
                    }
                }
                Text {
                    text: row.modelData.title
                    color: Services.Theme.foreground
                    font.pixelSize: Services.Theme.fontSizeSmall
                    font.family: Services.Theme.fontFamily
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    visible: row.modelData.body !== ""
                    text: row.modelData.body
                    color: Services.Theme.foreground
                    opacity: 0.65
                    font.pixelSize: Services.Theme.fontSizeSmall - 2
                    font.family: Services.Theme.fontFamily
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    width: parent.width
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Services.Notifications.dismissHistory(row.modelData.nid)
            }
        }
    }
}
