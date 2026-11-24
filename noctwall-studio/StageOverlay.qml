import QtQuick

Item {
    id: studio
    property var api: null

    readonly property bool isOpen: studio.api ? studio.api.studioOpen : false
    readonly property bool isEditorOpen: studio.api ? studio.api.editorOpen : false
    readonly property color accentCol: studio.api ? studio.api.activeAccent : "#7aa2f7"
    readonly property var cfg: studio.api ? studio.api.cfg : ({})
    readonly property var car: (studio.cfg && studio.cfg.carousel) ? studio.cfg.carousel : ({})
    readonly property var trn: (studio.cfg && studio.cfg.transitions) ? studio.cfg.transitions : ({})
    readonly property var pth: (studio.cfg && studio.cfg.paths) ? studio.cfg.paths : ({})
    readonly property var enabledList: (studio.cfg && studio.cfg.plugins && Array.isArray(studio.cfg.plugins.enabled))
        ? studio.cfg.plugins.enabled
        : ["noctwall-openrgb", "noctwall-studio"]

    // Match the exact vertical geometry of the central dark backdrop band
    readonly property real carH: (studio.car && studio.car.height !== undefined) ? Number(studio.car.height) : 560
    readonly property real blurPad: studio.isEditorOpen
        ? ((studio.car && studio.car.blurEditorPadding !== undefined) ? Number(studio.car.blurEditorPadding) : 240)
        : ((studio.car && studio.car.blurPadding !== undefined) ? Number(studio.car.blurPadding) : 96)
    readonly property real bandH: studio.carH + studio.blurPad
    readonly property real bandBottomY: (studio.height + studio.bandH) / 2

    property bool savedFlash: false
    property bool sliderDragging: false
    onIsOpenChanged: if (!isOpen) sliderDragging = false
    property string actionFeedback: ""

    function setParam(section, key, val) {
        if (!studio.api) return
        let patch = {}
        patch[key] = val
        studio.api.updateConfigSection(section, patch)
    }

    function togglePlugin(pluginId) {
        if (!studio.api) return
        let list = studio.enabledList.slice()
        const idx = list.indexOf(pluginId)
        if (idx >= 0) list.splice(idx, 1)
        else list.push(pluginId)
        if (list.indexOf("noctwall-studio") < 0) list.push("noctwall-studio")
        studio.api.updateConfigSection("plugins", { enabled: list })
    }

    Timer {
        id: savedTimer
        interval: 1500
        onTriggered: studio.savedFlash = false
    }

    Timer {
        id: actionTimer
        interval: 2200
        onTriggered: studio.actionFeedback = ""
    }

    component SectionHeader: Text {
        color: studio.accentCol
        font.pixelSize: 11
        font.weight: Font.Bold
        font.letterSpacing: 0.8
        topPadding: 6
    }

    component ToggleRow: Row {
        id: tRow
        property string label: ""
        property bool checked: false
        signal toggled()

        width: parent ? parent.width : 308
        height: 24

        Text {
            width: parent.width - pill.width
            anchors.verticalCenter: parent.verticalCenter
            text: tRow.label
            color: "#cfd5e6"
            font.pixelSize: 11
        }
        Rectangle {
            id: pill
            width: 38
            height: 20
            radius: 10
            anchors.verticalCenter: parent.verticalCenter
            color: tRow.checked ? studio.accentCol : "#262a36"
            Rectangle {
                width: 14
                height: 14
                radius: 7
                y: 3
                x: tRow.checked ? 21 : 3
                color: "#ffffff"
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tRow.toggled()
            }
        }
    }

    component SliderRow: Column {
        id: sRow
        property string label: ""
        property string sectionName: "carousel"
        property string keyName: ""
        property real defaultVal: 0
        property real minVal: 0
        property real maxVal: 100
        property real stepSize: 1
        property int decimals: 0
        property string suffix: ""

        readonly property real currentVal: {
            const sec = studio.cfg ? studio.cfg[sRow.sectionName] : null
            const v = (sec && sec[sRow.keyName] !== undefined) ? Number(sec[sRow.keyName]) : sRow.defaultVal
            return isNaN(v) ? sRow.defaultVal : v
        }
        readonly property real ratio: Math.max(0, Math.min(1, (sRow.currentVal - sRow.minVal) / Math.max(0.000001, sRow.maxVal - sRow.minVal)))

        width: parent ? parent.width : 308
        spacing: 5

        Row {
            width: parent.width
            Text {
                width: parent.width - valTxt.implicitWidth
                text: sRow.label
                color: "#cfd5e6"
                font.pixelSize: 11
            }
            Text {
                id: valTxt
                text: sRow.currentVal.toFixed(sRow.decimals) + sRow.suffix
                color: "#ffffff"
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        Item {
            id: track
            width: parent.width
            height: 18

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: "#262a36"

                Rectangle {
                    width: knob.x + knob.width / 2
                    height: parent.height
                    radius: 2
                    color: studio.accentCol
                }
            }

            Rectangle {
                id: knob
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 7
                color: "#ffffff"
                border.width: 2
                border.color: studio.accentCol
                x: sRow.ratio * Math.max(1, track.width - width)
            }

            MouseArea {
                anchors.fill: parent
                anchors.topMargin: -6
                anchors.bottomMargin: -4
                preventStealing: true
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function applyMouse(mx) {
                    const usable = Math.max(1, track.width - knob.width)
                    const r = Math.max(0, Math.min(1, (mx - knob.width / 2) / usable))
                    const raw = sRow.minVal + r * (sRow.maxVal - sRow.minVal)
                    const stepped = Math.round(raw / sRow.stepSize) * sRow.stepSize
                    const clamped = Math.max(sRow.minVal, Math.min(sRow.maxVal, Number(stepped.toFixed(sRow.decimals))))
                    studio.setParam(sRow.sectionName, sRow.keyName, clamped)
                }
                onPressed: (mouse) => {
                    studio.sliderDragging = true
                    applyMouse(mouse.x)
                }
                onPositionChanged: (mouse) => {
                    if (pressed) applyMouse(mouse.x)
                }
                onReleased: studio.sliderDragging = false
                onCanceled: studio.sliderDragging = false
            }
        }
    }

    // Subtle debossed "studio" button stamped into the bottom-right corner of the picker band
    Rectangle {
        id: toggleBtn
        y: studio.bandBottomY - height - 10
        anchors.right: parent.right
        anchors.rightMargin: 18
        width: btnRow.implicitWidth + 18
        height: 24
        radius: 6
        clip: true
        color: studio.isOpen
            ? Qt.rgba(studio.accentCol.r, studio.accentCol.g, studio.accentCol.b, 0.22)
            : (btnMouse.containsMouse ? "#66000000" : "#4d000000")
        border.width: 1
        border.color: studio.isOpen
            ? Qt.rgba(studio.accentCol.r, studio.accentCol.g, studio.accentCol.b, 0.55)
            : "#73000000"
        z: 10

        Behavior on y {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // Top inner shadow + bottom highlight lip for a debossed/imprinted feel
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: "#80000000"
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: studio.isOpen ? Qt.rgba(1, 1, 1, 0.22) : "#22ffffff"
        }

        Row {
            id: btnRow
            anchors.centerIn: parent
            spacing: 6

            Canvas {
                id: gearIcon
                width: 12
                height: 12
                anchors.verticalCenter: parent.verticalCenter
                property color iconColor: studio.isOpen ? "#ffffff" : (btnMouse.containsMouse ? "#d6dcec" : "#8f98b0")
                onIconColorChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    const cx = width / 2
                    const cy = height / 2
                    const teeth = 8
                    const rOuter = 5.4
                    const rInner = 3.8
                    ctx.save()
                    ctx.fillStyle = iconColor
                    ctx.beginPath()
                    for (let i = 0; i < teeth * 2; i++) {
                        const r = (i % 2 === 0) ? rOuter : rInner
                        const a = (i * Math.PI) / teeth
                        const px = cx + Math.cos(a) * r
                        const py = cy + Math.sin(a) * r
                        if (i === 0) ctx.moveTo(px, py)
                        else ctx.lineTo(px, py)
                    }
                    ctx.closePath()
                    ctx.fill()
                    ctx.globalCompositeOperation = "destination-out"
                    ctx.beginPath()
                    ctx.arc(cx, cy, 1.75, 0, Math.PI * 2)
                    ctx.fill()
                    ctx.restore()
                }
            }

            Text {
                text: "studio"
                color: studio.isOpen ? "#ffffff" : (btnMouse.containsMouse ? "#d6dcec" : "#8f98b0")
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 0.4
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!studio.api) return
                studio.api.studioOpen = !studio.api.studioOpen
                if (!studio.api.studioOpen) studio.api.refocusStage()
            }
        }
    }

    // Right-hand Glassmorphism Tuner Drawer opening directly above the debossed button
    Rectangle {
        id: drawer
        anchors.bottom: toggleBtn.top
        anchors.right: toggleBtn.right
        anchors.bottomMargin: 10
        width: 344
        height: Math.min(Math.max(260, toggleBtn.y - 64), contentCol.implicitHeight + 32)
        radius: 14
        color: "#f012141a"
        border.width: 1
        border.color: Qt.rgba(studio.accentCol.r, studio.accentCol.g, studio.accentCol.b, 0.50)
        visible: opacity > 0.01
        opacity: studio.isOpen ? 1.0 : 0.0
        z: 9

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        // Absorb clicks and leftover wheel events at scroll bounds so carousel stays locked
        MouseArea {
            anchors.fill: parent
            onWheel: (e) => { e.accepted = true }
        }

        Flickable {
            id: flick
            interactive: !studio.sliderDragging
            anchors.fill: parent
            anchors.margins: 16
            contentWidth: width
            contentHeight: contentCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: contentCol
                width: parent.width
                spacing: 10

                Row {
                    width: parent.width
                    Text {
                        width: parent.width - badge.implicitWidth
                        text: "NoctWall Studio"
                        color: "#ffffff"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                    Text {
                        id: badge
                        text: "LIVE"
                        color: studio.accentCol
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.1) }

                SectionHeader { text: "ACTIVE PLUGINS" }

                ToggleRow {
                    label: "OpenRGB Zone Sync (Keyboard RGB)"
                    checked: studio.enabledList.indexOf("noctwall-openrgb") >= 0
                    onToggled: studio.togglePlugin("noctwall-openrgb")
                }

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.1) }

                SectionHeader { text: "CAROUSEL GEOMETRY" }

                SliderRow { label: "Card Width"; sectionName: "carousel"; keyName: "cardWidth"; defaultVal: 720; minVal: 420; maxVal: 1080; stepSize: 10; suffix: " px" }
                SliderRow { label: "Card Height"; sectionName: "carousel"; keyName: "cardHeight"; defaultVal: 406; minVal: 240; maxVal: 620; stepSize: 6; suffix: " px" }
                SliderRow { label: "Skew Angle"; sectionName: "carousel"; keyName: "skew"; defaultVal: -0.35; minVal: -0.60; maxVal: 0.60; stepSize: 0.01; decimals: 2 }
                SliderRow { label: "Slot Spacing"; sectionName: "carousel"; keyName: "slotWidth"; defaultVal: 360; minVal: 180; maxVal: 560; stepSize: 10; suffix: " px" }
                SliderRow { label: "Side Scale"; sectionName: "carousel"; keyName: "sideScale"; defaultVal: 0.56; minVal: 0.30; maxVal: 0.90; stepSize: 0.02; decimals: 2 }
                SliderRow { label: "3D Perspective"; sectionName: "carousel"; keyName: "perspective"; defaultVal: 0.00022; minVal: 0.0; maxVal: 0.00080; stepSize: 0.00002; decimals: 5 }
                SliderRow { label: "Border Width"; sectionName: "carousel"; keyName: "borderWidth"; defaultVal: 3; minVal: 0; maxVal: 8; stepSize: 1; suffix: " px" }
                SliderRow { label: "Backdrop Blur"; sectionName: "carousel"; keyName: "blurPadding"; defaultVal: 96; minVal: 24; maxVal: 220; stepSize: 4; suffix: " px" }

                ToggleRow {
                    label: "Ambient Card Glow"
                    checked: (studio.car && studio.car.glowEnabled !== undefined) ? Boolean(studio.car.glowEnabled) : true
                    onToggled: studio.setParam("carousel", "glowEnabled", !((studio.car && studio.car.glowEnabled !== undefined) ? Boolean(studio.car.glowEnabled) : true))
                }

                ToggleRow {
                    label: "Side Card Borders"
                    checked: (studio.car && studio.car.sideBordersEnabled !== undefined) ? Boolean(studio.car.sideBordersEnabled) : true
                    onToggled: studio.setParam("carousel", "sideBordersEnabled", !((studio.car && studio.car.sideBordersEnabled !== undefined) ? Boolean(studio.car.sideBordersEnabled) : true))
                }

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.1) }

                SectionHeader { text: "TRANSITIONS & GLOW" }

                SliderRow { label: "Contagio Duration"; sectionName: "transitions"; keyName: "msContagio"; defaultVal: 1800; minVal: 300; maxVal: 3500; stepSize: 100; suffix: " ms" }
                SliderRow { label: "Perfil Duration"; sectionName: "transitions"; keyName: "msPerfil"; defaultVal: 2000; minVal: 300; maxVal: 3500; stepSize: 100; suffix: " ms" }
                SliderRow { label: "Glow Intensity"; sectionName: "transitions"; keyName: "glow"; defaultVal: 0.90; minVal: 0.0; maxVal: 2.0; stepSize: 0.05; decimals: 2 }

                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.1) }

                SectionHeader { text: "WALLPAPER PATHS & CACHE" }

                Text { text: "Wallpapers Directory"; color: "#9aa3ba"; font.pixelSize: 10 }
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: 6
                    color: "#1b1e28"
                    border.width: 1
                    border.color: dirInput.activeFocus ? studio.accentCol : Qt.rgba(1, 1, 1, 0.14)
                    TextInput {
                        id: dirInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#ffffff"
                        font.pixelSize: 11
                        clip: true
                        selectByMouse: true
                        text: (studio.pth && studio.pth.wallpapersDir) ? studio.pth.wallpapersDir : "~/Pictures/Wallpapers"
                        onEditingFinished: {
                            studio.setParam("paths", "wallpapersDir", text)
                            if (studio.api) studio.api.refocusStage()
                        }
                        Keys.onReturnPressed: (e) => {
                            editingFinished()
                            e.accepted = true
                        }
                        Keys.onEnterPressed: (e) => {
                            editingFinished()
                            e.accepted = true
                        }
                        Keys.onEscapePressed: (e) => {
                            focus = false
                            if (studio.api) studio.api.refocusStage()
                            e.accepted = true
                        }
                    }
                }

                Text { text: "Random Subdirectory"; color: "#9aa3ba"; font.pixelSize: 10 }
                Rectangle {
                    width: parent.width
                    height: 28
                    radius: 6
                    color: "#1b1e28"
                    border.width: 1
                    border.color: subInput.activeFocus ? studio.accentCol : Qt.rgba(1, 1, 1, 0.14)
                    TextInput {
                        id: subInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#ffffff"
                        font.pixelSize: 11
                        clip: true
                        selectByMouse: true
                        text: (studio.pth && studio.pth.randomSubdir) ? studio.pth.randomSubdir : "UltraDual"
                        onEditingFinished: {
                            studio.setParam("paths", "randomSubdir", text)
                            if (studio.api) studio.api.refocusStage()
                        }
                        Keys.onReturnPressed: (e) => {
                            editingFinished()
                            e.accepted = true
                        }
                        Keys.onEnterPressed: (e) => {
                            editingFinished()
                            e.accepted = true
                        }
                        Keys.onEscapePressed: (e) => {
                            focus = false
                            if (studio.api) studio.api.refocusStage()
                            e.accepted = true
                        }
                    }
                }

                // Cache maintenance actions
                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 28
                        radius: 6
                        color: "#1b1e28"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.14)
                        Text {
                            anchors.centerIn: parent
                            text: "Refresh Thumbs"
                            color: "#cfd5e6"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!studio.api) return
                                studio.api.rebuildThumbs()
                                studio.actionFeedback = "Refreshing thumbnails..."
                                actionTimer.restart()
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 28
                        radius: 6
                        color: "#1b1e28"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.14)
                        Text {
                            anchors.centerIn: parent
                            text: "Warm Masks"
                            color: "#cfd5e6"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!studio.api) return
                                studio.api.warmMasks()
                                studio.actionFeedback = "Precomputing outline masks..."
                                actionTimer.restart()
                            }
                        }
                    }
                }

                Text {
                    visible: studio.actionFeedback !== ""
                    text: studio.actionFeedback
                    color: studio.accentCol
                    font.pixelSize: 10
                }

                Item { width: 1; height: 2 }

                // Action buttons: Reset & Save
                Row {
                    width: parent.width
                    spacing: 8

                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 32
                        radius: 8
                        color: "#222634"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.16)
                        Text {
                            anchors.centerIn: parent
                            text: "Reset Defaults"
                            color: "#cfd5e6"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (studio.api) studio.api.resetConfig()
                        }
                    }

                    Rectangle {
                        width: (parent.width - 8) / 2
                        height: 32
                        radius: 8
                        color: studio.savedFlash ? "#2e7d32" : studio.accentCol
                        Text {
                            anchors.centerIn: parent
                            text: studio.savedFlash ? "Saved!" : "Save Config"
                            color: "#ffffff"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!studio.api) return
                                studio.api.saveConfig()
                                studio.savedFlash = true
                                savedTimer.restart()
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: flick.contentHeight > flick.height
            anchors.right: parent.right
            anchors.rightMargin: 5
            width: 3
            radius: 1.5
            color: Qt.rgba(studio.accentCol.r, studio.accentCol.g, studio.accentCol.b, 0.55)
            y: 16 + (flick.visibleArea.yPosition * flick.height)
            height: Math.max(24, flick.visibleArea.heightRatio * flick.height)
        }
    }
}
