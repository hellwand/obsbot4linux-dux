// SPDX-License-Identifier: GPL-3.0-or-later
//
// The widget's whole link to the daemon, without I/O: the connection (Session), the devices and
// their states (DeviceStore), the own values in flight (OwnValues) and the device shown. One
// QML component (CameraLink.qml) and the e2e test drive it the same way: they hand it what the
// socket did and carry out the effects it returns (session.mjs lists the I/O effects). Two more
// effects come from here:
//   { changed: true }               devices, states, own values or the selection changed
//   { failed: { id, code, message } }  a request of ours was refused (the UI shows a toast)
// Each control sends exactly one request (spec 2, 12.3): set(), setPatch() and act() each write
// one line and nothing else.

import { act as actRequest, setLeaves } from "./protocol.mjs";
import { Session } from "./session.mjs";
import { DeviceStore, selection } from "./devices.mjs";
import { OwnValues, shown, status } from "./values.mjs";

export class Link {
  constructor(client) {
    this.session = new Session(client);
    this.store = new DeviceStore();
    this.own = new OwnValues();
    this.selected = null;
  }

  get ready() {
    return this.session.phase === "ready";
  }

  get problem() {
    return this.session.problem;
  }

  start() {
    return this.handle(this.session.start());
  }

  connected() {
    return this.handle(this.session.connected());
  }

  line(text) {
    return this.handle(this.session.line(text));
  }

  closed(error) {
    return this.handle(this.session.closed(error));
  }

  helloTimeout() {
    return this.handle(this.session.helloTimeout());
  }

  retry() {
    return this.handle(this.session.retry());
  }

  stop() {
    return this.handle(this.session.stop());
  }

  setLive(topics) {
    return this.session.setLive(topics);
  }

  // The user picks a device in the device picker.
  pick(id) {
    if (!this.store.device(id)) return [];
    this.selected = id;
    return [{ changed: true }];
  }

  device() {
    return this.selected ? this.store.device(this.selected) : null;
  }

  state() {
    return this.selected ? this.store.state(this.selected) : null;
  }

  shown(path) {
    return shown(this.state(), this.own, path);
  }

  status(path) {
    return status(this.state(), this.own, path);
  }

  // One set request with one leaf.
  set(path, value) {
    return this.setPatch({ [path]: value });
  }

  // One set request with the leaves of one control; the own values show until its reply.
  setPatch(patch) {
    const device = this.selected;
    if (!device || !patch || Object.keys(patch).length === 0) return [];
    const sent = this.session.request((id) => setLeaves(id, device, patch));
    if (sent.id === null) return [];
    this.own.add(sent.id, patch);
    return sent.effects.concat([{ changed: true }]);
  }

  // One do request.
  act(name, params) {
    const device = this.selected;
    if (!device) return [];
    return this.session.request((id) =>
      actRequest(id, device, name, params ?? {}),
    ).effects;
  }

  handle(effects) {
    const out = [];
    for (const e of effects) {
      if (e.ready) {
        this.store.fromHello(e.ready);
        this.own.clear();
        this.reselect();
        out.push({ changed: true });
      } else if (e.lost) {
        // the pick stays: device() is null while the store is empty, and the next hello
        // shows the same id again while it is listed (reselect)
        this.store.reset();
        this.own.clear();
        out.push(e, { changed: true });
      } else if (e.event) {
        if (this.onEvent(e.event)) out.push({ changed: true });
      } else if (e.reply) {
        const r = e.reply;
        const had = this.own.settle(r.id);
        if (r.kind === "error")
          out.push({ failed: { id: r.id, code: r.code, message: r.message } });
        if (had || r.kind === "error") out.push({ changed: true });
      } else {
        out.push(e);
      }
    }
    return out;
  }

  onEvent(parsed) {
    const body = parsed.body;
    if (parsed.event === "devices" && Array.isArray(body.devices)) {
      this.store.onDevices(body.devices);
      this.reselect();
      return true;
    }
    if (parsed.event === "state") return this.store.onState(body);
    // an event type this widget does not know (4.1 rule 7)
    return false;
  }

  // After the list changed: the device shown while it is listed (its new id after a
  // hand-over), else the only usable device, or none (devices.selection).
  reselect() {
    this.selected = selection(this.store.devices, this.selected);
  }
}
