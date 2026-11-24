import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "lib/format.mjs" as Format

// Auto-sleep and what the camera shows while asleep
SectionCard {
    id: section

    property var ctl

    // The widget's shortcut times for auto-sleep (product choice, decision 16); only those
    // inside the description's bounds of sleep.auto.seconds are offered
    readonly property var shortcuts: [
        {
            label: "30 s",
            value: 30
        },
        {
            label: "2 min",
            value: 120
        },
        {
            label: "10 min",
            value: 600
        }
    ]
    readonly property var secondsSpec: ctl.link.spec("sleep.auto.seconds")
    readonly property var timeChips: secondsSpec === null ? [] : shortcuts.filter(t => (secondsSpec.min === null || t.value >= secondsSpec.min) && (secondsSpec.max === null || t.value <= secondsSpec.max))
    readonly property var seconds: ctl.link.value("sleep.auto.seconds")
    readonly property int timeIndex: timeChips.findIndex(t => t.value === seconds)

    // The value of a path as text, "" while the camera does not report it
    function shown(path) {
        const link = ctl.link;
        return link.has(path) && link.value(path) !== null ? Format.value(link.setting(path), link.value(path), ctl.labels(path)) : "";
    }

    function autoSleepText() {
        const enabled = ctl.link.value("sleep.auto.enabled");
        if (!ctl.link.has("sleep.auto.enabled") || enabled === null)
            return "";
        return "Auto-sleep " + (enabled ? shown("sleep.auto.seconds") : "off");
    }

    title: "Sleep"
    collapsible: true
    expanded: false
    visible: ctl.cardEnabled("Sleep") && ["sleep.auto.enabled", "sleep.auto.seconds", "sleep.background", "power_on.mode"].some(p => ctl.link.has(p))
    summary: [autoSleepText().trim(), shown("sleep.background") !== "" ? "background " + shown("sleep.background").toLowerCase() : ""].filter(s => s !== "").join(" · ")
    // Unlike the other settings these matter (and work) while the camera is asleep
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38

    SettingToggle {
        width: parent.width
        link: section.ctl.link
        path: "sleep.auto.enabled"
        text: "Auto-sleep"
    }

    // One set of the seconds only; it does not switch auto-sleep on (spec 4.3). When no chip
    // matches the camera's value, the label shows it.
    ChipRow {
        id: timeRow
        width: parent.width
        visible: section.ctl.link.has("sleep.auto.seconds")
        readonly property var block: section.ctl.link.blocked("sleep.auto.seconds")
        enabled: block === null
        opacity: enabled ? 1 : 0.38
        stacked: true
        label: (section.timeIndex >= 0 ? "After" : "After (" + Format.value(section.ctl.link.setting("sleep.auto.seconds"), section.seconds) + ")") + (section.ctl.link.status("sleep.auto.seconds") === "pending" ? " · pending" : "")
        options: section.timeChips.map(t => t.label)
        currentIndex: section.timeIndex
        onSelected: index => {
            const t = section.timeChips[index];
            if (t && index !== section.timeIndex)
                section.ctl.link.set("sleep.auto.seconds", t.value);
            else
                timeRow.sync();
        }
        onCurrentIndexChanged: sync()
    }

    // own_image shows when the camera reports it; it cannot be picked
    SettingChips {
        width: parent.width
        link: section.ctl.link
        path: "sleep.background"
        text: "While asleep"
        labels: section.ctl.labels("sleep.background")
    }

    // Stored in the camera and used when it powers on (plugged in), also without the widget running.
    // Waking from sleep, by command or by an app's stream, does not apply it (measured, #75).
    // "Zoom at power-on" (wake_zoom) is not offered: the camera applies it neither at power-on nor
    // on wake (obsbot4linux#102); the value stays readable in the Camera card.
    StyledText {
        width: parent.width
        visible: section.ctl.link.has("power_on.mode")
        wrapMode: Text.WordWrap
        text: "Power-on setting: waking from sleep does not apply it."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    SettingChips {
        width: parent.width
        stacked: true
        link: section.ctl.link
        path: "power_on.mode"
        text: "Tracking mode at power-on"
        labels: section.ctl.labels("power_on.mode")
    }
}
