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

    // -------------------------------------------------------------------------
    // Responsive Scaling
    // Base: 1366x768 = 1.0. Clamps to [0.75, 2.0] for all screen sizes.
    // -------------------------------------------------------------------------
    readonly property real scaleFactor: {
        var s = Math.min(width / 1366, height / 768)
        if (s < 0.75) return 0.75
        if (s > 2.0)  return 2.0
        return s
    }
    readonly property real baseUnit: 8 * scaleFactor

    // -------------------------------------------------------------------------
    // Theme Constants & Style Tokens
    // -------------------------------------------------------------------------
    readonly property color mPrimary:           config.mPrimary           || "#c7a1d8"
    readonly property color mOnPrimary:         config.mOnPrimary         || "#1a151f"
    readonly property color mSurface:           config.mSurface           || "#1c1822"
    readonly property color mSurfaceVariant:    config.mSurfaceVariant    || "#262130"
    readonly property color mOnSurface:         config.mOnSurface         || "#e9e4f0"
    readonly property color mOnSurfaceVariant:  config.mOnSurfaceVariant  || "#a79ab0"
    readonly property color mError:             config.mError             || "#e9899d"
    readonly property color mOutline:           config.mOutline           || "#342c42"

    // Responsive sizes
    readonly property real radiusL:       20 * scaleFactor
    readonly property real fontSizeM:     11 * scaleFactor
    readonly property real fontSizeL:     13 * scaleFactor
    readonly property real fontSizeXL:    16 * scaleFactor
    readonly property real fontSizeXXL:   18 * scaleFactor
    readonly property real fontSizeClock: 42 * scaleFactor

    readonly property string backgroundPath: config.background || "Assets/background.png"

    // Blur config
    // blurRadius      — static background blur (0 = off)
    // focusBlurRadius — blur that kicks in when typing password (0 = off)
    readonly property real blurRadius:      parseFloat(config.blurRadius)      || 0
    readonly property real focusBlurRadius: parseFloat(config.focusBlurRadius) || 32

    property font fontMain: Qt.font({ family: "Noto Sans", pixelSize: 14 * scaleFactor })

    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    // -------------------------------------------------------------------------
    // Background — static wallpaper
    // -------------------------------------------------------------------------
    Image {
        id: wallpaper
        anchors.fill: parent
        source: root.backgroundPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        clip: true
    }

    // -------------------------------------------------------------------------
    // Background — always-on static blur (blurRadius in theme.conf)
    // -------------------------------------------------------------------------
    FastBlur {
        id: staticBlur
        anchors.fill: parent
        source: wallpaper
        radius: root.blurRadius
        transparentBorder: false
        visible: root.blurRadius > 0
        cached: true
    }

    // -------------------------------------------------------------------------
    // Background — animated focus blur (triggered by typing password)
    // -------------------------------------------------------------------------
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

    // Dark vignette overlay
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0.6) }
            GradientStop { position: 0.4; color: Qt.rgba(0,0,0,0.2) }
            GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.7) }
        }
    }

    // -------------------------------------------------------------------------
    // Top Card: User Info & Time
    // -------------------------------------------------------------------------
    Rectangle {
        id: headerCard
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.12
        anchors.horizontalCenter: parent.horizontalCenter

        width: Math.max(400 * scaleFactor, Math.min(parent.width * 0.70, 550 * scaleFactor))
        height: 120 * scaleFactor
        radius: root.radiusL
        color: root.mSurface
        border.color: Qt.rgba(root.mOutline.r, root.mOutline.g, root.mOutline.b, 0.2)
        border.width: 1 * scaleFactor

        RowLayout {
            id: headerRow
            anchors.fill: parent
            anchors.margins: 16 * scaleFactor
            spacing: 32 * scaleFactor

            // ---- Avatar ----
            Item {
                id: avatarRect
                Layout.preferredWidth: 70 * scaleFactor
                Layout.preferredHeight: 70 * scaleFactor
                Layout.alignment: Qt.AlignVCenter

                width: 70 * scaleFactor
                height: 70 * scaleFactor

                property int tryIndex: 0

                property string primaryUser:     userModel.lastUser
                property string currentIcon:     ""
                property string currentHome:     ""
                property string currentRealName: ""
                property string firstUserName:   ""

                Repeater {
                    model: userModel
                    delegate: Item {
                        visible: false
                        Binding { target: avatarRect; property: "firstUserName";   value: model.name;     when: index === 0 }
                        Binding { target: avatarRect; property: "currentIcon";     value: model.icon;     when: model.name === avatarRect.displayUser }
                        Binding { target: avatarRect; property: "currentHome";     value: model.homeDir;  when: model.name === avatarRect.displayUser }
                        Binding { target: avatarRect; property: "currentRealName"; value: model.realName; when: model.name === avatarRect.displayUser }
                    }
                }

                property string displayUser: primaryUser !== "" ? primaryUser : firstUserName
                property string displayName: currentRealName !== "" ? currentRealName : (displayUser !== "" ? displayUser : "User")

                onDisplayUserChanged: { tryIndex = 0 }

                property var iconPaths: {
                    var paths = []
                    var u = displayUser
                    if (u) {
                        // 0. Noctalia avatar (from theme.conf, synced by post_hook)
                        if (config.avatarPath && config.avatarPath !== "")
                            paths.push("file://" + config.avatarPath)
                        // 1. Path from userModel / AccountsService
                        if (currentIcon && currentIcon !== "") {
                            var p = currentIcon
                            if (p.indexOf("://") === -1 && p.charAt(0) === '/')
                                p = "file://" + p
                            paths.push(p)
                        }
                        // 2. AccountsService standard location
                        paths.push("file:///var/lib/AccountsService/icons/" + u)
                        // 3. Home directory faces
                        if (currentHome) {
                            paths.push("file://" + currentHome + "/.face.icon")
                            paths.push("file://" + currentHome + "/.face")
                        }
                        // 4. SDDM system faces
                        paths.push("file:///usr/share/sddm/faces/" + u + ".face.icon")
                    }
                    // 5. SDDM default face
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
                    source: {
                        if (parent.iconPaths.length === 0) return ""
                        return parent.iconPaths[Math.min(parent.tryIndex, parent.iconPaths.length - 1)]
                    }
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
                    id: fallbackLogo
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

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.color: root.mPrimary
                    border.width: 2 * scaleFactor
                }
            }

            // ---- Text Info ----
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 2 * scaleFactor

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
                }

                Timer {
                    interval: 60000
                    running: true
                    repeat: true
                    onTriggered: dateText.text = Qt.formatDate(new Date(), "dddd, MMMM d")
                }
            }

            Item { Layout.fillWidth: true }

            // ---- Clock ----
            Item {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: clockText.implicitWidth
                Layout.preferredHeight: clockText.implicitHeight

                Text {
                    id: clockText
                    text: Qt.formatTime(new Date(), "hh:mm")
                    font.pixelSize: root.fontSizeClock
                    font.bold: true
                    color: root.mOnSurface
                }

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: clockText.text = Qt.formatTime(new Date(), "hh:mm")
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Bottom Card: Password & Controls
    // -------------------------------------------------------------------------
    Rectangle {
        id: bottomCard
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 100 * scaleFactor
        anchors.horizontalCenter: parent.horizontalCenter

        width: Math.min(750 * scaleFactor, parent.width * 0.9)
        height: 140 * scaleFactor
        radius: root.radiusL
        color: root.mSurface
        border.color: Qt.rgba(root.mOutline.r, root.mOutline.g, root.mOutline.b, 0.2)
        border.width: 1 * scaleFactor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20 * scaleFactor
            spacing: 15 * scaleFactor

            // ---- Password Field Row ----
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 50 * scaleFactor
                spacing: 15 * scaleFactor

                // Input Box
                Rectangle {
                    id: passwordFieldRect
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.mSurfaceVariant
                    radius: 12 * scaleFactor
                    clip: true

                    Row {
                        id: symbolsWrapper
                        spacing: 14
                        anchors.left: parent.left
                        anchors.leftMargin: 15 * scaleFactor
                        anchors.verticalCenter: parent.verticalCenter
                        Repeater {
                            model: passwordBox.text.length
                            delegate: Item {
                                id: charItem
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
                                        var ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.fillStyle = shapeCanvas.currentColor;
                                        var cx = width / 2, cy = height / 2;
                                        var baseSize = width * 0.9;
                                        ctx.beginPath();

                                        if (shapeType === 0) {
                                            ctx.arc(cx, cy, baseSize / 2, 0, Math.PI * 2);
                                        } else if (shapeType === 1) {
                                            var half = baseSize * 1.1 / 2;
                                            ctx.moveTo(cx, cy - half); ctx.lineTo(cx + half, cy);
                                            ctx.lineTo(cx, cy + half); ctx.lineTo(cx - half, cy);
                                            ctx.closePath();
                                        } else if (shapeType === 2) {
                                            var tSize = baseSize * 1.15;
                                            var tH = (Math.sqrt(3)/2) * tSize;
                                            var yOff = tH / 6;
                                            ctx.moveTo(cx, cy - tH/2 - yOff);
                                            ctx.lineTo(cx + tSize/2, cy + tH/2 - yOff);
                                            ctx.lineTo(cx - tSize/2, cy + tH/2 - yOff);
                                            ctx.closePath();
                                        } else if (shapeType === 3) {
                                            var sqS = baseSize * 0.85, off = sqS/2, r = sqS * 0.4;
                                            ctx.moveTo(cx-off+r, cy-off); ctx.lineTo(cx+off-r, cy-off);
                                            ctx.quadraticCurveTo(cx+off,cy-off, cx+off,cy-off+r);
                                            ctx.lineTo(cx+off,cy+off-r);
                                            ctx.quadraticCurveTo(cx+off,cy+off, cx+off-r,cy+off);
                                            ctx.lineTo(cx-off+r,cy+off);
                                            ctx.quadraticCurveTo(cx-off,cy+off, cx-off,cy+off-r);
                                            ctx.lineTo(cx-off,cy-off+r);
                                            ctx.quadraticCurveTo(cx-off,cy-off, cx-off+r,cy-off);
                                            ctx.closePath();
                                        } else if (shapeType === 4) {
                                            var oR = baseSize*0.75, iR = baseSize*0.32, spikes = 5;
                                            var step = Math.PI/spikes, rot = Math.PI/2*3;
                                            ctx.moveTo(cx, cy - oR);
                                            for (var i = 0; i < spikes; i++) {
                                                ctx.lineTo(cx+Math.cos(rot)*oR, cy+Math.sin(rot)*oR); rot+=step;
                                                ctx.lineTo(cx+Math.cos(rot)*iR, cy+Math.sin(rot)*iR); rot+=step;
                                            }
                                            ctx.lineTo(cx, cy - oR); ctx.closePath();
                                        } else if (shapeType === 5) {
                                            var pR = baseSize*0.55, pA = (Math.PI*2)/5, sA = -Math.PI/2;
                                            ctx.moveTo(cx+pR*Math.cos(sA), cy+pR*Math.sin(sA));
                                            for (var i=1; i<=5; i++) ctx.lineTo(cx+pR*Math.cos(sA+i*pA), cy+pR*Math.sin(sA+i*pA));
                                            ctx.closePath();
                                        } else if (shapeType === 6) {
                                            var hR = baseSize*0.5, hA = (Math.PI*2)/6, hS = -Math.PI/2;
                                            ctx.moveTo(cx+hR*Math.cos(hS), cy+hR*Math.sin(hS));
                                            for (var i=1; i<=6; i++) ctx.lineTo(cx+hR*Math.cos(hS+i*hA), cy+hR*Math.sin(hS+i*hA));
                                            ctx.closePath();
                                        } else {
                                            var fR = baseSize*0.5, petals = 8, fStep = (Math.PI*2)/petals;
                                            for (var i=0; i<petals; i++) {
                                                var t1=i*fStep, t2=(i+1)*fStep, cpT=(t1+t2)/2, cpR=fR*1.25;
                                                var sx=cx+fR*Math.cos(t1), sy=cy+fR*Math.sin(t1);
                                                var ex=cx+fR*Math.cos(t2), ey=cy+fR*Math.sin(t2);
                                                var cpx=cx+cpR*Math.cos(cpT), cpy=cy+cpR*Math.sin(cpT);
                                                if (i===0) ctx.moveTo(sx,sy);
                                                ctx.quadraticCurveTo(cpx,cpy,ex,ey);
                                            }
                                            ctx.closePath();
                                        }
                                        ctx.fill();
                                    }
                                }
                            }
                        }
                    }

                    // Invisible TextInput that captures keystrokes
                    TextInput {
                        id: passwordBox
                        anchors.fill: parent
                        anchors.margins: 15 * scaleFactor
                        verticalAlignment: Text.AlignVCenter
                        text: ""
                        echoMode: TextInput.NoEcho
                        visible: false
                        font.pixelSize: 14 * scaleFactor
                        focus: true
                        onAccepted: sddm.login(userModel.lastUser, passwordBox.text, sessionList.currentIndex)
                        Keys.onPressed: {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                sddm.login(userModel.lastUser, passwordBox.text, sessionList.currentIndex)
                                event.accepted = true
                            }
                        }
                    }

                    // Placeholder text
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

                // Login Button
                Controls.Button {
                    Layout.preferredWidth: 100 * scaleFactor
                    Layout.fillHeight: true
                    background: Rectangle {
                        color: parent.down ? Qt.darker(root.mPrimary, 1.2) : root.mPrimary
                        radius: 12 * scaleFactor
                    }
                    contentItem: Text {
                        text: "Login"
                        font.pixelSize: 14 * scaleFactor
                        font.bold: true
                        color: root.mOnPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: sddm.login(userModel.lastUser, passwordBox.text, sessionList.currentIndex)
                }
            }

            // ---- Controls Row ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 10 * scaleFactor

                Controls.ComboBox {
                    id: sessionList
                    model: sessionModel
                    textRole: "name"
                    currentIndex: sessionModel.lastIndex
                    Layout.preferredWidth: 200 * scaleFactor
                    Layout.preferredHeight: 36 * scaleFactor

                    delegate: Controls.ItemDelegate {
                        width: parent.width
                        text: model.name || ""
                        highlighted: sessionList.highlightedIndex === index
                        contentItem: Text {
                            text: parent.text
                            color: root.mOnSurface
                            font.pixelSize: root.fontSizeM
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: parent.highlighted ? root.mSurfaceVariant : "transparent"
                        }
                    }
                    background: Rectangle {
                        color: root.mSurfaceVariant
                        radius: 8 * scaleFactor
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
                            border.color: root.mOutline
                            color: root.mSurface
                            radius: 4 * scaleFactor
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Repeater {
                    model: [
                        { text: "Suspend",  type: "suspend"  },
                        { text: "Reboot",   type: "reboot"   },
                        { text: "Shutdown", type: "shutdown" }
                    ]
                    delegate: Controls.Button {
                        text: modelData.text
                        Layout.preferredHeight: 36 * scaleFactor
                        Layout.preferredWidth: 100 * scaleFactor
                        background: Rectangle {
                            color: parent.down ? Qt.darker(root.mSurfaceVariant, 1.2) : root.mSurfaceVariant
                            radius: 8 * scaleFactor
                        }
                        contentItem: Text {
                            text: parent.text
                            font.pixelSize: root.fontSizeM
                            color: root.mOnSurface
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            if      (modelData.type === "suspend")  sddm.suspend()
                            else if (modelData.type === "reboot")   sddm.reboot()
                            else if (modelData.type === "shutdown")  sddm.powerOff()
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Error Message
    // -------------------------------------------------------------------------
    Rectangle {
        width: errorMessage.implicitWidth + 40 * scaleFactor
        height: 50 * scaleFactor
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: bottomCard.top
        anchors.bottomMargin: 20 * scaleFactor
        radius: root.radiusL
        color: root.mError
        visible: errorMessage.text !== ""

        Text {
            id: errorMessage
            anchors.centerIn: parent
            text: ""
            color: "#1e1418"
            font.pixelSize: root.fontSizeM
            font.bold: true
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            passwordBox.text = ""
            errorMessage.text = "Authentication failed"
        }
    }
}
