// SPDX-License-Identifier: GPL-3.0-or-later
//
// The hello reply of a daemon started with `--fake fake-a,fake-b,unknown` before its first
// events: device facts and first states as the fake models report them (stage W0), each
// description from the synced description files. Written by hand for the tests;
// tests/e2e/fake-daemon.test.mjs compares it with the hello of the real fake daemon.

import fakeA from "./fake-a.description.mjs";
import fakeB from "./fake-b.description.mjs";

const empty = { settings: {}, actions: {}, limits: {} };

export const A = Object.assign(
  {
    id: "sn:FAKEA0000001",
    name: "Fake A 0001",
    model: "fake-a",
    support: "tested",
    serial: "FAKEA0000001",
    firmware: "1.0.0.0",
    video_node: "/dev/video102",
    available: true,
    usb: {
      vendor: "3564",
      product: "fa0a",
      product_name: "Fake A",
      bcd_device: "0100",
      path: "9-1",
      serial_present: false,
      interfaces: ["0e", "0e", "01", "01"],
      extension_units: [],
    },
  },
  fakeA,
);
export const B = Object.assign(
  {
    id: "sn:FAKEB0000001",
    name: "Fake B 0001",
    model: "fake-b",
    support: "untested",
    serial: "FAKEB0000001",
    firmware: "0.9.1",
    video_node: "/dev/video104",
    available: true,
    usb: {
      vendor: "3564",
      product: "fa0b",
      product_name: "Fake B",
      bcd_device: "0100",
      path: "9-2",
      serial_present: false,
      interfaces: ["0e", "0e"],
      extension_units: [],
    },
  },
  fakeB,
);
export const UNKNOWN = Object.assign(
  {
    id: "port:9-3",
    name: "Unknown Camera 9-3",
    model: "unknown",
    support: "unsupported",
    serial: null,
    firmware: null,
    video_node: "/dev/video106",
    available: true,
    usb: {
      vendor: "3564",
      product: "fa00",
      product_name: "Unknown Camera",
      bcd_device: "0100",
      path: "9-3",
      serial_present: false,
      interfaces: ["0e", "0e"],
      extension_units: [],
    },
  },
  empty,
);

export const STATES = {
  "port:9-3": { rev: 1, state: { available: true, pending: {}, unread: [] } },
  "sn:FAKEA0000001": {
    rev: 1,
    state: {
      available: true,
      pending: {},
      unread: [],
      asleep: false,
      audio: {
        auto_gain: false,
        enabled: false,
        in_sleep: false,
        noise_reduction: "off",
        volume: 0,
      },
      exposure: {
        anti_flicker: "off",
        compensation: 9.0,
        gain: 1.0,
        hdr: false,
        mode: "auto",
        region: "face",
        time: 33000,
      },
      focus: { mode: "continuous", position: 0.0, region: "face" },
      framing: {
        auto_zoom: false,
        offset: { x: 0, y: 0 },
        part: "normal",
        size: "long_shot",
        zoom_speed: "slow",
      },
      gestures: {
        direction_change: false,
        dynamic_zoom: false,
        target_lock: false,
        zoom: false,
        zoom_ratio: 1,
      },
      gimbal: { invert: false, pan: 0, tilt: 0 },
      hand: {
        area: { pan: { max: 150, min: -150 }, tilt: { max: 90, min: -70 } },
        axes: { pan: false, tilt: false },
        move_gimbal: null,
        return: null,
        return_after: 0,
        side: "left",
      },
      image: {
        brightness: 50.0,
        contrast: 50.0,
        frame_rate: 30,
        hue: 50.0,
        mirror: false,
        saturation: 50.0,
        sharpness: 50.0,
        white_balance: { auto: true, temperature: 5000 },
      },
      led: { blink: null, brightness: 0 },
      on_air: { active: false, apps: [] },
      power_on: {
        mode: "static",
        settings: {
          auto_exposure: null,
          autofocus: null,
          contrast: null,
          exposure_compensation: 0,
          hue: null,
          saturation: null,
          sharpness: null,
          tracking_speed: null,
          white_balance_mode: null,
          white_balance_temperature: null,
        },
        start: {
          mode: "static",
          pose: { pan: 0, tilt: 0, zoom: 1 },
          source: "own",
        },
      },
      presets: [],
      sleep: {
        auto: { enabled: false, seconds: 1 },
        background: "black",
        background_mirror: false,
        wake_zoom: 1,
      },
      tracking: {
        mode: "static",
        profile: "standard",
        speed: "lazy",
        target: { box: null, detected: false },
      },
      views: [],
      zone: {
        area: { pan: { max: 150, min: -150 }, tilt: { max: 90, min: -70 } },
        enabled: false,
        follow: false,
        return: { pan: 0, tilt: 0, zoom: 1 },
      },
      zoom: { factor: 1, field_of_view: "wide" },
    },
  },
  "sn:FAKEB0000001": {
    rev: 1,
    state: {
      available: true,
      pending: {},
      unread: [],
      asleep: false,
      beacon: { color: "red", pulse: null },
      exposure: { mode: "auto", time: 100 },
      led: { blink: null, brightness: 0 },
      on_air: { active: false, apps: [] },
      presets: [],
      tracking: { mode: "off" },
      zoom: { factor: 1 },
    },
  },
};

export const HELLO = {
  protocol: 2,
  daemon: "1.0.0",
  devices: [A, B, UNKNOWN],
  states: STATES,
};
