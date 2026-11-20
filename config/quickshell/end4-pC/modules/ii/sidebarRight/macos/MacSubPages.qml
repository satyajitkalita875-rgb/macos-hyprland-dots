import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarRight.wifiNetworks
import qs.modules.ii.sidebarRight.bluetoothDevices
import qs.modules.ii.sidebarRight.volumeMixer
import qs.modules.ii.sidebarRight.vpn
import qs.modules.ii.sidebarRight.notifications

Item {
    id: root

    property string activePage: ""
    property string renderedPage: ""
    property bool soundIsSink: true
    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)

    signal backRequested()

    readonly property bool dark: Appearance.m3colors.darkmode
    readonly property color textPrimary: Appearance.colors.colOnLayer0
    readonly property color textSecondary: Appearance.colors.colSubtext
    readonly property color dividerColor: Appearance.colors.colLayer0Border

    // Synchronous target height per subpage so the popover resizes smoothly on frame 0 without a Loader collapse dip
    readonly property real targetHeight: {
        const p = activePage !== "" ? activePage : renderedPage;
        switch (p) {
            case "wifi": return 406;
            case "bluetooth": return 406;
            case "sound": return 406;
            case "vpn": return 376;
            case "nightLight": return 290;
            case "notifications": return 416;
            default: return 400;
        }
    }

    implicitHeight: targetHeight

    Timer {
        id: clearRenderedTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (root.activePage === "") root.renderedPage = "";
        }
    }

    onActivePageChanged: {
        if (activePage !== "") {
            clearRenderedTimer.stop();
            renderedPage = activePage;
        } else {
            clearRenderedTimer.restart();
        }

        const adapter = Bluetooth.defaultAdapter;
        if (activePage === "bluetooth" && adapter) {
            if (adapter.enabled) adapter.discovering = true;
        } else if (adapter && adapter.discovering) {
            adapter.discovering = false;
        }

        if (activePage === "wifi" && Network.wifiEnabled) {
            Network.rescanWifi();
        } else if (activePage === "vpn") {
            Vpn.refresh();
        }
    }

    Component.onDestruction: {
        const adapter = Bluetooth.defaultAdapter;
        if (adapter && adapter.discovering) adapter.discovering = false;
    }

    ColumnLayout {
        id: pageCol
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: 10

        // macOS Control Center Sub-page Header
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 2
            Layout.rightMargin: 2
            spacing: 8

            Rectangle {
                id: backBtn
                width: 28
                height: 28
                radius: 14
                color: backMouse.pressed
                    ? (root.dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.14))
                    : (backMouse.containsMouse
                        ? (root.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08))
                        : (root.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)))

                Behavior on color { ColorAnimation { duration: 120 } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "chevron_left"
                    iconSize: 18
                    color: root.textPrimary
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backRequested()
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    switch (root.renderedPage) {
                        case "wifi": return Translation.tr("Wi-Fi");
                        case "bluetooth": return Translation.tr("Bluetooth");
                        case "sound": return Translation.tr("Sound");
                        case "vpn": return Translation.tr("VPN");
                        case "nightLight": return Translation.tr("Display & Night Shift");
                        case "notifications": return Translation.tr("Notifications");
                        default: return "";
                    }
                }
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: root.textPrimary
            }

            // Context toggle in header
            MacToggleSwitch {
                visible: root.renderedPage === "wifi"
                checked: Network.wifiEnabled
                onToggled: newVal => {
                    Network.enableWifi(newVal);
                    if (newVal) Network.rescanWifi();
                }
            }

            MacToggleSwitch {
                visible: root.renderedPage === "bluetooth"
                enabled: BluetoothStatus.available
                checked: BluetoothStatus.enabled
                onToggled: newVal => {
                    const adapter = Bluetooth.defaultAdapter;
                    if (!adapter) return;
                    adapter.enabled = newVal;
                    if (newVal) adapter.discovering = true;
                }
            }

            MacToggleSwitch {
                visible: root.renderedPage === "nightLight"
                accentColor: "#FF9F0A"
                checked: Hyprsunset.temperatureActive
                onToggled: newVal => Hyprsunset.toggleTemperature(newVal)
            }

            // Segmented Output/Input pill for Sound
            Rectangle {
                visible: root.renderedPage === "sound"
                height: 26
                width: soundSegRow.implicitWidth + 4
                radius: 13
                color: root.dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.07)

                Row {
                    id: soundSegRow
                    anchors.centerIn: parent
                    spacing: 2

                    Repeater {
                        model: [
                            { label: Translation.tr("Output"), isSink: true },
                            { label: Translation.tr("Input"), isSink: false }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool selected: root.soundIsSink === modelData.isSink
                            height: 22
                            width: segLabel.implicitWidth + 16
                            radius: 11
                            color: selected
                                ? (root.dark ? Qt.rgba(1, 1, 1, 0.20) : "#FFFFFF")
                                : "transparent"

                            StyledText {
                                id: segLabel
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: 11
                                font.weight: selected ? Font.DemiBold : Font.Normal
                                color: selected ? root.textPrimary : root.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.soundIsSink = modelData.isSink
                            }
                        }
                    }
                }
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: root.dividerColor
        }

        // Page content stack
        Loader {
            id: pageContentLoader
            Layout.fillWidth: true
            sourceComponent: {
                switch (root.renderedPage) {
                    case "wifi": return wifiPageComp;
                    case "bluetooth": return bluetoothPageComp;
                    case "sound": return soundPageComp;
                    case "vpn": return vpnPageComp;
                    case "nightLight": return nightLightPageComp;
                    case "notifications": return notificationsPageComp;
                    default: return null;
                }
            }
        }
    }

    component FooterLinkButton: Rectangle {
        id: footerBtn
        property string label: ""
        property string icon: ""
        signal clicked()

        Layout.fillWidth: true
        implicitHeight: 34
        radius: 10
        color: footerMouse.pressed
            ? (root.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.10))
            : (footerMouse.containsMouse
                ? (root.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06))
                : "transparent")

        Behavior on color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 10
            }
            spacing: 8

            MaterialSymbol {
                visible: footerBtn.icon.length > 0
                text: footerBtn.icon
                iconSize: 16
                color: root.textSecondary
            }

            StyledText {
                Layout.fillWidth: true
                text: footerBtn.label
                font.pixelSize: 12
                color: root.textSecondary
            }

            MaterialSymbol {
                text: "chevron_right"
                iconSize: 16
                color: root.textSecondary
                opacity: 0.7
            }
        }

        MouseArea {
            id: footerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: footerBtn.clicked()
        }
    }

    // 1. Wi-Fi Sub-page
    Component {
        id: wifiPageComp
        ColumnLayout {
            spacing: 8

            StyledIndeterminateProgressBar {
                visible: Network.wifiScanning
                Layout.fillWidth: true
            }

            MacModuleCard {
                Layout.fillWidth: true
                implicitHeight: 310
                clip: true

                ListView {
                    id: wifiList
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    spacing: 2
                    visible: Network.wifiEnabled

                    model: ScriptModel {
                        values: Network.friendlyWifiNetworks
                    }

                    TouchpadScrollArea { flickable: wifiList }

                    delegate: WifiNetworkItem {
                        required property WifiAccessPoint modelData
                        wifiNetwork: modelData
                        width: ListView.view.width
                        buttonRadius: 10
                        horizontalPadding: 12
                        verticalPadding: 9
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: !Network.wifiEnabled || Network.friendlyWifiNetworks.length === 0
                    spacing: 6

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: Network.wifiEnabled ? "wifi_find" : "signal_wifi_off"
                        iconSize: 32
                        color: root.textSecondary
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Network.wifiEnabled ? Translation.tr("Searching for networks…") : Translation.tr("Wi-Fi is turned off")
                        font.pixelSize: 12
                        color: root.textSecondary
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                FooterLinkButton {
                    label: Translation.tr("Wi-Fi Settings…")
                    icon: "settings"
                    onClicked: {
                        Quickshell.execDetached(["bash", "-c", `${Network.ethernet ? Config.options.apps.networkEthernet : Config.options.apps.network}`]);
                        GlobalStates.sidebarRightOpen = false;
                    }
                }
            }
        }
    }

    // 2. Bluetooth Sub-page
    Component {
        id: bluetoothPageComp
        ColumnLayout {
            spacing: 8

            StyledIndeterminateProgressBar {
                visible: Bluetooth.defaultAdapter?.discovering ?? false
                Layout.fillWidth: true
            }

            MacModuleCard {
                Layout.fillWidth: true
                implicitHeight: 310
                clip: true

                StyledListView {
                    id: btList
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    spacing: 2
                    animateAppearance: false
                    visible: BluetoothStatus.enabled

                    model: ScriptModel {
                        values: BluetoothStatus.friendlyDeviceList
                    }

                    delegate: BluetoothDeviceItem {
                        required property BluetoothDevice modelData
                        device: modelData
                        width: ListView.view.width
                        buttonRadius: 10
                        horizontalPadding: 12
                        verticalPadding: 9
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: !BluetoothStatus.enabled || BluetoothStatus.friendlyDeviceList.length === 0
                    spacing: 6

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: BluetoothStatus.enabled ? "bluetooth_searching" : "bluetooth_disabled"
                        iconSize: 32
                        color: root.textSecondary
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: BluetoothStatus.enabled ? Translation.tr("No devices found") : Translation.tr("Bluetooth is turned off")
                        font.pixelSize: 12
                        color: root.textSecondary
                    }
                }
            }

            FooterLinkButton {
                label: Translation.tr("Bluetooth Settings…")
                icon: "settings"
                onClicked: {
                    Quickshell.execDetached(["bash", "-c", `${Config.options.apps.bluetooth}`]);
                    GlobalStates.sidebarRightOpen = false;
                }
            }
        }
    }

    // 3. Sound Sub-page
    Component {
        id: soundPageComp
        ColumnLayout {
            spacing: 8

            MacModuleCard {
                Layout.fillWidth: true
                implicitHeight: 310
                clip: true

                VolumeDialogContent {
                    anchors.fill: parent
                    anchors.margins: 12
                    isSink: root.soundIsSink
                }
            }

            FooterLinkButton {
                label: Translation.tr("Sound Settings…")
                icon: "tune"
                onClicked: {
                    Quickshell.execDetached(["bash", "-c", `${Config.options.apps.volumeMixer}`]);
                    GlobalStates.sidebarRightOpen = false;
                }
            }
        }
    }

    // 4. VPN Sub-page
    Component {
        id: vpnPageComp
        ColumnLayout {
            spacing: 8

            StyledIndeterminateProgressBar {
                visible: Vpn.busy
                Layout.fillWidth: true
            }

            MacModuleCard {
                Layout.fillWidth: true
                implicitHeight: 280
                clip: true

                ListView {
                    id: vpnList
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    spacing: 2
                    visible: Vpn.profiles.length > 0

                    model: ScriptModel {
                        values: Vpn.profiles
                    }

                    TouchpadScrollArea { flickable: vpnList }

                    delegate: VpnProfileItem {
                        required property var modelData
                        profile: modelData
                        width: ListView.view.width
                        buttonRadius: 10
                        horizontalPadding: 12
                        verticalPadding: 9
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: Vpn.profiles.length === 0
                    spacing: 6

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "vpn_key_off"
                        iconSize: 32
                        color: root.textSecondary
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("No VPN profiles")
                        font.pixelSize: 12
                        color: root.textSecondary
                    }
                }
            }

            FooterLinkButton {
                label: Translation.tr("Import WireGuard / OpenVPN Profile…")
                icon: "add"
                onClicked: Vpn.pickAndImport()
            }
        }
    }

    // 5. Night Shift & Display Sub-page
    Component {
        id: nightLightPageComp
        ColumnLayout {
            spacing: 10

            MacModuleCard {
                Layout.fillWidth: true
                implicitHeight: nightShiftCol.implicitHeight + 24

                ColumnLayout {
                    id: nightShiftCol
                    anchors {
                        fill: parent
                        margins: 12
                    }
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Automatic Schedule")
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: root.textPrimary
                        }
                        MacToggleSwitch {
                            accentColor: "#FF9F0A"
                            checked: Config.options.light.night.automatic
                            onToggled: newVal => Config.options.light.night.automatic = newVal
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: root.dividerColor
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Color Temperature")
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: root.textPrimary
                        }
                        StyledText {
                            text: `${Math.round(Config.options.light.night.colorTemperature)}K`
                            font.pixelSize: 11
                            font.features: ({ "tnum": 1 })
                            color: root.textSecondary
                        }
                    }

                    MacSlider {
                        Layout.fillWidth: true
                        iconName: "wb_twilight"
                        from: 6500
                        to: 1200
                        value: Config.options.light.night.colorTemperature
                        onMoved: newVal => Config.options.light.night.colorTemperature = Math.round(newVal)
                    }
                }
            }

            MacModuleCard {
                Layout.fillWidth: true
                implicitHeight: gammaCol.implicitHeight + 24

                ColumnLayout {
                    id: gammaCol
                    anchors {
                        fill: parent
                        margins: 12
                    }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Gamma Dimming")
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: root.textPrimary
                        }
                        StyledText {
                            text: `${Math.round(Hyprsunset.gamma)}%`
                            font.pixelSize: 11
                            font.features: ({ "tnum": 1 })
                            color: root.textSecondary
                        }
                    }

                    MacSlider {
                        Layout.fillWidth: true
                        iconName: "brightness_low"
                        from: Hyprsunset.gammaLowerLimit
                        to: 100
                        value: Hyprsunset.gamma
                        onMoved: newVal => Hyprsunset.setGamma(Math.round(newVal))
                    }
                }
            }
        }
    }

    // 6. Notifications Sub-page
    Component {
        id: notificationsPageComp
        MacModuleCard {
            Layout.fillWidth: true
            implicitHeight: 360
            clip: true

            NotificationList {
                anchors.fill: parent
                anchors.margins: 6
            }
        }
    }
}
