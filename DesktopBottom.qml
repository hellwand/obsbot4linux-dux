import QtQuick
import qs.Common
import qs.DCommon.Common
import qs.DCommon.Widgets
import "lib/lists.mjs" as Lists

// Bottom row of the desktop widget card, full card width: zoom (- / slider / +) on the left,
// the camera's preset slots in the middle, Sleep / Wake at the right end (Retry when the
// camera is not reachable). No background; zoom and presets are greyed out (not hidden) while the
// camera cannot take them, so the card keeps its size.
//
// ctl is the DesktopPreview: link, available, live, toggleAwake(), stepZoom(), refresh().
// Two lines: the labels (the zoom slider's own label with its value, Presets), then the controls,
// all of one height (Style.buttonHeightS) and standing on one line.
// interactive: false ignores the buttons (desktop edit mode).
Item {
    id: bottom

    property var ctl
    property bool interactive: true

    // what is left of the row besides the Sleep / Wake button, split 1 : 1
    readonly property real sectionWidth: (width - powerButton.width - Theme.spacingL * 2) / 2
    // the one height of every control on the second line
    readonly property real controlHeight: Style.buttonHeightS
    // the camera's slots and the zoom bounds, all from its description and state
    readonly property var rows: Lists.presetRows(ctl.link.device, ctl.link.camState)
    readonly property var zoomSpec: ctl.link.spec("zoom.factor")
    readonly property var zoomNow: ctl.link.value("zoom.factor")
    readonly property bool zoomFree: zoomSpec !== null && zoomSpec.min !== null && zoomSpec.max !== null && typeof zoomNow === "number" && ctl.link.blocked("zoom.factor") === null
    // both lines: the slider brings its own label line, the presets get theirs
    readonly property real contentHeight: Math.max(zoomSlider.height, presetsLabel.implicitHeight + Theme.spacingS + controlHeight)

    implicitHeight: contentHeight

    // - / slider with its label and value / +; the buttons stand on the slider's line
    Item {
        id: zoomItem
        width: bottom.sectionWidth
        height: bottom.contentHeight
        enabled: bottom.interactive
        visible: bottom.ctl.link.has("zoom.factor")

        DButton {
            id: zoomOut
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            buttonHeight: bottom.controlHeight
            iconName: "remove"
            minimumWidth: 0
            tooltipText: "Zoom out"
            enabled: bottom.zoomFree && bottom.zoomNow > bottom.zoomSpec.min
            onClicked: bottom.ctl.stepZoom(-1)
        }

        SettingSlider {
            id: zoomSlider
            anchors.left: zoomOut.right
            anchors.right: zoomIn.left
            anchors.margins: Theme.spacingS
            anchors.bottom: parent.bottom
            link: bottom.ctl.link
            path: "zoom.factor"
            text: "Zoom"
        }

        DButton {
            id: zoomIn
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            buttonHeight: bottom.controlHeight
            iconName: "add"
            minimumWidth: 0
            tooltipText: "Zoom in"
            enabled: bottom.zoomFree && bottom.zoomNow < bottom.zoomSpec.max
            onClicked: bottom.ctl.stepZoom(1)
        }
    }

    // As many equal slots as the camera has, in slot order; an empty slot leaves its place blank,
    // so a preset keeps its position. Long names are elided in the button and shown in full as
    // the tooltip.
    Item {
        id: presetsItem
        x: bottom.sectionWidth + Theme.spacingL
        width: bottom.sectionWidth
        height: bottom.contentHeight
        enabled: bottom.interactive
        opacity: bottom.ctl.link.blocked("preset.recall") === null ? 1 : 0.38
        visible: bottom.ctl.link.has("presets")

        readonly property bool anySaved: bottom.rows !== null && bottom.rows.some(r => r.used)
        readonly property int slotCount: Math.max(1, bottom.rows?.length ?? 0)
        readonly property real slotWidth: (width - Theme.spacingS * (slotCount - 1)) / slotCount

        StyledText {
            id: presetsLabel
            text: "Presets"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
        }

        Row {
            anchors.bottom: parent.bottom
            spacing: Theme.spacingS
            visible: presetsItem.anySaved

            Repeater {
                model: bottom.rows ?? []

                PresetSlot {
                    required property var modelData
                    width: presetsItem.slotWidth
                    height: bottom.controlHeight
                    link: bottom.ctl.link
                    row: modelData
                }
            }
        }

        StyledText {
            anchors.bottom: parent.bottom
            width: parent.width
            height: bottom.controlHeight
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            visible: !presetsItem.anySaved
            text: bottom.rows === null ? (bottom.ctl.available ? "Presets not read yet" : "") : "No presets saved"
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    DButton {
        id: powerButton
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        buttonHeight: bottom.controlHeight
        enabled: bottom.interactive && (!bottom.ctl.available || bottom.ctl.link.blocked(bottom.ctl.live ? "sleep" : "wake") === null)
        text: !bottom.ctl.available ? "Retry" : bottom.ctl.live ? "Sleep" : "Wake"
        iconName: !bottom.ctl.available ? "refresh" : bottom.ctl.live ? "bedtime" : "videocam"
        onClicked: {
            if (!bottom.ctl.available)
                bottom.ctl.refresh();
            else
                bottom.ctl.toggleAwake();
        }
    }
}
