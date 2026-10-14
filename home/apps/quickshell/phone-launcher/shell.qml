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
        implicitWidth: Math.min(492, (screen?.width ?? 492) - 32)
        implicitHeight: Math.min(740, (screen?.height ?? 740) - 48)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sekai-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Presentation {
            anchors.fill: parent
            onDismissed: Qt.quit()
            onLaunchRequested: app => {
                app.execute();
                Qt.quit();
            }
        }
    }
}
