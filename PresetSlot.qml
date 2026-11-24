import QtQuick
import qs.Common
import qs.DCommon.Common
import qs.DCommon.Widgets

// One of the camera's preset slots in the desktop widget's bottom row: a recall button with the
// preset's name ("(unnamed)" for a preset without one, display only; the full name as tooltip),
// disabled while the slot is empty so the other slots keep their place. All slots share the
// secondary container colour and none is highlighted: the camera cannot report which preset is
// active.
//
// link is the CameraLink, row one entry of Lists.presetRows.
Item {
    id: slot

    property var link
    property var row

    DButton {
        anchors.verticalCenter: parent.verticalCenter
        width: slot.width
        buttonHeight: Style.buttonHeightS
        minimumWidth: 0
        maximumWidth: slot.width
        enabled: slot.row.used
        text: slot.row.used ? slot.row.label : "Slot " + (slot.row.slot + 1)
        tooltipText: slot.row.used ? slot.row.label : ""
        backgroundColor: Theme.secondaryContainer
        textColor: Theme.onSecondaryContainer
        onClicked: slot.link.act("preset.recall", {
            slot: slot.row.slot
        })
    }
}
