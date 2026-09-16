import QtQuick

// The Tailscale mark: three nodes joined into a mesh.
//
// Not Tailscale's own logo, which is a 3x3 grid of dots - at bar size that is
// very nearly the Apolloku mark sitting a few pixels away, and two icons that
// read the same are worse than one that is merely approximate. A triangle of
// linked nodes says "machines connected to each other", which is the thing.
Item {
    id: root

    property color stroke: "#cdd6f4"
    // Lit when the tailnet is up, so the bar carries the state and not just
    // the affordance.
    property bool on: false

    implicitWidth: 19
    implicitHeight: 19

    readonly property real r: Math.max(2, width * 0.15)
    readonly property real line: Math.max(1, Math.round(width / 19))

    function shade(a) { return Qt.rgba(root.stroke.r, root.stroke.g, root.stroke.b, a) }

    // Node centres: apex, bottom-left, bottom-right.
    readonly property var nodes: [
        { x: width * 0.5,  y: height * 0.2 },
        { x: width * 0.2,  y: height * 0.78 },
        { x: width * 0.8,  y: height * 0.78 }
    ]

    // Edges, drawn as thin rotated rectangles - three lines needs no Shapes
    // import, which would be one more thing that has to resolve at load.
    Repeater {
        model: [[0, 1], [0, 2], [1, 2]]
        delegate: Rectangle {
            required property var modelData
            readonly property var a: root.nodes[modelData[0]]
            readonly property var b: root.nodes[modelData[1]]
            readonly property real dx: b.x - a.x
            readonly property real dy: b.y - a.y

            x: a.x
            y: a.y - root.line / 2
            width: Math.sqrt(dx * dx + dy * dy)
            height: root.line
            transformOrigin: Item.Left
            rotation: Math.atan2(dy, dx) * 180 / Math.PI
            color: root.shade(root.on ? 0.55 : 0.3)
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    Repeater {
        model: 3
        delegate: Rectangle {
            required property int index
            readonly property var n: root.nodes[index]
            x: n.x - root.r
            y: n.y - root.r
            width: root.r * 2
            height: root.r * 2
            radius: root.r
            color: root.on ? root.stroke : "transparent"
            border.width: root.line
            border.color: root.shade(root.on ? 1.0 : 0.7)
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }
}
