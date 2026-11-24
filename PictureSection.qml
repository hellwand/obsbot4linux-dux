import QtQuick
import qs.Common
import qs.DCommon.Widgets

// HDR, exposure and its metering, exposure time and gain, every control on a path of the
// selected camera's description
SectionCard {
    id: section

    property var ctl

    title: "Picture"
    // the camera takes these while asleep too and keeps them when it wakes
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38

    SettingToggle {
        width: parent.width
        link: section.ctl.link
        path: "exposure.hdr"
        text: "HDR"
    }

    SettingChips {
        width: parent.width
        link: section.ctl.link
        path: "exposure.mode"
        text: "Exposure"
        labels: section.ctl.labels("exposure.mode")
    }

    SettingChips {
        width: parent.width
        link: section.ctl.link
        path: "exposure.region"
        text: "Metering"
        labels: section.ctl.labels("exposure.region")
    }

    // Blocked, with the reason, until exposure.mode is manual (the description's `requires`)
    SettingSlider {
        width: parent.width
        link: section.ctl.link
        path: "exposure.time"
        text: "Exposure time"
    }

    // The description gives the gain no `requires`: the widget adds no gate of its own
    SettingSlider {
        width: parent.width
        link: section.ctl.link
        path: "exposure.gain"
        text: "Gain"
    }
}
