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
                SessionWarnings.refresh();
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

            // Frosted dark scrim backdrop (Hyprland blurs everything behind this layer)
            Rectangle {
                id: backdrop
                anchors.fill: parent
                color: Qt.rgba(0.04, 0.05, 0.08, sessionRoot.dark ? 0.42 : 0.18)
                opacity: 0

                MouseArea {
                    anchors.fill: parent
                    onClicked: sessionRoot.hide()
                }
            }

            // Animated modal container
            Item {
                id: modalWrapper
                anchors.centerIn: parent
                implicitWidth: modalCard.implicitWidth
                implicitHeight: modalCard.implicitHeight
                opacity: 0

                transform: [
                    Scale {
                        id: modalScale
                        origin.x: modalWrapper.width / 2
                        origin.y: modalWrapper.height * 0.35
                        xScale: 0.86
                        yScale: 0.78
                    },
                    Translate {
                        id: modalTranslate
                        y: -14
                    }
                ]

                // Soft elevated shadow
                RectangularShadow {
                    anchors.fill: modalCard
                    radius: modalCard.radius
                    blur: 36
                    spread: 0
                    offset: Qt.vector2d(0, 14)
                    color: ColorUtils.applyAlpha(Appearance.m3colors.m3shadow, sessionRoot.dark ? 0.42 : 0.24)
                    cached: false
                }

                // Modern macOS / Material You Frosted Glass Card
                Rectangle {
                    id: modalCard
                    implicitWidth: cardLayout.implicitWidth + 44
                    implicitHeight: cardLayout.implicitHeight + 40
                    radius: 26
                    clip: true
                    color: Appearance.colors.colUiBackground
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border

                    WindowGlass {
                        anchors.fill: parent
                        glassEnabled: sessionRoot.glassOn
                        cardRadius: parent.radius
                        tint: parent.color
                    }

                    // macOS inner glass rim highlight
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: parent.radius - 1
                        color: "transparent"
                        border.width: 1
                        border.color: sessionRoot.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.58)
                        z: 20
                    }

                    // Swallow clicks inside the card
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {}
                    }

                    ColumnLayout {
                        id: cardLayout
                        anchors.centerIn: parent
                        spacing: 18

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                sessionRoot.hide();
                                event.accepted = true;
                            }
                        }

                        // Header: User Avatar + Name + Uptime + Close button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                radius: 19
                                color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, sessionRoot.dark ? 0.24 : 0.16)
                                border.width: 1
                                border.color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.35)

                                StyledText {
                                    anchors.centerIn: parent
                                    text: (SystemInfo.username && SystemInfo.username.length > 0)
                                        ? SystemInfo.username.charAt(0).toUpperCase()
                                        : "U"
                                    font.pixelSize: 16
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colPrimary
                                }
                            }

                            ColumnLayout {
                                spacing: 1

                                StyledText {
                                    text: SystemInfo.username || Translation.tr("Session")
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnLayer0
                                }

                                StyledText {
                                    text: `${Translation.tr("Power & Session")}  •  ${Translation.tr("Up")} ${DateTime.uptime}`
                                    font.pixelSize: 12
                                    color: Appearance.colors.colSubtext
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Subtle Esc keycap hint
                            Rectangle {
                                Layout.preferredWidth: escText.implicitWidth + 14
                                Layout.preferredHeight: 24
                                radius: 7
                                color: Appearance.colors.colLayer1
                                border.width: 1
                                border.color: ColorUtils.applyAlpha(Appearance.colors.colLayer0Border, 0.7)

                                StyledText {
                                    id: escText
                                    anchors.centerIn: parent
                                    text: "ESC"
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colSubtext
                                }
                            }

                            // Circular Close Button
                            Rectangle {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                radius: 15
                                color: closeMouse.containsMouse ? Appearance.colors.colLayer2 : Appearance.colors.colLayer1
                                border.width: 1
                                border.color: ColorUtils.applyAlpha(Appearance.colors.colLayer0Border, 0.7)

                                Behavior on color { ColorAnimation { duration: 120 } }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: 16
                                    color: Appearance.colors.colOnLayer0
                                }

                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: sessionRoot.hide()
                                }
                            }
                        }

                        // Subtle divider hairline
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: ColorUtils.applyAlpha(Appearance.colors.colLayer0Border, 0.5)
                        }

                        // 2x4 Modern Glass Action Grid
                        GridLayout {
                            columns: 4
                            columnSpacing: 12
                            rowSpacing: 12

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
                                KeyNavigation.down: sessionHibernate
                            }

                            SessionActionButton {
                                id: sessionSleep
                                buttonIcon: "bedtime"
                                buttonText: Translation.tr("Sleep")
                                accentColor: sessionRoot.dark ? "#A78BFA" : "#6D28D9"
                                onClicked: {
                                    Session.suspend();
                                    sessionRoot.hide();
                                }
                                KeyNavigation.left: sessionLock
                                KeyNavigation.right: sessionLogout
                                KeyNavigation.down: sessionShutdown
                            }

                            SessionActionButton {
                                id: sessionLogout
                                buttonIcon: "logout"
                                buttonText: Translation.tr("Log Out")
                                accentColor: sessionRoot.dark ? "#FBBF24" : "#D97706"
                                onClicked: {
                                    Session.logout();
                                    sessionRoot.hide();
                                }
                                KeyNavigation.left: sessionSleep
                                KeyNavigation.right: sessionTaskManager
                                KeyNavigation.down: sessionReboot
                            }

                            SessionActionButton {
                                id: sessionTaskManager
                                buttonIcon: "monitoring"
                                buttonText: Translation.tr("System Monitor")
                                accentColor: sessionRoot.dark ? "#34D399" : "#059669"
                                onClicked: {
                                    Session.launchTaskManager();
                                    sessionRoot.hide();
                                }
                                KeyNavigation.left: sessionLogout
                                KeyNavigation.down: sessionFirmwareReboot
                            }

                            SessionActionButton {
                                id: sessionHibernate
                                buttonIcon: "downloading"
                                buttonText: Translation.tr("Hibernate")
                                accentColor: sessionRoot.dark ? "#60A5FA" : "#2563EB"
                                onClicked: {
                                    Session.hibernate();
                                    sessionRoot.hide();
                                }
                                KeyNavigation.up: sessionLock
                                KeyNavigation.right: sessionShutdown
                            }

                            SessionActionButton {
                                id: sessionShutdown
                                buttonIcon: "power_settings_new"
                                buttonText: Translation.tr("Shut Down")
                                accentColor: sessionRoot.dark ? "#FF5C5C" : "#DC2626"
                                isDestructive: true
                                onClicked: {
                                    Session.poweroff();
                                    sessionRoot.hide();
                                }
                                KeyNavigation.left: sessionHibernate
                                KeyNavigation.right: sessionReboot
                                KeyNavigation.up: sessionSleep
                            }

                            SessionActionButton {
                                id: sessionReboot
                                buttonIcon: "restart_alt"
                                buttonText: Translation.tr("Restart")
                                accentColor: sessionRoot.dark ? "#FB923C" : "#EA580C"
                                onClicked: {
                                    Session.reboot();
                                    sessionRoot.hide();
                                }
                                KeyNavigation.left: sessionShutdown
                                KeyNavigation.right: sessionFirmwareReboot
                                KeyNavigation.up: sessionLogout
                            }

                            SessionActionButton {
                                id: sessionFirmwareReboot
                                buttonIcon: "memory"
                                buttonText: Translation.tr("UEFI / BIOS")
                                accentColor: Appearance.colors.colSubtext
                                onClicked: {
                                    Session.rebootToFirmware();
                                    sessionRoot.hide();
                                }
                                KeyNavigation.up: sessionTaskManager
                                KeyNavigation.left: sessionReboot
                            }
                        }

                        // Inline Warnings (if download or package manager active)
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: SessionWarnings.downloadRunning || SessionWarnings.packageManagerRunning
                            spacing: 6

                            WarningBanner {
                                visible: SessionWarnings.downloadRunning
                                text: Translation.tr("A download may still be in progress. Check your Downloads folder.")
                            }

                            WarningBanner {
                                visible: SessionWarnings.packageManagerRunning
                                text: Translation.tr("Your package manager is currently running.")
                            }
                        }
                    }
                }
            }

            // Expressive bouncy pop-in animation matching bar popups
            ParallelAnimation {
                id: openAnim
                running: true
                NumberAnimation {
                    target: backdrop
                    property: "opacity"
                    to: 1
                    duration: 240
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: modalWrapper
                    property: "opacity"
                    to: 1
                    duration: Appearance.animationCurves.expressiveEffectsDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveEffects
                }
                NumberAnimation {
                    target: modalScale
                    property: "yScale"
                    to: 1
                    duration: 460
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                }
                NumberAnimation {
                    target: modalScale
                    property: "xScale"
                    to: 1
                    duration: Appearance.animationCurves.expressiveDefaultSpatialDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                }
                NumberAnimation {
                    target: modalTranslate
                    property: "y"
                    to: 0
                    duration: Appearance.animationCurves.expressiveDefaultSpatialDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                }
            }

            ParallelAnimation {
                id: closeAnim
                onFinished: root.closing = false
                NumberAnimation {
                    target: backdrop
                    property: "opacity"
                    to: 0
                    duration: 180
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: modalWrapper
                    property: "opacity"
                    to: 0
                    duration: 170
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
                }
                NumberAnimation {
                    target: modalScale
                    property: "yScale"
                    to: 0.84
                    duration: 190
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
                }
                NumberAnimation {
                    target: modalScale
                    property: "xScale"
                    to: 0.90
                    duration: 190
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
                }
                NumberAnimation {
                    target: modalTranslate
                    property: "y"
                    to: -10
                    duration: 180
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
                }
            }
        }
    }

    component WarningBanner: Rectangle {
        id: warnBanner
        property string text: ""
        Layout.fillWidth: true
        implicitHeight: warnRow.implicitHeight + 14
        radius: 12
        color: ColorUtils.applyAlpha(Appearance.m3colors.m3errorContainer, 0.82)
        border.width: 1
        border.color: ColorUtils.applyAlpha(Appearance.colors.colError, 0.45)

        RowLayout {
            id: warnRow
            anchors {
                fill: parent
                leftMargin: 12
                rightMargin: 12
            }
            spacing: 8

            MaterialSymbol {
                text: "warning"
                fill: 1
                iconSize: 16
                color: Appearance.m3colors.m3onErrorContainer
            }

            StyledText {
                Layout.fillWidth: true
                text: warnBanner.text
                font.pixelSize: 12
                color: Appearance.m3colors.m3onErrorContainer
                wrapMode: Text.WordWrap
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
