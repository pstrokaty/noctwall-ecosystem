// WallpaperFx.qml — GPU-accelerated shader wallpaper transitions for Quickshell.
// Renders on WlrLayer.Bottom above the desktop wallpaper during transitions:
//   1. Load old/new wallpapers and precomputed transition maps asynchronously.
//   2. Fade in the shader layer at t=0 (visually identical to the old wallpaper).
//   3. Trigger wallSetter (Noctalia IPC) underneath once covered.
//   4. Complete shader transition, wait for settle (40 ms), fade out, and release textures.
//   5. Safety watchdog (2500 ms) ensures the wallpaper updates even if assets fail to load.

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

Scope {
    id: root

    readonly property string onlyScreen: Quickshell.env("WALLFX_ONLY") || ""
    readonly property bool dry: Quickshell.env("WALLFX_DRY") === "1"

    property int msContagio: 1800
    property int msPerfil: 2000
    property int msFade: 130
    property real glow: 0.9
    property real lineW: 1.5
    property var wallpaperSetCmd: ["noctalia", "msg", "wallpaper-set"]

    property string oldPath: ""
    property string newPath: ""
    property string kind: "contagio"
    property bool spanMode: false
    property string fieldPath: ""
    property string linePath: ""
    property bool autoGo: true
    property string phase: "idle"
    property real t: 0
    property real fade: 0
    property bool swapped: false
    property int gen: 0
    property int swapGen: -1
    property color ember: "#ff7a00"
    property color ink: "#ffffff"
    property real seed: 0
    property int readyCount: 0
    readonly property int screenCount: screens.instances.length
    readonly property bool active: phase !== "idle"

    function lifted(c) {
        return Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.55),
                       Math.min(Math.max(c.hslLightness, 0.62), 0.82), 1)
    }

    function prepare(o, n, k, f, l, go, span) {
        root.spanMode = (span === true || span === "true" || span === "1" || span === "span")
        if (root.active) root.finish()
        root.oldPath = o; root.newPath = n
        root.kind = k === "perfil" ? "perfil" : "contagio"
        root.fieldPath = f; root.linePath = l || f
        root.autoGo = go
        root.t = 0; root.fade = 0; root.readyCount = 0; root.swapped = false
        root.gen++
        root.phase = "loading"
        watchdog.restart()
    }

    function screenReady() {
        if (root.phase !== "loading") return
        root.readyCount++
        if (root.readyCount < root.screenCount) return
        watchdog.stop()
        if (root.dry) { root.fade = 1; root.phase = "ready"; if (root.autoGo) root.go(); return }
        root.go()
    }

    function go() {
        if (root.phase !== "ready" && root.phase !== "loading") return
        root.ember = root.lifted("#ff7a00")
        root.ink = "#ffffff"
        root.seed = Math.random() * 100
        root.phase = "run"
        run.duration = root.kind === "perfil" ? root.msPerfil : root.msContagio
        run.restart()
        if (!root.dry) fadeIn.restart()
    }

    function maybeFinish() {
        if (root.dry) { if (!run.running) root.phase = "done"; return }
        if (run.running) return
        if (!root.swapped) { root.phase = "held"; watchdog.restart(); return }
        root.phase = "fadeout"
        fadeOut.restart()
    }

    function setterCmd(path) {
        return root.wallpaperSetCmd.concat(root.onlyScreen ? [root.onlyScreen, path] : [path])
    }

    function swap() {
        root.swapGen = root.gen
        wallSetter.command = root.setterCmd(root.newPath)
        wallSetter.running = true
    }

    function finish() {
        fadeIn.stop(); run.stop(); fadeOut.stop(); watchdog.stop(); settle.stop()
        root.phase = "idle"; root.fade = 0; root.t = 0
        root.oldPath = ""; root.newPath = ""; root.fieldPath = ""; root.linePath = ""
    }

    NumberAnimation { id: fadeIn; target: root; property: "fade"; from: 0; to: 1
        duration: root.msFade; easing.type: Easing.OutQuad
        onFinished: root.swap() }

    NumberAnimation { id: run; target: root; property: "t"; from: 0; to: 1
        easing.type: Easing.Linear
        onFinished: root.maybeFinish() }

    property int statFrames: 0
    property real statWorst: 0
    property string lastStats: ""
    FrameAnimation {
        running: root.phase === "run"
        onRunningChanged: if (running) { root.statFrames = 0; root.statWorst = 0 }
                          else if (root.statFrames > 0)
                              root.lastStats = root.kind + ": " + root.statFrames + " frames in "
                                  + run.duration + " ms (" + Math.round(root.statFrames * 1000 / run.duration)
                                  + " fps), worst " + Math.round(root.statWorst * 1000) + " ms"
        onTriggered: { root.statFrames++; if (root.statFrames > 2) root.statWorst = Math.max(root.statWorst, frameTime) }
    }

    NumberAnimation { id: fadeOut; target: root; property: "fade"; from: 1; to: 0
        duration: root.msFade; easing.type: Easing.OutQuad
        onFinished: root.finish() }

    Process {
        id: wallSetter
        onExited: (code) => {
            if (root.swapGen !== root.gen) return
            if (code === 0) { settle.restart(); return }
            const n = root.newPath
            root.finish()
            Quickshell.execDetached(root.setterCmd(n))
        }
    }

    Timer { id: settle; interval: 40; onTriggered: { root.swapped = true; root.maybeFinish() } }

    Timer {
        id: watchdog; interval: 2500
        onTriggered: {
            const n = root.newPath, loading = root.phase === "loading"
            root.finish()
            if (loading && !root.dry && n)
                Quickshell.execDetached(root.setterCmd(n))
        }
    }

    IpcHandler {
        target: "wallfx"
        function play(oldImg: string, newImg: string, kind: string, field: string, line: string, span: string): string {
            root.prepare(oldImg, newImg, kind, field, line, true, span); return "ok"
        }
        function prepare(oldImg: string, newImg: string, kind: string, field: string, line: string): string {
            root.prepare(oldImg, newImg, kind, field, line, false); return "ok"
        }
        function go(): string { root.go(); return root.phase }
        function state(): string { return root.phase }
        function stats(): string { return root.lastStats }
        function stop(): string { root.finish(); return "ok" }
        function tune(key: string, value: string): string {
            root[key] = Number(value)
            return key + "=" + root[key]
        }
    }

    readonly property var activeScreens: Quickshell.screens.filter(s => !root.onlyScreen || s.name === root.onlyScreen)
    readonly property real deskMinX: activeScreens.length ? Math.min(...activeScreens.map(s => s.x)) : 0
    readonly property real deskMinY: activeScreens.length ? Math.min(...activeScreens.map(s => s.y)) : 0
    readonly property real deskMaxX: activeScreens.length ? Math.max(...activeScreens.map(s => s.x + s.width)) : 1920
    readonly property real deskMaxY: activeScreens.length ? Math.max(...activeScreens.map(s => s.y + s.height)) : 1080
    readonly property real deskW: Math.max(deskMaxX - deskMinX, 1)
    readonly property real deskH: Math.max(deskMaxY - deskMinY, 1)

    Variants {
        id: screens
        model: root.activeScreens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: root.active
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell:noctwall-fx"

            readonly property bool loaded: oldImg.status === Image.Ready && newImg.status === Image.Ready
                && fieldImg.status === Image.Ready && lineImg.status === Image.Ready
            onLoadedChanged: if (loaded) root.screenReady()

            Image { id: oldImg; visible: false; asynchronous: true; cache: false
                source: root.oldPath ? "file://" + root.oldPath : ""
                sourceSize: root.spanMode ? Qt.size(root.deskW, root.deskH) : Qt.size(win.width, win.height)
                fillMode: Image.PreserveAspectCrop }
            Image { id: newImg; visible: false; asynchronous: true; cache: false
                source: root.newPath ? "file://" + root.newPath : ""
                sourceSize: root.spanMode ? Qt.size(root.deskW, root.deskH) : Qt.size(win.width, win.height)
                fillMode: Image.PreserveAspectCrop }
            Image { id: fieldImg; visible: false; asynchronous: true; cache: false
                smooth: root.kind === "perfil"
                source: root.fieldPath ? "file://" + root.fieldPath : "" }
            Image { id: lineImg; visible: false; asynchronous: true; cache: false
                source: root.linePath ? "file://" + root.linePath : "" }

            function crop(img) {
                const iw = Math.max(img.implicitWidth, 1), ih = Math.max(img.implicitHeight, 1)
                const targetW = root.spanMode ? root.deskW : win.width
                const targetH = root.spanMode ? root.deskH : win.height
                const s = Math.max(targetW / iw, targetH / ih)
                const w = targetW / (iw * s), h = targetH / (ih * s)
                return Qt.vector4d((1 - w) / 2, (1 - h) / 2, w, h)
            }

            function calcSpanRect() {
                if (!root.spanMode) return Qt.vector4d(0, 0, 1, 1)
                return Qt.vector4d(
                    (modelData.x - root.deskMinX) / root.deskW,
                    (modelData.y - root.deskMinY) / root.deskH,
                    win.width / root.deskW,
                    win.height / root.deskH
                )
            }

            ShaderEffect {
                anchors.fill: parent
                visible: win.loaded
                opacity: root.fade
                property var oldTex: oldImg
                property var newTex: newImg
                property var fieldTex: fieldImg
                property var lineTex: lineImg
                property real t: root.t
                property real mode: root.kind === "perfil" ? 1 : 0
                property real sw: root.spanMode ? root.deskW : win.width
                property real sh: root.spanMode ? root.deskH : win.height
                property real fw: Math.max(fieldImg.implicitWidth, 1)
                property real fh: Math.max(fieldImg.implicitHeight, 1)
                property real lw: Math.max(lineImg.implicitWidth, 1)
                property real lh: Math.max(lineImg.implicitHeight, 1)
                property real glow: root.glow
                property real lineW: root.lineW
                property real sdRange: 16
                property real seed: root.seed
                property vector4d cropOld: win.crop(oldImg)
                property vector4d cropNew: win.crop(newImg)
                property color ember: root.ember
                property color ink: root.ink
                property vector4d spanRect: win.calcSpanRect()
                fragmentShader: Qt.resolvedUrl("shaders/wallfx.v16.frag.qsb")
            }
        }
    }
}
