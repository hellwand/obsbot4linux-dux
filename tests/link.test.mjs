// SPDX-License-Identifier: GPL-3.0-or-later
import { eq, ok } from "./assert.mjs";
import { Link } from "../lib/link.mjs";
import { moveRequest, moveSpec, stepTarget } from "../lib/gimbal.mjs";
import { A, B, HELLO, STATES, UNKNOWN } from "./fixtures/fakes.mjs";

function linked(devices) {
  const link = new Link("obsbot4linux-dux 1.0.0");
  link.start();
  link.connected();
  const hello = Object.assign({}, HELLO, { devices: devices ?? HELLO.devices });
  link.line(JSON.stringify({ id: 1, ok: hello }));
  return link;
}

const writes = (effects) =>
  effects.filter((e) => "write" in e).map((e) => JSON.parse(e.write));

export const tests = {
  "after hello: two usable devices, none chosen; the user picks one": () => {
    const link = linked();
    ok(link.ready, "ready");
    eq(link.device(), null);
    link.pick(B.id);
    eq(link.device().model, "fake-b");
    eq(link.shown("tracking.mode"), "off");
  },
  "one usable device is chosen by itself": () => {
    eq(linked([A, UNKNOWN]).device().id, A.id);
  },
  // spec 2, 12.3: one control, one request
  "a setting control writes exactly one set request with its one leaf": () => {
    const link = linked();
    link.pick(B.id);
    const out = writes(link.set("led.brightness", 3));
    eq(out, [{ id: 2, device: B.id, set: { "led.brightness": 3 } }]);
    eq(
      [link.shown("led.brightness"), link.status("led.brightness")],
      [3, "own"],
    );
  },
  "a gimbal arrow writes exactly one gimbal.move and nothing else": () => {
    const link = linked();
    link.pick(A.id);
    const target = stepTarget(moveSpec(A), link.state().gimbal, null, 0, 5, 0);
    const req = moveRequest(target);
    const out = writes(link.act(req.action, req.params));
    eq(out, [
      { id: 2, device: A.id, do: "gimbal.move", with: { pan: 5, tilt: 0 } },
    ]);
  },
  // 4.1 rules 3 and 4: the state event comes before the reply; pending shows after the reply
  "own value until the reply, then the state's pending value": () => {
    const link = linked();
    link.pick(B.id);
    link.set("led.brightness", 3);
    const pendingState = Object.assign({}, STATES[B.id].state, {
      pending: { "led.brightness": 3 },
    });
    link.line(
      JSON.stringify({
        event: "state",
        device: B.id,
        rev: 2,
        state: pendingState,
      }),
    );
    eq(link.status("led.brightness"), "own");
    link.line('{"id":2,"ok":{"rev":2}}');
    eq(
      [link.shown("led.brightness"), link.status("led.brightness")],
      [3, "pending"],
    );
  },
  "a refused request takes back its own value and reports the error": () => {
    const link = linked();
    link.pick(B.id);
    link.set("exposure.time", 500);
    const effects = link.line(
      '{"id":2,"error":{"code":"conflict","message":"exposure.time requires exposure.mode = manual"}}',
    );
    ok(
      effects.some((e) => e.failed && e.failed.code === "conflict"),
      "failed effect",
    );
    eq(link.shown("exposure.time"), 100);
  },
  // 8.4 step 7: the selected unsupported device goes on unplug; with two usable devices left
  // nothing is chosen for the user
  "unplugging the selected unsupported device": () => {
    const link = linked();
    link.pick(UNKNOWN.id);
    link.line(JSON.stringify({ event: "devices", devices: [A, B] }));
    eq(link.device(), null);
    const one = linked([A, UNKNOWN]);
    one.pick(UNKNOWN.id);
    one.line(JSON.stringify({ event: "devices", devices: [A] }));
    eq(one.device().id, A.id);
  },
  // 4.1 Reconnect: requests and own values die with the connection
  "a lost connection forgets everything and sends nothing": () => {
    const link = linked();
    link.pick(B.id);
    link.set("led.brightness", 3);
    link.closed(1);
    eq([link.device(), link.own.size, link.problem], [null, 0, "lost"]);
    eq(link.set("led.brightness", 2), []);
  },
  // 4.1 Reconnect drops requests and own values, not the user's pick: with two usable
  // cameras the pick comes back after the next hello while its id is listed
  "the pick survives a reconnect while the device is listed": () => {
    const link = linked();
    link.pick(B.id);
    link.closed(1);
    link.retry();
    const hello = writes(link.connected());
    eq(hello.length, 1);
    link.line(JSON.stringify({ id: hello[0].id, ok: HELLO }));
    ok(link.ready, "ready again");
    eq(link.device().id, B.id);
  },
  "an empty patch and no device send nothing": () => {
    const link = linked();
    eq(link.set("led.brightness", 2), []);
    link.pick(B.id);
    eq(link.setPatch({}), []);
  },
  // 4.1 rule 7: an unknown setting of fake-b (beacon.*) does not break anything
  "fake-b's unknown group is carried and ignored": () => {
    const link = linked();
    link.pick(B.id);
    eq(link.shown("beacon.color"), "red");
    const effects = link.line(
      JSON.stringify({ event: "thermal", device: B.id }),
    );
    eq(effects, []);
  },
};
