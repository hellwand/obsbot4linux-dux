// SPDX-License-Identifier: GPL-3.0-or-later
import { eq, ok } from "./assert.mjs";
import { labelledPaths, labelsFor, problemText } from "../lib/labels.mjs";
import { choices } from "../lib/describe.mjs";
import tiny2lite from "./fixtures/tiny2lite.description.mjs";
import { B } from "./fixtures/fakes.mjs";

const lite = Object.assign({ available: true, support: "tested" }, tiny2lite);

export const tests = {
  // A label names a value the description has; a typo would silently never show
  "every labelled value is a value of the Tiny 2 Lite's description": () => {
    for (const path of labelledPaths()) {
      const values = lite.settings[path]?.values ?? [];
      ok(values.length > 0, `${path} is an enum of the description`);
      for (const value of Object.keys(labelsFor(path)))
        ok(values.includes(value), `${path}: ${value} is in values`);
    }
  },
  "the description decides the chips; the labels only name them": () => {
    eq(
      choices(B, "tracking.mode", labelsFor("tracking.mode")).map(
        (c) => c.label,
      ),
      ["Off", "Person", "Desk"],
    );
    eq(labelsFor("not.labelled"), {});
  },
  // 5.10 and 6.2: the exact command that starts the daemon
  "the unreachable hint carries the systemctl line": () => {
    ok(
      problemText("unreachable").body.includes(
        "systemctl --user enable --now obsbot4linux.socket",
      ),
      "systemctl line",
    );
    eq(
      problemText("old").body,
      "an obsbot4linux daemon older than 1.0 is running: restart it or log out",
    );
    eq(problemText(""), null);
  },
};
