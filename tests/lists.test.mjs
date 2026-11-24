// SPDX-License-Identifier: GPL-3.0-or-later
import { eq, ok } from "./assert.mjs";
import {
  moveRequest,
  moveSpec,
  panLeftSign,
  stepTarget,
} from "../lib/gimbal.mjs";
import {
  nameProblem,
  presetRows,
  presetSlots,
  saveParams,
  UNNAMED,
  viewRows,
} from "../lib/lists.mjs";
import { A, B, STATES } from "./fixtures/fakes.mjs";

export const tests = {
  // 10.3 D: fake-b's preset count (5), not the Tiny 2 Lite's (3)
  "preset slots follow the description": () => {
    eq(presetSlots(A), [0, 1, 2]);
    eq(presetSlots(B), [0, 1, 2, 3, 4]);
    eq(presetSlots({ settings: {}, actions: {}, limits: {} }), []);
  },
  // 12.3: an empty name shows a placeholder of the widget's own, as display only
  "preset rows: used, unnamed, empty; null while unread": () => {
    const s = {
      available: true,
      pending: {},
      unread: [],
      presets: [
        { slot: 0, name: "Desk", pose: { pan: 1, tilt: 2, zoom: 1 } },
        { slot: 2, name: "", pose: null },
      ],
    };
    eq(
      presetRows(A, s).map((r) => [r.slot, r.used, r.label]),
      [
        [0, true, "Desk"],
        [1, false, "Empty"],
        [2, true, UNNAMED],
      ],
    );
    eq(
      presetRows(A, {
        available: true,
        pending: {},
        unread: ["presets"],
        presets: null,
      }),
      null,
    );
    eq(presetRows(B, STATES[B.id].state).length, 5);
  },
  // 12.3: saving a preset sends no name unless the user typed one
  "preset.save carries a name only when one was typed": () => {
    eq(saveParams(1, ""), { slot: 1 });
    eq(saveParams(1, "Desk"), { slot: 1, name: "Desk" });
    eq(saveParams(1, " "), { slot: 1, name: " " });
  },
  "names are checked against the description's bounds": () => {
    eq(nameProblem(B, "preset.save", "name", "x".repeat(16)), null);
    eq(
      nameProblem(B, "preset.save", "name", "x".repeat(17)),
      "at most 16 characters",
    );
    eq(
      nameProblem(A, "preset.rename", "name", "Büro"),
      "letters, digits and punctuation without accents only",
    );
    eq(nameProblem(A, "view.save", "name", ""), "a name is needed");
    eq(nameProblem(A, "preset.save", "name", ""), null);
    eq(nameProblem(B, "view.save", "name", "x"), "not offered by this camera");
  },
  "views: rows, or null while unread": () => {
    eq(
      viewRows({ unread: [], views: [{ id: 3, name: "Board", pose: null }] }),
      [{ id: 3, name: "Board", label: "Board", pose: null }],
    );
    eq(viewRows({ unread: ["views"], views: null }), null);
  },
  "gimbal: no gimbal.move, no arrows": () => {
    eq(moveSpec(B), null);
    eq(moveSpec(A).pan, {
      min: -150,
      max: 150,
      step: 0.1,
      precision: 0.1,
      unit: "deg",
    });
  },
  "a step builds on the live pose, or on the last own target within 2 s; none without either":
    () => {
      const spec = moveSpec(A);
      eq(stepTarget(spec, { pan: 10, tilt: 0 }, null, 0, 5, 0), {
        pan: 15,
        tilt: 0,
      });
      eq(
        stepTarget(
          spec,
          { pan: 10, tilt: 0 },
          { pan: 20, tilt: 5, at: 1000 },
          2500,
          5,
          0,
        ),
        { pan: 25, tilt: 5 },
      );
      eq(
        stepTarget(
          spec,
          { pan: 10, tilt: 0 },
          { pan: 20, tilt: 5, at: 1000 },
          3000,
          5,
          0,
        ),
        { pan: 15, tilt: 0 },
      );
      eq(stepTarget(spec, { pan: 148, tilt: 88 }, null, 0, 5, 5), {
        pan: 150,
        tilt: 90,
      });
      // no known pose and no recent own target: no step (the widget never makes a pose up)
      eq(stepTarget(spec, null, null, 0, -5, 0), null);
      eq(stepTarget(spec, { pan: null, tilt: null }, null, 0, 5, 0), null);
      eq(
        stepTarget(
          spec,
          { pan: null, tilt: null },
          { pan: 20, tilt: 5, at: 1000 },
          2500,
          5,
          0,
        ),
        { pan: 25, tilt: 5 },
      );
    },
  // spec 2, 12.3: a gimbal control sends gimbal.move alone, never a tracking switch
  "a gimbal step is one gimbal.move with pan and tilt": () => {
    eq(moveRequest({ pan: 15, tilt: 0 }), {
      action: "gimbal.move",
      params: { pan: 15, tilt: 0 },
    });
  },
  "the arrows follow the picture": () => {
    eq(panLeftSign({ image: { mirror: true } }), -1);
    eq(panLeftSign(STATES[A.id].state), 1);
    ok(panLeftSign(null) === 1, "no state");
  },
};
