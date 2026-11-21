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

    Layout.preferredWidth: 88
    Layout.preferredHeight: 100
    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    implicitWidth: 88
    implicitHeight: 100

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

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        // Minimal floating circular icon button
        Rectangle {
            id: circleBtn
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 68
            Layout.preferredHeight: 68
            radius: 34
            color: {
                if (button.pressed)
                    return ColorUtils.applyAlpha(button.accentColor, 0.92);
                if (button.highlighted)
                    return button.accentColor;
                return Qt.rgba(1, 1, 1, 0.14);
            }
            border.width: button.highlighted ? 0 : 1
            border.color: Qt.rgba(1, 1, 1, 0.22)

            scale: button.pressed ? 0.94 : (button.highlighted ? 1.08 : 1.0)

            Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

            MaterialSymbol {
                anchors.centerIn: parent
                text: button.buttonIcon
                iconSize: 28
                fill: button.highlighted ? 1 : 0
                color: "#FFFFFF"
                opacity: button.highlighted ? 1.0 : 0.92
            }
        }

        // Clean label below circle
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            text: button.buttonText
            font.pixelSize: 13
            font.weight: button.highlighted ? Font.DemiBold : Font.Medium
            color: "#FFFFFF"
            opacity: button.highlighted ? 1.0 : 0.78

            Behavior on opacity { NumberAnimation { duration: 130 } }
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
