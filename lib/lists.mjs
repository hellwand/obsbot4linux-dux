// SPDX-License-Identifier: GPL-3.0-or-later
//
// Presets and views (protocol 2, 4.2 "Lists", 4.4): rows for the cards, and the parameters of
// the actions on them. A preset saved without a name gets none (spec 12.3): the placeholder
// below is display only and never sent.

import { action, at, limit, numberSpec } from "./describe.mjs";

export const UNNAMED = "(unnamed)";

// The preset slots of a device: from its preset count (limits.presets) and the first slot the
// description allows (the slot parameter of preset.save); [] without presets.
export function presetSlots(device) {
  const save = action(device, "preset.save") ?? action(device, "preset.recall");
  const count = limit(device, "presets");
  const slot = save?.params?.slot ? numberSpec(save.params.slot) : null;
  if (count === null && (slot === null || slot.max === null)) return [];
  const first = slot?.min ?? 0;
  const n = count ?? slot.max - first + 1;
  return Array.from({ length: n }, (_, i) => first + i);
}

// One row per slot: { slot, used, name, label, pose }. null when the list is not read yet
// (it is in `unread`, or the state has no list).
export function presetRows(device, state) {
  const list = at(state, "presets");
  if (
    !Array.isArray(list) ||
    (Array.isArray(state?.unread) && state.unread.includes("presets"))
  )
    return null;
  return presetSlots(device).map((slot) => {
    const p = list.find((item) => item.slot === slot);
    if (!p) return { slot, used: false, name: "", label: "Empty", pose: null };
    const name = typeof p.name === "string" ? p.name : "";
    return {
      slot,
      used: true,
      name,
      label: name !== "" ? name : UNNAMED,
      pose: p.pose ?? null,
    };
  });
}

// The views of the state, or null while not read.
export function viewRows(state) {
  const list = at(state, "views");
  if (
    !Array.isArray(list) ||
    (Array.isArray(state?.unread) && state.unread.includes("views"))
  )
    return null;
  return list.map((v) => ({
    id: v.id,
    name: String(v.name ?? ""),
    label: v.name ? String(v.name) : UNNAMED,
    pose: v.pose ?? null,
  }));
}

// preset.save's parameters: the name only when the user typed one (spec 12.3).
export function saveParams(slot, typed) {
  return typed !== "" ? { slot, name: typed } : { slot };
}

// Why a typed name cannot be sent as parameter `param` of `actionName`, or null: the bounds of
// the description's string (max_len in characters, ascii = printable ASCII only).
export function nameProblem(device, actionName, param, text) {
  const p = action(device, actionName)?.params?.[param];
  if (!p) return "not offered by this camera";
  if (typeof p.max_len === "number" && Array.from(text).length > p.max_len)
    return `at most ${p.max_len} characters`;
  if (p.ascii === true && !/^[\x20-\x7e]*$/.test(text))
    return "letters, digits and punctuation without accents only";
  if (!p.optional && text === "") return "a name is needed";
  return null;
}
