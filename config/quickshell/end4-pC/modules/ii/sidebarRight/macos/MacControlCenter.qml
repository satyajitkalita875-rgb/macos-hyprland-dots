import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    property string activePage: "" // "", "wifi", "bluetooth", "sound", "vpn", "nightLight", "notifications"
    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)

    readonly property bool dark: Appearance.m3colors.darkmode
    readonly property bool glassOn: Config.options?.background?.widgets?.glass?.enable ?? false
    readonly property MprisPlayer activePlayer: MprisController.activePlayer

    readonly property color textPrimary: Appearance.colors.colOnLayer0
    readonly property color textSecondary: Appearance.colors.colSubtext
    readonly property color macBlue: Appearance.colors.colPrimary
    readonly property color macIndigo: Appearance.colors.colPrimary
    readonly property color macAmber: Appearance.colors.colPrimary
    readonly property color macGreen: dark ? "#30D158" : "#24B948"
    readonly property color activeIconOnAccent: Appearance.colors.colOnPrimary
    readonly property color inactiveCircleBg: Appearance.colors.colLayer2Base
    readonly property color inactiveIconColor: Appearance.colors.colOnLayer1

    readonly property real cardWidth: 348
    readonly property real padOuter: 12
    readonly property real mainSurfaceHeight: mainBento.implicitHeight + padOuter * 2
    readonly property real maxPanelHeight: Math.max(mainSurfaceHeight, 460)

    implicitWidth: cardWidth
    implicitHeight: maxPanelHeight

    function handleEscape() {
        if (root.activePage !== "") {
            root.activePage = "";
            return true;
        }
        return false;
    }

    Connections {
        target: Vpn
        function onDialogRequested() {
            root.activePage = "vpn";
            GlobalStates.sidebarRightOpen = true;
        }
    }

    Connections {
        target: GlobalStates
        function onRequestBluetoothDialog() {
            if (!BluetoothStatus.available) return;
            root.activePage = "bluetooth";
            GlobalStates.sidebarRightOpen = true;
        }
        function onSidebarRightOpenChanged() {
            if (!GlobalStates.sidebarRightOpen) {
                root.activePage = "";
            }
        }
    }

    Timer {
        id: screenshotTimer
        interval: 280
        repeat: false
        onTriggered: Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"])
    }

    Timer {
        id: colorPickerTimer
        interval: 280
        repeat: false
        onTriggered: Quickshell.execDetached(["hyprpicker", "-a"])
    }

    Timer {
        id: wallpaperTimer
        interval: 220
        repeat: false
        onTriggered: GlobalStates.wallpaperSelectorOpen = true
    }

    // Soft floating popover shadow (alpha < 0.35 so Hyprland blur stays cleanly inside the rounded glass card)
    RectangularShadow {
        anchors.fill: popoverSurface
        radius: popoverSurface.radius
        blur: 30
        spread: 0
        offset: Qt.vector2d(0, 10)
        color: ColorUtils.applyAlpha(Appearance.m3colors.m3shadow, 0.24)
        cached: false
    }

    // Main macOS Control Center Frosted Glass Popover
    Rectangle {
        id: popoverSurface
        width: root.cardWidth
        height: root.activePage === ""
            ? root.mainSurfaceHeight
            : (subPages.targetHeight + root.padOuter * 2)
        radius: 22
        clip: true

        color: Appearance.colors.colUiBackground

        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        Behavior on height {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        // Optional Liquid Glass shader when enabled globally
        WindowGlass {
            anchors.fill: parent
            glassEnabled: root.glassOn
            cardRadius: parent.radius
            tint: parent.color
        }

        // Subtle inner rim highlight (signature macOS glass edge)
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            border.width: 1
            border.color: root.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.55)
            z: 20
        }

        // Swallow clicks inside the popover
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // ============================================================
        // MAIN MACOS CONTROL CENTER BENTO GRID
        // ============================================================
        ColumnLayout {
            id: mainBento
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: root.padOuter
            }
            spacing: 10
            visible: opacity > 0.01
            opacity: root.activePage === "" ? 1.0 : 0.0
            enabled: root.activePage === ""

            transform: Translate {
                x: root.activePage === "" ? 0 : -14
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            // ------------------------------------------------------------
            // ROW 1: 2x2 Connectivity Module (Left) + Focus & 2 Tiles (Right)
            // ------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // LEFT: Connectivity Stack (Wi-Fi, Bluetooth, VPN)
                MacModuleCard {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 152

                    ColumnLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 8
                            topMargin: 10
                            bottomMargin: 10
                        }
                        spacing: 6

                        ConnectivityRow {
                            icon: Network.materialSymbol
                            title: Translation.tr("Wi-Fi")
                            subtitle: Network.wifiEnabled
                                ? (Network.networkName && Network.networkName.length > 0 ? Network.networkName : Translation.tr("On"))
                                : Translation.tr("Off")
                            active: Network.wifiEnabled
                            accentColor: root.macBlue
                            onToggleClicked: Network.toggleWifi()
                            onDetailClicked: root.activePage = "wifi"
                        }

                        ConnectivityRow {
                            icon: BluetoothStatus.connected
                                ? "bluetooth_connected"
                                : (BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled")
                            title: Translation.tr("Bluetooth")
                            subtitle: !BluetoothStatus.available
                                ? Translation.tr("Unavailable")
                                : (BluetoothStatus.enabled
                                    ? (BluetoothStatus.firstActiveDevice?.name ?? Translation.tr("On"))
                                    : Translation.tr("Off"))
                            active: BluetoothStatus.available && BluetoothStatus.enabled
                            accentColor: root.macBlue
                            onToggleClicked: BluetoothStatus.togglePower()
                            onDetailClicked: {
                                if (BluetoothStatus.available) root.activePage = "bluetooth";
                            }
                        }

                        ConnectivityRow {
                            icon: Vpn.connected ? "vpn_lock" : "vpn_key"
                            title: Translation.tr("VPN")
                            subtitle: Vpn.busy
                                ? Translation.tr("Connecting…")
                                : (Vpn.connected
                                    ? (Vpn.selectedProfile?.name ?? Translation.tr("Connected"))
                                    : Translation.tr("Off"))
                            active: Vpn.connected
                            accentColor: root.macGreen
                            onToggleClicked: Vpn.toggle()
                            onDetailClicked: root.activePage = "vpn"
                        }
                    }
                }

                // RIGHT COLUMN: Focus (Top) + Night Shift & Appearance (Bottom)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 152
                    spacing: 10

                    // Top Wide Tile: Focus / Do Not Disturb
                    MacModuleCard {
                        id: focusCard
                        Layout.fillWidth: true
                        Layout.preferredHeight: 71
                        interactive: true
                        hovered: focusMouse.containsMouse
                        pressed: focusMouse.pressed
                        active: Notifications.silent
                        activeTint: root.macIndigo

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 12
                                rightMargin: 10
                            }
                            spacing: 10

                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: Notifications.silent ? root.macIndigo : root.inactiveCircleBg
                                Behavior on color { ColorAnimation { duration: 150 } }

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "bedtime"
                                    iconSize: 17
                                    fill: 1
                                    color: Notifications.silent ? root.activeIconOnAccent : root.inactiveIconColor
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Focus")
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: root.textPrimary
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: Notifications.silent ? Translation.tr("Do Not Disturb") : Translation.tr("Off")
                                    font.pixelSize: 11
                                    color: root.textSecondary
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            id: focusMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifications.silent = !Notifications.silent
                        }
                    }

                    // Bottom Row: Two Square Glass Tiles (Night Shift + Appearance)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 71
                        spacing: 10

                        // Night Shift Square Tile
                        SquareTile {
                            icon: Config.options.light.night.automatic ? "night_sight_auto" : "wb_twilight"
                            label: Translation.tr("Night Shift")
                            active: Hyprsunset.temperatureActive
                            accentColor: root.macAmber
                            tooltip: Translation.tr("Click to toggle • Right-click for warmth")
                            onClicked: Hyprsunset.toggleTemperature()
                            onRightClicked: root.activePage = "nightLight"
                        }

                        // Dark / Light Appearance Square Tile
                        SquareTile {
                            icon: Appearance.m3colors.darkmode ? "dark_mode" : "light_mode"
                            label: Appearance.m3colors.darkmode ? Translation.tr("Dark Mode") : Translation.tr("Light Mode")
                            active: Appearance.m3colors.darkmode
                            accentColor: root.macIndigo
                            tooltip: Translation.tr("Switch Light / Dark appearance")
                            onClicked: {
                                const nextMode = Appearance.m3colors.darkmode ? "light" : "dark";
                                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", nextMode, "--noswitch"]);
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------------------
            // ROW 2: Display (Brightness) Slider Card
            // ------------------------------------------------------------
            MacModuleCard {
                id: displayCard
                Layout.fillWidth: true
                visible: Config.options.sidebar.quickSliders.enable && Config.options.sidebar.quickSliders.showBrightness
                implicitHeight: displayCardCol.implicitHeight + 21

                readonly property real minBrightness: root.brightnessMonitor?.minBrightness ?? 0.05

                ColumnLayout {
                    id: displayCardCol
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                        topMargin: 10
                        bottomMargin: 11
                    }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Display")
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: root.textPrimary
                        }

                        StyledText {
                            text: `${Math.round((root.brightnessMonitor?.brightness ?? 1) * 100)}%`
                            font.pixelSize: 11
                            font.features: ({ "tnum": 1 })
                            color: root.textSecondary
                        }

                        MiniCircleButton {
                            icon: "tune"
                            tooltip: Translation.tr("Display & Night Shift")
                            onClicked: root.activePage = "nightLight"
                        }
                    }

                    MacSlider {
                        Layout.fillWidth: true
                        iconName: "light_mode"
                        from: displayCard.minBrightness
                        to: 1.0
                        value: root.brightnessMonitor?.brightness ?? 1.0
                        onMoved: newVal => {
                            if (!root.brightnessMonitor) return;
                            root.brightnessMonitor.setBrightness(newVal);
                            if (Hyprsunset.gamma !== 100) Hyprsunset.setGamma(100);
                        }
                    }
                }
            }

            // ------------------------------------------------------------
            // ROW 3: Sound (Volume + optional Mic) Slider Card
            // ------------------------------------------------------------
            MacModuleCard {
                Layout.fillWidth: true
                visible: Config.options.sidebar.quickSliders.enable && (Config.options.sidebar.quickSliders.showVolume || Config.options.sidebar.quickSliders.showMic)
                implicitHeight: soundCardCol.implicitHeight + 21

                ColumnLayout {
                    id: soundCardCol
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                        topMargin: 10
                        bottomMargin: 11
                    }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        StyledText {
                            text: Translation.tr("Sound")
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: root.textPrimary
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Audio.sink ? Audio.friendlyDeviceName(Audio.sink) : ""
                            font.pixelSize: 11
                            color: root.textSecondary
                            elide: Text.ElideRight
                        }

                        StyledText {
                            visible: Config.options.sidebar.quickSliders.showVolume
                            text: (Audio.sink?.audio?.muted ?? false)
                                ? Translation.tr("Muted")
                                : `${Math.round((Audio.sink?.audio?.volume ?? 0) * 100)}%`
                            font.pixelSize: 11
                            font.features: ({ "tnum": 1 })
                            color: root.textSecondary
                        }

                        MiniCircleButton {
                            icon: "speaker"
                            tooltip: Translation.tr("Audio output & mixer")
                            onClicked: {
                                subPages.soundIsSink = true;
                                root.activePage = "sound";
                            }
                        }
                    }

                    MacSlider {
                        Layout.fillWidth: true
                        visible: Config.options.sidebar.quickSliders.showVolume
                        iconName: (Audio.sink?.audio?.muted ?? false)
                            ? "volume_off"
                            : ((Audio.sink?.audio?.volume ?? 0) < 0.01
                                ? "volume_mute"
                                : ((Audio.sink?.audio?.volume ?? 0) < 0.5 ? "volume_down" : "volume_up"))
                        iconClickable: true
                        muted: Audio.sink?.audio?.muted ?? false
                        value: Audio.sink?.audio?.volume ?? 0
                        onIconClicked: Audio.toggleMute()
                        onMoved: newVal => {
                            if (Audio.sink?.audio) {
                                if (Audio.sink.audio.muted && newVal > 0) Audio.sink.audio.muted = false;
                                Audio.sink.audio.volume = newVal;
                            }
                        }
                    }

                    MacSlider {
                        Layout.fillWidth: true
                        visible: Config.options.sidebar.quickSliders.showMic
                        iconName: (Audio.source?.audio?.muted ?? false) ? "mic_off" : "mic"
                        iconClickable: true
                        muted: Audio.source?.audio?.muted ?? false
                        value: Audio.source?.audio?.volume ?? 0
                        onIconClicked: Audio.toggleMicMute()
                        onMoved: newVal => {
                            if (Audio.source?.audio) {
                                if (Audio.source.audio.muted && newVal > 0) Audio.source.audio.muted = false;
                                Audio.source.audio.volume = newVal;
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------------------
            // ROW 4: Now Playing Media Module
            // ------------------------------------------------------------
            MacModuleCard {
                Layout.fillWidth: true
                implicitHeight: 66

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }
                    spacing: 10

                    // Rounded album artwork
                    Rectangle {
                        id: artBox
                        width: 44
                        height: 44
                        radius: 10
                        color: root.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: albumArt.status !== Image.Ready
                            text: "music_note"
                            iconSize: 22
                            color: root.textSecondary
                        }

                        Image {
                            id: albumArt
                            anchors.fill: parent
                            source: root.activePlayer?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            mipmap: true
                            visible: status === Image.Ready
                            layer.enabled: visible
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: artBox.width
                                    height: artBox.height
                                    radius: artBox.radius
                                }
                            }
                        }
                    }

                    // Track info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: root.activePlayer
                                ? (StringUtils.cleanMusicTitle(root.activePlayer.trackTitle) || Translation.tr("Now Playing"))
                                : Translation.tr("Not Playing")
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: root.activePlayer ? root.textPrimary : root.textSecondary
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: root.activePlayer
                                ? (root.activePlayer.trackArtist || root.activePlayer.identity || "")
                                : ""
                            font.pixelSize: 11
                            color: root.textSecondary
                            elide: Text.ElideRight
                        }
                    }

                    // Transport buttons
                    Row {
                        spacing: 2
                        opacity: root.activePlayer ? 1.0 : 0.40

                        MediaButton {
                            icon: "skip_previous"
                            iconSize: 19
                            enabled: !!root.activePlayer
                            onClicked: root.activePlayer?.previous()
                        }

                        MediaButton {
                            icon: (root.activePlayer?.isPlaying ?? false) ? "pause" : "play_arrow"
                            iconSize: 22
                            enabled: !!root.activePlayer
                            onClicked: root.activePlayer?.togglePlaying()
                        }

                        MediaButton {
                            icon: "skip_next"
                            iconSize: 19
                            enabled: !!root.activePlayer
                            onClicked: root.activePlayer?.next()
                        }
                    }
                }
            }

            // ------------------------------------------------------------
            // ROW 5: Quick Controls Strip (Keep Awake, Power Mode, Snip, Picker)
            // ------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                UtilityPillTile {
                    icon: "coffee"
                    label: Translation.tr("Awake")
                    active: Idle.inhibit
                    accentColor: root.macAmber
                    tooltip: Translation.tr("Keep system awake")
                    onClicked: Idle.toggleInhibit()
                }

                UtilityPillTile {
                    icon: {
                        switch (PowerProfiles.profile) {
                            case PowerProfile.PowerSaver: return "energy_savings_leaf";
                            case PowerProfile.Performance: return "local_fire_department";
                            default: return "airwave";
                        }
                    }
                    label: {
                        switch (PowerProfiles.profile) {
                            case PowerProfile.PowerSaver: return Translation.tr("Saver");
                            case PowerProfile.Performance: return Translation.tr("Perf");
                            default: return Translation.tr("Power");
                        }
                    }
                    active: PowerProfiles.profile !== PowerProfile.Balanced
                    accentColor: PowerProfiles.profile === PowerProfile.PowerSaver ? root.macGreen : root.macAmber
                    tooltip: Translation.tr("Cycle power profile")
                    onClicked: {
                        if (PowerProfiles.hasPerformanceProfile) {
                            switch (PowerProfiles.profile) {
                                case PowerProfile.PowerSaver: PowerProfiles.profile = PowerProfile.Balanced; break;
                                case PowerProfile.Balanced: PowerProfiles.profile = PowerProfile.Performance; break;
                                case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver; break;
                            }
                        } else {
                            PowerProfiles.profile = PowerProfiles.profile === PowerProfile.Balanced
                                ? PowerProfile.PowerSaver
                                : PowerProfile.Balanced;
                        }
                    }
                }

                UtilityPillTile {
                    icon: "screenshot_region"
                    label: Translation.tr("Snip")
                    active: false
                    accentColor: root.macBlue
                    tooltip: Translation.tr("Screen snip")
                    onClicked: {
                        GlobalStates.sidebarRightOpen = false;
                        screenshotTimer.restart();
                    }
                }

                UtilityPillTile {
                    icon: "colorize"
                    label: Translation.tr("Color")
                    active: false
                    accentColor: root.macBlue
                    tooltip: Translation.tr("Color picker")
                    onClicked: {
                        GlobalStates.sidebarRightOpen = false;
                        colorPickerTimer.restart();
                    }
                }
            }

            // ------------------------------------------------------------
            // ROW 6: Compact Footer (Notifications, Battery, System Actions)
            // ------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 6

                // Notifications Pill Button
                Rectangle {
                    id: notifPill
                    height: 28
                    implicitWidth: notifPillRow.implicitWidth + 18
                    radius: 14
                    color: notifPillMouse.pressed
                        ? Appearance.colors.colLayer3
                        : (notifPillMouse.containsMouse
                            ? Appearance.colors.colLayer2
                            : Appearance.colors.colLayer1)
                    border.width: 1
                    border.color: ColorUtils.applyAlpha(Appearance.colors.colLayer0Border, 0.70)

                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        id: notifPillRow
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialSymbol {
                            text: Notifications.silent ? "notifications_paused" : "notifications"
                            iconSize: 15
                            fill: Notifications.list.length > 0 ? 1 : 0
                            color: Notifications.list.length > 0 && !Notifications.silent ? root.macBlue : root.textSecondary
                        }

                        StyledText {
                            text: Notifications.list.length > 0
                                ? `${Notifications.list.length}`
                                : Translation.tr("Notifications")
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: root.textPrimary
                        }
                    }

                    MouseArea {
                        id: notifPillMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activePage = "notifications"
                    }
                }

                // Battery indicator pill (shown on laptops)
                Rectangle {
                    visible: Battery.available
                    height: 28
                    implicitWidth: battRow.implicitWidth + 16
                    radius: 14
                    color: Appearance.colors.colLayer1
                    border.width: 1
                    border.color: ColorUtils.applyAlpha(Appearance.colors.colLayer0Border, 0.65)

                    RowLayout {
                        id: battRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            readonly property bool acConnected: Battery.isCharging || Battery.isPluggedIn || Battery.chargeState === 4
                            text: acConnected ? "battery_charging_full" : "battery_std"
                            iconSize: 15
                            color: Battery.isLow && !acConnected
                                ? "#FF453A"
                                : (acConnected ? root.macGreen : root.textSecondary)
                        }

                        StyledText {
                            text: `${Math.round(Battery.percentage * 100)}%`
                            font.pixelSize: 12
                            font.features: ({ "tnum": 1 })
                            color: root.textSecondary
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // System Action Circles: Wallpaper, Reload, Settings, Power
                FooterIconButton {
                    icon: "wallpaper"
                    tooltip: Translation.tr("Wallpaper Selector")
                    onClicked: {
                        GlobalStates.sidebarRightOpen = false;
                        wallpaperTimer.restart();
                    }
                }

                FooterIconButton {
                    icon: "restart_alt"
                    tooltip: WM.compositor === "niri"
                        ? Translation.tr("Reload Niri & Quickshell")
                        : Translation.tr("Reload Hyprland & Quickshell")
                    onClicked: {
                        if (WM.compositor === "niri") {
                            Quickshell.execDetached(["niri", "msg", "action", "reload-config"]);
                        } else {
                            Quickshell.execDetached(["hyprctl", "reload"]);
                        }
                        Quickshell.reload(true);
                    }
                }

                FooterIconButton {
                    icon: "settings"
                    tooltip: Translation.tr("Settings")
                    onClicked: {
                        GlobalStates.sidebarRightOpen = false;
                        GlobalStates.settingsOpen = !GlobalStates.settingsOpen;
                    }
                }

                FooterIconButton {
                    icon: "power_settings_new"
                    tooltip: Translation.tr("Session")
                    onClicked: {
                        GlobalStates.sidebarRightOpen = false;
                        GlobalStates.sessionOpen = true;
                    }
                }
            }
        }

        // ============================================================
        // DRILL-DOWN SUB-PAGES (Wi-Fi, Bluetooth, Sound, VPN, Night Shift, Notifications)
        // ============================================================
        MacSubPages {
            id: subPages
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: root.padOuter
            }
            activePage: root.activePage
            visible: opacity > 0.01
            opacity: root.activePage !== "" ? 1.0 : 0.0
            enabled: root.activePage !== ""
            onBackRequested: root.activePage = ""

            transform: Translate {
                x: root.activePage !== "" ? 0 : 14
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }

            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
        }
    }

    // ============================================================
    // REUSABLE INTERNAL COMPONENTS
    // ============================================================

    component ConnectivityRow: Item {
        id: connRow
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool active: false
        property color accentColor: root.macBlue
        signal toggleClicked()
        signal detailClicked()

        Layout.fillWidth: true
        Layout.fillHeight: true

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -4
            anchors.rightMargin: -2
            radius: 10
            color: detailMouse.containsMouse && !circleMouse.containsMouse
                ? (root.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05))
                : "transparent"
            Behavior on color { ColorAnimation { duration: 110 } }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 9

            // Circular macOS icon toggle button
            Rectangle {
                id: iconCircle
                width: 30
                height: 30
                radius: 15
                color: connRow.active ? connRow.accentColor : root.inactiveCircleBg
                scale: circleMouse.pressed ? 0.90 : 1.0

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on scale { NumberAnimation { duration: 90 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: connRow.icon
                    iconSize: 16
                    fill: 1
                    color: connRow.active ? root.activeIconOnAccent : root.inactiveIconColor
                }

                MouseArea {
                    id: circleMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: connRow.toggleClicked()
                }
            }

            // Title & live status
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: connRow.title
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: root.textPrimary
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: connRow.subtitle
                    font.pixelSize: 11
                    color: root.textSecondary
                    elide: Text.ElideRight
                }
            }

            MaterialSymbol {
                text: "chevron_right"
                iconSize: 15
                color: root.textSecondary
                opacity: detailMouse.containsMouse ? 0.95 : 0.45
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }
        }

        MouseArea {
            id: detailMouse
            anchors {
                top: parent.top
                bottom: parent.bottom
                left: parent.left
                leftMargin: 34
                right: parent.right
            }
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: connRow.detailClicked()
        }
    }

    component SquareTile: MacModuleCard {
        id: sqTile
        property string icon: ""
        property string label: ""
        property color accentColor: root.macBlue
        property string tooltip: ""
        signal clicked()
        signal rightClicked()

        Layout.fillWidth: true
        Layout.fillHeight: true
        interactive: true
        hovered: sqMouse.containsMouse
        pressed: sqMouse.pressed
        activeTint: sqTile.accentColor

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 10
            spacing: 4

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: sqTile.icon
                iconSize: 21
                fill: sqTile.active ? 1 : 0
                color: sqTile.active ? sqTile.accentColor : root.textPrimary
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: sqTile.label
                font.pixelSize: 11
                font.weight: Font.Medium
                color: root.textPrimary
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: sqMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) sqTile.rightClicked();
                else sqTile.clicked();
            }
        }

        StyledToolTip {
            visible: sqTile.tooltip.length > 0 && sqMouse.containsMouse
            text: sqTile.tooltip
        }
    }

    component UtilityPillTile: MacModuleCard {
        id: utilTile
        property string icon: ""
        property string label: ""
        property color accentColor: root.macBlue
        property string tooltip: ""
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 50
        radius: 14
        interactive: true
        hovered: utilMouse.containsMouse
        pressed: utilMouse.pressed
        activeTint: utilTile.accentColor

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 8
            spacing: 2

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: utilTile.icon
                iconSize: 18
                fill: utilTile.active ? 1 : 0
                color: utilTile.active ? utilTile.accentColor : root.textPrimary
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: utilTile.label
                font.pixelSize: 10
                font.weight: Font.Medium
                color: utilTile.active ? root.textPrimary : root.textSecondary
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: utilMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: utilTile.clicked()
        }

        StyledToolTip {
            visible: utilTile.tooltip.length > 0 && utilMouse.containsMouse
            text: utilTile.tooltip
        }
    }

    component MediaButton: Rectangle {
        id: mediaBtn
        property string icon: ""
        property int iconSize: 20
        signal clicked()

        width: 30
        height: 30
        radius: 15
        color: mediaMouse.pressed
            ? (root.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.14))
            : (mediaMouse.containsMouse
                ? (root.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08))
                : "transparent")
        scale: mediaMouse.pressed ? 0.90 : 1.0

        Behavior on color { ColorAnimation { duration: 110 } }
        Behavior on scale { NumberAnimation { duration: 80 } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: mediaBtn.icon
            iconSize: mediaBtn.iconSize
            fill: 1
            color: root.textPrimary
        }

        MouseArea {
            id: mediaMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: mediaBtn.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: mediaBtn.clicked()
        }
    }

    component MiniCircleButton: Rectangle {
        id: miniBtn
        property string icon: ""
        property string tooltip: ""
        signal clicked()

        implicitWidth: 22
        implicitHeight: 22
        width: 22
        height: 22
        radius: 11
        color: miniMouse.pressed
            ? (root.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.14))
            : (miniMouse.containsMouse
                ? (root.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08))
                : (root.dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.05)))

        Behavior on color { ColorAnimation { duration: 110 } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: miniBtn.icon
            iconSize: 13
            color: root.textSecondary
        }

        MouseArea {
            id: miniMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: miniBtn.clicked()
        }

        StyledToolTip {
            visible: miniBtn.tooltip.length > 0 && miniMouse.containsMouse
            text: miniBtn.tooltip
        }
    }

    component FooterIconButton: Rectangle {
        id: footBtn
        property string icon: ""
        property string tooltip: ""
        signal clicked()

        width: 28
        height: 28
        radius: 14
        color: footMouse.pressed
            ? Appearance.colors.colLayer3
            : (footMouse.containsMouse
                ? Appearance.colors.colLayer2
                : Appearance.colors.colLayer1)
        border.width: 1
        border.color: ColorUtils.applyAlpha(Appearance.colors.colLayer0Border, 0.70)

        Behavior on color { ColorAnimation { duration: 110 } }

        MaterialSymbol {
            anchors.centerIn: parent
            text: footBtn.icon
            iconSize: 15
            color: root.textSecondary
        }

        MouseArea {
            id: footMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: footBtn.clicked()
        }

        StyledToolTip {
            visible: footBtn.tooltip.length > 0 && footMouse.containsMouse
            text: footBtn.tooltip
        }
    }
}
