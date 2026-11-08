"""Render the real greeter with fake SDDM calls and a real optional Qt keyboard."""
import json


def greeter(repo, fixtures, width, height, keyboard, output):
    source = (repo/'system/desktop-style/sddm/Main.qml').read_text()
    source = source.replace('Rectangle {\n    id: root', f'Window {{\n    id: fixtureWindow\n    visible: true; width: {width}; height: {height}\n    Component.onCompleted: requestActivate()\nRectangle {{\n    id: root', 1) + '\n}'
    source = 'import QtQuick.Window\nimport QtTest\n' + source
    config = dict(Font='Montserrat', HostName='OASIS' if keyboard else 'BLACKMOON',
                  VirtualKeyboardEnabled=str(keyboard).lower(),
                  Ink='#f1f3f3', Muted='#a9bac9', Surface='#102038',
                  Mint='#263f60', Lavender='#0d1c31', Pink='#355374', Urgent='#f0aaaa')
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
            check(Math.abs(loginCard.mapToItem(root, loginCard.width / 2, 0).x - root.width / 2) < 1, "login horizontally centered");
            dialFrames.running = false;
            const geometry = [hourText.x, hourText.width, minuteText.x, minuteText.width, secondText.x, secondText.width, timeReadout.width];
            for (const t of [[0,0,0,0], [9,9,9,250], [11,11,11,500], [23,59,59,999], [0,0,0,0]]) {
                root.now = new Date(2026, 10, 7, t[0], t[1], t[2], t[3]);
                const seconds = t[2] + t[3] / 1000;
                const minutes = t[1] + seconds / 60;
                const values = [t[0] + minutes / 60, minutes, seconds];
                for (let i=0; i<3; i++) {
                    const ring = timeRings.itemAt(i);
                    check(Math.abs(ring.value - values[i]) < .000001, "wheel follows fractional wall time");
                    check(Math.abs(ring.rotation + values[i] * 360 / ring.divisions - 90) < .000001, "wheel phase matches time");
                    if (i) check(ring.radius > timeRings.itemAt(i-1).radius, "hour minute second inner to outer");
                }
                check(JSON.stringify(geometry) === JSON.stringify([hourText.x, hourText.width, minuteText.x, minuteText.width, secondText.x, secondText.width, timeReadout.width]), "stable readout across digit changes and midnight");
            }
            // Equal 100 ms steps straddling midnight must advance every ring
            // by the same angle, including the wrap, without a stationary tick.
            let previous = null;
            const speeds = [360 / 86400, 360 / 3600, 360 / 60];
            for (let ms=0; ms<=1200; ms+=100) {
                root.now = new Date(2026, 10, 7, 23, 59, 59, ms);
                const angles = [0,1,2].map(i => timeRings.itemAt(i).rotation);
                if (previous) for (let i=0; i<3; i++) {
                    const step = ((previous[i] - angles[i]) % 360 + 360) % 360;
                    check(Math.abs(step - speeds[i] * .1) < .000001, "constant nonzero speed across midnight");
                }
                previous = angles;
            }
            dialFrames.running = true;
            wait(100);
            const frameTime = root.now.getTime();
            wait(100);
            check(root.now.getTime() > frameTime, "frame clock advances between second ticks");
            dialFrames.running = false;
            root.now = new Date(2026, 10, 7, 18, 15, 37);

            root.message = "";
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
