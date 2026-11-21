import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models

ContentPage {
    id: page
    property bool isMinimal: Config.options.settings.style === "minimal"
    readonly property bool isMacos: Config.options.settings.style === "macos"
    property string openPopup: ""
    forceWidth: true
    baseWidth: isMacos ? 640 : (!isMinimal ? 700 : 600)
    bottomContentPadding: 28

    component SmallLightDarkPreferenceButton: RippleButton {
        id: smallLightDarkPreferenceButton
        required property bool dark
        property color colText: toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
        padding: 0
        Layout.fillHeight: true
        Layout.preferredWidth: 42
        toggled: Appearance.m3colors.darkmode === dark
        colBackground: toggled
            ? Appearance.colors.colPrimary
            : ColorUtils.applyAlpha(Appearance.colors.colLayer1, 0.65)
        onClicked: {
            Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode ${dark ? "dark" : "light"} --noswitch`]);
        }
        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                iconSize: 20
                fill: toggled ? 1 : 0
                text: smallLightDarkPreferenceButton.dark ? "dark_mode" : "light_mode"
                color: smallLightDarkPreferenceButton.colText
            }
        }
    }

    // Lightweight translucent surface (zero FastBlur / ShaderEffectSource FBO overhead)
    component GlassCard: Rectangle {
        id: glass
        property Item backdrop: null
        property real cardRadius: page.isMacos ? 14 : Appearance.rounding.large
        default property alias content: contentHolder.data

        radius: cardRadius
        color: ColorUtils.applyAlpha(
            Appearance.m3colors.darkmode ? "#1C1C1E" : "#F5F5F7",
            Appearance.m3colors.darkmode ? 0.78 : 0.84
        )
        border.width: 1
        border.color: ColorUtils.applyAlpha(
            Appearance.m3colors.darkmode ? "#FFFFFF" : "#000000",
            Appearance.m3colors.darkmode ? 0.14 : 0.10
        )

        Item {
            id: contentHolder
            anchors.fill: parent
        }
    }

    component GlassPopup: Rectangle {
        id: glassPopup
        property Item backdrop: null
        property real cardRadius: 12
        default property alias content: contentHolder.data

        function syncBackdropRect() {}

        radius: cardRadius
        color: ColorUtils.applyAlpha(
            Appearance.m3colors.darkmode ? "#242426" : "#FFFFFF",
            Appearance.m3colors.darkmode ? 0.94 : 0.96
        )
        border.width: 1
        border.color: ColorUtils.applyAlpha(
            Appearance.m3colors.darkmode ? "#FFFFFF" : "#000000",
            Appearance.m3colors.darkmode ? 0.14 : 0.12
        )

        Item {
            id: contentHolder
            anchors.fill: parent
        }
    }

    component BarScreenPopupButton: RippleButton {
        id: barScreenPopupButton
        property string iconText
        property string popupId
        property var popupHost: null
        property int maxVisibleRows: 8
        property Item backdrop
        property string popupTitle
        property real popupXOffset: 0
        property var options: []
        property var isCurrentValue: value => false
        property var pickValue: value => {}
        readonly property bool popupVisible: popupHost !== null && popupHost.openPopup === popupId
        readonly property bool hoveredAnywhere: buttonHoverHandler.hovered || popupHoverHandler.hovered

        onHoveredAnywhereChanged: {
            if (hoveredAnywhere) {
                popupCloseTimer.stop();
                if (popupHost !== null)
                    popupHost.openPopup = popupId;
            } else {
                popupCloseTimer.restart();
            }
        }

        padding: 0
        Layout.fillHeight: true
        Layout.preferredWidth: 42

        colBackground: ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.08)

        contentItem: Item {
            anchors.fill: parent

            MaterialSymbol {
                anchors.centerIn: parent
                text: barScreenPopupButton.iconText
                iconSize: 20
                color: Appearance.colors.colOnLayer0
            }
        }

        HoverHandler {
            id: buttonHoverHandler
        }

        Timer {
            id: popupCloseTimer
            interval: 180
            onTriggered: {
                if (!barScreenPopupButton.hoveredAnywhere && barScreenPopupButton.popupHost !== null && barScreenPopupButton.popupHost.openPopup === barScreenPopupButton.popupId)
                    barScreenPopupButton.popupHost.openPopup = "";
            }
        }

        Item {
            id: sectionPopup
            x: (barScreenPopupButton.width - width) / 2 + barScreenPopupButton.popupXOffset
            y: -height - 8
            width: 232
            height: popupColumn.implicitHeight + 12
            opacity: barScreenPopupButton.popupVisible ? 1 : 0
            visible: opacity > 0.01
            enabled: barScreenPopupButton.popupVisible

            Behavior on opacity {
                NumberAnimation {
                    duration: 110
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: popupHoverHandler
            }

            GlassPopup {
                id: popupGlass
                anchors.fill: parent
                backdrop: barScreenPopupButton.backdrop

                ColumnLayout {
                    id: popupColumn
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                        text: barScreenPopupButton.popupTitle
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colSubtext
                    }

                    Flickable {
                        id: optionsFlick
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(optionsColumn.implicitHeight, barScreenPopupButton.maxVisibleRows * 28 + (barScreenPopupButton.maxVisibleRows - 1) * 2)
                        contentWidth: width
                        contentHeight: optionsColumn.implicitHeight
                        clip: true
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds

                        TouchpadScrollArea { flickable: optionsFlick }
                        ScrollBar.vertical: StyledScrollBar {}

                        ColumnLayout {
                            id: optionsColumn
                            width: optionsFlick.width
                            spacing: 2

                            Repeater {
                                model: barScreenPopupButton.options

                                delegate: Rectangle {
                                    id: popupOptionRow
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    radius: 8

                                    property bool isSelected: barScreenPopupButton.isCurrentValue(modelData.value)
                                    readonly property bool rowHovered: optionMouseArea.containsMouse

                                    color: isSelected ? Appearance.colors.colPrimary
                                        : rowHovered ? ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.08)
                                        : "transparent"

                                    MouseArea {
                                        id: optionMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            barScreenPopupButton.pickValue(popupOptionRow.modelData.value);
                                            if (barScreenPopupButton.popupHost !== null)
                                                barScreenPopupButton.popupHost.openPopup = "";
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 9
                                        anchors.rightMargin: 9
                                        spacing: 8

                                        MaterialSymbol {
                                            text: popupOptionRow.modelData.icon
                                            iconSize: 16
                                            color: popupOptionRow.isSelected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: popupOptionRow.modelData.displayName
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            color: popupOptionRow.isSelected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
                                        }

                                        MaterialSymbol {
                                            visible: popupOptionRow.isSelected
                                            text: "check"
                                            iconSize: 15
                                            color: Appearance.colors.colOnPrimary
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

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: page.isMacos ? 14 : 10

        ContentSection {
            icon: "screenshot_monitor"
            title: Translation.tr("Wallpaper & Appearance")
            shape: MaterialShape.Shape.Puffy
            Layout.fillWidth: true
            collapsible: false

            Item {
                id: mBox
                Layout.fillWidth: true
                Layout.preferredHeight: page.isMacos ? 250 : (isMinimal ? 320 : 420)
                readonly property real cardRadius: page.isMacos ? 14 : (Appearance.rounding.large - 3)

                ClippingRectangle {
                    anchors.fill: parent
                    radius: mBox.cardRadius
                    color: Appearance.colors.colLayer2

                    Image {
                        id: wallpaperImg
                        anchors.fill: parent
                        asynchronous: true
                        cache: true
                        smooth: true
                        sourceSize.width: 960
                        sourceSize.height: 540
                        fillMode: Image.PreserveAspectCrop
                        source: {
                            const raw = /\.(mp4|webm|mkv|avi|mov)$/i.test(Config.options.background.wallpaperPath)
                                ? Config.options.background.thumbnailPath
                                : Config.options.background.wallpaperPath;
                            if (!raw) return "";
                            return raw.startsWith("file:") ? raw : ("file://" + raw);
                        }
                    }

                    // Subtle bottom vignette for readable overlay controls
                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        height: 82
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.38) }
                        }
                    }
                }

                // Quick wallpaper picker button (top-right pill)
                Rectangle {
                    anchors {
                        top: parent.top
                        right: parent.right
                        margins: 10
                    }
                    width: wpBtnRow.implicitWidth + 16
                    height: 28
                    radius: 14
                    color: wpBtnMouse.containsMouse ? Qt.rgba(0, 0, 0, 0.62) : Qt.rgba(0, 0, 0, 0.45)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.16)

                    RowLayout {
                        id: wpBtnRow
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialSymbol {
                            text: "wallpaper"
                            iconSize: 14
                            color: "#FFFFFF"
                        }

                        StyledText {
                            text: Translation.tr("Change Wallpaper")
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: "#FFFFFF"
                        }
                    }

                    MouseArea {
                        id: wpBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            GlobalStates.settingsOpen = false;
                            GlobalStates.wallpaperSelectorOpen = true;
                        }
                    }
                }

                GlassCard {
                    id: bottomBar
                    backdrop: wallpaperImg
                    height: 54
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        margins: 10
                    }

                    Item {
                        id: barControls
                        anchors.fill: parent
                        anchors.margins: 6

                        RowLayout {
                            id: modeButtonsRow
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            spacing: 5
                            uniformCellSizes: true

                            SmallLightDarkPreferenceButton {
                                dark: false
                            }
                            SmallLightDarkPreferenceButton {
                                dark: true
                            }
                        }

                        RowLayout {
                            id: sectionButtonsRow
                            z: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            spacing: 5

                            BarScreenPopupButton {
                                iconText: "position_bottom_right"
                                popupId: "barPosition"
                                popupHost: page
                                backdrop: wallpaperImg
                                popupTitle: Translation.tr("Bar position")
                                options: [
                                    { displayName: Translation.tr("Top"), icon: "arrow_upward", value: 0 },
                                    { displayName: Translation.tr("Left"), icon: "arrow_back", value: 2 },
                                    { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: 1 },
                                    { displayName: Translation.tr("Right"), icon: "arrow_forward", value: 3 }
                                ]
                                isCurrentValue: value => ((Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)) === value
                                pickValue: value => {
                                    Config.options.bar.bottom = (value & 1) !== 0;
                                    Config.options.bar.vertical = (value & 2) !== 0;
                                }
                            }
                            BarScreenPopupButton {
                                iconText: "settop_component"
                                popupId: "barStyle"
                                popupHost: page
                                backdrop: wallpaperImg
                                popupTitle: Translation.tr("Bar style")
                                options: [
                                    { displayName: Translation.tr("Hug"), icon: "line_curve", value: 0 },
                                    { displayName: Translation.tr("Split Hug"), icon: "splitscreen", value: 6 },
                                    { displayName: Translation.tr("Float"), icon: "view_day", value: 1 },
                                    { displayName: Translation.tr("Islands"), icon: "crop_3_2", value: 2 },
                                    { displayName: Translation.tr("M3"), icon: "interests", value: 3 },
                                    { displayName: Translation.tr("M3 Hug"), icon: "category", value: 4 },
                                    { displayName: Translation.tr("Panel"), icon: "toolbar", value: 5 },
                                    { displayName: Translation.tr("macOS"), icon: "laptop_mac", value: 7 }
                                ]
                                isCurrentValue: value => Config.options.bar.cornerStyle === value
                                pickValue: value => {
                                    Config.options.bar.cornerStyle = value;
                                }
                            }
                            BarScreenPopupButton {
                                visible: Config.options.bar.cornerStyle !== 7
                                iconText: "tab_group"
                                popupId: "groupStyle"
                                popupHost: page
                                backdrop: wallpaperImg
                                popupTitle: Translation.tr("Group style")
                                options: [
                                    { displayName: Translation.tr("None"), icon: "block", value: "transparent" },
                                    { displayName: Translation.tr("Pills"), icon: "pill", value: "pills" },
                                    { displayName: Translation.tr("Separated"), icon: "view_column_2", value: "separated" },
                                    { displayName: Translation.tr("Segmented"), icon: "tablet", value: "segmented" }
                                ]
                                isCurrentValue: value => Config.options.bar.borderless === value
                                pickValue: value => {
                                    Config.options.bar.borderless = value;
                                }
                            }
                            BarScreenPopupButton {
                                iconText: "rounded_corner"
                                popupId: "screenCorner"
                                popupHost: page
                                backdrop: wallpaperImg
                                popupTitle: Translation.tr("Screen round corner")
                                options: [
                                    { displayName: Translation.tr("No"), icon: "close", value: 0 },
                                    { displayName: Translation.tr("Yes"), icon: "check", value: 1 },
                                    { displayName: Translation.tr("When not fullscreen"), icon: "fullscreen_exit", value: 2 }
                                ]
                                isCurrentValue: value => Config.options.appearance.fakeScreenRounding === value
                                pickValue: value => {
                                    Config.options.appearance.fakeScreenRounding = value;
                                }
                            }
                        }

                        RippleButton {
                            id: accentColorButton
                            visible: ColorSchemes.current === ""
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 42
                            height: parent.height
                            padding: 0
                            colBackground: Appearance.colors.colTertiaryContainer
                            colBackgroundHover: Appearance.colors.colTertiaryContainerHover
                            onClicked: {
                                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch", "--color"]);
                            }
                            contentItem: Item {
                                anchors.fill: parent

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "colorize"
                                    iconSize: 20
                                    color: Appearance.colors.colOnLayer1
                                }
                            }
                            StyledToolTip {
                                text: Translation.tr("Change accent color")
                            }
                        }

                        BarScreenPopupButton {
                            id: schemeButton
                            z: 11
                            anchors.right: accentColorButton.visible ? accentColorButton.left : parent.right
                            anchors.rightMargin: accentColorButton.visible ? 5 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: 42
                            height: parent.height
                            iconText: "palette"
                            popupId: "schemes"
                            popupHost: page
                            popupXOffset: (isMinimal ? -30 : -44) - (namedMode ? 68 : 0)
                            backdrop: wallpaperImg
                            popupTitle: Translation.tr("Color scheme")
                            readonly property bool namedMode: ColorSchemes.current !== ""
                            options: namedMode ? [{ displayName: "Material", icon: "auto_awesome", value: "" }].concat(
                                ColorSchemes.schemeOptions().filter(o => o.value !== "").map(o => ({ displayName: o.displayName, icon: "palette", value: o.value }))
                            ) : [
                                { displayName: Translation.tr("Auto"),        icon: "auto_awesome",  value: "auto" },
                                { displayName: Translation.tr("Content"),     icon: "image",         value: "scheme-content" },
                                { displayName: Translation.tr("Expressive"),  icon: "palette",       value: "scheme-expressive" },
                                { displayName: Translation.tr("Fidelity"),    icon: "equal",         value: "scheme-fidelity" },
                                { displayName: Translation.tr("Fruit Salad"), icon: "nutrition",     value: "scheme-fruit-salad" },
                                { displayName: Translation.tr("Mono"),        icon: "invert_colors", value: "scheme-monochrome" },
                                { displayName: Translation.tr("Neutral"),     icon: "tonality",      value: "scheme-neutral" },
                                { displayName: Translation.tr("Rainbow"),     icon: "gradient",      value: "scheme-rainbow" },
                                { displayName: Translation.tr("Tonal Spot"),  icon: "lens",          value: "scheme-tonal-spot" }
                            ]
                            isCurrentValue: value => namedMode ? ColorSchemes.current === value : Config.options.appearance.palette.type === value
                            pickValue: value => {
                                if (namedMode) {
                                    ColorSchemes.setScheme(value);
                                    return;
                                }
                                Config.options.appearance.palette.type = value;
                                Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --noswitch`]);
                            }
                        }
                    }
                }
            }
        }

        ContentSection {
            icon: "tune"
            title: Translation.tr("Quick Toggles")
            shape: MaterialShape.Shape.Clover4Leaf
            collapsible: false

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "blur_on"
                    text: Translation.tr("UI Transparency")
                    checked: Config.options.appearance.transparency.enable
                    onCheckedChanged: { Config.options.appearance.transparency.enable = checked }
                }
                ConfigSwitch {
                    buttonIcon: "layers"
                    text: Translation.tr("Stack notifications in Dynamic Island")
                    checked: Config.options.bar.dynamicIsland.stackNotifications
                    onCheckedChanged: { Config.options.bar.dynamicIsland.stackNotifications = checked }
                }
                ConfigSwitch {
                    buttonIcon: "call_to_action"
                    text: Translation.tr("Show Dock")
                    checked: Config.options.dock.enable
                    onCheckedChanged: { Config.options.dock.enable = checked }
                }
                ConfigSwitch {
                    buttonIcon: "colors"
                    text: Translation.tr("Tint Dock app icons")
                    checked: Config.options.dock.monochromeIcons
                    onCheckedChanged: { Config.options.dock.monochromeIcons = checked }
                }
            }
        }
    }
}
