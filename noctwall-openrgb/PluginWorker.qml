import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: worker
    property var api: null

    readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")
    readonly property string syncBin: worker.pluginDir + "/bin/noctwall-openrgb-sync"
    readonly property string cacheDir: (worker.api ? worker.api.home : Quickshell.env("HOME")) + "/.cache/noctwall/openrgb"
    readonly property string modesJsonPath: worker.cacheDir + "/g213-modes.json"

    property int modeIdx: 0
    property var modes: []
    property var pool: []
    property int sat: 0
    property int val: 0

    property bool editorOpen: false
    property int editorZone: 0
    property string editorName: ""
    property var editorColors: ["#7aa2f7", "#bb9af7", "#f7768e", "#e0af68", "#7dcfff"]

    function boostHex(hx) {
        const c = Qt.color(hx || "#7aa2f7")
        let s = c.hsvSaturation
        let v = c.hsvValue
        if (worker.sat > 0 && s > 0.03) {
            const f = worker.sat / 100.0
            s = Math.min(1.0, Math.pow(s, 1.0 / (1.0 + f)) * (1.0 + f * 0.35))
        } else if (worker.sat < 0) {
            s = Math.max(0.0, s * (1.0 + worker.sat / 100.0))
        }
        if (worker.val > 0 && v > 0.03) {
            const f = worker.val / 100.0
            v = Math.min(1.0, v * (1.0 + f))
        } else if (worker.val < 0) {
            v = Math.max(0.05, v * (1.0 + worker.val / 100.0))
        }
        return Qt.hsva(c.hsvHue, Math.max(0.0, Math.min(1.0, s)), Math.max(0.0, Math.min(1.0, v)), 1.0)
    }
    onSatChanged: worker.syncAccentToCore()
    onValChanged: worker.syncAccentToCore()

    function activeModeObj() {
        if (!worker.modes || worker.modes.length === 0) {
            return { name: "Accent & Glow", colors: ["#7aa2f7", "#9ece6a", "#f7768e", "#e0af68", "#bb9af7"], custom: false }
        }
        const idx = ((worker.modeIdx % worker.modes.length) + worker.modes.length) % worker.modes.length
        return worker.modes[idx]
    }

    function syncAccentToCore() {
        if (!worker.api) return
        const m = worker.activeModeObj()
        const c0 = (m && m.colors && m.colors[0]) ? m.colors[0] : "#7aa2f7"
        const boosted = worker.boostHex(c0)
        worker.api.activeAccent = boosted
        if (worker.api.centeredWallPath) {
            worker.api.setWallAccent(worker.api.centeredWallPath, boosted)
        }
    }

    function runSync(args) {
        syncProc.command = [worker.syncBin].concat(args)
        syncProc.running = false
        syncProc.running = true
    }

    Process {
        id: syncProc
        environment: ({ NOCTWALL_OPENRGB_DIR: worker.pluginDir })
        onExited: worker.reloadModes()
    }

    Process {
        id: applyProc
        environment: ({ NOCTWALL_OPENRGB_DIR: worker.pluginDir })
        onExited: worker.reloadModes()
    }

    Process {
        id: tuneProc
        environment: ({ NOCTWALL_OPENRGB_DIR: worker.pluginDir })
        onExited: worker.reloadModes()
    }
    Timer {
        id: tuneTimer
        interval: 90
        onTriggered: {
            const m = worker.activeModeObj()
            const cols = worker.editorOpen ? worker.editorColors : ((m && m.colors) || [])
            tuneProc.command = [worker.syncBin, "--set-tune", String(worker.sat), String(worker.val), "--preview-colors", cols.join(",")]
            tuneProc.running = false
            tuneProc.running = true
        }
    }
    function scheduleTune() { tuneTimer.restart() }

    Process {
        id: previewProc
        environment: ({ NOCTWALL_OPENRGB_DIR: worker.pluginDir })
    }
    function previewColors(cols) {
        if (!cols || cols.length < 5) return
        previewProc.command = [worker.syncBin, "--preview-colors", cols.slice(0, 5).join(",")]
        previewProc.running = false
        previewProc.running = true
    }

    Process {
        id: modesProc
        command: ["cat", worker.modesJsonPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text.trim())
                    if (d && typeof d === "object") {
                        if (typeof d.active === "number") worker.modeIdx = d.active
                        if (Array.isArray(d.modes)) worker.modes = d.modes
                        if (Array.isArray(d.pool)) worker.pool = d.pool
                        if (typeof d.sat === "number") worker.sat = d.sat
                        if (typeof d.val === "number") worker.val = d.val
                        worker.syncAccentToCore()
                    }
                } catch (e) {}
            }
        }
    }
    function reloadModes() { modesProc.running = false; modesProc.running = true }

    Process {
        id: warmRgbProc
        environment: ({ NOCTWALL_OPENRGB_DIR: worker.pluginDir })
        command: [worker.syncBin, "--warm", worker.api ? worker.api.wallsDir : ""]
    }

    function cycleMode(delta) {
        const wp = worker.api ? worker.api.centeredWallPath : ""
        let args = [delta > 0 ? "--next" : "--prev"]
        if (wp) args = args.concat(["--image", wp])
        worker.runSync(args)
    }

    function toggleEditor() {
        if (worker.editorOpen) {
            worker.closeEditor()
            return
        }
        const m = worker.activeModeObj()
        worker.editorColors = (m && m.colors && m.colors.length >= 5) ? m.colors.slice(0, 5) : ["#7aa2f7", "#bb9af7", "#f7768e", "#e0af68", "#7dcfff"]
        worker.editorZone = 0
        worker.editorName = "Custom #" + (Math.max(0, worker.modes.length - 6) + 1)
        worker.editorOpen = true
        if (worker.api) worker.api.editorOpen = true
    }

    function closeEditor() {
        worker.editorOpen = false
        if (worker.api) {
            worker.api.editorOpen = false
            worker.api.refocusStage()
        }
        const m = worker.activeModeObj()
        if (m && m.colors) worker.previewColors(m.colors)
    }

    function setEditorZoneColor(hexCol) {
        let next = worker.editorColors.slice(0, 5)
        next[worker.editorZone] = hexCol
        worker.editorColors = next
        worker.previewColors(next)
        worker.editorZone = (worker.editorZone + 1) % 5
    }

    function randomizeEditorColors() {
        const p = (worker.pool && worker.pool.length > 0) ? worker.pool : ["#7aa2f7", "#bb9af7", "#f7768e", "#e0af68", "#7dcfff"]
        let next = []
        for (let i = 0; i < 5; i++) {
            next.push(p[Math.floor(Math.random() * p.length)])
        }
        worker.editorColors = next
        worker.previewColors(next)
    }

    function saveEditorProfile() {
        const wp = worker.api ? worker.api.centeredWallPath : ""
        if (!wp) return
        const nm = worker.editorName.trim() || ("Custom #" + (Math.max(0, worker.modes.length - 6) + 1))
        let args = ["--add-custom", wp, nm, worker.editorColors.join(",")]
        worker.editorOpen = false
        if (worker.api) {
            worker.api.editorOpen = false
            worker.api.refocusStage()
        }
        worker.runSync(args)
    }

    function deleteActiveCustom() {
        const wp = worker.api ? worker.api.centeredWallPath : ""
        if (!wp || worker.modeIdx < 6) return
        let args = ["--del-custom", wp, String(worker.modeIdx)]
        worker.runSync(args)
    }

    Process {
        id: startupSyncProc
        environment: ({ NOCTWALL_OPENRGB_DIR: worker.pluginDir })
        onExited: worker.reloadModes()
    }
    Timer {
        id: startupSyncTimer
        interval: 800
        repeat: false
        onTriggered: {
            const wp = worker.api ? worker.api.currentWallPath : ""
            startupSyncProc.command = [worker.syncBin, "--wait"].concat(wp ? ["--image", wp] : [])
            startupSyncProc.running = false
            startupSyncProc.running = true
        }
    }

    // Register shared controller reference onto api so BottomSlot delegates can call it
    onApiChanged: {
        if (!worker.api) return
        worker.reloadModes()
        if (!warmRgbProc.running) warmRgbProc.running = true
        startupSyncTimer.restart()
    }

    // Expose controller singleton via root property on Qt.application
    Component.onCompleted: {
        Qt.application._noctwallOpenRgb = worker
        worker.reloadModes()
    }

    Connections {
        target: worker.api
        ignoreUnknownSignals: true
        function onOpenChanged() {
            if (worker.api.open) {
                if (!warmRgbProc.running) warmRgbProc.running = true
                if (worker.api.centeredWallPath) {
                    worker.runSync(["--image", worker.api.centeredWallPath])
                }
            } else {
                worker.editorOpen = false
            }
        }
        function onCenteredWallPathChanged() {
            if (worker.api.open && worker.api.centeredWallPath) {
                worker.runSync(["--image", worker.api.centeredWallPath])
            }
        }
        function onEditorOpenChanged() {
            if (!worker.api.editorOpen && worker.editorOpen) {
                worker.closeEditor()
            }
        }
        function onKeyAction(action, modifiers) {
            if (!worker.api || !worker.api.open) return
            if (action === "up" && !worker.editorOpen) {
                worker.cycleMode(-1)
            } else if (action === "down" && !worker.editorOpen) {
                worker.cycleMode(1)
            } else if (action === "left" && worker.editorOpen) {
                worker.editorZone = (worker.editorZone + 4) % 5
            } else if (action === "right" && worker.editorOpen) {
                worker.editorZone = (worker.editorZone + 1) % 5
            } else if (action === "return" && worker.editorOpen) {
                worker.saveEditorProfile()
            } else if (action === "escape" && worker.editorOpen) {
                worker.closeEditor()
            }
        }
    }

    Connections {
        target: worker.api
        ignoreUnknownSignals: true
        function onWallpaperApplied(wp) {
            applyProc.command = [worker.syncBin, "--image", wp]
            applyProc.running = false
            applyProc.running = true
        }
        function onPickerClosed(applied) {
            if (!applied && worker.api && worker.api.currentWallPath) {
                applyProc.command = [worker.syncBin, "--image", worker.api.currentWallPath]
                applyProc.running = false
                applyProc.running = true
            }
        }
    }

    IpcHandler {
        target: "openrgb"
        function next(): string { worker.cycleMode(1); return "next" }
        function prev(): string { worker.cycleMode(-1); return "prev" }
        function sync(): string {
            const wp = worker.api ? worker.api.currentWallPath : ""
            worker.runSync(wp ? ["--image", wp] : [])
            return "synced"
        }
    }
}
