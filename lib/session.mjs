// SPDX-License-Identifier: GPL-3.0-or-later
//
// One connection to the daemon as a state machine, without I/O: the QML side (CameraLink.qml)
// feeds it what the socket did and carries out the effects it returns. Protocol 2, 4.1
// "Reconnect": a backoff from 0.5 s doubling up to 5 s; after any reconnect every request in
// flight is dropped and the client rebuilds from the hello reply.
//
// Effects, in the order to carry them out:
//   { connect: true }          open the socket
//   { close: true }            close the socket
//   { write: "<line>\n" }      write the line and flush
//   { retryIn: ms }            call retry() after ms (one timer; a new one replaces the old)
//   { helloTimeoutIn: ms }     call helloTimeout() after ms, unless ready() came first
//   { ready: <hello ok> }      the hello reply: rebuild devices and states from it
//   { reply: <parsed> }        a reply or error to a request of ours (protocol.parse shape)
//   { event: <parsed> }        an event (protocol.parse shape)
//   { lost: true }             the connection is gone: drop own values and requests in flight
//   { problem: "<kind>" }      what the UI shows while not ready: "unreachable" (no socket file
//                              or refused: the systemctl hint), "old" (a daemon older than 1.0),
//                              "protocol" (another protocol), "lost" (closed or no hello reply)

import {
  encode,
  hello,
  helloOutcome,
  live as liveRequest,
  parse,
} from "./protocol.mjs";

export const BACKOFF_FIRST = 500;
export const BACKOFF_MAX = 5000;
// CLIENT_REPLY_TIMEOUT of protocol 2 (5.8): no hello reply within it is a lost daemon
export const HELLO_TIMEOUT = 30000;

// QLocalSocket::LocalSocketError values that mean "no daemon listens"
const UNREACHABLE = [0, 2]; // ConnectionRefusedError, ServerNotFoundError

export class Session {
  constructor(client) {
    this.client = client;
    this.phase = "idle"; // idle | connecting | hello | ready | waiting
    this.problem = "";
    this.backoff = BACKOFF_FIRST;
    this.nextId = 1;
    this.helloId = 0;
    this.topics = [];
  }

  start() {
    if (this.phase !== "idle" && this.phase !== "waiting") return [];
    this.phase = "connecting";
    return [{ connect: true }];
  }

  // The socket is connected: hello goes first (4.1).
  connected() {
    this.phase = "hello";
    this.helloId = this.nextId++;
    return [
      { write: encode(hello(this.helloId, this.client, this.topics)) },
      { helloTimeoutIn: HELLO_TIMEOUT },
    ];
  }

  // One line from the socket.
  line(text) {
    const parsed = parse(text);
    if (this.phase === "hello") {
      if (parsed.kind === "event") return [];
      const ours =
        parsed.kind === "bad" ||
        parsed.id === this.helloId ||
        parsed.id === null;
      if (!ours) return [];
      const outcome = helloOutcome(parsed);
      if (outcome === "ok") {
        this.phase = "ready";
        this.problem = "";
        this.backoff = BACKOFF_FIRST;
        return [{ ready: parsed.ok }];
      }
      return this.fail(outcome, BACKOFF_MAX);
    }
    if (this.phase !== "ready") return [];
    if (parsed.kind === "event") return [{ event: parsed }];
    if (parsed.kind === "reply" || parsed.kind === "error")
      return [{ reply: parsed }];
    return [];
  }

  // The socket closed, or failed to connect (error: a QLocalSocket::LocalSocketError value,
  // undefined for a plain close).
  closed(error) {
    if (this.phase === "idle" || this.phase === "waiting") return [];
    const unreachable =
      this.phase === "connecting" && UNREACHABLE.includes(error);
    return this.fail(unreachable ? "unreachable" : "lost", this.backoff);
  }

  helloTimeout() {
    return this.phase === "hello" ? this.fail("lost", this.backoff) : [];
  }

  retry() {
    return this.start();
  }

  // Stop for good (the widget instance goes away or is switched off).
  stop() {
    const open = this.phase !== "idle" && this.phase !== "waiting";
    this.phase = "idle";
    this.problem = "";
    this.backoff = BACKOFF_FIRST;
    // retryIn -1: cancel a pending retry
    return open
      ? [{ retryIn: -1 }, { close: true }, { lost: true }]
      : [{ retryIn: -1 }];
  }

  // A request object without its id; returns { id, effects }. Not ready: no id, nothing sent
  // (requests die with their connection, 4.1).
  request(build) {
    if (this.phase !== "ready") return { id: null, effects: [] };
    const id = this.nextId++;
    return { id, effects: [{ write: encode(build(id)) }] };
  }

  // The live topics this connection wants (4.1 rule 8). Sent when ready and changed; kept
  // for the next hello either way.
  setLive(topics) {
    const next = Array.from(new Set(topics)).sort();
    if (next.join("\n") === this.topics.join("\n")) return [];
    this.topics = next;
    if (this.phase !== "ready") return [];
    return [{ write: encode(liveRequest(this.nextId++, next)) }];
  }

  fail(problem, wait) {
    const wasOpen =
      this.phase === "hello" ||
      this.phase === "ready" ||
      this.phase === "connecting";
    this.phase = "waiting";
    this.problem = problem;
    const effects = [];
    if (wasOpen) effects.push({ close: true });
    effects.push({ lost: true }, { problem }, { retryIn: wait });
    this.backoff = Math.min(this.backoff * 2, BACKOFF_MAX);
    return effects;
  }
}
