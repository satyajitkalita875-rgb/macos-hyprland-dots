import QtQuick
import qs.modules.common

Item {
    id: root
    property bool checked: false
    property bool enabled: true
    property color accentColor: Appearance.colors.colPrimary
    signal toggled(bool newValue)

    implicitWidth: 38
    implicitHeight: 22
    opacity: enabled ? 1.0 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked
            ? root.accentColor
            : Appearance.colors.colLayer3Base

        Behavior on color {
            ColorAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: knob
            width: parent.height - 4
            height: parent.height - 4
            radius: width / 2
            y: 2
            x: root.checked ? (parent.width - width - 2) : 2
            color: root.checked ? Appearance.colors.colOnPrimary : Appearance.colors.colLayer0Base
            border.width: 0.5
            border.color: Appearance.colors.colLayer0Border

            Behavior on x {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
