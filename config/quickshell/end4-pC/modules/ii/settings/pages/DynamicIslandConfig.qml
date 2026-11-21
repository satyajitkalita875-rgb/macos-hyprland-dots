import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true

    readonly property bool isMacosBar: Config.options.bar.cornerStyle === 7

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        ContentSection {
            icon: "layers"
            shape: MaterialShape.Shape.Cookie7Sided
            title: Translation.tr("Layout & Appearance")

            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Card stack style")
                    icon: "view_agenda"
                    currentValue: Config.options.bar.dynamicIsland.stackStyle
                    onSelected: newValue => { Config.options.bar.dynamicIsland.stackStyle = newValue }
                    options: [
                        { displayName: Translation.tr("Fluid Cloud"), icon: "layers", value: "fluid" },
                        { displayName: Translation.tr("Unified"), icon: "crop_square", value: "unified" }
                    ]
                }
                ConfigSpinBox {
                    icon: "width"
                    text: Translation.tr("Expanded width (px)")
                    value: Config.options.bar.dynamicIsland.expandedWidth
                    from: 320
                    to: 460
                    stepSize: 8
                    onValueChanged: { Config.options.bar.dynamicIsland.expandedWidth = value }
                }
                ConfigSpinBox {
                    icon: "rounded_corner"
                    text: Translation.tr("Card corner radius (px)")
                    value: Config.options.bar.dynamicIsland.cardRadius
                    from: 12
                    to: 30
                    stepSize: 1
                    onValueChanged: { Config.options.bar.dynamicIsland.cardRadius = value }
                }
                ConfigSpinBox {
                    enabled: Config.options.bar.dynamicIsland.stackStyle === "fluid"
                    icon: "space_bar"
                    text: Translation.tr("Gap between stacked cards (px)")
                    value: Config.options.bar.dynamicIsland.cardSpacing
                    from: 2
                    to: 16
                    stepSize: 1
                    onValueChanged: { Config.options.bar.dynamicIsland.cardSpacing = value }
                }
            }
        }

        ContentSection {
            icon: "animation"
            shape: MaterialShape.Shape.SoftBurst
            title: Translation.tr("Animation & Interaction")

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "mouse"
                    text: Translation.tr("Expand on hover (off = click to toggle)")
                    checked: Config.options.bar.dynamicIsland.expandOnHover
                    onCheckedChanged: { Config.options.bar.dynamicIsland.expandOnHover = checked }
                }
                ConfigSwitch {
                    buttonIcon: "waves"
                    text: Translation.tr("Spring bounce cascade")
                    checked: Config.options.bar.dynamicIsland.springBounce
                    onCheckedChanged: { Config.options.bar.dynamicIsland.springBounce = checked }
                }
                ConfigSelectionArray {
                    text: Translation.tr("Animation speed")
                    icon: "speed"
                    currentValue: Config.options.bar.dynamicIsland.animationSpeed
                    onSelected: newValue => { Config.options.bar.dynamicIsland.animationSpeed = newValue }
                    options: [
                        { displayName: Translation.tr("Fast"), icon: "bolt", value: 0.7 },
                        { displayName: Translation.tr("Normal"), icon: "play_arrow", value: 1.0 },
                        { displayName: Translation.tr("Relaxed"), icon: "slow_motion_video", value: 1.35 }
                    ]
                }
            }
        }

        ContentSection {
            icon: "screen_record"
            shape: MaterialShape.Shape.Clover4Leaf
            title: Translation.tr("Screen Recorder Card")

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "videocam"
                    text: Translation.tr("Show live recording card in stack")
                    checked: Config.options.bar.dynamicIsland.showRecordingCard
                    onCheckedChanged: { Config.options.bar.dynamicIsland.showRecordingCard = checked }
                }
                ConfigSwitch {
                    buttonIcon: "stop_circle"
                    text: Translation.tr("Show quick Stop button on compact pill")
                    checked: Config.options.bar.dynamicIsland.showCompactRecStop
                    onCheckedChanged: { Config.options.bar.dynamicIsland.showCompactRecStop = checked }
                }
            }
        }

        ContentSection {
            icon: "music_note"
            shape: MaterialShape.Shape.Sunny
            title: Translation.tr("Now Playing Media Card")

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "album"
                    text: Translation.tr("Show media card when playing")
                    checked: Config.options.bar.dynamicIsland.showMusicCard
                    onCheckedChanged: { Config.options.bar.dynamicIsland.showMusicCard = checked }
                }
                ConfigSwitch {
                    enabled: Config.options.bar.dynamicIsland.showMusicCard
                    buttonIcon: "linear_scale"
                    text: Translation.tr("Show interactive progress scrubber")
                    checked: Config.options.bar.dynamicIsland.showMusicScrubber
                    onCheckedChanged: { Config.options.bar.dynamicIsland.showMusicScrubber = checked }
                }
                ConfigSwitch {
                    enabled: Config.options.bar.dynamicIsland.showMusicCard
                    buttonIcon: "graphic_eq"
                    text: Translation.tr("Show animated equalizer")
                    checked: Config.options.bar.dynamicIsland.showMusicEqualizer
                    onCheckedChanged: { Config.options.bar.dynamicIsland.showMusicEqualizer = checked }
                }
            }
        }

        ContentSection {
            icon: "notifications"
            shape: MaterialShape.Shape.Pentagon
            title: Translation.tr("Notifications Stack")

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "layers"
                    text: Translation.tr("Stack all app notifications in Dynamic Island")
                    checked: Config.options.bar.dynamicIsland.stackNotifications
                    onCheckedChanged: { Config.options.bar.dynamicIsland.stackNotifications = checked }
                }
            }
        }

        ContentSection {
            icon: "calendar_month"
            shape: MaterialShape.Shape.Puffy
            title: Translation.tr("Calendar & Status Card")

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "date_range"
                    text: Translation.tr("Show calendar card")
                    checked: Config.options.bar.dynamicIsland.showCalendarCard
                    onCheckedChanged: { Config.options.bar.dynamicIsland.showCalendarCard = checked }
                }
                ConfigSwitch {
                    enabled: Config.options.bar.dynamicIsland.showCalendarCard
                    buttonIcon: "checklist"
                    text: Translation.tr("Show pending tasks")
                    checked: Config.options.bar.dynamicIsland.showTasksInCalendar
                    onCheckedChanged: { Config.options.bar.dynamicIsland.showTasksInCalendar = checked }
                }
                ConfigSwitch {
                    enabled: Config.options.bar.dynamicIsland.showCalendarCard
                    buttonIcon: "timelapse"
                    text: Translation.tr("Show system uptime footer")
                    checked: Config.options.bar.dynamicIsland.showUptimeFooter
                    onCheckedChanged: { Config.options.bar.dynamicIsland.showUptimeFooter = checked }
                }
            }
        }

        ContentSection {
            icon: "nest_wifi_pro"
            shape: MaterialShape.Shape.Diamond
            title: Translation.tr("Classic Bar Dynamic Island")
            visible: !page.isMacosBar

            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Visualizer style")
                    icon: "graphic_eq"
                    currentValue: Config.options.bar.dynamicIsland.visualizerStyle
                    onSelected: newValue => { Config.options.bar.dynamicIsland.visualizerStyle = newValue }
                    options: [
                        { displayName: Translation.tr("None"), icon: "block", value: "none" },
                        { displayName: Translation.tr("Dots"), icon: "steppers", value: "dots" },
                        { displayName: Translation.tr("Wave"), icon: "ssid_chart", value: "wave" }
                    ]
                }
                ConfigSwitch {
                    buttonIcon: "play_circle"
                    text: Translation.tr("Show media controls")
                    checked: Config.options.bar.dynamicIsland.showMediaControls
                    onCheckedChanged: { Config.options.bar.dynamicIsland.showMediaControls = checked }
                }
            }
        }
    }
}
