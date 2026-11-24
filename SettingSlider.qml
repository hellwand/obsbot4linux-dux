import QtQuick
import "lib/describe.mjs" as Describe
import "lib/format.mjs" as Format

// A number leaf of the device's description, or one component of a range leaf, as a slider:
// bounds, step and unit come from the description (10.3 D), never from constants of the
// widget. The value is sent once, when the drag, key press or wheel step is over: one set
// request with the leaf (for a range component: the whole range with the other component as
// shown). Hidden when the device lacks the leaf or the slider has no bounds and step.
LabeledSlider {
    id: item

    property var link
    property string path: ""
    property string text: ""
    // "" for a number leaf; "min" or "max" for one end of a range leaf
    property string component: ""

    readonly property var setting: link.setting(path)
    readonly property var bounds: setting === null ? null : component === "" ? Describe.numberSpec(setting) : Describe.numberSpec(setting, component)
    readonly property var steps: Describe.sliderScale(bounds)
    readonly property var shownValue: link.value(path)
    readonly property var block: link.blocked(path)

    function current() {
        if (shownValue === null || shownValue === undefined)
            return null;
        return component === "" ? shownValue : shownValue[component];
    }

    visible: link.has(path) && steps !== null
    enabled: block === null
    opacity: enabled ? 1 : 0.38
    label: text + (link.status(path) === "pending" ? " · pending" : "") + (link.setting(path)?.no_effect ? " · no visible effect" : "") + (block !== null && block.reason === "requires" ? " · needs " + block.needs.map(n => n.path + " = " + n.equals).join(", ") : "")
    minimum: 0
    maximum: steps !== null ? steps.count : 0
    value: steps !== null && current() !== null ? steps.toIndex(current()) : 0
    formatValue: i => item.steps === null ? "" : item.current() === null && !item.dragging ? "–" : Format.number(item.steps.toValue(i), item.bounds.precision, item.bounds.unit)
    onReleased: i => {
        if (item.steps === null)
            return;
        const v = item.steps.toValue(i);
        if (item.component === "") {
            item.link.set(item.path, v);
            return;
        }
        const range = Object.assign({}, item.shownValue ?? {});
        range[item.component] = v;
        if (range.min !== undefined && range.max !== undefined && range.min <= range.max)
            item.link.set(item.path, range);
        else
            item.sync();
    }
}
