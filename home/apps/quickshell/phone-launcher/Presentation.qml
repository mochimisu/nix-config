import QtQuick
import Quickshell

Item {
    id: stage
    signal dismissed()
    signal actionRequested(string action)
    property var services: null
    signal launchRequested(var app)
    // Explicit opt-out for motion sensitivity and simpler renderers.
    property bool flat: Quickshell.env("SEKAI_LAUNCHER_FLAT") === "1"
    property bool opened: false
    property bool closing: false
    property bool pointerHeld: false
    property var pendingApp: null
    readonly property bool interactive: opened && !closing && !slide.running
    // Hide the whole lower rounded edge, including its raised far corner.
    // Use the settled projection rather than the untransformed rectangle.
    readonly property real restingTop: height + 8 - Math.min(
        settledY(6, phone.height - 42),
        settledY(phone.width - 6, phone.height - 42))
    function settledY(x, y) {
        if (flat) return y;
        const yaw = -30 * Math.PI / 180, pitch = 18 * Math.PI / 180;
        const roll = -4 * Math.PI / 180;
        const dx = x - phone.width / 2, dy = y - phone.height / 2;
        const b = Math.sin(roll) * Math.cos(yaw);
        const d = Math.sin(roll) * Math.sin(yaw) * Math.sin(pitch)
                + Math.cos(roll) * Math.cos(pitch);
        const z = -Math.sin(yaw) * dx + Math.cos(yaw) * Math.sin(pitch) * dy;
        return phone.height / 2 + 0.94 * (b * dx + d * dy) / (1 - z / 5000);
    }
    property real travel: opened ? 0 : 1
    Behavior on travel {
        NumberAnimation {
            id: slide
            duration: stage.flat ? 0 : (stage.closing ? 180 : 260)
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
        interval: stage.flat ? 0 : 200
        onTriggered: {
            if (stage.pointerHeld) { restart(); return; }
            if (stage.pendingApp && stage.pendingApp.action) stage.actionRequested(stage.pendingApp.action);
            else if (stage.pendingApp) stage.launchRequested(stage.pendingApp);
            else stage.dismissed();
        }
    }
    function roundedContains(point, x, y, width, height, radius) {
        const px = point.x - x, py = point.y - y;
        if (px < 0 || py < 0 || px > width || py > height) return false;
        const dx = Math.max(radius - px, 0, px - (width - radius));
        const dy = Math.max(radius - py, 0, py - (height - radius));
        return dx * dx + dy * dy <= radius * radius;
    }
    function insidePhone(x, y) {
        const point = phone.mapFromItem(stage, x, y);
        return roundedContains(point, 6, 6, phone.width - 12, phone.height - 12, 36)
            || (!flat && roundedContains(point, 28, 17, phone.width - 12, phone.height - 12, 36));
    }
    // Full-output input shield consumes the dismissal press and release.
    // Controls above this layer receive inside clicks normally.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: event => {
            stage.pointerHeld = true;
            if (!stage.insidePhone(event.x, event.y)) stage.finish(null);
            event.accepted = true;
        }
        onReleased: event => { stage.pointerHeld = false; event.accepted = true; }
        onCanceled: stage.pointerHeld = false
        onWheel: event => event.accepted = true
    }
    Phone {
        id: phone
        objectName: "phone"
        depth: !stage.flat
        services: stage.services
        width: Math.min(400, stage.width - 100)
        height: Math.min(720, stage.height - 100)
        // A shallow curved path and linked wrist rotation, not a scale change.
        x: (stage.width - width) / 2 + (stage.flat ? 0 :
            12 * stage.travel - 28 * Math.sin(Math.PI * stage.travel))
        y: stage.restingTop + (stage.flat ? 0 : stage.travel * (stage.height + height / 4 - stage.restingTop))
        interactive: stage.interactive
        opacity: 1
        scale: stage.flat ? 1 : 0.94
        // Match the reference's almost-parallel long edges. Separate Rotation
        // items each add Qt's short default perspective, exaggerating taper.
        property real yaw: stage.flat ? 0 : -30 - 6 * Math.sin(Math.PI * stage.travel)
        property real pitch: stage.flat ? 0 : 18 + 10 * stage.travel
        property real roll: stage.flat ? 0 : -4 - 2 * stage.travel - 8 * Math.sin(Math.PI * stage.travel)
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
        onActionRequested: action => stage.finish({action})
        onDismissed: stage.finish(null)
        onLaunchRequested: app => stage.finish(app)
    }
}
