// SPDX-License-Identifier: GPL-3.0-or-later
//
// The gimbal arrows: the camera has no relative move, so the widget computes the target of a
// step and sends one gimbal.move with it (spec 15 row 14), and nothing else (section 2: no
// tracking switch before it).

import { action, numberSpec, roundTo } from "./describe.mjs";

// How long the target of the last own move stays the base of the next step: the live pose reads
// a point in between while the gimbal is still on its way, and quick presses would fall short.
export const STEP_BASE_MS = 2000;

// The bounds of gimbal.move's pan and tilt, or null when the device has no gimbal.move.
export function moveSpec(device) {
  const a = action(device, "gimbal.move");
  if (!a?.params?.pan || !a?.params?.tilt) return null;
  return { pan: numberSpec(a.params.pan), tilt: numberSpec(a.params.tilt) };
}

function clamp(v, spec) {
  let x = v;
  if (spec.min !== null) x = Math.max(spec.min, x);
  if (spec.max !== null) x = Math.min(spec.max, x);
  return roundTo(x, spec.precision);
}

// The target of one arrow step. pose: { pan, tilt } of the state (the live pose); last: the
// target of the previous own move and when it was sent ({ pan, tilt, at }) or null; now: ms.
// null while the base has no numeric pan and tilt (the pose is not read yet): a step from a
// made-up pose would send the gimbal to a target the user never asked for.
export function stepTarget(spec, pose, last, now, dPan, dTilt) {
  const base = last && now - last.at < STEP_BASE_MS ? last : pose;
  if (typeof base?.pan !== "number" || typeof base?.tilt !== "number")
    return null;
  return {
    pan: clamp(base.pan + dPan, spec.pan),
    tilt: clamp(base.tilt + dTilt, spec.tilt),
  };
}

// The one request of a gimbal control: { action, params }.
export function moveRequest(target) {
  return {
    action: "gimbal.move",
    params: { pan: target.pan, tilt: target.tilt },
  };
}

// The arrows follow the picture: with the image mirrored, the picture's left is the camera's
// right (pan positive = the camera turns to its left, 4.2).
export function panLeftSign(state) {
  return state?.image?.mirror === true ? -1 : 1;
}
