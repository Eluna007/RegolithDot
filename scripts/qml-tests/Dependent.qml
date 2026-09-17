import QtQuick

// Stands in for a picker layout: something a Loader builds which cannot work
// without what the panel hands it.
Item {
    required property string dep
    readonly property string seen: "dep=" + dep
}
