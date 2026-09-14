import QtQuick
import "../services" as Services

// A Row on a top-docked bar, a Column on a left/right-docked one.
// Implemented with Flow rather than swapping actual Row/Column types —
// Flow only wraps when it runs out of cross-axis space, and since we never
// constrain the cross-axis here, an unconstrained Flow behaves exactly
// like a single-line Row or Column depending on its flow direction.
Flow {
    id: root
    flow: Services.BarSettings.vertical ? Flow.TopToBottom : Flow.LeftToRight
}
