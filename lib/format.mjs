// SPDX-License-Identifier: GPL-3.0-or-later
//
// Values as text, with the units of the description (protocol 2, 4.2 "Units and frames").

import { decimals, humanize } from "./describe.mjs";

const UNITS = {
  deg: "°",
  "deg/s": "°/s",
  factor: "×",
  us: " µs",
  K: " K",
  percent: " %",
  s: " s",
  fps: " fps",
  fraction: "",
};

// A unit the widget does not know is shown by its name (units are additive, 4.1 rule 7).
export function unitText(unit) {
  if (unit === null || unit === undefined) return "";
  return unit in UNITS ? UNITS[unit] : ` ${unit}`;
}

// 12.5 with precision 0.1 and unit deg -> "12.5°"; negative numbers with a real minus sign.
export function number(value, precision, unit) {
  const text = Number(value).toFixed(decimals(precision));
  return text.replace("-", "−") + unitText(unit);
}

function part(s, key) {
  const pick = (b) => (b !== null && typeof b === "object" ? b[key] : b);
  return { precision: pick(s.precision), unit: pick(s.unit) };
}

// One value as the description's type shows it. labels: the widget's own names of enum values.
export function value(s, v, labels) {
  if (v === null || v === undefined) return "–";
  if (typeof v === "string" && /^raw:-?\d+$/.test(v)) return v;
  switch (s?.type) {
    case "bool":
      return v ? "On" : "Off";
    case "enum":
      return labels?.[v] ?? humanize(v);
    case "number":
      return number(v, s.precision, s.unit);
    case "range": {
      const p = part(s, "min");
      return `${number(v.min, p.precision, null)}…${number(v.max, p.precision, p.unit)}`;
    }
    case "pose":
      return ["pan", "tilt", "zoom"]
        .map(
          (k) => `${k} ${number(v[k], part(s, k).precision, part(s, k).unit)}`,
        )
        .join(" · ");
    case "point":
    case "box":
      return Object.keys(v)
        .map(
          (k) => `${k} ${number(v[k], part(s, k).precision, part(s, k).unit)}`,
        )
        .join(" · ");
    case "string":
      return String(v);
    case "list":
      return Array.isArray(v) ? `${v.length}` : "–";
    default:
      // a setting of a type this widget does not know: read-only text (rule 7)
      return typeof v === "object" ? JSON.stringify(v) : String(v);
  }
}
