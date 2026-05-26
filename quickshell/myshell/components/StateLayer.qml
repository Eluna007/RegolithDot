import QtQuick

Item {
    id: root

    property real radius: parent?.radius ?? 0
    signal clicked()
    signal pressed()

    property real _rx: width / 2
    property real _ry: height / 2
    property real _rr: 0
    property real _rop: 0

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "#ffffff"
        opacity: _ma.pressed ? 0.10 : _ma.containsMouse ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    Item {
        anchors.fill: parent
        clip: true
        Rectangle {
            x: root._rx - width / 2
            y: root._ry - height / 2
            width: root._rr * 2
            height: root._rr * 2
            radius: root._rr
            color: "#ffffff"
            opacity: root._rop
        }
    }

    MouseArea {
        id: _ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: e => {
            root._rx = e.x; root._ry = e.y
            root._rr = 0; root._rop = 0.15
            _expand.restart()
            root.pressed()
        }
        onReleased: _fade.restart()
        onClicked: root.clicked()
    }

    NumberAnimation {
        id: _expand
        target: root; property: "_rr"
        to: Math.sqrt(root.width * root.width + root.height * root.height)
        duration: 400; easing.type: Easing.OutCubic
        onStopped: if (!_ma.pressed) _fade.restart()
    }
    NumberAnimation {
        id: _fade
        target: root; property: "_rop"
        to: 0; duration: 300; easing.type: Easing.OutCubic
    }
}
