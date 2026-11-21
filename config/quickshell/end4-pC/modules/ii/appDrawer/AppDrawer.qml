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
import Quickshell.Widgets
import Quickshell.Wayland

// macOS Tahoe-style floating Liquid Glass applications popover rising from the dock.
Scope {
    id: root

    function open() { GlobalStates.appDrawerOpen = true }
    function close() { GlobalStates.appDrawerOpen = false }
    function toggle() { GlobalStates.appDrawerOpen = !GlobalStates.appDrawerOpen }

    IpcHandler {
        target: "appDrawer"
        function open() { root.open() }
        function close() { root.close() }
        function toggle() { root.toggle() }
    }

    Variants {
        model: Quickshell.screens
        delegate: Loader {
            id: drawerLoader
            required property var modelData
            property bool initialized: GlobalStates.appDrawerOpen
            active: initialized

            Connections {
                target: GlobalStates
                function onAppDrawerOpenChanged() {
                    if (GlobalStates.appDrawerOpen) {
                        drawerLoader.initialized = true;
                    }
                }
            }

            sourceComponent: PanelWindow {
                id: drawer
                screen: drawerLoader.modelData
                visible: GlobalStates.appDrawerOpen

                property string query: ""
                property string activeCategory: "All"
                property int selectedIndex: -1
                property bool keyboardMode: false

                readonly property string dockPos: DockStyle.position
                readonly property bool glassOn: Config.options?.background?.widgets?.glass?.enable ?? false
                readonly property real dockClearance: Math.max(DockStyle.zone, DockStyle.thickness - Appearance.sizes.elevationMargin) + 14
                readonly property real screenW: drawerLoader.modelData?.width ?? 1920
                readonly property real screenH: drawerLoader.modelData?.height ?? 1080
                readonly property real targetW: Math.min(736, Math.max(520, Math.round(screenW * 0.40)))
                readonly property real targetH: Math.min(548, Math.max(410, Math.round(screenH * 0.54)))
                readonly property real padX: 34
                readonly property real padTop: 26
                readonly property real padBottom: 42

                readonly property var categoryLabels: ({
                    "Network": "Internet",
                    "AudioVideo": "Media",
                    "Utility": "Utilities",
                    "Development": "Developer",
                    "Graphics": "Graphics",
                    "Office": "Productivity",
                    "Game": "Games",
                    "System": "System",
                    "Settings": "Settings",
                    "Education": "Education",
                    "Science": "Science"
                })

                readonly property var categoryOrder: [
                    "Utility", "Network", "Development", "System",
                    "Settings", "AudioVideo", "Graphics", "Office",
                    "Game", "Education", "Science"
                ]

                readonly property var allApps: {
                    void AppSearch.appsRevision;
                    const list = AppSearch.list.slice();
                    list.sort((a, b) => String(a.name ?? "").localeCompare(String(b.name ?? ""), undefined, { sensitivity: "base" }));
                    return list;
                }

                readonly property var availableCategories: {
                    const present = {};
                    for (const app of drawer.allApps) {
                        const cats = app?.categories ?? [];
                        for (const c of cats) {
                            if (drawer.categoryLabels[c]) present[c] = true;
                        }
                    }
                    const out = [{ id: "All", label: "All" }];
                    for (const key of drawer.categoryOrder) {
                        if (present[key]) {
                            out.push({ id: key, label: drawer.categoryLabels[key] });
                        }
                    }
                    return out;
                }

                readonly property var shownApps: {
                    const q = drawer.query.trim();
                    let list = q === "" ? drawer.allApps : AppSearch.fuzzyQuery(q);
                    if (drawer.activeCategory !== "All") {
                        list = list.filter(app => {
                            const cats = app?.categories ?? [];
                            return cats.indexOf(drawer.activeCategory) !== -1;
                        });
                    }
                    return list;
                }

                readonly property var iconCache: {
                    void SystemAppearance.iconRevision;
                    void AppSearch.appsRevision;
                    const cache = {};
                    for (const app of drawer.allApps) {
                        const key = String(app?.id ?? app?.name ?? "");
                        if (key in cache) continue;
                        let url = "";
                        // Prefer the app's original full-color icon resolved live on disk
                        const directFile = String(app?.iconFile ?? "");
                        if (directFile.length > 0) {
                            url = directFile;
                        }
                        if (url === "") {
                            const iconName = String(app?.icon ?? "");
                            if (iconName.length > 0) {
                                const resolved = SystemAppearance.iconPath(iconName, true);
                                if (resolved && resolved.length > 0) url = resolved;
                            }
                        }
                        if (url === "") {
                            const guessed = AppSearch.guessIcon(key);
                            if (guessed && guessed.length > 0) {
                                const guessedPath = SystemAppearance.iconPath(guessed, true);
                                if (guessedPath && guessedPath.length > 0) url = guessedPath;
                            }
                        }
                        cache[key] = url;
                    }
                    return cache;
                }

                function resolveIcon(app) {
                    const key = String(app?.id ?? app?.name ?? "");
                    return drawer.iconCache[key] ?? "";
                }

                function fallbackGlyph(app) {
                    const text = `${app?.name ?? ""} ${app?.id ?? ""} ${app?.icon ?? ""}`.toLowerCase();
                    if (app?.runInTerminal || /term|shell|console|cli|uuctl/.test(text)) return "terminal";
                    if (/setting|config|pref|theme|qt|gtk|tweak/.test(text)) return "tune";
                    if (/hwloc|lstopo|cpu|hardware|monitor|system/.test(text)) return "memory";
                    if (/file|folder|manager/.test(text)) return "folder";
                    if (/edit|note|code/.test(text)) return "edit_note";
                    return "widgets";
                }

                function launch(entry) {
                    if (!entry) return;
                    try {
                        if (entry.runInTerminal) {
                            const cmd = Array.isArray(entry.command) ? entry.command.join(" ") : String(entry.command ?? "");
                            Quickshell.execDetached(["bash", "-c", `${Config.options.apps.terminal} -e '${cmd.replace(/'/g, "'\\''")}'`]);
                        } else {
                            entry.execute();
                        }
                    } finally {
                        root.close();
                    }
                }

                function moveSelection(dx, dy) {
                    const total = drawer.shownApps.length;
                    if (total === 0) return;

                    drawer.keyboardMode = true;
                    const cols = appGrid.columns;
                    if (drawer.selectedIndex < 0 || drawer.selectedIndex >= total) {
                        drawer.selectedIndex = 0;
                        appGrid.positionViewAtIndex(0, GridView.Contain);
                        return;
                    }

                    let col = drawer.selectedIndex % cols;
                    let row = Math.floor(drawer.selectedIndex / cols);

                    if (dx !== 0) {
                        const next = drawer.selectedIndex + dx;
                        drawer.selectedIndex = Math.max(0, Math.min(total - 1, next));
                    } else if (dy !== 0) {
                        const maxRow = Math.floor((total - 1) / cols);
                        const nextRow = Math.max(0, Math.min(maxRow, row + dy));
                        drawer.selectedIndex = Math.min(total - 1, nextRow * cols + col);
                    }
                    appGrid.positionViewAtIndex(drawer.selectedIndex, GridView.Contain);
                }

                onQueryChanged: {
                    appGrid.contentY = 0;
                    if (query.trim().length > 0 && shownApps.length > 0) {
                        drawer.selectedIndex = 0;
                        drawer.keyboardMode = true;
                    } else {
                        drawer.selectedIndex = -1;
                        drawer.keyboardMode = false;
                    }
                }

                onActiveCategoryChanged: {
                    appGrid.contentY = 0;
                    if (drawer.keyboardMode && shownApps.length > 0) {
                        drawer.selectedIndex = 0;
                    } else {
                        drawer.selectedIndex = -1;
                    }
                }

                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "quickshell:appDrawer"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: GlobalStates.appDrawerOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
                color: "transparent"

                mask: Region {
                    item: GlobalStates.appDrawerOpen ? popoverSurface : null
                }

                anchors {
                    bottom: drawer.dockPos === "bottom"
                    left: drawer.dockPos === "left"
                    right: drawer.dockPos === "right"
                }
                margins {
                    bottom: drawer.dockPos === "bottom" ? Math.max(0, drawer.dockClearance - drawer.padBottom) : 0
                    left: drawer.dockPos === "left" ? Math.max(0, drawer.dockClearance - drawer.padX) : 0
                    right: drawer.dockPos === "right" ? Math.max(0, drawer.dockClearance - drawer.padX) : 0
                }
                implicitWidth: drawer.targetW + drawer.padX * 2
                implicitHeight: drawer.targetH + drawer.padTop + drawer.padBottom

                function activateDrawer() {
                    searchField.text = "";
                    drawer.query = "";
                    drawer.activeCategory = "All";
                    drawer.selectedIndex = -1;
                    drawer.keyboardMode = false;
                    appGrid.contentY = 0;
                    Qt.callLater(() => {
                        if (GlobalStates.appDrawerOpen) {
                            GlobalFocusGrab.addDismissable(drawer);
                            searchField.forceActiveFocus();
                        }
                    });
                }

                onVisibleChanged: {
                    if (visible) {
                        GlobalFocusGrab.addDismissable(drawer);
                    } else {
                        GlobalFocusGrab.removeDismissable(drawer);
                    }
                }

                Component.onCompleted: {
                    if (GlobalStates.appDrawerOpen) drawer.activateDrawer();
                }

                Component.onDestruction: {
                    GlobalFocusGrab.removeDismissable(drawer);
                }

                Connections {
                    target: GlobalStates
                    function onAppDrawerOpenChanged() {
                        if (GlobalStates.appDrawerOpen) {
                            drawer.activateDrawer();
                        } else {
                            GlobalFocusGrab.removeDismissable(drawer);
                        }
                    }
                    function onSidebarRightOpenChanged() {
                        if (GlobalStates.sidebarRightOpen && GlobalStates.appDrawerOpen) root.close();
                    }
                    function onOverviewOpenChanged() {
                        if (GlobalStates.overviewOpen && GlobalStates.appDrawerOpen) root.close();
                    }
                    function onSearchOpenChanged() {
                        if (GlobalStates.searchOpen && GlobalStates.appDrawerOpen) root.close();
                    }
                }

                Connections {
                    target: GlobalFocusGrab
                    function onDismissed() {
                        if (GlobalStates.appDrawerOpen) root.close();
                    }
                }

                // Dismiss if clicking in the transparent shadow margin around the popover
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }

                // Floating Apps Popover anchored to the Dock (open/close animated natively by Hyprland layersIn/layersOut)
                Item {
                    id: popoverFrame

                    x: drawer.padX
                    y: drawer.padTop
                    width: drawer.targetW
                    height: drawer.targetH

                    // Soft floating window shadow (alpha kept below ignore_alpha=0.35 so blur stays cleanly inside the rounded card)
                    RectangularShadow {
                        anchors.fill: popoverSurface
                        radius: popoverSurface.radius
                        blur: 32
                        spread: 0
                        offset: Qt.vector2d(0, 12)
                        color: ColorUtils.applyAlpha(Appearance.m3colors.m3shadow, 0.22)
                        cached: true
                    }

                    // Main themed popover card matching system Material You palette
                    Rectangle {
                        id: popoverSurface
                        anchors.fill: parent
                        radius: Appearance.rounding.large
                        color: Appearance.colors.colUiBackground
                        border.width: 1
                        border.color: Appearance.colors.colLayer0Border

                        WindowGlass {
                            anchors.fill: parent
                            glassEnabled: drawer.glassOn
                            cardRadius: parent.radius
                            tint: parent.color
                        }

                        // Swallow clicks inside the popover so it doesn't dismiss
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {}
                        }

                        ColumnLayout {
                            anchors {
                                fill: parent
                                topMargin: 18
                                bottomMargin: 14
                                leftMargin: 18
                                rightMargin: 18
                            }
                            spacing: 12

                            // Header: Spotlight-style Search Pill
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Rectangle {
                                    id: searchPill
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    radius: Appearance.rounding.full
                                    color: searchField.activeFocus
                                        ? Appearance.colors.colLayer2
                                        : (searchHover.hovered ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1)
                                    border.width: 1
                                    border.color: searchField.activeFocus
                                        ? Appearance.colors.colPrimary
                                        : Appearance.colors.colLayer0Border

                                    Behavior on color { ColorAnimation { duration: 140 } }
                                    Behavior on border.color { ColorAnimation { duration: 140 } }

                                    HoverHandler { id: searchHover }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.IBeamCursor
                                        onClicked: searchField.forceActiveFocus()
                                    }

                                    MaterialSymbol {
                                        id: searchGlyph
                                        anchors {
                                            left: parent.left
                                            leftMargin: 14
                                            verticalCenter: parent.verticalCenter
                                        }
                                        text: "search"
                                        iconSize: 19
                                        color: searchField.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                                    }

                                    Text {
                                        anchors {
                                            left: searchGlyph.right
                                            leftMargin: 9
                                            verticalCenter: parent.verticalCenter
                                        }
                                        visible: searchField.text.length === 0
                                        text: "Search Apps"
                                        color: Appearance.colors.colSubtext
                                        font.family: Appearance.font.family.main
                                        font.pixelSize: 14
                                        font.weight: Font.Normal
                                    }

                                    TextInput {
                                        id: searchField
                                        anchors {
                                            left: searchGlyph.right
                                            right: clearBtn.visible ? clearBtn.left : countPill.left
                                            top: parent.top
                                            bottom: parent.bottom
                                            leftMargin: 9
                                            rightMargin: 8
                                        }
                                        verticalAlignment: TextInput.AlignVCenter
                                        color: Appearance.colors.colOnLayer0
                                        selectionColor: Appearance.colors.colSecondaryContainer
                                        selectedTextColor: Appearance.colors.colOnSecondaryContainer
                                        clip: true
                                        font.family: Appearance.font.family.main
                                        font.pixelSize: 14
                                        font.weight: Font.Normal
                                        onTextChanged: drawer.query = text

                                        Keys.onPressed: event => {
                                            if (event.key === Qt.Key_Escape) {
                                                if (searchField.text.length > 0) {
                                                    searchField.text = "";
                                                } else if (drawer.activeCategory !== "All") {
                                                    drawer.activeCategory = "All";
                                                } else {
                                                    root.close();
                                                }
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                                if (drawer.shownApps.length > 0) {
                                                    const idx = drawer.selectedIndex >= 0 && drawer.selectedIndex < drawer.shownApps.length
                                                        ? drawer.selectedIndex
                                                        : 0;
                                                    drawer.launch(drawer.shownApps[idx]);
                                                }
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Right && (searchField.text.length === 0 || searchField.cursorPosition === searchField.text.length)) {
                                                drawer.moveSelection(1, 0);
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Left && (searchField.text.length === 0 || searchField.cursorPosition === 0)) {
                                                drawer.moveSelection(-1, 0);
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Down) {
                                                drawer.moveSelection(0, 1);
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Up) {
                                                drawer.moveSelection(0, -1);
                                                event.accepted = true;
                                            }
                                        }
                                    }

                                    // Subtle app count badge when not typing
                                    Text {
                                        id: countPill
                                        anchors {
                                            right: parent.right
                                            rightMargin: 14
                                            verticalCenter: parent.verticalCenter
                                        }
                                        visible: searchField.text.length === 0
                                        text: `${drawer.shownApps.length}`
                                        color: Appearance.colors.colSubtext
                                        font.family: Appearance.font.family.numbers
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }

                                    // Circular clear button when typing
                                    Rectangle {
                                        id: clearBtn
                                        anchors {
                                            right: parent.right
                                            rightMargin: 10
                                            verticalCenter: parent.verticalCenter
                                        }
                                        width: 20
                                        height: 20
                                        radius: 10
                                        visible: searchField.text.length > 0
                                        color: clearMouse.containsMouse ? Appearance.colors.colLayer3Hover : Appearance.colors.colLayer3

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "close"
                                            iconSize: 13
                                            color: Appearance.colors.colOnLayer3
                                        }

                                        MouseArea {
                                            id: clearMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                searchField.text = "";
                                                searchField.forceActiveFocus();
                                            }
                                        }
                                    }
                                }
                            }

                            // macOS Tahoe Category Filter Pills
                            Flickable {
                                id: categoryBar
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                visible: drawer.availableCategories.length > 1
                                contentWidth: categoryRow.implicitWidth
                                contentHeight: height
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Row {
                                    id: categoryRow
                                    spacing: 6
                                    anchors.verticalCenter: parent.verticalCenter

                                    Repeater {
                                        model: drawer.availableCategories

                                        delegate: Rectangle {
                                            id: catChip
                                            required property var modelData
                                            readonly property bool selected: drawer.activeCategory === modelData.id

                                            height: 28
                                            width: catLabel.implicitWidth + 22
                                            radius: 14
                                            color: selected
                                                ? Appearance.colors.colSecondaryContainer
                                                : (catMouse.containsMouse ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1)
                                            border.width: 1
                                            border.color: selected
                                                ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.45)
                                                : Appearance.colors.colLayer0Border

                                            Behavior on color { ColorAnimation { duration: 140 } }
                                            Behavior on border.color { ColorAnimation { duration: 140 } }

                                            Text {
                                                id: catLabel
                                                anchors.centerIn: parent
                                                text: catChip.modelData.label
                                                color: catChip.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                                font.family: Appearance.font.family.main
                                                font.pixelSize: 12
                                                font.weight: catChip.selected ? Font.DemiBold : Font.Medium
                                            }

                                            MouseArea {
                                                id: catMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    drawer.activeCategory = catChip.modelData.id;
                                                    searchField.forceActiveFocus();
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Subtle hairline divider
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Appearance.colors.colLayer0Border
                            }

                            // Scrollable Borderless macOS App Grid
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                // Empty state
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    visible: drawer.shownApps.length === 0

                                    MaterialSymbol {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "search_off"
                                        iconSize: 36
                                        color: Appearance.colors.colSubtext
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "No Apps Found"
                                        color: Appearance.colors.colOnLayer1
                                        font.family: Appearance.font.family.main
                                        font.pixelSize: 15
                                        font.weight: Font.Medium
                                    }
                                }

                                GridView {
                                    id: appGrid
                                    anchors.fill: parent
                                    topMargin: 2
                                    bottomMargin: 8
                                    clip: true
                                    boundsBehavior: Flickable.DragOverBounds
                                    readonly property int columns: 5
                                    readonly property real iconSize: 52
                                    cellWidth: Math.floor(width / columns)
                                    cellHeight: 102
                                    model: drawer.shownApps

                                    ScrollBar.vertical: ScrollBar {
                                        id: vScroll
                                        policy: ScrollBar.AsNeeded
                                        width: 6
                                        contentItem: Rectangle {
                                            implicitWidth: 4
                                            radius: 2
                                            color: vScroll.pressed ? Appearance.colors.colPrimary : ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.35)
                                            opacity: vScroll.active ? 1.0 : 0.0
                                            Behavior on opacity { NumberAnimation { duration: 180 } }
                                        }
                                        background: Item {}
                                    }

                                    delegate: Item {
                                        id: appCell
                                        required property var modelData
                                        required property int index

                                        readonly property bool isSelected: drawer.keyboardMode && drawer.selectedIndex === index

                                        width: appGrid.cellWidth
                                        height: appGrid.cellHeight

                                        Rectangle {
                                            id: tileBg
                                            anchors {
                                                fill: parent
                                                margins: 4
                                            }
                                            radius: Appearance.rounding.normal
                                            color: appCell.isSelected
                                                ? Appearance.colors.colSecondaryContainer
                                                : (tileMouse.containsMouse ? Appearance.colors.colLayer1Hover : "transparent")
                                            border.width: appCell.isSelected ? 1 : 0
                                            border.color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.45)

                                            Behavior on color { ColorAnimation { duration: 130 } }

                                            Column {
                                                anchors.centerIn: parent
                                                width: parent.width - 10
                                                spacing: 5

                                                // Floating icon & macOS squircle fallback (no per-icon MultiEffect FBO blur)
                                                Item {
                                                    id: iconHolder
                                                    readonly property string iconUrl: drawer.resolveIcon(appCell.modelData)
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                    width: appGrid.iconSize
                                                    height: appGrid.iconSize
                                                    scale: tileMouse.pressed ? 0.88 : (tileMouse.containsMouse || appCell.isSelected ? 1.08 : 1.0)
                                                    opacity: tileMouse.pressed ? 0.78 : 1.0

                                                    Behavior on scale {
                                                        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                                                    }
                                                    Behavior on opacity {
                                                        NumberAnimation { duration: 100 }
                                                    }

                                                    Image {
                                                        anchors.fill: parent
                                                        visible: iconHolder.iconUrl.startsWith("file:")
                                                        asynchronous: true
                                                        smooth: true
                                                        mipmap: true
                                                        fillMode: Image.PreserveAspectFit
                                                        sourceSize.width: appGrid.iconSize * 2
                                                        sourceSize.height: appGrid.iconSize * 2
                                                        source: iconHolder.iconUrl.startsWith("file:") ? iconHolder.iconUrl : ""
                                                    }

                                                    IconImage {
                                                        anchors.fill: parent
                                                        visible: iconHolder.iconUrl !== "" && !iconHolder.iconUrl.startsWith("file:")
                                                        asynchronous: true
                                                        source: iconHolder.iconUrl.startsWith("file:") ? "" : iconHolder.iconUrl
                                                        implicitSize: appGrid.iconSize
                                                    }

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        anchors.margins: 3
                                                        visible: iconHolder.iconUrl === ""
                                                        radius: Math.round(width * 0.24)
                                                        color: Appearance.colors.colPrimaryContainer
                                                        border.width: 1
                                                        border.color: Appearance.colors.colLayer0Border

                                                        MaterialSymbol {
                                                            anchors.centerIn: parent
                                                            text: drawer.fallbackGlyph(appCell.modelData)
                                                            iconSize: Math.round(parent.width * 0.52)
                                                            color: Appearance.colors.colOnPrimaryContainer
                                                        }
                                                    }
                                                }

                                                Text {
                                                    width: parent.width
                                                    height: 32
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignTop
                                                    maximumLineCount: 2
                                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                                    elide: Text.ElideRight
                                                    lineHeight: 1.08
                                                    text: appCell.modelData?.name ?? ""
                                                    color: appCell.isSelected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer0
                                                    font.family: Appearance.font.family.main
                                                    font.pixelSize: 12
                                                    font.weight: Font.Medium
                                                }
                                            }

                                            MouseArea {
                                                id: tileMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: {
                                                    if (drawer.keyboardMode) drawer.keyboardMode = false;
                                                }
                                                onClicked: drawer.launch(appCell.modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
