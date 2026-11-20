import QtQuick
import QtQuick.Effects
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root

    property real value: 0.5
    property real from: 0.0
    property real to: 1.0
    property string iconName: ""
    property bool iconClickable: false
    property real stepSize: 0.05
    property bool muted: false

    signal moved(real newValue)
    signal iconClicked()

    readonly property bool dark: Appearance.m3colors.darkmode
    readonly property real span: Math.abs(to - from) < 0.0001 ? 1.0 : (to - from)
    readonly property real normalizedExternal: Math.max(0, Math.min(1, (value - from) / span))

    property bool dragging: false
    property real dragNormalized: normalizedExternal
    readonly property real currentNormalized: dragging ? dragNormalized : normalizedExternal

    property real animatedNormalized: currentNormalized
    Behavior on animatedNormalized {
        enabled: !root.dragging
        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }

    implicitHeight: 24
    implicitWidth: 200

    function valueFromX(mouseX) {
        const knobSize = root.height;
        const usable = Math.max(1, root.width - knobSize);
        const norm = Math.max(0, Math.min(1, (mouseX - knobSize / 2) / usable));
        return norm;
    }

    function commitNormalized(norm) {
        const clamped = Math.max(0, Math.min(1, norm));
        dragNormalized = clamped;
        const raw = from + clamped * span;
        root.moved(raw);
    }

    // Track capsule matching Material You palette
    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Appearance.colors.colLayer2Base
        border.width: 1
        border.color: ColorUtils.applyAlpha(Appearance.colors.colLayer0Border, 0.7)

        // Active fill bar in system primary accent
        Rectangle {
            id: fillBar
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: Math.max(height, height + (parent.width - height) * root.animatedNormalized)
            radius: height / 2
            color: root.muted
                ? Appearance.colors.colSecondaryContainer
                : Appearance.colors.colPrimary

            Behavior on color {
                ColorAnimation { duration: 140 }
            }

            // Crisp tactile circular thumb at the right edge of the fill
            Rectangle {
                id: thumb
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: 2
                }
                width: parent.height - 4
                height: parent.height - 4
                radius: width / 2
                color: Appearance.colors.colOnPrimary
                opacity: root.muted ? 0.7 : 0.96
            }
        }

        // Embedded icon on left side of track
        MaterialSymbol {
            id: leftIcon
            visible: root.iconName.length > 0
            anchors {
                left: parent.left
                leftMargin: Math.round((parent.height - 15) / 2)
                verticalCenter: parent.verticalCenter
            }
            text: root.iconName
            iconSize: 15
            fill: 1
            color: root.muted ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        property real pressX: 0
        property bool pressedOnIcon: false
        property bool movedDuringPress: false

        onPressed: mouse => {
            pressX = mouse.x;
            movedDuringPress = false;
            pressedOnIcon = root.iconClickable && mouse.x <= root.height + 2;
            if (!pressedOnIcon) {
                root.dragging = true;
                root.commitNormalized(root.valueFromX(mouse.x));
            }
        }

        onPositionChanged: mouse => {
            if (!pressed) return;
            if (!movedDuringPress && Math.abs(mouse.x - pressX) > 4) {
                movedDuringPress = true;
                root.dragging = true;
            }
            if (root.dragging) {
                root.commitNormalized(root.valueFromX(mouse.x));
            }
        }

        onReleased: mouse => {
            if (pressedOnIcon && !movedDuringPress) {
                root.iconClicked();
            }
            root.dragging = false;
            pressedOnIcon = false;
            movedDuringPress = false;
        }

        onCanceled: {
            root.dragging = false;
            pressedOnIcon = false;
            movedDuringPress = false;
        }

        onWheel: wheel => {
            const dir = wheel.angleDelta.y > 0 ? 1 : (wheel.angleDelta.y < 0 ? -1 : 0);
            if (dir === 0) return;
            const nextNorm = Math.max(0, Math.min(1, root.currentNormalized + dir * root.stepSize));
            root.commitNormalized(nextNorm);
        }
    }
}
