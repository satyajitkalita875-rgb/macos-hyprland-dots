import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    property var today: new Date()

    readonly property bool dark: Appearance.m3colors.darkmode
    readonly property color cardFill: Appearance.colors.colLayer1
    readonly property color cardBorder: ColorUtils.applyAlpha(Appearance.colors.colLayer0Border, dark ? 0.72 : 0.62)

    ColumnLayout {
        spacing: 10
        implicitWidth: 348
        width: 348

        // Month + Year + Live Day Header
        RowLayout {
            Layout.preferredWidth: 348
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 6

            Row {
                spacing: 6
                StyledText {
                    text: Qt.locale().toString(root.today, "MMMM")
                    font.pixelSize: 19
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnLayer0
                }
                StyledText {
                    text: Qt.locale().toString(root.today, "yyyy")
                    font.pixelSize: 19
                    font.weight: Font.Normal
                    color: Appearance.colors.colSubtext
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: dayBadgeText.implicitWidth + 14
                implicitHeight: 22
                radius: 11
                color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, root.dark ? 0.22 : 0.14)
                border.width: 1
                border.color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.30)

                StyledText {
                    id: dayBadgeText
                    anchors.centerIn: parent
                    text: Qt.locale().toString(root.today, "dddd")
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colPrimary
                }
            }
        }

        // 7-Day Week Strip matching macOS frosted glass tiles
        RowLayout {
            Layout.preferredWidth: 348
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                model: 7
                delegate: Rectangle {
                    required property int index

                    readonly property var date: {
                        const today = root.today
                        const dow = today.getDay()
                        const d = new Date(today)
                        d.setDate(today.getDate() - dow + index)
                        return d
                    }
                    readonly property bool isToday: {
                        const t = root.today
                        return date.getDate()     === t.getDate() &&
                               date.getMonth()    === t.getMonth() &&
                               date.getFullYear() === t.getFullYear()
                    }

                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    radius: 14
                    color: isToday
                        ? Appearance.colors.colPrimary
                        : root.cardFill
                    border.width: 1
                    border.color: isToday
                        ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.8)
                        : root.cardBorder

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.locale().toString(date, "ddd").slice(0, 2)
                            font.pixelSize: 11
                            color: isToday
                                ? ColorUtils.applyAlpha(Appearance.colors.colOnPrimary, 0.85)
                                : Appearance.colors.colSubtext
                            font.weight: isToday ? Font.DemiBold : Font.Medium
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: date.getDate()
                            font.pixelSize: isToday ? 15 : 13
                            font.weight: isToday ? Font.Bold : Font.Medium
                            font.features: ({ "tnum": 1 })
                            color: isToday
                                ? Appearance.colors.colOnPrimary
                                : Appearance.colors.colOnLayer0
                        }
                    }
                }
            }
        }

        // Tasks Glass Module Card
        Rectangle {
            Layout.preferredWidth: 348
            Layout.fillWidth: true
            implicitHeight: tasksRow.implicitHeight + 16
            radius: 16
            color: root.cardFill
            border.width: 1
            border.color: root.cardBorder

            RowLayout {
                id: tasksRow
                anchors {
                    fill: parent
                    margins: 8
                }
                spacing: 10

                // Left task counter badge
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 12
                        color: ColorUtils.applyAlpha(Appearance.colors.colPrimary, root.dark ? 0.24 : 0.14)

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "checklist"
                            iconSize: 18
                            color: Appearance.colors.colPrimary
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: `${Todo.list.filter(t => !t.done).length}`
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        font.features: ({ "tnum": 1 })
                        color: Appearance.colors.colPrimary
                    }
                }

                // Right task items or empty state
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        id: todoRepeater
                        model: Math.min(3, Todo.list.filter(t => !t.done).length)

                        delegate: Rectangle {
                            required property int index
                            readonly property var filteredList: Todo.list.filter(t => !t.done)
                            readonly property var todo: filteredList[filteredList.length - 1 - index]

                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: 9
                            color: Appearance.colors.colLayer2

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 10
                                    rightMargin: 10
                                }
                                spacing: 7

                                Rectangle {
                                    Layout.preferredWidth: 5
                                    Layout.preferredHeight: 5
                                    radius: 2.5
                                    color: Appearance.colors.colPrimary
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: todo.content
                                    font.pixelSize: 12
                                    color: Appearance.colors.colOnLayer0
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        visible: Todo.list.filter(t => !t.done).length === 0

                        StyledText {
                            anchors.centerIn: parent
                            text: Translation.tr("No pending tasks")
                            font.pixelSize: 12
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }

        // Subtle Uptime Footer
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 2
            spacing: 6

            MaterialSymbol {
                text: "timelapse"
                iconSize: 13
                color: Appearance.colors.colSubtext
            }

            StyledText {
                text: `${Translation.tr("System Uptime")}  •  ${DateTime.uptime}`
                font.pixelSize: 11
                color: Appearance.colors.colSubtext
            }
        }
    }
}
