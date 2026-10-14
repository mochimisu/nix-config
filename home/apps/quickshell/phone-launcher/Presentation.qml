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
        width: Math.min(392, stage.width - 100)
        height: Math.min(640, stage.height - 100)
        anchors.centerIn: parent
        enabled: !stage.closing
        opacity: stage.flat || stage.opened ? 1 : 0
        scale: stage.flat || stage.opened ? 1 : 0.86
        transform: [
            Rotation {
                origin.x: phone.width / 2; origin.y: phone.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: stage.flat ? 0 : (stage.opened ? -22 : -64)
                Behavior on angle { NumberAnimation { duration: stage.closing ? 180 : 420; easing.type: Easing.OutCubic } }
            },
            Rotation {
                origin.x: phone.width / 2; origin.y: phone.height / 2
                axis { x: 0; y: 0; z: 1 }
                angle: stage.flat ? 0 : (stage.opened ? -5 : 13)
                Behavior on angle { NumberAnimation { duration: stage.closing ? 180 : 420; easing.type: Easing.OutCubic } }
            }
        ]
        Behavior on opacity { NumberAnimation { duration: stage.flat ? 0 : 180 } }
        Behavior on scale { NumberAnimation { duration: stage.flat ? 0 : 420; easing.type: Easing.OutCubic } }
        onDismissed: stage.finish(null)
        onLaunchRequested: app => stage.finish(app)
    }
}
