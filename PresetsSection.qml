import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "lib/lists.mjs" as Lists

// The camera's preset slots: recall, save the current pose, rename, delete. The slots come from
// the description and the list from the camera's state. Saving sends no name; a preset without a
// name shows "(unnamed)" here only.
SectionCard {
    id: section

    property var ctl

    readonly property var rows: Lists.presetRows(ctl.link.device, ctl.link.camState)
    // Slot being renamed / asked to delete, -1 = none; only one row at a time
    property int renaming: -1
    property int deleting: -1
    readonly property bool zoneReturnArmed: ctl.link.value("zone.enabled") === true && ctl.link.value("zone.follow") === true

    function num(v) {
        return String(Math.round(v)).replace("-", "−");
    }
    function poseText(pose) {
        return pose ? "pan " + num(pose.pan) + "° · tilt " + num(pose.tilt) + "° · zoom " + Number(pose.zoom).toFixed(2) + "×" : "";
    }
    function reset() {
        renaming = -1;
        deleting = -1;
    }

    title: "Presets"
    collapsible: true
    expanded: false
    visible: ctl.cardEnabled("Presets") && ctl.link.has("presets")
    summary: rows === null ? "" : rows.filter(r => r.used).length + " of " + rows.length + " saved"
    enabled: ctl.available || arranging
    opacity: ctl.available || arranging ? 1 : 0.38
    onExpandedChanged: reset()

    StyledText {
        width: parent.width
        visible: section.rows === null
        text: "Presets not read yet"
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    Repeater {
        model: section.rows ?? []

        delegate: Column {
            id: row

            required property var modelData
            readonly property bool confirmingDelete: section.deleting === modelData.slot
            readonly property bool editing: section.renaming === modelData.slot
            readonly property var nameProblem: Lists.nameProblem(section.ctl.link.device, "preset.rename", "name", nameField.text)

            function rename() {
                if (nameProblem !== null)
                    return;
                section.renaming = -1;
                section.ctl.link.act("preset.rename", {
                    slot: modelData.slot,
                    name: nameField.text
                });
            }

            width: section.width - section.padding * 2
            spacing: Theme.spacingXS

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: "Slot " + (row.modelData.slot + 1) + (row.modelData.used ? ": " + row.modelData.label : "")
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: !row.confirmingDelete
                text: row.modelData.used ? section.poseText(row.modelData.pose) : "Empty"
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                font.features: { "tnum": 1 }
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: row.confirmingDelete
                text: "Delete this preset from the camera?"
                color: Theme.error
                font.pixelSize: Theme.fontSizeSmall
            }

            DTextField {
                id: nameField
                width: parent.width
                visible: row.editing
                placeholderText: "Name"
                onAccepted: row.rename()
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingS

                DButton {
                    visible: !row.confirmingDelete && !row.editing && section.ctl.link.has("preset.recall")
                    text: "Recall"
                    iconName: "my_location"
                    enabled: row.modelData.used && section.ctl.link.blocked("preset.recall") === null
                    onClicked: section.ctl.link.act("preset.recall", {
                        slot: row.modelData.slot
                    })
                }

                DButton {
                    visible: !row.confirmingDelete && !row.editing && section.ctl.link.has("preset.save")
                    text: "Save current pose"
                    iconName: "save"
                    enabled: section.ctl.link.blocked("preset.save") === null
                    onClicked: section.ctl.link.act("preset.save", Lists.saveParams(row.modelData.slot, ""))
                }

                DButton {
                    visible: !row.confirmingDelete && !row.editing && section.ctl.link.has("preset.rename")
                    text: "Rename"
                    iconName: "edit"
                    enabled: row.modelData.used && section.ctl.link.blocked("preset.rename") === null
                    onClicked: {
                        section.reset();
                        nameField.text = row.modelData.name;
                        section.renaming = row.modelData.slot;
                        nameField.forceActiveFocus();
                    }
                }

                DButton {
                    visible: !row.confirmingDelete && !row.editing && section.ctl.link.has("preset.delete")
                    text: "Delete"
                    iconName: "delete"
                    enabled: row.modelData.used && section.ctl.link.blocked("preset.delete") === null
                    backgroundColor: Theme.errorContainer
                    textColor: Theme.onErrorContainer
                    onClicked: {
                        section.reset();
                        section.deleting = row.modelData.slot;
                        cancelTimer.restart();
                    }
                }

                DButton {
                    visible: row.editing
                    text: "Cancel"
                    onClicked: section.renaming = -1
                }

                DButton {
                    visible: row.editing
                    text: "Rename"
                    iconName: "check"
                    enabled: row.nameProblem === null
                    tooltipText: row.nameProblem ?? ""
                    onClicked: row.rename()
                }

                DButton {
                    visible: row.confirmingDelete
                    text: "Cancel"
                    onClicked: section.deleting = -1
                }

                DButton {
                    visible: row.confirmingDelete
                    text: "Delete now"
                    iconName: "delete"
                    backgroundColor: Theme.error
                    textColor: Theme.onError
                    onClicked: {
                        section.deleting = -1;
                        section.ctl.link.act("preset.delete", {
                            slot: row.modelData.slot
                        });
                    }
                }
            }
        }
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Saving takes the camera's current pose and zoom. Delete frees the slot."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    StyledText {
        width: parent.width
        visible: section.zoneReturnArmed
        wrapMode: Text.WordWrap
        text: "Zone tracking follows new targets: after a recall, the camera's next return to the zone ends in Static."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    // A forgotten first click must not stay armed
    Timer {
        id: cancelTimer
        interval: 10000
        onTriggered: section.deleting = -1
    }
}
