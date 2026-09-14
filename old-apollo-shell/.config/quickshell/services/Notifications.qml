pragma Singleton
import QtQuick
import Quickshell.Services.Notifications
import "." as Services

QtObject {
    id: root

    property var history: []   // persists until cleared, capped at 50
    property var toasts: []    // auto-expiring popups, capped at 5

    function push(app, title, body) {
        var item = {
            nid: Date.now() + Math.random(),
            app: app || "Notification",
            title: title || "",
            body: body || "",
            time: Qt.formatDateTime(new Date(), "hh:mm")
        }
        var h = history.slice()
        h.unshift(item)
        if (h.length > 50) h.pop()
        history = h

        if (!Services.QuickToggles.dnd) {
            var t = toasts.slice()
            t.push(item)
            if (t.length > 5) t.shift()
            toasts = t
        }
    }

    function dismissHistory(nid) {
        history = history.filter(n => n.nid !== nid)
    }
    function clearHistory() { history = [] }
    function dismissToast(nid) {
        toasts = toasts.filter(n => n.nid !== nid)
    }

    property NotificationServer server: NotificationServer {
        keepOnReload: true
        onNotification: notif => root.push(notif.appName, notif.summary, notif.body)
    }
}
