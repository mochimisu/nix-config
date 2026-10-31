"""Render the real greeter with fake SDDM calls and a real optional Qt keyboard."""
import json


def greeter(repo, fixtures, width, height, keyboard, output):
    source = (repo/'system/desktop-style/sddm/Main.qml').read_text()
    source = source.replace('Rectangle {\n    id: root', f'Window {{\n    id: fixtureWindow\n    visible: true; width: {width}; height: {height}\n    Component.onCompleted: requestActivate()\nRectangle {{\n    id: root', 1) + '\n}'
    source = 'import QtQuick.Window\nimport QtTest\n' + source
    palette = json.loads((repo/'home/theme/sekai-palette.json').read_text())
    config = {k.capitalize():v for k,v in palette.items()}
    config.update(Font='Montserrat', HostName='OASIS' if keyboard else 'BLACKMOON', VirtualKeyboardEnabled=str(keyboard).lower())
    checks = '''
    property var config: (@config@)
    property var userModel: ListModel {
        property string lastUser: "fixture-user"
        property int lastIndex: 0
        ListElement { name: "fixture-user" }
        ListElement { name: "second-user" }
    }
    property var sessionModel: ListModel {
        property int lastIndex: 0
        ListElement { name: "Hyprland (uwsm-managed)" }
        ListElement { name: "Hyprland" }
    }
    property var keyboard: QtObject {
        property bool capsLock: false
        property int currentLayout: 0
        property var layouts: [{longName:"English (US)"},{longName:"Dvorak"}]
    }
    property var sddm: QtObject {
        property bool canSuspend: true
        property bool canReboot: true
        property bool canPowerOff: true
        property var calls: []
        signal loginFailed()
        signal loginSucceeded()
        signal informationMessage(string message)
        function login(user, password, session) { calls.push([user, password, session]); }
        function suspend() { calls.push("suspend"); }
        function reboot() { calls.push("reboot"); }
        function powerOff() { calls.push("poweroff"); }
    }
    TestCase {
        id: tests; when: false
        function check(ok, label) { if (!ok) throw new Error("ASSERT " + label); }
        function runChecks() {
            check(root.loginUser === "fixture-user", "remembered account");
            password.text="fixture-only"; sessions.currentIndex=1; root.login();
            check(sddm.calls.length===1 && sddm.calls[0][0]==="fixture-user" && sddm.calls[0][2]===1,"selected account/session passed");
            root.login(); check(sddm.calls.length===1,"duplicate login blocked");
            sddm.loginFailed(); check(!root.busy && password.text==="" && root.message!=="","failure clears password and restores input");
            layouts.currentIndex=1; layouts.activated(1); check(keyboard.currentLayout===1,"layout selection");
            if (root.virtualKeyboardEnabled) {
                check(virtualKeyboard.status===Loader.Ready, "real virtual keyboard loaded");
                password.forceActiveFocus(); Qt.inputMethod.show(); wait(500);
                check(virtualKeyboard.item.active && virtualKeyboard.height>100,"keyboard visible and sized: active="+virtualKeyboard.item.active+", height="+virtualKeyboard.height+", focus="+password.activeFocus+", window="+fixtureWindow.active);
                const pt=password.mapToItem(viewport,0,0);
                check(pt.y>=-1 && pt.y+password.height<=viewport.height+1,"password stays above keyboard");
                check(viewport.y+viewport.height<=virtualKeyboard.y,"form does not overlap keyboard");
            } else {
                check(virtualKeyboard.item===null,"keyboard not instantiated on non-touch host");
                sessions.forceActiveFocus(); wait(100);
                const pt=sessions.mapToItem(viewport,0,0);
                check(pt.y>=-1 && pt.y+sessions.height<=viewport.height+1,"focused session visible");
            }
            check(password.height>=40 && sessions.height>=40,"readable controls");
            check(form.width>=200 && form.width<=root.width,"form fits");
            root.grabToImage(r => {
                if (!r.saveToFile("@output@")) { console.error("ASSERT capture"); Qt.exit(1); return; }
                console.log("TESTS PASSED"); Qt.quit();
            });
        }
    }
    Timer { interval:10000; running:true; onTriggered: { console.error("ASSERT greeter watchdog"); Qt.exit(1); } }
    Timer { interval:500; running:true; onTriggered: {
        try { tests.runChecks(); } catch(e) { console.error(e); Qt.exit(1); }
    } }
'''.replace('@config@',json.dumps(config)).replace('@output@',str(output))
    return source.replace('    id: fixtureWindow','    id: fixtureWindow\n'+checks,1).replace('width: 1280; height: 800',f'width: {width}; height: {height}')
