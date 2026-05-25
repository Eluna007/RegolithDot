pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property bool visible: false

    function toggle(): void { visible = !visible }
    function open(): void   { visible = true }
    function close(): void  { visible = false }
}
