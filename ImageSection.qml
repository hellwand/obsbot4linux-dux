import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "lib/format.mjs" as Format

// Image adjustments with the reset button at the bottom
SectionCard {
    id: section

    property var ctl

    // The sliders of this card; the defaults reset covers exactly these (10.3 D: the widget's
    // product choice, unchanged from 0.29)
    readonly property var controls: [
        {
            path: "image.brightness",
            text: "Brightness"
        },
        {
            path: "image.contrast",
            text: "Contrast"
        },
        {
            path: "image.saturation",
            text: "Saturation"
        },
        {
            path: "image.sharpness",
            text: "Sharpness"
        },
        {
            path: "exposure.compensation",
            text: "Backlight compensation"
        }
    ]
    readonly property var shown: controls.filter(c => ctl.link.has(c.path))
    readonly property var resetPatch: ctl.link.defaultsPatch(controls.map(c => c.path))

    title: "Image"
    collapsible: true
    visible: ctl.cardEnabled("Image") && shown.length > 0
    summary: (shown.length > 0 && resetPatch === null ? "Defaults: " : "") + shown.map(c => c.text + " " + Format.value(ctl.link.setting(c.path), ctl.link.value(c.path), ctl.labels(c.path))).join(" · ")
    // the camera takes these while asleep too and keeps them when it wakes
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38

    Column {
        width: parent.width
        spacing: Theme.spacingS

        Repeater {
            model: section.controls

            SettingSlider {
                required property var modelData
                width: parent.width
                link: section.ctl.link
                path: modelData.path
                text: modelData.text
            }
        }
    }

    Item {
        width: parent.width
        height: resetButton.height

        DButton {
            id: resetButton
            anchors.right: parent.right
            text: "Reset to defaults"
            iconName: "restart_alt"
            // one set of the camera's own defaults; nothing to reset: disabled
            enabled: section.resetPatch !== null
            onClicked: section.ctl.link.setPatch(section.resetPatch)
        }
    }
}
