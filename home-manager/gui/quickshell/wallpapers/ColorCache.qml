pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.shared

// Everything that needs matugen.
//
//  - Source colours of a wallpaper (`matugen image <file> --show-source-colors`: 1 to 5 hex colours,
//    about 0.25 s each). Cached on disk, keyed by file name and modification time, so that every
//    wallpaper is analysed once. One matugen process at a time; `prioritize()` puts the wallpaper
//    being looked at first, `enqueue()` fills in the others while the popup is open.
//  - The scheme matugen would make from one colour, type and mode (`matugen color hex ... --dry-run
//    -j hex`, a few ms): shown as a live preview before anything is applied. Kept in memory.
Singleton {
    id: root

    readonly property string dir:
        (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
        + "/quickshell-wallpapers"
    readonly property string path: dir + "/colors.json"

    // file name -> { mtime, colors: ["#rrggbb", ...] }. Replaced as a whole when it changes.
    property var sources: ({})
    // "<hex>|<type>|<mode>" -> { role: "#rrggbb" }
    property var palettes: ({})
    // The wallpaper being analysed right now (file name), "" when idle.
    property string busyWith: ""

    // ---- source colours ---------------------------------------------------------------------

    // The cached colours of `entry` (from WallpaperModel), or undefined if not known (yet).
    function colorsOf(entry) {
        if (!entry)
            return undefined
        const c = sources[entry.name]
        return (c && c.mtime === entry.modified) ? c.colors : undefined
    }

    property var queue: []   // entries, next first

    function enqueue(entries) {
        const add = entries.filter(e => colorsOf(e) === undefined
                                   && !queue.some(q => q.name === e.name) && e.name !== busyWith)
        if (add.length === 0)
            return
        queue = queue.concat(add)
        pump()
    }

    function prioritize(entry) {
        if (!entry || colorsOf(entry) !== undefined || entry.name === busyWith)
            return
        queue = [entry].concat(queue.filter(q => q.name !== entry.name))
        pump()
    }

    function pump() {
        if (analyse.running || queue.length === 0)
            return
        const next = queue[0]
        queue = queue.slice(1)
        if (colorsOf(next) !== undefined) {
            pump()
            return
        }
        busyWith = next.name
        analyse.entry = next
        analyse.command = ["matugen", "image", next.path, "--show-source-colors"]
        analyse.running = true
    }

    Process {
        id: analyse
        property var entry: null
        stdout: StdioCollector {
            id: analyseOut
        }
        onExited: (code, status) => {
            const e = entry
            const colors = analyseOut.text.split("\n").map(l => l.trim()).filter(l => /^#[0-9a-fA-F]{6}$/.test(l))
            if (code === 0 && colors.length > 0) {
                const next = Object.assign({}, root.sources)
                next[e.name] = { mtime: e.modified, colors: colors }
                root.sources = next
                file.save(root.sources)
            } else {
                // Not retried (it would loop on a file matugen cannot read); the card just shows no colours.
                console.warn("matugen could not read the colours of", e.name, "(exit", code + ")")
            }
            root.busyWith = ""
            root.pump()
        }
    }

    // ---- scheme preview ---------------------------------------------------------------------

    function paletteKey(hex, type, mode) {
        return hex + "|" + type + "|" + mode
    }

    function paletteOf(hex, type, mode) {
        return palettes[paletteKey(hex, type, mode)]
    }

    property string wantedKey: ""
    property var wanted: null

    function requestPalette(hex, type, mode) {
        if (!hex)
            return
        const key = paletteKey(hex, type, mode)
        if (palettes[key] !== undefined)
            return
        wanted = { key: key, hex: hex, type: type, mode: mode }
        pumpPalette()
    }

    function pumpPalette() {
        if (preview.running || wanted === null)
            return
        const w = wanted
        wanted = null
        if (palettes[w.key] !== undefined)
            return
        preview.key = w.key
        preview.command = ["matugen", "color", "hex", w.hex, "-t", w.type, "-m", w.mode,
                           "--dry-run", "-j", "hex", "-q"]
        preview.running = true
    }

    Process {
        id: preview
        property string key: ""
        stdout: StdioCollector {
            id: previewOut
        }
        onExited: (code, status) => {
            try {
                const text = previewOut.text
                const colors = JSON.parse(text.substring(text.indexOf("{"))).colors
                const roles = {}
                for (const role of Object.keys(colors))
                    roles[role] = (colors[role].default || colors[role]).color
                const next = Object.assign({}, root.palettes)
                next[preview.key] = roles
                root.palettes = next
            } catch (e) {
                console.warn("could not read matugen's scheme:", e)
            }
            root.pumpPalette()
        }
    }

    // ---- disk cache -------------------------------------------------------------------------

    // Read once at start, written 400 ms after the last change (nothing else writes it).
    JsonFile {
        id: file
        path: root.path
        name: "colour cache"
        watch: false
        retryInterval: 0
        writeDelay: 400
        indent: 0
        onParsed: value => {
            if (value && typeof value === "object" && !Array.isArray(value))
                root.sources = value
        }
    }
}
