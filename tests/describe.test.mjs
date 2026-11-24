// SPDX-License-Identifier: GPL-3.0-or-later
import { eq, ok } from "./assert.mjs";
import {
  blocked,
  choices,
  decimals,
  has,
  humanize,
  limit,
  numberSpec,
  roundTo,
  setting,
  sliderScale,
  topics,
  wantedTopics,
  warnings,
  writable,
} from "../lib/describe.mjs";
import { A, B, STATES, UNKNOWN } from "./fixtures/fakes.mjs";

const TRACKING_LABELS = {
  static: "Static",
  normal: "Normal Tracking",
  upper_body: "Upper Body",
};
const stateOf = (d, extra) =>
  Object.assign({}, STATES[d.id].state, extra ?? {});

export const tests = {
  // 10.3 D: fake-b's missing groups hide their controls
  "fake-b has no gimbal and no views; fake-a has both": () => {
    ok(has(A, "gimbal") && has(A, "views") && has(A, "gimbal.move"), "fake-a");
    ok(
      !has(B, "gimbal") && !has(B, "views") && !has(B, "gimbal.move"),
      "fake-b",
    );
    ok(
      has(B, "tracking.mode") &&
        has(B, "tracking") &&
        !has(B, "tracking.profile"),
      "fake-b tracking",
    );
    ok(!has(B, "gim") && !has(B, ""), "a group is a whole path segment");
    ok(!has(UNKNOWN, "tracking"), "unsupported: nothing");
  },
  // 10.3 D: fake-b's own enum values, not the Tiny 2 Lite's
  "choices come from the description; unknown values get a text of their own":
    () => {
      eq(
        choices(B, "tracking.mode", TRACKING_LABELS).map((c) => [
          c.value,
          c.label,
        ]),
        [
          ["off", "Off"],
          ["person", "Person"],
          ["desk", "Desk"],
        ],
      );
      eq(
        choices(A, "tracking.mode", TRACKING_LABELS)
          .slice(0, 3)
          .map((c) => c.label),
        ["Static", "Normal Tracking", "Upper Body"],
      );
    },
  "values outside writable are shown but not selectable": () => {
    const fov = choices(A, "zoom.field_of_view", {});
    eq(
      fov.map((c) => [c.value, c.selectable]),
      [
        ["wide", true],
        ["medium", true],
        ["narrow", true],
        ["custom", false],
      ],
    );
  },
  // 10.3 D: fake-b's own bounds
  "number bounds come from the description": () => {
    eq(numberSpec(setting(B, "zoom.factor")), {
      min: 1,
      max: 2,
      step: 0.01,
      precision: 0.01,
      unit: "factor",
    });
    eq(numberSpec(setting(A, "zoom.factor")).max, 4);
    eq(numberSpec(setting(B, "led.brightness")), {
      min: 0,
      max: 5,
      step: 1,
      precision: 1,
      unit: null,
    });
  },
  "range bounds per component": () => {
    const pan = setting(A, "zone.area.pan");
    eq(numberSpec(pan, "min"), {
      min: -150,
      max: 150,
      step: 0.1,
      precision: 0.1,
      unit: "deg",
    });
  },
  // A slider's positions land on the step and never outside the bounds (W0 review focus 1)
  "a slider scale maps positions to stepped values": () => {
    const zoom = sliderScale(numberSpec(setting(B, "zoom.factor")));
    eq(
      [
        zoom.count,
        zoom.toValue(0),
        zoom.toValue(37),
        zoom.toValue(100),
        zoom.toValue(500),
      ],
      [100, 1, 1.37, 2, 2],
    );
    eq(zoom.toIndex(1.5), 50);
    const ratio = sliderScale(numberSpec(setting(A, "gestures.zoom_ratio")));
    eq([ratio.count, ratio.toValue(3)], [30, 1.3]);
    eq(sliderScale(numberSpec(setting(A, "hand.return_after"))), null);
  },
  "rounding and decimals": () => {
    eq(
      [decimals(0.01), decimals(0.1), decimals(1), decimals(undefined)],
      [2, 1, 0, 0],
    );
    eq(roundTo(0.1 + 0.2, 0.1), 0.3);
    eq(humanize("upper_body"), "Upper body");
    eq(humanize("raw:7"), "raw:7");
  },
  "writable: read-only leaves and unknown types are not": () => {
    ok(writable(A, "led.brightness"), "led");
    ok(!writable(A, "gimbal.pan"), "pose is read-only");
    const odd = Object.assign({}, A, {
      settings: {
        "image.matrix": { type: "matrix", label: "M", readonly: false },
      },
    });
    ok(!writable(odd, "image.matrix"), "unknown type");
  },
  // 4.2 requires: the control is blocked; the widget never adds the needed leaf itself
  "a requires that does not hold blocks the control and names the need": () => {
    eq(blocked(B, stateOf(B), "exposure.time"), {
      reason: "requires",
      needs: [{ path: "exposure.mode", equals: "manual" }],
    });
    eq(
      blocked(
        B,
        stateOf(B, { exposure: { mode: "manual", time: 100 } }),
        "exposure.time",
      ),
      null,
    );
  },
  // 4.1 rule 5: the daemon checks a request against the state with its pending values laid
  // over it, so a pending requirement holds; a pending change away from it does not
  "a requirement that is pending holds, and one pending the other way does not":
    () => {
      eq(
        blocked(
          B,
          stateOf(B, { pending: { "exposure.mode": "manual" } }),
          "exposure.time",
        ),
        null,
      );
      eq(
        blocked(
          B,
          stateOf(B, {
            exposure: { mode: "manual" },
            pending: { "exposure.mode": "auto" },
          }),
          "exposure.time",
        ),
        {
          reason: "requires",
          needs: [{ path: "exposure.mode", equals: "manual" }],
        },
      );
      eq(
        blocked(B, stateOf(B, { pending: { asleep: true } }), "zoom.factor"),
        { reason: "asleep" },
      );
    },
  // 5.7: asleep: ignored is refused by the daemon; the control is off while asleep
  "asleep blocks only what the description marks ignored": () => {
    const asleep = stateOf(B, { asleep: true });
    eq(blocked(B, asleep, "zoom.factor"), { reason: "asleep" });
    eq(blocked(B, asleep, "led.brightness"), null);
    eq(blocked(B, asleep, "preset.save"), { reason: "asleep" });
    eq(blocked(B, asleep, "wake"), null);
  },
  "an unavailable or unsupported device blocks everything": () => {
    eq(
      blocked(
        Object.assign({}, B, { available: false }),
        stateOf(B),
        "led.brightness",
      ),
      { reason: "unavailable" },
    );
    eq(blocked(UNKNOWN, STATES[UNKNOWN.id].state, "led.brightness"), {
      reason: "unavailable",
    });
    eq(blocked(B, stateOf(B), "gimbal.move"), { reason: "unavailable" });
    eq(blocked(A, stateOf(A), "gimbal.pan"), { reason: "readonly" });
  },
  "warnings to confirm": () => {
    eq(warnings(A, "factory_reset"), ["destructive", "restart"]);
    eq(warnings(A, "audio.enabled"), ["restart"]);
    eq(warnings(A, "led.brightness"), []);
  },
  // 10.3 D: fake-b's preset count
  "list limits": () => {
    eq(
      [limit(A, "presets"), limit(B, "presets"), limit(A, "views")],
      [3, 5, null],
    );
  },
  // 10.3 D: live topics only while the popout is open
  "live topics: none while closed, only the shown and named ones while open":
    () => {
      eq(topics(A), ["auto", "pose", "target"]);
      eq(topics(B), ["auto"]);
      eq(
        wantedTopics(A, { open: false, pose: true, target: true, auto: true }),
        [],
      );
      eq(
        wantedTopics(A, { open: true, pose: true, target: false, auto: true }),
        ["auto", "pose"],
      );
      eq(
        wantedTopics(B, { open: true, pose: true, target: true, auto: true }),
        ["auto"],
      );
    },
};
