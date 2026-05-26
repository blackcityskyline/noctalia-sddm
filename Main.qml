import QtQuick 2.15
import QtQuick.Controls 2.15 as Controls
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import Qt5Compat.GraphicalEffects 1.0
import "."

import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width || 1366
    height: Screen.height || 768

    // --- Scale & layout ---
    readonly property real scaleFactor: {
        var s = Math.min(width / 1366, height / 768)
        return Math.max(0.75, Math.min(s, 2.0))
    }
    readonly property real baseUnit: 8 * scaleFactor

    // --- Color palette (Material You tokens) ---
    readonly property color mPrimary:          config.mPrimary          || "#c7a1d8"
    readonly property color mOnPrimary:        config.mOnPrimary        || "#1a151f"
    readonly property color mSurface:          config.mSurface          || "#1c1822"
    readonly property color mSurfaceVariant:   config.mSurfaceVariant   || "#262130"
    readonly property color mOnSurface:        config.mOnSurface        || "#e9e4f0"
    readonly property color mOnSurfaceVariant: config.mOnSurfaceVariant || "#a79ab0"
    readonly property color mTertiary:         config.mTertiary         || "#d8c68d"
    readonly property color mOnTertiary:       config.mOnTertiary       || "#3a3005"
    readonly property color mError:            config.mError            || "#e9899d"
    readonly property color mOnError:          config.mOnError          || "#690005"
    readonly property color mOutline:          config.mOutline          || "#342c42"

    // --- Radii: outer for cards/popups, inner for buttons/fields ---
    readonly property real radiusOuter: 16 * scaleFactor
    readonly property real radiusInner:  8 * scaleFactor
    readonly property real radiusL: radiusOuter

    // --- Typography ---
    readonly property real fontSizeM:     11 * scaleFactor
    readonly property real fontSizeL:     13 * scaleFactor
    readonly property real fontSizeXL:    16 * scaleFactor
    readonly property real fontSizeXXL:   18 * scaleFactor
    readonly property real fontSizeClock: 42 * scaleFactor

    // --- Config ---
    readonly property string backgroundPath:  config.background    || "Assets/background.png"
    readonly property real   blurRadius:      parseFloat(config.blurRadius)      || 0
    readonly property real   focusBlurRadius: parseFloat(config.focusBlurRadius) || 32
    readonly property string keyboardLayout:  config.keyboardLayout || Qt.locale().name.substring(0, 2).toUpperCase()

    property bool   debugBattery: true
    property string selectedUser: ""
    property bool   capsLockOn:   false
    property string loginState:   "idle"   // idle | trying | success | error

    FontLoader {
        id: nerdFont
        source: "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"
    }

    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    color: root.mSurface

    Component.onCompleted: {
        if (userModel.lastUser !== "")
            selectedUser = userModel.lastUser
        else if (userModel.count > 0)
            selectedUser = userModel.get(0).name
    }

    // --- Login callbacks ---
    NumberAnimation {
        id: fadeOut
        target: root
        property: "opacity"
        to: 0
        duration: 600
        easing.type: Easing.OutCubic
    }

    Connections {
        target: sddm
        function onLoginSucceeded() {
            root.loginState = "success"
            fadeOut.start()
        }
        function onLoginFailed() {
            passwordBox.text = ""
            errorMessage.text = "Authentication failed"
            errorTimer.restart()
            root.loginState = "error"
            shakeAnimation.start()
            errorStateTimer.restart()
        }
    }

    Timer {
        id: errorStateTimer
        interval: 700
        onTriggered: root.loginState = "idle"
    }

    // --- Background ---
    Image {
        id: wallpaper
        anchors.fill: parent
        source: root.backgroundPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        clip: true
    }

    FastBlur {
        id: staticBlur
        anchors.fill: parent
        source: wallpaper
        radius: root.blurRadius
        transparentBorder: false
        visible: root.blurRadius > 0
        cached: true
    }

    FastBlur {
        id: focusBlur
        anchors.fill: parent
        source: wallpaper
        radius: 0
        transparentBorder: false
        cached: false
        visible: radius > 0
        Behavior on radius {
            NumberAnimation { duration: 350; easing.type: Easing.InOutQuad }
        }
    }

    Connections {
        target: passwordBox
        function onTextChanged() {
            if (root.focusBlurRadius > 0)
                focusBlur.radius = passwordBox.text.length > 0 ? root.focusBlurRadius : 0
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.6) }
            GradientStop { position: 0.4; color: Qt.rgba(0, 0, 0, 0.2) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.7) }
        }
    }

    // =========================================================
    // User switcher popup
    // =========================================================
    Controls.Popup {
        id: userPopup
        x: headerCard.x + headerCard.width / 2 - width / 2
        y: headerCard.y + headerCard.height + 10 * scaleFactor
        width: Math.min(300 * scaleFactor, root.width * 0.5)

        readonly property real rowHeight:    56 * scaleFactor
        readonly property real popupPadding:  6 * scaleFactor
        readonly property int  visibleRows:  Math.min(Math.max(userModel.count, 1), 6)
        height: visibleRows * rowHeight + popupPadding * 2

        padding: 0
        modal: true
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside

        background: Rectangle {
            color: root.mSurface
            border.color: Qt.rgba(root.mOutline.r, root.mOutline.g, root.mOutline.b, 0.2)
            border.width: 1 * scaleFactor
            radius: root.radiusL
        }

        ListView {
            id: userList
            anchors.fill: parent
            anchors.margins: userPopup.popupPadding
            model: userModel
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: {
                for (var i = 0; i < userModel.count; i++) {
                    if (userModel.get(i).name === root.selectedUser) return i
                }
                return -1
            }

            delegate: Controls.ItemDelegate {
                id: userDelegate
                width: parent.width
                height: userPopup.rowHeight

                // ListView.isCurrentItem is set synchronously on delegate creation,
                // unlike a plain binding to root.selectedUser — so highlight is correct on open.
                readonly property bool isSelected: ListView.isCurrentItem
                highlighted: false  // disable built-in highlight to avoid conflicts with custom background

                readonly property real avatarSize: userPopup.rowHeight - 12 * scaleFactor

                onClicked: {
                    userList.currentIndex = index
                    root.selectedUser = model.name
                    userPopup.close()
                }

                background: Rectangle {
                    color:        parent.isSelected ? Qt.rgba(root.mPrimary.r, root.mPrimary.g, root.mPrimary.b, 0.18) : "transparent"
                    border.color: parent.isSelected ? Qt.rgba(root.mPrimary.r, root.mPrimary.g, root.mPrimary.b, 0.5)  : "transparent"
                    border.width: parent.isSelected ? 1 * scaleFactor : 0
                    radius: root.radiusOuter - userPopup.popupPadding
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6 * scaleFactor
                    spacing: 10 * scaleFactor

                    Item {
                        Layout.preferredWidth: userDelegate.avatarSize
                        Layout.preferredHeight: userDelegate.avatarSize

                        Rectangle {
                            id: delegateMask
                            anchors.fill: parent
                            radius: width / 2
                            visible: false
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: root.mSurfaceVariant
                        }

                        Image {
                            id: delegateAvatar
                            anchors.fill: parent
                            property int tryIndex: 0
                            property var iconPaths: {
                                var paths = []
                                var u = model.name
                                if (u) {
                                    if (config.avatarPath && config.avatarPath !== "")
                                        paths.push("file://" + config.avatarPath)
                                    if (model.icon && model.icon !== "") {
                                        var p = model.icon
                                        if (p.indexOf("://") === -1 && p.charAt(0) === "/")
                                            p = "file://" + p
                                        paths.push(p)
                                    }
                                    paths.push("file:///var/lib/AccountsService/icons/" + u)
                                    if (model.homeDir) {
                                        paths.push("file://" + model.homeDir + "/.face.icon")
                                        paths.push("file://" + model.homeDir + "/.face")
                                    }
                                    paths.push("file:///usr/share/sddm/faces/" + u + ".face.icon")
                                }
                                paths.push("file:///usr/share/sddm/faces/.face.icon")
                                return paths
                            }
                            source: iconPaths.length > 0 ? iconPaths[Math.min(tryIndex, iconPaths.length - 1)] : ""
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            layer.enabled: true
                            layer.effect: OpacityMask { maskSource: delegateMask }
                            onStatusChanged: {
                                if (status === Image.Error && tryIndex < iconPaths.length - 1)
                                    tryIndex++
                            }
                        }

                        Image {
                            anchors.fill: parent
                            anchors.margins: 6 * scaleFactor
                            source: "Assets/logo.svg"
                            fillMode: Image.PreserveAspectFit
                            visible: delegateAvatar.status !== Image.Ready && delegateAvatar.status !== Image.Loading
                            layer.enabled: true
                            layer.effect: OpacityMask { maskSource: delegateMask }
                        }
                    }

                    Text {
                        text: model.realName || model.name
                        color: root.mOnSurface
                        font.pixelSize: root.fontSizeL
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    // =========================================================
    // Header card: avatar, greeting, date, clock, battery
    // =========================================================
    Rectangle {
        id: headerCard
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.12 + 20 * scaleFactor
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(400 * scaleFactor, Math.min(parent.width * 0.70, 550 * scaleFactor))
        height: 120 * scaleFactor
        radius: root.radiusL
        color: root.mSurface
        border.color: Qt.rgba(root.mOutline.r, root.mOutline.g, root.mOutline.b, 0.2)
        border.width: 1 * scaleFactor
        opacity: 0

        Component.onCompleted: fadeInHeader.start()

        ParallelAnimation {
            id: fadeInHeader
            NumberAnimation { target: headerCard; property: "opacity";              to: 1;                    duration: 1000; easing.type: Easing.OutCubic }
            NumberAnimation { target: headerCard; property: "anchors.topMargin";    to: root.height * 0.12;   duration: 1000; easing.type: Easing.OutCubic }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16 * scaleFactor
            spacing: 32 * scaleFactor

            // --- Avatar ---
            Item {
                id: avatarContainer
                Layout.preferredWidth: 70 * scaleFactor
                Layout.preferredHeight: 70 * scaleFactor
                Layout.alignment: Qt.AlignVCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: userPopup.open()
                }

                SequentialAnimation {
                    running: true
                    loops: Animation.Infinite
                    NumberAnimation { target: avatarContainer; property: "scale"; from: 1.0;  to: 1.06; duration: 1800; easing.type: Easing.InOutSine }
                    NumberAnimation { target: avatarContainer; property: "scale"; from: 1.06; to: 1.0;  duration: 1800; easing.type: Easing.InOutSine }
                }

                Rectangle {
                    id: avatarBorder
                    anchors.centerIn: parent
                    width:  parent.width  + 4 * scaleFactor
                    height: parent.height + 4 * scaleFactor
                    radius: width / 2
                    color: "transparent"
                    border.width: 2 * scaleFactor
                    property color animColor: "#c7a1d8"
                    border.color: animColor

                    SequentialAnimation {
                        running: true
                        loops: Animation.Infinite
                        ColorAnimation { target: avatarBorder; property: "animColor"; from: "#c7a1d8"; to: "#ff6eb4"; duration: 2000; easing.type: Easing.InOutSine }
                        ColorAnimation { target: avatarBorder; property: "animColor"; from: "#ff6eb4"; to: "#6eb4ff"; duration: 2000; easing.type: Easing.InOutSine }
                        ColorAnimation { target: avatarBorder; property: "animColor"; from: "#6eb4ff"; to: "#ffe066"; duration: 2000; easing.type: Easing.InOutSine }
                        ColorAnimation { target: avatarBorder; property: "animColor"; from: "#ffe066"; to: "#c7a1d8"; duration: 2000; easing.type: Easing.InOutSine }
                    }
                }

                Item {
                    id: avatarRect
                    anchors.centerIn: parent
                    width:  70 * scaleFactor
                    height: 70 * scaleFactor

                    property int    tryIndex:       0
                    property string primaryUser:    userModel.lastUser
                    property string currentIcon:    ""
                    property string currentHome:    ""
                    property string currentRealName: ""
                    property string firstUserName:  ""
                    property string displayUser:    root.selectedUser !== "" ? root.selectedUser : (primaryUser !== "" ? primaryUser : firstUserName)
                    property string displayName:    currentRealName !== "" ? currentRealName : (displayUser !== "" ? displayUser : "User")

                    onDisplayUserChanged: tryIndex = 0

                    Repeater {
                        model: userModel
                        delegate: Item {
                            visible: false
                            Binding { target: avatarRect; property: "firstUserName";    value: model.name;     when: index === 0 }
                            Binding { target: avatarRect; property: "currentIcon";      value: model.icon;     when: model.name === avatarRect.displayUser }
                            Binding { target: avatarRect; property: "currentHome";      value: model.homeDir;  when: model.name === avatarRect.displayUser }
                            Binding { target: avatarRect; property: "currentRealName";  value: model.realName; when: model.name === avatarRect.displayUser }
                        }
                    }

                    property var iconPaths: {
                        var paths = []
                        var u = displayUser
                        if (u) {
                            if (config.avatarPath && config.avatarPath !== "")
                                paths.push("file://" + config.avatarPath)
                            if (currentIcon && currentIcon !== "") {
                                var p = currentIcon
                                if (p.indexOf("://") === -1 && p.charAt(0) === "/")
                                    p = "file://" + p
                                paths.push(p)
                            }
                            paths.push("file:///var/lib/AccountsService/icons/" + u)
                            if (currentHome) {
                                paths.push("file://" + currentHome + "/.face.icon")
                                paths.push("file://" + currentHome + "/.face")
                            }
                            paths.push("file:///usr/share/sddm/faces/" + u + ".face.icon")
                        }
                        paths.push("file:///usr/share/sddm/faces/.face.icon")
                        return paths
                    }

                    Rectangle {
                        id: avatarMask
                        anchors.fill: parent
                        radius: width / 2
                        visible: false
                    }

                    Image {
                        id: userAvatar
                        anchors.fill: parent
                        source: parent.iconPaths.length > 0 ? parent.iconPaths[Math.min(parent.tryIndex, parent.iconPaths.length - 1)] : ""
                        sourceSize: Qt.size(70 * scaleFactor, 70 * scaleFactor)
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        visible: status === Image.Ready
                        asynchronous: true
                        layer.enabled: true
                        layer.effect: OpacityMask { maskSource: avatarMask }
                        onStatusChanged: {
                            if (status === Image.Error && parent.tryIndex < parent.iconPaths.length - 1)
                                parent.tryIndex++
                        }
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: 8 * scaleFactor
                        source: "Assets/logo.svg"
                        sourceSize: Qt.size(70 * scaleFactor, 70 * scaleFactor)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: userAvatar.status !== Image.Ready && userAvatar.status !== Image.Loading
                        layer.enabled: true
                        layer.effect: OpacityMask { maskSource: avatarMask }
                    }
                }
            }

            // --- Greeting & date ---
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 2 * scaleFactor

                TapHandler {
                    cursorShape: Qt.PointingHandCursor
                    onTapped: userPopup.open()
                }

                Text {
                    text: "Welcome back, " + avatarRect.displayName + "!"
                    font.pixelSize: root.fontSizeXXL
                    font.bold: true
                    color: root.mOnSurface
                }
                Text {
                    id: dateText
                    text: Qt.formatDate(new Date(), "dddd, MMMM d")
                    font.pixelSize: root.fontSizeXL
                    color: root.mOnSurfaceVariant
                    Timer {
                        interval: 60000
                        running: true
                        repeat: true
                        onTriggered: dateText.text = Qt.formatDate(new Date(), "dddd, MMMM d")
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // --- Clock & battery ---
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 4 * scaleFactor

                Text {
                    id: clockText
                    text: Qt.formatTime(new Date(), "hh:mm")
                    font.pixelSize: root.fontSizeClock
                    font.bold: true
                    color: root.mOnSurface
                    Layout.alignment: Qt.AlignHCenter
                    Timer {
                        interval: 1000
                        running: true
                        repeat: true
                        onTriggered: clockText.text = Qt.formatTime(new Date(), "hh:mm")
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6 * scaleFactor

                    Text {
                        font.pixelSize: root.fontSizeL
                        font.family: nerdFont.status === FontLoader.Ready ? nerdFont.name : ""
                        color: batteryReader.color
                        text: {
                            if (nerdFont.status !== FontLoader.Ready)
                                return batteryReader.percent < 0 ? "N/A" : (batteryReader.charging ? "CHG" : "BAT")
                            if (batteryReader.charging) {
                                if (batteryReader.percent >= 95) return "󰂅"
                                if (batteryReader.percent >= 90) return "󰂋"
                                if (batteryReader.percent >= 80) return "󰂊"
                                if (batteryReader.percent >= 70) return "󰂉"
                                if (batteryReader.percent >= 60) return "󰢝"
                                if (batteryReader.percent >= 50) return "󰢝"
                                if (batteryReader.percent >= 40) return "󰂈"
                                if (batteryReader.percent >= 30) return "󰂇"
                                if (batteryReader.percent >= 20) return "󰂆"
                                if (batteryReader.percent >= 10) return "󰢜"
                                return "󰢟"
                            }
                            if (batteryReader.percent >= 95) return "󰁹"
                            if (batteryReader.percent >= 90) return "󰂂"
                            if (batteryReader.percent >= 80) return "󰂁"
                            if (batteryReader.percent >= 70) return "󰂀"
                            if (batteryReader.percent >= 60) return "󰁿"
                            if (batteryReader.percent >= 50) return "󰁾"
                            if (batteryReader.percent >= 40) return "󰁽"
                            if (batteryReader.percent >= 30) return "󰁼"
                            if (batteryReader.percent >= 20) return "󰁻"
                            if (batteryReader.percent >= 10) return "󰁺"
                            if (batteryReader.percent >= 1)  return "󱃍"
                            return "󱉞"
                        }
                    }

                    Text {
                        text: batteryReader.percent >= 0 ? batteryReader.percent + "%" : "No battery"
                        font.pixelSize: root.fontSizeM
                        color: batteryReader.color
                    }

                    QtObject {
                        id: batteryReader
                        property int   percent:  -1
                        property bool  charging: false
                        property color color: {
                            if (percent < 0)   return root.mOnSurfaceVariant
                            if (percent <= 20) return root.mError
                            if (percent <= 50) return "#ffe066"
                            if (percent <= 75) return "#ffffff"
                            return "#4caf50"
                        }

                        function readXhr(path, callback) {
                            var xhr = new XMLHttpRequest()
                            xhr.open("GET", path, true)
                            xhr.onreadystatechange = function() {
                                if (xhr.readyState === XMLHttpRequest.DONE)
                                    callback(xhr.responseText.trim())
                            }
                            xhr.send()
                        }

                        function update() {
                            if (debugBattery) {
                                readXhr(Qt.resolvedUrl("debug_battery.json"), function(v) {
                                    try {
                                        var d = JSON.parse(v)
                                        percent  = d.percent  !== undefined ? d.percent  : -1
                                        charging = d.charging || false
                                    } catch(e) {
                                        percent = -1; charging = false
                                    }
                                })
                            } else {
                                readXhr("file:///sys/class/power_supply/BAT0/capacity", function(v) {
                                    if (v !== "") { percent = parseInt(v); return }
                                    readXhr("file:///sys/class/power_supply/BAT1/capacity", function(v2) {
                                        if (v2 !== "") percent = parseInt(v2)
                                    })
                                })
                                readXhr("file:///sys/class/power_supply/BAT0/status", function(v) {
                                    if (v !== "") { charging = (v === "Charging"); return }
                                    readXhr("file:///sys/class/power_supply/BAT1/status", function(v2) {
                                        charging = (v2 === "Charging")
                                    })
                                })
                            }
                        }

                        Component.onCompleted: update()
                    }

                    Timer { interval: 5000; running: true; repeat: true; onTriggered: batteryReader.update() }
                }
            }
        }
    }

    // =========================================================
    // Bottom card: password field & system controls
    // =========================================================
    Rectangle {
        id: bottomCard
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(750 * scaleFactor, parent.width * 0.9)
        height: 140 * scaleFactor
        radius: root.radiusL
        color: root.mSurface
        border.color: Qt.rgba(root.mOutline.r, root.mOutline.g, root.mOutline.b, 0.2)
        border.width: 1 * scaleFactor
        opacity: 0

        property real activeBottomMargin: passwordBox.text.length > 0 ? 88 * scaleFactor : 100 * scaleFactor
        anchors.bottomMargin: activeBottomMargin
        Behavior on activeBottomMargin {
            NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
        }

        Component.onCompleted: fadeInBottom.start()

        NumberAnimation {
            id: fadeInBottom
            target: bottomCard
            property: "opacity"
            from: 0; to: 1
            duration: 1000
            easing.type: Easing.OutCubic
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20 * scaleFactor
            spacing: 15 * scaleFactor

            // --- Password row ---
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 50 * scaleFactor
                spacing: 15 * scaleFactor

                Rectangle {
                    id: passwordFieldRect
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.mSurfaceVariant
                    radius: root.radiusInner
                    clip: true
                    border.width: 2 * scaleFactor
                    border.color: passwordBox.text.length > 0 ? root.mPrimary : "transparent"
                    Behavior on border.color { ColorAnimation { duration: 200 } }

                    // Visual password characters
                    Row {
                        id: symbolsWrapper
                        spacing: 14
                        anchors.left: parent.left
                        anchors.leftMargin: 15 * scaleFactor
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: passwordBox.text.length
                            delegate: Item {
                                width: 20
                                height: 20
                                property int shapeType: index % 8

                                Canvas {
                                    id: shapeCanvas
                                    anchors.centerIn: parent
                                    width: 26
                                    height: 26
                                    property color currentColor: root.mOnSurface
                                    onCurrentColorChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.reset()
                                        ctx.fillStyle = shapeCanvas.currentColor
                                        var cx = width / 2, cy = height / 2
                                        var sz = width * 0.9
                                        ctx.beginPath()
                                        if (shapeType === 0) {
                                            ctx.arc(cx, cy, sz / 2, 0, Math.PI * 2)
                                        } else if (shapeType === 1) {
                                            var h = sz * 1.1 / 2
                                            ctx.moveTo(cx, cy - h); ctx.lineTo(cx + h, cy)
                                            ctx.lineTo(cx, cy + h); ctx.lineTo(cx - h, cy)
                                            ctx.closePath()
                                        } else if (shapeType === 2) {
                                            var tS = sz * 1.15, tH = (Math.sqrt(3) / 2) * tS, tO = tH / 6
                                            ctx.moveTo(cx, cy - tH / 2 - tO)
                                            ctx.lineTo(cx + tS / 2, cy + tH / 2 - tO)
                                            ctx.lineTo(cx - tS / 2, cy + tH / 2 - tO)
                                            ctx.closePath()
                                        } else if (shapeType === 3) {
                                            var sqS = sz * 0.85, off = sqS / 2, r = sqS * 0.4
                                            ctx.moveTo(cx-off+r, cy-off); ctx.lineTo(cx+off-r, cy-off)
                                            ctx.quadraticCurveTo(cx+off, cy-off, cx+off, cy-off+r)
                                            ctx.lineTo(cx+off, cy+off-r)
                                            ctx.quadraticCurveTo(cx+off, cy+off, cx+off-r, cy+off)
                                            ctx.lineTo(cx-off+r, cy+off)
                                            ctx.quadraticCurveTo(cx-off, cy+off, cx-off, cy+off-r)
                                            ctx.lineTo(cx-off, cy-off+r)
                                            ctx.quadraticCurveTo(cx-off, cy-off, cx-off+r, cy-off)
                                            ctx.closePath()
                                        } else if (shapeType === 4) {
                                            var oR = sz*0.75, iR = sz*0.32, spikes = 5
                                            var step = Math.PI / spikes, rot = Math.PI / 2 * 3
                                            ctx.moveTo(cx, cy - oR)
                                            for (var i = 0; i < spikes; i++) {
                                                ctx.lineTo(cx + Math.cos(rot)*oR, cy + Math.sin(rot)*oR); rot += step
                                                ctx.lineTo(cx + Math.cos(rot)*iR, cy + Math.sin(rot)*iR); rot += step
                                            }
                                            ctx.lineTo(cx, cy - oR); ctx.closePath()
                                        } else if (shapeType === 5) {
                                            var pR = sz*0.55, pA = (Math.PI*2)/5, sA = -Math.PI/2
                                            ctx.moveTo(cx + pR*Math.cos(sA), cy + pR*Math.sin(sA))
                                            for (var i = 1; i <= 5; i++)
                                                ctx.lineTo(cx + pR*Math.cos(sA + i*pA), cy + pR*Math.sin(sA + i*pA))
                                            ctx.closePath()
                                        } else if (shapeType === 6) {
                                            var hR = sz*0.5, hA = (Math.PI*2)/6, hS = -Math.PI/2
                                            ctx.moveTo(cx + hR*Math.cos(hS), cy + hR*Math.sin(hS))
                                            for (var i = 1; i <= 6; i++)
                                                ctx.lineTo(cx + hR*Math.cos(hS + i*hA), cy + hR*Math.sin(hS + i*hA))
                                            ctx.closePath()
                                        } else {
                                            var fR = sz*0.5, petals = 8, fStep = (Math.PI*2) / petals
                                            for (var i = 0; i < petals; i++) {
                                                var t1 = i*fStep, t2 = (i+1)*fStep, cpT = (t1+t2)/2, cpR = fR*1.25
                                                var sx = cx + fR*Math.cos(t1), sy = cy + fR*Math.sin(t1)
                                                var ex = cx + fR*Math.cos(t2), ey = cy + fR*Math.sin(t2)
                                                var cpx = cx + cpR*Math.cos(cpT), cpy = cy + cpR*Math.sin(cpT)
                                                if (i === 0) ctx.moveTo(sx, sy)
                                                ctx.quadraticCurveTo(cpx, cpy, ex, ey)
                                            }
                                            ctx.closePath()
                                        }
                                        ctx.fill()
                                    }
                                }
                            }
                        }
                    }

                    // Keyboard layout & Caps Lock indicators
                    Column {
                        anchors.right: parent.right
                        anchors.rightMargin: 12 * scaleFactor
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2 * scaleFactor

                        Text {
                            text: root.keyboardLayout
                            font.pixelSize: root.fontSizeM
                            color: root.mOnSurfaceVariant
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            visible: root.capsLockOn
                            text: "⇪ Caps"
                            font.pixelSize: root.fontSizeM
                            color: root.mError
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    // Hidden input — captures keystrokes, NoEcho for security
                    TextInput {
                        id: passwordBox
                        anchors.fill: parent
                        anchors.margins: 15 * scaleFactor
                        verticalAlignment: Text.AlignVCenter
                        echoMode: TextInput.NoEcho
                        visible: false
                        font.pixelSize: 14 * scaleFactor
                        focus: true
                        KeyNavigation.tab: loginButton
                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_CapsLock) {
                                root.capsLockOn = !root.capsLockOn
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (root.loginState === "idle" || root.loginState === "error") {
                                    root.loginState = "trying"
                                    loginTimer.start()
                                }
                                event.accepted = true
                            }
                        }
                    }

                    Text {
                        anchors.fill: parent
                        anchors.margins: 15 * scaleFactor
                        verticalAlignment: Text.AlignVCenter
                        text: "Password..."
                        color: Qt.rgba(root.mOnSurfaceVariant.r, root.mOnSurfaceVariant.g, root.mOnSurfaceVariant.b, 0.5)
                        font.pixelSize: 14 * scaleFactor
                        visible: !passwordBox.text && !passwordBox.activeFocus
                    }
                }

                Controls.Button {
                    id: loginButton
                    Layout.preferredWidth: 110 * scaleFactor
                    Layout.fillHeight: true
                    KeyNavigation.tab: sessionList
                    onClicked: {
                        if (root.loginState === "idle" || root.loginState === "error") {
                            root.loginState = "trying"
                            loginTimer.start()
                        }
                    }

                    Timer {
                        id: loginTimer
                        interval: 50
                        onTriggered: sddm.login(
                            root.selectedUser !== "" ? root.selectedUser : userModel.lastUser,
                            passwordBox.text, sessionList.currentIndex)
                    }

                    // Resolved button colors based on loginState
                    readonly property color btnBg: {
                        if (root.loginState === "error")   return root.mError
                        if (root.loginState === "success") return root.mTertiary
                        return root.mPrimary
                    }
                    readonly property color btnFg: {
                        if (root.loginState === "error")   return root.mOnError
                        if (root.loginState === "success") return root.mOnTertiary
                        return root.mOnPrimary
                    }

                    background: Rectangle {
                        radius: root.radiusInner
                        color: loginButton.down
                               ? Qt.darker(loginButton.btnBg, 1.2)
                               : loginButton.btnBg
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    contentItem: Item {
                        Row {
                        anchors.centerIn: parent
                        spacing: 5 * scaleFactor

                        Text {
                            id: lockIcon
                            font.family: nerdFont.status === FontLoader.Ready ? nerdFont.name : ""
                            font.pixelSize: 14 * scaleFactor
                            color: loginButton.btnFg
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 200 } }

                            text: {
                                if (nerdFont.status !== FontLoader.Ready) return ""
                                if (root.loginState === "success") return "󰍁"
                                if (root.loginState === "trying")  return "󰁪"
                                return "󰌾"
                            }

                            SequentialAnimation {
                                running: root.loginState === "trying"
                                loops: Animation.Infinite
                                NumberAnimation { target: lockIcon; property: "opacity"; to: 0.4; duration: 300; easing.type: Easing.InOutSine }
                                NumberAnimation { target: lockIcon; property: "opacity"; to: 1.0; duration: 300; easing.type: Easing.InOutSine }
                            }
                            Connections {
                                target: root
                                function onLoginStateChanged() {
                                    if (root.loginState !== "trying") lockIcon.opacity = 1.0
                                }
                            }
                        }

                        Text {
                            text: root.loginState === "trying" ? "Logging in" : "Login"
                            font.pixelSize: 14 * scaleFactor
                            font.bold: true
                            color: loginButton.btnFg
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                        } // Row
                    }     // Item (contentItem)
                }         // Controls.Button
            }

            // --- Session & power controls ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 15 * scaleFactor

                Controls.ComboBox {
                    id: sessionList
                    model: sessionModel
                    textRole: "name"
                    currentIndex: sessionModel.lastIndex
                    Layout.preferredWidth: 200 * scaleFactor
                    Layout.preferredHeight: 36 * scaleFactor
                    KeyNavigation.tab: suspendButton

                    delegate: Controls.ItemDelegate {
                        width: parent.width
                        text: model.name || ""
                        highlighted: sessionList.highlightedIndex === index
                        hoverEnabled: true
                        contentItem: Text {
                            text: parent.text
                            color: root.mOnSurface
                            font.pixelSize: root.fontSizeM
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.highlighted || parent.hovered
                                   ? Qt.lighter(root.mSurfaceVariant, 1.4)
                                   : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                    hoverEnabled: true
                    background: Rectangle {
                        color: sessionList.pressed
                               ? Qt.darker(root.mSurfaceVariant, 1.3)
                               : sessionList.hovered
                                 ? Qt.lighter(root.mSurfaceVariant, 1.4)
                                 : root.mSurfaceVariant
                        radius: root.radiusInner
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    contentItem: Text {
                        leftPadding: 10 * scaleFactor
                        text: sessionList.displayText || ""
                        color: root.mOnSurface
                        font.pixelSize: root.fontSizeM
                        verticalAlignment: Text.AlignVCenter
                    }
                    popup: Controls.Popup {
                        y: sessionList.height - 1
                        width: sessionList.width
                        implicitHeight: contentItem.implicitHeight
                        padding: 1 * scaleFactor
                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: sessionList.popup.visible ? sessionList.delegateModel : null
                            currentIndex: sessionList.highlightedIndex
                            Controls.ScrollIndicator.vertical: Controls.ScrollIndicator { }
                        }
                        background: Rectangle {
                            color: root.mSurface
                            border.color: root.mOutline
                            radius: root.radiusInner
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                component PowerButton: Controls.Button {
                    Layout.preferredHeight: 36 * scaleFactor
                    Layout.preferredWidth: loginButton.width
                    hoverEnabled: true
                    background: Rectangle {
                        color: parent.down
                               ? Qt.darker(root.mSurfaceVariant, 1.3)
                               : parent.hovered
                                 ? Qt.lighter(root.mSurfaceVariant, 1.4)
                                 : root.mSurfaceVariant
                        radius: root.radiusInner
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: root.fontSizeM
                        color: root.mOnSurface
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                PowerButton { id: suspendButton;  text: "Suspend";  KeyNavigation.tab: rebootButton;   onClicked: sddm.suspend()  }
                PowerButton { id: rebootButton;   text: "Reboot";   KeyNavigation.tab: shutdownButton;  onClicked: sddm.reboot()   }
                PowerButton { id: shutdownButton; text: "Shutdown"; KeyNavigation.tab: passwordBox;     onClicked: sddm.powerOff() }
            }
        }
    }

    // =========================================================
    // Error toast
    // =========================================================
    Rectangle {
        id: errorRect
        width: errorMessage.implicitWidth + 40 * scaleFactor
        height: 50 * scaleFactor
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: bottomCard.top
        anchors.bottomMargin: 20 * scaleFactor
        radius: root.radiusL
        color: root.mError
        visible: false
        opacity: 0

        states: [
            State { name: "visible"; when: errorMessage.text !== ""; PropertyChanges { target: errorRect; opacity: 1; visible: true  } },
            State { name: "hidden";  when: errorMessage.text === ""; PropertyChanges { target: errorRect; opacity: 0; visible: false } }
        ]
        transitions: [
            Transition { from: "hidden";  to: "visible"; NumberAnimation { properties: "opacity"; duration: 300 } },
            Transition { from: "visible"; to: "hidden";  NumberAnimation { properties: "opacity"; duration: 300 } }
        ]

        Text {
            id: errorMessage
            anchors.centerIn: parent
            text: ""
            color: "#1e1418"
            font.pixelSize: root.fontSizeM
            font.bold: true
        }
    }

    Timer {
        id: errorTimer
        interval: 4000
        onTriggered: errorMessage.text = ""
    }

    // =========================================================
    // Shake animation on failed login
    // =========================================================
    SequentialAnimation {
        id: shakeAnimation
        property string tgt: "anchors.horizontalCenterOffset"
        PropertyAnimation { target: bottomCard; property: "anchors.horizontalCenterOffset"; to: -18; duration: 50 }
        PropertyAnimation { target: bottomCard; property: "anchors.horizontalCenterOffset"; to:  18; duration: 50 }
        PropertyAnimation { target: bottomCard; property: "anchors.horizontalCenterOffset"; to: -12; duration: 50 }
        PropertyAnimation { target: bottomCard; property: "anchors.horizontalCenterOffset"; to:  12; duration: 50 }
        PropertyAnimation { target: bottomCard; property: "anchors.horizontalCenterOffset"; to:  -6; duration: 50 }
        PropertyAnimation { target: bottomCard; property: "anchors.horizontalCenterOffset"; to:   6; duration: 50 }
        PropertyAnimation { target: bottomCard; property: "anchors.horizontalCenterOffset"; to:   0; duration: 50 }
    }
}
