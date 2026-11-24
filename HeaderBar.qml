import QtQuick
import qs.Common
import qs.DCommon.Widgets

// Camera name, status line, the Awake switch (one sleep or wake action), the hint while the daemon
// is not reachable, and the camera picker.
// In arrange mode the status line becomes the hint and Reset layout takes the Awake switch's place,
// so the header keeps its height and the cards below don't move.
Column {
    id: bar

    property var ctl

    spacing: Theme.spacingS

    Item {
        width: parent.width
        height: badge.height

        Rectangle {
            id: badge
            width: Theme.buttonHeightS
            height: Theme.buttonHeightS
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.surfaceContainerHighest

            DIcon {
                anchors.centerIn: parent
                name: !bar.ctl.available ? "error" : (bar.ctl.live ? "videocam" : "videocam_off")
                color: bar.ctl.live ? Theme.primary : Theme.surfaceVariantText
                size: Theme.iconSize
            }
        }

        Column {
            anchors.left: badge.right
            anchors.leftMargin: Theme.spacingM
            anchors.right: editButton.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXXS

            StyledText {
                text: "OBSBOT Control"
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.DemiBold
            }

            StyledText {
                width: parent.width
                // one line, elided: a long status must not run under the buttons on the right
                maximumLineCount: 1
                elide: Text.ElideRight
                // the camera model, then its state: the title is the plugin's name
                text: bar.ctl.arranging ? "Drag a card by its handle to move it." : bar.ctl.summary
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        // Arrange mode of the popout cards (drag handles, Reset layout)
        DIconButton {
            id: editButton
            anchors.right: resetButton.visible ? resetButton.left : (awakeRow.visible ? awakeRow.left : parent.right)
            anchors.rightMargin: resetButton.visible || awakeRow.visible ? Theme.spacingM : 0
            anchors.verticalCenter: parent.verticalCenter
            iconName: bar.ctl.arranging ? "check" : "edit"
            variant: bar.ctl.arranging ? "tonal" : "standard"
            tooltipText: bar.ctl.arranging ? "Done" : "Arrange cards"
            onClicked: bar.ctl.arranging = !bar.ctl.arranging
        }

        DButton {
            id: resetButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: bar.ctl.arranging
            text: "Reset layout"
            iconName: "restart_alt"
            backgroundColor: Theme.surfaceContainerHighest
            textColor: Theme.surfaceText
            onClicked: bar.ctl.resetLayout()
        }

        Row {
            id: awakeRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS
            visible: bar.ctl.available && !bar.ctl.arranging

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Awake"
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
            }

            DToggle {
                anchors.verticalCenter: parent.verticalCenter
                // A DToggle label would span the whole row, so the label is the text beside it
                hideText: true
                checked: bar.ctl.live
                enabled: bar.ctl.link.blocked(bar.ctl.live ? "sleep" : "wake") === null
                onToggled: bar.ctl.toggleAwake()
            }
        }
    }

    // No daemon, an older one, or a lost connection: what to do about it (spec 5.10)
    Item {
        width: parent.width
        height: bar.ctl.problem !== null ? Math.max(problemBody.implicitHeight, retryButton.height) : 0
        visible: bar.ctl.problem !== null

        StyledText {
            id: problemBody
            anchors.left: parent.left
            anchors.right: retryButton.left
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.Wrap
            text: bar.ctl.problem !== null ? bar.ctl.problem.body : ""
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
        }

        DButton {
            id: retryButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "Retry"
            iconName: "refresh"
            backgroundColor: Theme.surfaceContainerHighest
            textColor: Theme.surfaceText
            onClicked: bar.ctl.refresh()
        }
    }

    DevicePicker {
        width: parent.width
        link: bar.ctl.link
    }
}
