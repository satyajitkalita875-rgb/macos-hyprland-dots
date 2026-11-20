import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false

    PanelWindow {
        id: panelWindow
        property string searchingText: ""
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
        readonly property bool barCenterOnly: Config.options.bar.layouts.leftLayout.length === 0
            && Config.options.bar.layouts.rightLayout.length === 0
            && !Config.options.bar.vertical

        readonly property bool barOverlapActive: panelWindow.barCenterOnly
            && Config.options.bar.centerOnlyReserveFrame
            && !Config.options.bar.bottom
            && !Config.options.bar.autoHide.enable
        property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
        readonly property bool anyOpen: GlobalStates.overviewOpen || GlobalStates.searchOpen
        property bool reallyVisible: false
        property bool showSearchContent: false
        property bool showOverviewContent: false
        visible: reallyVisible

        function startOpen() {
            overviewCloseAnim.stop();
            reallyVisible = true;
            overviewOpenAnim.restart();
            Qt.callLater(() => {
                if (panelWindow.anyOpen) GlobalFocusGrab.addDismissable(panelWindow);
            });
        }

        function startClose() {
            GlobalFocusGrab.removeDismissable(panelWindow);
            if (!reallyVisible) return;
            overviewOpenAnim.stop();
            overviewCloseAnim.restart();
        }

        WlrLayershell.namespace: "quickshell:overview"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: anyOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        onVisibleChanged: {
            if (visible) {
                GlobalFocusGrab.addDismissable(panelWindow);
            } else {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
        }

        // While a window preview is being dragged, take input over the whole screen.
        // Otherwise the pointer leaves the mask, Hyprland ends the focus grab and the overview closes.
        readonly property bool windowDragging: (overviewLoader.item?.draggingFromWorkspace ?? -1) !== -1
        mask: Region {
            item: panelWindow.anyOpen ? (panelWindow.windowDragging ? fullscreenMask : columnMask) : null
            Region {
                item: searchWidget.clipboardPopover.visible ? searchWidget.clipboardPopover : null
            }
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Connections {
            target: GlobalStates
            function onOverviewOpenChanged() {
                if (GlobalStates.overviewOpen) {
                    const alreadyShown = panelWindow.reallyVisible && !overviewCloseAnim.running;
                    panelWindow.showOverviewContent = true;
                    panelWindow.showSearchContent = false;
                    if (GlobalStates.searchOpen) GlobalStates.searchOpen = false;
                    if (!alreadyShown) {
                        panelWindow.startOpen();
                    }
                } else if (!GlobalStates.searchOpen) {
                    panelWindow.startClose();
                }
            }
            function onSearchOpenChanged() {
                if (GlobalStates.searchOpen) {
                    const alreadyShown = panelWindow.reallyVisible && !overviewCloseAnim.running;
                    panelWindow.showSearchContent = true;
                    panelWindow.showOverviewContent = false;
                    if (GlobalStates.overviewOpen) GlobalStates.overviewOpen = false;
                    if (!overviewScope.dontAutoCancelSearch) {
                        searchWidget.cancelSearch();
                    }
                    if (!alreadyShown) {
                        panelWindow.startOpen();
                    }
                    Qt.callLater(() => searchWidget.focusSearchInput());
                } else {
                    searchWidget.disableExpandAnimation();
                    overviewScope.dontAutoCancelSearch = false;
                    if (!GlobalStates.overviewOpen) {
                        panelWindow.startClose();
                    }
                }
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                GlobalStates.overviewOpen = false;
                GlobalStates.searchOpen = false;
            }
        }
        implicitWidth: columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight

        function setSearchingText(text) {
            searchWidget.setSearchingText(text);
            searchWidget.focusFirstItem();
        }

        Item {
            id: fullscreenMask
            anchors.fill: parent
        }

        // Unscaled stand-in for columnLayout. Region ignores the open-animation scale,
        // so masking columnLayout directly leaves its outer edges unclickable.
        Item {
            id: columnMask
            x: columnLayout.x
            y: columnLayout.y
            width: columnLayout.width
            height: columnLayout.height
        }

        Column {
            id: columnLayout
            opacity: 0
            scale: 0.85
            transformOrigin: Item.Top
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                topMargin: panelWindow.barOverlapActive
                    ? Appearance.sizes.barHeight - Config.options.bar.frameThickness
                    : 10
            }
            spacing: -8

            transform: Translate {
                id: columnShift
                y: -12
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.overviewOpen = false;
                    GlobalStates.searchOpen = false;
                } else if (event.key === Qt.Key_Left) {
                    if (GlobalStates.overviewOpen)
                        Hyprland.dispatch("workspace r-1");
                } else if (event.key === Qt.Key_Right) {
                    if (GlobalStates.overviewOpen)
                        Hyprland.dispatch("workspace r+1");
                }
            }

            SearchWidget {
                id: searchWidget
                visible: panelWindow.showSearchContent
                anchors.horizontalCenter: parent.horizontalCenter
                Synchronizer on searchingText {
                    property alias source: panelWindow.searchingText
                }
            }

            Loader {
                id: overviewLoader
                active: panelWindow.showOverviewContent && (Config?.options.overview.enable ?? true)
                visible: panelWindow.showOverviewContent
                sourceComponent: (Config?.options.overview.style ?? "default") === "niri" ? niriComponent : defaultComponent

                Component {
                    id: defaultComponent
                    OverviewWidget {
                        screen: panelWindow.screen
                        visible: panelWindow.showOverviewContent
                    }
                }

                Component {
                    id: niriComponent
                    NiriOverview {
                        screen: panelWindow.screen
                        panelWindow: panelWindow
                        visible: panelWindow.showOverviewContent
                    }
                }
            }
        }

        ParallelAnimation {
            id: overviewOpenAnim
            NumberAnimation {
                target: columnLayout
                property: "opacity"
                from: 0
                to: 1
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveEffects
            }
            NumberAnimation {
                target: columnLayout
                property: "scale"
                from: 0.85
                to: 1
                duration: 260
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
            NumberAnimation {
                target: columnShift
                property: "y"
                from: -12
                to: 0
                duration: 240
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
            }
        }

        ParallelAnimation {
            id: overviewCloseAnim
            onFinished: {
                if (!panelWindow.anyOpen) {
                    panelWindow.reallyVisible = false;
                    panelWindow.showSearchContent = false;
                    panelWindow.showOverviewContent = false;
                }
            }
            NumberAnimation {
                target: columnLayout
                property: "opacity"
                to: 0
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveEffects
            }
            NumberAnimation {
                target: columnLayout
                property: "scale"
                to: 0.85
                duration: 260
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
            }
            NumberAnimation {
                target: columnShift
                property: "y"
                to: -12
                duration: 240
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
            }
        }
    }

    function toggleClipboard() {
        if (GlobalStates.searchOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.searchOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.clipboard);
        GlobalStates.searchOpen = true;
    }

    function toggleEmojis() {
        if (GlobalStates.searchOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.searchOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.emojis);
        GlobalStates.searchOpen = true;
    }

    function toggleSymbols() {
        if (GlobalStates.searchOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.searchOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.symbols);
        GlobalStates.searchOpen = true;
    }

    IpcHandler {
        target: "search"

        function toggle() {
            GlobalStates.searchOpen = !GlobalStates.searchOpen;
        }
        function workspacesToggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
            GlobalStates.searchOpen = false;
        }
        function open() {
            GlobalStates.searchOpen = true;
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle() {
            overviewScope.toggleClipboard();
        }
    }

    CompositorGlobalShortcut {
        name: "searchToggle"
        description: "Toggles search on press"

        onPressed: {
            GlobalStates.searchOpen = !GlobalStates.searchOpen;
        }
    }
    CompositorGlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes overview on press"

        onPressed: {
            GlobalStates.overviewOpen = false;
            GlobalStates.searchOpen = false;
        }
    }
    CompositorGlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    CompositorGlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles search on release"

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true;
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            GlobalStates.searchOpen = !GlobalStates.searchOpen;
        }
    }
    CompositorGlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts possibility of search being toggled on release. " + "This is necessary because GlobalShortcut.onReleased in quickshell triggers whether or not you press something else while holding the key. " + "To make sure this works consistently, use binditn = MODKEYS, catchall in an automatically triggered submap that includes everything."

        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
        }
    }
    CompositorGlobalShortcut {
        name: "overviewClipboardToggle"
        description: "Toggle clipboard query on overview widget"

        onPressed: {
            overviewScope.toggleClipboard();
        }
    }

    CompositorGlobalShortcut {
        name: "overviewEmojiToggle"
        description: "Toggle emoji query on overview widget"

        onPressed: {
            overviewScope.toggleEmojis();
        }
    }

    CompositorGlobalShortcut {
        name: "overviewSymbolsToggle"
        description: "Toggle material symbols search on overview widget"

        onPressed: {
            overviewScope.toggleSymbols();
        }
    }
}