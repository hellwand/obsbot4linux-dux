// SPDX-License-Identifier: GPL-3.0-or-later
import { eq, ok } from "./assert.mjs";
import { checkTool, isOlder, parseVersion } from "../lib/version.mjs";

const links = { releases: "R", widgetReleases: "W" };

export const tests = {
  "a version line parses into three numbers": () => {
    eq(parseVersion("obsbot4linux 0.13.2\n"), [0, 13, 2]);
    eq(parseVersion("no version here"), null);
  },
  // W4 runs widget 1.0 against v1.0.0-rc.N: the candidate must pass the 1.0 check
  "a release candidate counts as its release": () => {
    eq(parseVersion("obsbot4linux 1.0.0-rc.3"), [1, 0, 0]);
    eq(checkTool("obsbot4linux 1.0.0-rc.3", 0, [1, 0, 0], null, links), null);
  },
  "isOlder compares major, minor, patch in that order": () => {
    ok(isOlder([0, 13, 2], [1, 0, 0]), "0.13.2 < 1.0.0");
    ok(!isOlder([1, 0, 0], [1, 0, 0]), "equal is not older");
    ok(isOlder([1, 9, 9], [1, 10, 0]), "minor wins over patch");
  },
  // Widget 1.0 speaks protocol 2 only: a 0.13 tool must be refused at enable time
  "widget 1.0 refuses a 0.x tool and names the minimum": () => {
    const r = checkTool("obsbot4linux 0.13.2", 0, [1, 0, 0], null, links);
    eq(r.title, "obsbot4linux 1.0.0 or newer is required");
    ok(
      r.details.includes("Installed: obsbot4linux 0.13.2"),
      "details name the installed version",
    );
  },
  // Widget 1.0 keeps working with newer tools (it shows what the description offers), so the
  // 1.0 check has no upper bound
  "widget 1.0 accepts newer obsbot4linux releases": () => {
    eq(checkTool("obsbot4linux 1.4.0", 0, [1, 0, 0], null, links), null);
    eq(checkTool("obsbot4linux 2.0.0", 0, [1, 0, 0], null, links), null);
  },
  // The first stable release itself must pass the 1.0 check (min is inclusive, no upper bound)
  "widget 1.0 accepts obsbot4linux 1.0.0": () => {
    eq(checkTool("obsbot4linux 1.0.0", 0, [1, 0, 0], null, links), null);
  },
  // 0.14.0 is the last 0.x on the owner's desktop and speaks protocol 1, so it must be refused
  "widget 1.0 refuses obsbot4linux 0.14.0": () => {
    eq(
      checkTool("obsbot4linux 0.14.0", 0, [1, 0, 0], null, links).title,
      "obsbot4linux 1.0.0 or newer is required",
    );
  },
  // The 0.x widget's bound: obsbot4linux 1.0 needs widget 1.0
  "a 0.x widget refuses 1.0 and points to the widget releases": () => {
    const r = checkTool("obsbot4linux 1.0.0", 0, [0, 7, 3], [1, 0, 0], links);
    eq(r.title, "obsbot4linux 1.0 or newer needs a newer widget");
    ok(r.details.includes("W"), "details link the widget releases");
  },
  "a missing tool is reported as not installed": () => {
    eq(
      checkTool("", 127, [1, 0, 0], null, links).title,
      "obsbot4linux is required",
    );
  },
  "an unreadable version is refused, not accepted": () => {
    eq(
      checkTool("obsbot4linux dev", 0, [1, 0, 0], null, links).title,
      "obsbot4linux 1.0.0 or newer is required",
    );
  },
};
