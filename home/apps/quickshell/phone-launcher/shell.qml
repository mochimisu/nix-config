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
        earlyInput.clear();
        presentation.suspend();
    }
    function open() {
        presentation.suspend();
        earlyInput.clear();
        opening = true;
        requestSerial++;
        // Map exclusive keyboard input before asynchronous context/media lookup.
        // The phone itself stays hidden until the pointer output is resolved.
        window.visible = true;
        earlyInput.forceActiveFocus();
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
                    const query = earlyInput.text;
                    root.opening = false;
                    presentation.open(query);
                    earlyInput.clear();
                } catch (error) { console.warn("Launcher context:", error); root.hide(); }
            }
        }
        onExited: (code, exitStatus) => {
            if (root.querySerial !== root.requestSerial) Qt.callLater(root.startQuery);
            else if (code !== 0) { root.hide(); console.warn("Launcher context query failed:", code); }
        }
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (root.opening) { root.hide(); return; }
            if (window.visible && !presentation.closing) presentation.finish(null);
            else root.open();
        }
        function close(): void { if (root.opening) root.hide(); else if (window.visible) presentation.finish(null); }
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

        // Local text input only while this launcher owns keyboard focus.
        // TextInput retains normal editing/IME behavior; nothing is recorded.
        TextInput {
            id: earlyInput
            visible: root.opening
            opacity: 0
            focus: root.opening
            Keys.onEscapePressed: root.hide()
            Keys.onPressed: event => {
                // A still-held invocation modifier must not eat the first letters.
                if ((event.modifiers & Qt.MetaModifier) && event.text.length
                        && !/[\x00-\x1f\x7f]/.test(event.text)
                        && !(event.modifiers & Qt.ControlModifier)) {
                    if (event.key !== Qt.Key_Space) insert(cursorPosition, event.text);
                    event.accepted = true;
                }
            }
        }
        Presentation {
            id: presentation
            autoOpen: false
            visible: window.visible && !root.opening
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
