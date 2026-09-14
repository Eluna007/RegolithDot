import QtQuick
import Quickshell.Services.Mpris
import "../components" as Components
import "../services" as Services

Components.AnchoredPopup {
    id: popup
    contentWidth: 300

    function fmtTime(s) {
        if (!s || s < 0 || !isFinite(s)) return "0:00"
        var m = Math.floor(s / 60)
        var sec = Math.floor(s % 60)
        return m + ":" + (sec < 10 ? "0" : "") + sec
    }

    Text {
        text: "Audio"
        color: Services.Theme.foreground
        opacity: 0.7
        font.pixelSize: Services.Theme.fontSizeSmall
        font.family: Services.Theme.fontFamily
    }

    // ---- Now playing, one card per active MPRIS player ----
    Repeater {
        model: Mpris.players

        delegate: Column {
            id: card
            required property MprisPlayer modelData
            width: parent.width
            spacing: 8

            Timer {
                interval: 1000
                repeat: true
                running: card.modelData.isPlaying && popup.visible
                onTriggered: card.modelData.positionChanged()
            }

            Row {
                width: parent.width
                spacing: 10

                Rectangle {
                    width: 48; height: 48; radius: 10
                    color: Services.Theme.pillColor
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: card.modelData.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        visible: (card.modelData.trackArtUrl ?? "") !== ""
                        asynchronous: true
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: (card.modelData.trackArtUrl ?? "") === ""
                        text: String.fromCodePoint(0xf0388)
                        color: Qt.rgba(Services.Theme.foreground.r, Services.Theme.foreground.g, Services.Theme.foreground.b, 0.5)
                        font.pixelSize: 20
                        font.family: Services.Theme.fontFamily
                    }
                }

                Column {
                    width: parent.width - 58
                    spacing: 2
                    Text {
                        text: card.modelData.trackTitle || card.modelData.identity || "Unknown"
                        color: Services.Theme.foreground
                        font.pixelSize: Services.Theme.fontSizeSmall
                        font.family: Services.Theme.fontFamily
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        text: {
                            var a = card.modelData.trackArtist || ""
                            var al = card.modelData.trackAlbum || ""
                            return al && a ? a + " \u00b7 " + al : (a || al)
                        }
                        visible: text !== ""
                        color: Services.Theme.foreground
                        opacity: 0.6
                        font.pixelSize: Services.Theme.fontSizeSmall - 3
                        font.family: Services.Theme.fontFamily
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            // Seek bar
            Column {
                width: parent.width
                spacing: 2
                visible: card.modelData.lengthSupported && card.modelData.length > 0

                Item {
                    width: parent.width
                    height: 8
                    Rectangle { anchors.fill: parent; radius: 99; color: Services.Theme.pillBorder }
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, card.modelData.position / Math.max(1, card.modelData.length)))
                        height: 8; radius: 99
                        color: Services.Theme.pillAccent
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: card.modelData.canSeek
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: mouse => {
                            var frac = Math.max(0, Math.min(1, mouse.x / width))
                            var target = frac * card.modelData.length
                            card.modelData.seek(target - card.modelData.position)
                        }
                    }
                }
                Row {
                    width: parent.width
                    Text {
                        text: popup.fmtTime(card.modelData.position)
                        color: Services.Theme.foreground
                        opacity: 0.5
                        font.pixelSize: Services.Theme.fontSizeSmall - 4
                        font.family: Services.Theme.fontFamily
                    }
                    Item { width: parent.width - 60; height: 1 }
                    Text {
                        text: popup.fmtTime(card.modelData.length)
                        color: Services.Theme.foreground
                        opacity: 0.5
                        font.pixelSize: Services.Theme.fontSizeSmall - 4
                        font.family: Services.Theme.fontFamily
                    }
                }
            }

            // Controls
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                component MediaBtn: Rectangle {
                    property string icon: ""
                    property bool enabledHere: true
                    signal clicked()
                    width: 30; height: 30; radius: 9
                    color: mbMa.containsMouse ? Services.Theme.hoverBg : "transparent"
                    opacity: enabledHere ? 1 : 0.3
                    Text {
                        anchors.centerIn: parent
                        text: parent.icon
                        color: Services.Theme.foreground
                        font.pixelSize: 15
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

                MediaBtn {
                    icon: String.fromCodePoint(0xf04ae)
                    enabledHere: card.modelData.canGoPrevious
                    onClicked: card.modelData.previous()
                }
                MediaBtn {
                    icon: card.modelData.isPlaying ? String.fromCodePoint(0xf03e4) : String.fromCodePoint(0xf040a)
                    enabledHere: card.modelData.canTogglePlaying
                    onClicked: card.modelData.togglePlaying()
                }
                MediaBtn {
                    icon: String.fromCodePoint(0xf04db)
                    enabledHere: card.modelData.canControl
                    onClicked: card.modelData.stop()
                }
                MediaBtn {
                    icon: String.fromCodePoint(0xf04ad)
                    enabledHere: card.modelData.canGoNext
                    onClicked: card.modelData.next()
                }
            }

            Rectangle { width: parent.width; height: 1; color: Services.Theme.pillBorder }
        }
    }

    Row {
        visible: Mpris.players.values.length === 0
        spacing: 8
        Text {
            text: String.fromCodePoint(0xf038a)
            color: Qt.rgba(Services.Theme.foreground.r, Services.Theme.foreground.g, Services.Theme.foreground.b, 0.5)
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
        }
        Text {
            text: "Nothing playing"
            color: Services.Theme.foreground
            opacity: 0.5
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
        }
    }

    // ---- Master volume ----
    Row {
        width: parent.width
        spacing: 8
        Text {
            text: Services.Audio.muted ? String.fromCodePoint(0xf0581) : String.fromCodePoint(0xf057e)
            color: Services.Theme.foreground
            font.pixelSize: Services.Theme.fontSizeNormal
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Services.Audio.toggleMute() }
        }
        Item {
            width: parent.width - 60
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            Rectangle { width: parent.width; height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: Services.Theme.pillBorder }
            Rectangle { width: parent.width * Services.Audio.volume; height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: Services.Theme.pillAccent }
            MouseArea {
                anchors.fill: parent
                onPressed: mouse => Services.Audio.setVolume(mouse.x / width)
                onPositionChanged: mouse => { if (pressed) Services.Audio.setVolume(mouse.x / width) }
            }
        }
        Text {
            text: Math.round(Services.Audio.volume * 100) + "%"
            color: Services.Theme.foreground
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ---- Mic ----
    Text {
        text: "Microphone"
        visible: Services.Audio.hasMic
        color: Services.Theme.foreground
        opacity: 0.7
        font.pixelSize: Services.Theme.fontSizeSmall
        font.family: Services.Theme.fontFamily
    }
    Row {
        width: parent.width
        spacing: 8
        visible: Services.Audio.hasMic
        Text {
            text: Services.Audio.micMuted ? String.fromCodePoint(0xf0131) : String.fromCodePoint(0xf0130)
            color: Services.Theme.pillSecondary
            font.pixelSize: Services.Theme.fontSizeNormal
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Services.Audio.toggleMicMute() }
        }
        Item {
            width: parent.width - 60
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            Rectangle { width: parent.width; height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: Services.Theme.pillBorder }
            Rectangle { width: parent.width * Services.Audio.micVolume; height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: Services.Theme.pillSecondary }
            MouseArea {
                anchors.fill: parent
                onPressed: mouse => Services.Audio.setMicVolume(mouse.x / width)
                onPositionChanged: mouse => { if (pressed) Services.Audio.setMicVolume(mouse.x / width) }
            }
        }
        Text {
            text: Math.round(Services.Audio.micVolume * 100) + "%"
            color: Services.Theme.foreground
            font.pixelSize: Services.Theme.fontSizeSmall
            font.family: Services.Theme.fontFamily
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
