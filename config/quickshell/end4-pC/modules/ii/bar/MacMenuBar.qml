pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
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

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool hasMedia: root.activePlayer !== null && ((root.activePlayer.trackTitle ?? "").trim().length > 0 || (root.activePlayer.identity ?? "").trim().length > 0)

    // Unified dark obsidian notch palette with subtle Material You accent tint
    readonly property color notchBaseColor: dark
        ? ColorUtils.applyAlpha(ColorUtils.mix("#0d0f14", Appearance.colors.colPrimary, 0.94), 0.92)
        : ColorUtils.applyAlpha(ColorUtils.mix("#14171f", Appearance.colors.colPrimary, 0.93), 0.88)
    readonly property color notchHoverColor: dark
        ? ColorUtils.applyAlpha(ColorUtils.mix("#0d0f14", Appearance.colors.colPrimary, 0.90), 0.96)
        : ColorUtils.applyAlpha(ColorUtils.mix("#14171f", Appearance.colors.colPrimary, 0.88), 0.93)

    // Crisp high-contrast foreground colors inside the 3 notches
    readonly property color fgColor: "#f5f7fa"
    readonly property color fgMuted: Qt.rgba(1, 1, 1, 0.62)
    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.14)
    readonly property color activeBg: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.34)
    readonly property color activeFg: "#ffffff"
    readonly property color accentColor: Appearance.colors.colPrimary
    readonly property color macGreen: "#30D158"
    readonly property color macRed: "#FF5C5C"
    readonly property color macOrange: "#FF9F0A"

    readonly property real notchHeight: root.height + 4

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

        let cleaned = raw.trim();
        if (cleaned.includes(".")) {
            const parts = cleaned.split(".");
            cleaned = parts[parts.length - 1] || cleaned;
        }
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

    // ============================================================
    // LEFT NOTCH: System Logo + Active App Name + Workspaces
    // ============================================================
    NotchIsland {
        id: leftNotch
        visible: root.showLogo || root.showActiveApp || root.showWorkspaces
        anchors {
            left: parent.left
            leftMargin: 12
            top: Config.options.bar.bottom ? undefined : parent.top
            bottom: Config.options.bar.bottom ? parent.bottom : undefined
        }
        horizontalPad: 10

        RowLayout {
            id: leftSection
            spacing: 2

            // System / Distro Logo Menu Button
            MenuBarItem {
                id: logoItem
                visible: root.showLogo
                horizontalPad: 7
                active: GlobalStates.settingsOpen
                tooltip: Translation.tr("Settings • Right-click for Power Menu")
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

            // Bold Active App Name
            MenuBarItem {
                visible: root.showActiveApp
                horizontalPad: 7
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
                Layout.preferredWidth: 3
                Layout.preferredHeight: 3
                radius: 1.5
                color: root.fgMuted
                opacity: 0.65
            }

            // Compact Workspaces Switcher
            Item {
                id: wsContainer
                visible: root.showWorkspaces
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: wsRow.implicitWidth
                implicitHeight: root.notchHeight

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
                                border.color: ColorUtils.applyAlpha(root.accentColor, 0.65)

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
                                    opacity: wsItem.isActive ? 1.0 : (wsItem.isOccupied ? 0.90 : 0.60)
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
                                    opacity: 0.60
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
    }

    // ============================================================
    // CENTER NOTCH: Dynamic Island (Date & Time + Live Media Player)
    // ============================================================
    NotchIsland {
        id: centerNotch
        visible: root.showClock || root.hasMedia
        z: 10
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: Config.options.bar.bottom ? undefined : parent.top
            bottom: Config.options.bar.bottom ? parent.bottom : undefined
        }
        horizontalPad: (dateMouse.containsMouse || mediaHover.containsMouse) ? 16 : 13
        highlighted: dateMouse.containsMouse || mediaHover.containsMouse

        property var today: new Date()
        Timer {
            interval: 60000
            running: true
            repeat: true
            onTriggered: centerNotch.today = new Date()
        }

        RowLayout {
            spacing: 10

            // Date & Time interactive zone (hover -> frosted Calendar popup, click -> Control Center)
            Item {
                id: dateZone
                visible: root.showClock
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: dateRow.implicitWidth + 6
                implicitHeight: root.notchHeight

                RowLayout {
                    id: dateRow
                    anchors.centerIn: parent
                    spacing: 6

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

                MouseArea {
                    id: dateMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen
                }

                ClockWidgetPopup {
                    hoverTarget: dateMouse
                    today: centerNotch.today
                }
            }

            // Divider between Date & Now Playing
            Rectangle {
                visible: root.showClock && root.hasMedia
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 1
                Layout.preferredHeight: 14
                radius: 0.5
                color: Qt.rgba(1, 1, 1, 0.20)
            }

            // Live Now Playing Media Player inside the Center Notch
            Item {
                id: mediaZone
                visible: root.hasMedia
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: mediaRow.implicitWidth
                implicitHeight: root.notchHeight

                MouseArea {
                    id: mediaHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0) Audio.incrementVolume();
                        else if (wheel.angleDelta.y < 0) Audio.decrementVolume();
                    }
                }

                RowLayout {
                    id: mediaRow
                    anchors.centerIn: parent
                    spacing: 6

                    // Album Art Thumbnail (with rounded mask & icon fallback)
                    Item {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 19
                        Layout.preferredHeight: 19

                        Rectangle {
                            id: artFallback
                            anchors.fill: parent
                            radius: 5
                            color: ColorUtils.applyAlpha(root.accentColor, 0.28)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.18)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "music_note"
                                iconSize: 12
                                color: "#ffffff"
                            }
                        }

                        Image {
                            id: notchArtImg
                            anchors.fill: parent
                            source: root.activePlayer?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                            asynchronous: true
                            cache: true
                        }

                        Rectangle {
                            id: notchArtMask
                            anchors.fill: parent
                            radius: 5
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: notchArtImg
                            maskSource: notchArtMask
                            visible: notchArtImg.status === Image.Ready
                        }

                        // Tiny green live playing dot on bottom-right of album art
                        Rectangle {
                            visible: root.activePlayer?.isPlaying ?? false
                            anchors {
                                right: parent.right
                                bottom: parent.bottom
                                margins: -1
                            }
                            width: 6
                            height: 6
                            radius: 3
                            color: root.macGreen
                            border.width: 1
                            border.color: "#12151d"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activePlayer?.togglePlaying()
                        }
                    }

                    // Compact Track Title
                    StyledText {
                        id: trackTitleText
                        Layout.alignment: Qt.AlignVCenter
                        Layout.maximumWidth: 140
                        text: root.activePlayer
                            ? (StringUtils.cleanMusicTitle(root.activePlayer.trackTitle) || root.activePlayer.identity || Translation.tr("Now Playing"))
                            : ""
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        color: (root.activePlayer?.isPlaying ?? false) ? "#ffffff" : Qt.rgba(1, 1, 1, 0.72)
                        elide: Text.ElideRight
                        maximumLineCount: 1

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activePlayer?.togglePlaying()
                        }
                    }

                    // Compact Inline Media Transport Buttons (Prev / Play-Pause / Next)
                    Row {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        NotchMediaBtn {
                            icon: "skip_previous"
                            iconSz: 14
                            onClicked: root.activePlayer?.previous()
                        }

                        NotchMediaBtn {
                            icon: (root.activePlayer?.isPlaying ?? false) ? "pause" : "play_arrow"
                            iconSz: 15
                            filled: true
                            accent: true
                            onClicked: root.activePlayer?.togglePlaying()
                        }

                        NotchMediaBtn {
                            icon: "skip_next"
                            iconSz: 14
                            onClicked: root.activePlayer?.next()
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // RIGHT NOTCH: Tray + Status Icons + Battery + Controls
    // ============================================================
    NotchIsland {
        id: rightNotch
        visible: root.showTray || root.showBattery || root.showWifi || root.showBluetooth || root.showVolume || root.showSpotlight || root.showControlCenter
        anchors {
            right: parent.right
            rightMargin: 12
            top: Config.options.bar.bottom ? undefined : parent.top
            bottom: Config.options.bar.bottom ? parent.bottom : undefined
        }
        horizontalPad: 10

        RowLayout {
            id: rightSection
            spacing: 1

            // 1. System Tray
            SysTray {
                visible: root.showTray && SystemTray.items.values.length > 0
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 2
                contentColor: root.fgColor
                contentColorOverridden: true
                implicitHeight: root.notchHeight
            }

            // 2. Recording Indicator
            MenuBarItem {
                visible: Config.options.bar.utilButtons.isRecording
                horizontalPad: 5
                tooltip: Translation.tr("Screen recording active")
                onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: root.macRed
                }
            }

            // 3. Mic Muted Indicator
            MenuBarItem {
                visible: Audio.source?.audio?.muted ?? false
                horizontalPad: 5
                tooltip: Translation.tr("Microphone muted • Click to unmute")
                onClicked: Audio.toggleMicMute()

                MaterialSymbol {
                    text: "mic_off"
                    iconSize: 15
                    color: root.macOrange
                }
            }

            // 4. Keyboard Layout
            MenuBarItem {
                id: xkbItem
                readonly property string layoutCode: (WM.compositor === "niri" ? NiriXkb.currentLayoutCode : HyprlandXkb.currentLayoutCode) ?? ""
                visible: layoutCode.length > 0 && ((WM.compositor === "niri" ? (NiriXkb.layoutCodes?.length ?? 1) : (HyprlandXkb.layoutCodes?.length ?? 1)) > 1)
                horizontalPad: 5
                tooltip: Translation.tr("Keyboard layout")

                StyledText {
                    text: xkbItem.layoutCode.toUpperCase()
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: root.fgColor
                }
            }

            // 5. Battery with Charging Indicator + Frosted Hover Popup
            MenuBarItem {
                id: batteryItem
                visible: root.showBattery && Battery.available
                horizontalPad: 6
                onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen

                readonly property real pct: Math.max(0, Math.min(1, Battery.percentage))
                readonly property int pctInt: Math.round(pct * 100)
                readonly property bool charging: Battery.isCharging
                readonly property bool fullyCharged: Battery.chargeState === UPowerDeviceState.FullyCharged || Battery.chargeState === 4
                readonly property bool pluggedIn: Battery.isPluggedIn || fullyCharged
                readonly property bool low: Battery.isLow && !charging && !pluggedIn

                RowLayout {
                    spacing: 5

                    StyledText {
                        visible: Config.options.bar.battery.showPercentage
                        text: `${batteryItem.pctInt}%`
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.features: ({ "tnum": 1 })
                        color: batteryItem.low ? root.macRed : root.fgColor
                    }

                    Item {
                        implicitWidth: 27
                        implicitHeight: 13

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

                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: Config.options.bar.battery.showCharging && (batteryItem.charging || batteryItem.pluggedIn)
                                text: "bolt"
                                fill: 1
                                iconSize: 12
                                color: "#101012"
                            }
                        }

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
                horizontalPad: 5
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
                horizontalPad: 5
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

            // 8. Volume Icon
            MenuBarItem {
                visible: root.showVolume
                horizontalPad: 5
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
                horizontalPad: 5
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
                horizontalPad: 6
                active: GlobalStates.sidebarRightOpen
                tooltip: Translation.tr("Control Center")
                onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen

                Item {
                    width: 15
                    height: 13

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

            // 11. Focus / Do Not Disturb Icon
            MenuBarItem {
                visible: Notifications.silent
                horizontalPad: 5
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
    }

    // ============================================================
    // REUSABLE TOP-EDGE ROUNDED NOTCH ISLAND (Left, Center, Right)
    // ============================================================
    component NotchIsland: Item {
        id: islandRoot
        default property alias content: islandContent.data
        property real horizontalPad: 12
        property real filletR: 9
        property bool highlighted: false
        readonly property color fillCol: highlighted ? root.notchHoverColor : root.notchBaseColor

        width: islandContent.implicitWidth + horizontalPad * 2
        height: root.notchHeight

        Behavior on width {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }

        // Left concave shoulder fillet
        Shape {
            visible: !Config.options.bar.bottom
            x: -islandRoot.filletR
            y: 0
            width: islandRoot.filletR
            height: islandRoot.filletR
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                fillColor: islandRoot.fillCol
                strokeWidth: -1
                startX: islandRoot.filletR
                startY: 0
                PathLine { x: 0; y: 0 }
                PathArc {
                    x: islandRoot.filletR
                    y: islandRoot.filletR
                    radiusX: islandRoot.filletR
                    radiusY: islandRoot.filletR
                    direction: PathArc.Clockwise
                }
                PathLine { x: islandRoot.filletR; y: 0 }
            }
        }

        // Right concave shoulder fillet
        Shape {
            visible: !Config.options.bar.bottom
            x: islandRoot.width
            y: 0
            width: islandRoot.filletR
            height: islandRoot.filletR
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                fillColor: islandRoot.fillCol
                strokeWidth: -1
                startX: 0
                startY: 0
                PathLine { x: islandRoot.filletR; y: 0 }
                PathArc {
                    x: 0
                    y: islandRoot.filletR
                    radiusX: islandRoot.filletR
                    radiusY: islandRoot.filletR
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: 0; y: 0 }
            }
        }

        // Main rounded notch body
        Rectangle {
            anchors.fill: parent
            topLeftRadius: Config.options.bar.bottom ? 13 : 0
            topRightRadius: Config.options.bar.bottom ? 13 : 0
            bottomLeftRadius: Config.options.bar.bottom ? 0 : 13
            bottomRightRadius: Config.options.bar.bottom ? 0 : 13
            color: islandRoot.fillCol

            Behavior on color { ColorAnimation { duration: 150 } }

            // Subtle specular rim along bottom & sides
            Rectangle {
                visible: root.showBorder
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
                border.color: islandRoot.highlighted
                    ? ColorUtils.applyAlpha(root.accentColor, 0.45)
                    : Qt.rgba(1, 1, 1, 0.13)

                Behavior on border.color { ColorAnimation { duration: 150 } }
            }

            Row {
                id: islandContent
                anchors.centerIn: parent
                anchors.verticalCenterOffset: Config.options.bar.bottom ? 1 : -1
            }
        }
    }

    // ============================================================
    // COMPACT MEDIA TRANSPORT BUTTON FOR CENTER NOTCH
    // ============================================================
    component NotchMediaBtn: Item {
        id: mediaBtn
        property string icon: ""
        property int iconSz: 14
        property bool filled: false
        property bool accent: false
        signal clicked()

        width: 21
        height: 21

        Rectangle {
            anchors.fill: parent
            radius: 10.5
            color: btnMouse.pressed
                ? ColorUtils.applyAlpha(root.accentColor, 0.42)
                : (btnMouse.containsMouse
                    ? (mediaBtn.accent ? ColorUtils.applyAlpha(root.accentColor, 0.28) : Qt.rgba(1, 1, 1, 0.16))
                    : "transparent")

            Behavior on color { ColorAnimation { duration: 110 } }

            MaterialSymbol {
                anchors.centerIn: parent
                text: mediaBtn.icon
                iconSize: mediaBtn.iconSz
                fill: mediaBtn.filled ? 1 : 0
                color: "#ffffff"
            }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mediaBtn.clicked()
        }
    }

    // ============================================================
    // REUSABLE NOTCH ITEM WRAPPER
    // ============================================================
    component MenuBarItem: Item {
        id: itemRoot
        default property alias content: innerContainer.data
        property int horizontalPad: 6
        property bool active: false
        property string tooltip: ""
        readonly property alias mouseArea: itemMouse

        signal clicked()
        signal rightClicked()
        signal wheelUp()
        signal wheelDown()

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: innerContainer.implicitWidth + horizontalPad * 2
        implicitHeight: root.notchHeight

        Rectangle {
            anchors {
                fill: parent
                topMargin: 5
                bottomMargin: 5
            }
            radius: 6
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
