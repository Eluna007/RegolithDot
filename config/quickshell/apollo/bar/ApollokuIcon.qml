import QtQuick

// The Apolloku mark: a 3x3 sudoku board, drawn rather than borrowed from a
// font. The Nerd Font glyph previously used here (nf-md-view_grid) reads as a
// generic grid — closer to a Steam library icon than a sudoku.
//
// Drawn because at bar size a real sudoku is nine cells and two rules, which
// is a handful of Rectangles and stays crisp at any scale; a 9x9 board or
// actual digits turn to mush below ~40px.
Item {
    id: root

    property color stroke: "#cdd6f4"
    property color fill: stroke
    // Lit cells spell a diagonal, so the mark reads as a puzzle mid-solve
    // rather than an empty grid.
    property var lit: [0, 4, 8, 5]
    property bool solved: false

    implicitWidth: 20
    implicitHeight: 20

    readonly property real line: Math.max(1, Math.round(width / 20))
    readonly property real cell: (width - line * 4) / 3

    function shade(a) { return Qt.rgba(root.stroke.r, root.stroke.g, root.stroke.b, a) }

    // Board edge
    Rectangle {
        anchors.fill: parent
        radius: Math.round(root.width * 0.12)
        color: "transparent"
        border.width: root.line
        border.color: root.shade(root.solved ? 0.95 : 0.75)
        Behavior on border.color { ColorAnimation { duration: 220 } }
    }

    // The two rules each way. A sudoku's defining feature is the 3x3 division,
    // so these are what make the mark legible at 18px.
    Repeater {
        model: 2
        delegate: Rectangle {
            required property int index
            // (index+1) cells plus the rules already passed - not
            // (index+1) pitches, which lands on the next cell instead of in
            // the gap before it.
            x: root.line + (index + 1) * root.cell + index * root.line
            y: root.line
            width: root.line
            height: root.height - root.line * 2
            color: root.shade(0.45)
        }
    }
    Repeater {
        model: 2
        delegate: Rectangle {
            required property int index
            x: root.line
            y: root.line + (index + 1) * root.cell + index * root.line
            width: root.width - root.line * 2
            height: root.line
            color: root.shade(0.45)
        }
    }

    // Filled cells
    Repeater {
        model: 9
        delegate: Rectangle {
            required property int index
            readonly property bool on: root.solved || root.lit.indexOf(index) !== -1

            x: root.line + (index % 3) * (root.cell + root.line) + root.cell * 0.22
            y: root.line + Math.floor(index / 3) * (root.cell + root.line) + root.cell * 0.22
            width: root.cell * 0.56
            height: root.cell * 0.56
            radius: width / 2
            color: on ? root.fill : "transparent"
            opacity: on ? (root.solved ? 1 : 0.9) : 0
            Behavior on opacity { NumberAnimation { duration: 220 } }
        }
    }
}
