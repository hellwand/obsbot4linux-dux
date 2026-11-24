import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "lib/format.mjs" as Format

// Zone tracking: stay within an area, return to a chosen position. Every control is bound to a
// path or action of the camera's description; the area's bounds and step come from it.
SectionCard {
    id: section

    property var ctl

    title: "Zone"
    collapsible: true
    expanded: false
    visible: ctl.cardEnabled("Zone") && ctl.link.has("zone")
    summary: "Zone " + (ctl.link.value("zone.enabled") ? "on" : "off") + " · pan " + Format.value(ctl.link.setting("zone.area.pan"), ctl.link.value("zone.area.pan")) + " · tilt " + Format.value(ctl.link.setting("zone.area.tilt"), ctl.link.value("zone.area.tilt"))
    // the camera takes these while asleep too and keeps them when it wakes
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38

    SettingToggle {
        width: parent.width
        link: section.ctl.link
        path: "zone.enabled"
        text: "Zone tracking"
    }

    // Sent once the slider is let go, not on every step
    SettingSlider {
        width: parent.width
        link: section.ctl.link
        path: "zone.area.pan"
        component: "min"
        text: "Pan from"
    }

    SettingSlider {
        width: parent.width
        link: section.ctl.link
        path: "zone.area.pan"
        component: "max"
        text: "Pan to"
    }

    SettingSlider {
        width: parent.width
        link: section.ctl.link
        path: "zone.area.tilt"
        component: "min"
        text: "Tilt from"
    }

    SettingSlider {
        width: parent.width
        link: section.ctl.link
        path: "zone.area.tilt"
        component: "max"
        text: "Tilt to"
    }

    Flow {
        width: parent.width
        spacing: Theme.spacingS

        DButton {
            text: "Return here"
            iconName: "my_location"
            visible: section.ctl.link.has("zone.return_here")
            enabled: section.ctl.link.blocked("zone.return_here") === null
            onClicked: section.ctl.link.act("zone.return_here", {})
        }

        DButton {
            text: "Go to return position"
            iconName: "u_turn_left"
            visible: section.ctl.link.has("zone.go_return")
            enabled: section.ctl.link.blocked("zone.go_return") === null
            onClicked: section.ctl.link.act("zone.go_return", {})
        }
    }

    StyledText {
        width: parent.width
        visible: section.ctl.link.has("zone.return")
        text: "Return position: " + Format.value(section.ctl.link.setting("zone.return"), section.ctl.link.value("zone.return"))
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    StyledText {
        width: parent.width
        visible: section.ctl.link.has("zone.follow")
        wrapMode: Text.WordWrap
        text: section.ctl.link.value("zone.follow") === true
            ? "When the target leaves the area, the camera returns to its return position, keeps tracking and takes the next person who enters it."
            : "When the target leaves the area, tracking stops (Static) and the camera returns to its return position."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    ZoneViews {
        width: parent.width
        visible: section.ctl.link.has("views")
        ctl: section.ctl
    }
}
