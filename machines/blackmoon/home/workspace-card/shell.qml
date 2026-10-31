import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

ShellRoot {
    id: root
    readonly property string hostname: @hostnameJson@
    readonly property var palette: (@paletteJson@)
    property bool ready: false
    // Ignore initial IPC hydration and output discovery.
    Timer { interval: 800; running: true; onTriggered: root.ready = true }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: window
            required property var modelData
            screen: modelData
            readonly property var monitor: {
                // Track IPC hydration/hotplug as well as the screen object itself.
                const monitors = Hyprland.monitors.values;
                return monitors.find(m => m.name === modelData.name) || null;
            }
            readonly property int workspaceId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
            property int displayedId: 1
            property bool showing: false
            property real entrance: 0
            property real visibility: 0
            property real sparkle: 0
            property real lift: 1
            onWorkspaceIdChanged: {
                if (root.ready && workspaceId > 0) showCard(workspaceId);
            }
            function showCard(number) {
                displayedId = number;
                exitAnimation.stop();
                entranceAnimation.stop();
                sparkleAnimation.stop();
                shadowAnimation.stop();
                showing = true;
                entrance = 0;
                visibility = 1;
                sparkle = 0;
                lift = 1;
                entranceAnimation.start();
                sparkleAnimation.start();
                shadowAnimation.start();
                hold.restart();
            }
            // Kept mapped only while animating. Empty input region never steals clicks.
            visible: showing
            color: "transparent"
            implicitWidth: Math.min(440, Math.max(160, modelData.width - 60))
            implicitHeight: 140
            anchors { top: true; left: true }
            margins { top: 30; left: 30 }
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "sekai-workspace-card"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            NumberAnimation { id: entranceAnimation; target: window; property: "entrance"; to: 1; duration: 230; easing.type: Easing.OutCubic }
            NumberAnimation { id: sparkleAnimation; target: window; property: "sparkle"; to: 1; duration: 720; easing.type: Easing.OutCubic }
            NumberAnimation { id: shadowAnimation; target: window; property: "lift"; to: 0; duration: 380; easing.type: Easing.OutCubic }
            Timer { id: hold; interval: 850; onTriggered: exitAnimation.start() }
            NumberAnimation {
                id: exitAnimation; target: window; property: "visibility"; to: 0; duration: 170; easing.type: Easing.InQuad
                onFinished: window.showing = false
            }
            Item {
                id: card
                x: 28 - 24 * (1 - window.entrance) + 10 * (1 - window.visibility)
                y: 24 - 8 * (1 - window.entrance)
                width: label.implicitWidth + 76
                height: 70
                opacity: window.entrance * window.visibility
                transformOrigin: Item.TopLeft
                scale: Math.min(1, (window.width - 65) / width) * (0.96 + window.entrance * 0.04)
                rotation: -1.5 * (1 - window.entrance)
                Rectangle {
                    x: 5 + 5 * window.lift; y: 7 + 10 * window.lift + 5 * (1 - window.visibility)
                    width: parent.width + 8 * window.lift; height: parent.height + 5 * window.lift
                    radius: 17 + 4 * window.lift; color: root.palette.shadow
                    opacity: 0.11 + 0.07 * (1 - window.lift)
                }
                Rectangle { x: -6; y: 6; width: parent.width; height: parent.height; radius: 16; color: root.palette.lavender; border.width: 1; border.color: root.palette.lavenderEdge; rotation: -2 }
                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: root.palette.surface
                    border { width: 1; color: root.palette.ink }
                    Rectangle { anchors.fill: parent; anchors.margins: 4; radius: 12; color: "transparent"; border { width: 1; color: "white" } }
                    Rectangle { x: 0; y: 19; width: 4; height: 32; radius: 2; color: root.palette.teal }
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: root.hostname + " // " + String(window.displayedId).padStart(2, "0")
                        font { family: "Montserrat"; pixelSize: 22; weight: Font.DemiBold; letterSpacing: 1.1 }
                        color: root.palette.ink
                    }
                    Rectangle { x: 25; y: parent.height - 11; width: (parent.width - 50) * window.entrance; height: 2; radius: 1; color: root.palette.mint }
                }
                // A single pearl sparkle, offset from the lettering.
                Text {
                    x: parent.width - 5; y: -13 - 5 * (1 - window.sparkle)
                    text: "✦"; font.pixelSize: 27; color: root.palette.teal
                    rotation: -45 + 65 * window.sparkle
                    scale: 0.5 + 0.5 * window.sparkle + 0.24 * Math.sin(window.sparkle * Math.PI)
                    opacity: 0.65 + 0.35 * Math.sin(window.sparkle * Math.PI)
                }
                Text {
                    readonly property real twinkle: Math.max(0, (window.sparkle - 0.22) / 0.78)
                    x: parent.width + 13; y: 11 + 5 * (1 - twinkle)
                    text: "✦"; font.pixelSize: 12; color: root.palette.lavenderEdge
                    rotation: 35 - 55 * twinkle
                    scale: 0.2 + 0.8 * twinkle + 0.35 * Math.sin(twinkle * Math.PI)
                    opacity: twinkle * (0.75 + 0.25 * Math.sin(twinkle * Math.PI))
                }
            }
        }
    }
}
