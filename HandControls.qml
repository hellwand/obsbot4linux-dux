import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Hand tracking settings stored in the camera: area, axes, return time and the gimbal switch.
// Each control is on its own path of the description. Shown by the Tracking card while Hand is
// the tracking mode.
Column {
    id: hand

    property var ctl

    width: parent.width
    spacing: Theme.spacingM

    // Sent once the slider is let go, not on every step: one end at a time, the other as shown
    SettingSlider {
        width: parent.width
        link: hand.ctl.link
        path: "hand.area.pan"
        component: "min"
        text: "Hand area: pan from"
    }

    SettingSlider {
        width: parent.width
        link: hand.ctl.link
        path: "hand.area.pan"
        component: "max"
        text: "Hand area: pan to"
    }

    SettingSlider {
        width: parent.width
        link: hand.ctl.link
        path: "hand.area.tilt"
        component: "min"
        text: "Hand area: tilt from"
    }

    SettingSlider {
        width: parent.width
        link: hand.ctl.link
        path: "hand.area.tilt"
        component: "max"
        text: "Hand area: tilt to"
    }

    DButton {
        visible: hand.ctl.link.has("hand.area_reset")
        text: "Default area"
        iconName: "fit_screen"
        enabled: hand.ctl.link.blocked("hand.area_reset") === null
        onClicked: hand.ctl.link.act("hand.area_reset", {})
    }

    SettingToggle {
        width: parent.width
        link: hand.ctl.link
        path: "hand.axes.pan"
        text: "Hand moves pan"
        hint: "Off: the pan axis stays where it is"
    }

    SettingToggle {
        width: parent.width
        link: hand.ctl.link
        path: "hand.axes.tilt"
        text: "Hand moves tilt"
        hint: "Off: the tilt axis stays where it is"
    }

    // Hidden while the description gives no maximum
    SettingSlider {
        width: parent.width
        link: hand.ctl.link
        path: "hand.return_after"
        text: "Return after"
    }

    SettingToggle {
        width: parent.width
        link: hand.ctl.link
        path: "hand.move_gimbal"
        text: "Hand moves the gimbal"
        hint: "Off stops the gimbal."
    }
}
