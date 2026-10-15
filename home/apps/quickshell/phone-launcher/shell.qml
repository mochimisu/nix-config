//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

ShellRoot {
    id: root
    function hide() {
        window.visible = false;
        presentation.suspend();
    }
    function open() {
        window.screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        window.visible = true;
        presentation.open();
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (window.visible && !presentation.closing) presentation.finish(null);
            else root.open();
        }
        function close(): void { if (window.visible) presentation.finish(null); }
        function state(): string { return window.visible ? (presentation.closing ? "closing" : "open") : "hidden"; }
    }
    Status { id: status; active: window.visible }
    PanelWindow {
        id: window
        visible: false
        focusable: visible
        screen: Quickshell.screens[0]
        // Keep the output shield mapped through the outside dismissal release.
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "sekai-launcher"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Presentation {
            id: presentation
            autoOpen: false
            visible: window.visible
            services: status
            anchors.fill: parent
            onActionRequested: action => {
                root.hide();
                const command = action === "network" ? ["nm-connection-editor"]
                    : action === "bluetooth" ? ["blueman-manager"]
                    : action === "capture" ? ["sh", "-c", 'sleep 0.2; exec "$HOME/.config/hypr/screenshot.sh"'] : null;
                if (command) Quickshell.execDetached(command);
            }
            onDismissed: root.hide()
            onLaunchRequested: app => { root.hide(); app.execute(); }
        }
    }
}
