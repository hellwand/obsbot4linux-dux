import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "lib/format.mjs" as Format

// Microphone processing. Switching the microphone on or off is left to the CLI: either change restarts the camera.
SectionCard {
    id: section

    property var ctl

    // Near / Standard / Far set the volume to 10 / 50 / 100 (spec 4.3, 9.1: UIs may offer those
    // three as volume presets; the widget's product choice, decision 16); only those inside the
    // description's bounds of audio.volume are offered
    readonly property var pickups: [
        {
            label: "Near",
            value: 10
        },
        {
            label: "Standard",
            value: 50
        },
        {
            label: "Far",
            value: 100
        }
    ]
    readonly property var volumeSpec: ctl.link.spec("audio.volume")
    readonly property var pickupChips: volumeSpec === null ? [] : pickups.filter(p => (volumeSpec.min === null || p.value >= volumeSpec.min) && (volumeSpec.max === null || p.value <= volumeSpec.max))
    readonly property var volume: ctl.link.value("audio.volume")
    // The preset whose band holds the shown volume: below 50, 50 to 84, from 85
    readonly property int pickupIndex: typeof volume !== "number" ? -1 : pickupChips.findIndex(p => p.value === (volume < 50 ? 10 : volume < 85 ? 50 : 100))

    // The value of a path as text, "" while the camera does not report it
    function shown(path) {
        const link = ctl.link;
        return link.has(path) && link.value(path) !== null ? Format.value(link.setting(path), link.value(path), ctl.labels(path)) : "";
    }

    title: "Audio"
    collapsible: true
    expanded: false
    visible: ctl.cardEnabled("Audio") && ["audio.noise_reduction", "audio.volume", "audio.auto_gain", "audio.in_sleep"].some(p => ctl.link.has(p))
    summary: [shown("audio.noise_reduction") !== "" ? "Noise reduction " + shown("audio.noise_reduction").toLowerCase() : "", pickupIndex >= 0 ? "pickup " + pickupChips[pickupIndex].label.toLowerCase() : "", shown("audio.volume") !== "" ? "volume " + shown("audio.volume") : "", shown("audio.auto_gain") !== "" ? "auto gain " + shown("audio.auto_gain").toLowerCase() : "", shown("audio.in_sleep") !== "" ? "mic asleep " + shown("audio.in_sleep").toLowerCase() : ""].filter(s => s !== "").join(" · ")
    // the camera takes these while asleep too and keeps them when it wakes
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38

    SettingChips {
        width: parent.width
        stacked: true
        link: section.ctl.link
        path: "audio.noise_reduction"
        text: "Noise reduction"
        labels: section.ctl.labels("audio.noise_reduction")
    }

    // One set of audio.volume; the chip shown is the band of the volume the camera reports
    ChipRow {
        id: pickupRow
        width: parent.width
        visible: section.ctl.link.has("audio.volume") && section.pickupChips.length > 0
        readonly property var block: section.ctl.link.blocked("audio.volume")
        enabled: block === null
        opacity: enabled ? 1 : 0.38
        label: "Pickup distance" + (section.ctl.link.status("audio.volume") === "pending" ? " · pending" : "") + (section.ctl.link.setting("audio.volume")?.no_effect ? " · no visible effect" : "") + (block !== null && block.reason === "requires" ? " · needs " + block.needs.map(n => n.path + " = " + n.equals).join(", ") : "")
        options: section.pickupChips.map(p => p.label)
        currentIndex: section.pickupIndex
        onSelected: index => {
            const p = section.pickupChips[index];
            if (p && index !== section.pickupIndex)
                section.ctl.link.set("audio.volume", p.value);
            else
                pickupRow.sync();
        }
    }

    SettingSlider {
        width: parent.width
        link: section.ctl.link
        path: "audio.volume"
        text: "Microphone volume"
    }

    SettingToggle {
        width: parent.width
        link: section.ctl.link
        path: "audio.auto_gain"
        text: "Automatic gain"
    }

    SettingToggle {
        width: parent.width
        link: section.ctl.link
        path: "audio.in_sleep"
        text: "Microphone while asleep"
    }
}
