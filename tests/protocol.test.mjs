// SPDX-License-Identifier: GPL-3.0-or-later
import { eq, ok } from "./assert.mjs";
import {
  act,
  encode,
  ERROR_CODES,
  hello,
  helloOutcome,
  live,
  parse,
  setLeaves,
  socketPath,
} from "../lib/protocol.mjs";
import session from "./fixtures/session.transcript.mjs";
import errors from "./fixtures/errors.transcript.mjs";

const env = (vars) => (name) => vars[name];

export const tests = {
  // 4.1: OBSBOT4LINUX_SOCKET overrides the path; the default is in XDG_RUNTIME_DIR
  "the socket path follows the environment": () => {
    eq(
      socketPath(env({ XDG_RUNTIME_DIR: "/run/user/1000" })),
      "/run/user/1000/obsbot4linux.sock",
    );
    eq(
      socketPath(
        env({
          XDG_RUNTIME_DIR: "/run/user/1000",
          OBSBOT4LINUX_SOCKET: "/tmp/t.sock",
        }),
      ),
      "/tmp/t.sock",
    );
    eq(socketPath(env({ OBSBOT4LINUX_SOCKET: "" })), "");
    eq(socketPath(env({})), "");
  },
  // The requests the widget writes are the golden transcript's lines, byte for byte
  "requests are written as the golden transcript writes them": () => {
    const sent = session
      .filter((m) => m.from === "client")
      .map((m) => JSON.stringify(m.msg));
    eq(JSON.stringify(hello(1, "widget 1.0", ["pose"])), sent[0]);
    eq(
      JSON.stringify(
        setLeaves(2, "sn:EXAMPLE0000001", { "led.brightness": 2 }),
      ),
      sent[1],
    );
    eq(
      JSON.stringify(act(4, "sn:EXAMPLE0000001", "preset.recall", { slot: 0 })),
      sent[3],
    );
    eq(JSON.stringify(live(5, ["pose", "target"])), sent[4]);
  },
  "an action without parameters has no with": () => {
    eq(act(6, "sn:X", "gimbal.stop", {}), {
      id: 6,
      device: "sn:X",
      do: "gimbal.stop",
    });
    eq(act(6, "sn:X", "gimbal.stop", undefined), {
      id: 6,
      device: "sn:X",
      do: "gimbal.stop",
    });
  },
  "a request is one line": () => {
    const line = encode(
      setLeaves(3, "sn:X", { "zone.area.pan": { min: -20, max: 20 } }),
    );
    ok(
      line.endsWith("\n") && line.indexOf("\n") === line.length - 1,
      "one newline, at the end",
    );
  },
  "every golden daemon line parses as a reply, an error or an event": () => {
    for (const m of session.concat(errors).filter((x) => x.from === "daemon")) {
      const p = parse(JSON.stringify(m.msg));
      ok(
        p.kind === "reply" || p.kind === "error" || p.kind === "event",
        `kind of ${JSON.stringify(m.msg)}`,
      );
    }
  },
  "each error code of the golden file keeps its code": () => {
    const codes = errors
      .filter((x) => x.from === "daemon")
      .map((m) => parse(JSON.stringify(m.msg)).code);
    eq(codes, ERROR_CODES);
  },
  // 4.1 rule 7: an unknown error code is treated as internal; unknown events are passed on
  "an unknown error code reads as internal": () => {
    const p = parse(
      '{"id":3,"error":{"code":"rate_limited","message":"slow down"}}',
    );
    eq([p.kind, p.code, p.message], ["error", "internal", "slow down"]);
  },
  "an unknown event type is an event, not an error": () => {
    eq(parse('{"event":"thermal","device":"sn:X"}').kind, "event");
  },
  "unknown fields are ignored": () => {
    eq(parse('{"id":4,"ok":{"rev":6},"trace":"abc"}'), {
      kind: "reply",
      id: 4,
      ok: { rev: 6 },
    });
  },
  "junk is bad, never a throw": () => {
    for (const line of [
      "",
      "{",
      "[]",
      "null",
      '"text"',
      '{"ok":{}}',
      '{"id":1,"ok":[]}',
    ])
      eq(parse(line).kind, "bad", line);
  },
  // 5.10: a 0.13 daemon answers hello with ok:false and a string error
  "a 0.13 daemon's answer to hello is an older daemon": () => {
    eq(
      helloOutcome(parse('{"id":1,"ok":false,"error":"unknown command"}')),
      "old",
    );
    eq(
      helloOutcome(
        parse(
          '{"id":null,"error":{"code":"protocol","message":"x","supported":[3]}}',
        ),
      ),
      "protocol",
    );
    const golden = session.find((m) => m.from === "daemon").msg;
    eq(helloOutcome(parse(JSON.stringify(golden))), "ok");
  },
};
