//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

Scope {
    id: root

    readonly property real sizeScale: Config.options.settings.style === "minimal" ? 0.75 : 1.0
    property bool isMinimal: Config.options.settings.style === "minimal"
    readonly property bool isMacos: Config.options.settings.style === "macos"
    property bool macExpanded: false
    property bool initialized: false

    Component.onCompleted: {
        GlobalStates.settingsOpen = false;
    }

    Connections {
        target: GlobalStates
        function onSettingsOpenChanged() {
            if (GlobalStates.settingsOpen && Config.options.settings.style !== "dashboard") {
                root.initialized = true;
            }
        }
    }

    Dashboard {}

    Loader {
        id: panelLoader
        active: root.initialized && Config.options.settings.style !== "dashboard"

        sourceComponent: PanelWindow {
            id: panelWindow
            visible: GlobalStates.settingsOpen && Config.options.settings.style !== "dashboard"

            function hide() {
                GlobalStates.settingsOpen = false;
            }

            readonly property real screenW: panelWindow.screen?.width ?? 1920
            readonly property real screenH: panelWindow.screen?.height ?? 1080
            readonly property real targetWidth: root.isMacos
                ? Math.min(screenW - 64, root.macExpanded ? 1120 : 940)
                : (Config.options.settings.style === "minimal" ? Math.min(screenW - 70, 980 * root.sizeScale) : Math.min(screenW - 80, 980 * root.sizeScale))
            readonly property real targetHeight: root.isMacos
                ? Math.min(screenH - 64, root.macExpanded ? 760 : 640)
                : Math.min(screenH - 80, 665 * root.sizeScale)

            implicitWidth: Math.round(targetWidth)
            implicitHeight: Math.round(targetHeight)

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:settings"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.settingsOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            color: "transparent"

            onVisibleChanged: {
                if (visible) {
                    GlobalFocusGrab.addDismissable(panelWindow);
                    settingsWindow.forceActiveFocus();
                } else {
                    GlobalFocusGrab.removeDismissable(panelWindow);
                }
            }

            Component.onCompleted: {
                if (visible) {
                    GlobalFocusGrab.addDismissable(panelWindow);
                    settingsWindow.forceActiveFocus();
                }
            }

            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }

            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    if (panelWindow.visible) panelWindow.hide();
                }
            }

            Rectangle {
                id: settingsWindow
                anchors.fill: parent
                focus: true
                color: Appearance.colors.colUiBackground
                radius: root.isMacos
                    ? 16
                    : (!root.isMinimal ? Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 5 : Appearance.rounding.screenRounding + 5)

                Loader {
                    anchors.fill: parent
                    active: (Config.options?.background?.widgets?.glass?.enable ?? false) && (settingsWindow.color.a > 0)
                    sourceComponent: WindowGlass {
                        glassEnabled: true
                        cardRadius: settingsWindow.radius
                        tint: settingsWindow.color
                    }
                }

                Keys.onTabPressed: (event) => {
                    const count = settingsContent.pages.length;
                    settingsContent.selectPage((settingsContent.currentPage + 1) % count, false);
                    event.accepted = true;
                }

                Keys.onBacktabPressed: (event) => {
                    const count = settingsContent.pages.length;
                    settingsContent.selectPage((settingsContent.currentPage - 1 + count) % count, false);
                    event.accepted = true;
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        panelWindow.hide();
                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
                        const instance = GlobalStates.currentPageInstance;
                        if (instance && instance.contentY !== undefined) {
                            const step = 60;
                            const delta = event.key === Qt.Key_Down ? step : -step;
                            const maxY = Math.max(0, (instance.contentHeight ?? 0) - instance.height);
                            instance.contentY = Math.max(0, Math.min(maxY, instance.contentY + delta));
                        }
                        event.accepted = true;
                        return;
                    }
                }

                SettingsContent {
                    id: settingsContent
                    anchors.fill: parent
                    windowRadius: settingsWindow.radius
                    panelVisible: panelWindow.visible
                    onRequestClose: panelWindow.hide()
                    onRequestToggleExpand: root.macExpanded = !root.macExpanded
                }

                // Top-level border overlay so sidebar/toolbar never cover the rounded border
                Rectangle {
                    anchors.fill: parent
                    radius: settingsWindow.radius
                    color: "transparent"
                    border.width: root.isMacos ? 1 : Config.options.settings.borderSize
                    border.color: root.isMacos
                        ? CF.ColorUtils.applyAlpha(Appearance.m3colors.darkmode ? "#ffffff" : "#000000", Appearance.m3colors.darkmode ? 0.14 : 0.12)
                        : CF.ColorUtils.transparentize(Appearance.getColorFromName(Config.options.settings.borderColor), 0.8)
                    z: 10
                }
            }
        }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { GlobalStates.settingsOpen = !GlobalStates.settingsOpen; }
        function open(): void   { GlobalStates.settingsOpen = true; }
        function close(): void  { GlobalStates.settingsOpen = false; }
    }

    CompositorGlobalShortcut {
        name: "settingsToggle"
        description: "Toggles settings panel"
        onPressed: GlobalStates.settingsOpen = !GlobalStates.settingsOpen;
    }
}
