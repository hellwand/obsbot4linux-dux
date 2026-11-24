// SPDX-License-Identifier: GPL-3.0-or-later
//
// Runs the test modules: in node through tests/run.mjs and in the QML engine through
// scripts/check-js.sh. A test module exports `tests`, an object of synchronous functions; a
// function passes when it returns and fails when it throws.

export function runAll(modules) {
  const lines = [];
  let passed = 0;
  let failed = 0;
  for (const file of Object.keys(modules).sort()) {
    const tests = modules[file].tests ?? {};
    for (const name of Object.keys(tests)) {
      try {
        tests[name]();
        passed += 1;
      } catch (e) {
        failed += 1;
        lines.push(
          `not ok - ${file}: ${name}: ${e && e.message ? e.message : String(e)}`,
        );
      }
    }
  }
  lines.push(`${passed} passed, ${failed} failed`);
  return { passed, failed, lines };
}
