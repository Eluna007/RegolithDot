import QtQuick

// The chess mark: a checkerboard. Drawn rather than taken from a font, for the
// same reason as the Apolloku mark next to it in the bar.
//
// A board, not a piece: a knight silhouette is the usual choice but needs real
// curves to read as anything but a blob at 19px, while alternating squares are
// unmistakably chess at any size - and unmistakably *not* the sudoku grid
// sitting beside it, which is three lines and four dots.
Item {
    id: root

    property color stroke: "#cdd6f4"
    // 4x4 rather than 8x8: at bar size an eight-square board is a grey smear.
    readonly property int cells: 4

    implicitWidth: 19
    implicitHeight: 19

    readonly property real line: Math.max(1, Math.round(width / 19))
    readonly property real cell: (width - line * 2) / cells

    function shade(a) { return Qt.rgba(root.stroke.r, root.stroke.g, root.stroke.b, a) }

    Rectangle {
        anchors.fill: parent
        radius: Math.round(root.width * 0.14)
        color: "transparent"
        border.width: root.line
        border.color: root.shade(0.8)
    }

    Item {
        anchors.fill: parent
        anchors.margins: root.line
        clip: true                      // keep the squares inside the rounded edge

        Repeater {
            model: root.cells * root.cells
            delegate: Rectangle {
                required property int index
                readonly property int col: index % root.cells
                readonly property int row: Math.floor(index / root.cells)
                // Dark square when the coordinates share parity, exactly as on
                // a real board with a1 dark.
                readonly property bool dark: ((col + row) % 2) === 0

                x: col * root.cell
                y: row * root.cell
                width: root.cell
                height: root.cell
                color: dark ? root.shade(0.85) : "transparent"
            }
        }
    }
}
