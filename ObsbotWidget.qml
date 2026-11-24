import QtQuick
import QtQuick.Window
import QtQml.Models
import Quickshell
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.ControlCenter.Widgets
import qs.Modules.Plugins
import qs.Services
import "lib/labels.mjs" as Labels
import "lib/describe.mjs" as Describe

PluginComponent {
    id: root

    // Settings page: the pill's mouse wheel zooms, its middle click toggles tracking
    readonly property bool wheelZoom: pluginData?.wheelZoom ?? true
    readonly property bool middleClickTracking: pluginData?.middleClickTracking ?? true
    // Settings page: hide the bar icon while no supported camera is plugged in (default: show it dimmed)
    readonly property bool hideWithoutCamera: pluginData?.hideWithoutCamera ?? false
    // Settings page: short status text next to the bar icon (horizontal bars only), off by default
    readonly property bool statusTextInBar: pluginData?.statusTextInBar ?? false
    // Experimental: draw the tracked target's box over the preview (popout and desktop widget)
    readonly property bool showTargetBox: pluginData?.showTargetBox ?? false
    function setShowTargetBox(on) {
        pluginService?.savePluginData(pluginId, "showTargetBox", on);
    }
    // Settings page: one switch per popout card, all on by default. Popout only; the bar icon
    // and the Control Center tile do not look at them.
    function cardEnabled(card) {
        return pluginData?.["card" + card] ?? true;
    }
    // Last tracking mode other than Static (a tracking.mode value), what the middle click goes back to
    readonly property string lastTrackingMode: pluginData?.lastTrackingMode ?? "normal"

    // Fine steps: 1° per arrow click instead of 5°
    property bool fineGimbal: false
    readonly property int gimbalStep: fineGimbal ? 1 : 5

    // Live preview; holds the camera, so no other app can open it meanwhile
    property bool previewOn: false
    // Starting the preview on a desktop widget switches this one off, and the other way round
    PreviewClaim {
        id: previewClaim
        pluginId: root.pluginId
        holding: root.previewOn
        onDisplaced: root.previewOn = false
    }
    // Off when the camera goes away (unplugged, connection lost) or falls asleep while the preview
    // was running, here or from another surface, like the desktop widget. A preview started while
    // the camera sleeps stays on: opening the stream wakes the camera (#93). `live` is the state's
    // own report; there is no optimistic value of it.
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
        applyVisibility();
    }

    // On air (`streaming` below): any app streams (the daemon's kernel probe) or our own preview
    // runs. The preview is counted here too: Qt reads the frames without mmap, so the daemon can't
    // name it. A preview of ours also runs on a desktop widget (PreviewClaim shares that between
    // surfaces)
    readonly property bool previewRunning: previewOn || previewClaim.anyRunning
    readonly property var appNames: ({
            "qs": "preview",
            "chrome": "Chrome",
            "chromium": "Chrome",
            "firefox": "Firefox",
            "obs": "OBS"
        })

    // DMS only hides the popout, its content stays alive; switch the preview off on close
    onInteractionActiveChanged: {
        if (!interactionActive) {
            previewOn = false;
            arranging = false;
        }
    }

    // The open card of each tab ("" = all closed); opening one closes the other in the same
    // tab, so the popout stays short
    property var openCards: ({})
    function isOpen(id) {
        return openCards[tabOf(id)] === id;
    }
    function toggleOpen(id) {
        const next = Object.assign({}, openCards);
        next[tabOf(id)] = isOpen(id) ? "" : id;
        openCards = next;
    }

    // The right column of the popout is a tab bar; Preview and Framing stay in the left column.
    // Arrange mode of the popout (header button): cards fold up and can be dragged by their grip,
    // within their tab or onto another tab's button. The assignment is saved as card ids per tab
    // in cardTabs. Ids missing there (new cards) join their default tab at the end, unknown ids
    // are dropped. Hidden and unsupported cards keep their slot, they are only not shown.
    property bool arranging: false
    onArrangingChanged: openCards = ({})
    readonly property var tabs: [
        { id: "tracking", text: "Tracking", icon: "track_changes" },
        { id: "picture", text: "Picture", icon: "tune" },
        { id: "device", text: "Device", icon: "settings" }
    ]
    readonly property var defaultTabs: ({
            tracking: ["tracking", "zone", "presets"],
            picture: ["picture", "image"],
            device: ["camera", "sleep", "audio", "gestures", "reset"]
        })
    property var cardTabs: defaultTabs
    function tabOf(id) {
        return tabs.find(t => cardTabs[t.id].includes(id))?.id ?? "device";
    }

    // The tab selected in the popout ("" = the saved one); the last click is saved as lastTab
    property string tab: ""
    readonly property string lastTab: pluginData?.lastTab ?? "tracking"
    function selectTab(id, save) {
        tab = id;
        if (save)
            pluginService?.savePluginData(pluginId, "lastTab", id);
    }

    // Replaced only when the assignment really differs, so other plugin settings changing
    // do not rebuild the cards
    function refreshTabs() {
        const known = tabs.reduce((all, t) => all.concat(defaultTabs[t.id]), []);
        const defaultTab = id => tabs.find(t => defaultTabs[t.id].includes(id)).id;
        const next = {};
        const seen = {};
        const take = (t, id) => {
            if (known.includes(id) && !seen[id]) {
                seen[id] = true;
                next[t].push(id);
            }
        };
        for (const t of tabs)
            next[t.id] = [];
        const saved = pluginData?.cardTabs;
        if (saved && typeof saved === "object") {
            for (const t of tabs) {
                for (const id of Array.isArray(saved[t.id]) ? saved[t.id] : [])
                    take(t.id, id);
            }
        } else {
            // Before 0.17.0 the order was saved per column (cardOrderLeft / cardOrderRight): every
            // card goes to its default tab, ordered by its place in its old column (left first on a tie)
            const old = [];
            for (const col of ["Left", "Right"]) {
                const list = pluginData?.["cardOrder" + col];
                (Array.isArray(list) ? list : []).filter(id => known.includes(id)).forEach((id, rank) => old.push({ id: id, rank: rank, col: col }));
            }
            old.sort((x, y) => x.rank - y.rank || (x.col === "Left" ? -1 : 1) - (y.col === "Left" ? -1 : 1));
            for (const e of old)
                take(defaultTab(e.id), e.id);
        }
        for (const t of tabs) {
            for (const id of defaultTabs[t.id])
                take(t.id, id);
        }
        if (JSON.stringify(next) !== JSON.stringify(cardTabs))
            cardTabs = next;
    }
    onPluginDataChanged: refreshTabs()

    // anchorId: the visible card next to the drop position (after it or before it); "" = end of the tab
    function moveCard(id, toTab, anchorId, after) {
        const next = {};
        for (const t of tabs)
            next[t.id] = cardTabs[t.id].filter(c => c !== id);
        next[toTab].splice(anchorId === "" ? next[toTab].length : next[toTab].indexOf(anchorId) + (after ? 1 : 0), 0, id);
        selectTab(toTab, false);
        if (JSON.stringify(next) === JSON.stringify(cardTabs))
            return;
        pluginService?.savePluginData(pluginId, "cardTabs", next);
    }

    // undefined drops the keys from the saved settings (the pre-0.17.0 column orders too); cardTabs
    // goes last so the migration of the old keys does not run in between
    function resetLayout() {
        pluginService?.savePluginData(pluginId, "cardOrderLeft", undefined);
        pluginService?.savePluginData(pluginId, "cardOrderRight", undefined);
        pluginService?.savePluginData(pluginId, "cardTabs", undefined);
    }

    function degrees(d) {
        const r = Math.round(d);
        return (r > 0 ? "+" : r < 0 ? "−" : "") + Math.abs(r) + "°";
    }

    // Any usable camera listed drives the bar icon when it should hide without a camera, also
    // while none is picked yet. DMS only fades the pill out, the component and the link stay
    // alive, so the icon returns when the camera is plugged in again.
    function applyVisibility() {
        if (hideWithoutCamera)
            setVisibilityOverride(link.anyUsable);
        else
            clearVisibilityOverride();
    }
    onHideWithoutCameraChanged: applyVisibility()
    Component.onCompleted: {
        applyVisibility();
    }

    // DMS also creates a throw-away instance only to read ccWidgetIcon; it gets no pluginService
    // and opens no connection. The bar sets hostContext and the screen; Control Center sets neither.
    readonly property bool realInstance: pluginService !== null
    readonly property string instanceName: !hostContext ? "Control Center tile or detail page" : (hostContext.kind === "bar" ? "bar widget" : hostContext.kind + " widget") + (parentScreen?.name ? " on screen " + parentScreen.name : "")

    CameraLink {
        id: cameraLink
        active: root.realInstance
        instanceName: root.instanceName
        client: "obsbot4linux-dux"
        // Live topics only while the popout is open (spec 10.3 D); each only if the device names it
        liveView: ({
                open: root.interactionActive,
                pose: root.cardEnabled("Framing"),
                target: root.showTargetBox,
                auto: root.cardEnabled("Picture")
            })
        // "Hide without camera" counts any usable camera, picked or not (decision 11)
        onAnyUsableChanged: root.applyVisibility()
    }
    // Not `id: link`: an id and a property of the same name shadow each other (qmllint
    // id-shadows-member); inside this file `link` is this alias
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
    // "Pick camera" while the picker still has to be used: no camera picked, a usable one listed
    readonly property string pillText: link.device !== null && link.device.support === "unsupported" ? "Unsupported" : link.device === null && link.anyUsable ? "Pick camera" : !available ? "Offline" : !live ? "Asleep" : modeText
    readonly property string statusText: {
        if (problem !== null)
            return problem.title;
        if (link.device === null)
            return link.devices.length > 0 ? "Pick a camera" : "No camera";
        if (link.device.support === "unsupported")
            return "Not supported by obsbot4linux";
        if (!available)
            return "Unplugged";
        const target = link.value("tracking.target.detected");
        const mode = Describe.choices(link.device, "tracking.mode", labels("tracking.mode")).find(c => c.value === link.value("tracking.mode"));
        return live ? "Awake · " + (mode ? mode.label : "") + (target === false && link.value("tracking.mode") !== "static" ? " · searching" : "") : "Asleep · lens stowed";
    }
    readonly property string baseSummary: (link.device !== null ? link.device.name + (link.marker !== "" ? " (" + link.marker + ")" : "") : "OBSBOT camera") + " · " + statusText
    readonly property string summary: baseSummary + (streaming ? " · On air" + (streamingApps.length > 0 ? ": " + streamingApps.map(a => appNames[a] ?? a).join(", ") : "") : "")

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

    // Middle click: Static <-> the last other mode, one set; only when the description lets
    // both be written (decision 12)
    function toggleTracking() {
        const s = link.setting("tracking.mode");
        const writable = s && Array.isArray(s.writable) ? s.writable : [];
        const mode = link.value("tracking.mode");
        const target = mode === "static" ? lastTrackingMode : "static";
        if (available && writable.includes("static") && writable.includes(target) && link.blocked("tracking.mode") === null)
            link.set("tracking.mode", target);
    }

    // Mouse wheel: 0.1 per notch, rounded to the description's precision of zoom.factor and
    // inside its bounds, one set
    function stepZoom(notches) {
        const spec = link.spec("zoom.factor");
        const now = link.value("zoom.factor");
        if (!spec || spec.min === null || spec.max === null || typeof now !== "number" || link.blocked("zoom.factor") !== null)
            return;
        const next = Math.max(spec.min, Math.min(spec.max, Describe.roundTo(now + notches * 0.1, spec.precision)));
        if (next !== now)
            link.set("zoom.factor", next);
    }

    // The last tracking mode other than Static, saved as before
    Connections {
        target: root.link
        function onRevisionChanged() {
            const mode = root.link.value("tracking.mode");
            if (typeof mode === "string" && mode !== "static" && mode in Labels.labelsFor("tracking.mode") && mode !== root.lastTrackingMode && root.link.status("tracking.mode") === "camera")
                root.pluginService?.savePluginData(root.pluginId, "lastTrackingMode", mode);
        }
    }

    // Retry button: connect again now
    function refresh() {
        cameraLink.retry();
    }

    // Layout: the left column (preview, framing) is always there, the right one has the tabs
    // (Tracking | Picture | Device). The preview area stays in place and is black while the
    // preview is off. Cards switched off on the settings page (or not supported by the camera)
    // close up; a tab without cards drops out of the tab bar, and when a column is left without
    // cards the popout narrows to the one column that is left. The popout reports the count.
    property int shownColumns: 2
    // 920 px, but at most 90 % of the screen (only below ~1020 px wide screens, e.g. scaled
    // displays) and at least 720 px so the right column keeps its minimum width
    // Theme has no popout width tokens; these are this layout's own sizes, named in one place
    readonly property int minRightWidth: 320
    readonly property int popoutWidthTwoColumns: 920
    readonly property int popoutWidthTwoColumnsMin: 720
    readonly property int popoutWidthOneColumn: 380
    popoutWidth: shownColumns >= 2 ? Math.max(popoutWidthTwoColumnsMin, Math.min(popoutWidthTwoColumns, Screen.width > 0 ? Math.round(Screen.width * 0.9) : popoutWidthTwoColumns)) : popoutWidthOneColumn

    // The bar draws the pill; plugins only provide the content (same as the built-in widgets).
    // Right click is sleep/wake; left click opens the popout.
    horizontalBarPill: Component {
        PillContent {
            ctl: root
        }
    }

    verticalBarPill: Component {
        PillContent {
            ctl: root
        }
    }
    pillRightClickAction: () => root.toggleAwake()

    // Control Center tile: the icon toggles sleep/wake. Larger tiles and the detail page show
    // the tracking card. Control Center runs its own instance of this component.
    ccWidgetIcon: link.device === null || !available ? "usb_off" : live ? "videocam" : "videocam_off"
    ccWidgetPrimaryText: "OBSBOT Control"
    ccWidgetSecondaryText: root.baseSummary + (root.streaming ? " · On air" : "")
    ccWidgetIsActive: root.live
    onCcWidgetToggled: root.toggleAwake()
    ccExpandedMinimumHeight: Theme.listItemHeight * 3.5
    ccExpandedContent: Component {
        CcTileContent {
            clip: true

            TrackingSection {
                width: parent.width
                ctl: root
                flat: true
                compact: true
                title: ""
            }
        }
    }
    ccDetailHeight: Theme.listItemHeight * 6
    ccDetailContent: Component {
        Item {
            TrackingSection {
                width: parent.width
                ctl: root
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout

            Component.onCompleted: root.refresh()

            // In arrange mode the tabs stay, an empty one is a drop target
            Binding {
                target: root
                property: "shownColumns"
                value: (leftColumn.hasCards ? 1 : 0) + (root.arranging || popout.shownTabs.length > 0 ? 1 : 0)
            }

            // The tabs with cards (all of them while arranging) and the selected one: the last
            // click, else the saved tab, else the first tab that is left
            readonly property var shownTabs: root.tabs.filter(t => root.arranging || tabColumn(t.id).hasCards)
            readonly property string activeTab: {
                const want = root.tab !== "" ? root.tab : root.lastTab;
                return shownTabs.some(t => t.id === want) ? want : (shownTabs[0]?.id ?? "");
            }
            onActiveTabChanged: root.openCards = ({})

            function tabColumn(id) {
                return id === "tracking" ? trackingTab : id === "picture" ? pictureTab : deviceTab;
            }

            // Arrange mode: cards report the pointer while their grip is dragged; `drop` is the
            // insert position (tab, neighbour card, side), shown as a line, applied on release.
            // Over a tab button the card goes to the end of that tab (the button is highlighted).
            readonly property bool arranging: root.arranging
            property var drop: null

            function dragMove(id, scenePos) {
                const b = tabBar.mapFromItem(null, scenePos.x, scenePos.y);
                if (b.x >= 0 && b.x < tabBar.width && b.y >= 0 && b.y < tabBar.height) {
                    // DTabBar: equal buttons with `spacing` gaps between them
                    const w = (tabBar.width - tabBar.spacing * (shownTabs.length - 1)) / shownTabs.length;
                    const i = Math.max(0, Math.min(shownTabs.length - 1, Math.floor(b.x / (w + tabBar.spacing))));
                    drop = {
                        tab: shownTabs[i].id,
                        anchorId: "",
                        after: true,
                        bar: true,
                        x: i * (w + tabBar.spacing),
                        width: w
                    };
                    return;
                }
                const column = tabColumn(activeTab);
                const p = column.mapFromItem(null, scenePos.x, scenePos.y);
                const others = [];
                for (const c of column.children) {
                    if (c.cardId && c.cardId !== id && c.visible)
                        others.push(c);
                }
                const k = others.findIndex(c => p.y < c.y + c.height / 2);
                const before = k >= 0 ? others[k] : null;
                const last = others[others.length - 1];
                const at = column.mapToItem(cols, 0, before ? before.y - column.spacing / 2 : last ? last.y + last.height + column.spacing / 2 : 0);
                drop = {
                    tab: activeTab,
                    anchorId: before ? before.cardId : last ? last.cardId : "",
                    after: !before,
                    bar: false,
                    x: at.x,
                    width: column.width,
                    y: at.y
                };
            }

            function dragEnd(id) {
                const d = drop;
                drop = null;
                if (d)
                    Qt.callLater(() => root.moveCard(id, d.tab, d.anchorId, d.after));
            }

            // DMS sizes the popout to its content; past 85 % of the screen the tab content scrolls
            // (the left column shrinks its preview instead) and the header stays in place
            readonly property real maxBodyHeight: Math.round(Screen.height * 0.85) - header.height - Theme.spacingM

            HeaderBar {
                id: header
                width: parent.width
                ctl: root
            }

            Item {
                width: parent.width
                height: Theme.spacingM
            }

            Item {
                id: cols
                width: parent.width
                height: columnRow.height

                Row {
                    id: columnRow
                    width: parent.width
                    spacing: leftColumn.hasCards && rightColumn.shown ? Theme.spacingM : 0

                    // Always there: the picture to watch while changing settings
                    Column {
                        id: leftColumn
                        // Column skips hidden cards; without any it drops out
                        readonly property bool hasCards: visibleChildren.length > 0
                        width: !hasCards ? 0 : rightColumn.shown ? parent.width - parent.spacing - rightColumn.width : parent.width
                        spacing: Theme.spacingM

                        PreviewPane {
                            width: parent.width
                            // On a small screen the preview shrinks so the column fits
                            maxHeight: popout.maxBodyHeight - (framing.visible ? framing.height + leftColumn.spacing : 0)
                            visible: root.cardEnabled("Preview")
                            ctl: root
                        }

                        FramingSection {
                            id: framing
                            width: parent.width
                            visible: root.cardEnabled("Framing")
                            ctl: root
                        }
                    }

                    Column {
                        id: rightColumn
                        readonly property bool shown: popout.shownTabs.length > 0
                        width: !shown ? 0 : !leftColumn.hasCards ? parent.width : Math.max(root.minRightWidth, Math.round((parent.width - parent.spacing) * 0.45))
                        spacing: Theme.spacingM

                        DTabBar {
                            id: tabBar
                            width: parent.width
                            model: popout.shownTabs
                            // Without a camera the cards behind the tabs are unusable; arrange mode
                            // keeps them (the buttons are its drop targets)
                            enabled: root.available || root.arranging
                            opacity: root.available || root.arranging ? 1 : 0.38
                            currentIndex: popout.shownTabs.findIndex(t => t.id === popout.activeTab)
                            onTabClicked: index => root.selectTab(popout.shownTabs[index].id, true)
                        }

                        // The tabs lie on top of each other and the area is as high as the
                        // tallest one, so the popout does not jump when switching. A tab that is
                        // not selected stays "visible" (the cards' visibility is what counts as
                        // having cards) but is see-through and inert. Open cards close on a tab
                        // switch, so a card left open in a hidden tab cannot make the area taller.
                        DFlickable {
                            id: tabFlick
                            width: parent.width
                            // The left column stays put; only the tab content scrolls, within what the
                            // screen leaves below the tab bar
                            height: Math.min(tabArea.height, Math.max(0, popout.maxBodyHeight - tabBar.height - rightColumn.spacing))
                            contentWidth: width
                            contentHeight: tabArea.height
                            clip: true

                            Item {
                                id: tabArea
                                width: parent.width
                                height: Math.max(trackingTab.height, pictureTab.height, deviceTab.height)

                                Column {
                                    id: trackingTab
                                    readonly property bool hasCards: visibleChildren.length > 0
                                    width: parent.width
                                    spacing: Theme.spacingM
                                    opacity: popout.activeTab === "tracking" ? 1 : 0
                                    enabled: popout.activeTab === "tracking"

                                    Repeater {
                                        visible: false
                                        model: root.cardTabs.tracking
                                        delegate: cardChooser
                                    }
                                }

                                Column {
                                    id: pictureTab
                                    readonly property bool hasCards: visibleChildren.length > 0
                                    width: parent.width
                                    spacing: Theme.spacingM
                                    opacity: popout.activeTab === "picture" ? 1 : 0
                                    enabled: popout.activeTab === "picture"

                                    Repeater {
                                        visible: false
                                        model: root.cardTabs.picture
                                        delegate: cardChooser
                                    }
                                }

                                Column {
                                    id: deviceTab
                                    readonly property bool hasCards: visibleChildren.length > 0
                                    width: parent.width
                                    spacing: Theme.spacingM
                                    opacity: popout.activeTab === "device" ? 1 : 0
                                    enabled: popout.activeTab === "device"

                                    Repeater {
                                        visible: false
                                        model: root.cardTabs.device
                                        delegate: cardChooser
                                    }
                                }
                            }
                        }
                    }
                }

                // Insert position of the card being dragged
                Rectangle {
                    visible: popout.drop !== null && !popout.drop.bar
                    x: popout.drop?.x ?? 0
                    y: Math.max(0, (popout.drop?.y ?? 0) - height / 2)
                    width: popout.drop?.width ?? 0
                    height: Theme.spacingXS
                    radius: height / 2
                    color: Theme.primary
                }

                // Tab button the card would be dropped on
                Rectangle {
                    visible: popout.drop?.bar ?? false
                    x: tabBar.mapToItem(cols, popout.drop?.x ?? 0, 0).x
                    y: tabBar.mapToItem(cols, 0, 0).y
                    width: popout.drop?.width ?? 0
                    height: tabBar.height
                    radius: Theme.cornerRadius
                    color: "transparent"
                    border.width: Theme.outlineWidthFocused
                    border.color: Theme.primary
                }
            }

            // One delegate per card id; the repeaters above create them in the saved order
            DelegateChooser {
                id: cardChooser
                role: "modelData"

                DelegateChoice {
                    roleValue: "camera"
                    CameraSection {
                        width: parent.width
                        cardId: "camera"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("camera")
                        onToggleRequested: root.toggleOpen("camera")
                    }
                }

                DelegateChoice {
                    roleValue: "sleep"
                    SleepSection {
                        width: parent.width
                        cardId: "sleep"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("sleep")
                        onToggleRequested: root.toggleOpen("sleep")
                    }
                }

                DelegateChoice {
                    roleValue: "tracking"
                    TrackingSection {
                        width: parent.width
                        cardId: "tracking"
                        arranger: popout
                        visible: root.cardEnabled("Tracking")
                        ctl: root
                    }
                }

                DelegateChoice {
                    roleValue: "zone"
                    ZoneSection {
                        width: parent.width
                        cardId: "zone"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("zone")
                        onToggleRequested: root.toggleOpen("zone")
                    }
                }

                DelegateChoice {
                    roleValue: "presets"
                    PresetsSection {
                        width: parent.width
                        cardId: "presets"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("presets")
                        onToggleRequested: root.toggleOpen("presets")
                    }
                }

                DelegateChoice {
                    roleValue: "picture"
                    PictureSection {
                        width: parent.width
                        cardId: "picture"
                        arranger: popout
                        visible: root.cardEnabled("Picture")
                        ctl: root
                    }
                }

                DelegateChoice {
                    roleValue: "image"
                    ImageSection {
                        width: parent.width
                        cardId: "image"
                        arranger: popout
                        visible: root.cardEnabled("Image")
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("image")
                        onToggleRequested: root.toggleOpen("image")
                    }
                }

                DelegateChoice {
                    roleValue: "audio"
                    AudioSection {
                        width: parent.width
                        cardId: "audio"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("audio")
                        onToggleRequested: root.toggleOpen("audio")
                    }
                }

                DelegateChoice {
                    roleValue: "gestures"
                    GestureSection {
                        width: parent.width
                        cardId: "gestures"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("gestures")
                        onToggleRequested: root.toggleOpen("gestures")
                    }
                }

                DelegateChoice {
                    roleValue: "reset"
                    ResetSection {
                        width: parent.width
                        cardId: "reset"
                        arranger: popout
                        ctl: root
                        controlled: true
                        expanded: root.isOpen("reset")
                        onToggleRequested: root.toggleOpen("reset")
                    }
                }
            }
        }
    }
}
