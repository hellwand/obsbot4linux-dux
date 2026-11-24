// SPDX-License-Identifier: GPL-3.0-or-later
//
// The widget's link against the real daemon in fake mode (spec 10.3 D, "Acceptance without
// camera"): OBSBOT4LINUXD names the daemon binary, started here as
// `obsbot4linuxd --fake fake-a,fake-b,unknown` on a temporary socket. Run: node --test tests/e2e/

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { existsSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { NodeLink, exchange } from "./node-link.mjs";
import { choices, has, limit } from "../../lib/describe.mjs";
import { marker, unsupportedHint, usable } from "../../lib/devices.mjs";
import { presetSlots } from "../../lib/lists.mjs";
import { moveRequest, moveSpec, stepTarget } from "../../lib/gimbal.mjs";
import { HELLO } from "../fixtures/fakes.mjs";

const daemon = process.env.OBSBOT4LINUXD;
const A = "sn:FAKEA0000001";
const B = "sn:FAKEB0000001";
const UNKNOWN = "port:9-3";
let dir;
let sock;
let child;

async function waitForFile(path, ms) {
  const end = Date.now() + ms;
  while (!existsSync(path)) {
    if (Date.now() > end) throw new Error(`${path} did not appear`);
    await new Promise((r) => setTimeout(r, 50));
  }
}

async function connected() {
  const n = new NodeLink(sock, "obsbot4linux-dux e2e");
  n.start();
  await n.until(() => n.link.ready, 20000, "hello reply");
  return n;
}

before(async () => {
  assert.ok(daemon, "set OBSBOT4LINUXD to the obsbot4linuxd binary");
  dir = mkdtempSync(join(tmpdir(), "obsbot-dux-e2e-"));
  sock = join(dir, "obsbot4linux.sock");
  child = spawn(daemon, ["--fake", "fake-a,fake-b,unknown"], {
    env: Object.assign({}, process.env, { OBSBOT4LINUX_SOCKET: sock }),
    stdio: ["ignore", "inherit", "inherit"],
  });
  await waitForFile(sock, 10000);
  await waitForFile(sock + ".test", 10000);
});

after(() => {
  child?.kill("SIGTERM");
  if (dir) rmSync(dir, { recursive: true, force: true });
});

test("hello lists the three fakes; nothing is chosen with two usable devices", async () => {
  const n = await connected();
  try {
    assert.deepEqual(
      n.link.store.devices.map((d) => d.id).sort(),
      [UNKNOWN, A, B].sort(),
    );
    assert.equal(n.link.device(), null);
    const unknown = n.link.store.device(UNKNOWN);
    assert.equal(marker(unknown), "unsupported");
    assert.equal(usable(unknown), false);
    assert.match(unsupportedHint(unknown), /obsbot4linux devices --report/);
  } finally {
    n.stop();
  }
});

// The unit tests rely on tests/fixtures/fakes.mjs, written by hand: its device entries and first
// states must be what the daemon sends. Runs before the tests below change values. firmware and
// video_node are left out (the daemon may fill them in for a fake); on_air is the daemon's probe.
test("the unit tests' fixtures match the fake daemon's hello", async () => {
  const n = await connected();
  try {
    const fields = [
      "id",
      "name",
      "model",
      "support",
      "serial",
      "available",
      "usb",
      "settings",
      "actions",
      "limits",
    ];
    const facts = (d) => Object.fromEntries(fields.map((k) => [k, d[k]]));
    for (const want of HELLO.devices) {
      const got = n.link.store.device(want.id);
      assert.ok(got, `${want.id} is listed`);
      assert.deepEqual(facts(got), facts(want), want.id);
    }
    await n.until(
      () =>
        HELLO.devices.every(
          (d) => n.link.store.state(d.id)?.unread?.length === 0,
        ),
      5000,
      "the first reads",
    );
    const withoutOnAir = (state) => {
      const copy = Object.assign({}, state);
      delete copy.on_air;
      return copy;
    };
    for (const id of Object.keys(HELLO.states))
      assert.deepEqual(
        withoutOnAir(n.link.store.state(id)),
        withoutOnAir(HELLO.states[id].state),
        id,
      );
  } finally {
    n.stop();
  }
});

test("fake-b: unknown group carried, missing groups absent, own values, bounds and presets", async () => {
  const n = await connected();
  try {
    n.run(n.link.pick(B));
    const d = n.link.device();
    assert.equal(has(d, "gimbal"), false);
    assert.equal(has(d, "views"), false);
    assert.deepEqual(
      choices(d, "tracking.mode", {}).map((c) => c.value),
      ["off", "person", "desk"],
    );
    assert.equal(limit(d, "presets"), 5);
    assert.deepEqual(presetSlots(d), [0, 1, 2, 3, 4]);
    assert.equal(typeof n.link.shown("beacon.color"), "string");
  } finally {
    n.stop();
  }
});

test("a value set by another client shows at once (pending or read back)", async () => {
  const n = await connected();
  try {
    n.run(n.link.pick(B));
    const before = n.link.shown("led.brightness");
    const next = before === 4 ? 2 : 4;
    // a second client, as the CLI is: hello, then one set
    const replies = await exchange(
      sock,
      [
        {
          id: 1,
          hello: { protocol: 2, client: "e2e-cli", subscribe: false, live: [] },
        },
        { id: 2, device: B, set: { "led.brightness": next } },
      ],
      2,
    );
    assert.ok(replies[1].ok, JSON.stringify(replies[1]));
    await n.until(
      () => n.link.shown("led.brightness") === next,
      2000,
      "the other client's value",
    );
  } finally {
    n.stop();
  }
});

test("the widget's own set: one request, own value until the reply", async () => {
  const n = await connected();
  try {
    n.run(n.link.pick(B));
    const effects = n.link.set("tracking.mode", "person");
    assert.equal(effects.filter((e) => "write" in e).length, 1);
    n.run(effects);
    assert.equal(n.link.status("tracking.mode"), "own");
    await n.until(() => n.link.own.size === 0, 5000, "the reply");
    assert.equal(n.link.shown("tracking.mode"), "person");
  } finally {
    n.stop();
  }
});

test("a gimbal step on fake-a is one gimbal.move and leaves the tracking mode alone", async () => {
  const n = await connected();
  try {
    n.run(n.link.pick(A));
    const mode = n.link.shown("tracking.mode");
    const target = stepTarget(
      moveSpec(n.link.device()),
      n.link.state().gimbal,
      null,
      Date.now(),
      5,
      0,
    );
    assert.notEqual(target, null, "fake-a reports its pose");
    const r = moveRequest(target);
    const effects = n.link.act(r.action, r.params);
    assert.equal(effects.filter((e) => "write" in e).length, 1);
    n.run(effects);
    await new Promise((res) => setTimeout(res, 500));
    assert.deepEqual(n.failures, []);
    assert.equal(n.link.shown("tracking.mode"), mode);
  } finally {
    n.stop();
  }
});

test("unplugging the selected unsupported device: it goes, nothing is chosen for the user", async () => {
  const n = await connected();
  try {
    n.run(n.link.pick(UNKNOWN));
    const reply = await exchange(sock + ".test", [{ unplug: UNKNOWN }], 1);
    assert.ok(reply[0].ok, JSON.stringify(reply[0]));
    await n.until(() => !n.link.store.device(UNKNOWN), 5000, "the removal");
    assert.equal(n.link.device(), null);
    await exchange(sock + ".test", [{ plug: "unknown" }], 1);
    await n.until(
      () => n.link.store.devices.some((d) => d.support === "unsupported"),
      5000,
      "the re-plug",
    );
  } finally {
    n.stop();
  }
});
