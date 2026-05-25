import QtQuick
import "../../../services" as Services

Text {
    text: Services.Hypr.activeWindowTitle
    color: "white"
    font.pixelSize: 12
    elide: Text.ElideRight
    maximumLineCount: 1

    Behavior on opacity {
        NumberAnimation { duration: 150 }
    }

    opacity: Services.Hypr.activeWindowTitle.length > 0 ? 1 : 0
}
