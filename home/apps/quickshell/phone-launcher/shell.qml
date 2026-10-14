//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

ShellRoot {
    Status { id: status }
    PanelWindow {
        id: window
        visible: true
        focusable: true
        // A single panel follows the focused output, in logical (scaled) pixels.
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        // Full-output input shield prevents the outside click reaching apps.
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sekai-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Presentation {
            id: presentation
            services: status
            onActionRequested: action => {
                window.visible = false;
                const command = action === "network" ? ["nm-connection-editor"]
                    : action === "bluetooth" ? ["blueman-manager"]
                    : action === "capture" ? ["sh", "-c", 'sleep 0.2; exec "$HOME/.config/hypr/screenshot.sh"'] : null;
                if (!command) { Qt.quit(); return; }
                Quickshell.execDetached(command);
                Qt.quit();
            }
            anchors.fill: parent
            onDismissed: Qt.quit()
            onLaunchRequested: app => {
                app.execute();
                Qt.quit();
            }
        }
    }
}
