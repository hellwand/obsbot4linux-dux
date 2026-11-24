import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "lib/format.mjs" as Format

// Tracking mode, speed and the hand that hand tracking follows, every control on a path or
// action of the selected camera's description
SectionCard {
    id: section

    property var ctl
    // compact: for the Control Center tile; the tracked hand stays in the popout and the detail page
    property bool compact: false

    readonly property string returnText: {
        const link = ctl.link;
        if (!link.has("hand.return"))
            return "";
        const pose = link.value("hand.return");
        return "Return position: " + (pose ? Format.value(link.setting("hand.return"), pose, ctl.labels("hand.return")) : "none");
    }
    readonly property string areaText: {
        const link = ctl.link;
        if (!link.has("hand.area.pan") || !link.has("hand.area.tilt"))
            return "";
        return "Hand area: pan " + Format.value(link.setting("hand.area.pan"), link.value("hand.area.pan"), ctl.labels("hand.area.pan")) + ", tilt " + Format.value(link.setting("hand.area.tilt"), link.value("hand.area.tilt"), ctl.labels("hand.area.tilt"));
    }

    title: "Tracking"
    // the camera takes these while asleep too and keeps them when it wakes
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38

    SettingChips {
        width: parent.width
        stacked: true
        link: section.ctl.link
        path: "tracking.mode"
        text: ""
        labels: section.ctl.labels("tracking.mode")
    }

    SettingChips {
        width: parent.width
        link: section.ctl.link
        path: "tracking.profile"
        text: "Speed"
        labels: section.ctl.labels("tracking.profile")
    }

    // Gated by the description and blocked() only; the hint below says when the camera uses it
    SettingChips {
        width: parent.width
        visible: section.ctl.link.has("hand.side") && !section.compact
        link: section.ctl.link
        path: "hand.side"
        text: "Tracked hand"
        labels: section.ctl.labels("hand.side")
    }

    StyledText {
        width: parent.width
        visible: section.ctl.link.has("hand.side") && !section.compact
        text: "Used in Hand mode"
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    Flow {
        width: parent.width
        visible: !section.compact && (section.ctl.link.has("hand.return_here") || section.ctl.link.has("hand.go_return") || section.ctl.link.has("hand.return_clear"))
        spacing: Theme.spacingS

        DButton {
            visible: !section.compact && section.ctl.link.has("hand.return_here")
            text: "Return here"
            iconName: "my_location"
            enabled: section.ctl.link.blocked("hand.return_here") === null
            onClicked: section.ctl.link.act("hand.return_here", {})
        }

        DButton {
            visible: !section.compact && section.ctl.link.has("hand.go_return")
            text: "Go to return position"
            iconName: "u_turn_left"
            enabled: section.ctl.link.blocked("hand.go_return") === null
            onClicked: section.ctl.link.act("hand.go_return", {})
        }

        DButton {
            visible: !section.compact && section.ctl.link.has("hand.return_clear")
            text: "Clear"
            iconName: "close"
            enabled: section.ctl.link.blocked("hand.return_clear") === null
            onClicked: section.ctl.link.act("hand.return_clear", {})
        }
    }

    StyledText {
        width: parent.width
        visible: !section.compact && text !== ""
        wrapMode: Text.WordWrap
        text: section.returnText + (section.returnText !== "" && section.areaText !== "" ? "\n" : "") + section.areaText
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    // Only while hand tracking is selected; each control checks its own path
    HandControls {
        width: parent.width
        visible: !section.compact && section.ctl.link.value("tracking.mode") === "hand" && section.ctl.link.has("hand")
        ctl: section.ctl
    }

    // Measured with zone tracking on (Tiny 2 Lite): when the target left the area the camera kept
    // tracking and took a new one. Not in the compact tile.
    SettingToggle {
        width: parent.width
        visible: section.ctl.link.has("zone.follow") && !section.compact
        link: section.ctl.link
        path: "zone.follow"
        text: "Follow new targets"
    }

    // Experimental: the tracked target's box over the preview
    ToggleRow {
        width: parent.width
        visible: section.ctl.link.has("tracking.target.box") && !section.compact
        label: "Show target box in preview"
        checked: section.ctl.showTargetBox
        onToggled: checked => section.ctl.setShowTargetBox(checked)
    }
}
