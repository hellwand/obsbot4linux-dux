// SPDX-License-Identifier: GPL-3.0-or-later
//
// The device list and the last state of each device, as the hello reply and the devices and
// state events give them (protocol 2, 4.1 "Events" and rule 1), and which device the widget
// shows (8.4 step 7).

export const ISSUES = "https://github.com/hellwand/obsbot4linux/issues";

// A device the widget can control: a supported model (tested or untested) that is plugged in.
export function usable(device) {
  return (
    device.available === true &&
    (device.support === "tested" || device.support === "untested")
  );
}

// Whether any listed device is usable, selected or not ("Hide without camera" keeps the pill
// while the user still has to pick one).
export function anyUsable(devices) {
  return devices.some(usable);
}

// The marker next to a device's name: "" for a tested model, else its support level as the
// daemon names it ("untested", "unsupported", or a newer level as raw text).
export function marker(device) {
  return device.support === "tested" ? "" : String(device.support);
}

// What the widget shows for an unsupported device instead of controls (8.4 step 3).
export function unsupportedHint(device) {
  const usb = device.usb ?? {};
  return (
    `${device.name} (USB ${usb.vendor}:${usb.product}) is not supported by obsbot4linux. ` +
    `\`obsbot4linux devices --report\` prints what an issue report needs: ${ISSUES}`
  );
}

export class DeviceStore {
  constructor() {
    this.reset();
  }

  // Nothing is known (no connection, or before a hello reply).
  reset() {
    this.devices = [];
    this.states = {}; // id -> { rev, state }
  }

  // The hello reply rebuilds everything (4.1 "Reconnect").
  fromHello(ok) {
    this.devices = Array.from(ok.devices ?? []);
    this.states = {};
    for (const d of this.devices) {
      const s = ok.states?.[d.id];
      if (s) this.states[d.id] = { rev: s.rev, state: s.state };
    }
  }

  // A devices event: the full list. Returns the ids no longer listed. The rev and state of
  // such an id are forgotten: an entry added later under the same port: id starts at rev 1.
  onDevices(list) {
    const ids = new Set(list.map((d) => d.id));
    const removed = this.devices.map((d) => d.id).filter((id) => !ids.has(id));
    for (const id of removed) delete this.states[id];
    this.devices = Array.from(list);
    return removed;
  }

  // A state event { device, rev, state }. Applied when its device is listed and its rev is
  // newer than the one known; returns whether it was applied.
  onState(body) {
    if (!this.device(body.device)) return false;
    const known = this.states[body.device];
    if (known && !(body.rev > known.rev)) return false;
    this.states[body.device] = { rev: body.rev, state: body.state };
    return true;
  }

  device(id) {
    return this.devices.find((d) => d.id === id) ?? null;
  }

  state(id) {
    return this.states[id]?.state ?? null;
  }

  rev(id) {
    return this.states[id]?.rev ?? 0;
  }
}

// The device to show after a change of the list: the current one while it is listed (its new
// id after a hand-over, 5.5); else the only usable device, or none (8.4 step 7). An unplugged
// sn: device stays listed and stays selected.
export function selection(devices, current) {
  const now = current ? devices.find((d) => d.id === current) : null;
  if (now) {
    const next = now.replaced_by
      ? devices.find((d) => d.id === now.replaced_by)
      : null;
    return next ? next.id : now.id;
  }
  const candidates = devices.filter(usable);
  return candidates.length === 1 ? candidates[0].id : null;
}
