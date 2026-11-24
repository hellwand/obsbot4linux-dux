import QtQuick

// A bool leaf of the device's description as a switch (10.3 D: every control gated on its
// path). Hidden when the device lacks the leaf; off while blocked (lib/describe.mjs blocked:
// unavailable, read-only, asleep and ignored, a requires not met), with the reason as its
// description; one set request with the one leaf when toggled (spec 2).
ToggleRow {
    id: row

    property var link
    property string path: ""
    property string text: ""
    // Shown under the label while the control can be used
    property string hint: ""

    readonly property var block: link.blocked(path)
    readonly property string shownStatus: link.status(path)

    visible: link.has(path)
    enabled: block === null
    opacity: enabled ? 1 : 0.38
    readonly property var setting: link.setting(path)
    readonly property var current: link.value(path)

    label: text + (shownStatus === "pending" ? " · pending" : "")
    // The reason it is blocked; else whether the value is known and has an effect (4.2: a
    // readback:false leaf is null until it is written; no_effect)
    description: block !== null && block.reason === "requires" ? "Needs " + block.needs.map(n => n.path + " = " + n.equals).join(", ") : current === null ? "Not known until it is set here" : setting !== null && setting.no_effect ? "No visible effect on this camera" : hint
    checked: current === true
    onToggled: on => row.link.set(row.path, on)
}
