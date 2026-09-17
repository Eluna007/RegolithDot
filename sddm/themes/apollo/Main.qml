// Apollo's login screen.
//
// The same shapes the rest of the rice uses — a translucent card on the
// wallpaper, an accent pill, Material 3 easing — drawn with nothing but
// QtQuick, because the greeter's environment is not the desktop's.
//
// Three constraints shaped this file, all of them the same fact from different
// angles: the greeter runs as the unprivileged `sddm` user, before any session
// exists.
//
//   * It cannot read $HOME. Not the wallpaper, not ~/.config, not ~/.face.
//     Everything it draws is copied into /usr/share/sddm/themes/apollo by
//     `apollo-sddm-sync`, which is the only part of this that needs root.
//   * QtQuick.Controls is not imported. A Controls style is a separate package
//     from a separate tree, and a theme that fails to load does not fall back
//     gracefully — SDDM drops to its built-in theme, which looks like the theme
//     "not applying" with nothing anywhere to say why. TextInput and
//     MouseArea cost a few more lines and cannot fail that way.
//   * Nothing here uses `NumberAnimation on <property>`. The whole rice avoids
//     it (see services/Motion.qml) and a check in CI enforces that; a Behavior
//     driven from Component.onCompleted does the same job and reads the same
//     way everywhere.
import QtQuick 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root

    // SDDM resizes the root item to the screen; these are only what the file
    // is authored against, the way upstream's own themes declare them.
    width: 1920
    height: 1080
    color: root.base

    // ── Palette ─────────────────────────────────────────────────────────
    // theme.conf is generated (see apollo-settings/login.go). A key it does
    // not define comes back as an empty string, and an empty string assigned
    // to a color property is *invalid* — QML logs a warning nobody will ever
    // read and paints black. On a login screen that is a black rectangle with
    // no way in, so every read goes through a fallback.
    //
    // config.stringValue() is SDDM 0.20+. Older greeters expose the same keys
    // as plain properties, which return strings too; prefer the typed call
    // when it is there rather than assuming either.
    function conf(key, fallback) {
        var v = ""
        if (typeof config.stringValue === "function")
            v = config.stringValue(key)
        else if (config[key] !== undefined)
            v = config[key]
        return (v && v.length > 0) ? v : fallback
    }

    readonly property color base:     conf("base", "#1e1e2e")
    readonly property color mantle:   conf("mantle", "#181825")
    readonly property color crust:    conf("crust", "#11111b")
    readonly property color surface0: conf("surface0", "#313244")
    readonly property color surface1: conf("surface1", "#45475a")
    readonly property color overlay1: conf("overlay1", "#7f849c")
    readonly property color subtext0: conf("subtext0", "#a6adc8")
    readonly property color text:     conf("text", "#cdd6f4")
    readonly property color accent:   conf("accent", "#cba6f7")
    readonly property color onAccent: conf("onAccent", "#11111b")
    readonly property color error:    conf("error", "#f38ba8")

    readonly property string nfFont: "JetBrainsMono Nerd Font Mono"

    // Material 3 expressive, the same numbers as services/Motion.qml.
    readonly property var curveStandard: [0.2, 0, 0, 1, 1, 1]
    readonly property int dEffects: 200
    readonly property int dSpatial: 500

    // ── State ───────────────────────────────────────────────────────────
    property int sessionIndex: sessionModel.lastIndex
    property string message: ""
    property bool busy: false

    // 0 while the card is off-stage, 1 once it has arrived. Driven from
    // Component.onCompleted rather than by a property-value-source animation.
    property real reveal: 0

    Behavior on reveal {
        NumberAnimation {
            duration: root.dSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: root.curveStandard
        }
    }
    Component.onCompleted: {
        root.reveal = 1
        passwordField.forceActiveFocus()
    }

    // ── Wallpaper ───────────────────────────────────────────────────────
    Image {
        anchors.fill: parent
        // A relative path, resolved against this file — which is the installed
        // theme directory, the only place the greeter can read from.
        source: root.conf("background", "")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // A wallpaper that has not been synced yet leaves `base` showing,
        // which is a colour from the rice rather than a broken-image glyph.
        visible: status === Image.Ready
    }

    // Scrim. The card is translucent like the shell's panels, so the text on
    // it needs the wallpaper held back a little first.
    Rectangle {
        anchors.fill: parent
        color: root.base
        opacity: 0.45
    }

    // ── Clock ───────────────────────────────────────────────────────────
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(parent.height * 0.12)
        spacing: 4
        opacity: root.reveal

        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.text
            font { family: root.nfFont; pixelSize: 72; bold: true }
            text: Qt.formatDateTime(new Date(), "HH:mm")
        }
        Text {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.subtext0
            font { family: root.nfFont; pixelSize: 16 }
            text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
        }
    }

    // One timer, not a binding on a new Date(): a binding would never
    // re-evaluate, so the clock would show the time the greeter started and
    // then stop.
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            var now = new Date()
            clock.text = Qt.formatDateTime(now, "HH:mm")
            dateText.text = Qt.formatDateTime(now, "dddd, d MMMM")
        }
    }

    // ── Login card ──────────────────────────────────────────────────────
    Rectangle {
        id: card
        width: 380
        height: content.implicitHeight + 48
        radius: 18
        color: Qt.rgba(root.mantle.r, root.mantle.g, root.mantle.b, 0.78)
        border.width: 1
        border.color: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.6)

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: Math.round(parent.height * 0.08)

        opacity: root.reveal
        // Rises into place. 24px is the whole distance — far enough to read as
        // motion, near enough that it never looks like the card fell.
        transform: Translate { y: (1 - root.reveal) * 24 }

        // Left/right/top, not fill: the card's height is this layout's
        // implicitHeight, and anchoring the layout's height back to the card
        // would be that binding pointing at itself.
        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 14

            // Avatar. userModel.icon is a path in the user's home, which this
            // greeter cannot read, so it is deliberately not used — a glyph in
            // the accent is honest about what it is.
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 64
                height: 64
                radius: 32
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                border.width: 2
                border.color: root.accent

                Text {
                    anchors.centerIn: parent
                    text: "󰀄"
                    color: root.accent
                    font { family: root.nfFont; pixelSize: 30 }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: sddm.hostName
                color: root.subtext0
                font { family: root.nfFont; pixelSize: 12 }
            }

            // Username
            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 12
                color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.7)
                border.width: 1
                border.color: userField.activeFocus ? root.accent : "transparent"

                Behavior on border.color {
                    ColorAnimation { duration: root.dEffects }
                }

                TextInput {
                    id: userField
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.text
                    font { family: root.nfFont; pixelSize: 14 }
                    selectionColor: root.accent
                    selectedTextColor: root.onAccent
                    text: userModel.lastUser
                    onAccepted: passwordField.forceActiveFocus()
                    KeyNavigation.tab: passwordField
                }
            }

            // Password
            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 12
                color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.7)
                border.width: 1
                border.color: passwordField.activeFocus ? root.accent : "transparent"

                Behavior on border.color {
                    ColorAnimation { duration: root.dEffects }
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    verticalAlignment: Text.AlignVCenter
                    text: "Password"
                    color: root.overlay1
                    font { family: root.nfFont; pixelSize: 14 }
                    visible: passwordField.text.length === 0
                }

                TextInput {
                    id: passwordField
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: root.text
                    font { family: root.nfFont; pixelSize: 14 }
                    selectionColor: root.accent
                    selectedTextColor: root.onAccent
                    onAccepted: root.attemptLogin()
                }
            }

            // Caps lock. Silent caps lock is the single most common reason a
            // password that is definitely right is definitely rejected.
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "󰪛  Caps Lock is on"
                color: root.error
                font { family: root.nfFont; pixelSize: 11 }
                visible: keyboard.capsLock
            }

            // Whatever PAM had to say — a wrong password, an expired account,
            // a locked-out user. Reserving the row's height stops the card
            // resizing under the pointer the moment a login fails.
            Text {
                Layout.fillWidth: true
                Layout.minimumHeight: 16
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.message
                color: root.error
                font { family: root.nfFont; pixelSize: 11 }
            }

            // Log in
            Rectangle {
                id: loginButton
                Layout.fillWidth: true
                height: 40
                radius: 12
                color: root.accent
                opacity: root.busy ? 0.6 : (loginArea.containsMouse ? 0.88 : 1)

                Behavior on opacity {
                    NumberAnimation { duration: root.dEffects }
                }

                Text {
                    anchors.centerIn: parent
                    text: root.busy ? "Signing in…" : "Log in"
                    color: root.onAccent
                    font { family: root.nfFont; pixelSize: 14; bold: true }
                }

                MouseArea {
                    id: loginArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.attemptLogin()
                }
            }

            // Sessions, as pills. A Repeater rather than a dropdown because a
            // dropdown is a Controls widget, and because a machine has two or
            // three sessions — laying them all out is simpler than hiding them
            // behind a control.
            Flow {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                // The Repeater's count, not the model's: SDDM documents
                // sessionModel's roles and lastIndex, not a count property,
                // and an undefined one compares false against everything —
                // the session pills would simply never appear.
                visible: sessions.count > 1

                Repeater {
                    id: sessions
                    model: sessionModel

                    Rectangle {
                        required property int index
                        required property string name

                        height: 24
                        width: label.implicitWidth + 20
                        radius: 12
                        color: index === root.sessionIndex
                               ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                               : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.6)
                        border.width: 1
                        border.color: index === root.sessionIndex ? root.accent : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: root.dEffects }
                        }

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: parent.name
                            color: parent.index === root.sessionIndex ? root.text : root.subtext0
                            font { family: root.nfFont; pixelSize: 11 }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.sessionIndex = parent.index
                        }
                    }
                }
            }
        }
    }

    // ── Power ───────────────────────────────────────────────────────────
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 10
        opacity: root.reveal

        Repeater {
            model: [
                { glyph: "󰐥", label: "Power off", enabled: sddm.canPowerOff, action: "poweroff" },
                { glyph: "󰜉", label: "Restart",   enabled: sddm.canReboot,   action: "reboot" },
                { glyph: "󰤄", label: "Suspend",   enabled: sddm.canSuspend,  action: "suspend" }
            ]

            Rectangle {
                required property var modelData

                width: 40
                height: 40
                radius: 20
                visible: modelData.enabled
                color: powerArea.containsMouse
                       ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22)
                       : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.55)

                Behavior on color {
                    ColorAnimation { duration: root.dEffects }
                }

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.glyph
                    color: powerArea.containsMouse ? root.accent : root.subtext0
                    font { family: root.nfFont; pixelSize: 16 }
                }

                MouseArea {
                    id: powerArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (parent.modelData.action === "poweroff") sddm.powerOff()
                        else if (parent.modelData.action === "reboot") sddm.reboot()
                        else sddm.suspend()
                    }
                }
            }
        }
    }

    // ── Login ───────────────────────────────────────────────────────────
    function attemptLogin() {
        if (root.busy)
            return
        root.message = ""
        root.busy = true
        sddm.login(userField.text, passwordField.text, root.sessionIndex)
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            root.reveal = 0
        }

        function onLoginFailed() {
            root.busy = false
            root.message = "Wrong password"
            passwordField.text = ""
            passwordField.forceActiveFocus()
        }

        // PAM's own words — "account expired", "password must be changed".
        // Upstream themes show this; without it those states look exactly like
        // a typo, and no amount of retyping fixes them.
        function onInformationMessage(message) {
            root.busy = false
            root.message = message
        }
    }
}
