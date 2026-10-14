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
        if (busy || username.text.trim() === "" || sessions.currentIndex < 0) return;
        busy = true;
        message = "";
        sddm.login(username.text, password.text, sessions.currentIndex);
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
    // Quiet native geometry: no image asset, network request or wallpaper dependency.
    Item {
        anchors.fill: parent
        clip: true
        Rectangle {
            width: Math.min(root.width * 0.55, 680); height: width; radius: width / 2
            x: root.width - width * 0.58; y: -height * 0.58
            color: config.Lavender; opacity: 0.55
        }
        Rectangle {
            width: Math.min(root.width * 0.62, 760); height: width; radius: width / 2
            x: -width * 0.5; y: root.height - height * 0.3
            color: config.Mint; opacity: 0.35
        }
        Rectangle {
            visible: !root.compact
            x: root.width * 0.46; y: root.height * 0.32
            width: 1; height: root.height * 0.36
            color: config.Ink; opacity: 0.12
        }
    }

    component Card: Rectangle {
        color: config.Surface; radius: 24; border.width: 2; border.color: config.Ink
        Rectangle { anchors.fill: parent; anchors.margins: 5; radius: 19; color: "transparent"; border.width: 1; border.color: "white" }
    }
    component Label: Text {
        color: config.Ink; font.family: config.Font; font.pixelSize: 14
        renderType: Text.NativeRendering
    }
    component Pill: Button {
        id: button
        onActiveFocusChanged: if (activeFocus) root.reveal(button)
        implicitHeight: 40
        font.family: config.Font; font.pixelSize: 14; font.bold: true
        palette.buttonText: config.Ink
        Accessible.name: text
        background: Rectangle {
            radius: 13; color: button.down ? config.Mint : config.Lavender
            border.width: button.activeFocus ? 3 : 2; border.color: config.Ink
            Rectangle { anchors.fill: parent; anchors.margins: 4; radius: 9; color: "transparent"; border.width: 1; border.color: "white" }
        }
        opacity: enabled ? 1 : 0.55
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
            radius: 12; color: "white"; border.width: entry.activeFocus ? 3 : 1; border.color: config.Ink
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
            radius: 12; color: config.Lavender; border.width: choice.activeFocus ? 3 : 1; border.color: config.Ink
        }
    }

    // Scroll rather than scale controls below comfortable keyboard/touch sizes.
    Flickable {
        id: viewport
        anchors.fill: parent; anchors.margins: root.compact ? 20 : 48
        contentWidth: width; contentHeight: Math.max(height, layout.implicitHeight)
        clip: true; boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        GridLayout {
            id: layout
            width: parent.width
            y: Math.max(0, (parent.height - implicitHeight) / 2)
            columns: root.compact ? 1 : 2
            columnSpacing: 72; rowSpacing: 20
            ColumnLayout {
                Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                spacing: 10
                Label { text: "BLACKMOON"; font.bold: true; font.letterSpacing: 5; color: config.Ink }
                Text {
                    text: Qt.formatTime(root.now, "hh:mm")
                    font.family: config.Font; font.pixelSize: root.compact ? 64 : Math.min(132, root.width / 11)
                    font.bold: true; color: config.Mint; style: Text.Outline; styleColor: config.Ink
                    renderType: Text.CurveRendering
                }
                Card {
                    implicitWidth: dateLabel.implicitWidth + 36; implicitHeight: 42; radius: 15
                    Label { id: dateLabel; anchors.centerIn: parent; text: Qt.formatDate(root.now, "dddd, MMMM d"); font.bold: true }
                }
            }
            Card {
                color: "#fcfdfb"
                Layout.preferredWidth: 420; Layout.maximumWidth: 460
                Layout.fillWidth: true; Layout.alignment: Qt.AlignHCenter
                implicitHeight: form.implicitHeight + 48
                ColumnLayout {
                    id: form
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 24; spacing: 10
                    Label { text: qsTr("Welcome back"); font.pixelSize: 28; font.bold: true; font.italic: true }
                    Row {
                        Layout.fillWidth: true; height: 4
                        Rectangle { width: parent.width / 3; height: 4; color: config.Mint }
                        Rectangle { width: parent.width / 3; height: 4; color: config.Lavender }
                        Rectangle { width: parent.width / 3; height: 4; color: config.Pink }
                    }
                    Label { text: qsTr("Username"); font.bold: true }
                    Entry {
                        id: username; Layout.fillWidth: true; text: userModel.lastUser
                        Accessible.name: qsTr("Username"); enabled: !root.busy
                        KeyNavigation.tab: password
                        onAccepted: password.forceActiveFocus()
                    }
                    Label { text: qsTr("Password"); font.bold: true }
                    Entry {
                        id: password; Layout.fillWidth: true; echoMode: TextInput.Password
                        Accessible.name: qsTr("Password"); enabled: !root.busy
                        KeyNavigation.tab: sessions
                        onAccepted: root.login()
                        Component.onCompleted: forceActiveFocus()
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
                        Layout.fillWidth: true; text: root.busy ? qsTr("Signing in…") : qsTr("Sign in")
                        enabled: !root.busy && username.text.trim() !== "" && sessions.currentIndex >= 0
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
