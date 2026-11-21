import qs.modules.common.widgets
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

RippleButton {
    id: root
    property string buttonIcon
    property alias iconSize: iconWidget.iconSize
    readonly property bool isMacos: Config.options.settings.style === "macos"
    rippleEnabled: !isMacos
    colBackgroundHover: "transparent"

    Layout.fillWidth: true
    Layout.bottomMargin: isMacos ? 0 : 6
    implicitHeight: isMacos ? Math.max(28, contentItem.implicitHeight + 4) : (contentItem.implicitHeight + 8)
    font.pixelSize: isMacos ? 13 : Appearance.font.pixelSize.small

    onClicked: checked = !checked

    contentItem: RowLayout {
        spacing: 10
        OptionalMaterialSymbol {
            id: iconWidget
            icon: root.buttonIcon
            opacity: root.enabled ? (root.isMacos ? 0.78 : 1) : 0.4
            iconSize: root.isMacos ? 18 : Appearance.font.pixelSize.larger
        }
        StyledText {
            id: labelWidget
            Layout.fillWidth: true
            text: root.text
            font: root.font
            color: root.isMacos ? Appearance.colors.colOnLayer0 : Appearance.colors.colOnSecondaryContainer
            opacity: root.enabled ? 1 : 0.4
        }
        Loader {
            id: materialSwitchLoader
            active: !root.isMacos
            visible: active
            Layout.fillWidth: false
            sourceComponent: StyledSwitch {
                down: root.down
                checked: root.checked
                onClicked: root.clicked()
            }
        }
        // Authentic macOS pill toggle switch (pure Rectangles, zero FBO/MultiEffect overhead)
        Loader {
            id: macSwitchLoader
            active: root.isMacos
            visible: active
            Layout.fillWidth: false
            sourceComponent: Item {
                implicitWidth: 38
                implicitHeight: 22
                opacity: root.enabled ? 1.0 : 0.4

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.checked
                        ? Appearance.colors.colPrimary
                        : ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, Appearance.m3colors.darkmode ? 0.22 : 0.16)

                    Behavior on color { ColorAnimation { duration: 130; easing.type: Easing.OutCubic } }

                    Rectangle {
                        width: parent.height - 4
                        height: parent.height - 4
                        radius: width / 2
                        y: 2
                        x: root.checked ? (parent.width - width - 2) : 2
                        color: "#FFFFFF"
                        border.width: 0.5
                        border.color: Qt.rgba(0, 0, 0, 0.14)

                        Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }
}
