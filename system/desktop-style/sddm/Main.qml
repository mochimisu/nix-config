import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Shapes

Rectangle {
    id: root
    width: 1280; height: 800
    color: config.Surface
    property date now: new Date()
    readonly property bool virtualKeyboardEnabled: config.VirtualKeyboardEnabled === "true"
    property bool busy: false
    property string message: ""
    property bool manualUser: false
    property bool choosingUser: false
    readonly property string loginUser: manualUser ? username.text.trim() : userChoice.currentText
    // SDDM supplies the real account model; test mode may have no readable last-user state.
    function initializeUser() {
        const remembered = String(userModel.lastUser || "");
        const rememberedIndex = remembered === "" ? -1 : userChoice.find(remembered);
        if (rememberedIndex >= 0) {
            userChoice.currentIndex = rememberedIndex;
            manualUser = false;
        } else if (remembered !== "") {
            // A remembered directory/hidden account may not be in the visible list.
            username.text = remembered;
            manualUser = true;
        } else if (userChoice.count > 0) {
            const index = userModel.lastIndex;
            userChoice.currentIndex = index >= 0 && index < userChoice.count ? index : 0;
            manualUser = false;
        } else {
            username.text = "";
            manualUser = true;
        }
        choosingUser = loginUser === "";
        Qt.callLater(function() {
            if (root.loginUser === "") username.forceActiveFocus();
            else password.forceActiveFocus();
        });
    }
    Component.onCompleted: Qt.callLater(initializeUser)
    readonly property bool compact: width < 900 || height < 680
    // The greeter supplies userModel, sessionModel, keyboard and sddm.
    function reveal(item) {
        Qt.callLater(function() {
            const point = item.mapToItem(viewport.contentItem, 0, 0);
            if (point.y < viewport.contentY) viewport.contentY = point.y;
            else if (point.y + item.height > viewport.contentY + viewport.height)
                viewport.contentY = point.y + item.height - viewport.height;
            viewport.returnToBounds();
        });
    }
    function login() {
        if (busy || loginUser === "" || sessions.currentIndex < 0) return;
        busy = true;
        message = "";
        sddm.login(loginUser, password.text, sessions.currentIndex);
    }
    // Sample wall time at the display cadence: no easing, tick pauses, cumulative
    // animation drift, or catch-up sweep after the greeter has been suspended.
    FrameAnimation {
        id: dialFrames
        running: root.visible
        onTriggered: root.now = new Date()
    }
    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false; root.message = qsTr("Sign-in failed. Please try again.");
            password.clear(); password.forceActiveFocus();
        }
        function onLoginSucceeded() { root.message = qsTr("Starting your session…"); }
        function onInformationMessage(message) { root.message = message; }
    }
    // Broad, off-center light like the blue watch dial: a restrained steel-blue
    // highlight falls into deep navy, rather than a flat slate-colored surface.
    Shape {
        anchors.fill: parent
        ShapePath {
            strokeWidth: 0
            fillGradient: RadialGradient {
                centerX: root.width * 0.22; centerY: root.height * 0.16
                focalX: centerX; focalY: centerY
                centerRadius: Math.max(root.width * 0.9, root.height * 1.15)
                GradientStop { position: 0; color: "#243e5a" }
                GradientStop { position: 0.30; color: "#192f4b" }
                GradientStop { position: 0.66; color: config.Surface }
                GradientStop { position: 1; color: "#080f20" }
            }
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
        }
    }

    // Analytic curve rendering keeps large circular strokes smooth while rotating,
    // without a large offscreen texture or polygonal rounded-rectangle edges.
    component DialCircle: Shape {
        id: outline
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: 2
            strokeColor: "#60798e"
            fillColor: "transparent"
            PathAngleArc {
                centerX: outline.width / 2; centerY: outline.height / 2
                radiusX: (outline.width - 2) / 2; radiusY: (outline.height - 2) / 2
                startAngle: 0; sweepAngle: 360
            }
        }
    }

    // Three continuous wheels share the readout axis. Fractional hours/minutes/
    // seconds carry each wheel toward its next index at a constant angular speed.
    Item {
        anchors.fill: parent; clip: true
        Item {
            id: dial
            readonly property real centerX: Math.min(root.height * 0.88, root.width * 0.66) * 0.02
            readonly property real centerY: timeReadout.y + timeReadout.height / 2
            Repeater {
                id: timeRings
                model: 3
                Item {
                    id: ring
                    required property int index
                    readonly property int divisions: index === 0 ? 24 : 60
                    readonly property real seconds: root.now.getSeconds() + root.now.getMilliseconds() / 1000
                    readonly property real minutes: root.now.getMinutes() + seconds / 60
                    readonly property real value: index === 0 ? root.now.getHours() + minutes / 60 : index === 1 ? minutes : seconds
                    readonly property real readoutX: timeReadout.x + (index === 0 ? timeReadout.hourWidth / 2 : timeReadout.hourWidth + (index === 1 ? timeReadout.minuteWidth / 2 : timeReadout.minuteWidth + timeReadout.secondWidth / 2))
                    readonly property font readoutFont: index === 0 ? hourText.font : index === 1 ? minuteText.font : secondText.font
                    FontMetrics { id: ringMetrics; font: ring.readoutFont }
                    // Center the selected ring glyph under its overlay glyph, including
                    // the inset and font height, so large hours cannot peek past the pill.
                    readonly property real radius: readoutX - dial.centerX + 21 + ringMetrics.height / 2
                    width: radius * 2; height: width
                    x: dial.centerX - radius; y: dial.centerY - radius
                    rotation: 90 - value * 360 / divisions
                    DialCircle {
                        anchors.fill: parent; anchors.margins: 1
                    }
                    DialCircle {
                        visible: ring.index === 2
                        anchors.fill: parent; anchors.margins: 12
                    }
                    Repeater {
                        model: ring.divisions
                        Item {
                            required property int index
                            anchors.fill: parent
                            rotation: index * 360 / ring.divisions
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: ring.index === 2
                                y: 2; width: index % 5 === 0 ? 2 : 1
                                height: 10; color: config.Ink; antialiasing: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter; y: 21; height: ringMetrics.height
                                text: String(index).padStart(2, "0")
                                visible: ring.index === 0 ? index % (root.compact ? 4 : 2) === 0 : index % 5 === 0
                                rotation: -90
                                font: ring.readoutFont
                                color: config.Muted
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            id: timeReadout
            readonly property real hourSize: root.compact ? 32 : 40
            readonly property real hourWidth: root.compact ? 90 : 120
            readonly property real minuteWidth: root.compact ? 86 : 120
            readonly property real secondWidth: root.compact ? 64 : 80
            x: root.compact ? 32 : root.width * 0.075
            y: root.compact ? 20 : root.height / 2 - height / 2
            width: hourWidth + minuteWidth + secondWidth
            height: root.compact ? 64 : 80
            radius: height / 2; color: config.Lavender
            gradient: Gradient {
                GradientStop { position: 0; color: "#1a304a" }
                GradientStop { position: 1; color: config.Lavender }
            }
            border.width: 1; border.color: "#526b81"
            Text {
                id: hourText
                width: timeReadout.hourWidth; height: parent.height
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: Qt.formatTime(root.now, "HH")
                color: config.Ink; font.family: config.Font
                font.pixelSize: timeReadout.hourSize; font.bold: true
                font.features: { "tnum": 1 }
            }
            Text {
                id: minuteText
                x: timeReadout.hourWidth; width: timeReadout.minuteWidth; height: parent.height
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: Qt.formatTime(root.now, "mm")
                color: config.Ink; font.family: config.Font; font.pixelSize: root.compact ? 24 : 26; font.bold: true
                font.features: { "tnum": 1 }
            }
            Rectangle {
                x: timeReadout.hourWidth + timeReadout.minuteWidth; width: 1; height: 24
                anchors.verticalCenter: parent.verticalCenter; color: "#526b81"
            }
            Text {
                id: secondText
                x: timeReadout.hourWidth + timeReadout.minuteWidth; width: timeReadout.secondWidth; height: parent.height
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: Qt.formatTime(root.now, "ss")
                color: config.Muted; font.family: config.Font; font.pixelSize: root.compact ? 18 : 20
                font.features: { "tnum": 1 }
            }
        }
        Column {
            visible: !root.compact && root.width >= 1200
            x: root.width * 0.73; y: root.height / 2 - height / 2; spacing: 9
            Text { text: Qt.formatDate(root.now, "dd MMM yyyy").toUpperCase(); color: config.Muted; font.family: config.Font; font.pixelSize: 11; font.letterSpacing: 3 }
            Text { text: Qt.formatDate(root.now, "dddd").toUpperCase(); color: config.Ink; font.family: config.Font; font.pixelSize: 15; font.bold: true; font.letterSpacing: 6 }
        }
    }

    component Label: Text {
        color: config.Ink; font.family: config.Font; font.pixelSize: 14
        renderType: Text.NativeRendering
    }
    component Pill: Button {
        id: button
        onActiveFocusChanged: if (activeFocus) root.reveal(button)
        property bool primary: false
        implicitHeight: primary ? 52 : 42
        font.family: config.Font; font.pixelSize: 14; font.bold: true
        palette.buttonText: config.Ink
        Accessible.name: text
        contentItem: Text {
            text: button.text + (button.primary ? "   →" : "")
            color: config.Ink; font: button.font
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 8
            color: button.down ? config.Pink : button.primary ? config.Mint : config.Lavender
            border.width: button.activeFocus ? 2 : 1; border.color: config.Ink
        }
        opacity: enabled ? 1 : 0.65
    }
    component Entry: TextField {
        id: entry
        onActiveFocusChanged: if (activeFocus) root.reveal(entry)
        implicitHeight: 42
        font.family: config.Font; font.pixelSize: 16
        color: config.Ink; placeholderTextColor: config.Muted
        selectionColor: config.Mint; selectedTextColor: config.Ink
        selectByMouse: true
        leftPadding: 14; rightPadding: 14
        background: Rectangle {
            radius: 8; color: config.Lavender; border.width: entry.activeFocus ? 2 : 1; border.color: config.Ink
        }
    }
    component Choice: ComboBox {
        id: choice
        onActiveFocusChanged: if (activeFocus) root.reveal(choice)
        implicitHeight: 42
        font.family: config.Font; font.pixelSize: 14
        palette.text: config.Ink; palette.buttonText: config.Ink
        palette.base: config.Surface; palette.highlight: config.Mint
        palette.highlightedText: config.Ink
        background: Rectangle {
            radius: 8; color: config.Lavender; border.width: choice.activeFocus ? 2 : 1; border.color: config.Ink
        }
    }

    // Scroll rather than scale controls below comfortable keyboard/touch sizes.
    Flickable {
        id: viewport
        anchors.fill: parent; anchors.margins: root.compact ? 24 : 56
        anchors.topMargin: root.compact ? 100 : 56
        anchors.bottomMargin: (root.compact ? 24 : 56) + (virtualKeyboard.item && virtualKeyboard.item.active ? virtualKeyboard.height : 0)
        onHeightChanged: {
            if (password.activeFocus) root.reveal(password);
            else if (username.activeFocus) root.reveal(username);
        }
        contentWidth: width; contentHeight: Math.max(height, layout.implicitHeight)
        clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        Item {
            id: layout
            width: viewport.width
            implicitHeight: loginCard.implicitHeight
            y: Math.max(0, (viewport.height - implicitHeight) / 2)
            Rectangle {
                id: loginCard
                color: "transparent"
                width: Math.min(360, parent.width)
                x: (parent.width - width) / 2
                implicitHeight: form.implicitHeight + 56
                ColumnLayout {
                    id: form
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 28; spacing: 10
                    Label { text: config.HostName; font.pixelSize: 15; font.letterSpacing: 6; font.bold: true }
                    Label { text: qsTr("Account"); font.bold: true }
                    RowLayout {
                        Layout.fillWidth: true; visible: !root.choosingUser
                        Label {
                            Layout.fillWidth: true; text: root.loginUser; elide: Text.ElideRight
                            font.pixelSize: 18; font.bold: true
                            Accessible.name: qsTr("Selected account: ") + text
                        }
                        ToolButton {
                            text: qsTr("Change"); implicitHeight: 40
                            font.family: config.Font; palette.buttonText: config.Ink
                            Accessible.name: qsTr("Change account"); enabled: !root.busy
                            onClicked: {
                                root.choosingUser = true; password.clear();
                                if (root.manualUser) username.forceActiveFocus();
                                else userChoice.forceActiveFocus();
                            }
                        }
                    }
                    Choice {
                        id: userChoice; Layout.fillWidth: true
                        visible: root.choosingUser && !root.manualUser
                        model: userModel; textRole: "name"; currentIndex: userModel.lastIndex
                        Accessible.name: qsTr("Account"); enabled: !root.busy
                        onActivated: {
                            root.choosingUser = false; password.clear(); password.forceActiveFocus();
                        }
                    }
                    Entry {
                        id: username; Layout.fillWidth: true
                        visible: root.choosingUser && root.manualUser
                        Accessible.name: qsTr("Username"); enabled: !root.busy
                        KeyNavigation.tab: password
                        onAccepted: {
                            if (text.trim() !== "") root.choosingUser = false;
                            password.forceActiveFocus();
                        }
                        onTextEdited: password.clear()
                    }
                    ToolButton {
                        visible: root.choosingUser && userChoice.count > 0
                        text: root.manualUser ? qsTr("Use listed account") : qsTr("Other user…")
                        implicitHeight: 40; font.family: config.Font; palette.buttonText: config.Ink
                        Accessible.name: text; enabled: !root.busy
                        onClicked: {
                            root.manualUser = !root.manualUser; password.clear();
                            if (root.manualUser) { username.clear(); username.forceActiveFocus(); }
                            else {
                                if (userChoice.currentIndex < 0) userChoice.currentIndex = 0;
                                userChoice.forceActiveFocus();
                            }
                        }
                    }
                    Label { text: qsTr("Password"); font.bold: true }
                    Entry {
                        id: password; Layout.fillWidth: true; echoMode: TextInput.Password
                        Accessible.name: qsTr("Password"); enabled: !root.busy
                        KeyNavigation.tab: sessions
                        onAccepted: root.login()
                    }
                    Pill {
                        visible: root.virtualKeyboardEnabled
                        Layout.fillWidth: true; text: qsTr("On-screen keyboard")
                        onClicked: { password.forceActiveFocus(); Qt.inputMethod.visible ? Qt.inputMethod.hide() : Qt.inputMethod.show(); }
                    }
                    Label { text: qsTr("Caps Lock is on"); color: config.Urgent; visible: keyboard.capsLock }
                    Label { text: qsTr("Session"); font.bold: true }
                    Choice {
                        id: sessions; Layout.fillWidth: true
                        model: sessionModel; textRole: "name"; currentIndex: sessionModel.lastIndex
                        Accessible.name: qsTr("Session"); enabled: !root.busy
                    }
                    Label { text: qsTr("Keyboard layout"); font.bold: true }
                    Choice {
                        id: layouts; Layout.fillWidth: true
                        model: keyboard.layouts; textRole: "longName"; currentIndex: keyboard.currentLayout
                        Accessible.name: qsTr("Keyboard layout"); enabled: !root.busy
                        onActivated: keyboard.currentLayout = currentIndex
                    }
                    Label {
                        Layout.fillWidth: true; wrapMode: Text.Wrap
                        text: root.message; color: config.Urgent; visible: text !== ""
                        Accessible.name: text
                    }
                    Pill {
                        primary: true
                        Layout.fillWidth: true; text: root.busy ? qsTr("Signing in…") : qsTr("Sign in")
                        enabled: !root.busy && root.loginUser !== "" && sessions.currentIndex >= 0
                        onClicked: root.login()
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Pill { Layout.fillWidth: true; text: qsTr("Sleep"); visible: sddm.canSuspend; onClicked: sddm.suspend() }
                        Pill { Layout.fillWidth: true; text: qsTr("Restart"); visible: sddm.canReboot; onClicked: sddm.reboot() }
                        Pill { Layout.fillWidth: true; text: qsTr("Shut down"); visible: sddm.canPowerOff; onClicked: sddm.powerOff() }
                    }
                }
            }
        }
    }
    Loader {
        id: virtualKeyboard
        active: root.virtualKeyboardEnabled
        source: "VirtualKeyboard.qml"
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: item ? item.implicitHeight : 0
        z: 100
    }
}
