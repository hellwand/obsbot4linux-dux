// SPDX-License-Identifier: GPL-3.0-or-later
import { eq, ok } from "./assert.mjs";
import {
  BACKOFF_FIRST,
  BACKOFF_MAX,
  HELLO_TIMEOUT,
  Session,
} from "../lib/session.mjs";

const HELLO_OK =
  '{"id":1,"ok":{"protocol":2,"daemon":"1.0.0","devices":[],"states":{}}}';

function ready() {
  const s = new Session("obsbot4linux-dux 1.0.0");
  s.start();
  s.connected();
  s.line(HELLO_OK);
  return s;
}

const kinds = (effects) => effects.map((e) => Object.keys(e)[0]);

export const tests = {
  // 4.1: the first message on a connection is hello, with subscribe:true
  "hello goes first, with the client name and the live list": () => {
    const s = new Session("obsbot4linux-dux 1.0.0");
    eq(s.start(), [{ connect: true }]);
    s.setLive(["pose"]);
    const effects = s.connected();
    eq(JSON.parse(effects[0].write), {
      id: 1,
      hello: {
        protocol: 2,
        client: "obsbot4linux-dux 1.0.0",
        subscribe: true,
        live: ["pose"],
      },
    });
    eq(effects[1], { helloTimeoutIn: HELLO_TIMEOUT });
  },
  "the hello reply makes the session ready": () => {
    const s = new Session("c");
    s.start();
    s.connected();
    const effects = s.line(HELLO_OK);
    eq(kinds(effects), ["ready"]);
    eq(s.phase, "ready");
  },
  // 4.1 Reconnect: 0.5 s, doubling, at most 5 s; reset once a hello succeeded
  "the backoff doubles from 0.5 s to 5 s and resets when ready": () => {
    const s = new Session("c");
    const waits = [];
    for (let i = 0; i < 6; i++) {
      s.start();
      waits.push(s.closed(2).find((e) => "retryIn" in e).retryIn);
    }
    eq(waits, [BACKOFF_FIRST, 1000, 2000, 4000, BACKOFF_MAX, BACKOFF_MAX]);
    s.start();
    s.connected();
    s.line(HELLO_OK);
    eq(s.backoff, BACKOFF_FIRST);
  },
  // 5.10: no socket file or connection refused: the systemctl hint
  "no daemon listening is unreachable": () => {
    const s = new Session("c");
    s.start();
    const effects = s.closed(0);
    ok(
      effects.some((e) => e.problem === "unreachable"),
      "unreachable",
    );
    eq(s.phase, "waiting");
  },
  "a connection that closes after hello is lost, and own values go": () => {
    const s = ready();
    const effects = s.closed(1);
    eq(kinds(effects), ["close", "lost", "problem", "retryIn"]);
    eq(s.problem, "lost");
  },
  "an older daemon is reported and retried at the slowest pace": () => {
    const s = new Session("c");
    s.start();
    s.connected();
    const effects = s.line('{"id":1,"ok":false,"error":"unknown command"}');
    ok(
      effects.some((e) => e.problem === "old"),
      "old",
    );
    ok(
      effects.some((e) => e.retryIn === BACKOFF_MAX),
      "5 s",
    );
  },
  "no hello reply within the client timeout is a lost daemon": () => {
    const s = new Session("c");
    s.start();
    s.connected();
    ok(
      s.helloTimeout().some((e) => e.problem === "lost"),
      "lost",
    );
    eq(ready().helloTimeout(), []);
  },
  // Requests die with their connection (4.1): nothing is queued while not ready
  "a request while not ready sends nothing": () => {
    const s = new Session("c");
    eq(
      s.request((id) => ({ id, live: [] })),
      { id: null, effects: [] },
    );
  },
  "request ids count up after the hello id": () => {
    const s = ready();
    eq(s.request((id) => ({ id, live: [] })).id, 2);
    eq(s.request((id) => ({ id, live: [] })).id, 3);
  },
  "events before the hello reply are ignored; replies and events pass when ready":
    () => {
      const s = new Session("c");
      s.start();
      s.connected();
      eq(s.line('{"event":"state","state":{}}'), []);
      s.line(HELLO_OK);
      eq(kinds(s.line('{"event":"devices","devices":[]}')), ["event"]);
      eq(kinds(s.line('{"id":2,"ok":{"rev":3}}')), ["reply"]);
      eq(s.line("not json"), []);
    },
  "the live list is sent only when it changes, and kept for the next hello":
    () => {
      const s = ready();
      eq(JSON.parse(s.setLive(["target", "pose", "pose"])[0].write).live, [
        "pose",
        "target",
      ]);
      eq(s.setLive(["pose", "target"]), []);
      s.closed(1);
      s.start();
      eq(JSON.parse(s.connected()[0].write).hello.live, ["pose", "target"]);
    },
  "stop closes an open connection and cancels a retry": () => {
    eq(kinds(ready().stop()), ["retryIn", "close", "lost"]);
    const s = new Session("c");
    s.start();
    s.closed(2);
    eq(s.stop(), [{ retryIn: -1 }]);
    eq(s.closed(1), []);
  },
};
