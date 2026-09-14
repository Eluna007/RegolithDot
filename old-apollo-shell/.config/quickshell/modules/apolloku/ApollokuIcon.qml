import QtQuick
import "../../services" as Services

// The bar wordmark: APOLLOKU laid out as one row of a sudoku grid, each
// letter in its own cell. Ported from bhaveshsooka/omadoku's Icon.qml — a
// single row (not a 3x3 grid) reads far better at bar-icon size than a
// packed square would, since each letter gets the icon's full height
// instead of a ninth of it.
Item {
  id: root

  property color foreground: Services.Theme.foreground
  property string fontFamily: Services.Theme.fontFamily
  property int barSize: 28
  property string letters: "APOLLOKU"

  // Lit up on a win: the cells fill and the edge brightens.
  property bool solved: false

  readonly property real line: 1
  readonly property real cellHeight: Math.max(14, Math.round(barSize * 0.70))
  readonly property real cellWidth: Math.max(7, Math.round(cellHeight * 0.50))
  readonly property int cells: letters.length

  function shade(alpha) {
    return Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, alpha)
  }

  implicitWidth: cellWidth * cells + line
  implicitHeight: cellHeight

  Rectangle {
    anchors.fill: parent
    color: root.solved ? root.shade(0.20) : "transparent"
    border.width: root.line
    border.color: root.shade(root.solved ? 0.85 : 0.55)
    Behavior on color { ColorAnimation { duration: 220 } }
    Behavior on border.color { ColorAnimation { duration: 220 } }
  }

  Repeater {
    model: root.cells - 1
    delegate: Rectangle {
      required property int index
      x: Math.round(root.line + (index + 1) * root.cellWidth - root.line / 2)
      y: root.line
      width: root.line
      height: root.height - root.line * 2
      color: root.shade(0.32)
    }
  }

  Repeater {
    model: root.cells
    delegate: Text {
      required property int index
      x: root.line + index * root.cellWidth
      width: root.cellWidth
      height: root.height
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      textFormat: Text.PlainText
      text: root.letters.charAt(index)
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Math.max(7, Math.round(root.cellHeight * 0.50))
      font.bold: true
      renderType: Text.NativeRendering
    }
  }
}
