//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

ShellRoot {
    id: root
    property bool opening: false
    property int requestSerial: 0
    property int querySerial: 0
    function hide() {
        opening = false;
        requestSerial++;
        window.visible = false;
        presentation.suspend();
    }
    function open() {
        opening = true;
        requestSerial++;
        startQuery();
    }
    function startQuery() {
        if (!opening || contextQuery.running) return;
        querySerial = requestSerial;
        contextQuery.running = true;
    }
    Process {
        id: contextQuery
        command: ["@context@"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.opening || root.querySerial !== root.requestSerial) return;
                try {
                    const context = JSON.parse(text);
                    const output = Quickshell.screens.find(s => s.name === context.monitor);
                    if (!output) throw new Error("Pointer output disconnected");
                    status.wallpaper = context.wallpaper;
                    status.wallpaperVideo = context.video;
                    window.screen = output;
                    window.visible = true;
                    presentation.open();
                } catch (error) { console.warn("Launcher context:", error); }
                root.opening = false;
            }
        }
        onExited: (code, exitStatus) => {
            if (root.querySerial !== root.requestSerial) Qt.callLater(root.startQuery);
            else if (code !== 0) { root.opening = false; console.warn("Launcher context query failed:", code); }
        }
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (root.opening) { root.opening = false; root.requestSerial++; return; }
            if (window.visible && !presentation.closing) presentation.finish(null);
            else root.open();
        }
        function close(): void { root.opening = false; root.requestSerial++; if (window.visible) presentation.finish(null); }
        function state(): string { return root.opening ? "opening" : window.visible ? (presentation.closing ? "closing" : "open") : "hidden"; }
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
