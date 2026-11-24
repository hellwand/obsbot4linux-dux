// SPDX-License-Identifier: GPL-3.0-or-later
//
// The assertions of the test modules. Plain JavaScript, so that the same tests run in node and
// in the QML engine (scripts/check-js.sh).

function show(value) {
  return value === undefined ? "undefined" : JSON.stringify(value);
}

// Deep equality: numbers, strings, booleans and null by ===; arrays by length and items; objects
// by their own keys (an undefined property counts as absent).
export function same(a, b) {
  if (a === b) return true;
  if (
    a === null ||
    b === null ||
    typeof a !== "object" ||
    typeof b !== "object"
  )
    return false;
  if (Array.isArray(a) !== Array.isArray(b)) return false;
  if (Array.isArray(a))
    return a.length === b.length && a.every((x, i) => same(x, b[i]));
  const keys = (o) =>
    Object.keys(o)
      .filter((k) => o[k] !== undefined)
      .sort();
  const ka = keys(a);
  const kb = keys(b);
  return same(ka, kb) && ka.every((k) => same(a[k], b[k]));
}

export function eq(actual, expected, what) {
  if (!same(actual, expected))
    throw new Error(
      `${what ?? "value"}: expected ${show(expected)}, got ${show(actual)}`,
    );
}

export function ok(condition, what) {
  if (!condition) throw new Error(`${what ?? "condition"} is false`);
}

export function throws(fn, what) {
  try {
    fn();
  } catch (e) {
    return;
  }
  throw new Error(`${what ?? "call"} did not throw`);
}
