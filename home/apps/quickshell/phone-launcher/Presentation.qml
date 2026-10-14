import QtQuick
import Quickshell

Item {
    id: stage
    signal dismissed()
    signal launchRequested(var app)
    // Explicit opt-out for motion sensitivity and simpler renderers.
    property bool flat: Quickshell.env("SEKAI_LAUNCHER_FLAT") === "1"
    property bool opened: false
    property bool closing: false
    property var pendingApp: null
    readonly property bool interactive: opened && !closing && !slide.running
    readonly property real restingTop: (height - phone.height) / 2
    property real travel: opened ? 0 : 1
    Behavior on travel {
        NumberAnimation {
            id: slide
            duration: stage.flat ? 0 : (stage.closing ? 320 : 460)
            easing.type: stage.closing ? Easing.InCubic : Easing.OutCubic
        }
    }
    readonly property alias phone: phone

    function finish(app) {
        if (closing) return;
        pendingApp = app;
        closing = true;
        opened = false;
        closeTimer.start();
    }
    Component.onCompleted: { if (!closing) opened = true; }
    Timer {
        id: closeTimer
        interval: stage.flat ? 0 : 340
        onTriggered: {
            if (stage.pendingApp) stage.launchRequested(stage.pendingApp);
            else stage.dismissed();
        }
    }
    Phone {
        id: phone
        objectName: "phone"
        depth: !stage.flat
        width: Math.min(356, stage.width - 100)
        height: Math.min(640, stage.height - 100)
        x: (stage.width - width) / 2
        y: stage.restingTop + (stage.flat ? 0 : stage.travel * (stage.height + height / 4 - stage.restingTop))
        interactive: stage.interactive
        opacity: 1
        scale: stage.flat ? 1 : 0.94
        // Match the reference's almost-parallel long edges. Separate Rotation
        // items each add Qt's short default perspective, exaggerating taper.
        property real yaw: stage.flat ? 0 : -35
        property real pitch: stage.flat ? 0 : 25
        property real roll: stage.flat ? 0 : (-4 - stage.travel * 7)
        transform: Matrix4x4 {
            matrix: {
                const y = phone.yaw * Math.PI / 180;
                const p = phone.pitch * Math.PI / 180;
                const r = phone.roll * Math.PI / 180;
                const cy = Math.cos(y), sy = Math.sin(y);
                const cp = Math.cos(p), sp = Math.sin(p);
                const cr = Math.cos(r), sr = Math.sin(r);
                const a = cr * cy, b = sr * cy;
                const c = cr * sy * sp - sr * cp;
                const d = sr * sy * sp + cr * cp;
                const g = -sy, h = cy * sp;
                const cx = phone.width / 2, centerY = phone.height / 2;
                const focal = 5000;
                const u = -g / focal, v = -h / focal;
                const aa = a + cx * u, cc = c + cx * v;
                const bb = b + centerY * u, dd = d + centerY * v;
                return Qt.matrix4x4(
                    aa, cc, 0, cx - aa * cx - cc * centerY,
                    bb, dd, 0, centerY - bb * cx - dd * centerY,
                    0, 0, 1, 0,
                    u, v, 0, 1 - u * cx - v * centerY);
            }
        }
        onDismissed: stage.finish(null)
        onLaunchRequested: app => stage.finish(app)
    }
}
