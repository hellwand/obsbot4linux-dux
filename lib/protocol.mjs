// SPDX-License-Identifier: GPL-3.0-or-later
//
// Protocol 2 of obsbot4linux as the widget speaks it (the tool's docs/protocol-2.md): the
// socket path, the request lines and the parsing of what the daemon sends. No state here.

export const PROTOCOL = 2;

// The daemon's error codes (protocol 2, 4.1). Another code is read as "internal" (rule 7).
export const ERROR_CODES = [
  "protocol",
  "invalid",
  "unknown_device",
  "unsupported",
  "unsupported_device",
  "out_of_range",
  "conflict",
  "unavailable",
  "asleep",
  "busy",
  "camera",
  "internal",
];

// $OBSBOT4LINUX_SOCKET, else $XDG_RUNTIME_DIR/obsbot4linux.sock; "" when neither is set.
// env: name -> value, "" for an unset variable (Quickshell.env returns undefined for it).
export function socketPath(env) {
  const own = env("OBSBOT4LINUX_SOCKET") ?? "";
  if (own !== "") return own;
  const runtime = env("XDG_RUNTIME_DIR") ?? "";
  return runtime !== "" ? `${runtime}/obsbot4linux.sock` : "";
}

// One request object as one line for the socket.
export function encode(request) {
  return JSON.stringify(request) + "\n";
}

export function hello(id, client, live) {
  return {
    id,
    hello: { protocol: PROTOCOL, client, subscribe: true, live: live.slice() },
  };
}

export function setLeaves(id, device, patch) {
  return { id, device, set: Object.assign({}, patch) };
}

export function act(id, device, action, params) {
  const request = { id, device, do: action };
  if (params && Object.keys(params).length > 0)
    request.with = Object.assign({}, params);
  return request;
}

export function live(id, topics) {
  return { id, live: topics.slice() };
}

// One line from the daemon:
//   { kind: "reply", id, ok }                   ok: the reply's payload object
//   { kind: "error", id, code, message, body }  code: one of ERROR_CODES ("internal" for others)
//   { kind: "event", event, body }              event: "state", "devices" or a newer name
//   { kind: "bad", text }                       not a protocol-2 object (a 0.13 daemon's reply
//                                               {"ok":false,"error":"…"} included)
export function parse(line) {
  let msg;
  try {
    msg = JSON.parse(line);
  } catch (e) {
    return { kind: "bad", text: String(line) };
  }
  if (msg === null || typeof msg !== "object" || Array.isArray(msg))
    return { kind: "bad", text: String(line) };
  if (typeof msg.event === "string")
    return { kind: "event", event: msg.event, body: msg };
  if (!("id" in msg)) return { kind: "bad", text: String(line) };
  if (msg.ok !== null && typeof msg.ok === "object" && !Array.isArray(msg.ok))
    return { kind: "reply", id: msg.id, ok: msg.ok };
  if (
    msg.error !== null &&
    typeof msg.error === "object" &&
    typeof msg.error.code === "string"
  ) {
    const code = ERROR_CODES.includes(msg.error.code)
      ? msg.error.code
      : "internal";
    return {
      kind: "error",
      id: msg.id,
      code,
      message: String(msg.error.message ?? ""),
      body: msg.error,
    };
  }
  return { kind: "bad", text: String(line) };
}

// The answer to our hello: "ok" (protocol 2), "protocol" (the daemon speaks another protocol:
// its error lists the ones it does), "old" (a daemon older than 1.0: its reply is no protocol-2
// object, 5.10).
export function helloOutcome(parsed) {
  if (
    parsed.kind === "reply" &&
    parsed.ok.protocol === PROTOCOL &&
    Array.isArray(parsed.ok.devices)
  )
    return "ok";
  if (parsed.kind === "error" && parsed.code === "protocol") return "protocol";
  return "old";
}
