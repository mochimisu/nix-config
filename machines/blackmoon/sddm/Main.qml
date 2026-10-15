import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: root
    width: 1280; height: 800
    color: config.Surface
    property date now: new Date()
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
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false; root.message = qsTr("Sign-in failed. Please try again.");
            password.clear(); password.forceActiveFocus();
        }
        function onLoginSucceeded() { root.message = qsTr("Starting your session…"); }
        function onInformationMessage(message) { root.message = message; }
    }
    // Graphic motifs from the reference: slanted pastel bands and outlined modules.
    Item {
        anchors.fill: parent; clip: true
        Rectangle {
            width: root.width * 0.6; height: root.compact ? 70 : 130
            x: -width * 0.22; y: root.height * 0.79; rotation: -14
            color: config.Mint; border.width: 2; border.color: config.Ink; opacity: 0.45
        }
        Rectangle {
            width: root.width * 0.5; height: 28
            x: root.width * 0.73; y: root.height * 0.12; rotation: -14
            color: config.Lavender; border.width: 2; border.color: config.Ink; opacity: 0.65
        }
        Rectangle {
            width: root.compact ? 140 : 230; height: width; radius: width / 2
            x: root.width - width * 0.55; y: -height * 0.52
            color: "transparent"; border.width: 14; border.color: config.Lavender
        }
    }

    component Card: Rectangle {
        property bool stacked: false
        color: config.Surface; radius: 24; border.width: 3; border.color: config.Ink
        Rectangle {
            z: -1; visible: parent.stacked
            x: 10; y: 10; width: parent.width; height: parent.height
            radius: parent.radius; color: config.Lavender; border.width: 3; border.color: config.Ink
        }
        Rectangle { anchors.fill: parent; anchors.margins: 6; radius: 18; color: "transparent"; border.width: 2; border.color: "white" }
    }
    component ClockGlyph: Item {
        id: digit
        property string glyph
        property color tint
        property real size: Math.min(118, decoration.width / 4.5)
        implicitWidth: face.implicitWidth + 2
        implicitHeight: face.implicitHeight + 8
        Repeater {
            model: [[-3,-3],[0,-3],[3,-3],[-3,0],[3,0],[-3,3],[0,3],[3,3],[4,6]]
            Text {
                required property var modelData
                x: modelData[0]; y: modelData[1]
                text: digit.glyph; font.family: config.Font; font.pixelSize: digit.size; font.weight: Font.Black
                color: config.Ink; renderType: Text.CurveRendering
            }
        }
        Text {
            id: face; text: digit.glyph
            font.family: config.Font; font.pixelSize: digit.size; font.weight: Font.Black
            color: digit.tint; style: Text.Outline; styleColor: "white"; renderType: Text.CurveRendering
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
            radius: button.primary ? 20 : 14
            color: button.down ? config.Pink : button.primary ? config.Mint : config.Lavender
            border.width: button.activeFocus ? 4 : 3; border.color: config.Ink
            Rectangle {
                z: -1; x: 0; y: button.down ? 0 : 4; width: parent.width; height: parent.height
                radius: parent.radius; color: config.Ink
            }
            Rectangle { anchors.fill: parent; anchors.margins: 5; radius: parent.radius - 5; color: "transparent"; border.width: 2; border.color: "white" }
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
            radius: 12; color: "white"; border.width: entry.activeFocus ? 4 : 2; border.color: config.Ink
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
            radius: 12; color: config.Lavender; border.width: choice.activeFocus ? 4 : 2; border.color: config.Ink
        }
    }

    // Scroll rather than scale controls below comfortable keyboard/touch sizes.
    Flickable {
        id: viewport
        anchors.fill: parent; anchors.margins: root.compact ? 24 : 56
        contentWidth: width; contentHeight: Math.max(height, layout.implicitHeight)
        clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        Item {
            id: layout
            width: viewport.width
            implicitHeight: loginCard.implicitHeight
            y: Math.max(0, (viewport.height - implicitHeight) / 2)
            ColumnLayout {
                id: decoration
                width: Math.max(0, (parent.width - loginCard.width) / 2 - 48)
                anchors.verticalCenter: parent.verticalCenter
                visible: width >= 220
                spacing: root.compact ? 12 : 22
                Card {
                    implicitWidth: brand.implicitWidth + 40; implicitHeight: 40; radius: 14
                    color: config.Mint
                    Label { id: brand; anchors.centerIn: parent; text: "BLACKMOON"; font.bold: true; font.letterSpacing: 4 }
                }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: clockRow.implicitHeight + (root.compact ? 16 : 30)
                    Rectangle {
                        x: 12; y: parent.height * 0.63
                        width: Math.min(parent.width - 24, clockRow.implicitWidth + 20); height: root.compact ? 22 : 36
                        rotation: -5; radius: 8; color: config.Pink
                        border.width: 2; border.color: config.Ink
                    }
                    Row {
                        id: clockRow; x: 4; spacing: 2
                        Repeater {
                            model: Qt.formatTime(root.now, "hh:mm").split("")
                            ClockGlyph {
                                required property string modelData
                                required property int index
                                glyph: modelData
                                tint: index % 2 ? config.Lavender : config.Mint
                                rotation: index === 2 ? 0 : index % 2 ? 3 : -3
                            }
                        }
                    }
                }
                Card {
                    implicitWidth: dateLabel.implicitWidth + 36; implicitHeight: 42; radius: 15
                    stacked: !root.compact
                    Label { id: dateLabel; anchors.centerIn: parent; text: Qt.formatDate(root.now, "dddd, MMMM d"); font.bold: true }
                }
                Row {
                    visible: !root.compact; spacing: 12; topPadding: 10
                    Repeater {
                        model: [config.Mint, config.Lavender, config.Pink]
                        Rectangle {
                            required property color modelData
                            width: 14; height: 14; rotation: 45; radius: 3
                            color: modelData; border.width: 2; border.color: config.Ink
                        }
                    }
                }
            }
            Card {
                id: loginCard
                stacked: true
                color: "#fcfdfb"
                width: Math.min(420, parent.width)
                x: (parent.width - width) / 2
                implicitHeight: form.implicitHeight + 56
                ColumnLayout {
                    id: form
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 28; spacing: 10
                    Label { text: qsTr("Welcome back"); font.pixelSize: 30; font.bold: true; font.italic: true }
                    Row {
                        Layout.fillWidth: true; height: 8
                        Rectangle { width: parent.width / 3; height: 8; color: config.Mint }
                        Rectangle { width: parent.width / 3; height: 8; color: config.Lavender }
                        Rectangle { width: parent.width / 3; height: 8; color: config.Pink }
                    }
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
}
