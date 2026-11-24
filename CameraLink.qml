import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import "lib/link.mjs" as LinkModule
import "lib/describe.mjs" as Describe
import "lib/devices.mjs" as Devices
import "lib/protocol.mjs" as Protocol
import "lib/values.mjs" as Values

// The link of one widget instance (bar widget, Control Center tile, desktop widget) to the
// obsbot4linux daemon: protocol 2 on its Unix socket. All logic is in lib/link.mjs and the
// modules it uses; this component only carries out the I/O they ask for (the socket, two
// timers) and tells the bindings when something changed (`revision`).
//
// Controls read through the functions below and send through set(), setPatch() and act(): each
// of these sends exactly one request (spec 2, 12.3).
Item {
    id: root

    // false: no connection (the throw-away instance DMS creates to read ccWidgetIcon; the lock
    // screen; the desktop editor)
    property bool active: false
    // For the log, e.g. "bar widget on screen DP-1"
    property string instanceName: ""
    // The client name in hello (protocol 2, 4.1)
    property string client: "obsbot4linux-dux"
    // What the owner shows now; decides the live topics (only while the popout is open, 10.3 D)
    property var liveView: ({
            open: false,
            pose: false,
            target: false,
            auto: false
        })

    // Goes up on every change of devices, states, own values or the selection
    property int revision: 0
    property var link: null

    readonly property string socketPath: Protocol.socketPath(name => Quickshell.env(name) ?? "")
    readonly property bool ready: revision >= 0 && link !== null && link.ready
    // "" while ready or idle, else "unreachable", "old", "protocol" or "lost" (lib/session.mjs)
    readonly property string problem: revision >= 0 && link !== null ? link.problem : ""
    readonly property var devices: revision >= 0 && link !== null ? link.store.devices : []
    readonly property var device: revision >= 0 && link !== null ? link.device() : null
    readonly property var camState: revision >= 0 && link !== null ? link.state() : null
    readonly property string deviceId: device !== null ? device.id : ""
    readonly property bool available: device !== null && device.available === true
    readonly property bool usable: device !== null && Devices.usable(device)
    // Some listed device is usable, selected or not ("Hide without camera")
    readonly property bool anyUsable: Devices.anyUsable(devices)
    readonly property bool awake: usable && camState !== null && camState.asleep !== true
    readonly property string marker: device !== null ? Devices.marker(device) : ""
    readonly property string unsupportedHint: device !== null && device.support === "unsupported" ? Devices.unsupportedHint(device) : ""
    readonly property var wantedTopics: Describe.wantedTopics(device, liveView)

    // A request of ours was refused; a toast shows it too
    signal failed(var id, string code, string message)

    function has(path) {
        return revision >= 0 && Describe.has(device, path);
    }
    function setting(path) {
        return revision >= 0 ? Describe.setting(device, path) : null;
    }
    function value(path) {
        return revision >= 0 && link !== null ? link.shown(path) : null;
    }
    // "own", "pending", "unread" or "camera" (lib/values.mjs)
    function status(path) {
        return revision >= 0 && link !== null ? link.status(path) : "unread";
    }
    function choices(path, labels) {
        return revision >= 0 ? Describe.choices(device, path, labels) : [];
    }
    // Bounds of a leaf, or of one component of it ("min", "pan", …)
    function spec(path, component) {
        return revision >= 0 ? Describe.numberSpec(Describe.setting(device, path), component) : null;
    }
    // Bounds of a parameter of an action
    function paramSpec(action, param, component) {
        const a = revision >= 0 ? Describe.action(device, action) : null;
        return a && a.params && a.params[param] ? Describe.numberSpec(a.params[param], component) : null;
    }
    // null when the control can be used now, else { reason, needs? } (lib/describe.mjs)
    function blocked(path) {
        return revision >= 0 ? Describe.blocked(device, camState, path) : ({
                reason: "unavailable"
            });
    }
    function warnings(path) {
        return revision >= 0 ? Describe.warnings(device, path) : [];
    }
    // The defaults reset of these leaves as one patch, or null (lib/values.mjs defaults)
    function defaultsPatch(paths) {
        return revision >= 0 && link !== null ? Values.defaults(device, camState, link.own, paths) : null;
    }
    function limit(path) {
        return revision >= 0 ? Describe.limit(device, path) : null;
    }

    function set(path, value) {
        run(link.set(path, value));
    }
    function setPatch(patch) {
        run(link.setPatch(patch));
    }
    function act(name, params) {
        run(link.act(name, params));
    }
    function pick(id) {
        run(link.pick(id));
    }
    // Retry button: connect again now
    function retry() {
        if (link !== null && active) {
            retryTimer.stop();
            run(link.retry());
        }
    }

    function log(text) {
        console.info("obsbot4linuxDux (" + instanceName + "): " + text);
    }

    // Carries out the effects of lib/link.mjs, in order
    function run(effects) {
        for (const e of effects) {
            if (e.connect) {
                socket.path = root.socketPath;
                socket.connected = true;
            } else if (e.close) {
                socket.connected = false;
            } else if (e.write !== undefined) {
                socket.write(e.write);
                socket.flush();
            } else if (e.retryIn !== undefined) {
                if (e.retryIn < 0) {
                    retryTimer.stop();
                } else {
                    retryTimer.interval = e.retryIn;
                    retryTimer.restart();
                }
            } else if (e.helloTimeoutIn !== undefined) {
                helloTimer.interval = e.helloTimeoutIn;
                helloTimer.restart();
            } else if (e.changed) {
                root.revision += 1;
            } else if (e.failed) {
                root.log("refused: " + e.failed.code + ": " + e.failed.message);
                ToastService.showError("OBSBOT Control: " + e.failed.message, "");
                root.failed(e.failed.id, e.failed.code, e.failed.message);
            } else if (e.problem !== undefined) {
                root.log("daemon " + e.problem + (root.socketPath !== "" ? " at " + root.socketPath : ""));
            }
        }
    }

    onWantedTopicsChanged: {
        if (link !== null)
            run(link.setLive(wantedTopics));
    }
    onActiveChanged: {
        if (link !== null)
            run(active ? link.start() : link.stop());
    }
    Component.onCompleted: {
        link = new LinkModule.Link(client);
        if (active)
            run(link.start());
    }
    Component.onDestruction: {
        if (link !== null)
            run(link.stop());
    }

    Timer {
        id: retryTimer
        onTriggered: root.run(root.link.retry())
    }

    Timer {
        id: helloTimer
        onTriggered: root.run(root.link.helloTimeout())
    }

    Socket {
        id: socket
        parser: SplitParser {
            onRead: line => root.run(root.link.line(line))
        }
        onConnectionStateChanged: root.run(connected ? root.link.connected() : root.link.closed(undefined))
        // Before a connection exists: no socket file or refused (the systemctl hint). While
        // connected, the close that follows reports it.
        onError: error => {
            if (!connected)
                root.run(root.link.closed(error));
        }
    }
}
