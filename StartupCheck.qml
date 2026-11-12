import QtQuick
import qs.Common

// Dependency gate: the plugin only activates when obsbot4linux is installed, new enough and
// older than 1.0 (0.3.1 detects streaming in the kernel driver, so every app counts; 0.5.0 reads
// the zone settings from the camera and sets the zone return position for real; 0.7.1 reports the
// gimbal and zone ranges as `limits` and stops tilt above the camera's sleep threshold; 0.7.3
// fixes zone tracking ending in Static, so "Follow new targets" works). obsbot4linux 1.0 and
// newer speak a new protocol that this 0.x widget does not know, so they need widget 1.0 or newer.
// The camera itself is not required, the widget copes with it being unplugged.
QtObject {
    readonly property var minVersion: [0, 7, 3]
    // exclusive upper bound
    readonly property var maxVersion: [1, 0, 0]
    readonly property string releases: "https://github.com/hellwand/obsbot4linux/releases"

    // "obsbot4linux 0.2.0" -> [0, 2, 0]; null when there is no version in the text
    function parseVersion(text) {
        const m = /(\d+)\.(\d+)\.(\d+)/.exec(text);
        return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : null;
    }

    function isOlder(version, minimum) {
        for (let i = 0; i < 3; i++) {
            if (version[i] !== minimum[i])
                return version[i] < minimum[i];
        }
        return false;
    }

    function check(done) {
        Proc.runCommand("obsbot4linuxDux.depCheck", ["sh", "-c", "command -v obsbot4linux >/dev/null && obsbot4linux --version"], (stdout, exitCode) => {
            const minimum = minVersion.join(".");
            if (exitCode !== 0) {
                done({
                    "title": "obsbot4linux is required",
                    "details": "The 'obsbot4linux' tool is not installed or not on your PATH. This plugin needs obsbot4linux " + minimum + " or newer.\n\nInstall it from " + releases + " (packages for Arch, Debian/Ubuntu, Fedora/openSUSE and a tarball), then enable this plugin again."
                });
                return;
            }
            const version = parseVersion(stdout);
            if (version && !isOlder(version, minVersion) && isOlder(version, maxVersion)) {
                done(null);
                return;
            }
            if (version && !isOlder(version, maxVersion)) {
                done({
                    "title": "obsbot4linux " + maxVersion[0] + ".0 or newer needs a newer widget",
                    "details": "Installed: " + stdout.trim() + ". This widget version works with obsbot4linux " + minimum + " or newer but older than " + maxVersion[0] + ".0, because obsbot4linux " + maxVersion[0] + ".0 and newer speak a new protocol.\n\nInstall widget " + maxVersion[0] + ".0 or newer, then enable this plugin again."
                });
                return;
            }
            done({
                "title": "obsbot4linux " + minimum + " or newer is required",
                "details": "Installed: " + stdout.trim() + ". This plugin needs obsbot4linux " + minimum + " or newer, which fixes zone tracking ending in Static.\n\nUpdate it from " + releases + ", then enable this plugin again."
            });
        });
    }
}
