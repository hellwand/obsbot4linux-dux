// SPDX-License-Identifier: GPL-3.0-or-later
//
// What a device's description (protocol 2, 4.2) allows: every control of the widget asks here
// whether it is shown, which values it offers, its bounds, step and unit, and whether it is
// blocked right now. Nothing here knows a model.

export const TYPES = [
  "bool",
  "enum",
  "number",
  "range",
  "pose",
  "point",
  "box",
  "string",
  "list",
];

export function setting(device, path) {
  return device?.settings?.[path] ?? null;
}

export function action(device, name) {
  return device?.actions?.[name] ?? null;
}

// A leaf, an action, or a group (a prefix of a leaf or action path) of the description.
export function has(device, path) {
  if (setting(device, path) || action(device, path)) return true;
  const prefix = path + ".";
  const names = Object.keys(device?.settings ?? {}).concat(
    Object.keys(device?.actions ?? {}),
  );
  return names.some((n) => n.startsWith(prefix));
}

// A leaf of a type this widget knows and the daemon accepts writes for. A setting of an unknown
// type is shown read-only as text (rule 7).
export function writable(device, path) {
  const s = setting(device, path);
  return s !== null && !s.readonly && TYPES.includes(s.type);
}

// The values an enum shows, each { value, label, selectable }: every value of `values`, in its
// order; selectable when `writable` holds it (all are, when `writable` is missing). labels: the
// widget's own names for values it knows; another value shows as text made from it.
export function choices(device, path, labels) {
  const s = setting(device, path);
  if (!s || s.type !== "enum") return [];
  const writable = Array.isArray(s.writable) ? s.writable : s.values;
  return (s.values ?? []).map((value) => ({
    value,
    label: labels?.[value] ?? humanize(value),
    selectable: !s.readonly && writable.includes(value),
  }));
}

// "upper_body" -> "Upper body"; "raw:7" stays "raw:7"
export function humanize(value) {
  const text = String(value);
  if (/^raw:-?\d+$/.test(text)) return text;
  const words = text.replace(/_/g, " ");
  return words.charAt(0).toUpperCase() + words.slice(1);
}

function bound(b, key) {
  if (b === undefined || b === null) return null;
  return typeof b === "number" ? b : (b[key] ?? null);
}

// Bounds of a number, or of one component of a range, pose, point or box (component: "min",
// "max", "pan", …): { min, max, step, precision, unit }; missing parts are null. step: the
// description's step, else its precision.
export function numberSpec(s, component) {
  if (!s) return null;
  const unit =
    typeof s.unit === "object" && s.unit !== null
      ? (s.unit[component] ?? null)
      : (s.unit ?? null);
  const precision = bound(s.precision, component);
  const step = bound(s.step, component) ?? precision;
  if (component === undefined || s.type === "number")
    return { min: s.min ?? null, max: s.max ?? null, step, precision, unit };
  return {
    min: bound(s.min, component),
    max: bound(s.max, component),
    step,
    precision,
    unit,
  };
}

// Decimal places of a precision (0.01 -> 2, 1 -> 0).
export function decimals(precision) {
  if (!precision || precision >= 1) return 0;
  return Math.min(6, Math.max(0, Math.round(-Math.log10(precision))));
}

export function roundTo(value, precision) {
  if (!precision) return value;
  const places = decimals(precision);
  const n = Math.round(value / precision) * precision;
  return Number(n.toFixed(places));
}

// A slider over [min, max] in steps: positions 0..count. null without both bounds or a step.
export function sliderScale(spec) {
  if (!spec || spec.min === null || spec.max === null || !spec.step)
    return null;
  const count = Math.max(0, Math.round((spec.max - spec.min) / spec.step));
  const precision = spec.precision ?? spec.step;
  return {
    count,
    toValue: (i) =>
      roundTo(
        Math.min(
          spec.max,
          spec.min + Math.max(0, Math.min(count, i)) * spec.step,
        ),
        precision,
      ),
    toIndex: (v) =>
      Math.max(0, Math.min(count, Math.round((v - spec.min) / spec.step))),
  };
}

// The value at a dotted path of a state (its nested tree, 4.3); undefined when absent.
export function at(state, path) {
  let node = state;
  for (const key of String(path).split(".")) {
    if (node === null || typeof node !== "object" || !(key in node))
      return undefined;
    node = node[key];
  }
  return node;
}

// Why a control for a leaf or action cannot be used now, or null when it can. state: the
// device's published state with its pending values laid over it (what the daemon checks a
// request against, 4.1 rule 5); the widget's own values do not count.
//   { reason: "unavailable" }                   the device is unplugged or unsupported
//   { reason: "readonly" }                      the leaf is read-only or of an unknown type
//   { reason: "asleep" }                        asleep, and the description says it is ignored
//   { reason: "requires", needs: [{path, equals}] } a requires condition does not hold
export function blocked(device, state, path) {
  const s = setting(device, path);
  const a = s ? null : action(device, path);
  if (
    !device ||
    device.available !== true ||
    device.support === "unsupported" ||
    (!s && !a)
  )
    return { reason: "unavailable" };
  if (s && !writable(device, path)) return { reason: "readonly" };
  const spec = s ?? a;
  const current = (p) =>
    state?.pending && p in state.pending ? state.pending[p] : at(state, p);
  if (current("asleep") === true && spec.asleep === "ignored")
    return { reason: "asleep" };
  const needs = (spec.requires ?? []).filter(
    (r) => !sameValue(current(r.path), r.equals),
  );
  if (needs.length > 0) return { reason: "requires", needs };
  return null;
}

// The warnings a control asks the user to confirm before it sends (4.2 `warning`: "restart",
// "destructive"); [] when there is nothing to ask.
export function warnings(device, path) {
  const spec = setting(device, path) ?? action(device, path);
  return Array.isArray(spec?.warning) ? spec.warning.slice() : [];
}

// The maximum item count of a list (4.2 `limits`), or null when the camera has none.
export function limit(device, path) {
  const n = device?.limits?.[path];
  return typeof n === "number" ? n : null;
}

// The live topics a device's description names (4.2 `live`).
export function topics(device) {
  const all = new Set();
  for (const s of Object.values(device?.settings ?? {})) {
    if (typeof s.live === "string") all.add(s.live);
  }
  return Array.from(all).sort();
}

// Equality of two protocol values: numbers by value, objects and arrays by their parts.
export function sameValue(a, b) {
  if (a === b) return true;
  if (typeof a === "number" && typeof b === "number")
    return Math.abs(a - b) < 1e-9;
  if (
    a === null ||
    b === null ||
    typeof a !== "object" ||
    typeof b !== "object"
  )
    return false;
  const ka = Object.keys(a);
  const kb = Object.keys(b);
  return ka.length === kb.length && ka.every((k) => sameValue(a[k], b[k]));
}

// The live topics the widget asks for (4.1 rule 8): none while the popout is closed; while it
// is open, those of the shown parts that the device's description names. view: { open, pose,
// target, auto }, each a bool: the popout is open, and it shows the live pose, the target box,
// the values the camera adjusts itself.
export function wantedTopics(device, view) {
  if (!view.open) return [];
  const named = topics(device);
  return ["auto", "pose", "target"].filter(
    (t) => view[t] === true && named.includes(t),
  );
}
