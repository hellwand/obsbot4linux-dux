// SPDX-License-Identifier: GPL-3.0-or-later
//
// The value each control shows (protocol 2, 4.1 rule 4): the client's own value from sending a
// request until its reply arrives, then the state, its pending values included. No timers.

import { at, sameValue, setting, writable } from "./describe.mjs";

// The own values of the set requests in flight: request id -> { path: value }.
export class OwnValues {
  constructor() {
    this.byRequest = new Map();
  }

  // A set request went out with these leaves (a flat patch: path -> value).
  add(id, patch) {
    this.byRequest.set(id, Object.assign({}, patch));
  }

  // Its reply arrived (ok or error): its own values go.
  settle(id) {
    return this.byRequest.delete(id);
  }

  // The connection was lost: every request died with it (4.1 "Reconnect").
  clear() {
    this.byRequest.clear();
  }

  // The newest own value of a path, or undefined.
  value(path) {
    let found;
    let newest = -Infinity;
    for (const [id, patch] of this.byRequest) {
      if (path in patch && id > newest) {
        newest = id;
        found = patch[path];
      }
    }
    return found;
  }

  get size() {
    return this.byRequest.size;
  }
}

// The value a control shows for a leaf.
export function shown(state, own, path) {
  const mine = own?.value(path);
  if (mine !== undefined) return mine;
  if (state?.pending && path in state.pending) return state.pending[path];
  const v = at(state, path);
  return v === undefined ? null : v;
}

// The target box to draw over the preview, or null: the box as shown and its status (`status`
// above). A box in `unread` is the last one read, not where the target is now (obsbot4linux lists
// it there while it does not read the target, for example in Static).
export function targetBox(box, boxStatus) {
  return boxStatus === "unread" || box === undefined ? null : box;
}

// What the value of a leaf stands for: "own" (sent, no reply yet), "pending" (the camera took
// it, its readback does not show it yet), "unread" (never read, or the last read failed), or
// "camera" (as the camera reports it).
export function status(state, own, path) {
  if (own?.value(path) !== undefined) return "own";
  if (state?.pending && path in state.pending) return "pending";
  if (Array.isArray(state?.unread) && state.unread.includes(path))
    return "unread";
  return "camera";
}

// The patch of one control that edits several leaves (an area with two ranges): only the leaves
// whose edited value differs from the value shown. null when nothing changed.
export function changed(state, own, edits) {
  const patch = {};
  for (const [path, value] of Object.entries(edits)) {
    if (!sameValue(shown(state, own, path), value)) patch[path] = value;
  }
  return Object.keys(patch).length > 0 ? patch : null;
}

// The defaults reset (10.3 D): one set patch of the `default` values of the given leaves.
// A leaf is left out when the device lacks it, it is not writable, it has no default, it has a
// `requires` (the daemon refuses a whole patch when one leaf fails, 4.1 rule 5), or it shows
// its default already. null when nothing is left.
export function defaults(device, state, own, paths) {
  const patch = {};
  for (const path of paths) {
    const s = setting(device, path);
    if (
      !s ||
      !writable(device, path) ||
      s.default === undefined ||
      (s.requires ?? []).length > 0
    )
      continue;
    if (!sameValue(shown(state, own, path), s.default)) patch[path] = s.default;
  }
  return Object.keys(patch).length > 0 ? patch : null;
}
