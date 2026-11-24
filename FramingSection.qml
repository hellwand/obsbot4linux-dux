import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "lib/format.mjs" as Format
import "lib/gimbal.mjs" as Gimbal

// Pan/tilt and zoom
SectionCard {
    id: section

    property var ctl

    readonly property var moveSpec: Gimbal.moveSpec(ctl.link.device)
    // The target of the last own move and when it went out ({pan, tilt, at}); the base of the
    // next step for STEP_BASE_MS (decision 12)
    property var lastMove: null
    // The arrows need a pose to step from; while it is not read they are disabled
    readonly property bool poseKnown: typeof ctl.link.value("gimbal.pan") === "number" && typeof ctl.link.value("gimbal.tilt") === "number"
    // The centre button needs 0 inside both bounds of gimbal.move
    readonly property bool centerOk: moveSpec !== null && (moveSpec.pan.min === null || moveSpec.pan.min <= 0) && (moveSpec.pan.max === null || moveSpec.pan.max >= 0) && (moveSpec.tilt.min === null || moveSpec.tilt.min <= 0) && (moveSpec.tilt.max === null || moveSpec.tilt.max >= 0)

    // One arrow press: one gimbal.move to the computed target, nothing else (spec 2, 12.3)
    function step(dPan, dTilt) {
        if (moveSpec === null || ctl.link.blocked("gimbal.move") !== null)
            return;
        const pose = { pan: ctl.link.value("gimbal.pan"), tilt: ctl.link.value("gimbal.tilt") };
        const sign = Gimbal.panLeftSign(ctl.link.camState);
        const target = Gimbal.stepTarget(moveSpec, pose, lastMove, Date.now(), dPan * sign, dTilt);
        // no pose to step from: nothing is sent (the widget never makes a target up)
        if (target === null)
            return;
        lastMove = { pan: target.pan, tilt: target.tilt, at: Date.now() };
        const request = Gimbal.moveRequest(target);
        ctl.link.act(request.action, request.params);
    }

    title: "Framing"
    enabled: ctl.live || arranging
    opacity: ctl.live || arranging ? 1 : 0.38

    // D-pad and side panel; the panel drops below the pad when the popout is too narrow for both
    Flow {
        id: moveZoom
        width: parent.width
        spacing: Theme.spacingL

        // D-pad: up / left center right / down
        Grid {
            id: dpad
            visible: section.moveSpec !== null
            columns: 3
            spacing: Theme.spacingXS

            Item { width: upButton.width; height: upButton.height }
            DIconButton {
                id: upButton
                variant: "tonal"
                iconName: "keyboard_arrow_up"
                enabled: section.poseKnown && section.ctl.link.blocked("gimbal.move") === null
                tooltipText: "Tilt up " + section.ctl.gimbalStep + "°"
                onClicked: section.step(0, section.ctl.gimbalStep)
            }
            Item { width: upButton.width; height: upButton.height }
            DIconButton {
                variant: "tonal"
                iconName: "keyboard_arrow_left"
                enabled: section.poseKnown && section.ctl.link.blocked("gimbal.move") === null
                tooltipText: "Pan left " + section.ctl.gimbalStep + "°"
                onClicked: section.step(section.ctl.gimbalStep, 0)
            }
            DIconButton {
                variant: "outlined"
                iconName: "filter_center_focus"
                enabled: section.centerOk && section.ctl.link.blocked("gimbal.move") === null
                tooltipText: "Center"
                onClicked: section.ctl.link.act("gimbal.move", { pan: 0, tilt: 0 })
            }
            DIconButton {
                variant: "tonal"
                iconName: "keyboard_arrow_right"
                enabled: section.poseKnown && section.ctl.link.blocked("gimbal.move") === null
                tooltipText: "Pan right " + section.ctl.gimbalStep + "°"
                onClicked: section.step(-section.ctl.gimbalStep, 0)
            }
            Item { width: upButton.width; height: upButton.height }
            DIconButton {
                variant: "tonal"
                iconName: "keyboard_arrow_down"
                enabled: section.poseKnown && section.ctl.link.blocked("gimbal.move") === null
                tooltipText: "Tilt down " + section.ctl.gimbalStep + "°"
                onClicked: section.step(0, -section.ctl.gimbalStep)
            }
            Item { width: upButton.width; height: upButton.height }
        }

        Column {
            // beside the pad while at least sideMin wide, else full width under it
            readonly property real sideMin: Theme.spacingXL * 6
            readonly property real beside: moveZoom.width - dpad.width - moveZoom.spacing
            width: dpad.visible && beside >= sideMin ? beside : moveZoom.width
            spacing: Theme.spacingS

            StyledText {
                visible: section.ctl.link.has("gimbal.pan")
                text: "Pan " + Format.value(section.ctl.link.setting("gimbal.pan"), section.ctl.link.value("gimbal.pan")) + " · Tilt " + Format.value(section.ctl.link.setting("gimbal.tilt"), section.ctl.link.value("gimbal.tilt"))
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.features: { "tnum": 1 }
            }

            ChipRow {
                id: stepRow
                width: parent.width
                visible: dpad.visible
                label: "Step"
                options: ["5°", "1°"]
                currentIndex: section.ctl.fineGimbal ? 1 : 0
                onSelected: index => section.ctl.fineGimbal = index === 1
            }

            SettingSlider {
                width: parent.width
                link: section.ctl.link
                path: "zoom.factor"
                text: "Zoom"
            }
        }
    }

    Connections {
        target: section.ctl
        function onFineGimbalChanged() {
            stepRow.sync();
        }
    }

    // The pose the camera takes at power-on; shown only when obsbot4linux reports it
    Item {
        width: parent.width
        height: startRow.height
        visible: section.ctl.link.has("power_on.start.pose") || section.ctl.link.has("power_on.use_current") || section.ctl.link.has("power_on.go")

        Column {
            anchors.left: parent.left
            anchors.right: startRow.left
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: "Start pose"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeSmall
            }

            StyledText {
                width: parent.width
                visible: section.ctl.link.has("power_on.start.pose")
                wrapMode: Text.WordWrap
                text: Format.value(section.ctl.link.setting("power_on.start.pose"), section.ctl.link.value("power_on.start.pose"))
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Row {
            id: startRow
            anchors.right: parent.right
            spacing: Theme.spacingS

            DButton {
                text: "Use current"
                iconName: "flag"
                visible: section.ctl.link.has("power_on.use_current")
                enabled: section.ctl.link.blocked("power_on.use_current") === null
                onClicked: section.ctl.link.act("power_on.use_current", {})
            }

            DButton {
                text: "Go"
                iconName: "start"
                visible: section.ctl.link.has("power_on.go")
                enabled: section.ctl.link.blocked("power_on.go") === null
                onClicked: section.ctl.link.act("power_on.go", {})
            }
        }
    }

    // A setting stored in the camera; written only when picked here
    SettingChips {
        id: startModeRow
        width: parent.width
        stacked: true
        link: section.ctl.link
        path: "power_on.start.mode"
        text: "Start mode"
        labels: section.ctl.labels("power_on.start.mode")
    }

    StyledText {
        width: parent.width
        visible: startModeRow.visible
        wrapMode: Text.WordWrap
        text: "With a start mode the camera tracks in it after \"Go\" and powers on in it. Without one, \"Go\" leaves tracking stopped until a mode is picked again."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }
}
