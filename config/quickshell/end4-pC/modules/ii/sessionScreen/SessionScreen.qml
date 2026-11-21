import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property string focusedScreenName: WM.compositor === "niri"
        ? (NiriBackend.focusedMonitor?.name ?? "")
        : (Hyprland.focusedMonitor?.name ?? "")

    property var focusedScreen: Quickshell.screens.find(s => s.name === root.focusedScreenName)
        ?? Quickshell.screens[0]

    property bool closing: false

    Connections {
        target: GlobalStates
        function onSessionOpenChanged() {
            if (GlobalStates.sessionOpen) {
                root.closing = false;
            } else if (sessionLoader.item) {
                root.closing = true;
            }
        }
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked) {
                GlobalStates.sessionOpen = false;
            }
        }
    }

    Loader {
        id: sessionLoader
        active: GlobalStates.sessionOpen || root.closing

        sourceComponent: PanelWindow {
            id: sessionRoot
            screen: root.focusedScreen
            visible: true

            readonly property bool dark: Appearance.m3colors.darkmode
            readonly property bool glassOn: Config.options?.background?.widgets?.glass?.enable ?? false
            readonly property bool isOpen: GlobalStates.sessionOpen

            function hide() {
                GlobalStates.sessionOpen = false;
            }

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:session"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Connections {
                target: GlobalStates
                function onSessionOpenChanged() {
                    if (GlobalStates.sessionOpen) {
                        closeAnim.stop();
                        openAnim.restart();
                    } else {
                        openAnim.stop();
                        closeAnim.restart();
                    }
                }
            }

            // Frosted scrim backdrop (Hyprland blurs everything behind this layer)
            Rectangle {
                id: backdrop
                anchors.fill: parent
                color: Qt.rgba(0.03, 0.04, 0.07, sessionRoot.dark ? 0.52 : 0.38)
                opacity: 0

                MouseArea {
                    anchors.fill: parent
                    onClicked: sessionRoot.hide()
                }
            }

            // Minimal floating action row (no outer box)
            Item {
                id: modalWrapper
                anchors.centerIn: parent
                implicitWidth: actionRow.implicitWidth
                implicitHeight: actionRow.implicitHeight
                opacity: 0

                transform: [
                    Scale {
                        id: modalScale
                        origin.x: modalWrapper.width / 2
                        origin.y: modalWrapper.height / 2
                        xScale: 0.92
                        yScale: 0.92
                    },
                    Translate {
                        id: modalTranslate
                        y: 8
                    }
                ]

                RowLayout {
                    id: actionRow
                    anchors.centerIn: parent
                    spacing: 28

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            sessionRoot.hide();
                            event.accepted = true;
                        }
                    }

                    SessionActionButton {
                        id: sessionLock
                        focus: sessionRoot.isOpen
                        buttonIcon: "lock"
                        buttonText: Translation.tr("Lock")
                        accentColor: Appearance.colors.colPrimary
                        onClicked: {
                            Session.lock();
                            sessionRoot.hide();
                        }
                        KeyNavigation.right: sessionSleep
                    }

                    SessionActionButton {
                        id: sessionSleep
                        buttonIcon: "bedtime"
                        buttonText: Translation.tr("Sleep")
                        accentColor: "#8B5CF6"
                        onClicked: {
                            Session.suspend();
                            sessionRoot.hide();
                        }
                        KeyNavigation.left: sessionLock
                        KeyNavigation.right: sessionLogout
                    }

                    SessionActionButton {
                        id: sessionLogout
                        buttonIcon: "logout"
                        buttonText: Translation.tr("Log Out")
                        accentColor: "#F59E0B"
                        onClicked: {
                            Session.logout();
                            sessionRoot.hide();
                        }
                        KeyNavigation.left: sessionSleep
                        KeyNavigation.right: sessionReboot
                    }

                    SessionActionButton {
                        id: sessionReboot
                        buttonIcon: "restart_alt"
                        buttonText: Translation.tr("Restart")
                        accentColor: "#F97316"
                        onClicked: {
                            Session.reboot();
                            sessionRoot.hide();
                        }
                        KeyNavigation.left: sessionLogout
                        KeyNavigation.right: sessionShutdown
                    }

                    SessionActionButton {
                        id: sessionShutdown
                        buttonIcon: "power_settings_new"
                        buttonText: Translation.tr("Shut Down")
                        accentColor: "#EF4444"
                        isDestructive: true
                        onClicked: {
                            Session.poweroff();
                            sessionRoot.hide();
                        }
                        KeyNavigation.left: sessionReboot
                    }
                }
            }

            // Symmetric expressive pop-in / pop-out animations
            ParallelAnimation {
                id: openAnim
                running: true
                NumberAnimation {
                    target: backdrop
                    property: "opacity"
                    to: 1
                    duration: 220
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: modalWrapper
                    property: "opacity"
                    to: 1
                    duration: 220
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveEffects
                }
                NumberAnimation {
                    target: modalScale
                    property: "yScale"
                    to: 1
                    duration: 280
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                }
                NumberAnimation {
                    target: modalScale
                    property: "xScale"
                    to: 1
                    duration: 260
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                }
                NumberAnimation {
                    target: modalTranslate
                    property: "y"
                    to: 0
                    duration: 260
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                }
            }

            ParallelAnimation {
                id: closeAnim
                onFinished: root.closing = false
                NumberAnimation {
                    target: backdrop
                    property: "opacity"
                    to: 0
                    duration: 220
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: modalWrapper
                    property: "opacity"
                    to: 0
                    duration: 220
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveEffects
                }
                NumberAnimation {
                    target: modalScale
                    property: "yScale"
                    to: 0.92
                    duration: 180
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: modalScale
                    property: "xScale"
                    to: 0.92
                    duration: 180
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: modalTranslate
                    property: "y"
                    to: 8
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    IpcHandler {
        target: "session"

        function toggle(): void {
            GlobalStates.sessionOpen = !GlobalStates.sessionOpen;
        }

        function close(): void {
            GlobalStates.sessionOpen = false;
        }

        function open(): void {
            GlobalStates.sessionOpen = true;
        }
    }

    CompositorGlobalShortcut {
        name: "sessionToggle"
        description: "Toggles session screen on press"

        onPressed: {
            if (Config.options.bar.layouts.middleLayout.includes("dynamicIsland")) {
                GlobalStates.diSessionOpen = !GlobalStates.diSessionOpen;
            } else {
                GlobalStates.sessionOpen = !GlobalStates.sessionOpen;
            }
        }
    }

    CompositorGlobalShortcut {
        name: "sessionOpen"
        description: "Opens session screen on press"

        onPressed: {
            GlobalStates.sessionOpen = true;
        }
    }

    CompositorGlobalShortcut {
        name: "sessionClose"
        description: "Closes session screen on press"

        onPressed: {
            GlobalStates.sessionOpen = false;
        }
    }
}
