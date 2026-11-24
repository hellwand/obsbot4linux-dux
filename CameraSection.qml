import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "lib/format.mjs" as Format

// Field of view, status LED, mirror and invert, every control on a path of the selected
// camera's description (obsbot4linux)
SectionCard {
    id: section

    property var ctl

    // The value of a path as text, "" while the camera does not report it
    function shown(path) {
        const link = ctl.link;
        return link.has(path) && link.value(path) !== null ? Format.value(link.setting(path), link.value(path), ctl.labels(path)) : "";
    }

    // Read-only info lines from the device's entry; a missing firmware shows as "–"
    readonly property var infoLines: {
        const device = ctl.link.device;
        if (device === null)
            return [];
        return [["Camera", device.name ?? ""], ["Firmware", device.firmware ?? "–"], ["Video device", ctl.videoNode]].filter(l => l[1] !== "");
    }

    title: "Camera"
    collapsible: true
    expanded: false
    visible: ctl.cardEnabled("Camera") && ["zoom.field_of_view", "led.brightness", "led.blink", "image.mirror", "gimbal.invert"].some(p => ctl.link.has(p))
    summary: [shown("zoom.field_of_view"), shown("led.brightness") !== "" ? "LED " + shown("led.brightness") : "", shown("image.mirror") !== "" ? "mirror " + shown("image.mirror").toLowerCase() : "", shown("gimbal.invert") !== "" ? "invert " + shown("gimbal.invert").toLowerCase() : ""].filter(s => s !== "").join(" · ")
    // the camera takes these while asleep too and keeps them when it wakes
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38

    // "custom" shows after the zoom was set freely; it cannot be picked
    SettingChips {
        width: parent.width
        link: section.ctl.link
        path: "zoom.field_of_view"
        text: "Field of view"
        labels: section.ctl.labels("zoom.field_of_view")
    }

    SettingSlider {
        width: parent.width
        link: section.ctl.link
        path: "led.brightness"
        text: "Status LED"
    }

    SettingToggle {
        width: parent.width
        link: section.ctl.link
        path: "led.blink"
        text: "Blink status LED"
    }

    SettingToggle {
        width: parent.width
        link: section.ctl.link
        path: "image.mirror"
        text: "Mirror image"
    }

    SettingToggle {
        width: parent.width
        link: section.ctl.link
        path: "gimbal.invert"
        text: "Invert gimbal"
        hint: "Reverses left/right panning"
    }

    StyledText {
        width: parent.width
        visible: section.infoLines.length > 0
        wrapMode: Text.WordWrap
        text: section.infoLines.map(l => l[0] + ": " + l[1]).join(" · ")
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }
}
