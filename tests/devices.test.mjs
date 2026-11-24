// SPDX-License-Identifier: GPL-3.0-or-later
import { eq, ok } from "./assert.mjs";
import {
  anyUsable,
  DeviceStore,
  marker,
  selection,
  unsupportedHint,
  usable,
} from "../lib/devices.mjs";
import { A, B, HELLO, UNKNOWN } from "./fixtures/fakes.mjs";
import hotplug from "./fixtures/hotplug.transcript.mjs";

const off = (d) => Object.assign({}, d, { available: false });

export const tests = {
  "markers: none for tested, the level for the others": () => {
    eq([A, B, UNKNOWN].map(marker), ["", "untested", "unsupported"]);
    eq(marker(Object.assign({}, A, { support: "beta" })), "beta");
  },
  // 6.2: unsupported devices never count as usable; unplugged ones neither
  "usable: a supported model that is plugged in": () => {
    eq([A, B, UNKNOWN].map(usable), [true, true, false]);
    eq(usable(off(A)), false);
  },
  // "Hide without camera": the pill stays while a usable camera is listed, picked or not
  // (two usable cameras: nothing is picked, 8.4 step 7, and the picker is in the popout)
  "anyUsable: some listed device is usable, selected or not": () => {
    eq(anyUsable([A, B, UNKNOWN]), true);
    eq(anyUsable([UNKNOWN]), false);
    eq(anyUsable([off(A)]), false);
    eq(anyUsable([]), false);
  },
  // 8.4 step 3: the unsupported device shows the report hint instead of controls
  "the unsupported hint names the device, its USB ids and the report command":
    () => {
      const text = unsupportedHint(UNKNOWN);
      ok(text.includes("Unknown Camera 9-3 (USB 3564:fa00)"), text);
      ok(text.includes("obsbot4linux devices --report"), text);
      ok(
        text.includes("https://github.com/hellwand/obsbot4linux/issues"),
        text,
      );
    },
  // 8.4 step 7 and 6.2: the only usable device, or none; unsupported never auto-selected
  "selection: only one usable device is chosen by itself": () => {
    eq(selection([A, UNKNOWN], null), A.id);
    eq(selection([A, B, UNKNOWN], null), null);
    eq(selection([UNKNOWN], null), null);
    eq(selection([A, B, UNKNOWN], B.id), B.id);
    eq(selection([A, UNKNOWN], UNKNOWN.id), UNKNOWN.id);
  },
  "selection: the selected unsupported device goes, the only usable one takes over":
    () => {
      eq(selection([A], UNKNOWN.id), A.id);
      eq(selection([A, B], UNKNOWN.id), null);
    },
  "selection: an unplugged sn: device stays selected": () => {
    eq(selection([off(A), B], A.id), A.id);
  },
  // 5.5: clients move their selection on a hand-over
  "selection follows replaced_by": () => {
    const port = Object.assign({}, A, {
      id: "port:9-1",
      available: false,
      replaced_by: A.id,
    });
    eq(selection([A, port], "port:9-1"), A.id);
  },
  "the hello reply fills devices and states": () => {
    const store = new DeviceStore();
    store.fromHello(HELLO);
    eq(
      store.devices.map((d) => d.id),
      [A.id, B.id, UNKNOWN.id],
    );
    eq(store.rev(B.id), 1);
    eq(store.state(UNKNOWN.id), { available: true, pending: {}, unread: [] });
  },
  // 4.1 rule 1: a rev never goes back; equal revs are not applied twice
  "a state event applies only with a newer rev": () => {
    const store = new DeviceStore();
    store.fromHello(HELLO);
    ok(
      store.onState({
        device: B.id,
        rev: 2,
        state: {
          available: true,
          pending: {},
          unread: [],
          zoom: { factor: 2 },
        },
      }),
      "rev 2",
    );
    ok(!store.onState({ device: B.id, rev: 2, state: {} }), "rev 2 again");
    ok(!store.onState({ device: B.id, rev: 1, state: {} }), "rev 1");
    eq(store.state(B.id).zoom.factor, 2);
    ok(
      !store.onState({ device: "sn:NOTLISTED001", rev: 9, state: {} }),
      "unlisted device",
    );
  },
  // 4.1 rule 1: a port: entry added again starts at rev 1; clients forget dropped revs
  "a removed entry's rev is forgotten, so its return at rev 1 applies": () => {
    const store = new DeviceStore();
    store.fromHello(HELLO);
    store.onState({
      device: UNKNOWN.id,
      rev: 1,
      state: { available: true, pending: {}, unread: [] },
    });
    eq(store.onDevices([A, B]), [UNKNOWN.id]);
    eq(store.rev(UNKNOWN.id), 0);
    store.onDevices([A, B, UNKNOWN]);
    ok(
      store.onState({
        device: UNKNOWN.id,
        rev: 1,
        state: { available: true, pending: {}, unread: [] },
      }),
      "rev 1 again",
    );
  },
  // The golden hotplug transcript, replayed: the hand-over leaves the sn: entry selected,
  // its rev above both entries
  "the golden hotplug transcript ends on the sn: entry with its newest state":
    () => {
      const store = new DeviceStore();
      let selected = null;
      for (const m of hotplug.filter((x) => x.from === "daemon")) {
        if (m.msg.event === "devices") {
          store.onDevices(m.msg.devices);
          selected = selection(store.devices, selected);
        } else if (m.msg.event === "state") {
          store.onState(m.msg);
        }
      }
      eq(selected, "sn:EXAMPLE0000001");
      eq(
        store.devices.map((d) => d.id),
        ["sn:EXAMPLE0000001"],
      );
      eq(store.rev("sn:EXAMPLE0000001"), 9);
      eq(store.state("sn:EXAMPLE0000001").available, true);
    },
};
