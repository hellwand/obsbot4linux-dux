import QtQuick
import qs.Common
import "lib/version.mjs" as Version

// Dependency gate: the plugin activates only with obsbot4linux 1.0 or newer, which speaks
// protocol 2 on its socket. A release candidate of 1.0.0 counts as 1.0.0. The camera itself is
// not required.
QtObject {
    readonly property var minVersion: [1, 0, 0]
    readonly property var links: ({
            releases: "https://github.com/hellwand/obsbot4linux/releases",
            widgetReleases: "https://github.com/hellwand/obsbot4linux-dux/releases"
        })

    function check(done) {
        // The command can answer after this object is gone (the widget was created twice in a
        // row); the callback then must not read the object, so it works on copies only.
        const minV = minVersion;
        const urls = links;
        const checkTool = Version.checkTool;
        Proc.runCommand("obsbot4linuxDux.depCheck", ["sh", "-c", "command -v obsbot4linux >/dev/null && obsbot4linux --version"], (stdout, exitCode) => done(checkTool(stdout, exitCode, minV, null, urls)));
    }
}
