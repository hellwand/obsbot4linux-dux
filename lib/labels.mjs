// SPDX-License-Identifier: GPL-3.0-or-later
//
// The widget's own words: names for enum values it knows (a value it does not know shows as
// text made from the value, describe.humanize) and the texts for a daemon it cannot use.
// Which values a control offers always comes from the device's description, never from here.

const TRACKING = {
  static: "Static",
  normal: "Normal Tracking",
  upper_body: "Upper Body",
  close_up: "Close-up",
  headless: "Headless",
  lower_body: "Lower Body",
  hand: "Hand",
  group: "Group",
};

const LABELS = {
  "tracking.mode": TRACKING,
  "power_on.mode": TRACKING,
  "power_on.start.mode": Object.assign({}, TRACKING, { unset: "Not set" }),
  "tracking.profile": {
    standard: "Standard",
    headroom: "Headroom",
    sport: "Sport",
  },
  "hand.side": { left: "Left", right: "Right" },
  "zoom.field_of_view": {
    wide: "Wide",
    medium: "Medium",
    narrow: "Narrow",
    custom: "Custom",
  },
  "exposure.mode": { auto: "Auto", manual: "Manual" },
  "exposure.region": { face: "Face", global: "Global" },
  "sleep.background": {
    black: "Black",
    image: "Picture",
    own_image: "Own picture",
  },
  "audio.noise_reduction": {
    off: "Off",
    weak: "Weak",
    medium: "Medium",
    strong: "Strong",
  },
};

export function labelsFor(path) {
  return LABELS[path] ?? {};
}

// Every path this table names, for its test against the descriptions.
export function labelledPaths() {
  return Object.keys(LABELS);
}

// What the widget shows while it cannot use the daemon (lib/session.mjs problems; spec 5.10).
export function problemText(problem) {
  switch (problem) {
    case "unreachable":
      return {
        title: "obsbot4linux is not running",
        body: "Start its socket once: systemctl --user enable --now obsbot4linux.socket",
      };
    case "old":
      return {
        title: "obsbot4linux is older than 1.0",
        body: "an obsbot4linux daemon older than 1.0 is running: restart it or log out",
      };
    case "protocol":
      return {
        title: "obsbot4linux speaks another protocol",
        body: "Install the same version of obsbot4linux and this widget, then restart the daemon.",
      };
    case "lost":
      return {
        title: "Connection to obsbot4linux lost",
        body: "Reconnecting…",
      };
    default:
      return null;
  }
}
