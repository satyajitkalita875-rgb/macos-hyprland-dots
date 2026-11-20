pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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

    // Expose the 3 floating pills for Bar.qml click-through Wayland input mask
    readonly property Item leftIslandItem: leftPill
    readonly property Item centerIslandItem: centerIsland
    readonly property Item rightIslandItem: rightIsland

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

    // Media state: only show music in the Dynamic Island when actively playing
    // (and keep media visible inside an already-expanded island if user pauses while hovering)
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool isMusicPlaying: root.activePlayer !== null && (root.activePlayer.isPlaying ?? false)
    property bool keepMediaWhileExpanded: false
    readonly property bool showCompactMusic: root.isMusicPlaying
    readonly property bool showExpandedMusic: root.activePlayer !== null && (root.isMusicPlaying || root.keepMediaWhileExpanded)

    // Floating iPhone Dynamic Island geometry
    readonly property real pillHeight: Math.max(32, (macCfg?.height ?? 28) + 4)
    readonly property real edgeGapTop: 6
    readonly property real edgeGapSide: 12

    // Unified iPhone Dynamic Island dark glass palette with subtle Material You tint
    readonly property color islandBg: dark
        ? ColorUtils.applyAlpha(ColorUtils.mix("#0b0d12", Appearance.colors.colPrimary, 0.94), 0.92)
        : ColorUtils.applyAlpha(ColorUtils.mix("#11141c", Appearance.colors.colPrimary, 0.93), 0.88)
    readonly property color islandBgHover: dark
        ? ColorUtils.applyAlpha(ColorUtils.mix("#0b0d12", Appearance.colors.colPrimary, 0.90), 0.95)
        : ColorUtils.applyAlpha(ColorUtils.mix("#11141c", Appearance.colors.colPrimary, 0.89), 0.92)
    readonly property color innerCardBg: Qt.rgba(1, 1, 1, 0.08)
    readonly property color innerCardBorder: Qt.rgba(1, 1, 1, 0.12)

    readonly property color fgColor: "#f5f7fa"
    readonly property color fgMuted: Qt.rgba(1, 1, 1, 0.62)
    readonly property color hoverBg: Qt.rgba(1, 1, 1, 0.14)
    readonly property color activeBg: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.36)
    readonly property color activeFg: "#ffffff"
    readonly property color accentColor: Appearance.colors.colPrimary
    readonly property color macGreen: "#30D158"
    readonly property color macRed: "#FF5C5C"
    readonly property color macOrange: "#FF9F0A"

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

    function formatBatteryTime(seconds) {
        var h = Math.floor(seconds / 3600);
        var m = Math.floor((seconds % 3600) / 60);
        if (h > 0) return `${h}h ${m}m`;
        return `${m}m`;
    }

    WorkspaceModel {
        id: wsModel
        screen: root.QsWindow.window?.screen
    }

    // ============================================================
    // 1. LEFT FLOATING PILL: Logo + Active App + Workspaces
    // ============================================================
    Rectangle {
        id: leftPill
        visible: root.showLogo || root.showActiveApp || root.showWorkspaces
        anchors {
            left: parent.left
            leftMargin: root.edgeGapSide
            top: parent.top
            topMargin: root.edgeGapTop
        }
        width: leftSection.implicitWidth + 18
        height: root.pillHeight
        radius: height / 2
        color: root.islandBg
        border.width: root.showBorder ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.14)

        Behavior on width {
            NumberAnimation {
                duration: 320
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
            }
        }

        RowLayout {
            id: leftSection
            anchors.centerIn: parent
            spacing: 2

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

            Item {
                id: wsContainer
                visible: root.showWorkspaces
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: wsRow.implicitWidth
                implicitHeight: root.pillHeight

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
                                radius: 9
                                color: wsItem.isActive
                                    ? root.activeBg
                                    : (wsMouse.containsMouse ? root.hoverBg : "transparent")
                                border.width: wsItem.isActive ? 1 : 0
                                border.color: ColorUtils.applyAlpha(root.accentColor, 0.7)

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
    // 2. CENTER IPHONE DYNAMIC ISLAND (Morphs & Expands In-Place!)
    //    - Idle: Compact floating pill showing ONLY Date & Time
    //    - Music Playing: Widens with Album Art + Animated Waveform
    //    - Hovered: Smoothly expands downward showing Calendar, Tasks,
    //      Uptime & Expanded Media Player (when playing) — NO external popup!
    // ============================================================
    Rectangle {
        id: centerIsland
        visible: root.showClock || root.showCompactMusic
        z: 20
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: root.edgeGapTop
        }

        property bool expanded: false
        property var today: new Date()

        Timer {
            interval: 60000
            running: true
            repeat: true
            onTriggered: centerIsland.today = new Date()
        }

        Timer {
            id: centerCollapseTimer
            interval: 160
            onTriggered: {
                if (!centerHover.hovered) {
                    centerIsland.expanded = false;
                    root.keepMediaWhileExpanded = false;
                }
            }
        }

        HoverHandler {
            id: centerHover
            onHoveredChanged: {
                if (hovered) {
                    centerCollapseTimer.stop();
                    if (root.isMusicPlaying) root.keepMediaWhileExpanded = true;
                    centerIsland.today = new Date();
                    centerIsland.expanded = true;
                } else {
                    centerCollapseTimer.restart();
                }
            }
        }

        readonly property real collapsedW: compactIslandRow.implicitWidth + 28
        readonly property real expandedW: 368
        readonly property real expandedH: centerExpandedCol.implicitHeight + 28

        width: expanded ? expandedW : collapsedW
        height: expanded ? expandedH : root.pillHeight
        radius: expanded ? 26 : root.pillHeight / 2
        clip: true
        color: expanded ? root.islandBgHover : root.islandBg
        border.width: root.showBorder ? 1 : 0
        border.color: expanded
            ? ColorUtils.applyAlpha(root.accentColor, 0.35)
            : Qt.rgba(1, 1, 1, 0.15)

        Behavior on width {
            NumberAnimation {
                duration: centerIsland.expanded ? 460 : 300
                easing.type: Easing.BezierSpline
                easing.bezierCurve: centerIsland.expanded
                    ? Appearance.animationCurves.expressiveFastSpatial
                    : Appearance.animationCurves.emphasizedAccel
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: centerIsland.expanded ? 480 : 280
                easing.type: Easing.BezierSpline
                easing.bezierCurve: centerIsland.expanded
                    ? Appearance.animationCurves.expressiveFastSpatial
                    : Appearance.animationCurves.emphasizedAccel
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: centerIsland.expanded ? 420 : 260
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        // Inner top glass rim
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)
            z: 30
        }

        // Scroll volume when hovering media in Dynamic Island
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                if (root.showCompactMusic || root.showExpandedMusic) {
                    if (wheel.angleDelta.y > 0) Audio.incrementVolume();
                    else if (wheel.angleDelta.y < 0) Audio.decrementVolume();
                }
            }
        }

        // --- COMPACT PILL CONTENT (Date & Time + Live Playing Art/Waveform when music plays) ---
        RowLayout {
            id: compactIslandRow
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            height: root.pillHeight
            spacing: 8
            opacity: centerIsland.expanded ? 0 : 1
            visible: opacity > 0.02

            Behavior on opacity {
                NumberAnimation { duration: centerIsland.expanded ? 110 : 220; easing.type: Easing.OutCubic }
            }

            // Compact Album Art (ONLY shown while music is actively playing)
            Item {
                visible: root.showCompactMusic
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20

                Rectangle {
                    anchors.fill: parent
                    radius: 10
                    color: ColorUtils.applyAlpha(root.accentColor, 0.32)
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "music_note"
                        iconSize: 12
                        color: "#ffffff"
                    }
                }

                Image {
                    id: compactArt
                    anchors.fill: parent
                    source: root.activePlayer?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    asynchronous: true
                    cache: true
                }

                Rectangle {
                    id: compactArtMask
                    anchors.fill: parent
                    radius: 10
                    visible: false
                }

                OpacityMask {
                    anchors.fill: parent
                    source: compactArt
                    maskSource: compactArtMask
                    visible: compactArt.status === Image.Ready
                }
            }

            // Date & Time (always centered in idle state)
            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 6

                StyledText {
                    visible: Config.options.time.showDate
                    text: Qt.locale().toString(DateTime.clock.date, "ddd d MMM")
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Qt.rgba(1, 1, 1, 0.85)
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

                Rectangle {
                    visible: Notifications.unread > 0 && !Notifications.silent
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 5
                    Layout.preferredHeight: 5
                    radius: 2.5
                    color: root.accentColor
                }
            }

            // Animated 3-bar Dynamic Island Sound Waveform (ONLY while music is actively playing)
            Row {
                visible: root.showCompactMusic
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Repeater {
                    model: [
                        { lo: 4, hi: 13, dur: 420 },
                        { lo: 6, hi: 15, dur: 330 },
                        { lo: 4, hi: 11, dur: 490 }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: 2.5
                        height: modelData.lo
                        radius: 1.25
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.macGreen

                        SequentialAnimation on height {
                            running: root.showCompactMusic && !centerIsland.expanded
                            loops: Animation.Infinite
                            NumberAnimation { to: modelData.hi; duration: modelData.dur; easing.type: Easing.InOutSine }
                            NumberAnimation { to: modelData.lo; duration: modelData.dur; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }

        // --- EXPANDED DYNAMIC ISLAND CONTENT (Calendar + Tasks + Live Media Player) ---
        ColumnLayout {
            id: centerExpandedCol
            anchors {
                top: parent.top
                topMargin: 14
                horizontalCenter: parent.horizontalCenter
            }
            width: centerIsland.expandedW - 28
            spacing: 11
            opacity: centerIsland.expanded ? 1 : 0
            visible: opacity > 0.02

            transform: Translate {
                y: centerIsland.expanded ? 0 : -12
                Behavior on y {
                    NumberAnimation {
                        duration: 340
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: centerIsland.expanded ? 240 : 110; easing.type: Easing.OutCubic }
            }

            // Expanded Top Row: Month Year + Live Time & Day Pill
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Row {
                    spacing: 6
                    StyledText {
                        text: Qt.locale().toString(centerIsland.today, "MMMM")
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: "#ffffff"
                    }
                    StyledText {
                        text: Qt.locale().toString(centerIsland.today, "yyyy")
                        font.pixelSize: 18
                        color: root.fgMuted
                    }
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    text: DateTime.time
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    font.features: ({ "tnum": 1 })
                    color: Qt.rgba(1, 1, 1, 0.90)
                }

                Rectangle {
                    Layout.preferredWidth: expDayLabel.implicitWidth + 14
                    Layout.preferredHeight: 22
                    radius: 11
                    color: ColorUtils.applyAlpha(root.accentColor, 0.28)
                    border.width: 1
                    border.color: ColorUtils.applyAlpha(root.accentColor, 0.5)

                    StyledText {
                        id: expDayLabel
                        anchors.centerIn: parent
                        text: Qt.locale().toString(centerIsland.today, "dddd")
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: "#ffffff"
                    }
                }
            }

            // Expanded Now Playing Media Card (ONLY shown when music is playing)
            Rectangle {
                visible: root.showExpandedMusic
                Layout.fillWidth: true
                Layout.preferredHeight: 66
                radius: 16
                color: root.innerCardBg
                border.width: 1
                border.color: root.innerCardBorder

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                    }
                    spacing: 10

                    // 46x46 Rounded Album Art
                    Item {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 46

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: ColorUtils.applyAlpha(root.accentColor, 0.28)
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "music_note"
                                iconSize: 22
                                color: "#ffffff"
                            }
                        }

                        Image {
                            id: expArtImg
                            anchors.fill: parent
                            source: root.activePlayer?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                            asynchronous: true
                            cache: true
                        }

                        Rectangle {
                            id: expArtMask
                            anchors.fill: parent
                            radius: 10
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: expArtImg
                            maskSource: expArtMask
                            visible: expArtImg.status === Image.Ready
                        }
                    }

                    // Track Title + Artist
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: root.activePlayer
                                ? (StringUtils.cleanMusicTitle(root.activePlayer.trackTitle) || Translation.tr("Now Playing"))
                                : ""
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: "#ffffff"
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.activePlayer
                                ? (root.activePlayer.trackArtist || root.activePlayer.identity || "")
                                : ""
                            font.pixelSize: 11
                            color: root.fgMuted
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    // Transport Controls (Prev / Play-Pause / Next)
                    Row {
                        spacing: 3

                        IslandMediaBtn {
                            icon: "skip_previous"
                            iconSz: 18
                            onClicked: root.activePlayer?.previous()
                        }

                        IslandMediaBtn {
                            icon: (root.activePlayer?.isPlaying ?? false) ? "pause" : "play_arrow"
                            iconSz: 19
                            filled: true
                            primary: true
                            onClicked: root.activePlayer?.togglePlaying()
                        }

                        IslandMediaBtn {
                            icon: "skip_next"
                            iconSz: 18
                            onClicked: root.activePlayer?.next()
                        }
                    }
                }
            }

            // 7-Day Calendar Week Strip
            RowLayout {
                Layout.fillWidth: true
                spacing: 5

                Repeater {
                    model: 7
                    delegate: Rectangle {
                        required property int index

                        readonly property var date: {
                            const t = centerIsland.today;
                            const d = new Date(t);
                            d.setDate(t.getDate() - t.getDay() + index);
                            return d;
                        }
                        readonly property bool isToday: {
                            const t = centerIsland.today;
                            return date.getDate() === t.getDate() &&
                                   date.getMonth() === t.getMonth() &&
                                   date.getFullYear() === t.getFullYear();
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 13
                        color: isToday ? root.accentColor : root.innerCardBg
                        border.width: 1
                        border.color: isToday
                            ? ColorUtils.applyAlpha(root.accentColor, 0.9)
                            : root.innerCardBorder

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.locale().toString(date, "ddd").slice(0, 2)
                                font.pixelSize: 10
                                font.weight: isToday ? Font.DemiBold : Font.Medium
                                color: isToday ? Qt.rgba(1, 1, 1, 0.88) : root.fgMuted
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: date.getDate()
                                font.pixelSize: isToday ? 14 : 13
                                font.weight: isToday ? Font.Bold : Font.Medium
                                font.features: ({ "tnum": 1 })
                                color: "#ffffff"
                            }
                        }
                    }
                }
            }

            // Tasks Card inside Dynamic Island
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: tasksInnerRow.implicitHeight + 14
                radius: 14
                color: root.innerCardBg
                border.width: 1
                border.color: root.innerCardBorder

                RowLayout {
                    id: tasksInnerRow
                    anchors {
                        fill: parent
                        margins: 7
                    }
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        radius: 10
                        color: ColorUtils.applyAlpha(root.accentColor, 0.24)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "checklist"
                            iconSize: 17
                            color: "#ffffff"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Repeater {
                            model: Math.min(2, Todo.list.filter(t => !t.done).length)
                            delegate: StyledText {
                                required property int index
                                readonly property var filtered: Todo.list.filter(t => !t.done)
                                readonly property var todo: filtered[filtered.length - 1 - index]
                                Layout.fillWidth: true
                                text: `•  ${todo.content}`
                                font.pixelSize: 12
                                color: root.fgColor
                                elide: Text.ElideRight
                            }
                        }

                        StyledText {
                            visible: Todo.list.filter(t => !t.done).length === 0
                            text: Translation.tr("No pending tasks")
                            font.pixelSize: 12
                            color: root.fgMuted
                        }
                    }

                    StyledText {
                        text: `${Todo.list.filter(t => !t.done).length}`
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        font.features: ({ "tnum": 1 })
                        color: root.accentColor
                        Layout.rightMargin: 4
                    }
                }
            }

            // System Uptime Footer
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                MaterialSymbol {
                    text: "timelapse"
                    iconSize: 13
                    color: root.fgMuted
                }

                StyledText {
                    text: `${Translation.tr("System Uptime")}  •  ${DateTime.uptime}`
                    font.pixelSize: 11
                    color: root.fgMuted
                }
            }
        }
    }

    // ============================================================
    // 3. RIGHT FLOATING PILL / EXPANDABLE BATTERY ISLAND
    //    - Default: Compact floating pill with Tray + Battery + Controls
    //    - Hovering Battery: Right Island itself smoothly expands downward
    //      to reveal Battery details (percentage, time, bar, health, power)
    //      — NO external BatteryPopup!
    // ============================================================
    Rectangle {
        id: rightIsland
        visible: root.showTray || root.showBattery || root.showWifi || root.showBluetooth || root.showVolume || root.showSpotlight || root.showControlCenter
        z: 15
        anchors {
            right: parent.right
            rightMargin: root.edgeGapSide
            top: parent.top
            topMargin: root.edgeGapTop
        }

        property bool batteryExpanded: false

        Timer {
            id: batteryCollapseTimer
            interval: 160
            onTriggered: {
                if (!batteryItem.mouseArea.containsMouse && !batteryDetailsHover.hovered) {
                    rightIsland.batteryExpanded = false;
                }
            }
        }

        readonly property real collapsedW: rightSection.implicitWidth + 18
        readonly property real expandedW: Math.max(collapsedW, 326)
        readonly property real expandedH: root.pillHeight + batteryDetailsCol.implicitHeight + 20

        width: batteryExpanded ? expandedW : collapsedW
        height: batteryExpanded ? expandedH : root.pillHeight
        radius: batteryExpanded ? 22 : root.pillHeight / 2
        clip: true
        color: batteryExpanded ? root.islandBgHover : root.islandBg
        border.width: root.showBorder ? 1 : 0
        border.color: batteryExpanded
            ? ColorUtils.applyAlpha(root.macGreen, 0.35)
            : Qt.rgba(1, 1, 1, 0.14)

        Behavior on width {
            NumberAnimation {
                duration: rightIsland.batteryExpanded ? 440 : 280
                easing.type: Easing.BezierSpline
                easing.bezierCurve: rightIsland.batteryExpanded
                    ? Appearance.animationCurves.expressiveFastSpatial
                    : Appearance.animationCurves.emphasizedAccel
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: rightIsland.batteryExpanded ? 460 : 260
                easing.type: Easing.BezierSpline
                easing.bezierCurve: rightIsland.batteryExpanded
                    ? Appearance.animationCurves.expressiveFastSpatial
                    : Appearance.animationCurves.emphasizedAccel
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: rightIsland.batteryExpanded ? 400 : 240
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        // Inner top glass rim
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)
            z: 30
        }

        // Top Header Row (always pinned to top-right inside the pill)
        RowLayout {
            id: rightSection
            anchors {
                top: parent.top
                right: parent.right
                rightMargin: 9
            }
            height: root.pillHeight
            spacing: 1

            SysTray {
                visible: root.showTray && SystemTray.items.values.length > 0
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 2
                contentColor: root.fgColor
                contentColorOverridden: true
                implicitHeight: root.pillHeight
            }

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

            // Battery Trigger — hovering expands rightIsland in-place!
            MenuBarItem {
                id: batteryItem
                visible: root.showBattery && Battery.available
                horizontalPad: 6
                active: rightIsland.batteryExpanded
                onClicked: GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen

                Connections {
                    target: batteryItem.mouseArea
                    function onContainsMouseChanged() {
                        if (batteryItem.mouseArea.containsMouse) {
                            batteryCollapseTimer.stop();
                            rightIsland.batteryExpanded = true;
                        } else {
                            batteryCollapseTimer.restart();
                        }
                    }
                }

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
            }

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

        // --- IN-PLACE EXPANDED BATTERY DETAILS (Inside Right Island) ---
        Item {
            id: batteryDetailsWrap
            anchors {
                top: parent.top
                topMargin: root.pillHeight + 4
                left: parent.left
                right: parent.right
                leftMargin: 14
                rightMargin: 14
            }
            height: batteryDetailsCol.implicitHeight + 12
            opacity: rightIsland.batteryExpanded ? 1 : 0
            visible: opacity > 0.02

            transform: Translate {
                y: rightIsland.batteryExpanded ? 0 : -10
                Behavior on y {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                    }
                }
            }

            Behavior on opacity {
                NumberAnimation { duration: rightIsland.batteryExpanded ? 230 : 100; easing.type: Easing.OutCubic }
            }

            HoverHandler {
                id: batteryDetailsHover
                onHoveredChanged: {
                    if (hovered) {
                        batteryCollapseTimer.stop();
                        rightIsland.batteryExpanded = true;
                    } else {
                        batteryCollapseTimer.restart();
                    }
                }
            }

            readonly property bool healthKnown: Battery.health > 0
            readonly property bool showTime: !(Battery.chargeState == 4
                || (Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty) <= 0
                || Battery.energyRate <= 0.01)

            ColumnLayout {
                id: batteryDetailsCol
                width: parent.width
                spacing: 10

                // Subtle divider between top pill row & expanded battery panel
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.rgba(1, 1, 1, 0.12)
                }

                // Battery Header: Icon + Status + Giant %
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 12
                        color: (batteryItem.charging || batteryItem.pluggedIn)
                            ? ColorUtils.applyAlpha(root.macGreen, 0.22)
                            : (batteryItem.low
                                ? ColorUtils.applyAlpha(root.macRed, 0.22)
                                : ColorUtils.applyAlpha(root.accentColor, 0.22))

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: (batteryItem.charging || batteryItem.pluggedIn) ? "battery_charging_full" : "battery_full"
                            iconSize: 20
                            color: (batteryItem.charging || batteryItem.pluggedIn)
                                ? root.macGreen
                                : (batteryItem.low ? root.macRed : "#ffffff")
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        StyledText {
                            text: Translation.tr("Battery")
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: "#ffffff"
                        }

                        StyledText {
                            font.pixelSize: 11
                            color: root.fgMuted
                            text: {
                                if (Battery.chargeState == 4)
                                    return Translation.tr("Fully charged");
                                if (Battery.isCharging)
                                    return Translation.tr("Charging") + (batteryDetailsWrap.showTime ? " · " + root.formatBatteryTime(Battery.timeToFull) : "");
                                return Translation.tr("Remaining") + (batteryDetailsWrap.showTime ? " · " + root.formatBatteryTime(Battery.timeToEmpty) : "");
                            }
                        }
                    }

                    StyledText {
                        text: `${batteryItem.pctInt}%`
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        font.features: ({ "tnum": 1 })
                        color: (batteryItem.charging || batteryItem.pluggedIn)
                            ? root.macGreen
                            : (batteryItem.low ? root.macRed : "#ffffff")
                    }
                }

                // Animated horizontal charge progress bar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 7
                    radius: 3.5
                    color: Qt.rgba(1, 1, 1, 0.12)

                    Rectangle {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                        }
                        width: Math.max(7, parent.width * batteryItem.pct)
                        radius: 3.5
                        color: (batteryItem.charging || batteryItem.pluggedIn)
                            ? root.macGreen
                            : (batteryItem.low ? root.macRed : root.accentColor)

                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                }

                // 2 Side-by-Side Stat Cards: Health & Power Draw
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 62
                        radius: 14
                        color: root.innerCardBg
                        border.width: 1
                        border.color: root.innerCardBorder

                        ColumnLayout {
                            anchors {
                                fill: parent
                                margins: 9
                            }
                            spacing: 2

                            RowLayout {
                                spacing: 5
                                MaterialSymbol {
                                    text: "favorite"
                                    fill: 1
                                    iconSize: 13
                                    color: root.macGreen
                                }
                                StyledText {
                                    text: Translation.tr("Health")
                                    font.pixelSize: 11
                                    color: root.fgMuted
                                }
                            }

                            StyledText {
                                text: batteryDetailsWrap.healthKnown ? `${Math.round(Battery.health)}%` : "—"
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                font.features: ({ "tnum": 1 })
                                color: "#ffffff"
                            }

                            StyledText {
                                text: Battery.chargeCycles > 0
                                    ? `${Battery.chargeCycles} ${Translation.tr("cycles")}`
                                    : Translation.tr("Good condition")
                                font.pixelSize: 10
                                color: root.fgMuted
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 62
                        radius: 14
                        color: root.innerCardBg
                        border.width: 1
                        border.color: root.innerCardBorder

                        ColumnLayout {
                            anchors {
                                fill: parent
                                margins: 9
                            }
                            spacing: 2

                            RowLayout {
                                spacing: 5
                                MaterialSymbol {
                                    text: "bolt"
                                    fill: 1
                                    iconSize: 13
                                    color: root.macOrange
                                }
                                StyledText {
                                    text: Battery.isCharging ? Translation.tr("Charge rate") : Translation.tr("Power draw")
                                    font.pixelSize: 11
                                    color: root.fgMuted
                                }
                            }

                            StyledText {
                                text: Battery.chargeState == 4 ? "0.0 W" : `${Battery.energyRate.toFixed(1)} W`
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                font.features: ({ "tnum": 1 })
                                color: "#ffffff"
                            }

                            StyledText {
                                text: Battery.chargeState == 4
                                    ? Translation.tr("Full")
                                    : (Battery.isCharging ? Translation.tr("Plugged in") : Translation.tr("On battery"))
                                font.pixelSize: 10
                                color: root.fgMuted
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // MEDIA BUTTON FOR EXPANDED DYNAMIC ISLAND
    // ============================================================
    component IslandMediaBtn: Item {
        id: mBtn
        property string icon: ""
        property int iconSz: 18
        property bool filled: false
        property bool primary: false
        signal clicked()

        width: primary ? 32 : 28
        height: primary ? 32 : 28

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: mBtn.primary
                ? (mBtnMouse.pressed ? Qt.rgba(1, 1, 1, 0.78) : (mBtnMouse.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.92)))
                : (mBtnMouse.pressed ? Qt.rgba(1, 1, 1, 0.24) : (mBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"))

            Behavior on color { ColorAnimation { duration: 110 } }

            MaterialSymbol {
                anchors.centerIn: parent
                text: mBtn.icon
                iconSize: mBtn.iconSz
                fill: mBtn.filled ? 1 : 0
                color: mBtn.primary ? "#11141c" : "#ffffff"
            }
        }

        MouseArea {
            id: mBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mBtn.clicked()
        }
    }

    // ============================================================
    // REUSABLE PILL ITEM WRAPPER
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
        implicitHeight: root.pillHeight

        Rectangle {
            anchors {
                fill: parent
                topMargin: 4
                bottomMargin: 4
            }
            radius: 12
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
