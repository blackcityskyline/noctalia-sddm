import QtQuick 2.15
import QtQuick.Controls 2.15 as Controls
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import Qt5Compat.GraphicalEffects 1.0
import "."

import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width || 1920
    height: Screen.height || 1080

    // -------------------------------------------------------------------------
    // Responsive Scaling
    // -------------------------------------------------------------------------
    readonly property real scaleFactor: Math.max(0.5, Math.min(width / 1920, height / 1080))
    readonly property real baseUnit: 8 * scaleFactor
    
    // -------------------------------------------------------------------------
    // Theme Constants (Rose Pine) & Style Tokens
    // -------------------------------------------------------------------------
    readonly property color mPrimary: config.mPrimary || "#c7a1d8"
    readonly property color mOnPrimary: config.mOnPrimary || "#1a151f"
    readonly property color mSurface: config.mSurface || "#1c1822"
    readonly property color mSurfaceVariant: config.mSurfaceVariant || "#262130"
    readonly property color mOnSurface: config.mOnSurface || "#e9e4f0"
    readonly property color mOnSurfaceVariant: config.mOnSurfaceVariant || "#a79ab0"
    readonly property color mError: config.mError || "#e9899d"
    readonly property color mOutline: config.mOutline || "#342c42"
    
    // Responsive sizes
    readonly property real radiusL: 20 * scaleFactor
    readonly property real fontSizeM: 11 * scaleFactor
    readonly property real fontSizeL: 13 * scaleFactor
    readonly property real fontSizeXL: 16 * scaleFactor
    readonly property real fontSizeXXL: 18 * scaleFactor
    readonly property real fontSizeClock: 42 * scaleFactor

    // Configurable Background
    readonly property string backgroundPath: config.background || "Assets/background.png"

    // Fonts
    property font fontMain: Qt.font({
        family: "Noto Sans",
        pixelSize: 14 * scaleFactor
    })
    
    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    readonly property real blurRadius: config.blurRadius || 0

    // -------------------------------------------------------------------------
    // Background
    // -------------------------------------------------------------------------
    Image {
        id: wallpaper
        anchors.fill: parent
        source: root.backgroundPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        clip: true
        visible: root.blurRadius <= 0 // Hide if blurred version is shown
    }

    FastBlur {
        anchors.fill: parent
        source: wallpaper
        radius: root.blurRadius
        transparentBorder: false
        visible: root.blurRadius > 0
        cached: true
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0.6) } // Darker top
            GradientStop { position: 0.4; color: Qt.rgba(0,0,0,0.2) }
            GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.7) } // Darker bottom
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

            // Avatar - Perfect Circle
            Item {
                id: avatarRect
                Layout.preferredWidth: 70 * scaleFactor
                Layout.preferredHeight: 70 * scaleFactor
                Layout.alignment: Qt.AlignVCenter
                
                width: 70 * scaleFactor
                height: 70 * scaleFactor
                
                property int tryIndex: 0
                
                property string primaryUser: userModel.lastUser
                property string currentIcon: ""
                property string currentHome: ""
                property string currentRealName: ""
                property string firstUserName: ""

                // Data Extractor
                Repeater {
                    model: userModel
                    delegate: Item {
                        visible: false
                        
                        // Capture first user name as fallback
                        Binding {
                            target: avatarRect
                            property: "firstUserName"
                            value: model.name
                            when: index === 0
                        }

                        // Capture details if this matches primaryUser
                        Binding {
                            target: avatarRect // The Avatar Rectangle
                            property: "currentIcon"
                            value: model.icon
                            when: model.name === avatarRect.displayUser
                        }
                        Binding {
                            target: avatarRect // The Avatar Rectangle
                            property: "currentHome"
                            value: model.homeDir
                            when: model.name === avatarRect.displayUser
                        }
                         Binding {
                            target: avatarRect // The Avatar Rectangle
                            property: "currentRealName"
                            value: model.realName
                            when: model.name === avatarRect.displayUser
                        }
                    }
                }
                
                // Computed property for whom we are showing
                property string displayUser: primaryUser !== "" ? primaryUser : firstUserName
                property string displayName: currentRealName !== "" ? currentRealName : (displayUser !== "" ? displayUser : "User")
                
                // Reset try index when user changes
                onDisplayUserChanged: {
                    tryIndex = 0
                }
                
                // Get list of icon paths to try
                property var iconPaths: {
                    var paths = []
                    var u = displayUser
                    
                    if (u) {
                        // 1. Try path from userModel (if any)
                        if (currentIcon && currentIcon !== "") {
                            var p = currentIcon
                            if (p.indexOf("://") === -1 && p.charAt(0) === '/') 
                                p = "file://" + p
                            paths.push(p)
                        }
                        
                        // 2. Try home directory faces
                        if (currentHome) {
                            paths.push("file://" + currentHome + "/.face.icon")
                            paths.push("file://" + currentHome + "/.face")
                        }
                        
                        // 3. System paths
                        paths.push("file:///usr/share/sddm/faces/" + u + ".face.icon")
                        paths.push("file:///var/lib/AccountsService/icons/" + u)
                    }
                    
                    // 4. Default fallback
                    paths.push("file:///usr/share/sddm/faces/.face.icon")
                    
                    return paths
                }
                
                // Circular mask for perfect circle
                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }
                
                // User avatar image (circular)
                Image {
                    id: userAvatar
                    anchors.fill: parent
                    source: {
                        if (parent.iconPaths.length === 0) return ""
                        var idx = Math.min(parent.tryIndex, parent.iconPaths.length - 1)
                        return parent.iconPaths[idx]
                    }
                    sourceSize: Qt.size(70 * scaleFactor, 70 * scaleFactor)
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    visible: status === Image.Ready
                    asynchronous: true
                    
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: avatarMask
                    }
                    
                    // Try next path if current one fails
                    onStatusChanged: {
                        if (status === Image.Error && parent.tryIndex < parent.iconPaths.length - 1) {
                            parent.tryIndex++
                        }
                    }
                }
                
                // Fallback logo if user avatar not available
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
                    layer.effect: OpacityMask {
                        maskSource: avatarMask
                    }
                }
                
                // Circular border
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.color: root.mPrimary
                    border.width: 2 * scaleFactor
                }
            }
            
            // Text Info
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
                    text: Qt.formatDate(new Date(), "dddd, MMMM d")
                    font.pixelSize: root.fontSizeXL
                    color: root.mOnSurfaceVariant
                }
            }
            
            Item { Layout.fillWidth: true } // Spacer
            
            // Clock
            Text {
                text: Qt.formatTime(new Date(), "hh:mm")
                font.pixelSize: root.fontSizeClock
                font.bold: true
                color: root.mOnSurface
                Layout.alignment: Qt.AlignVCenter
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
            
            // Password Field Row
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 50 * scaleFactor
                spacing: 15 * scaleFactor
                
                // Input Box
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: root.mSurfaceVariant
                    radius: 12 * scaleFactor

                    // Largely duplicated from the PixelOS theme: PixelDots.qml
                    Row {
                        id: symbolsWrapper
                        spacing: 14
                        anchors.top: passwordBox.top
                        anchors.left: passwordBox.left
                        Repeater {
                            model: passwordBox.text.length

                            delegate: Item {
                                id: charItem
                                width: 20
                                height: 20
                                
                                // Animation removed. Scale is static 1.
                                scale: 1 

                                // --- SHAPE SELECTION (8 types) ---
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

                                        var cx = width / 2;
                                        var cy = height / 2;
                                        var baseSize = width * 0.9; 

                                        ctx.beginPath();
                                        
                                        if (shapeType === 0) { 
                                            // 1. Circle
                                            var r = baseSize / 2; 
                                            ctx.arc(cx, cy, r, 0, Math.PI * 2);

                                        } else if (shapeType === 1) { 
                                            // 2. Diamond
                                            var dSize = baseSize * 1.1; 
                                            var half = dSize / 2;
                                            ctx.moveTo(cx, cy - half);
                                            ctx.lineTo(cx + half, cy);
                                            ctx.lineTo(cx, cy + half);
                                            ctx.lineTo(cx - half, cy);
                                            ctx.closePath();

                                        } else if (shapeType === 2) { 
                                            // 3. Triangle
                                            var tSize = baseSize * 1.15;
                                            var tHeight = (Math.sqrt(3)/2) * tSize;
                                            var yOffset = tHeight / 6; 
                                            ctx.moveTo(cx, cy - (tHeight/2) - yOffset);
                                            ctx.lineTo(cx + (tSize/2), cy + (tHeight/2) - yOffset);
                                            ctx.lineTo(cx - (tSize/2), cy + (tHeight/2) - yOffset);
                                            ctx.closePath();

                                        } else if (shapeType === 3) { 
                                            // 4. Squircle (Pixel Style)
                                            var sqSize = baseSize * 0.85; 
                                            var offset = sqSize / 2;
                                            var radius = sqSize * 0.4; 
                                            ctx.moveTo(cx - offset + radius, cy - offset);
                                            ctx.lineTo(cx + offset - radius, cy - offset);
                                            ctx.quadraticCurveTo(cx + offset, cy - offset, cx + offset, cy - offset + radius);
                                            ctx.lineTo(cx + offset, cy + offset - radius);
                                            ctx.quadraticCurveTo(cx + offset, cy + offset, cx + offset - radius, cy + offset);
                                            ctx.lineTo(cx - offset + radius, cy + offset);
                                            ctx.quadraticCurveTo(cx - offset, cy + offset, cx - offset, cy + offset - radius);
                                            ctx.lineTo(cx - offset, cy - offset + radius);
                                            ctx.quadraticCurveTo(cx - offset, cy - offset, cx - offset + radius, cy - offset);
                                            ctx.closePath();

                                        } else if (shapeType === 4) { 
                                            // 5. Star
                                            var outerRadius = baseSize * 0.75; 
                                            var innerRadius = baseSize * 0.32; 
                                            var spikes = 5;
                                            var step = Math.PI / spikes;
                                            var rot = Math.PI / 2 * 3;
                                            var x = cx; var y = cy;
                                            ctx.moveTo(cx, cy - outerRadius);
                                            for (var i = 0; i < spikes; i++) {
                                                x = cx + Math.cos(rot) * outerRadius;
                                                y = cy + Math.sin(rot) * outerRadius;
                                                ctx.lineTo(x, y);
                                                rot += step;
                                                x = cx + Math.cos(rot) * innerRadius;
                                                y = cy + Math.sin(rot) * innerRadius;
                                                ctx.lineTo(x, y);
                                                rot += step;
                                            }
                                            ctx.lineTo(cx, cy - outerRadius);
                                            ctx.closePath();

                                        } else if (shapeType === 5) {
                                            // 6. Pentagon
                                            var pRadius = baseSize * 0.55;
                                            var pAngle = (Math.PI * 2) / 5;
                                            var startAngle = -Math.PI / 2; 
                                            ctx.moveTo(cx + pRadius * Math.cos(startAngle), cy + pRadius * Math.sin(startAngle));
                                            for (var i = 1; i <= 5; i++) {
                                                ctx.lineTo(cx + pRadius * Math.cos(startAngle + i * pAngle), 
                                                        cy + pRadius * Math.sin(startAngle + i * pAngle));
                                            }
                                            ctx.closePath();

                                        } else if (shapeType === 6) {
                                            // 7. Hexagon
                                            var hRadius = baseSize * 0.5;
                                            var hAngle = (Math.PI * 2) / 6;
                                            var hStart = -Math.PI / 2; 
                                            ctx.moveTo(cx + hRadius * Math.cos(hStart), cy + hRadius * Math.sin(hStart));
                                            for (var i = 1; i <= 6; i++) {
                                                ctx.lineTo(cx + hRadius * Math.cos(hStart + i * hAngle), 
                                                        cy + hRadius * Math.sin(hStart + i * hAngle));
                                            }
                                            ctx.closePath();

                                        } else {
                                            // 8. Flower / Scallop
                                            var fRadius = baseSize * 0.5;
                                            var petals = 8;
                                            var step = (Math.PI * 2) / petals;
                                            
                                            for (var i = 0; i < petals; i++) {
                                                var theta1 = i * step;
                                                var theta2 = (i + 1) * step;
                                                
                                                var cpRadius = fRadius * 1.25; 
                                                var cpTheta = (theta1 + theta2) / 2;

                                                var startX = cx + fRadius * Math.cos(theta1);
                                                var startY = cy + fRadius * Math.sin(theta1);
                                                var endX = cx + fRadius * Math.cos(theta2);
                                                var endY = cy + fRadius * Math.sin(theta2);
                                                var cpX = cx + cpRadius * Math.cos(cpTheta);
                                                var cpY = cy + cpRadius * Math.sin(cpTheta);

                                                if (i === 0) ctx.moveTo(startX, startY);
                                                ctx.quadraticCurveTo(cpX, cpY, endX, endY);
                                            }
                                            ctx.closePath();
                                        }
                                        
                                        ctx.fill();
                                    }
                                }
                            }
                        }
                    }
                    
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
                        
                        onAccepted: sddm.login(userModel.lastUser, passwordBox.text, sessionModel.lastIndex)
                        Keys.onPressed: {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                sddm.login(userModel.lastUser, passwordBox.text, sessionModel.lastIndex)
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
                    
                    onClicked: sddm.login(userModel.lastUser, passwordBox.text, sessionModel.lastIndex)
                }
            }
            
            // Controls Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 10 * scaleFactor
                
                // Session List
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
                
                Item { Layout.fillWidth: true } // Spacer
                
                // Power Buttons
                Repeater {
                    model: [
                        { text: "Suspend", type: "suspend" },
                        { text: "Reboot", type: "reboot" },
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
                            if (modelData.type === "suspend") {
                                sddm.suspend()
                            } else if (modelData.type === "reboot") {
                                sddm.reboot()
                            } else if (modelData.type === "shutdown") {
                                sddm.powerOff()
                            }
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
            text: "" // Set by signal
            color: "#1e1418" // mOnError
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
