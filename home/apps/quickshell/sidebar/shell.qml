//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
    id: root

    // ----- Config injected from Nix -----
    property var sidebarScreens: @sidebarScreensJson@
    readonly property string hostName: "@hostName@"
    readonly property bool pttEnabled: "@pttStateFile@" !== ""

    readonly property int iconSize: {
        const parsed = parseInt("@iconSize@", 10);
        return isNaN(parsed) ? 16 : parsed;
    }
    readonly property int fontSizePx: {
        const parsed = parseInt("@fontSize@", 10);
        return isNaN(parsed) ? 13 : parsed;
    }
    // Keep panel width in sync with content scaling from icon/text size.
    readonly property int sidebarWidth: Math.max(20, Math.round(Math.max(iconSize * 1.35, fontSizePx * 1.5)))

    // ----- Derived sizing / style -----
    readonly property color fgColor: "white"
    readonly property color mutedColor: "#a6adc8"
    readonly property color accentColor: "#a6e3a1"
    readonly property color urgentColor: "#f38ba8"
    readonly property var blockedAudioDescriptions: hostName === "blackmoon" ? [
        "AD102 High Definition Audio Controller Digital Stereo (HDMI)",
        "USB Audio Front Headphones",
        "USB Audio Speakers",
        "RZ19-0229 Gaming Microphone Analog Stereo"
    ] : []
    readonly property string baseFont: "Montserrat Bold"
    readonly property int tinyTextPx: Math.max(8, Math.round(fontSizePx * 0.65))
    readonly property int clockMainPx: Math.max(11, Math.round(fontSizePx * 1.2))
    readonly property int dateTextPx: Math.max(7, Math.round(fontSizePx * 0.55))
    readonly property real clockLetterSpacing: -0.6
    readonly property int trayIconPx: Math.max(16, Math.round(iconSize * 1.2))
    readonly property int statusIconPx: Math.max(12, Math.round(Math.max(iconSize, fontSizePx * 1.3)))
    readonly property int cavaTextPx: Math.max(10, Math.round(fontSizePx * 0.8))
    readonly property int batteryIconPx: Math.max(statusIconPx + 4, Math.round(fontSizePx * 1.45))
    readonly property int trayToStatusGapPx: Math.max(4, Math.round(trayIconPx * 0.3))

    // ----- Runtime state -----
    property var workspacesState: ({})
    property var windowState: ({})
    property var networkState: ({"ssid": null, "eth": null})
    property var batteryState: ({"state": "", "percent": 0, "time": "", "rate": ""})
    readonly property int bluetoothCount: (Bluetooth.devices && Bluetooth.devices.values)
        ? Bluetooth.devices.values.length
        : 0
    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property bool defaultSinkReady: defaultSink && defaultSink.audio
    readonly property bool audioMuted: defaultSinkReady ? defaultSink.audio.muted : false
    readonly property int volumePercent: defaultSinkReady ? Math.round(defaultSink.audio.volume * 100) : 0
    property string cavaBars: ""
    property var clockState: ({"hour": "00", "minute": "00", "ampm": "am", "date": "01/01"})
    property string qwertyState: "other"
    property string pttState: "unknown"
    property var toastNotifications: []
    property int notificationSerial: 0
    readonly property int notificationCount: notificationServer.trackedNotifications && notificationServer.trackedNotifications.values
        ? notificationServer.trackedNotifications.values.length
        : 0

    // ----- Helpers -----
    function parseJsonLine(data, fallback) {
        try {
            return JSON.parse(String(data));
        } catch (_) {
            return fallback;
        }
    }

    function parseIntegerLine(data, fallback) {
        const parsed = parseInt(String(data).trim(), 10);
        return isNaN(parsed) ? fallback : parsed;
    }

    function screenIndex(screen) {
        for (let i = 0; i < Quickshell.screens.length; i += 1) {
            if (Quickshell.screens[i] === screen) {
                return i;
            }
        }

        return -1;
    }

    function isScreenEnabled(screenName, screenIdx) {
        if (!Array.isArray(sidebarScreens) || sidebarScreens.length === 0) {
            return true;
        }

        const name = String(screenName);
        const index = String(screenIdx);
        return sidebarScreens.indexOf(name) !== -1 || sidebarScreens.indexOf(index) !== -1;
    }

    function isPrimarySidebarScreen(screenName, screenIdx) {
        if (!Array.isArray(sidebarScreens) || sidebarScreens.length === 0) {
            return screenIdx === 0;
        }

        const preferred = String(sidebarScreens[0]);
        return preferred === String(screenName) || preferred === String(screenIdx);
    }

    function monitorWorkspaces(screenName) {
        const monitor = workspacesState[screenName];
        if (!monitor || !Array.isArray(monitor.workspaces)) {
            return [];
        }

        const copy = monitor.workspaces.slice();
        copy.sort(function(a, b) {
            return (a.id || 0) - (b.id || 0);
        });
        return copy;
    }

    function activeWindowTitle(screenName) {
        const monitor = windowState[screenName];
        if (!monitor || !monitor.title) {
            return "";
        }

        return String(monitor.title);
    }

    function dispatchWorkspace(workspace) {
        if (!workspace || workspace.id === undefined || workspace.id === null) {
            return;
        }

        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(workspace.id)]);
    }

    function isAudioSink(node) {
        return !!node && !!node.audio && !!node.isSink && !node.isStream;
    }

    function sinkLabel(node) {
        if (!node) {
            return "No output";
        }

        return String(node.description || node.nickname || node.name || "Audio output");
    }

    function isBlockedAudioSink(node) {
        const label = sinkLabel(node);
        return blockedAudioDescriptions.indexOf(label) !== -1;
    }

    function setDefaultSink(node) {
        if (!isAudioSink(node)) {
            return;
        }

        Pipewire.preferredDefaultAudioSink = node;
    }

    function setVolumePercent(percent) {
        if (!defaultSinkReady) {
            return;
        }

        const clamped = Math.max(0, Math.min(150, percent));
        defaultSink.audio.volume = clamped / 100;
    }

    function adjustVolume(delta) {
        setVolumePercent(volumePercent + delta);
    }

    function toggleMute() {
        if (!defaultSinkReady) {
            return;
        }

        defaultSink.audio.muted = !defaultSink.audio.muted;
    }

    function powerProfileLabel() {
        if (PowerProfiles.profile === PowerProfile.Performance) {
            return "performance";
        }

        if (PowerProfiles.profile === PowerProfile.PowerSaver) {
            return "powersave";
        }

        return "balanced";
    }

    function powerProfileGlyph() {
        if (PowerProfiles.profile === PowerProfile.Performance) {
            return "PERF";
        }

        if (PowerProfiles.profile === PowerProfile.PowerSaver) {
            return "SAVE";
        }

        return "BAL";
    }

    function setPowerProfile(profile) {
        if (profile === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile) {
            return;
        }

        PowerProfiles.profile = profile;
    }

    function cyclePowerProfile() {
        if (PowerProfiles.profile === PowerProfile.PowerSaver) {
            setPowerProfile(PowerProfile.Balanced);
        } else if (PowerProfiles.profile === PowerProfile.Balanced && PowerProfiles.hasPerformanceProfile) {
            setPowerProfile(PowerProfile.Performance);
        } else {
            setPowerProfile(PowerProfile.PowerSaver);
        }
    }

    function adjustBrightness(delta) {
        const op = delta > 0 ? "5%+" : "5%-";
        Quickshell.execDetached(["brightnessctl", "set", op]);
    }

    function toggleWifi() {
        if (!Networking.wifiHardwareEnabled) {
            return;
        }

        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function lockSession() {
        controlCenterPopup.visible = false;
        Quickshell.execDetached(["hyprlock"]);
    }

    function suspendSession() {
        controlCenterPopup.visible = false;
        Quickshell.execDetached(["sh", "-lc", "pidof hyprlock >/dev/null 2>&1 || hyprlock & sleep 0.3; systemctl suspend"]);
    }

    function notificationSummary(notification) {
        if (!notification) {
            return "";
        }

        return String(notification.summary || notification.appName || "Notification");
    }

    function notificationBody(notification) {
        if (!notification) {
            return "";
        }

        return String(notification.body || "").replace(/<[^>]*>/g, "");
    }

    function notificationAccent(notification) {
        if (notification && notification.urgency === NotificationUrgency.Critical) {
            return urgentColor;
        }

        return fgColor;
    }

    function pushToastNotification(notification) {
        const now = Date.now();
        root.notificationSerial += 1;
        const next = [{
            "notification": notification,
            "serial": root.notificationSerial,
            "expiresAt": now + 5500
        }];

        for (let i = 0; i < root.toastNotifications.length && next.length < 5; i += 1) {
            const entry = root.toastNotifications[i];
            if (entry && entry.notification && entry.expiresAt > now) {
                next.push(entry);
            }
        }

        root.toastNotifications = next;
    }

    function pruneToastNotifications() {
        const now = Date.now();
        root.toastNotifications = root.toastNotifications.filter(function(entry) {
            return entry && entry.notification && entry.expiresAt > now;
        });
    }

    function removeToastNotification(serial) {
        root.toastNotifications = root.toastNotifications.filter(function(entry) {
            return entry && entry.serial !== serial;
        });
    }

    function activateNotification(notification) {
        if (!notification) {
            return;
        }

        const actions = notification.actions || [];
        let action = null;
        for (let i = 0; i < actions.length; i += 1) {
            if (actions[i].identifier === "default") {
                action = actions[i];
                break;
            }
        }

        if (!action && actions.length > 0) {
            action = actions[0];
        }

        if (action) {
            action.invoke();
        }

        notification.dismiss();
    }

    function trayIconSource(rawIcon) {
        const iconRaw = String(rawIcon || "");
        if (iconRaw === "") {
            return "image://icon/image-missing";
        }

        // App-specific tray fallbacks.
        if (iconRaw.indexOf("image://icon/nm-device-wired") === 0) {
            return "image://icon/nm-device-wired?fallback=network-wired";
        }

        if (iconRaw.indexOf("image://icon/blueman-tray") === 0) {
            return "image://icon/blueman-tray?fallback=bluetooth-active";
        }

        return iconRaw;
    }

    function networkIconGlyph() {
        if (networkState.eth) {
            return "";
        }

        if (networkState.ssid) {
            return "";
        }

        return "";
    }

    function batteryIcon() {
        const state = String(batteryState.state || "");
        const percent = parseInt(batteryState.percent, 10);
        const p = isNaN(percent) ? 0 : percent;

        if (state === "charging") {
            if (p < 10) return "󰢟";
            if (p < 20) return "󰢜";
            if (p < 30) return "󰂆";
            if (p < 40) return "󰂇";
            if (p < 50) return "󰂈";
            if (p < 60) return "󰢝";
            if (p < 70) return "󰂉";
            if (p < 80) return "󰢞";
            if (p < 90) return "󰂊";
            if (p < 100) return "󰂋";
            return "󱐋";
        }

        if (state === "discharging" || state === "pending-discharge") {
            if (p < 10) return "󰂎";
            if (p < 20) return "󰁺";
            if (p < 30) return "󰁻";
            if (p < 40) return "󰁼";
            if (p < 50) return "󰁽";
            if (p < 60) return "󰁾";
            if (p < 70) return "󰁿";
            if (p < 80) return "󰂀";
            if (p < 90) return "󰂁";
            if (p < 100) return "󰂂";
            if (p === 100) return "󰁹";
            return "󰂃";
        }

        if (state === "fully-charged" || state === "pending-charge") {
            return "󱟢";
        }

        if (state === "empty") {
            return "󱃍";
        }

        return "󱉝";
    }

    function openTrayMenu(item, trayItem, panelWindow, panelRoot) {
        if (!trayItem.hasNativeMenu) {
            return false;
        }

        const menuPoint = trayItem.mapToItem(panelRoot, trayItem.width, Math.round(trayItem.height / 2));
        item.display(panelWindow, Math.round(menuPoint.x), Math.round(menuPoint.y));
        return true;
    }

    PwObjectTracker {
        objects: root.defaultSink ? [root.defaultSink] : []
    }

    NotificationServer {
        id: notificationServer

        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        persistenceSupported: true
        keepOnReload: true

        onNotification: function(notification) {
            notification.tracked = true;
            root.pushToastNotification(notification);
        }
    }

    Timer {
        id: notificationToastPruneTimer

        running: root.toastNotifications.length > 0
        interval: 1000
        repeat: true
        onTriggered: root.pruneToastNotifications()
    }

    // ----- Data feeds -----
    Process {
        running: true
        command: ["@workspacesBin@"]
        stdout: SplitParser {
            onRead: function(data) {
                root.workspacesState = root.parseJsonLine(data, root.workspacesState);
            }
        }
    }

    Process {
        running: true
        command: ["@windowsBin@"]
        stdout: SplitParser {
            onRead: function(data) {
                root.windowState = root.parseJsonLine(data, root.windowState);
            }
        }
    }

    Process {
        running: true
        command: ["@networkBin@"]
        stdout: SplitParser {
            onRead: function(data) {
                root.networkState = root.parseJsonLine(data, root.networkState);
            }
        }
    }

    Process {
        running: true
        command: ["@batteryBin@"]
        stdout: SplitParser {
            onRead: function(data) {
                root.batteryState = root.parseJsonLine(data, root.batteryState);
            }
        }
    }

    Process {
        running: true
        command: ["@cavaBin@"]
        stdout: SplitParser {
            onRead: function(data) {
                root.cavaBars = String(data).trim();
            }
        }
    }

    Process {
        running: true
        command: ["@clockBin@"]
        stdout: SplitParser {
            onRead: function(data) {
                root.clockState = root.parseJsonLine(data, root.clockState);
            }
        }
    }

    Process {
        running: true
        command: ["@qwertyWatchBin@"]
        stdout: SplitParser {
            onRead: function(data) {
                root.qwertyState = String(data).trim();
            }
        }
    }

    Process {
        running: root.pttEnabled
        command: ["@pttWatchBin@"]
        stdout: SplitParser {
            onRead: function(data) {
                root.pttState = String(data).trim();
            }
        }
    }

    // ----- UI -----
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel

            required property ShellScreen modelData

            readonly property int monitorIndex: root.screenIndex(modelData)
            readonly property bool enabledForScreen: root.isScreenEnabled(modelData.name, monitorIndex)

            screen: modelData
            visible: enabledForScreen
            color: "transparent"
            implicitWidth: root.sidebarWidth
            anchors {
                top: true
                bottom: true
                right: true
            }
            exclusiveZone: root.sidebarWidth
            focusable: false
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell-sidebar"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                id: contentRoot
                anchors.fill: parent
                color: "transparent"

                readonly property string monitorName: panel.modelData.name
                readonly property var monitorWorkspaces: root.monitorWorkspaces(monitorName)
                readonly property string monitorWindowTitle: root.activeWindowTitle(monitorName)

                Column {
                    anchors.fill: parent
                    spacing: 0

                    // --- Top: workspaces ---
                    Column {
                        id: topSection
                        width: parent.width
                        spacing: 2

                        Repeater {
                            model: contentRoot.monitorWorkspaces

                            Item {
                                required property var modelData

                                width: topSection.width
                                height: 18

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width - 4
                                    height: parent.height - 2
                                    radius: 3
                                    color: modelData.urgent ? "#33f38ba8" : "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.urgent ? ("!" + modelData.name + "!") : (modelData.active ? ("-" + modelData.name + "-") : String(modelData.name))
                                    color: modelData.urgent ? root.urgentColor : root.fgColor
                                    font.family: root.baseFont
                                    font.pixelSize: Math.max(8, root.fontSizePx - 2)
                                    font.bold: !!modelData.active || !!modelData.urgent
                                    renderType: Text.NativeRendering
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.AllButtons
                                    onClicked: {
                                        root.dispatchWorkspace(modelData);
                                    }
                                }
                            }
                        }
                    }

                    // --- Center: active window title ---
                    Item {
                        id: centerSection
                        width: parent.width
                        height: Math.max(0, contentRoot.height - topSection.implicitHeight - bottomSection.implicitHeight)

                        Text {
                            anchors.centerIn: parent
                            width: centerSection.height
                            text: contentRoot.monitorWindowTitle
                            color: root.fgColor
                            font.family: root.baseFont
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            rotation: 90
                            horizontalAlignment: Text.AlignHCenter
                            renderType: Text.NativeRendering
                        }
                    }

                    // --- Bottom: status blocks ---
                    Column {
                        id: bottomSection
                        width: parent.width
                        spacing: 6

                        // System tray
                        Column {
                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: SystemTray.items

                                Item {
                                    id: trayItem
                                    required property var modelData

                                    readonly property bool hasNativeMenu: !!modelData && !!modelData.hasMenu
                                    property bool longPressTriggered: false

                                    width: bottomSection.width
                                    height: root.trayIconPx + 4

                                    IconImage {
                                        anchors.centerIn: parent
                                        implicitSize: root.trayIconPx
                                        source: root.trayIconSource(modelData.icon)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.AllButtons
                                        pressAndHoldInterval: 400

                                        onClicked: function(mouse) {
                                            if (trayItem.longPressTriggered) {
                                                trayItem.longPressTriggered = false;
                                                return;
                                            }

                                            if (mouse.button === Qt.LeftButton) {
                                                if (modelData.onlyMenu) {
                                                    if (!root.openTrayMenu(modelData, trayItem, panel, contentRoot)) {
                                                        modelData.activate();
                                                    }
                                                } else {
                                                    modelData.activate();
                                                }
                                            } else if (mouse.button === Qt.RightButton) {
                                                if (!root.openTrayMenu(modelData, trayItem, panel, contentRoot)) {
                                                    modelData.secondaryActivate();
                                                }
                                            } else if (mouse.button === Qt.MiddleButton) {
                                                modelData.secondaryActivate();
                                            }
                                        }

                                        onPressAndHold: {
                                            trayItem.longPressTriggered = true;
                                            if (!root.openTrayMenu(modelData, trayItem, panel, contentRoot)) {
                                                modelData.secondaryActivate();
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Gap between tray items and status icons.
                        Item {
                            width: parent.width
                            height: root.trayToStatusGapPx
                        }

                        // Bluetooth icon + count
                        Item {
                            width: parent.width
                            height: 24

                            Column {
                                anchors.centerIn: parent
                                spacing: -2

                                Text {
                                    text: ""
                                    color: root.fgColor
                                    font.family: "Font Awesome 7 Brands"
                                    font.pixelSize: root.statusIconPx
                                    horizontalAlignment: Text.AlignHCenter
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: String(root.bluetoothCount)
                                    color: root.fgColor
                                    font.family: root.baseFont
                                    font.pixelSize: 9
                                    horizontalAlignment: Text.AlignHCenter
                                    renderType: Text.NativeRendering
                                }
                            }
                        }

                        // Network
                        Text {
                            width: parent.width
                            text: root.networkIconGlyph()
                            color: root.fgColor
                            font.family: "Font Awesome 7 Free Solid"
                            font.pixelSize: root.statusIconPx
                            horizontalAlignment: Text.AlignHCenter
                            renderType: Text.NativeRendering
                        }

                        // Volume + cava
                        Item {
                            width: parent.width
                            height: 32

                            Column {
                                anchors.centerIn: parent
                                width: parent.width
                                spacing: -1

                                Item {
                                    width: parent.width
                                    height: root.cavaTextPx
                                    clip: true

                                    Text {
                                        id: cavaText
                                        text: root.cavaBars
                                        color: root.fgColor
                                        font.family: "monospace"
                                        font.pixelSize: root.cavaTextPx
                                        renderType: Text.NativeRendering
                                        x: Math.round((parent.width - (cavaText.implicitWidth * 0.16)) / 2)

                                        transform: Scale {
                                            xScale: 0.16
                                            yScale: 1.0
                                            origin.x: 0
                                            origin.y: cavaText.height / 2
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: root.audioMuted ? "MUTE" : (String(root.volumePercent) + "%")
                                    color: root.audioMuted ? root.mutedColor : root.fgColor
                                    font.family: root.baseFont
                                    font.pixelSize: 9
                                    horizontalAlignment: Text.AlignHCenter
                                    renderType: Text.NativeRendering
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.AllButtons
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        root.toggleMute();
                                    } else {
                                        audioPopup.visible = !audioPopup.visible;
                                    }
                                }
                                onWheel: function(wheel) {
                                    root.adjustVolume(wheel.angleDelta.y > 0 ? 5 : -5);
                                }
                            }
                        }

                        // PTT
                        Item {
                            visible: root.pttEnabled && root.pttState === "enabled"
                            width: parent.width
                            height: visible ? 24 : 0

                            Column {
                                anchors.centerIn: parent
                                spacing: -2

                                Text {
                                    text: "󰍬"
                                    color: "#a6e3a1"
                                    font.family: root.baseFont
                                    font.pixelSize: 9
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    text: "PTT"
                                    color: "#a6e3a1"
                                    font.family: root.baseFont
                                    font.pixelSize: 8
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        // Keyboard mode
                        Item {
                            visible: root.qwertyState === "qwerty"
                            width: parent.width
                            height: visible ? 24 : 0

                            Column {
                                anchors.centerIn: parent
                                spacing: -2

                                Text {
                                    text: "KEY"
                                    color: "#a6e3a1"
                                    font.family: root.baseFont
                                    font.pixelSize: 8
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    text: "QWER"
                                    color: "#a6e3a1"
                                    font.family: root.baseFont
                                    font.pixelSize: 8
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        // Battery
                        Item {
                            visible: String(root.batteryState.state || "") !== ""
                            width: parent.width
                            height: visible ? Math.max(28, root.batteryIconPx + root.tinyTextPx) : 0

                            Column {
                                anchors.centerIn: parent
                                spacing: -2

                                Text {
                                    text: root.batteryIcon()
                                    color: root.fgColor
                                    font.family: root.baseFont
                                    font.pixelSize: root.batteryIconPx
                                    rotation: -90
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    text: String(root.batteryState.percent || 0) + "%"
                                    color: root.fgColor
                                    font.family: root.baseFont
                                    font.pixelSize: 8
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        // Notifications
                        Item {
                            visible: root.notificationCount > 0
                            width: parent.width
                            height: visible ? 24 : 0

                            Column {
                                anchors.centerIn: parent
                                spacing: -2

                                Text {
                                    text: ""
                                    color: root.toastNotifications.length > 0 ? root.accentColor : root.fgColor
                                    font.family: "Font Awesome 7 Free Solid"
                                    font.pixelSize: root.statusIconPx
                                    horizontalAlignment: Text.AlignHCenter
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    text: String(root.notificationCount)
                                    color: root.fgColor
                                    font.family: root.baseFont
                                    font.pixelSize: 8
                                    horizontalAlignment: Text.AlignHCenter
                                    renderType: Text.NativeRendering
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    controlCenterPopup.visible = !controlCenterPopup.visible;
                                }
                            }
                        }

                        // Clock
                        Item {
                            id: clockBlock

                            width: parent.width
                            height: clockColumn.implicitHeight

                            Column {
                                id: clockColumn

                                width: parent.width
                                spacing: -2

                                Text {
                                    width: parent.width
                                    text: String(root.clockState.hour || "00")
                                    color: root.fgColor
                                    font.family: root.baseFont
                                    font.pixelSize: root.clockMainPx
                                    font.letterSpacing: root.clockLetterSpacing
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    width: parent.width
                                    text: String(root.clockState.minute || "00")
                                    color: root.fgColor
                                    font.family: root.baseFont
                                    font.pixelSize: root.clockMainPx
                                    font.letterSpacing: root.clockLetterSpacing
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    renderType: Text.NativeRendering
                                }

                                Text {
                                    width: parent.width
                                    text: String(root.clockState.ampm || "am")
                                    color: root.fgColor
                                    font.family: root.baseFont
                                    font.pixelSize: root.tinyTextPx
                                    horizontalAlignment: Text.AlignRight
                                }

                                Text {
                                    width: parent.width
                                    text: String(root.clockState.date || "01/01")
                                    color: root.fgColor
                                    font.family: root.baseFont
                                    font.pixelSize: root.dateTextPx
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    controlCenterPopup.visible = !controlCenterPopup.visible;
                                }
                            }
                        }
                    }
                }

                // Audio output popup
                PopupWindow {
                    id: audioPopup

                    visible: false
                    color: "transparent"
                    implicitWidth: 260
                    implicitHeight: Math.max(40, sinksColumn.implicitHeight + 10)

                    anchor {
                        window: panel
                        rect.x: -audioPopup.implicitWidth - 8
                        rect.y: panel.height - audioPopup.implicitHeight - 8
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: "#99000000"
                        border.width: 1
                        border.color: "#80ffffff"

                        Column {
                            id: sinksColumn
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 2

                            Repeater {
                                model: Pipewire.nodes

                                Rectangle {
                                    required property var modelData
                                    id: audioSinkRow

                                    readonly property bool audioOutput: root.isAudioSink(modelData) && !root.isBlockedAudioSink(modelData)
                                    readonly property bool isDefaultOutput: root.defaultSink && modelData && root.defaultSink.id === modelData.id
                                    property bool hovered: false

                                    width: sinksColumn.width
                                    height: audioOutput ? 24 : 0
                                    radius: 4
                                    visible: audioOutput
                                    color: isDefaultOutput ? "#33ffffff" : (hovered ? "#22ffffff" : "transparent")
                                    border.width: hovered ? 1 : 0
                                    border.color: "#55ffffff"

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.right: parent.right
                                        anchors.rightMargin: 6
                                        text: (isDefaultOutput ? "* " : "") + root.sinkLabel(modelData)
                                        elide: Text.ElideRight
                                        color: root.fgColor
                                        font.family: root.baseFont
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: audioSinkRow.hovered = true
                                        onExited: audioSinkRow.hovered = false
                                        onClicked: {
                                            root.setDefaultSink(modelData);
                                            audioPopup.visible = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Clock-click controls and notification history
                PopupWindow {
                    id: controlCenterPopup

                    visible: false
                    color: "transparent"
                    implicitWidth: 320
                    implicitHeight: Math.min(panel.height - 16, Math.max(260, controlCenterColumn.implicitHeight + 16))

                    anchor {
                        window: panel
                        rect.x: -controlCenterPopup.implicitWidth - 8
                        rect.y: panel.height - controlCenterPopup.implicitHeight - 8
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: "#cc11111b"
                        border.width: 1
                        border.color: "#80ffffff"

                        Column {
                            id: controlCenterColumn

                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Text {
                                width: parent.width
                                text: "Controls"
                                color: root.fgColor
                                font.family: root.baseFont
                                font.pixelSize: 14
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: "#33ffffff"
                            }

                            Row {
                                width: parent.width
                                height: 28
                                spacing: 6

                                Rectangle {
                                    width: 92
                                    height: parent.height
                                    radius: 4
                                    color: root.audioMuted ? "#33f38ba8" : "#22ffffff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.audioMuted ? "unmute" : "mute"
                                        color: root.fgColor
                                        font.family: root.baseFont
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.toggleMute()
                                    }
                                }

                                Rectangle {
                                    width: 42
                                    height: parent.height
                                    radius: 4
                                    color: "#22ffffff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "-"
                                        color: root.fgColor
                                        font.family: root.baseFont
                                        font.pixelSize: 14
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.adjustVolume(-5)
                                    }
                                }

                                Text {
                                    width: 54
                                    height: parent.height
                                    text: String(root.volumePercent) + "%"
                                    color: root.fgColor
                                    font.family: root.baseFont
                                    font.pixelSize: 12
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Rectangle {
                                    width: 42
                                    height: parent.height
                                    radius: 4
                                    color: "#22ffffff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: root.fgColor
                                        font.family: root.baseFont
                                        font.pixelSize: 14
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.adjustVolume(5)
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: root.sinkLabel(root.defaultSink)
                                color: root.mutedColor
                                elide: Text.ElideRight
                                font.family: root.baseFont
                                font.pixelSize: 10
                            }

                            Row {
                                width: parent.width
                                height: 28
                                spacing: 6

                                Rectangle {
                                    width: 92
                                    height: parent.height
                                    radius: 4
                                    color: "#22ffffff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "bright -"
                                        color: root.fgColor
                                        font.family: root.baseFont
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.adjustBrightness(-5)
                                    }
                                }

                                Rectangle {
                                    width: 92
                                    height: parent.height
                                    radius: 4
                                    color: "#22ffffff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "bright +"
                                        color: root.fgColor
                                        font.family: root.baseFont
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.adjustBrightness(5)
                                    }
                                }

                                Rectangle {
                                    width: 92
                                    height: parent.height
                                    radius: 4
                                    color: "#22ffffff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.powerProfileGlyph()
                                        color: root.fgColor
                                        font.family: root.baseFont
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.cyclePowerProfile()
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                height: 28
                                spacing: 6

                                Rectangle {
                                    width: 92
                                    height: parent.height
                                    radius: 4
                                    color: Networking.wifiEnabled ? "#22ffffff" : "#33f38ba8"

                                    Text {
                                        anchors.centerIn: parent
                                        text: Networking.wifiEnabled ? "wifi on" : "wifi off"
                                        color: root.fgColor
                                        font.family: root.baseFont
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.toggleWifi()
                                    }
                                }

                                Rectangle {
                                    width: 92
                                    height: parent.height
                                    radius: 4
                                    color: "#22ffffff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "lock"
                                        color: root.fgColor
                                        font.family: root.baseFont
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.lockSession()
                                    }
                                }

                                Rectangle {
                                    width: 92
                                    height: parent.height
                                    radius: 4
                                    color: "#22ffffff"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "suspend"
                                        color: root.fgColor
                                        font.family: root.baseFont
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.suspendSession()
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                height: 20
                                spacing: 8

                                Text {
                                    width: parent.width - 58
                                    height: parent.height
                                    text: "Notifications"
                                    color: root.fgColor
                                    font.family: root.baseFont
                                    font.pixelSize: 13
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    width: 50
                                    height: parent.height
                                    text: "clear"
                                    color: root.notificationCount > 0 ? root.accentColor : root.mutedColor
                                    font.family: root.baseFont
                                    font.pixelSize: 10
                                    horizontalAlignment: Text.AlignRight
                                    verticalAlignment: Text.AlignVCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            const notifications = notificationServer.trackedNotifications && notificationServer.trackedNotifications.values
                                                ? notificationServer.trackedNotifications.values.slice()
                                                : [];
                                            for (let i = 0; i < notifications.length; i += 1) {
                                                notifications[i].dismiss();
                                            }
                                        }
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    model: notificationServer.trackedNotifications

                                    Rectangle {
                                        required property var modelData

                                        width: controlCenterColumn.width
                                        height: 54
                                        radius: 5
                                        color: "#22ffffff"
                                        border.width: modelData.urgency === NotificationUrgency.Critical ? 1 : 0
                                        border.color: root.urgentColor

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            spacing: 2

                                            Text {
                                                width: parent.width
                                                text: root.notificationSummary(modelData)
                                                color: root.notificationAccent(modelData)
                                                elide: Text.ElideRight
                                                font.family: root.baseFont
                                                font.pixelSize: 11
                                            }

                                            Text {
                                                width: parent.width
                                                text: root.notificationBody(modelData)
                                                color: root.mutedColor
                                                elide: Text.ElideRight
                                                maximumLineCount: 2
                                                wrapMode: Text.Wrap
                                                font.family: root.baseFont
                                                font.pixelSize: 10
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            acceptedButtons: Qt.AllButtons
                                            onClicked: function(mouse) {
                                                if (mouse.button === Qt.RightButton) {
                                                    modelData.dismiss();
                                                } else {
                                                    root.activateNotification(modelData);
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: root.notificationCount === 0
                                    width: parent.width
                                    text: "No notifications"
                                    color: root.mutedColor
                                    font.family: root.baseFont
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }

                // New notification toast
                PanelWindow {
                    id: notificationToast

                    visible: root.toastNotifications.length > 0 && root.isPrimarySidebarScreen(panel.modelData.name, panel.monitorIndex)
                    screen: panel.modelData
                    color: "transparent"
                    implicitWidth: 300
                    implicitHeight: toastStack.implicitHeight
                    anchors {
                        top: true
                        right: true
                    }
                    margins {
                        top: 10
                        right: root.sidebarWidth + 10
                    }
                    exclusiveZone: 0
                    focusable: false
                    aboveWindows: true
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.namespace: "quickshell-notification-toast"
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                    Column {
                        id: toastStack

                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: root.toastNotifications

                            Rectangle {
                                required property var modelData

                                width: toastStack.width
                                height: 76
                                radius: 8
                                color: "#dd11111b"
                                border.width: 1
                                border.color: modelData.notification && modelData.notification.urgency === NotificationUrgency.Critical
                                    ? root.urgentColor
                                    : "#80ffffff"

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 3

                                    Text {
                                        width: parent.width
                                        text: root.notificationSummary(modelData.notification)
                                        color: root.notificationAccent(modelData.notification)
                                        elide: Text.ElideRight
                                        font.family: root.baseFont
                                        font.pixelSize: 12
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.notificationBody(modelData.notification)
                                        color: root.fgColor
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                        font.family: root.baseFont
                                        font.pixelSize: 10
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.AllButtons
                                    onClicked: function(mouse) {
                                        if (!modelData.notification) {
                                            return;
                                        }

                                        if (mouse.button === Qt.RightButton) {
                                            modelData.notification.dismiss();
                                        } else {
                                            root.activateNotification(modelData.notification);
                                        }

                                        root.removeToastNotification(modelData.serial);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
