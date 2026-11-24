import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "lib/format.mjs" as Format

// Gesture switches and how far the zoom gesture zooms in
SectionCard {
    id: section

    property var ctl

    // label shown and the description's path of each switch
    readonly property var gestures: [
        {
            label: "Target lock",
            path: "gestures.target_lock"
        },
        {
            label: "Zoom",
            path: "gestures.zoom"
        },
        {
            label: "Dynamic zoom",
            path: "gestures.dynamic_zoom"
        },
        {
            label: "Direction change",
            path: "gestures.direction_change"
        }
    ]
    readonly property var gesturesOn: gestures.filter(g => ctl.link.value(g.path) === true)
    readonly property bool anyKnown: gestures.some(g => ctl.link.has(g.path) && ctl.link.value(g.path) !== null)
    readonly property string ratioText: ctl.link.has("gestures.zoom_ratio") && ctl.link.value("gestures.zoom_ratio") !== null ? Format.value(ctl.link.setting("gestures.zoom_ratio"), ctl.link.value("gestures.zoom_ratio")) : ""

    title: "Gestures"
    collapsible: true
    expanded: false
    visible: ctl.cardEnabled("Gestures") && gestures.concat([
        {
            path: "gestures.zoom_ratio"
        }
    ]).some(g => ctl.link.has(g.path))
    summary: (!anyKnown ? "" : gesturesOn.length === 0 ? "All off" : gesturesOn.map(g => g.label).join(", ") + " on") + (ratioText !== "" ? (anyKnown ? " · " : "") + "zoom ratio " + ratioText : "")
    // the camera takes these while asleep too and keeps them when it wakes
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38

    SettingToggle {
        width: parent.width
        link: section.ctl.link
        path: "gestures.target_lock"
        text: "Target lock"
    }

    SettingToggle {
        width: parent.width
        link: section.ctl.link
        path: "gestures.zoom"
        text: "Zoom"
    }

    SettingToggle {
        width: parent.width
        link: section.ctl.link
        path: "gestures.dynamic_zoom"
        text: "Dynamic zoom"
    }

    SettingToggle {
        width: parent.width
        link: section.ctl.link
        path: "gestures.direction_change"
        text: "Direction change"
        hint: "Reverses which hand movement zooms in or out with Dynamic zoom."
    }

    // The bounds and the step come from the description; sent once when the slider rests
    SettingSlider {
        width: parent.width
        link: section.ctl.link
        path: "gestures.zoom_ratio"
        text: "Zoom gesture ratio"
    }
}
