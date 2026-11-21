import QtQuick
import QtQuick.Effects

Item {
    id: zoneDock
    property var api: null
    property string wallPath: ""
    property real slotAd: 0

    readonly property var ctrl: Qt.application._noctwallOpenRgb || null
    readonly property real cardW: zoneDock.api ? zoneDock.api.cardWidth : 720
    readonly property real cardH: zoneDock.api ? zoneDock.api.cardHeight : 406
    readonly property real skew: zoneDock.api ? zoneDock.api.skew : -0.35
    readonly property color accentCol: zoneDock.api ? zoneDock.api.accentForWall(zoneDock.wallPath) : "#7aa2f7"

    readonly property real zoneH: 18
    readonly property real zoneGap: 8
    readonly property real gapY: 12
    readonly property real zoneW: (zoneDock.cardW - 4 * zoneGap) / 5
    readonly property real dockBaseX: zoneDock.skew * (zoneDock.cardH / 2 + zoneDock.gapY + zoneDock.zoneH + 18)

    readonly property var modeObj: zoneDock.ctrl ? zoneDock.ctrl.activeModeObj() : ({ name: "Accent & Glow", colors: ["#7aa2f7","#9ece6a","#f7768e","#e0af68","#bb9af7"] })
    readonly property int modeIdx: zoneDock.ctrl ? zoneDock.ctrl.modeIdx : 0
    readonly property int modeCount: (zoneDock.ctrl && zoneDock.ctrl.modes) ? zoneDock.ctrl.modes.length : 6
    readonly property bool isEdOpen: zoneDock.ctrl ? zoneDock.ctrl.editorOpen : false
    readonly property int edZone: zoneDock.ctrl ? zoneDock.ctrl.editorZone : 0
    readonly property var edColors: (zoneDock.ctrl && zoneDock.ctrl.editorColors) ? zoneDock.ctrl.editorColors : ["#7aa2f7","#bb9af7","#f7768e","#e0af68","#7dcfff"]

    // 1. 5 skewed zone bars matching the card parallelogram geometry
    Row {
        x: zoneDock.skew * (zoneDock.cardH / 2 + zoneDock.gapY + zoneDock.zoneH / 2)
        y: zoneDock.cardH + zoneDock.gapY
        spacing: zoneDock.zoneGap
        Repeater {
            model: 5
            Rectangle {
                width: zoneDock.zoneW
                height: zoneDock.zoneH
                readonly property string rawHex: zoneDock.isEdOpen
                    ? (zoneDock.edColors[index] || "#7aa2f7")
                    : ((zoneDock.modeObj && zoneDock.modeObj.colors && zoneDock.modeObj.colors[index]) || "#7aa2f7")
                color: zoneDock.ctrl ? zoneDock.ctrl.boostHex(rawHex) : rawHex
                border.width: zoneDock.isEdOpen && zoneDock.edZone === index ? 2 : 1
                border.color: zoneDock.isEdOpen && zoneDock.edZone === index ? "#ffffff" : Qt.rgba(1, 1, 1, 0.28)
                transform: Matrix4x4 { matrix: Qt.matrix4x4(1, zoneDock.skew, 0, -zoneDock.skew * zoneDock.zoneH / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                Behavior on color { ColorAnimation { duration: 120 } }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!zoneDock.ctrl) return
                        if (zoneDock.isEdOpen) zoneDock.ctrl.editorZone = index
                        else zoneDock.ctrl.cycleMode(1)
                    }
                }
            }
        }
    }

    // 2. Profile switcher row (<  1/6 · Accent & Glow  >  + Profile  [✕])
    Row {
        x: zoneDock.dockBaseX + (zoneDock.cardW - width) / 2
        y: zoneDock.cardH + zoneDock.gapY + zoneDock.zoneH + 8
        spacing: 10

        Rectangle {
            width: 22; height: 22; radius: 6
            color: "#cc14161b"
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.2)
            Text { anchors.centerIn: parent; text: "<"; color: "#e6e9ef"; font.pixelSize: 12; font.weight: Font.Bold }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (zoneDock.ctrl) zoneDock.ctrl.cycleMode(-1) }
        }

        Item {
            width: modeLabel.implicitWidth + 12
            height: 22
            Text {
                id: modeLabel
                anchors.centerIn: parent
                text: (zoneDock.modeIdx + 1) + "/" + Math.max(1, zoneDock.modeCount) + "  ·  " + (zoneDock.modeObj ? zoneDock.modeObj.name : "Accent & Glow")
                color: "#e6e9ef"
                font.pixelSize: 12
                font.weight: Font.Medium
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (zoneDock.ctrl) zoneDock.ctrl.cycleMode(1) }
        }

        Rectangle {
            width: 22; height: 22; radius: 6
            color: "#cc14161b"
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.2)
            Text { anchors.centerIn: parent; text: ">"; color: "#e6e9ef"; font.pixelSize: 12; font.weight: Font.Bold }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (zoneDock.ctrl) zoneDock.ctrl.cycleMode(1) }
        }

        Rectangle {
            width: addBtnTxt.implicitWidth + 16; height: 22; radius: 6
            color: zoneDock.isEdOpen ? zoneDock.accentCol : "#cc14161b"
            border.width: 1; border.color: zoneDock.isEdOpen ? "#ffffff" : Qt.rgba(1, 1, 1, 0.24)
            Text {
                id: addBtnTxt
                anchors.centerIn: parent
                text: zoneDock.isEdOpen ? "Close" : "+ Profile"
                color: "#ffffff"
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (zoneDock.ctrl) zoneDock.ctrl.toggleEditor() }
        }

        Rectangle {
            visible: zoneDock.modeIdx >= 6 && !zoneDock.isEdOpen
            width: 22; height: 22; radius: 6
            color: "#cc2b1418"
            border.width: 1; border.color: "#80ff6b6b"
            Text { anchors.centerIn: parent; text: "✕"; color: "#ff8787"; font.pixelSize: 11; font.weight: Font.Bold }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (zoneDock.ctrl) zoneDock.ctrl.deleteActiveCustom() }
        }
    }

    // 3. Saturation & Brightness live sliders
    Row {
        id: slidersRow
        x: zoneDock.dockBaseX
        y: zoneDock.cardH + zoneDock.gapY + zoneDock.zoneH + 38
        spacing: 14

        Repeater {
            model: [
                { label: "Saturation", minV: -50, maxV: 100, isSat: true },
                { label: "Brightness", minV: -50, maxV: 80, isSat: false }
            ]
            Rectangle {
                readonly property int curVal: zoneDock.ctrl ? (modelData.isSat ? zoneDock.ctrl.sat : zoneDock.ctrl.val) : 0
                readonly property real norm: (curVal - modelData.minV) / (modelData.maxV - modelData.minV)
                width: (zoneDock.cardW - 14) / 2
                height: 28
                radius: 8
                color: "#cc14161b"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.16)

                Text {
                    id: sLbl
                    anchors.left: parent.left; anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: "#cbd2df"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }

                Text {
                    id: sValTxt
                    anchors.right: parent.right; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    horizontalAlignment: Text.AlignRight
                    text: (curVal > 0 ? "+" : "") + curVal + "%"
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }

                Item {
                    id: trackArea
                    anchors.left: sLbl.right; anchors.leftMargin: 10
                    anchors.right: sValTxt.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 20

                    function updateFromX(mx) {
                        if (!zoneDock.ctrl) return
                        const r = Math.max(0.0, Math.min(1.0, mx / Math.max(1, width)))
                        const raw = modelData.minV + r * (modelData.maxV - modelData.minV)
                        const snapped = Math.round(raw / 5) * 5
                        if (modelData.isSat) {
                            if (zoneDock.ctrl.sat !== snapped) { zoneDock.ctrl.sat = snapped; zoneDock.ctrl.scheduleTune() }
                        } else {
                            if (zoneDock.ctrl.val !== snapped) { zoneDock.ctrl.val = snapped; zoneDock.ctrl.scheduleTune() }
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 4; radius: 2
                        color: Qt.rgba(1, 1, 1, 0.16)

                        Rectangle {
                            width: parent.width * norm
                            height: parent.height; radius: 2
                            color: zoneDock.accentCol
                        }
                    }

                    Rectangle {
                        x: Math.max(0, Math.min(parent.width - width, parent.width * norm - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12; height: 12; radius: 6
                        color: "#ffffff"
                        border.width: 2; border.color: zoneDock.accentCol
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onPressed: (m) => trackArea.updateFromX(m.x)
                        onPositionChanged: (m) => { if (pressed) trackArea.updateFromX(m.x) }
                        onDoubleClicked: {
                            if (!zoneDock.ctrl) return
                            if (modelData.isSat) zoneDock.ctrl.sat = 0
                            else zoneDock.ctrl.val = 0
                            zoneDock.ctrl.scheduleTune()
                        }
                    }
                }
            }
        }
    }

    // 4. Custom Profile Editor Drawer (fixed swatch color bug from v1)
    Rectangle {
        id: editorDrawer
        visible: zoneDock.isEdOpen && zoneDock.slotAd < 0.25
        x: zoneDock.dockBaseX
        y: zoneDock.cardH + zoneDock.gapY + zoneDock.zoneH + 74
        width: zoneDock.cardW
        height: 124
        radius: 12
        color: "#eb14161b"
        border.width: 1
        border.color: Qt.rgba(zoneDock.accentCol.r, zoneDock.accentCol.g, zoneDock.accentCol.b, 0.55)
        layer.enabled: visible
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowBlur: 0.9
            blurMax: 20
            shadowVerticalOffset: 6
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Row {
                width: parent.width
                height: 28
                spacing: 8

                Rectangle {
                    width: parent.width - 236
                    height: 28
                    radius: 6
                    color: "#ff0d0f13"
                    border.width: 1
                    border.color: nameInput.activeFocus ? zoneDock.accentCol : Qt.rgba(1, 1, 1, 0.22)

                    TextInput {
                        id: nameInput
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: "#ffffff"
                        font.pixelSize: 12
                        selectByMouse: true
                        text: zoneDock.ctrl ? zoneDock.ctrl.editorName : ""
                        onTextEdited: if (zoneDock.ctrl) zoneDock.ctrl.editorName = text
                        Keys.onEscapePressed: if (zoneDock.ctrl) zoneDock.ctrl.closeEditor()
                        Keys.onReturnPressed: if (zoneDock.ctrl) zoneDock.ctrl.saveEditorProfile()
                        Keys.onEnterPressed: if (zoneDock.ctrl) zoneDock.ctrl.saveEditorProfile()
                    }
                }

                Rectangle {
                    width: 74; height: 28; radius: 6
                    color: "#ff1e222b"
                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.22)
                    Text { anchors.centerIn: parent; text: "Random"; color: "#e6e9ef"; font.pixelSize: 11; font.weight: Font.Medium }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (zoneDock.ctrl) zoneDock.ctrl.randomizeEditorColors() }
                }

                Rectangle {
                    width: 70; height: 28; radius: 6
                    color: zoneDock.accentCol
                    border.width: 1; border.color: "#40ffffff"
                    Text { anchors.centerIn: parent; text: "Save"; color: "#ffffff"; font.pixelSize: 11; font.weight: Font.Bold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (zoneDock.ctrl) zoneDock.ctrl.saveEditorProfile() }
                }

                Rectangle {
                    width: 68; height: 28; radius: 6
                    color: "#ff1e222b"
                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.18)
                    Text { anchors.centerIn: parent; text: "Cancel"; color: "#aab2c0"; font.pixelSize: 11 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (zoneDock.ctrl) zoneDock.ctrl.closeEditor() }
                }
            }

            Row {
                width: parent.width
                height: 26
                spacing: 8
                Repeater {
                    model: 5
                    Rectangle {
                        width: (parent.width - 32) / 5
                        height: 26
                        radius: 6
                        readonly property string zHex: zoneDock.edColors[index] || "#7aa2f7"
                        color: zoneDock.ctrl ? zoneDock.ctrl.boostHex(zHex) : zHex
                        border.width: zoneDock.edZone === index ? 2 : 1
                        border.color: zoneDock.edZone === index ? "#ffffff" : Qt.rgba(1, 1, 1, 0.25)
                        Text {
                            anchors.centerIn: parent
                            text: "Z" + (index + 1)
                            color: "#ffffff"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            style: Text.Outline; styleColor: "#80000000"
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (zoneDock.ctrl) zoneDock.ctrl.editorZone = index }
                    }
                }
            }

            Row {
                width: parent.width
                height: 26
                spacing: 6
                readonly property var pal: (zoneDock.ctrl && zoneDock.ctrl.pool && zoneDock.ctrl.pool.length > 0)
                    ? zoneDock.ctrl.pool
                    : ["#7aa2f7", "#bb9af7", "#f7768e", "#e0af68", "#7dcfff", "#9ece6a"]
                Repeater {
                    model: parent.pal
                    Rectangle {
                        width: Math.min(48, (editorDrawer.width - 24 - (parent.pal.length - 1) * 6) / Math.max(1, parent.pal.length))
                        height: 26
                        radius: 6
                        color: zoneDock.ctrl ? zoneDock.ctrl.boostHex(modelData) : modelData
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.35)
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (zoneDock.ctrl) zoneDock.ctrl.setEditorZoneColor(modelData)
                        }
                    }
                }
            }
        }
    }
}
