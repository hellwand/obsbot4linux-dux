import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Right column of the desktop widget card, as high as the picture: camera picker, status line with
// the on-air dot, tracking mode chips and tracking speed chips. It has no background; the controls
// grey out (not hide) when the camera is asleep or offline.
//
// ctl is the DesktopPreview: link, labels(), available, live, problem, streaming, modeText.
// interactive: false ignores the chips (desktop edit mode).
Item {
    id: side

    property var ctl
    property bool interactive: true

    readonly property string title: !ctl.available ? "Offline" : ctl.live ? "Awake" : "Asleep"
    readonly property string subtitle: {
        if (ctl.available)
            return ctl.live ? ctl.modeText : "Lens stowed";
        if (ctl.problem !== null)
            return ctl.problem.body;
        if (ctl.link.device === null)
            return ctl.link.devices.length > 0 ? "Pick a camera" : "No camera";
        return ctl.link.device.support === "unsupported" ? "Not supported by obsbot4linux" : "Camera not connected";
    }

    // The choices the description lists, as the chips show them
    readonly property var modeLabels: ctl.link.choices("tracking.mode", ctl.labels("tracking.mode")).map(c => c.label)
    readonly property var speedLabels: ctl.link.choices("tracking.profile", ctl.labels("tracking.profile")).map(c => c.label)

    // Width the column needs: the widest pair of neighbouring mode chips side by side, and the widest
    // single speed chip. Measured from real chips (the hidden DFilterChips below lay out in one
    // row), so it follows the font, the theme and the camera's choices. The owner sizes the column
    // to this, the chips wrap in it. Without a camera there is nothing to measure: the column keeps
    // a floor for the picker and the status text (the same width the Framing card gives its side column).
    readonly property real naturalWidth: {
        const spacing = measureModes.spacing;
        // the Repeater is a child too, with no width
        const modes = Array.from(measureModes.children).filter(c => c.width > 0);
        const speeds = Array.from(measureSpeeds.children).filter(c => c.width > 0);
        let widest = Theme.spacingXL * 6;
        for (let i = 0; i < side.modeLabels.length; i += 2) {
            const a = modes[i]?.width ?? 0;
            const b = modes[i + 1]?.width ?? 0;
            widest = Math.max(widest, a + (b > 0 ? spacing + b : 0));
        }
        for (let i = 0; i < side.speedLabels.length; i++)
            widest = Math.max(widest, speeds[i]?.width ?? 0);
        return Math.ceil(widest);
    }

    DFilterChips {
        id: measureModes
        visible: false
        width: 100000
        showCheck: false
        model: side.modeLabels
    }

    DFilterChips {
        id: measureSpeeds
        visible: false
        width: 100000
        showCheck: false
        model: side.speedLabels
    }

    Column {
        width: parent.width
        spacing: Theme.spacingM

        DevicePicker {
            width: parent.width
            link: side.ctl.link
        }

        Item {
            id: statusItem
            width: parent.width
            height: statusText.implicitHeight

            Column {
                id: statusText
                anchors.left: parent.left
                anchors.right: airRow.visible ? airRow.left : parent.right
                anchors.rightMargin: Theme.spacingS

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: side.title
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                }

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: side.subtitle
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            // Any application reads the camera, the widget's own preview included
            Row {
                id: airRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS
                visible: side.ctl.available && side.ctl.streaming

                Rectangle {
                    width: Theme.spacingM
                    height: width
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.error
                }

                StyledText {
                    text: "On air"
                    color: Theme.error
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }
            }
        }

        SettingChips {
            width: parent.width
            stacked: true
            link: side.ctl.link
            path: "tracking.mode"
            text: "Tracking mode"
            labels: side.ctl.labels("tracking.mode")
            enabled: block === null && side.interactive
        }

        SettingChips {
            width: parent.width
            stacked: true
            link: side.ctl.link
            path: "tracking.profile"
            text: "Tracking speed"
            labels: side.ctl.labels("tracking.profile")
            enabled: block === null && side.interactive
        }
    }
}
