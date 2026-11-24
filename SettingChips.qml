import QtQuick

// An enum leaf of the device's description as single-select chips: the chips are the values
// the description lists (`values`), with the widget's own names where it has them; values that
// are not in `writable` are shown but cannot be picked. A value the description does not list
// (raw:<n>, a newer value) selects no chip and shows as text after the label (4.1 rule 7). One
// set request with the one leaf when a chip is picked (spec 2).
ChipRow {
    id: row

    property var link
    property string path: ""
    property string text: ""
    // value -> the widget's own name; other values show as text made from the value
    property var labels: ({})

    readonly property var block: link.blocked(path)
    readonly property var all: link.choices(path, labels)
    readonly property var current: link.value(path)
    readonly property int currentChoice: all.findIndex(c => c.value === current)

    visible: link.has(path)
    enabled: block === null
    opacity: enabled ? 1 : 0.38
    label: text + (currentChoice < 0 && current !== null ? " (" + String(current) + ")" : "") + (link.status(path) === "pending" ? " · pending" : "") + (link.setting(path)?.no_effect ? " · no visible effect" : "") + (block !== null && block.reason === "requires" ? " · needs " + block.needs.map(n => n.path + " = " + n.equals).join(", ") : "")
    options: all.map(c => c.label)
    currentIndex: currentChoice
    onSelected: index => {
        const c = row.all[index];
        if (c && c.selectable && c.value !== row.current)
            row.link.set(row.path, c.value);
        else
            row.sync();
    }
    onCurrentChoiceChanged: sync()
}
