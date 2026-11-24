// SPDX-License-Identifier: GPL-3.0-or-later
//
// lib/link.mjs over a node socket: what CameraLink.qml does with Quickshell's Socket, for the
// e2e test against a running fake daemon.

import { createConnection } from "node:net";
import { Link } from "../../lib/link.mjs";

export class NodeLink {
  constructor(path, client) {
    this.path = path;
    this.link = new Link(client);
    this.socket = null;
    this.buffer = "";
    this.timers = [];
    this.failures = [];
    this.waiters = [];
  }

  start() {
    this.run(this.link.start());
  }

  stop() {
    this.run(this.link.stop());
    this.timers.forEach(clearTimeout);
  }

  run(effects) {
    for (const e of effects) {
      if (e.connect) {
        const s = createConnection(this.path);
        this.socket = s;
        s.setEncoding("utf8");
        s.on("connect", () => this.run(this.link.connected()));
        s.on("data", (chunk) => {
          this.buffer += chunk;
          let i;
          while ((i = this.buffer.indexOf("\n")) >= 0) {
            const line = this.buffer.slice(0, i);
            this.buffer = this.buffer.slice(i + 1);
            this.run(this.link.line(line));
          }
        });
        s.on("error", (err) =>
          this.run(
            this.link.closed(
              err.code === "ENOENT" ? 2 : err.code === "ECONNREFUSED" ? 0 : 1,
            ),
          ),
        );
        s.on("close", () => this.run(this.link.closed(undefined)));
      } else if (e.close) {
        this.socket?.destroy();
      } else if (e.write !== undefined) {
        this.socket.write(e.write);
      } else if (e.retryIn !== undefined && e.retryIn >= 0) {
        this.timers.push(
          setTimeout(() => this.run(this.link.retry()), e.retryIn),
        );
      } else if (e.failed) {
        this.failures.push(e.failed);
      }
    }
    this.waiters = this.waiters.filter((w) => !w());
  }

  // Resolves once check() is true after an effect, rejects after ms.
  until(check, ms, what) {
    return new Promise((resolve, reject) => {
      if (check()) return resolve();
      const timer = setTimeout(() => reject(new Error(`timeout: ${what}`)), ms);
      this.waiters.push(() => {
        if (!check()) return false;
        clearTimeout(timer);
        resolve();
        return true;
      });
    });
  }
}

// One line on a socket (the test-control socket, or a second client like the CLI); resolves
// with the lines received until `count` arrived.
export function exchange(path, lines, count) {
  return new Promise((resolve, reject) => {
    const s = createConnection(path);
    let buffer = "";
    const got = [];
    s.setEncoding("utf8");
    s.on("connect", () =>
      s.write(lines.map((l) => JSON.stringify(l) + "\n").join("")),
    );
    s.on("data", (chunk) => {
      buffer += chunk;
      let i;
      while ((i = buffer.indexOf("\n")) >= 0) {
        got.push(JSON.parse(buffer.slice(0, i)));
        buffer = buffer.slice(i + 1);
      }
      if (got.length >= count) {
        s.destroy();
        resolve(got);
      }
    });
    s.on("error", reject);
    setTimeout(() => {
      s.destroy();
      reject(new Error(`no answer on ${path}`));
    }, 10000);
  });
}
