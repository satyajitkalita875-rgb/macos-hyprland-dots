pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    readonly property bool dark: Appearance.m3colors.darkmode
    readonly property bool glassOn: Config.options?.background?.widgets?.glass?.enable ?? false
    readonly property var macCfg: Config.options?.bar?.macos ?? null
    readonly property bool showBorder: macCfg?.showBorder ?? true
    readonly property bool showLogo: macCfg?.showLogo ?? true
    readonly property bool showActiveApp: macCfg?.showActiveApp ?? true
    readonly property bool showWorkspaces: macCfg?.showWorkspaces ?? true
    readonly property int minWorkspaces: macCfg?.workspaceCount ?? 4
    readonly property bool showTray: macCfg?.showTray ?? true
    readonly property bool showBattery: macCfg?.showBattery ?? true
    readonly property bool showWifi: macCfg?.showWifi ?? true
    readonly property bool showBluetooth: macCfg?.showBluetooth ?? true
    readonly property bool showVolume: macCfg?.showVolume ?? true
    readonly property bool showSpotlight: macCfg?.showSpotlight ?? true
    readonly property bool showControlCenter: macCfg?.showControlCenter ?? true
    readonly property bool showClock: macCfg?.showClock ?? true

    // Unified Material You palette matching Dock, App Drawer, Control Center & Widgets
    readonly property color fgColor: Appearance.colors.colOnLayer0
    readonly property color fgMuted: Appearance.colors.colSubtext
    readonly property color hoverBg: Appearance.colors.colLayer1Hover
    readonly property color activeBg: Appearance.colors.colSecondaryContainer
    readonly property color activeFg: Appearance.colors.colOnSecondaryContainer
    readonly property color accentColor: Appearance.colors.colPrimary
    readonly property color macGreen: dark ? "#30D158" : "#24B948"
    readonly property color macRed: Appearance.colors.colError
    readonly property color macOrange: dark ? "#FF9F0A" : "#E67E00"

    readonly property var monitor: WM.monitorFor(root.QsWindow.window?.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    readonly property bool focusingThisMonitor: WM.focusedMonitor?.name === monitor?.name
    readonly property var biggestWindow: WM.biggestWindowForWorkspace(WM.activeWorkspaceForMonitor(monitor?.name)?.id ?? 1)

    readonly property string activeAppDisplayName: {
        let raw = "";
        if (root.focusingThisMonitor && root.activeWindow?.activated) {
            raw = root.activeWindow.appId || root.biggestWindow?.class || "";
        } else {
            raw = root.biggestWindow?.class || "";
        }
        if (!raw || raw.trim() === "") return Translation.tr("Desktop");

        // Clean reverse-DNS app IDs (e.g. org.gnome.Nautilus -> Nautilus)
        let cleaned = raw.trim();
        if (cleaned.includes(".")) {
            const parts = cleaned.split(".");
            cleaned = parts[parts.length - 1] || cleaned;
        }
        // Replace dashes/underscores with spaces and title-case words
        cleaned = cleaned.replace(/[-_]+/g, " ");
        const prettyMap = {
            "nautilus": "Files",
            "google chrome": "Chrome",
            "chromium": "Chromium",
            "firefox": "Firefox",
            "alacritty": "Alacritty",
            "kitty": "Kitty",
            "code": "VS Code",
            "brave browser": "Brave",
            "dolphin": "Dolphin",
            "zen": "Zen"
        };
        const lower = cleaned.toLowerCase();
        if (prettyMap[lower]) return prettyMap[lower];
        return cleaned.replace(/\b\w/g, c => c.toUpperCase());
    }

    WorkspaceModel {
        id: wsModel
        screen: root.QsWindow.window?.screen
    }

    // Transparent frosted glass macOS Menu Bar matching system Material You surface
    Rectangle {
        id: menuBarBg
        anchors.fill: parent
        color: Appearance.colors.colUiBackground

        WindowGlass {
            anchors.fill: parent
            glassEnabled: root.glassOn
            cardRadius: 0
            tint: parent.color
        }

        // Crisp 1px bottom hairline matching system panel borders
        Rectangle {
            visible: root.showBorder
            anchors {
                left: parent.left
                right: parent.right
                bottom: Config.options.bar.bottom ? undefined : parent.bottom
                top: Config.options.bar.bottom ? parent.top : undefined
            }
            height: 1
            color: ColorUtils.applyAlpha(Appearance.colors.colLayer0Border, 0.65)
        }
    }

    // ============================================================
    // LEFT SIDE: System Logo + Active App Name + Compact Workspaces
    // ============================================================
    RowLayout {
        id: leftSection
        anchors {
            left: parent.left
            leftMargin: 12
            top: parent.top
            bottom: parent.bottom
        }
        spacing: 2

        // System / Distro Logo Menu Button
        MenuBarItem {
            id: logoItem
            visible: root.showLogo
            horizontalPad: 8
            active: GlobalStates.settingsOpen
            tooltip: Translation.tr("Settings • Right-click for Session")
            onClicked: GlobalStates.settingsOpen = !GlobalStates.settingsOpen
            onRightClicked: GlobalStates.sessionOpen = true

            CustomIcon {
                width: 15
                height: 15
                source: Config.options.custom.distroIcon || SystemInfo.distroIcon
                customFolder: Config.options.custom.iconsPath
                colorize: true
                color: root.fgColor
            }
        }

        // Bold Active App Name (classic macOS Finder / App menu title)
        MenuBarItem {
            visible: root.showActiveApp
            horizontalPad: 8
            tooltip: Translation.tr("Overview")
            onClicked: GlobalStates.overviewOpen = !GlobalStates.overviewOpen

            StyledText {
                text: root.activeAppDisplayName
                font.pixelSize: 13
                font.weight: Font.Bold
                color: root.fgColor
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // Subtle separator dot
        Rectangle {
            visible: root.showWorkspaces && (root.showLogo || root.showActiveApp)
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 2
            Layout.rightMargin: 4
            width: 3
            height: 3
            radius: 1.5
            color: root.fgMuted
            opacity: 0.45
        }

        // Compact macOS-style Workspaces Switcher
        Item {
            id: wsContainer
            visible: root.showWorkspaces
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: wsRow.implicitWidth
            implicitHeight: root.height

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    if (wheel.angleDelta.y > 0) WM.switchWorkspaceRelative("prev");
                    else if (wheel.angleDelta.y < 0) WM.switchWorkspaceRelative("next");
                }
            }

            Row {
                id: wsRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: Math.min(wsModel.shownCount, 10)
                    delegate: Item {
                        id: wsItem
                        required property int index
                        readonly property int wsId: wsModel.getWorkspaceIdAt(index)
                        readonly property bool isActive: wsModel.activeNumber === wsId
                        readonly property bool isOccupied: wsModel.occupied[index] ?? false
                        readonly property bool shown: isActive || isOccupied || index < root.minWorkspaces

                        visible: shown
                        width: shown ? 20 : 0
                        height: 20

                        Rectangle {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            radius: 5
                            color: wsItem.isActive
                                ? root.activeBg
                                : (wsMouse.containsMouse ? root.hoverBg : "transparent")
                            border.width: wsItem.isActive ? 1 : 0
                            border.color: Appearance.colors.colLayer0Border

                            Behavior on color { ColorAnimation { duration: 110 } }

                            StyledText {
                                anchors.centerIn: parent
                                text: String(wsItem.wsId)
                                font.pixelSize: 11
                                font.weight: wsItem.isActive ? Font.DemiBold : Font.Medium
                                font.features: ({ "tnum": 1 })
                                color: wsItem.isActive
                                    ? root.activeFg
                                    : (wsItem.isOccupied ? root.fgColor : root.fgMuted)
                                opacity: wsItem.isActive ? 1.0 : (wsItem.isOccupied ? 0.85 : 0.55)
                            }

                            // Tiny occupied dot under non-active occupied workspace
                            Rectangle {
                                visible: wsItem.isOccupied && !wsItem.isActive
                                anchors {
                                    horizontalCenter: parent.horizontalCenter
                                    bottom: parent.bottom
                                    bottomMargin: 1
                                }
                                width: 3
                                height: 3
                                radius: 1.5
                                color: root.fgColor
                                opacity: 0.55
                            }
                        }

                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: WM.switchWorkspace(wsItem.wsId)
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // CENTER NOTCH: Date & Time (MacBook Notch / Dynamic Island)
    // ============================================================
    Item {
        id: clockNotch
        visible: root.showClock
        z: 10
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: Config.options.bar.bottom ? undefined : parent.top
            bottom: Config.options.bar.bottom ? parent.bottom : undefined
        }

        property var today: new Date()
        Timer {
            interval: 60000
            running: true
            repeat: true
            onTriggered: clockNotch.today = new Date()
        }

        readonly property real filletR: 9
        readonly property real notchPad: notchMouse.containsMouse ? 22 : 17
        readonly property color notchColor: root.dark
            ? (notchMouse.containsMouse
                ? ColorUtils.applyAlpha(ColorUtils.mix("#0d0f14", Appearance.colors.colPrimary, 0.90), 0.96)
                : ColorUtils.applyAlpha(ColorUtils.mix("#0d0f14", Appearance.colors.colPrimary, 0.94), 0.92))
            : (notchMouse.containsMouse
                ? ColorUtils.applyAlpha(ColorUtils.mix("#14171f", Appearance.colors.colPrimary, 0.88), 0.92)
                : ColorUtils.applyAlpha(ColorUtils.mix("#14171f", Appearance.colors.colPrimary, 0.93), 0.86))

        width: notchContentRow.implicitWidth + notchPad * 2
        height: root.height + 4

        Behavior on width {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // Left concave notch shoulder fillet
        Shape {
            visible: !Config.options.bar.bottom
            x: -clockNotch.filletR
            y: 0
            width: clockNotch.filletR
            height: clockNotch.filletR
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                fillColor: clockNotch.notchColor
                strokeWidth: -1
                startX: clockNotch.filletR
                startY: 0
                PathLine { x: 0; y: 0 }
                PathArc {
                    x: clockNotch.filletR
                    y: clockNotch.filletR
                    radiusX: clockNotch.filletR
                    radiusY: clockNotch.filletR
                    direction: PathArc.Clockwise
                }
                PathLine { x: clockNotch.filletR; y: 0 }
            }
        }

        // Right concave notch shoulder fillet
        Shape {
            visible: !Config.options.bar.bottom
            x: clockNotch.width
            y: 0
            width: clockNotch.filletR
            height: clockNotch.filletR
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                fillColor: clockNotch.notchColor
                strokeWidth: -1
                startX: 0
                startY: 0
                PathLine { x: clockNotch.filletR; y: 0 }
                PathArc {
                    x: 0
                    y: clockNotch.filletR
                    radiusX: clockNotch.filletR
                    radiusY: clockNotch.filletR
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: 0; y: 0 }
            }
        }

        // Main Notch Body
        Rectangle {
            id: notchBody
            anchors.fill: parent
            topLeftRadius: Config.options.bar.bottom ? 13 : 0
            topRightRadius: Config.options.bar.bottom ? 13 : 0
            bottomLeftRadius: Config.options.bar.bottom ? 0 : 13
            bottomRightRadius: Config.options.bar.bottom ? 0 : 13
            color: clockNotch.notchColor

            Behavior on color { ColorAnimation { duration: 150 } }

            // Subtle glass rim on bottom/sides
            Rectangle {
                anchors {
                    fill: parent
                    topMargin: Config.options.bar.bottom ? 0 : -1
                    bottomMargin: Config.options.bar.bottom ? -1 : 0
                }
                topLeftRadius: parent.topLeftRadius
                topRightRadius: parent.topRightRadius
                bottomLeftRadius: parent.bottomLeftRadius
                bottomRightRadius: parent.bottomRightRadius
                color: "transparent"
                border.width: 1
                border.color: notchMouse.containsMouse
                    ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.45)
                    : Qt.rgba(1, 1, 1, 0.14)

                Behavior on border.color { ColorAnimation { duration: 150 } }
            }

            RowLayout {
                id: notchContentRow
                anchors.centerIn: parent
                anchors.verticalCenterOffset: Config.options.bar.bottom ? 1 : -1
                spacing: 7

                StyledText {
                    visible: Config.options.time.showDate
                    text: Qt.locale().toString(DateTime.clock.date, "ddd d MMM")
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Qt.rgba(1, 1, 1, 0.84)
                }

                Rectangle {
                    visible: Config.options.time.showDate
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 3
                    Layout.preferredHeight: 3
                    radius: 1.5
                    color: Qt.rgba(1, 1, 1, 0.42)
                }

                StyledText {
                    text: DateTime.time
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    font.features: ({ "tnum": 1 })
                    color: "#ffffff"
                }

                // Unread notifications dot
                Rectangle {
                    visible: Notifications.unread > 0 && !Notifications.silent
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 5
                    Layout.preferredHeight: 5
                    radius: 2.5
                    color: root.accentColor
                }
            }
        }

        MouseArea {
            id: notchMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
        }

        ClockWidgetPopup {
            hoverTarget: notchMouse
            today: clockNotch.today
        }
    }

    // ============================================================
    // RIGHT SIDE: Tray + Status Icons + Battery + Controls
    // ============================================================
    RowLayout {
        id: rightSection
        anchors {
            right: parent.right
            rightMargin: 10
            top: parent.top
            bottom: parent.bottom
        }
        spacing: 1

        // 1. System Tray (only takes space when tray apps exist)
        SysTray {
            visible: root.showTray && SystemTray.items.values.length > 0
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: 2
            contentColor: root.fgColor
            contentColorOverridden: true
            implicitHeight: root.height
        }

        // 2. Recording Indicator (only when recording)
        MenuBarItem {
            visible: Config.options.bar.utilButtons.isRecording
            horizontalPad: 6
            tooltip: Translation.tr("Screen recording active")
            onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: root.macRed
            }
        }

        // 3. Mic Muted Indicator (when mic is muted)
        MenuBarItem {
            visible: Audio.source?.audio?.muted ?? false
            horizontalPad: 6
            tooltip: Translation.tr("Microphone muted • Click to unmute")
            onClicked: Audio.toggleMicMute()

            MaterialSymbol {
                text: "mic_off"
                iconSize: 15
                color: root.macOrange
            }
        }

        // 4. Keyboard Layout (sleek macOS badge, matches bar foreground color)
        MenuBarItem {
            id: xkbItem
            readonly property string layoutCode: (WM.compositor === "niri" ? NiriXkb.currentLayoutCode : HyprlandXkb.currentLayoutCode) ?? ""
            visible: layoutCode.length > 0 && ((WM.compositor === "niri" ? (NiriXkb.layoutCodes?.length ?? 1) : (HyprlandXkb.layoutCodes?.length ?? 1)) > 1)
            horizontalPad: 6
            tooltip: Translation.tr("Keyboard layout")

            StyledText {
                text: xkbItem.layoutCode.toUpperCase()
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: root.fgColor
            }
        }

        // 5. Battery with Charging Indicator + Hover Popup
        MenuBarItem {
            id: batteryItem
            visible: root.showBattery && Battery.available
            horizontalPad: 7
            onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen

            readonly property real pct: Math.max(0, Math.min(1, Battery.percentage))
            readonly property int pctInt: Math.round(pct * 100)
            readonly property bool charging: Battery.isCharging
            readonly property bool fullyCharged: Battery.chargeState === UPowerDeviceState.FullyCharged || Battery.chargeState === 4
            readonly property bool pluggedIn: Battery.isPluggedIn || fullyCharged
            readonly property bool low: Battery.isLow && !charging && !pluggedIn

            RowLayout {
                spacing: 5

                // Percentage readout
                StyledText {
                    visible: Config.options.bar.battery.showPercentage
                    text: `${batteryItem.pctInt}%`
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.features: ({ "tnum": 1 })
                    color: batteryItem.low ? root.macRed : root.fgColor
                }

                // Authentic macOS Horizontal Battery Glyph + Charging Bolt
                Item {
                    implicitWidth: 27
                    implicitHeight: 13

                    // Outer rounded battery shell
                    Rectangle {
                        id: battShell
                        width: 24
                        height: 12
                        radius: 3.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"
                        border.width: 1.2
                        border.color: batteryItem.low
                            ? root.macRed
                            : Qt.alpha(root.fgColor, 0.72)

                        // Charge level fill bar
                        Rectangle {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                                margins: 2
                            }
                            width: Math.max(2, (parent.width - 4) * batteryItem.pct)
                            radius: 1.8
                            color: (batteryItem.charging || batteryItem.pluggedIn)
                                ? root.macGreen
                                : (batteryItem.low ? root.macRed : root.fgColor)

                            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }

                        // Charging bolt / AC plug indicator centered over battery
                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: Config.options.bar.battery.showCharging && (batteryItem.charging || batteryItem.pluggedIn)
                            text: batteryItem.charging ? "bolt" : "bolt"
                            fill: 1
                            iconSize: 12
                            color: "#101012"
                        }
                    }

                    // Battery positive terminal nub
                    Rectangle {
                        anchors {
                            left: battShell.right
                            leftMargin: 1
                            verticalCenter: battShell.verticalCenter
                        }
                        width: 2
                        height: 4.5
                        radius: 1
                        color: batteryItem.low
                            ? root.macRed
                            : Qt.alpha(root.fgColor, 0.62)
                    }
                }
            }

            BatteryPopup {
                hoverTarget: batteryItem.mouseArea
            }
        }

        // 6. Wi-Fi / Network Icon
        MenuBarItem {
            visible: root.showWifi
            horizontalPad: 6
            tooltip: Network.wifiEnabled
                ? (Network.networkName || Translation.tr("Wi-Fi On"))
                : Translation.tr("Wi-Fi Off")
            onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen

            MaterialSymbol {
                text: Network.materialSymbol
                iconSize: 16
                color: root.fgColor
                opacity: (Network.wifiEnabled || Network.ethernet) ? 1.0 : 0.45
            }
        }

        // 7. Bluetooth Icon
        MenuBarItem {
            visible: root.showBluetooth && BluetoothStatus.available
            horizontalPad: 6
            tooltip: BluetoothStatus.enabled
                ? (BluetoothStatus.firstActiveDevice?.name ?? Translation.tr("Bluetooth On"))
                : Translation.tr("Bluetooth Off")
            onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen

            MaterialSymbol {
                text: BluetoothStatus.connected
                    ? "bluetooth_connected"
                    : (BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled")
                iconSize: 15
                color: root.fgColor
                opacity: BluetoothStatus.enabled ? 1.0 : 0.45
            }
        }

        // 8. Volume Icon (scroll to adjust volume, right-click to mute, left-click for Control Center)
        MenuBarItem {
            visible: root.showVolume
            horizontalPad: 6
            tooltip: (Audio.sink?.audio?.muted ?? false)
                ? Translation.tr("Muted • Scroll to adjust")
                : `${Translation.tr("Volume")}: ${Math.round((Audio.sink?.audio?.volume ?? 0) * 100)}%`
            onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
            onRightClicked: Audio.toggleMute()
            onWheelUp: Audio.incrementVolume()
            onWheelDown: Audio.decrementVolume()

            MaterialSymbol {
                text: (Audio.sink?.audio?.muted ?? false)
                    ? "volume_off"
                    : ((Audio.sink?.audio?.volume ?? 0) < 0.01
                        ? "volume_mute"
                        : ((Audio.sink?.audio?.volume ?? 0) < 0.5 ? "volume_down" : "volume_up"))
                iconSize: 16
                color: root.fgColor
                opacity: (Audio.sink?.audio?.muted ?? false) ? 0.50 : 1.0
            }
        }

        // 9. Spotlight Search Icon
        MenuBarItem {
            visible: root.showSpotlight
            horizontalPad: 6
            active: GlobalStates.overviewOpen
            tooltip: Translation.tr("Spotlight Search")
            onClicked: GlobalStates.overviewOpen = !GlobalStates.overviewOpen

            MaterialSymbol {
                text: "search"
                iconSize: 16
                color: root.fgColor
            }
        }

        // 10. Iconic macOS Control Center Dual-Toggle Icon
        MenuBarItem {
            visible: root.showControlCenter
            horizontalPad: 7
            active: GlobalStates.sidebarRightOpen
            tooltip: Translation.tr("Control Center")
            onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen

            Item {
                width: 15
                height: 13

                // Top pill switch (knob left, unfilled)
                Rectangle {
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    height: 6
                    radius: 3
                    color: "transparent"
                    border.width: 1.15
                    border.color: root.fgColor

                    Rectangle {
                        width: 4
                        height: 4
                        radius: 2
                        anchors {
                            left: parent.left
                            leftMargin: 1
                            verticalCenter: parent.verticalCenter
                        }
                        color: root.fgColor
                    }
                }

                // Bottom pill switch (outline, solid knob right)
                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                    }
                    height: 6
                    radius: 3
                    color: "transparent"
                    border.width: 1.15
                    border.color: root.fgColor

                    Rectangle {
                        width: 4
                        height: 4
                        radius: 2
                        anchors {
                            right: parent.right
                            rightMargin: 1
                            verticalCenter: parent.verticalCenter
                        }
                        color: root.fgColor
                    }
                }
            }
        }

        // 11. Focus / Do Not Disturb Icon (shown when active)
        MenuBarItem {
            visible: Notifications.silent
            horizontalPad: 6
            tooltip: Translation.tr("Do Not Disturb • Click to turn off")
            onClicked: Notifications.silent = false

            MaterialSymbol {
                text: "bedtime"
                fill: 1
                iconSize: 14
                color: root.fgColor
            }
        }
    }

    // ============================================================
    // REUSABLE MACOS MENU BAR ITEM WRAPPER
    // ============================================================
    component MenuBarItem: Item {
        id: itemRoot
        default property alias content: innerContainer.data
        property int horizontalPad: 7
        property bool active: false
        property string tooltip: ""
        readonly property alias mouseArea: itemMouse

        signal clicked()
        signal rightClicked()
        signal wheelUp()
        signal wheelDown()

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: innerContainer.implicitWidth + horizontalPad * 2
        implicitHeight: root.height

        Rectangle {
            anchors {
                fill: parent
                topMargin: 3
                bottomMargin: 3
            }
            radius: 5
            color: itemRoot.active
                ? root.activeBg
                : (itemMouse.pressed
                    ? root.activeBg
                    : (itemMouse.containsMouse ? root.hoverBg : "transparent"))

            Behavior on color { ColorAnimation { duration: 100 } }
        }

        Row {
            id: innerContainer
            anchors.centerIn: parent
        }

        MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) itemRoot.rightClicked();
                else itemRoot.clicked();
            }
            onWheel: wheel => {
                if (wheel.angleDelta.y > 0) itemRoot.wheelUp();
                else if (wheel.angleDelta.y < 0) itemRoot.wheelDown();
            }
        }

        PopupToolTip {
            extraVisibleCondition: itemRoot.tooltip.length > 0 && itemMouse.containsMouse
            alternativeVisibleCondition: extraVisibleCondition
            anchorEdges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
            text: itemRoot.tooltip
        }
    }
}
