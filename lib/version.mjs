// SPDX-License-Identifier: GPL-3.0-or-later
//
// The startup check's version test (StartupCheck.qml): which obsbot4linux the widget accepts.

// "obsbot4linux 1.0.0-rc.2" -> [1, 0, 0]; null when the text holds no X.Y.Z. A pre-release
// suffix is ignored, so a release candidate of 1.0.0 counts as 1.0.0: stage W4 runs widget 1.0
// against the candidate.
export function parseVersion(text) {
  const m = /(\d+)\.(\d+)\.(\d+)/.exec(String(text));
  return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : null;
}

export function isOlder(version, other) {
  for (let i = 0; i < 3; i++) {
    if (version[i] !== other[i]) return version[i] < other[i];
  }
  return false;
}

// The result of `obsbot4linux --version` (its stdout and exit code) against [min, max): null
// when it fits, else { title, details } for the shell's startup-check message. max null: no
// upper bound.
export function checkTool(stdout, exitCode, min, max, links) {
  const minimum = min.join(".");
  const range = max
    ? `${minimum} or newer (before ${max[0]}.0)`
    : `${minimum} or newer`;
  if (exitCode !== 0) {
    return {
      title: "obsbot4linux is required",
      details: `The 'obsbot4linux' tool is not installed or not on your PATH. This plugin needs obsbot4linux ${range}.\n\nInstall it from ${links.releases}, then enable this plugin again.`,
    };
  }
  const version = parseVersion(stdout);
  const installed = String(stdout).trim();
  if (version && !isOlder(version, min) && (!max || isOlder(version, max)))
    return null;
  if (version && max && !isOlder(version, max)) {
    return {
      title: `obsbot4linux ${max[0]}.0 or newer needs a newer widget`,
      details: `Installed: ${installed}. This widget version works with obsbot4linux ${range}.\n\nUpdate this plugin (obsbot4linux-dux) from ${links.widgetReleases}, then enable it again.`,
    };
  }
  return {
    title: `obsbot4linux ${minimum} or newer is required`,
    details: `Installed: ${installed}. This plugin needs obsbot4linux ${range}.\n\nUpdate it from ${links.releases}, then enable this plugin again.`,
  };
}
