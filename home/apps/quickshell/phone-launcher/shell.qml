//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        id: window
        visible: true
        focusable: true
        // A single panel follows the focused output, in logical (scaled) pixels.
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        implicitWidth: Math.min(560, screen?.width ?? 560)
        // Span the output vertically: motion is clipped only at screen edges.
        anchors { top: true; bottom: true }
        mask: Region {
            x: 0
            y: Math.max(0, presentation.restingTop - 40)
            width: presentation.interactive ? window.width : 0
            height: presentation.phone.height + 80
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sekai-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Presentation {
            id: presentation
            anchors.fill: parent
            onDismissed: Qt.quit()
            onLaunchRequested: app => {
                app.execute();
                Qt.quit();
            }
        }
    }
}
