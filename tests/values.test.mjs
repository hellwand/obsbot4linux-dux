// SPDX-License-Identifier: GPL-3.0-or-later
import { eq, ok } from "./assert.mjs";
import {
  changed,
  defaults,
  OwnValues,
  shown,
  status,
  targetBox,
} from "../lib/values.mjs";
import { number, unitText, value } from "../lib/format.mjs";
import { setting } from "../lib/describe.mjs";
import { A, B, STATES } from "./fixtures/fakes.mjs";
import session from "./fixtures/session.transcript.mjs";

const IMAGE = [
  "image.brightness",
  "image.contrast",
  "image.saturation",
  "image.hue",
  "image.sharpness",
  "image.white_balance.auto",
  "image.white_balance.temperature",
  "exposure.compensation",
];

export const tests = {
  // Measured on the Tiny 2 Lite with 1.0.0: after a switch to Static the state kept the last box
  // and detected true for as long as the mode stayed Static, because the target is not asked then.
  "no target box in Static: the box is the last one read, not where the target is":
    () => {
      const box = { left: 0, top: 0.39, right: 0.19, bottom: 0.98 };
      eq(targetBox("static", box), null);
      eq(targetBox("normal", box), box);
      eq(targetBox("close_up", box), box);
      eq(targetBox("normal", null), null);
      eq(targetBox(null, box), box);
    },
  // 4.1 rule 4: own value from sending until the reply, then the state with its pending values
  "own value, then pending, then the camera's value": () => {
    const own = new OwnValues();
    const before = {
      available: true,
      pending: {},
      unread: [],
      led: { brightness: 1 },
    };
    own.add(7, { "led.brightness": 3 });
    eq(
      [
        shown(before, own, "led.brightness"),
        status(before, own, "led.brightness"),
      ],
      [3, "own"],
    );
    const pendingState = {
      available: true,
      pending: { "led.brightness": 3 },
      unread: [],
      led: { brightness: 1 },
    };
    own.settle(7);
    eq(
      [
        shown(pendingState, own, "led.brightness"),
        status(pendingState, own, "led.brightness"),
      ],
      [3, "pending"],
    );
    const after = {
      available: true,
      pending: {},
      unread: [],
      led: { brightness: 3 },
    };
    eq(
      [
        shown(after, own, "led.brightness"),
        status(after, own, "led.brightness"),
      ],
      [3, "camera"],
    );
  },
  // 10.3 D: a value set by another client (the CLI) shows at once through pending
  "a write of another client shows at once through pending": () => {
    const lines = session.filter(
      (m) => m.from === "daemon" && m.msg.event === "state",
    );
    const first = lines[0].msg.state;
    eq(first.led.brightness, 1);
    eq(shown(first, new OwnValues(), "led.brightness"), 2);
    eq(status(first, new OwnValues(), "led.brightness"), "pending");
  },
  "the newest own value wins; an error takes back only its own": () => {
    const own = new OwnValues();
    own.add(4, { "zoom.factor": 1.5 });
    own.add(5, { "zoom.factor": 1.8 });
    eq(own.value("zoom.factor"), 1.8);
    own.settle(5);
    eq(own.value("zoom.factor"), 1.5);
    own.clear();
    eq(own.value("zoom.factor"), undefined);
  },
  "an unread leaf is null and says so": () => {
    const s = {
      available: true,
      pending: {},
      unread: ["presets"],
      presets: null,
    };
    eq(
      [shown(s, null, "presets"), status(s, null, "presets")],
      [null, "unread"],
    );
    eq(shown(s, null, "not.there"), null);
  },
  // One control, one request, only what the user changed (spec 2)
  "an area edit sends only the leaves that changed": () => {
    const s = STATES[A.id].state;
    eq(
      changed(s, null, {
        "zone.area.pan": s.zone.area.pan,
        "zone.area.tilt": { min: -20, max: 30 },
      }),
      { "zone.area.tilt": { min: -20, max: 30 } },
    );
    eq(changed(s, null, { "zone.area.pan": s.zone.area.pan }), null);
  },
  // 10.3 D defaults reset: one patch of defaults; leaves with requires stay out, so the
  // daemon cannot refuse the whole patch with conflict
  "the defaults reset patch": () => {
    const s = Object.assign({}, STATES[A.id].state, {
      image: Object.assign({}, STATES[A.id].state.image, {
        brightness: 80,
        white_balance: { auto: false, temperature: 4000 },
      }),
    });
    eq(defaults(A, s, null, IMAGE), {
      "image.brightness": 50,
      "image.white_balance.auto": true,
    });
    eq(defaults(A, STATES[A.id].state, null, IMAGE), null);
    eq(defaults(B, STATES[B.id].state, null, IMAGE), null);
  },
  "numbers with units and precision": () => {
    eq(number(-12.54, 0.1, "deg"), "−12.5°");
    eq(number(1.5, 0.01, "factor"), "1.50×");
    eq(number(33000, 1, "us"), "33000 µs");
    eq(unitText("lux"), " lux");
  },
  "values by type; raw and unknown types as text": () => {
    eq(value(setting(A, "image.mirror"), true), "On");
    eq(
      value(setting(A, "tracking.mode"), "upper_body", {
        upper_body: "Upper Body",
      }),
      "Upper Body",
    );
    eq(value(setting(B, "tracking.mode"), "person"), "Person");
    eq(value(setting(A, "tracking.mode"), "raw:9"), "raw:9");
    eq(
      value(setting(A, "zone.area.pan"), { min: -20, max: 20 }),
      "−20.0…20.0°",
    );
    eq(value(setting(A, "hand.return"), null), "–");
    eq(value({ type: "matrix" }, [1, 2]), "[1,2]");
  },
};
