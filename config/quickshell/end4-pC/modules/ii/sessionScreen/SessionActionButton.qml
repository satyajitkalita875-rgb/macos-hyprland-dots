import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

Item {
    id: button

    property string buttonIcon: ""
    property string buttonText: ""
    property color accentColor: Appearance.colors.colPrimary
    property bool isDestructive: false
    property bool keyboardDown: false

    readonly property bool dark: Appearance.m3colors.darkmode
    readonly property bool hovered: tileMouse.containsMouse
    readonly property bool pressed: tileMouse.pressed || keyboardDown
    readonly property bool highlighted: hovered || activeFocus

    signal clicked()

    Layout.preferredWidth: 122
    Layout.preferredHeight: 102
    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    implicitWidth: 122
    implicitHeight: 102

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            keyboardDown = true;
            button.clicked();
            event.accepted = true;
        }
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            keyboardDown = false;
            event.accepted = true;
        }
    }

    Rectangle {
        id: tileBg
        anchors.fill: parent
        radius: 18
        color: {
            if (button.pressed)
                return ColorUtils.applyAlpha(button.accentColor, button.dark ? 0.28 : 0.20);
            if (button.highlighted)
                return ColorUtils.applyAlpha(button.accentColor, button.dark ? 0.18 : 0.13);
            return Appearance.colors.colLayer1;
        }
        border.width: button.highlighted ? 1.5 : 1
        border.color: button.highlighted
            ? ColorUtils.applyAlpha(button.accentColor, button.dark ? 0.68 : 0.55)
            : ColorUtils.applyAlpha(Appearance.colors.colLayer0Border, button.dark ? 0.7 : 0.6)

        scale: button.pressed ? 0.96 : (button.highlighted ? 1.03 : 1.0)

        Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 14
            spacing: 9

            // Circular Icon Badge
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46
                radius: 23
                color: button.highlighted
                    ? button.accentColor
                    : ColorUtils.applyAlpha(button.accentColor, button.dark ? 0.22 : 0.14)

                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: button.buttonIcon
                    iconSize: 23
                    fill: button.highlighted ? 1 : 0
                    color: button.highlighted ? "#ffffff" : button.accentColor

                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            // Clear Action Label inside the tile
            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: button.buttonText
                font.pixelSize: 12
                font.weight: button.highlighted ? Font.DemiBold : Font.Medium
                color: button.highlighted && button.isDestructive
                    ? button.accentColor
                    : Appearance.colors.colOnLayer0
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }

    MouseArea {
        id: tileMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: button.forceActiveFocus()
        onClicked: button.clicked()
    }
}
