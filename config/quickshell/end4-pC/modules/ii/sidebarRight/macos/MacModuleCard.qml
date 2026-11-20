import QtQuick
import qs.modules.common
import qs.modules.common.functions

Rectangle {
    id: root

    property bool interactive: false
    property bool hovered: false
    property bool pressed: false
    property bool active: false
    property color activeTint: "transparent"

    readonly property bool dark: Appearance.m3colors.darkmode

    readonly property color idleColor: ColorUtils.applyAlpha(Appearance.colors.colLayer1Base, dark ? 0.72 : 0.78)
    readonly property color hoverColor: ColorUtils.applyAlpha(Appearance.colors.colLayer2Base, dark ? 0.84 : 0.88)
    readonly property color pressColor: ColorUtils.applyAlpha(Appearance.colors.colLayer3Base, dark ? 0.90 : 0.94)

    radius: 16
    color: {
        if (root.active && root.activeTint.a > 0) {
            return root.pressed
                ? ColorUtils.applyAlpha(Appearance.colors.colSecondaryContainerActive, dark ? 0.88 : 0.92)
                : (root.hovered
                    ? ColorUtils.applyAlpha(Appearance.colors.colSecondaryContainerHover, dark ? 0.84 : 0.88)
                    : ColorUtils.applyAlpha(Appearance.colors.colSecondaryContainer, dark ? 0.78 : 0.84));
        }
        if (root.interactive && root.pressed) return pressColor;
        if (root.interactive && root.hovered) return hoverColor;
        return idleColor;
    }

    border.width: 1
    border.color: {
        if (root.active && root.activeTint.a > 0)
            return ColorUtils.applyAlpha(Appearance.colors.colPrimary, dark ? 0.42 : 0.35);
        return ColorUtils.applyAlpha(Appearance.colors.colLayer0Border, dark ? 0.75 : 0.65);
    }

    scale: (root.interactive && root.pressed) ? 0.975 : 1.0

    Behavior on color {
        ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
    Behavior on border.color {
        ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }
}
