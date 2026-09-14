import QtQuick
import "../services" as Services

// A single floating "pill" - the base building block of the whole shell.
// Put your module's content directly inside <Pill> ... </Pill> (it becomes
// a normal QML child) and it gets the shared glass look + morph animation
// for free.
//
// Style-aware: in "islands" mode (default) each pill is its own floating
// glass capsule. In "classic" mode individual pill backgrounds disappear
// (radius/border/fill all drop out) since the whole bar gets one
// continuous solid background instead — wired in shell.qml.
Rectangle {
    id: pill

    default property alias contentChildren: inner.children

    property int horizontalPadding: Services.Theme.pillPaddingH
    property int verticalPadding: Services.Theme.pillPaddingV
    readonly property bool classic: Services.BarSettings.style === "classic"

    implicitWidth: inner.implicitWidth + horizontalPadding * 2
    implicitHeight: inner.implicitHeight + verticalPadding * 2

    color: classic ? "transparent" : Services.Theme.pillColor
    border.color: classic ? "transparent" : Services.Theme.pillBorder
    border.width: classic ? 0 : 1
    radius: classic ? 0 : height / 2

    Behavior on implicitWidth {
        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
    }
    Behavior on color {
        ColorAnimation { duration: 400 }
    }

    Row {
        id: inner
        anchors.centerIn: parent
        spacing: 0
    }
}
