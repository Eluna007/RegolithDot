import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel
import "../services"

// Everything a wallpaper layout needs, and nothing it draws.
//
// Upstream (ujjalsigdel/hyprquickpaper) ships each layout as a complete
// standalone shell, so all fourteen of them re-declare the same plumbing: read
// the config, list the folder, find the thumbnails, spawn the apply command,
// remember what is currently set. That is right for a drop-in `shell.qml` and
// wrong here, because Apollo already has every one of those pieces exactly
// once. This is where they live, so a layout file is only its look — the same
// split the hyprlock layouts use.
//
// The one piece that must not be re-implemented per layout is apply(). Every
// upstream layout runs its own `commands.sh`, which sets the wallpaper itself.
// Going through wallpaper-switch.sh instead is what keeps the rest of the rice
// following it: the boot restore's record of what is set, matugen, the lock
// screen's colours and wallpaper, the shell/kitty/GTK/rofi palette, and the
// login screen. Apply a wallpaper any other way and all of that silently stops
// tracking.
Item {
    id: root

    // Set by the panel, so nothing scans or spawns while the picker is closed.
    property bool active: false

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string wallDir: Config.resolvedWallpaperDir

    // The wallpaper currently applied, as an absolute path. Read from the file
    // restore-wallpaper.sh reads on session start, so the picker and the boot
    // restore can never disagree about what is set.
    property string appliedPath: ""

    readonly property alias model: wallModel
    readonly property alias count: wallModel.count

    // ── Thumbnails ───────────────────────────────────────────────────────
    // wallpaper-thumbs.sh downscales every wallpaper once and caches it here,
    // named after the original plus .png. That naming rule is the whole
    // contract between the two — there is no index file to fall out of sync.
    readonly property string thumbDir: {
        var c = Quickshell.env("XDG_CACHE_HOME")
        return (c ? c : root.homeDir + "/.cache") + "/apollo/wallpaper-thumbs"
    }

    // Bumped when a batch finishes. A tile's source depends on it, so new
    // thumbnails appear as soon as they exist rather than on the next open.
    property int thumbsRev: 0

    function thumbFor(fileName) {
        return "file://" + root.thumbDir + "/" + encodeURIComponent(fileName) + ".png"
    }

    // Image cannot decode a video at all, so these have only their cached
    // frame — there is nothing to fall back to. A gif is drawn by
    // AnimatedImage, which needs the original.
    function isVideo(fileName) { return /\.(mp4|webm|mkv|mov)$/i.test(fileName) }
    function isGif(fileName)   { return /\.gif$/i.test(fileName) }

    // onRunningChanged, not onExited: that is the Process idiom this shell
    // uses (BtPanel, WifiPanel, ApollokuPanel). Process has no `exited` signal.
    Process {
        id: thumbProc
        command: [Config.shellScript("wallpaper-thumbs.sh"), root.wallDir]
        onRunningChanged: if (!running) root.thumbsRev++
    }

    function refreshThumbs() {
        // Cheap when every thumbnail is current, which is the normal case: the
        // script compares timestamps and never spawns ImageMagick at all.
        if (!thumbProc.running) thumbProc.running = true
    }

    // ── The folder ───────────────────────────────────────────────────────
    FolderListModel {
        id: wallModel
        folder: "file://" + root.wallDir
        showDirs: false
        sortField: FolderListModel.Name
        // Videos belong here: wallpaper-switch.sh has always handled them
        // through mpvpaper. Leaving them out of this one line is what made
        // that path unreachable from the UI written for it.
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.webp",
                      "*.bmp", "*.mp4", "*.webm", "*.mkv", "*.mov"]
        // Filters are case-sensitive by default, so a wallpaper saved as .JPG
        // or .MP4 was simply invisible — present in the folder, absent from
        // the picker, with nothing to suggest why.
        caseSensitive: false
    }

    FileView {
        id: currentFile
        path: root.homeDir + "/.config/hypr/last-wallpaper.txt"
        onLoaded: root.appliedPath = text().trim()
    }

    // ── Applying ─────────────────────────────────────────────────────────
    Process { id: applyProc }

    signal applied(string path)

    function apply(path) {
        if (!path)
            return
        applyProc.running = false
        // The path goes in as $1 rather than being interpolated, to dodge
        // quoting: wallpapers have spaces and apostrophes in their names.
        applyProc.command = ["sh", "-c",
            "\"$HOME/.local/bin/wallpaper-switch.sh\" \"$1\"", "sh", path]
        applyProc.running = true
        root.appliedPath = path
        root.applied(path)
    }

    // indexOfApplied is how a layout opens on the wallpaper you are actually
    // using rather than at the start of the list.
    function indexOfApplied() {
        if (!root.appliedPath)
            return -1
        for (var i = 0; i < wallModel.count; i++)
            if (wallModel.get(i, "filePath") === root.appliedPath)
                return i
        return -1
    }

    function nameAt(i) {
        if (i < 0 || i >= wallModel.count)
            return ""
        var n = wallModel.get(i, "fileName")
        return n ? n : ""
    }

    function pathAt(i) {
        if (i < 0 || i >= wallModel.count)
            return ""
        var p = wallModel.get(i, "filePath")
        return p ? p : ""
    }

    onActiveChanged: if (active) {
        currentFile.reload()
        refreshThumbs()
    }
}
