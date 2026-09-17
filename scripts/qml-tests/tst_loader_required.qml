import QtQuick
import QtTest

// How a Loader must hand a required property to what it builds.
//
// WallpaperPanel.qml loads a layout and gives it the WallpaperSource it needs.
// The layout declares that as a *required* property so no layout can forget
// it — but a required property has to be supplied when the object is created,
// and the obvious way to write this does not do that:
//
//     Loader { source: "Layout.qml"; onLoaded: item.wallpapers = wallpapers }
//
// That fails silently from the outside. The component is never built, `item`
// stays null, `onLoaded` never runs — so the assignment that was supposed to
// fix it cannot run either — and the picker opens as a dimmed screen with
// nothing on it. QML writes "Required property ... was not initialized" into a
// log nobody is reading while looking at the empty panel. That shipped.
//
// The other two cases here are what the panel relies on and would otherwise be
// assumed: that Loader remembers a source set while it is inactive, and that
// it reuses the initial properties every time `active` goes true again. The
// panel toggles `active` with its own visibility, so if either were false the
// picker would work once and then be empty, or be empty the first time only.
//
// Run: scripts/test-qml-loader.sh
Item {
    width: 100
    height: 100

    Loader {
        id: lateLoader
        source: "Dependent.qml"
        onLoaded: item.dep = "assigned in onLoaded"
    }

    Loader { id: initLoader }

    Loader { id: inactiveFirst; active: false }
    Component.onCompleted: inactiveFirst.setSource("Dependent.qml", { "dep": "set while inactive" })

    TestCase {
        name: "LoaderRequiredProperty"
        when: windowShown

        function test_assigning_in_onLoaded_builds_nothing() {
            compare(lateLoader.status, Loader.Error,
                    "a required property assigned in onLoaded should fail to build")
            compare(lateLoader.item, null,
                    "there is no item to assign to — this is the bug the picker shipped with")
        }

        function test_setSource_with_initial_properties() {
            initLoader.setSource("Dependent.qml", { "dep": "set at creation" })
            compare(initLoader.status, Loader.Ready)
            verify(initLoader.item !== null)
            compare(initLoader.item.seen, "dep=set at creation")
        }

        function test_source_set_while_inactive_is_remembered() {
            compare(inactiveFirst.item, null, "nothing is built while inactive")
            inactiveFirst.active = true
            verify(inactiveFirst.item !== null,
                   "activating must use the source set before it was active")
            compare(inactiveFirst.item.seen, "dep=set while inactive")
        }

        function test_reactivating_keeps_the_initial_properties() {
            var l = initLoader
            l.setSource("Dependent.qml", { "dep": "first" })
            compare(l.item.seen, "dep=first")

            l.active = false          // the picker closes
            compare(l.item, null)

            l.active = true           // and opens again
            verify(l.item !== null, "re-activating must rebuild the layout")
            compare(l.item.seen, "dep=first",
                    "re-activating must reuse the properties, not drop them")
        }
    }
}
