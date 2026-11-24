import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "lib/format.mjs" as Format
import "lib/lists.mjs" as Lists

// Named poses stored in the camera: go, rename, delete, save the current pose. The list is the
// `views` of the camera's state, [{id, name, pose}]; the camera does not track by them. Rename
// and delete work like in the Presets card. A name is sent as typed; the description's limits
// (length, characters) only gate the buttons.
Column {
    id: views

    property var ctl

    // null while the camera's views are not read
    readonly property var rows: Lists.viewRows(ctl.link.camState)
    readonly property var poseSetting: ctl.link.setting("views")?.item?.pose ?? null
    readonly property string newProblem: Lists.nameProblem(ctl.link.device, "view.save", "name", newName.text) ?? ""
    // View id being renamed / asked to delete, -1 = none; only one row at a time
    property int renaming: -1
    property int deleting: -1

    function poseText(row) {
        return row.pose === null ? "–" : Format.value(poseSetting, row.pose);
    }
    function reset() {
        renaming = -1;
        deleting = -1;
    }
    function save() {
        if (Lists.nameProblem(ctl.link.device, "view.save", "name", newName.text) !== null || ctl.link.blocked("view.save") !== null)
            return;
        const name = newName.text;
        newName.text = "";
        ctl.link.act("view.save", { name: name });
    }

    width: parent.width
    spacing: Theme.spacingS

    StyledText {
        width: parent.width
        text: "Views"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeSmall
    }

    StyledText {
        width: parent.width
        visible: views.rows === null || views.rows.length === 0
        text: views.rows === null ? "Views not read yet" : "No views saved"
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    Repeater {
        model: views.rows ?? []

        delegate: Column {
            id: row

            required property var modelData
            readonly property bool confirmingDelete: views.deleting === modelData.id
            readonly property bool editing: views.renaming === modelData.id
            readonly property string problem: Lists.nameProblem(views.ctl.link.device, "view.rename", "name", nameField.text) ?? ""

            function rename() {
                if (problem !== "" || views.ctl.link.blocked("view.rename") !== null)
                    return;
                views.renaming = -1;
                views.ctl.link.act("view.rename", { id: row.modelData.id, name: nameField.text });
            }

            width: views.width
            spacing: Theme.spacingXS

            StyledText {
                width: parent.width
                elide: Text.ElideRight
                text: row.modelData.label
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: !row.confirmingDelete
                text: views.poseText(row.modelData)
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                font.features: { "tnum": 1 }
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: row.confirmingDelete
                text: "Delete this view from the camera?"
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

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: row.editing && row.problem !== "" && nameField.text !== ""
                text: row.problem
                color: Theme.error
                font.pixelSize: Theme.fontSizeSmall
            }

            Flow {
                width: parent.width
                spacing: Theme.spacingS

                DButton {
                    text: "Go"
                    iconName: "my_location"
                    visible: !row.confirmingDelete && !row.editing && views.ctl.link.has("view.go")
                    enabled: views.ctl.link.blocked("view.go") === null
                    onClicked: views.ctl.link.act("view.go", { id: row.modelData.id })
                }

                DButton {
                    visible: !row.confirmingDelete && !row.editing && views.ctl.link.has("view.rename")
                    text: "Rename"
                    iconName: "edit"
                    enabled: views.ctl.link.blocked("view.rename") === null
                    onClicked: {
                        views.reset();
                        nameField.text = row.modelData.name;
                        views.renaming = row.modelData.id;
                        nameField.forceActiveFocus();
                    }
                }

                DButton {
                    visible: !row.confirmingDelete && !row.editing && views.ctl.link.has("view.delete")
                    text: "Delete"
                    iconName: "delete"
                    enabled: views.ctl.link.blocked("view.delete") === null
                    backgroundColor: Theme.errorContainer
                    textColor: Theme.onErrorContainer
                    onClicked: {
                        views.reset();
                        views.deleting = row.modelData.id;
                        cancelTimer.restart();
                    }
                }

                DButton {
                    visible: row.editing
                    text: "Cancel"
                    onClicked: views.renaming = -1
                }

                DButton {
                    visible: row.editing
                    text: "Rename"
                    iconName: "check"
                    enabled: row.problem === "" && views.ctl.link.blocked("view.rename") === null
                    onClicked: row.rename()
                }

                DButton {
                    visible: row.confirmingDelete
                    text: "Cancel"
                    onClicked: views.deleting = -1
                }

                DButton {
                    visible: row.confirmingDelete
                    text: "Delete now"
                    iconName: "delete"
                    enabled: views.ctl.link.blocked("view.delete") === null
                    backgroundColor: Theme.error
                    textColor: Theme.onError
                    onClicked: {
                        views.deleting = -1;
                        views.ctl.link.act("view.delete", { id: row.modelData.id });
                    }
                }
            }
        }
    }

    DTextField {
        id: newName
        width: parent.width
        placeholderText: "Name for the current pose"
        onAccepted: views.save()
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        visible: views.newProblem !== "" && newName.text !== ""
        text: views.newProblem
        color: Theme.error
        font.pixelSize: Theme.fontSizeSmall
    }

    DButton {
        text: "Save current pose as view"
        iconName: "save"
        visible: views.ctl.link.has("view.save")
        enabled: views.newProblem === "" && views.ctl.link.blocked("view.save") === null
        onClicked: views.save()
    }

    StyledText {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "In a tracking mode, Go only applies the view's zoom (tracking keeps pan and tilt); in Static the camera moves to the full pose. The camera does not track by views."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    // A forgotten first click must not stay armed
    Timer {
        id: cancelTimer
        interval: 10000
        onTriggered: views.deleting = -1
    }
}
