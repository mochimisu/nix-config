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
    readonly property alias phone: phone

    function finish(app) {
        if (closing) return;
        pendingApp = app;
        closing = true;
        opened = false;
        closeTimer.start();
    }
    Component.onCompleted: opened = true
    Timer {
        id: closeTimer
        interval: stage.flat ? 0 : 180
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
        anchors.centerIn: parent
        enabled: !stage.closing
        opacity: stage.flat || stage.opened ? 1 : 0
        scale: stage.flat ? 1 : (stage.opened ? 0.94 : 0.60)
        // Match the reference's almost-parallel long edges. Separate Rotation
        // items each add Qt's short default perspective, exaggerating taper.
        property real yaw: stage.flat ? 0 : -35
        property real pitch: stage.flat ? 0 : 25
        property real roll: stage.flat ? 0 : (stage.opened ? -4 : -84)
        Behavior on roll { NumberAnimation { duration: stage.closing ? 180 : 420; easing.type: Easing.OutCubic } }
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
        Behavior on opacity { NumberAnimation { duration: stage.flat ? 0 : 180 } }
        Behavior on scale { NumberAnimation { duration: stage.flat ? 0 : (stage.closing ? 180 : 420); easing.type: Easing.OutCubic } }
        onDismissed: stage.finish(null)
        onLaunchRequested: app => stage.finish(app)
    }
}
