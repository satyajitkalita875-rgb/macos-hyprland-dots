import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.ii.settings.pages
import qs.modules.common.widgets
import qs.modules.common.functions as CF

Item {
    id: root
    property real contentPadding: 8
    property int currentPage: 0
    property bool showingProfile: false
    property bool isMinimal: Config.options.settings.style === "minimal"
    readonly property bool isMacos: Config.options.settings.style === "macos"
    property real windowRadius: root.isMacos ? 16 : 0
    property bool panelVisible: true

    property Item dragTarget: null
    signal requestClose()
    signal requestToggleExpand()
    signal requestStartDrag()
    signal requestResetPosition()

    property string macSearchQuery: ""
    property var navHistory: [{ page: 0, profile: false }]
    property int navHistoryIndex: 0
    property bool _navigatingHistory: false
    property bool macConfigCopied: false

    readonly property bool canGoBack: navHistoryIndex > 0
    readonly property bool canGoForward: navHistoryIndex < navHistory.length - 1

    readonly property var macSearchResults: {
        const q = root.macSearchQuery.trim();
        if (q.length === 0) return [];
        return SettingsSearchIndex.search(q, 16);
    }

    readonly property string activePageTitle: root.showingProfile
        ? Translation.tr("Profile")
        : (root.pages[root.currentPage]?.name ?? Translation.tr("Settings"))

    function macBadgeColor(pageId) {
        switch (pageId) {
            case "quick":         return "#FF9500";
            case "general":       return "#8E8E93";
            case "bar":           return "#0A84FF";
            case "dynamicIsland": return "#BF5AF2";
            case "desktop":       return "#32ADE6";
            case "interface":     return "#5E5CE6";
            case "services":      return "#30D158";
            case "hyprland":      return "#FF375F";
            case "niri":          return "#AF52DE";
            case "about":         return "#636366";
            default:              return "#0A84FF";
        }
    }

    function selectPage(idx, isProfile) {
        const targetProfile = Boolean(isProfile);
        const targetIdx = idx;
        if (root.currentPage === targetIdx && root.showingProfile === targetProfile) return;
        root.currentPage = targetIdx;
        root.showingProfile = targetProfile;
        if (!_navigatingHistory) {
            const next = root.navHistory.slice(0, root.navHistoryIndex + 1);
            next.push({ page: targetIdx, profile: targetProfile });
            if (next.length > 30) next.shift();
            root.navHistory = next;
            root.navHistoryIndex = next.length - 1;
        }
    }

    function goBack() {
        if (!root.canGoBack) return;
        _navigatingHistory = true;
        root.navHistoryIndex -= 1;
        const entry = root.navHistory[root.navHistoryIndex];
        root.currentPage = entry.page;
        root.showingProfile = entry.profile;
        _navigatingHistory = false;
    }

    function goForward() {
        if (!root.canGoForward) return;
        _navigatingHistory = true;
        root.navHistoryIndex += 1;
        const entry = root.navHistory[root.navHistoryIndex];
        root.currentPage = entry.page;
        root.showingProfile = entry.profile;
        _navigatingHistory = false;
    }

    function goToTarget(target) {
        const idx = root.pages.findIndex(p => p.id === target.page);
        if (idx < 0) return;
        root.selectPage(idx, false);
        if (!target.label) return;

        const loader = pagesRepeater.itemAt(idx);
        if (!loader) return;
        const run = () => loader.item?.goTo(target.label, target.section, target.subsection);
        if (loader.item) {
            run();
        } else {
            const onceLoaded = () => {
                loader.loaded.disconnect(onceLoaded);
                run();
            };
            loader.loaded.connect(onceLoaded);
        }
    }

    Connections {
        target: GlobalStates
        function onSettingsTargetChanged() {
            const target = GlobalStates.settingsTarget;
            if (!target) return;
            root.goToTarget(target);
            GlobalStates.settingsTarget = null;
        }
        function onSettingsOpenChanged() {
            if (!GlobalStates.settingsOpen) {
                root.macSearchQuery = "";
                if (macSearchInput) macSearchInput.text = "";
            }
        }
    }

    onCurrentPageChanged: {
        if (root.pages[currentPage]?.id === "about") {
            if (SystemInfo.cpu === "") SystemInfo.refresh()
            Updates.refresh()
        }
    }

    property var pages: SettingsPages.pages

    Timer {
        id: macCopyResetTimer
        interval: 1500
        onTriggered: root.macConfigCopied = false
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: root.isMacos ? 0 : contentPadding
        }
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.isMacos ? 0 : contentPadding

            // =================================================================
            // Default / Minimal Material You Navigation Rail (lazy-loaded only when not in macOS mode)
            // =================================================================
            Loader {
                id: navRailLoader
                active: !root.isMacos
                visible: active
                Layout.fillHeight: true
                Layout.margins: 0
                sourceComponent: Rectangle {
                    id: navRailWrapper
                    implicitWidth: navRail.expanded ? 195 : fab.baseSize
                    color: root.isMinimal ? "transparent" : Appearance.colors.colLayer1
                    radius: Appearance.rounding.normal

                    Behavior on implicitWidth {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }

                    NavigationRail {
                        id: navRail
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 20 }
                        spacing: 10
                        expanded: root.width > 900

                        Item {
                            id: profileRowContainer
                            visible: true
                            Layout.fillWidth: false
                            Layout.margins: root.isMinimal ? 0 : 5
                            Layout.topMargin: 15
                            Layout.bottomMargin: root.isMinimal ? -30 : 0
                            implicitHeight: profileRow.implicitHeight
                            implicitWidth: profileRow.implicitWidth

                            RowLayout {
                                id: profileRow
                                anchors.fill: parent
                                spacing: 10

                                UserAvatar {
                                    width: 48
                                    height: 48
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Layout.fillWidth: true
                                    visible: !root.isMinimal

                                    StyledText {
                                        text: Config.options.profile.displayName === "" ? SystemInfo.username : Config.options.profile.displayName
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        color: Appearance.colors.colOnLayer1
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 100
                                    }

                                    StyledText {
                                        id: distroText
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colSubtext
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 100

                                        text: {
                                            const d = Config.options.profile.descriptionText
                                            if (d === "::uptime::") return Translation.tr("Up • %1").arg(DateTime.uptime)
                                            return SystemInfo.distroName
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectPage(root.currentPage, !root.showingProfile)
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: root.isMinimal ? 50 : 160
                            Layout.topMargin: root.isMinimal ? 30 : -5
                            Layout.bottomMargin: root.isMinimal ? -30 : 0
                            height: 2
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.2; color: Appearance.colors.colOutline }
                                GradientStop { position: 0.8; color: Appearance.colors.colOutline }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                            opacity: 0.15
                        }

                        FloatingActionButton {
                            id: fab
                            visible: !root.isMinimal
                            Layout.bottomMargin: -25
                            property bool justCopied: false
                            iconText: justCopied ? "check" : "edit"
                            buttonText: justCopied ? Translation.tr("Path copied") : Translation.tr("Config file")
                            expanded: navRail.expanded
                            downAction: () => {
                                Qt.openUrlExternally(`${Directories.config}/illogical-impulse/config.json`);
                            }
                            altAction: () => {
                                Quickshell.clipboardText = CF.FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/config.json`);
                                fab.justCopied = true;
                                revertTextTimer.restart()
                            }
                            Timer {
                                id: revertTextTimer
                                interval: 1500
                                onTriggered: fab.justCopied = false
                            }
                            StyledToolTip {
                                text: Translation.tr("Open the shell config file\nAlternatively right-click to copy path")
                            }
                        }

                        NavigationRailTabArray {
                            currentIndex: root.currentPage
                            expanded: navRail.expanded
                            colToggled: root.showingProfile ? "transparent" : Appearance.colors.colSecondaryContainer
                            Repeater {
                                model: root.pages
                                NavigationRailButton {
                                    required property var index
                                    required property var modelData
                                    toggled: root.currentPage === index && !root.showingProfile
                                    onPressed: root.selectPage(index, false)
                                    expanded: navRail.expanded
                                    buttonIcon: modelData.icon
                                    buttonIconRotation: modelData.iconRotation || 0
                                    buttonText: modelData.name
                                    showToggledHighlight: false
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // macOS System Settings Sidebar
            // =================================================================
            Rectangle {
                id: macSidebar
                visible: root.isMacos
                Layout.fillHeight: true
                Layout.preferredWidth: 238
                Layout.minimumWidth: 238
                topLeftRadius: root.windowRadius
                bottomLeftRadius: root.windowRadius
                topRightRadius: 0
                bottomRightRadius: 0
                color: CF.ColorUtils.applyAlpha(
                    Appearance.m3colors.darkmode ? "#000000" : "#ffffff",
                    Appearance.m3colors.darkmode ? 0.22 : 0.30
                )

                // Right hairline separator
                Rectangle {
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        right: parent.right
                    }
                    width: 1
                    color: CF.ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.10)
                    z: 2
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // Top Window Chrome: Traffic Lights + Double-Click Expand Strip
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46

                        MouseArea {
                            anchors.fill: parent
                            onDoubleClicked: root.requestToggleExpand()
                        }

                        Row {
                            id: trafficLights
                            anchors {
                                left: parent.left
                                leftMargin: 16
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 8

                            readonly property bool groupHovered: closeBtn.hovered || minBtn.hovered || maxBtn.hovered

                            // Close (Red)
                            Rectangle {
                                id: closeBtn
                                property alias hovered: closeMouse.containsMouse
                                width: 12
                                height: 12
                                radius: 6
                                color: closeMouse.pressed ? "#BF4942" : "#FF5F57"
                                border.width: 0.5
                                border.color: Qt.rgba(0, 0, 0, 0.18)

                                Text {
                                    anchors.centerIn: parent
                                    visible: trafficLights.groupHovered
                                    text: "×"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: "#4D0000"
                                }

                                MouseArea {
                                    id: closeMouse
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.requestClose()
                                }
                            }

                            // Minimize / Hide (Yellow)
                            Rectangle {
                                id: minBtn
                                property alias hovered: minMouse.containsMouse
                                width: 12
                                height: 12
                                radius: 6
                                color: minMouse.pressed ? "#BF8E22" : "#FEBC2E"
                                border.width: 0.5
                                border.color: Qt.rgba(0, 0, 0, 0.18)

                                Text {
                                    anchors.centerIn: parent
                                    visible: trafficLights.groupHovered
                                    text: "−"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: "#6B4500"
                                }

                                MouseArea {
                                    id: minMouse
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.requestClose()
                                }
                            }

                            // Zoom / Expand (Green)
                            Rectangle {
                                id: maxBtn
                                property alias hovered: maxMouse.containsMouse
                                width: 12
                                height: 12
                                radius: 6
                                color: maxMouse.pressed ? "#1E9630" : "#28C840"
                                border.width: 0.5
                                border.color: Qt.rgba(0, 0, 0, 0.18)

                                Text {
                                    anchors.centerIn: parent
                                    visible: trafficLights.groupHovered
                                    text: "+"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: "#004D0F"
                                }

                                MouseArea {
                                    id: maxMouse
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.requestToggleExpand()
                                }
                            }
                        }
                    }

                    // macOS Search Bar
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        Layout.bottomMargin: 6

                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 3
                            anchors.bottomMargin: 3
                            radius: 8
                            color: CF.ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, macSearchInput.activeFocus ? 0.11 : 0.07)
                            border.width: 1
                            border.color: macSearchInput.activeFocus
                                ? CF.ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.7)
                                : CF.ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.08)

                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            MaterialSymbol {
                                id: macSearchIcon
                                anchors {
                                    left: parent.left
                                    leftMargin: 8
                                    verticalCenter: parent.verticalCenter
                                }
                                text: "search"
                                iconSize: 15
                                color: Appearance.colors.colSubtext
                            }

                            Text {
                                anchors {
                                    left: macSearchIcon.right
                                    leftMargin: 6
                                    verticalCenter: parent.verticalCenter
                                }
                                visible: macSearchInput.text.length === 0
                                text: Translation.tr("Search")
                                font.family: Appearance.font.family.main
                                font.pixelSize: 13
                                color: Appearance.colors.colSubtext
                            }

                            TextInput {
                                id: macSearchInput
                                anchors {
                                    left: macSearchIcon.right
                                    right: macSearchClear.visible ? macSearchClear.left : parent.right
                                    top: parent.top
                                    bottom: parent.bottom
                                    leftMargin: 6
                                    rightMargin: 6
                                }
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                font.family: Appearance.font.family.main
                                font.pixelSize: 13
                                color: Appearance.colors.colOnLayer0
                                selectionColor: Appearance.colors.colSecondaryContainer
                                selectedTextColor: Appearance.colors.colOnSecondaryContainer
                                onTextChanged: root.macSearchQuery = text

                                Keys.onEscapePressed: {
                                    if (text.length > 0) {
                                        text = "";
                                    } else {
                                        root.requestClose();
                                    }
                                }
                                Keys.onReturnPressed: {
                                    if (root.macSearchResults.length > 0) {
                                        const first = root.macSearchResults[0];
                                        root.goToTarget({
                                            page: first.pageId,
                                            label: first.rawLabel ?? "",
                                            section: first.rawSection ?? "",
                                            subsection: first.rawSubsection ?? ""
                                        });
                                        text = "";
                                    }
                                }
                            }

                            Rectangle {
                                id: macSearchClear
                                visible: macSearchInput.text.length > 0
                                anchors {
                                    right: parent.right
                                    rightMargin: 6
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 16
                                height: 16
                                radius: 8
                                color: CF.ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.22)

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: 11
                                    color: Appearance.colors.colOnLayer0
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        macSearchInput.text = "";
                                        macSearchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }

                    // Sidebar Scrollable Content (Profile + Nav List OR Live Search Results)
                    Flickable {
                        id: macSidebarFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: macSidebarCol.implicitHeight + 12
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: macSidebarCol
                            width: macSidebarFlick.width - 20
                            x: 10
                            y: 2
                            spacing: 2

                            // Apple Account / User Profile Row
                            Rectangle {
                                visible: root.macSearchQuery.trim().length === 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: 54
                                Layout.bottomMargin: 8
                                radius: 10
                                color: root.showingProfile
                                    ? Appearance.colors.colPrimary
                                    : (macProfileMouse.containsMouse
                                        ? CF.ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.06)
                                        : "transparent")

                                Behavior on color { ColorAnimation { duration: 110 } }

                                RowLayout {
                                    anchors {
                                        fill: parent
                                        leftMargin: 8
                                        rightMargin: 8
                                    }
                                    spacing: 10

                                    UserAvatar {
                                        width: 38
                                        height: 38
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: Config.options.profile.displayName === "" ? SystemInfo.username : Config.options.profile.displayName
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            color: root.showingProfile ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            font.pixelSize: 11
                                            color: root.showingProfile
                                                ? CF.ColorUtils.applyAlpha(Appearance.colors.colOnPrimary, 0.8)
                                                : Appearance.colors.colSubtext
                                            elide: Text.ElideRight
                                            text: {
                                                const d = Config.options.profile.descriptionText;
                                                if (d === "::uptime::") return Translation.tr("Up • %1").arg(DateTime.uptime);
                                                return SystemInfo.distroName;
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: macProfileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectPage(root.currentPage, true)
                                }
                            }

                            // Category Items (when not searching)
                            Repeater {
                                model: root.macSearchQuery.trim().length === 0 ? root.pages : []

                                delegate: Rectangle {
                                    id: macNavItem
                                    required property var modelData
                                    required property int index
                                    readonly property bool selected: root.currentPage === index && !root.showingProfile

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: 7
                                    color: selected
                                        ? Appearance.colors.colPrimary
                                        : (macNavMouse.containsMouse
                                            ? CF.ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.06)
                                            : "transparent")

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    RowLayout {
                                        anchors {
                                            fill: parent
                                            leftMargin: 8
                                            rightMargin: 8
                                        }
                                        spacing: 9

                                        // macOS colorful squircle icon badge
                                        Rectangle {
                                            Layout.preferredWidth: 22
                                            Layout.preferredHeight: 22
                                            radius: 5.5
                                            color: root.macBadgeColor(macNavItem.modelData.id)

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: parent.radius
                                                gradient: Gradient {
                                                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.22) }
                                                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.08) }
                                                }
                                            }

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: macNavItem.modelData.icon
                                                iconSize: 14
                                                fill: 1
                                                rotation: macNavItem.modelData.iconRotation || 0
                                                color: "#FFFFFF"
                                            }
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: macNavItem.modelData.name
                                            font.pixelSize: 13
                                            font.weight: macNavItem.selected ? Font.DemiBold : Font.Normal
                                            color: macNavItem.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: macNavMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.selectPage(macNavItem.index, false)
                                    }
                                }
                            }

                            // Live Search Results (when searching)
                            Repeater {
                                model: root.macSearchQuery.trim().length > 0 ? root.macSearchResults : []

                                delegate: Rectangle {
                                    id: searchResItem
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 42
                                    radius: 7
                                    color: searchResMouse.containsMouse
                                        ? CF.ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.22)
                                        : "transparent"

                                    RowLayout {
                                        anchors {
                                            fill: parent
                                            leftMargin: 8
                                            rightMargin: 8
                                        }
                                        spacing: 9

                                        Rectangle {
                                            Layout.preferredWidth: 22
                                            Layout.preferredHeight: 22
                                            radius: 5.5
                                            color: root.macBadgeColor(searchResItem.modelData.pageId)

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: searchResItem.modelData.icon || "settings"
                                                iconSize: 14
                                                fill: 1
                                                color: "#FFFFFF"
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: searchResItem.modelData.label
                                                font.pixelSize: 12
                                                font.weight: Font.Medium
                                                color: Appearance.colors.colOnLayer0
                                                elide: Text.ElideRight
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: searchResItem.modelData.section
                                                    ? `${searchResItem.modelData.pageName} › ${searchResItem.modelData.section}`
                                                    : searchResItem.modelData.pageName
                                                font.pixelSize: 11
                                                color: Appearance.colors.colSubtext
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: searchResMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.goToTarget({
                                                page: searchResItem.modelData.pageId,
                                                label: searchResItem.modelData.rawLabel ?? "",
                                                section: searchResItem.modelData.rawSection ?? "",
                                                subsection: searchResItem.modelData.rawSubsection ?? ""
                                            });
                                            macSearchInput.text = "";
                                        }
                                    }
                                }
                            }

                            StyledText {
                                visible: root.macSearchQuery.trim().length > 0 && root.macSearchResults.length === 0
                                Layout.fillWidth: true
                                Layout.topMargin: 18
                                horizontalAlignment: Text.AlignHCenter
                                text: Translation.tr("No Results")
                                font.pixelSize: 12
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }

                    // Bottom Sidebar Utility Bar (Open / Copy config.json)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: CF.ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.08)
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40

                        Rectangle {
                            anchors {
                                fill: parent
                                margins: 6
                            }
                            radius: 7
                            bottomLeftRadius: Math.max(7, root.windowRadius - 6)
                            color: macCfgMouse.containsMouse
                                ? CF.ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.07)
                                : "transparent"

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 8
                                    rightMargin: 8
                                }
                                spacing: 7

                                MaterialSymbol {
                                    text: root.macConfigCopied ? "check" : "tune"
                                    iconSize: 15
                                    color: Appearance.colors.colSubtext
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.macConfigCopied ? Translation.tr("Path copied") : Translation.tr("Config File")
                                    font.pixelSize: 12
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                }

                                MaterialSymbol {
                                    text: "open_in_new"
                                    iconSize: 13
                                    color: Appearance.colors.colSubtext
                                    opacity: 0.65
                                }
                            }

                            MouseArea {
                                id: macCfgMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        Quickshell.clipboardText = CF.FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/config.json`);
                                        root.macConfigCopied = true;
                                        macCopyResetTimer.restart();
                                    } else {
                                        Qt.openUrlExternally(`${Directories.config}/illogical-impulse/config.json`);
                                    }
                                }
                            }

                            StyledToolTip {
                                extraVisibleCondition: macCfgMouse.containsMouse
                                text: Translation.tr("Open the shell config file\nRight-click to copy path")
                            }
                        }
                    }
                }
            }

            // =================================================================
            // Right Content Area (Unified macOS Toolbar + Page Stack)
            // =================================================================
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // macOS Unified Window Titlebar / Toolbar
                Rectangle {
                    id: macToolbar
                    visible: root.isMacos
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    topLeftRadius: 0
                    bottomLeftRadius: 0
                    topRightRadius: root.windowRadius
                    bottomRightRadius: 0
                    color: CF.ColorUtils.applyAlpha(
                        Appearance.m3colors.darkmode ? "#ffffff" : "#000000",
                        Appearance.m3colors.darkmode ? 0.02 : 0.015
                    )

                    // Double-click toolbar to expand/restore
                    MouseArea {
                        anchors.fill: parent
                        onDoubleClicked: root.requestToggleExpand()
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 16
                            rightMargin: 18
                        }
                        spacing: 6

                        // Back / Forward Navigation Chevrons
                        Row {
                            spacing: 2

                            Rectangle {
                                width: 26
                                height: 26
                                radius: 6
                                color: backMouse.containsMouse && root.canGoBack
                                    ? CF.ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.08)
                                    : "transparent"

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "chevron_left"
                                    iconSize: 20
                                    color: Appearance.colors.colOnLayer0
                                    opacity: root.canGoBack ? 0.9 : 0.28
                                }

                                MouseArea {
                                    id: backMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: root.canGoBack
                                    cursorShape: root.canGoBack ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: root.goBack()
                                }
                            }

                            Rectangle {
                                width: 26
                                height: 26
                                radius: 6
                                color: fwdMouse.containsMouse && root.canGoForward
                                    ? CF.ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.08)
                                    : "transparent"

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "chevron_right"
                                    iconSize: 20
                                    color: Appearance.colors.colOnLayer0
                                    opacity: root.canGoForward ? 0.9 : 0.28
                                }

                                MouseArea {
                                    id: fwdMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: root.canGoForward
                                    cursorShape: root.canGoForward ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: root.goForward()
                                }
                            }
                        }

                        StyledText {
                            Layout.leftMargin: 6
                            Layout.fillWidth: true
                            text: root.activePageTitle
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer0
                            elide: Text.ElideRight
                        }
                    }

                    // Bottom hairline divider
                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        height: 1
                        color: CF.ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.09)
                    }
                }

                // Page Container (Shared across Default, Minimal, and macOS)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    radius: root.isMacos ? 0 : (Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut)

                    Item {
                        anchors.fill: parent

                        Repeater {
                            id: pagesRepeater
                            model: root.pages
                            Loader {
                                id: pageLoader
                                required property var modelData
                                required property var index
                                source: modelData.component
                                asynchronous: true

                                property bool isActive: root.currentPage === index && !root.showingProfile
                                active: Config.ready && (root.panelVisible ? (isActive || item !== null) : isActive)

                                anchors.fill: parent

                                opacity: (isActive && status === Loader.Ready) ? 1 : 0
                                enabled: isActive && status === Loader.Ready
                                visible: isActive

                                onLoaded: {
                                    if (isActive) {
                                        GlobalStates.currentPageInstance = item;
                                    }
                                }

                                onIsActiveChanged: {
                                    if (isActive && item) {
                                        GlobalStates.currentPageInstance = item;
                                    } else if (!isActive && GlobalStates.currentPageInstance === item) {
                                        GlobalStates.currentPageInstance = null;
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation { duration: root.isMacos ? 90 : 140; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        Loader {
                            id: profileLoader
                            asynchronous: true
                            property bool isActive: root.showingProfile
                            active: Config.ready && (root.panelVisible ? (isActive || item !== null) : isActive)
                            anchors.fill: parent
                            source: Qt.resolvedUrl("pages/Profile.qml")

                            opacity: (isActive && status === Loader.Ready) ? 1 : 0
                            enabled: isActive && status === Loader.Ready
                            visible: isActive

                            onLoaded: {
                                if (isActive) {
                                    GlobalStates.currentPageInstance = item;
                                }
                            }

                            onIsActiveChanged: {
                                if (isActive && item) {
                                    GlobalStates.currentPageInstance = item;
                                } else if (!isActive && GlobalStates.currentPageInstance === item) {
                                    GlobalStates.currentPageInstance = null;
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: root.isMacos ? 90 : 140; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }
            }
        }
    }
}
