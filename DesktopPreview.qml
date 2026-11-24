import QtQuick
import qs.Common
import qs.Services
import qs.Modules.Plugins
import "lib/labels.mjs" as Labels
import "lib/describe.mjs" as Describe

// Desktop surface of the plugin, one fixed layout like the popout: the picture area on top
// (PreviewFrame: dark with the "Preview is off" hint and Start button, live picture while the
// preview runs, Stop on hover) and the control panel below it (DesktopPanel: status, tracking mode,
// zoom, presets, sleep/wake). Nothing here starts the preview by itself.
//
// This surface has its own link to the obsbot4linux daemon (CameraLink; the bar widget, the
// Control Center tile and the popout are separate objects; the state is not shared between
// surfaces, only the "who runs a preview" flag, see PreviewClaim). It asks for no live topics.
DesktopPluginComponent {
    id: root

    // Fixed layout, one card: the 16:9 picture (640 x 360 on a normal screen) with the status,
    // tracking mode and Sleep / Wake in a column to its right and zoom and presets in a row below
    // it. DMS keeps one saved size per widget and the bottom row's height depends on the fonts and
    // the presets, so the widget asks once for the size of its content with requestResize
    // (transient, not saved). Without it the saved size applies. DMS refuses a request that is
    // larger than the screen without a message, so on a narrow or short screen the picture shrinks
    // (16:9, down to pictureMinWidth) until the whole card fits.
    // Theme has no picture or card size tokens: the picture bounds are this layout's own sizes
    readonly property real pictureMaxWidth: 640
    readonly property real pictureMinWidth: 320
    // logical size of the screen, the same numbers DMS checks the request against
    readonly property real screenWidth: screen?.width ?? Number.POSITIVE_INFINITY
    readonly property real screenHeight: screen?.height ?? Number.POSITIVE_INFINITY
    // what is left of the screen for the picture, beside the side column and above the bottom row
    readonly property real fitWidth: screenWidth - sideWidth - Theme.spacingM - Theme.spacingL * 2
    readonly property real fitHeight: screenHeight - bottomRow.implicitHeight - Theme.spacingM - Theme.spacingL * 2
    readonly property real pictureWidth: Math.max(pictureMinWidth, Math.min(pictureMaxWidth, fitWidth, Math.floor(Math.floor(fitHeight) * 16 / 9)))
    // the side column is as wide as its widest chip row (measured, see DesktopSide.naturalWidth)
    readonly property real sideWidth: sideColumn.naturalWidth
    readonly property real contentWidth: pictureWidth + sideWidth + Theme.spacingM + Theme.spacingL * 2
    readonly property real defaultWidth: contentWidth
    // no Theme token for a card height either: this layout's own size
    readonly property real defaultHeight: 520
    minWidth: 240
    minHeight: 135

    // DMS unloads desktop widgets while the desktop is being edited, but the editor shows its own
    // copy of them: that one is inert
    readonly property bool editing: DesktopWidgetRegistry.editing
    // On the lock screen the widget is inert too: no picture, no controls, no connection. DMS declares
    // and sets `lockScreen` on the plugin component (DesktopPluginComponent, in DMS 2.0.0 as well),
    // a moment after this object is created.
    readonly property bool inert: editing || lockScreen

    // Set by DMS (DesktopWidgetContent) when the component declares it; for the log and to
    // fit the card to the screen
    property var screen: null

    // The bar widget's "Show target box" switch (a global plugin setting, not this instance's).
    // SettingsData replaces pluginSettings on every save, so the binding follows at once.
    readonly property bool showTargetBox: SettingsData.pluginSettings[pluginId]?.showTargetBox ?? false
    property bool previewOn: false

    // The members below are those of the popout root (ObsbotWidget) that PreviewFrame,
    // DesktopSide and DesktopBottom read as `ctl`. Not `id: link`: an id and a property of the
    // same name shadow each other; inside this file `link` is this alias.
    readonly property alias link: cameraLink

    function labels(path) {
        return Labels.labelsFor(path);
    }
    readonly property bool available: link.usable
    readonly property bool live: link.awake
    readonly property var problem: Labels.problemText(link.problem)
    readonly property bool streaming: link.value("on_air.active") === true || previewRunning
    readonly property var streamingApps: {
        const apps = link.value("on_air.apps");
        const names = Array.isArray(apps) ? apps.map(a => String(a.name)).filter(n => n !== "qs") : [];
        return previewRunning ? names.concat(["qs"]) : names;
    }
    readonly property string videoNode: link.device !== null && link.device.video_node ? link.device.video_node : ""
    readonly property bool previewReady: videoNode !== ""
    // Decision 14: "Static" for static, "Tracking" for a mode the widget names, else the value's text
    readonly property string modeText: {
        const mode = link.value("tracking.mode");
        if (mode === null || mode === undefined)
            return "";
        if (mode === "static")
            return "Static";
        return mode in Labels.labelsFor("tracking.mode") ? "Tracking" : Describe.humanize(mode);
    }
    // Loads Qt Multimedia; not while inert
    readonly property bool interactionActive: !inert

    // Stop rules: whenever the camera goes away (unplugged, lost) or falls asleep while the preview
    // was running (a preview started while it sleeps stays on: opening the stream wakes it, #93),
    // and while inert (editing, lock screen). `live` is the state's own report; there is no
    // optimistic value of it. DMS also unloads the widget when it is disabled or removed, which
    // closes the camera. Otherwise the preview keeps running until the user stops it.
    property bool previewWasAwake: false
    onPreviewOnChanged: previewWasAwake = previewOn && live
    onLiveChanged: {
        if (live && previewOn)
            previewWasAwake = true;
        if (!live && previewWasAwake)
            previewOn = false;
    }
    onAvailableChanged: {
        if (!available)
            previewOn = false;
    }
    onEditingChanged: applySize()
    onInertChanged: {
        if (inert)
            previewOn = false;
    }

    // Retry button: connect again now
    function refresh() {
        cameraLink.retry();
    }

    // One act: wake while asleep, else sleep. The switch then follows the state (spec 4.4:
    // clients wait for the state, never for their own value). As in 0.29, the preview stops
    // when the user sends sleep; a preview started on a sleeping camera stays on while it wakes.
    function toggleAwake() {
        if (!available)
            return;
        if (live)
            previewOn = false;
        link.act(live ? "sleep" : "wake", {});
    }

    // Mouse wheel and the zoom buttons: 0.1 per notch, rounded to the description's precision of
    // zoom.factor and inside its bounds, one set
    function stepZoom(notches) {
        const spec = link.spec("zoom.factor");
        const now = link.value("zoom.factor");
        if (!spec || spec.min === null || spec.max === null || typeof now !== "number" || link.blocked("zoom.factor") !== null)
            return;
        const next = Math.max(spec.min, Math.min(spec.max, Describe.roundTo(now + notches * 0.1, spec.precision)));
        if (next !== now)
            link.set("zoom.factor", next);
    }

    // the screen or the side column's width changed: ask again (layout only, no retry)
    onContentWidthChanged: applySize()

    function applySize() {
        if (!requestResize || !clearResize)
            return;
        if (editing)
            clearResize();
        else if (card.implicitHeight > 0)
            requestResize(contentWidth, card.implicitHeight);
    }
    // DMS sets the two functions one after the other, the size can only be asked for once both are there
    onRequestResizeChanged: applySize()
    onClearResizeChanged: applySize()
    Component.onCompleted: applySize()

    // One preview at a time: starting one in the popout switches this one off and vice versa
    PreviewClaim {
        id: previewClaim
        pluginId: root.pluginId
        holding: root.previewOn
        onDisplaced: root.previewOn = false
    }
    // A preview of ours runs on some surface (this one, the popout or another desktop widget)
    readonly property bool previewRunning: previewOn || previewClaim.anyRunning

    // Errors are logged and shown as a toast by the link
    CameraLink {
        id: cameraLink
        active: !root.inert
        instanceName: "desktop widget" + (root.screen?.name ? " on screen " + root.screen.name : "")
        client: "obsbot4linux-dux"
        // No live topics on the desktop (decision 13)
        liveView: ({
                open: false,
                pose: false,
                target: false,
                auto: false
            })
    }

    // One card like the popout's cards: picture area inset at the top, the controls below
    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: content.implicitHeight + Theme.spacingL * 2
        color: Theme.surfaceContainerHigh
        radius: Theme.cornerRadius
        onImplicitHeightChanged: root.applySize()

        Column {
            id: content
            x: Theme.spacingL
            y: Theme.spacingL
            width: card.width - Theme.spacingL * 2
            spacing: Theme.spacingM

            Row {
                width: parent.width
                spacing: Theme.spacingM

                PreviewFrame {
                    id: frame
                    width: root.pictureWidth
                    height: Math.round(width * 9 / 16)
                    ctl: root
                    interactive: !root.inert
                    dropBodyWhenTight: true

                    // On air while the picture is live (the hover overlay keeps it visible)
                    Rectangle {
                        visible: frame.previewShown
                        width: Theme.spacingM
                        height: width
                        radius: width / 2
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: Theme.spacingS
                        color: Theme.error
                    }
                }

                DesktopSide {
                    id: sideColumn
                    width: root.sideWidth
                    height: frame.height
                    ctl: root
                    interactive: !root.inert
                }
            }

            DesktopBottom {
                id: bottomRow
                width: parent.width
                ctl: root
                interactive: !root.inert
            }
        }
    }
}
