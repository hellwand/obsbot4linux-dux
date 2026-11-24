import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "lib/devices.mjs" as Devices

// The cameras the daemon lists, one chip each, with the marks "untested" and "unsupported" and
// "unplugged". Picking a chip only chooses which camera the widget shows: no request goes out.
// An unsupported camera shows no controls, only the hint to report it (spec 8.4 step 3).
Item {
    id: picker

    property var link

    readonly property var devices: link.devices
    readonly property bool listed: devices.length > 0

    visible: devices.length > 1 || (devices.length === 1 && (link.device === null || link.marker !== ""))
    implicitHeight: column.height

    function chipText(device) {
        const mark = Devices.marker(device);
        return device.name + (mark !== "" ? " · " + mark : "") + (device.available !== true ? " · unplugged" : "");
    }

    Column {
        id: column
        width: parent.width
        spacing: Theme.spacingS

        ChipRow {
            id: chips
            width: parent.width
            stacked: true
            label: "Camera"
            options: picker.devices.map(d => picker.chipText(d))
            currentIndex: picker.devices.findIndex(d => d.id === picker.link.deviceId)
            onSelected: index => {
                const d = picker.devices[index];
                if (d)
                    picker.link.pick(d.id);
                chips.sync();
            }
        }

        TextEdit {
            width: parent.width
            visible: picker.link.unsupportedHint !== ""
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            text: picker.link.unsupportedHint
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
        }

        StyledText {
            width: parent.width
            visible: picker.link.device === null && picker.listed
            wrapMode: Text.Wrap
            text: "Pick a camera to control."
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
