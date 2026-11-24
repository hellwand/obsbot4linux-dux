// SPDX-License-Identifier: GPL-3.0-or-later
//
// node tests/run.mjs [file.test.mjs …]: runs the given test modules, or every tests/*.test.mjs.
// Exits 1 when a test fails or when no test ran.

import { readdirSync } from "node:fs";
import { dirname, join, basename } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { runAll } from "./harness.mjs";

const dir = dirname(fileURLToPath(import.meta.url));
const files =
  process.argv.length > 2
    ? process.argv.slice(2)
    : readdirSync(dir)
        .filter((f) => f.endsWith(".test.mjs"))
        .map((f) => join(dir, f));
const modules = {};
for (const file of files)
  modules[basename(file)] = await import(pathToFileURL(file).href);
const result = runAll(modules);
for (const line of result.lines) console.log(line);
if (result.failed > 0 || result.passed === 0) process.exit(1);
