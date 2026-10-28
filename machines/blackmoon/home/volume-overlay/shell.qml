import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    readonly property var palette: (@paletteJson@)
    property int value: 0
    property bool muted: false
    property int serial: 0
    IpcHandler {
        target: "volume"
        function show(value: int, muted: bool, output: string, bottom: int): void {
            const screen = Quickshell.screens.find(s => s.name === output);
            if (!screen) return;
            window.screen = screen;
            window.bottomInset = Math.max(0, bottom);
            root.value = Math.max(0, Math.min(150, value));
            root.muted = muted;
            root.serial++;
            window.visible = true;
            fade.stop();
            scene.opacity = 1;
            stars.burst();
            hold.restart();
        }
        function state(): string {
            return JSON.stringify({ visible: window.visible, serial: root.serial,
                value: root.value, muted: root.muted, output: window.screen.name,
                particles: stars.particles.length, bottom: window.margins.bottom });
        }
    }
    Timer { id: hold; interval: 1600; onTriggered: fade.start() }
    NumberAnimation {
        id: fade; target: scene; property: "opacity"; to: 0; duration: 160
        onFinished: { window.visible = false; stars.particles = []; }
    }
    PanelWindow {
        id: window
        visible: false
        property int bottomInset: 0
        screen: Quickshell.screens[0]
        implicitWidth: Math.min(540, screen.width - 24)
        implicitHeight: 230
        anchors.bottom: true
        // Logical pixels: Qt handles output scale and rotation. Card is 38px
        // above the usable edge; lower sparkles stay inside the window.
        margins.bottom: bottomInset + 14
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sekai-volume-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        Item {
            id: scene
            anchors.fill: parent
            Canvas {
                id: stars
                anchors.fill: parent
                property var particles: []
                function burst() {
                    const now = Date.now();
                    const live = particles.filter(p => now - p.born < 760).slice(-48);
                    for (let i = 0; i < 24; i++) {
                        const a = Math.random() * Math.PI * 2;
                        // Emit beyond the card border, keeping text and bar clear.
                        live.push({born: now, x: window.implicitWidth / 2 + Math.cos(a) * (Math.min(304, window.implicitWidth - 100) / 2 + 8),
                            y: window.implicitHeight - 65 + Math.sin(a) * 47,
                            dx: Math.cos(a) * (35 + Math.random() * 50),
                            dy: Math.sin(a) * (20 + Math.random() * 10) - 30,
                            size: 3 + Math.random() * 6, spin: (Math.random() - .5) * 3,
                            color: [root.palette.teal, root.palette.lavender, "#fff3cf"][i % 3]});
                    }
                    particles = live;
                    requestPaint();
                }
                Timer {
                    interval: 16; repeat: true
                    running: window.visible && stars.particles.length > 0
                    onTriggered: {
                        stars.particles = stars.particles.filter(p => Date.now() - p.born < 760);
                        stars.requestPaint();
                    }
                }
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const now = Date.now();
                    for (const p of particles) {
                        const t = Math.min(1, (now - p.born) / 760);
                        const e = 1 - Math.pow(1 - t, 3);
                        ctx.save();
                        ctx.translate(p.x + p.dx * e, p.y + p.dy * e);
                        ctx.rotate(p.spin * t);
                        // Bright arrival followed by a soft twinkle/fade.
                        ctx.globalAlpha = Math.min(1, t * 14) * (1 - t);
                        ctx.fillStyle = p.color;
                        const r = p.size * (.8 + Math.sin(t * Math.PI) * .4);
                        ctx.beginPath();
                        for (let j = 0; j < 8; j++) {
                            const angle = j * Math.PI / 4;
                            const radius = j % 2 ? r * .23 : r;
                            const x = Math.cos(angle) * radius, y = Math.sin(angle) * radius;
                            if (j === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                        }
                        ctx.closePath(); ctx.fill(); ctx.restore();
                    }
                }
            }
            Rectangle {
                id: card
                width: Math.min(304, parent.width - 100); height: 82
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - height - 24
                radius: 19
                color: root.palette.background
                border { width: 2; color: root.palette.teal }
                Rectangle {
                    x: 6; y: 6; width: parent.width - 12; height: parent.height - 12
                    radius: 14; color: "transparent"
                    border { width: 1; color: root.palette.raised }
                }
                Text {
                    x: 22; y: 15
                    text: root.muted ? "Volume · muted" : "Volume · " + root.value + "%"
                    color: root.palette.text
                    font { family: "Montserrat Semi-Bold"; pixelSize: 17 }
                }
                Text {
                    anchors { right: parent.right; rightMargin: 20; top: parent.top; topMargin: 12 }
                    text: "✦"; color: root.palette.lavender; font.pixelSize: 23
                }
                Rectangle {
                    x: 22; y: 51; width: parent.width - 44; height: 7
                    radius: 4; color: root.palette.raised
                    Rectangle {
                        width: parent.width * (root.muted ? 0 : Math.min(100, root.value)) / 100
                        height: parent.height; radius: 4; color: root.palette.teal
                        Behavior on width { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }
}
