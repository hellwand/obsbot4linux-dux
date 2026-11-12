import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root

    pluginId: "obsbot4linuxDux"

    // The shell sets this only when it opens the page for a desktop widget instance. There the
    // toggles would write into that instance's own config, which nothing reads, so they stay
    // hidden; the bar and popout options live in Settings -> Plugins.
    property string instanceId: ""
    readonly property bool desktopInstance: instanceId !== ""

    StyledText {
        visible: root.desktopInstance
        width: parent.width
        text: "The desktop widget has no options of its own; the bar and popout options are in Settings → Plugins."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    ToggleSetting {
        visible: !root.desktopInstance
        settingKey: "hideWithoutCamera"
        label: "Hide the bar icon without a camera"
        description: "Off: the icon stays, dimmed, while no camera is plugged in"
        defaultValue: false
    }

    ToggleSetting {
        visible: !root.desktopInstance
        settingKey: "statusTextInBar"
        label: "Status text in the bar"
        description: "Shows Static, Tracking, Asleep or Offline next to the icon on a horizontal bar; the pill keeps its width"
        defaultValue: false
    }

    ToggleSetting {
        visible: !root.desktopInstance
        settingKey: "wheelZoom"
        label: "Mouse wheel zooms"
        description: "Scrolling over the bar icon changes the zoom by 0.1 per notch"
        defaultValue: true
    }

    ToggleSetting {
        visible: !root.desktopInstance
        settingKey: "middleClickTracking"
        label: "Middle click toggles tracking"
        description: "Switches between Static and the last tracking mode; right click always wakes or sleeps the camera"
        defaultValue: true
    }

    StyledText {
        visible: !root.desktopInstance
        width: parent.width
        text: "Popout cards"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        topPadding: Theme.spacingL
    }

    StyledText {
        visible: !root.desktopInstance
        width: parent.width
        text: "Choose which cards the popout shows. A card the connected camera does not support stays hidden either way. The bar icon and the Control Center tile are not affected."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    ToggleSetting {
        visible: !root.desktopInstance
        settingKey: "cardPreview"
        label: "Preview"
        defaultValue: true
    }

    ToggleSetting {
        visible: !root.desktopInstance
        settingKey: "cardFraming"
        label: "Framing"
        defaultValue: true
    }

    ToggleSetting {
        visible: !root.desktopInstance
        settingKey: "cardCamera"
        label: "Camera"
        defaultValue: true
    }

    ToggleSetting {
        visible: !root.desktopInstance
        settingKey: "cardSleep"
        label: "Sleep"
        defaultValue: true
    }

    ToggleSetting {
        visible: !root.desktopInstance
        settingKey: "cardTracking"
        label: "Tracking"
        defaultValue: true
    }

    ToggleSetting {
        visible: !root.desktopInstance
        settingKey: "cardZone"
        label: "Zone"
        defaultValue: true
    }

    ToggleSetting {
        visible: !root.desktopInstance
        settingKey: "cardPresets"
        label: "Presets"
        defaultValue: true
    }

    ToggleSetting {
        visible: !root.desktopInstance
        settingKey: "cardPicture"
        label: "Picture"
        defaultValue: true
    }

    ToggleSetting {
        visible: !root.desktopInstance
        settingKey: "cardImage"
        label: "Image"
        defaultValue: true
    }

    ToggleSetting {
        visible: !root.desktopInstance
        settingKey: "cardAudio"
        label: "Audio"
        defaultValue: true
    }

    ToggleSetting {
        visible: !root.desktopInstance
        settingKey: "cardGestures"
        label: "Gestures"
        defaultValue: true
    }

    ToggleSetting {
        visible: !root.desktopInstance
        settingKey: "cardReset"
        label: "Factory reset"
        defaultValue: true
    }
}
