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
        implicitWidth: Math.min(392, (screen?.width ?? 392) - 32)
        implicitHeight: Math.min(640, (screen?.height ?? 640) - 48)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sekai-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Phone {
            anchors.fill: parent
            onDismissed: Qt.quit()
            onLaunchRequested: app => {
                app.execute();
                Qt.quit();
            }
        }
    }
}
