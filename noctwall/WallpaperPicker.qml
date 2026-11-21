import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel

Scope {
    id: root
    property bool open: false
    readonly property string home: Quickshell.env("HOME")
    readonly property string rootDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/+$/, "")
    readonly property string configPath: root.rootDir + "/config.json"

    // Reactive configuration loaded from config.json (live-editable by NoctWall-Studio)
    property var cfg: ({
        paths: {
            wallpapersDir: "~/Obrazy/Wallpapers",
            randomSubdir: "UltraDual",
            thumbsDir: "~/.cache/noctwall/thumbs",
            cacheDir: "~/.cache/noctwall"
        },
        carousel: {
            cardWidth: 720,
            cardHeight: 406,
            skew: -0.35,
            borderWidth: 3,
            slotWidth: 360,
            sideScale: 0.56,
            perspective: 0.00022,
            height: 560,
            blurPadding: 96,
            blurEditorPadding: 240,
            editorShiftY: -82,
            glowEnabled: true,
            sideBordersEnabled: true,
            glowPulseMin: 0.65,
            glowPulseMax: 0.96,
            defaultAccent: "#7aa2f7"
        },
        transitions: {
            msContagio: 1800,
            msPerfil: 2000,
            msFade: 130,
            glow: 0.9,
            lineWidth: 1.5
        },
        plugins: {
            enabled: ["noctwall-openrgb", "noctwall-studio"]
        }
    })

    function expandHome(p) {
        if (!p) return ""
        return p.startsWith("~/") ? (root.home + p.slice(1)) : p
    }

    readonly property string wallsDir: root.expandHome((root.cfg.paths && root.cfg.paths.wallpapersDir) || "~/Obrazy/Wallpapers")
    readonly property string thumbsDir: root.expandHome((root.cfg.paths && root.cfg.paths.thumbsDir) || "~/.cache/noctwall/thumbs")
    readonly property string cacheDir: root.expandHome((root.cfg.paths && root.cfg.paths.cacheDir) || "~/.cache/noctwall")

    property string currentWallPath: ""
    property bool appliedInSession: false
    property real glowPulse: 0.85

    // Shared Hook State exposed to plugins (NoctWall-OpenRGB, NoctWall-Studio, etc.)
    property bool editorOpen: false
    property bool studioOpen: false
    property color activeAccent: (root.cfg.carousel && root.cfg.carousel.defaultAccent) || "#7aa2f7"
    property var slotAccents: ({})
    property var enabledPlugins: (root.cfg.plugins && Array.isArray(root.cfg.plugins.enabled)) ? root.cfg.plugins.enabled : []

    readonly property string centeredWallPath: (carousel.currentIndex >= 0 && carousel.currentIndex < wallModel.count)
        ? root.originalOf(wallModel.get(carousel.currentIndex, "fileName"))
        : root.currentWallPath

    // Hook Signals for plugins
    signal wallpaperPreviewed(string wallPath)
    signal wallpaperApplied(string wallPath)
    signal pickerClosed(bool applied)
    signal configReloaded()

    // Public API object passed into every loaded plugin
    property QtObject pluginApi: QtObject {
        signal keyAction(string action, int modifiers)
        signal wallpaperPreviewed(string wallPath)
        signal wallpaperApplied(string wallPath)
        signal pickerClosed(bool applied)
        signal configReloaded()
        readonly property bool open: root.open
        readonly property string home: root.home
        readonly property string rootDir: root.rootDir
        readonly property string wallsDir: root.wallsDir
        readonly property string currentWallPath: root.currentWallPath
        readonly property string centeredWallPath: root.centeredWallPath
        property bool editorOpen: root.editorOpen
        onEditorOpenChanged: if (root.editorOpen !== editorOpen) root.editorOpen = editorOpen
        property bool studioOpen: root.studioOpen
        onStudioOpenChanged: if (root.studioOpen !== studioOpen) root.studioOpen = studioOpen
        property color activeAccent: root.activeAccent
        onActiveAccentChanged: if (root.activeAccent !== activeAccent) root.activeAccent = activeAccent

        readonly property real cardWidth: carousel.iw
        readonly property real cardHeight: carousel.ih
        readonly property real skew: carousel.skew
        readonly property var cfg: root.cfg

        function accentForWall(wp) {
            return (wp && root.slotAccents && root.slotAccents[wp]) ? root.slotAccents[wp] : root.activeAccent
        }
        function setWallAccent(wp, hexCol) {
            if (!wp || !hexCol) return
            let next = Object.assign({}, root.slotAccents)
            next[wp] = hexCol
            root.slotAccents = next
            if (wp === root.centeredWallPath) root.activeAccent = hexCol
        }
        function updateConfigSection(section, patch) {
            let nextCfg = JSON.parse(JSON.stringify(root.cfg))
            if (!nextCfg[section]) nextCfg[section] = {}
            Object.assign(nextCfg[section], patch)
            root.cfg = nextCfg
        }
        function saveConfig() {
            root.persistConfig()
        }
        function resetConfig() {
            resetCfgProc.running = false
            resetCfgProc.running = true
        }
        function refocusStage() {
            stage.forceActiveFocus()
        }
        function rebuildThumbs() {
            root.refreshThumbs()
        }
        function warmMasks() {
            root.warmTransitions()
        }
    }

    Connections {
        target: root
        function onEditorOpenChanged() { if (pluginApi.editorOpen !== root.editorOpen) pluginApi.editorOpen = root.editorOpen }
        function onStudioOpenChanged() { if (pluginApi.studioOpen !== root.studioOpen) pluginApi.studioOpen = root.studioOpen }
        function onActiveAccentChanged() { if (pluginApi.activeAccent !== root.activeAccent) pluginApi.activeAccent = root.activeAccent }
        function onWallpaperPreviewed(wallPath) { pluginApi.wallpaperPreviewed(wallPath) }
        function onWallpaperApplied(wallPath) { pluginApi.wallpaperApplied(wallPath) }
        function onPickerClosed(applied) { pluginApi.pickerClosed(applied) }
        function onConfigReloaded() { pluginApi.configReloaded() }
    }

    SequentialAnimation on glowPulse {
        running: root.open && ((root.cfg.carousel && root.cfg.carousel.glowEnabled) !== false)
        loops: Animation.Infinite
        NumberAnimation {
            from: (root.cfg.carousel && root.cfg.carousel.glowPulseMin) || 0.65
            to: (root.cfg.carousel && root.cfg.carousel.glowPulseMax) || 0.96
            duration: 1700; easing.type: Easing.InOutSine
        }
        NumberAnimation {
            from: (root.cfg.carousel && root.cfg.carousel.glowPulseMax) || 0.96
            to: (root.cfg.carousel && root.cfg.carousel.glowPulseMin) || 0.65
            duration: 1700; easing.type: Easing.InOutSine
        }
    }

    function originalOf(thumbName) {
        return root.wallsDir + "/" + String(thumbName).replace(/\.jpg$/, "").replace(/__/g, "/")
    }

    function thumbKeyOf(fullPath) {
        const prefix = root.wallsDir + "/"
        if (!fullPath.startsWith(prefix)) return ""
        return fullPath.slice(prefix.length).replace(/\//g, "__") + ".jpg"
    }

    function applyPath(fullPath) {
        if (!fullPath) return
        root.currentWallPath = fullPath
        root.appliedInSession = true
        Quickshell.execDetached(["bash", root.rootDir + "/scripts/set-wallpaper.sh", fullPath])
        root.wallpaperApplied(fullPath)
    }

    function apply(thumbName) {
        if (!thumbName) return
        root.applyPath(root.originalOf(thumbName))
        root.open = false
    }

    function syncToCurrent() {
        const targetThumb = root.thumbKeyOf(root.currentWallPath)
        if (!targetThumb || wallModel.count === 0) return
        for (let i = 0; i < wallModel.count; i++) {
            if (wallModel.get(i, "fileName") === targetThumb) {
                carousel.currentIndex = i
                carousel.positionViewAtIndex(i, ListView.Center)
                return
            }
        }
    }

    function stepImmediate(delta) {
        if (wallModel.count === 0) return
        let idx = -1
        const targetThumb = root.thumbKeyOf(root.currentWallPath)
        for (let i = 0; i < wallModel.count; i++) {
            if (wallModel.get(i, "fileName") === targetThumb) { idx = i; break }
        }
        const nextIdx = (idx + delta + wallModel.count) % wallModel.count
        root.applyPath(root.originalOf(wallModel.get(nextIdx, "fileName")))
    }

    function persistConfig() {
        const py = "import json,os,sys; p=os.path.realpath(sys.argv[1]); os.makedirs(os.path.dirname(p),exist_ok=True); t=p+'.tmp'; open(t,'w',encoding='utf-8').write(json.dumps(json.loads(sys.argv[2]),indent=2)+chr(10)); os.replace(t,p)"
        saveCfgProc.command = ["python3", "-c", py, root.configPath, JSON.stringify(root.cfg)]
        saveCfgProc.running = false
        saveCfgProc.running = true
    }

    Process { id: saveCfgProc }
    Process {
        id: resetCfgProc
        command: ["cp", "-f", root.rootDir + "/config.default.json", root.configPath]
        onExited: root.reloadConfig()
    }

    Process {
        id: loadCfgProc
        command: ["bash", "-c", '[ -f "$1" ] || cp "$2" "$1"; cat "$1"', "_", root.configPath, root.rootDir + "/config.default.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text.trim())
                    if (parsed && typeof parsed === "object") {
                        root.cfg = parsed
                        root.configReloaded()
                    }
                } catch (e) {}
            }
        }
    }
    function reloadConfig() { loadCfgProc.running = false; loadCfgProc.running = true }

    Process {
        id: currentWallProc
        command: ["noctalia", "msg", "wallpaper-get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim()
                if (p) {
                    root.currentWallPath = p
                    if (root.open) root.syncToCurrent()
                }
            }
        }
    }
    function refreshCurrentWall() { currentWallProc.running = false; currentWallProc.running = true }

    Process {
        id: thumbsProc
        command: ["bash", root.rootDir + "/scripts/wall-thumbs.sh", root.wallsDir, root.thumbsDir]
        onExited: {
            if (wallModel.count === 0) {
                wallModel.folder = ""
                wallModel.folder = "file://" + root.thumbsDir
            }
            if (root.open) root.syncToCurrent()
        }
    }
    function refreshThumbs() { thumbsProc.running = false; thumbsProc.running = true }

    Process {
        id: warmProc
        command: [root.rootDir + "/bin/noctwall-fx", "warm", root.wallsDir + "/" + ((root.cfg.paths && root.cfg.paths.randomSubdir) || "UltraDual")]
    }
    function warmTransitions() { if (!warmProc.running) warmProc.running = true }

    Component.onCompleted: {
        root.reloadConfig()
        root.refreshThumbs()
        root.refreshCurrentWall()
    }

    // Background plugin workers (non-visual hooks, e.g. OpenRGB warm/sync)
    Instantiator {
        model: root.enabledPlugins
        delegate: Loader {
            required property string modelData
            source: modelData === "noctwall-studio" ? "" : Qt.resolvedUrl("plugins/" + modelData + "/PluginWorker.qml")
            asynchronous: false
            onLoaded: if (item && item.hasOwnProperty("api")) item.api = root.pluginApi
        }
    }

    IpcHandler {
        target: "picker"
        function toggle(): string {
            root.open = !root.open
            return root.open ? "open" : "closed"
        }
        function next(): string {
            if (root.open) { carousel.incrementCurrentIndex(); return "carousel-next" }
            root.stepImmediate(1); return "applied-next"
        }
        function prev(): string {
            if (root.open) { carousel.decrementCurrentIndex(); return "carousel-prev" }
            root.stepImmediate(-1); return "applied-prev"
        }
        function random(): string {
            if (wallModel.count === 0) return "empty"
            if (root.open) {
                if (wallModel.count > 1) {
                    let r = Math.floor(Math.random() * (wallModel.count - 1))
                    if (r >= carousel.currentIndex) r++
                    carousel.currentIndex = r
                }
                return "carousel-random"
            }
            const sub = (root.cfg.paths && root.cfg.paths.randomSubdir) || "UltraDual"
            Quickshell.execDetached(["bash", root.rootDir + "/scripts/random-wallpaper.sh", root.wallsDir + "/" + sub])
            return "applied-random"
        }
        function reload(): string {
            root.reloadConfig()
            return "reloaded"
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [win]
        active: root.open
        onCleared: {
            if (win.migratingScreen) {
                regrabTimer.restart()
            } else {
                root.open = false
            }
        }
    }

    Timer {
        id: screenMigrateTimer
        interval: 280
        onTriggered: win.migratingScreen = false
    }

    Timer {
        id: regrabTimer
        interval: 45
        onTriggered: {
            if (root.open) {
                focusGrab.active = false
                focusGrab.active = true
                stage.forceActiveFocus()
            }
        }
    }

    FolderListModel {
        id: wallModel
        folder: "file://" + root.thumbsDir
        nameFilters: ["*.jpg"]
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: if (root.open) root.syncToCurrent()
    }

    PanelWindow {
        id: win
        property bool migratingScreen: false
        onScreenChanged: {
            if (root.open) {
                migratingScreen = true
                screenMigrateTimer.restart()
                regrabTimer.restart()
            }
        }
        screen: {
            const mon = Hyprland.focusedMonitor
            if (mon) {
                const found = Quickshell.screens.find(s => s.name === mon.name)
                if (found) return found
            }
            return Quickshell.screens[0]
        }
        visible: root.open || stage.opacity > 0
        anchors { top: true; bottom: true; left: true; right: true }
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: (root.cfg.carousel && root.cfg.carousel.layerNamespace) || "quickshell:wallpaper"

        Item {
            id: stage
            anchors.fill: parent
            focus: true
            opacity: root.open ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: root.open ? 210 : 110
                    easing.type: root.open ? Easing.OutCubic : Easing.InCubic
                }
            }

            Connections {
                target: root
                function onOpenChanged() {
                    if (!root.open) {
                        root.editorOpen = false
                        root.studioOpen = false
                        root.pickerClosed(root.appliedInSession)
                        return
                    }
                    root.appliedInSession = false
                    stage.forceActiveFocus()
                    root.reloadConfig()
                    root.refreshCurrentWall()
                    root.refreshThumbs()
                    root.warmTransitions()
                    root.syncToCurrent()
                }
            }

            Keys.onEscapePressed: {
                if (root.editorOpen) { pluginApi.keyAction("escape", 0); root.editorOpen = false }
                else if (root.studioOpen) root.studioOpen = false
                else root.open = false
            }
            Keys.onLeftPressed: (e) => {
                if (root.editorOpen) pluginApi.keyAction("left", e.modifiers)
                else carousel.decrementCurrentIndex()
            }
            Keys.onRightPressed: (e) => {
                if (root.editorOpen) pluginApi.keyAction("right", e.modifiers)
                else carousel.incrementCurrentIndex()
            }
            Keys.onUpPressed: (e) => {
                if ((e.modifiers & (Qt.MetaModifier | Qt.AltModifier)) === 0) {
                    pluginApi.keyAction("up", e.modifiers)
                    e.accepted = true
                }
            }
            Keys.onDownPressed: (e) => {
                if ((e.modifiers & (Qt.MetaModifier | Qt.AltModifier)) === 0) {
                    pluginApi.keyAction("down", e.modifiers)
                    e.accepted = true
                }
            }
            Keys.onReturnPressed: (e) => {
                if (root.editorOpen) pluginApi.keyAction("return", e.modifiers)
                else carousel.applyCurrent()
            }
            Keys.onEnterPressed: (e) => {
                if (root.editorOpen) pluginApi.keyAction("return", e.modifiers)
                else carousel.applyCurrent()
            }

            MouseArea {
                anchors.fill: parent
                z: 999
                acceptedButtons: Qt.NoButton
                property real wheelAcc: 0
                onWheel: (e) => {
                    if (root.editorOpen || root.studioOpen) return
                    const d = Math.abs(e.angleDelta.y) >= Math.abs(e.angleDelta.x) ? e.angleDelta.y : e.angleDelta.x
                    if ((d > 0 && wheelAcc < 0) || (d < 0 && wheelAcc > 0)) wheelAcc = 0
                    wheelAcc += d
                    if (wheelAcc >= 80) { carousel.decrementCurrentIndex(); wheelAcc = 0 }
                    else if (wheelAcc <= -80) { carousel.incrementCurrentIndex(); wheelAcc = 0 }
                    e.accepted = true
                }
            }

            MouseArea { anchors.fill: parent; z: -1; onClicked: root.open = false }

            // Blurred backdrop band
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: carousel.height + (root.editorOpen
                    ? ((root.cfg.carousel && root.cfg.carousel.blurEditorPadding) || 240)
                    : ((root.cfg.carousel && root.cfg.carousel.blurPadding) || 96))
                color: "#73000000"
                z: -0.5
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: "#26ffffff" }
                Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: "#26ffffff" }
            }

            ListView {
                id: carousel
                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    verticalCenterOffset: root.editorOpen ? ((root.cfg.carousel && root.cfg.carousel.editorShiftY) || -82) : 0
                }
                Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                height: (root.cfg.carousel && root.cfg.carousel.height) || 560
                orientation: ListView.Horizontal
                model: wallModel

                property real iw: (root.cfg.carousel && root.cfg.carousel.cardWidth) || 720
                property real ih: (root.cfg.carousel && root.cfg.carousel.cardHeight) || 406
                property real skew: (root.cfg.carousel && root.cfg.carousel.skew !== undefined) ? root.cfg.carousel.skew : -0.35
                property real bw: (root.cfg.carousel && root.cfg.carousel.borderWidth) || 3
                property real slotW: (root.cfg.carousel && root.cfg.carousel.slotWidth) || 360
                property real sideBase: (root.cfg.carousel && root.cfg.carousel.sideScale) || 0.56
                property real persp: (root.cfg.carousel && root.cfg.carousel.perspective !== undefined) ? root.cfg.carousel.perspective : 0.00022
                readonly property real imgW: iw + ih * Math.abs(skew) + 12

                spacing: 0; clip: false; cacheBuffer: 2500
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: (width - slotW) / 2
                preferredHighlightEnd: (width + slotW) / 2
                highlightMoveDuration: 420
                highlightMoveVelocity: 3000
                snapMode: ListView.SnapToItem
                boundsBehavior: Flickable.StopAtBounds
                maximumFlickVelocity: 6000

                onCurrentIndexChanged: if (root.open) {
                    if (root.editorOpen) root.editorOpen = false
                    root.wallpaperPreviewed(root.centeredWallPath)
                }
                function applyCurrent() {
                    if (currentIndex < 0 || wallModel.count <= currentIndex) return
                    root.apply(wallModel.get(currentIndex, "fileName"))
                }

                delegate: Item {
                    id: slot
                    readonly property string wallPath: root.originalOf(model.fileName)
                    readonly property color accentCol: (root.slotAccents && root.slotAccents[slot.wallPath]) ? root.slotAccents[slot.wallPath] : root.activeAccent
                    readonly property real d: (x + width / 2 - (carousel.contentX + carousel.width / 2)) / carousel.slotW
                    width: carousel.slotW
                    height: carousel.height
                    readonly property real ad: Math.abs(d)
                    readonly property real sc: ad <= 1
                        ? carousel.sideBase + (1 - carousel.sideBase) * Math.pow(1 - ad, 1.35)
                        : carousel.sideBase * Math.pow(0.86, ad - 1)
                    z: Math.round(100 - ad * 10)
                    opacity: Math.max(0, Math.min(1, 1.15 - 0.34 * ad))

                    Item {
                        id: card
                        anchors.centerIn: parent
                        width: carousel.iw
                        height: carousel.ih
                        scale: slot.sc
                        transformOrigin: Item.Center
                        transform: Matrix4x4 {
                            matrix: {
                                const pv = -Math.max(-2.5, Math.min(2.5, slot.d)) * carousel.persp
                                const cx = carousel.iw / 2
                                const cy = carousel.ih / 2
                                return Qt.matrix4x4(
                                    1 + pv * cx, carousel.skew, 0, -pv * cx * cx - carousel.skew * cy,
                                    pv * cy, 1, 0, -pv * cx * cy,
                                    0, 0, 1, 0,
                                    pv, 0, 0, 1 - pv * cx
                                )
                            }
                        }

                        Rectangle {
                            id: cardGlow
                            anchors.fill: parent
                            visible: ((root.cfg.carousel && root.cfg.carousel.glowEnabled) !== false) && slot.ad < 0.45
                            color: Qt.rgba(slot.accentCol.r, slot.accentCol.g, slot.accentCol.b, 0.25)
                            border.width: 2
                            border.color: slot.accentCol
                            opacity: Math.max(0.0, 1.0 - slot.ad * 2.2) * root.glowPulse
                            layer.enabled: visible
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: slot.accentCol
                                shadowBlur: 1.0
                                blurMax: 28
                                shadowHorizontalOffset: 0
                                shadowVerticalOffset: 0
                            }
                        }

                        Item {
                            id: cardSurface
                            anchors.fill: parent
                            anchors.margins: -3
                            layer.enabled: true
                            layer.smooth: true
                            layer.mipmap: true

                            Item {
                                anchors.fill: parent
                                anchors.margins: 3

                                Rectangle {
                                    readonly property bool sideBorders: (root.cfg.carousel && root.cfg.carousel.sideBordersEnabled !== undefined) ? Boolean(root.cfg.carousel.sideBordersEnabled) : true
                                    readonly property real focusFactor: sideBorders ? 1.0 : Math.max(0.0, Math.min(1.0, 1.0 - slot.ad * 1.8))
                                    anchors.fill: parent
                                    antialiasing: true
                                    color: Qt.rgba(0.078, 0.086, 0.106, focusFactor)
                                    border.width: slot.ad < 0.25 ? 2 : (focusFactor > 0.05 ? 1 : 0)
                                    border.color: slot.ad < 0.45
                                        ? Qt.rgba(slot.accentCol.r, slot.accentCol.g, slot.accentCol.b, Math.max(sideBorders ? 0.22 : 0.0, 0.95 * (1.0 - slot.ad * 1.6)))
                                        : (sideBorders ? Qt.rgba(1, 1, 1, 0.22) : "transparent")
                                }
                                Item {
                                    readonly property bool sideBorders: (root.cfg.carousel && root.cfg.carousel.sideBordersEnabled !== undefined) ? Boolean(root.cfg.carousel.sideBordersEnabled) : true
                                    readonly property real focusFactor: sideBorders ? 1.0 : Math.max(0.0, Math.min(1.0, 1.0 - slot.ad * 1.8))
                                    anchors.fill: parent; anchors.margins: carousel.bw * focusFactor; clip: true
                                    Image {
                                        anchors.centerIn: parent
                                        width: carousel.imgW
                                        height: carousel.ih
                                        fillMode: Image.PreserveAspectCrop
                                        source: model.fileUrl
                                        asynchronous: true; cache: true; mipmap: true; smooth: true; antialiasing: true
                                        sourceSize: Qt.size(carousel.imgW, carousel.ih)
                                        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -carousel.skew, 0, carousel.skew * carousel.ih / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                                    }
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: slot.ad < 0.5 ? carousel.applyCurrent() : (carousel.currentIndex = index)
                        }
                    }

                    // Bottom Slot: mounted per-card (used by NoctWall-OpenRGB zone dock & profile drawer)
                    Item {
                        id: bottomSlotMount
                        anchors.centerIn: parent
                        width: carousel.iw
                        height: carousel.ih
                        scale: slot.sc
                        readonly property real centerFocus: Math.max(0, 1.0 - slot.ad * 2.5)
                        opacity: centerFocus
                        visible: centerFocus > 0.01

                        Repeater {
                            model: root.enabledPlugins
                            delegate: Loader {
                                required property string modelData
                                anchors.fill: parent
                                source: modelData === "noctwall-studio" ? "" : Qt.resolvedUrl("plugins/" + modelData + "/BottomSlot.qml")
                                asynchronous: false
                                onLoaded: if (item) {
                                    if (item.hasOwnProperty("api")) item.api = root.pluginApi
                                    if (item.hasOwnProperty("wallPath")) item.wallPath = Qt.binding(() => slot.wallPath)
                                    if (item.hasOwnProperty("slotAd")) item.slotAd = Qt.binding(() => slot.ad)
                                }
                            }
                        }
                    }
                }
            }

            // Stage Overlay Slot: mounted on screen above global wheel handler (z: 999)
            Repeater {
                model: root.enabledPlugins
                delegate: Loader {
                    required property string modelData
                    anchors.fill: parent
                    z: 1000
                    source: modelData === "noctwall-openrgb" ? "" : Qt.resolvedUrl("plugins/" + modelData + "/StageOverlay.qml")
                    asynchronous: false
                    onLoaded: if (item && item.hasOwnProperty("api")) item.api = root.pluginApi
                }
            }

            Text {
                anchors.centerIn: parent
                visible: wallModel.count === 0
                text: "No wallpapers found in " + root.wallsDir
                color: "#e6e9ef"
                font.pixelSize: 18
                opacity: 0.9
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowBlur: 1.0
                    blurMax: 16
                    shadowVerticalOffset: 0
                }
            }
        }
    }
}
