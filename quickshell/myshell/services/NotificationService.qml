pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    property var notifications: []
    readonly property int count: notifications.length

    readonly property bool hasNotifs: count > 0

    function dismiss(id) {
        notifications = notifications.filter(n => n.id !== id)
    }

    function dismissAll() {
        notifications = []
    }

    NotificationServer {
        id: server
        actionsSupported: true
        bodyHtmlSupported: false
        bodyMarkupSupported: false
        bodySupported: true
        iconSupported: true

        onNotification: notif => {
            const entry = {
                id:      notif.id,
                appName: notif.appName,
                summary: notif.summary,
                body:    notif.body,
                urgency: notif.urgency,
                time:    new Date().toLocaleTimeString(Qt.locale(), "hh:mm"),
                actions: notif.actions ?? [],
                raw:     notif
            }
            root.notifications = [entry].concat(root.notifications).slice(0, 40)
        }
    }
}
