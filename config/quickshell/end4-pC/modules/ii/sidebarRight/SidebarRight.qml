import qs
import qs.services
import qs.modules.common
import qs.modules.ii.sidebarRight.macos
import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    readonly property bool isMacos: (Config.options?.sidebar?.style ?? "macos") === "macos"
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    readonly property bool centerOnly: Config.options.bar.layouts.leftLayout.length === 0 && Config.options.bar.layouts.rightLayout.length === 0 && !Config.options.bar.vertical
    readonly property real barCenterOnlyOffset: (Config.options.bar.centerOnlyReserveFrame && root.centerOnly)
        ? Config.options.bar.frameThickness
        : Appearance.sizes.barHeight

    // Shadow margins for macOS floating popover (keeps RectangularShadow unclipped without bleeding blur)
    readonly property int macPadLeft: 26
    readonly property int macPadRight: 10
    readonly property int macPadTop: 8
    readonly property int macPadBottom: 28

    PanelWindow {
        id: panelWindow

        readonly property bool animatedEntrance: !root.isMacos && WM.compositor !== "hyprland"
        property bool reallyVisible: false
        visible: reallyVisible

        Component.onCompleted: reallyVisible = GlobalStates.sidebarRightOpen

        Connections {
            target: GlobalStates
            function onSidebarRightOpenChanged() {
                if (GlobalStates.sidebarRightOpen) {
                    closeAnimTimer.stop();
                    panelWindow.reallyVisible = true;
                } else if (panelWindow.animatedEntrance) {
                    closeAnimTimer.restart();
                } else {
                    panelWindow.reallyVisible = false;
                }
            }
        }

        Timer {
            id: closeAnimTimer
            interval: 150
            onTriggered: panelWindow.reallyVisible = false
        }

        function hide() {
            GlobalStates.sidebarRightOpen = false;
        }

        onVisibleChanged: {
            if (visible) {
                GlobalFocusGrab.addDismissable(panelWindow);
            } else {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                panelWindow.hide();
            }
        }

        exclusiveZone: 0
        implicitWidth: root.isMacos
            ? ((macContentLoader.item?.implicitWidth ?? 348) + root.macPadLeft + root.macPadRight)
            : sidebarWidth
        implicitHeight: root.isMacos
            ? ((macContentLoader.item?.maxPanelHeight ?? 520) + root.macPadTop + root.macPadBottom)
            : 0
        WlrLayershell.namespace: "quickshell:sidebarRight"
        WlrLayershell.keyboardFocus: GlobalStates.sidebarRightOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: root.isMacos ? !Config.options.bar.bottom : true
            right: true
            bottom: root.isMacos ? Config.options.bar.bottom : true
            left: animatedEntrance
        }

        margins {
            top: {
                if (Config.options.bar.bottom) return 0;
                if (Config?.options.bar.autoHide.enable) return 0;
                if (!centerOnly) return 0;
                switch (Config.options.bar.cornerStyle) {
                case 0:
                case 4:
                case 6: return -root.barCenterOnlyOffset;
                case 1: return -root.barCenterOnlyOffset + Appearance.sizes.hyprlandGapsOut;
                case 2: return -root.barCenterOnlyOffset + Appearance.sizes.hyprlandGapsOut;
                case 3: return -root.barCenterOnlyOffset - Appearance.sizes.hyprlandGapsOut;
                default: return 0;
                }
            }
            bottom: {
                if (!Config.options.bar.bottom) return 0;
                if (Config?.options.bar.autoHide.enable) return 0;
                if (!centerOnly) return 0;
                switch (Config.options.bar.cornerStyle) {
                case 0:
                case 4:
                case 6: return -root.barCenterOnlyOffset;
                case 1: return -root.barCenterOnlyOffset + Appearance.sizes.hyprlandGapsOut;
                case 2: return -root.barCenterOnlyOffset + Appearance.sizes.hyprlandGapsOut;
                case 3: return -root.barCenterOnlyOffset - Appearance.sizes.hyprlandGapsOut;
                default: return 0;
                }
            }
        }

        // ============================================================
        // MACOS FLOATING CONTROL CENTER
        // ============================================================
        Item {
            anchors.fill: parent
            visible: root.isMacos

            // Dismiss when clicking in the transparent shadow padding around the popover
            MouseArea {
                anchors.fill: parent
                onClicked: panelWindow.hide()
            }

            Loader {
                id: macContentLoader
                active: root.isMacos && (panelWindow.reallyVisible || Config?.options.sidebar.keepRightSidebarLoaded)
                x: root.macPadLeft
                y: root.macPadTop
                focus: root.isMacos && GlobalStates.sidebarRightOpen

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        if (!item || !item.handleEscape()) {
                            panelWindow.hide();
                        }
                        event.accepted = true;
                    }
                }

                sourceComponent: MacControlCenter {}
            }
        }

        // ============================================================
        // CLASSIC FULL-HEIGHT RIGHT SIDEBAR
        // ============================================================
        Item {
            anchors.fill: parent
            visible: !root.isMacos

            MouseArea {
                id: outsideClickArea
                anchors.fill: parent
                enabled: panelWindow.animatedEntrance
                visible: panelWindow.animatedEntrance
                onClicked: panelWindow.hide()
            }

            Item {
                id: entranceWrapper
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: sidebarWidth
                clip: true

                readonly property bool open: GlobalStates.sidebarRightOpen
                property real cachedParentWidth: sidebarWidth
                readonly property real restX: cachedParentWidth - width
                x: panelWindow.animatedEntrance ? (open ? restX : cachedParentWidth) : restX

                Connections {
                    target: entranceWrapper.parent
                    function onWidthChanged() {
                        if (entranceWrapper.parent.width > 0)
                            entranceWrapper.cachedParentWidth = entranceWrapper.parent.width;
                    }
                }

                Behavior on x {
                    enabled: panelWindow.animatedEntrance
                    NumberAnimation {
                        duration: entranceWrapper.open
                            ? Appearance.animation.sidebarSlideEnter.duration
                            : Appearance.animation.sidebarSlideExit.duration
                        easing.type: entranceWrapper.open
                            ? Appearance.animation.sidebarSlideEnter.type
                            : Appearance.animation.sidebarSlideExit.type
                        easing.bezierCurve: entranceWrapper.open
                            ? Appearance.animation.sidebarSlideEnter.bezierCurve
                            : Appearance.animation.sidebarSlideExit.bezierCurve
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => { mouse.accepted = true }
                    z: -1
                }

                Loader {
                    id: sidebarContentLoader
                    active: !root.isMacos && (panelWindow.reallyVisible || Config?.options.sidebar.keepRightSidebarLoaded)
                    anchors {
                        fill: parent
                        margins: Appearance.sizes.hyprlandGapsOut
                        leftMargin: Appearance.sizes.elevationMargin
                    }
                    width: sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
                    height: parent.height - Appearance.sizes.hyprlandGapsOut * 2

                    focus: !root.isMacos && GlobalStates.sidebarRightOpen
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            panelWindow.hide();
                        }
                    }

                    sourceComponent: SidebarRightContent {}
                }
            }
        }

        IpcHandler {
            target: "sidebarRight"

            function toggle(): void {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }

            function close(): void {
                GlobalStates.sidebarRightOpen = false;
            }

            function open(): void {
                GlobalStates.sidebarRightOpen = true;
            }
        }

        CompositorGlobalShortcut {
            name: "sidebarRightToggle"
            description: "Toggles right sidebar on press"

            onPressed: {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }
        }
        CompositorGlobalShortcut {
            name: "sidebarRightOpen"
            description: "Opens right sidebar on press"

            onPressed: {
                GlobalStates.sidebarRightOpen = true;
            }
        }
        CompositorGlobalShortcut {
            name: "sidebarRightClose"
            description: "Closes right sidebar on press"

            onPressed: {
                GlobalStates.sidebarRightOpen = false;
            }
        }
    }
}
