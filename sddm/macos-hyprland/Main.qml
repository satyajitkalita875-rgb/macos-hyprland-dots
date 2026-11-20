import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#12161e"

    property string fontName: (config && config.fontFamily && config.fontFamily.length > 0)
        ? config.fontFamily.split(",")[0].trim()
        : "Sans"
    property int selectedUserIndex: (userModel && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
    property int selectedSessionIndex: (sessionModel && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    property string currentUserName: (userModel && userModel.lastUser) ? userModel.lastUser : ""
    property string currentRealName: ""
    property string statusMessage: ""
    property bool loginFailed: false
    property bool loggingIn: false
    property bool sessionMenuOpen: false
    property date currentTime: new Date()

    function submitLogin() {
        if (loggingIn) return
        var user = currentUserName.trim()
        if (user.length === 0 && manualUserInput.text.trim().length > 0)
            user = manualUserInput.text.trim()
        if (user.length === 0) {
            statusMessage = "Enter a username"
            loginFailed = true
            return
        }
        loggingIn = true
        loginFailed = false
        statusMessage = "Logging in..."
        sddm.login(user, passwordInput.text, selectedSessionIndex)
    }

    function selectNextUser(delta) {
        if (!userModel || userModel.count <= 1) return
        selectedUserIndex = (selectedUserIndex + delta + userModel.count) % userModel.count
        userHelperView.currentIndex = selectedUserIndex
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.currentTime = new Date()
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.loggingIn = false
            root.loginFailed = true
            root.statusMessage = "Wrong password"
            passwordInput.text = ""
            passwordInput.forceActiveFocus()
            shakeAnim.restart()
        }
        function onLoginSucceeded() {
            root.loggingIn = false
            root.loginFailed = false
            root.statusMessage = ""
        }
        function onInformationMessage(message) {
            if (message && message.length > 0)
                root.statusMessage = message
        }
    }

    // Hidden helper ListView to reliably read SDDM userModel roles
    ListView {
        id: userHelperView
        visible: false
        width: 1
        height: 1
        model: userModel
        currentIndex: root.selectedUserIndex
        delegate: Item {
            property string uName: model.name || ""
            property string uReal: model.realName || ""
        }
        onCurrentItemChanged: {
            if (currentItem) {
                root.currentUserName = currentItem.uName
                root.currentRealName = currentItem.uReal
            }
        }
        Component.onCompleted: {
            if (currentItem) {
                root.currentUserName = currentItem.uName
                root.currentRealName = currentItem.uReal
            }
        }
    }

    // Hidden helper ListView to reliably read SDDM sessionModel names
    ListView {
        id: sessionHelperView
        visible: false
        width: 1
        height: 1
        model: sessionModel
        currentIndex: root.selectedSessionIndex
        delegate: Item {
            property string sName: model.name || ""
        }
    }

    // Wallpaper background
    Image {
        id: wallpaper
        anchors.fill: parent
        source: (config && config.background && config.background.length > 0) ? config.background : "background.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        smooth: true
        visible: false
    }

    MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        blurEnabled: true
        blur: (config && config.blurRadius !== undefined) ? Number(config.blurRadius) : 0.45
        blurMax: 32
        brightness: -0.06
        saturation: 0.08
    }

    // Subtle dark gradient veil matching hyprlock contrast
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.07, 0.09, 0.12, 0.28) }
            GradientStop { position: 0.5; color: Qt.rgba(0.07, 0.09, 0.12, 0.16) }
            GradientStop { position: 1.0; color: Qt.rgba(0.07, 0.09, 0.12, 0.36) }
        }
    }

    // Dismiss session popup on outside click
    MouseArea {
        anchors.fill: parent
        enabled: root.sessionMenuOpen
        onClicked: root.sessionMenuOpen = false
    }

    // Top-right bar: Caps Lock indicator + Session selector pill
    RowLayout {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.rightMargin: 26
        spacing: 10
        z: 10

        Rectangle {
            visible: keyboard && keyboard.capsLock
            implicitWidth: capsLabel.implicitWidth + 20
            implicitHeight: 30
            radius: 15
            color: Qt.rgba(1.0, 0.76, 0.31, 0.26)
            border.width: 1
            border.color: Qt.rgba(1.0, 0.80, 0.38, 0.65)

            Text {
                id: capsLabel
                anchors.centerIn: parent
                text: "CAPS LOCK"
                color: "#fff7e0"
                font.family: root.fontName
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }

        // Session Selector Pill
        Rectangle {
            id: sessionPill
            visible: sessionModel && sessionModel.count > 0
            implicitWidth: sessionRow.implicitWidth + 24
            implicitHeight: 32
            radius: 16
            color: sessionPillMouse.containsMouse || root.sessionMenuOpen
                ? Qt.rgba(1, 1, 1, 0.28)
                : Qt.rgba(1, 1, 1, 0.18)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.38)

            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: sessionRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: (sessionHelperView.currentItem && sessionHelperView.currentItem.sName)
                        ? sessionHelperView.currentItem.sName
                        : "Session"
                    color: Qt.rgba(1, 1, 1, 0.94)
                    font.family: root.fontName
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                Text {
                    text: root.sessionMenuOpen ? "▴" : "▾"
                    color: Qt.rgba(1, 1, 1, 0.82)
                    font.pixelSize: 11
                }
            }

            MouseArea {
                id: sessionPillMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sessionMenuOpen = !root.sessionMenuOpen
            }
        }
    }

    // Frosted glass Session dropdown menu
    Rectangle {
        id: sessionDropdown
        visible: root.sessionMenuOpen
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 58
        anchors.rightMargin: 26
        width: 240
        height: Math.min(sessionList.contentHeight + 12, 280)
        radius: 14
        color: Qt.rgba(0.11, 0.13, 0.18, 0.78)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.28)
        clip: true
        z: 20

        ListView {
            id: sessionList
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2
            model: sessionModel
            delegate: Rectangle {
                width: sessionList.width
                height: 34
                radius: 9
                color: index === root.selectedSessionIndex
                    ? Qt.rgba(1, 1, 1, 0.24)
                    : (itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: model.name || ""
                        color: "#ffffff"
                        font.family: root.fontName
                        font.pixelSize: 13
                        font.weight: index === root.selectedSessionIndex ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: index === root.selectedSessionIndex
                        text: "✓"
                        color: "#8cc8ff"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selectedSessionIndex = index
                        sessionHelperView.currentIndex = index
                        root.sessionMenuOpen = false
                        passwordInput.forceActiveFocus()
                    }
                }
            }
        }
    }

    // Top-center macOS Date + Giant Clock (matching hyprlock.conf)
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(70, parent.height * 0.10)
        spacing: 2

        Text {
            id: dateText
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(root.currentTime, (config && config.dateFormat) ? config.dateFormat : "dddd, MMMM d")
            color: Qt.rgba(1, 1, 1, 0.92)
            font.family: root.fontName
            font.pixelSize: 24
            font.weight: Font.Medium
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.35)
                shadowBlur: 0.35
                shadowVerticalOffset: 2
            }
        }

        Text {
            id: clockText
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(root.currentTime, (config && config.clockFormat) ? config.clockFormat : "HH:mm")
            color: Qt.rgba(1, 1, 1, 0.96)
            font.family: root.fontName
            font.pixelSize: 112
            font.weight: Font.Bold
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.36)
                shadowBlur: 0.45
                shadowVerticalOffset: 3
            }
        }
    }

    // Bottom-center macOS User Badge + Pill Password Input (matching hyprlock.conf)
    ColumnLayout {
        id: loginColumn
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 56
        spacing: 10

        // User circle badge + switcher arrows (if > 1 user)
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 14

            Rectangle {
                visible: userModel && userModel.count > 1
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: prevUserMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.14)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.35)
                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: "#ffffff"
                    font.pixelSize: 18
                }
                MouseArea {
                    id: prevUserMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectNextUser(-1)
                }
            }

            Rectangle {
                Layout.preferredWidth: 66
                Layout.preferredHeight: 66
                radius: 33
                color: Qt.rgba(1, 1, 1, 0.22)
                border.width: 2
                border.color: Qt.rgba(1, 1, 1, 0.55)

                Text {
                    anchors.centerIn: parent
                    text: {
                        var n = root.currentUserName || manualUserInput.text || "U"
                        return n.length > 0 ? n.charAt(0).toUpperCase() : "U"
                    }
                    color: Qt.rgba(1, 1, 1, 0.96)
                    font.family: root.fontName
                    font.pixelSize: 28
                    font.weight: Font.Bold
                }
            }

            Rectangle {
                visible: userModel && userModel.count > 1
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: nextUserMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.14)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.35)
                Text {
                    anchors.centerIn: parent
                    text: "›"
                    color: "#ffffff"
                    font.pixelSize: 18
                }
                MouseArea {
                    id: nextUserMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectNextUser(1)
                }
            }
        }

        // Username label (or editable fallback if userModel is empty)
        Text {
            visible: root.currentUserName.length > 0
            Layout.alignment: Qt.AlignHCenter
            text: root.currentRealName.length > 0 ? root.currentRealName : root.currentUserName
            color: Qt.rgba(1, 1, 1, 0.95)
            font.family: root.fontName
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        Rectangle {
            visible: root.currentUserName.length === 0
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 248
            Layout.preferredHeight: 38
            radius: 19
            color: Qt.rgba(1, 1, 1, 0.20)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.45)

            TextInput {
                id: manualUserInput
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                color: "#ffffff"
                font.family: root.fontName
                font.pixelSize: 14
                clip: true
                KeyNavigation.tab: passwordInput
                onAccepted: passwordInput.forceActiveFocus()
            }

            Text {
                anchors.centerIn: parent
                visible: manualUserInput.text.length === 0
                text: "Username"
                color: Qt.rgba(1, 1, 1, 0.65)
                font.family: root.fontName
                font.pixelSize: 14
            }
        }

        // Frosted glass pill password input
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 256
            Layout.preferredHeight: 42

            Rectangle {
                id: passwordPill
                width: parent.width
                height: parent.height
                x: 0
                radius: 21
                color: Qt.rgba(1, 1, 1, 0.22)
                border.width: 1.5
                border.color: root.loginFailed
                    ? Qt.rgba(1.0, 0.35, 0.37, 0.92)
                    : (root.loggingIn
                        ? Qt.rgba(0.39, 0.71, 1.0, 0.90)
                        : Qt.rgba(1, 1, 1, 0.48))

                Behavior on border.color { ColorAnimation { duration: 180 } }

                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: passwordPill; property: "x"; to: -10; duration: 45 }
                    NumberAnimation { target: passwordPill; property: "x"; to: 10; duration: 45 }
                    NumberAnimation { target: passwordPill; property: "x"; to: -7; duration: 45 }
                    NumberAnimation { target: passwordPill; property: "x"; to: 7; duration: 45 }
                    NumberAnimation { target: passwordPill; property: "x"; to: 0; duration: 45 }
                }

                TextInput {
                    id: passwordInput
                    anchors.left: parent.left
                    anchors.right: submitBtn.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 38
                    anchors.rightMargin: 6
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: Qt.rgba(1, 1, 1, 0.96)
                    selectionColor: Qt.rgba(0.39, 0.71, 1.0, 0.45)
                    font.family: root.fontName
                    font.pixelSize: 14
                    focus: true
                    clip: true

                    onTextChanged: {
                        if (root.loginFailed && text.length > 0) {
                            root.loginFailed = false
                            root.statusMessage = ""
                        }
                    }
                    onAccepted: root.submitLogin()
                }

                Text {
                    anchors.centerIn: parent
                    visible: passwordInput.text.length === 0
                    text: "Enter Password"
                    color: Qt.rgba(1, 1, 1, 0.76)
                    font.family: root.fontName
                    font.pixelSize: 14
                }

                // Inline macOS circular arrow submit button
                Rectangle {
                    id: submitBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 6
                    width: 30
                    height: 30
                    radius: 15
                    visible: passwordInput.text.length > 0 || root.loggingIn
                    color: submitMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.36) : Qt.rgba(1, 1, 1, 0.22)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.45)

                    Text {
                        anchors.centerIn: parent
                        text: root.loggingIn ? "⋯" : "→"
                        color: "#ffffff"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: submitMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submitLogin()
                    }
                }
            }
        }

        // Bottom hint / error message
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.statusMessage.length > 0 ? root.statusMessage : "Enter Password to Unlock"
            color: root.loginFailed ? "#ff8a8e" : Qt.rgba(1, 1, 1, 0.74)
            font.family: root.fontName
            font.pixelSize: 12
            font.italic: root.loginFailed
        }
    }

    // Bottom-right macOS Power Controls (Sleep, Restart, Shut Down)
    RowLayout {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 28
        anchors.bottomMargin: 24
        spacing: 14

        // Sleep
        ColumnLayout {
            visible: sddm && sddm.canSuspend
            spacing: 4
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: sleepMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.16)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.36)
                Behavior on color { ColorAnimation { duration: 140 } }
                Text {
                    anchors.centerIn: parent
                    text: "☾"
                    color: "#ffffff"
                    font.pixelSize: 15
                }
                MouseArea {
                    id: sleepMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sddm.suspend()
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Sleep"
                color: Qt.rgba(1, 1, 1, 0.78)
                font.family: root.fontName
                font.pixelSize: 11
            }
        }

        // Restart
        ColumnLayout {
            visible: sddm && sddm.canReboot
            spacing: 4
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: rebootMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.16)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.36)
                Behavior on color { ColorAnimation { duration: 140 } }
                Text {
                    anchors.centerIn: parent
                    text: "↻"
                    color: "#ffffff"
                    font.pixelSize: 16
                }
                MouseArea {
                    id: rebootMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sddm.reboot()
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Restart"
                color: Qt.rgba(1, 1, 1, 0.78)
                font.family: root.fontName
                font.pixelSize: 11
            }
        }

        // Shut Down
        ColumnLayout {
            visible: sddm && sddm.canPowerOff
            spacing: 4
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: powerMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.16)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.36)
                Behavior on color { ColorAnimation { duration: 140 } }
                Text {
                    anchors.centerIn: parent
                    text: "⏻"
                    color: "#ffffff"
                    font.pixelSize: 15
                }
                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sddm.powerOff()
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Shut Down"
                color: Qt.rgba(1, 1, 1, 0.78)
                font.family: root.fontName
                font.pixelSize: 11
            }
        }
    }

    Component.onCompleted: {
        if (root.currentUserName.length > 0)
            passwordInput.forceActiveFocus()
        else
            manualUserInput.forceActiveFocus()
    }
}
