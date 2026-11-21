import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    default property list<Item> items
    readonly property bool isMacos: Config.options.settings.style === "macos"
    property real bigRadius: isMacos ? 10 : Appearance.rounding.normal
    property real smallRadius: isMacos ? 0 : Appearance.rounding.unsharpenmore
    property color bgcolor: isMacos
        ? ColorUtils.applyAlpha(Appearance.colors.colLayer1, Appearance.m3colors.darkmode ? 0.78 : 0.88)
        : Appearance.colors.colLayer1
    property real itemVerticalPadding: isMacos ? 14 : 24
    property bool glass: false
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight

    // macOS unified outer border overlay
    Rectangle {
        visible: root.isMacos
        anchors.fill: parent
        radius: root.bigRadius
        color: "transparent"
        border.width: 1
        border.color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, Appearance.m3colors.darkmode ? 0.10 : 0.08)
        z: 5
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: root.isMacos ? 0 : 2

        Repeater {
            model: root.items.length
            delegate: Rectangle {
                required property int index
                readonly property bool isFirst: index === 0
                readonly property bool isLast: index === root.items.length - 1
                Layout.fillWidth: true
                implicitHeight: (root.items[index]?.implicitHeight ?? 0) + root.itemVerticalPadding
                color: root.bgcolor

                Loader {
                    anchors.fill: parent
                    active: (root?.glass ?? false) && (Config.options?.background?.widgets?.glass?.enable ?? false)
                    sourceComponent: WindowGlass {
                        glassEnabled: true
                        topLeftRadius: parent.parent.topLeftRadius
                        topRightRadius: parent.parent.topRightRadius
                        bottomLeftRadius: parent.parent.bottomLeftRadius
                        bottomRightRadius: parent.parent.bottomRightRadius
                        tint: root?.bgcolor ?? "transparent"
                    }
                }
                topLeftRadius:     isFirst ? root.bigRadius : root.smallRadius
                topRightRadius:    isFirst ? root.bigRadius : root.smallRadius
                bottomLeftRadius:  isLast  ? root.bigRadius : root.smallRadius
                bottomRightRadius: isLast  ? root.bigRadius : root.smallRadius

                // macOS inset horizontal separator between rows
                Rectangle {
                    visible: root.isMacos && !parent.isFirst
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        leftMargin: 14
                        rightMargin: 14
                    }
                    height: 1
                    color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer0, 0.08)
                    z: 3
                }

                Component.onCompleted: {
                    const child = root.items[index]
                    if (child) {
                        child.parent = contentArea
                        child.Layout.fillWidth = true
                    }
                }

                ColumnLayout {
                    id: contentArea
                    anchors {
                        fill: parent
                        leftMargin: root.isMacos ? 10 : 8
                        rightMargin: root.isMacos ? 10 : 8
                        topMargin: root.isMacos ? 5 : 8
                        bottomMargin: root.isMacos ? 5 : 8
                    }
                    spacing: 0
                }
            }
        }
    }
}
