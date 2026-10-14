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
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
    id: root

    // ----- Config injected from Nix -----
    readonly property bool sessionControlsEnabled: @sessionControlsEnabled@
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
    readonly property int workspaceHeightPx: {
        const parsed = parseInt("@workspaceHeight@", 10);
        return isNaN(parsed) ? 18 : parsed;
    }
    readonly property int workspaceSpacingPx: {
        const parsed = parseInt("@workspaceSpacing@", 10);
        return isNaN(parsed) ? 2 : parsed;
    }
    // Keep panel width in sync with content scaling from icon/text size.
    readonly property int sidebarWidth: Math.max(20, Math.round(Math.max(iconSize * 1.35, fontSizePx * 1.5)))

    // A small shared palette is injected only for Blackmoon.
    readonly property var theme: (@themePaletteJson@)
    readonly property bool themed: !!theme.ink
    readonly property color surfaceColor: themed ? theme.surface : "#cc11111b"
    readonly property color chipColor: themed ? theme.lavender : "#22ffffff"
    readonly property color selectedColor: themed ? theme.mint : "#33ffffff"
    readonly property color warningFill: themed ? theme.pink : "#33f38ba8"
    readonly property color edgeColor: themed ? theme.ink : "#80ffffff"
    readonly property int panelRadius: themed ? 16 : 8

    // ----- Derived sizing / style -----
    readonly property color fgColor: themed ? theme.ink : "white"
    readonly property color mutedColor: themed ? theme.muted : "#a6adc8"
    readonly property color accentColor: themed ? theme.ink : "#a6e3a1"
    readonly property color urgentColor: themed ? theme.urgent : "#f38ba8"
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

    // Decorative cards do not own input: existing handlers keep their targets.
    component RailCard: Rectangle {
        visible: root.themed
        radius: 9
        color: root.surfaceColor
        border { width: 1; color: root.edgeColor }
        Rectangle {
            anchors.fill: parent; anchors.margins: 2
            radius: 7; color: "transparent"
            border { width: 1; color: "#ffffff" }
        }
    }
    component MenuCard: Rectangle {
        radius: root.panelRadius
        Rectangle {
            visible: root.themed
            anchors.fill: parent; anchors.margins: 4
            radius: parent.radius - 4; color: "transparent"
            border { width: 1; color: root.theme.inactive || "transparent" }
            opacity: 0.45
        }
    }
    component MenuButton: Rectangle {
        objectName: "menuButton"
        radius: root.themed ? 12 : 4
        border.width: root.themed ? 2 : 0
        border.color: root.themed ? (menuHover.hovered ? root.theme.teal : root.edgeColor) : "transparent"
        HoverHandler { id: menuHover }
        Rectangle {
            visible: root.themed
            anchors.fill: parent; anchors.margins: 3
            radius: parent.radius - 3; color: "transparent"
            border { width: 1; color: "#ffffff" }
        }
    }

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
    property var notificationTimestamps: ({})
    property int notificationSerial: 0
    property bool powerActionVisible: false
    property string powerActionLabel: ""
    property var pendingPowerCommand: []
    readonly property var notificationModel: []
    readonly property int notificationCount: 0

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

    function isMonitorFullscreen(screenName) {
        const monitor = windowState[screenName];
        return !!monitor && monitor.fullscreen === true;
    }

    function dispatchWorkspace(workspace) {
        if (!workspace || workspace.id === undefined || workspace.id === null) {
            return;
        }

        const workspaceId = parseInt(workspace.id, 10);
        if (isNaN(workspaceId)) {
            return;
        }

        if (Hyprland.usingLua) {
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspaceId + " })");
        } else {
            Hyprland.dispatch("workspace " + workspaceId);
        }
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
        if (root.themed) {
            Quickshell.execDetached(["@mediaOsdBin@", "volume", delta > 0 ? "up" : "down"]);
            return;
        }
        setVolumePercent(volumePercent + delta);
    }

    function toggleMute() {
        if (root.themed) {
            Quickshell.execDetached(["@mediaOsdBin@", "volume", "mute"]);
            return;
        }
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
        if (!sessionControlsEnabled) return;
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
        if (!sessionControlsEnabled) return;
        if (root.themed) {
            Quickshell.execDetached(["@mediaOsdBin@", "brightness", delta > 0 ? "up" : "down"]);
            return;
        }
        const op = delta > 0 ? "5%+" : "5%-";
        Quickshell.execDetached(["brightnessctl", "set", op]);
    }

    function toggleWifi() {
        if (!sessionControlsEnabled) return;
        if (!Networking.wifiHardwareEnabled) {
            return;
        }

        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function lockSession() {
        if (!sessionControlsEnabled) return;
        controlCenterPopup.visible = false;
        Quickshell.execDetached(["hyprlock"]);
    }

    function beginPowerAction(label, command) {
        if (!sessionControlsEnabled) return;
        controlCenterPopup.visible = false;
        root.powerActionLabel = label;
        root.pendingPowerCommand = command;
        root.powerActionVisible = true;
        powerActionCommandTimer.restart();
    }

    function suspendSession() {
        beginPowerAction(
            "Suspending...",
            ["sh", "-lc", "sleep 0.8; pidof hyprlock >/dev/null 2>&1 || hyprlock & sleep 0.3; systemctl suspend"]
        );
    }

    function shutdownSession() {
        beginPowerAction("Shutting down...", ["systemctl", "poweroff"]);
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

    function notificationEntryAccent(entry) {
        if (entry && entry.critical) {
            return urgentColor;
        }

        return fgColor;
    }

    function notificationIconSource(notification) {
        if (!notification) {
            return "";
        }

        const image = String(notification.image || "");
        if (image !== "") {
            return image;
        }

        const appIcon = String(notification.appIcon || "");
        if (appIcon === "") {
            return "";
        }

        if (appIcon.indexOf("/") === 0 || appIcon.indexOf("file:") === 0 || appIcon.indexOf("image:") === 0) {
            return appIcon;
        }

        return "image://icon/" + appIcon;
    }

    function notificationKey(notification) {
        if (!notification) {
            return "";
        }

        return String(notification.appName || "") + ":" + String(notification.id || "") + ":" + root.notificationSummary(notification);
    }

    function formatTimestamp(date) {
        const hours = date.getHours();
        const minutes = date.getMinutes();
        const hour12 = hours % 12 || 12;
        const suffix = hours >= 12 ? "pm" : "am";
        return String(hour12) + ":" + String(minutes).padStart(2, "0") + suffix;
    }

    function rememberNotificationTimestamp(notification, timestamp) {
        const key = root.notificationKey(notification);
        if (key === "") {
            return;
        }

        const next = Object.assign({}, root.notificationTimestamps);
        next[key] = timestamp;
        root.notificationTimestamps = next;
    }

    function notificationTimestamp(notification) {
        const key = root.notificationKey(notification);
        if (key !== "" && root.notificationTimestamps[key]) {
            return root.notificationTimestamps[key];
        }

        const timestamp = root.formatTimestamp(new Date());
        root.rememberNotificationTimestamp(notification, timestamp);
        return timestamp;
    }

    function pushToastNotification(notification) {
        const now = Date.now();
        const timestamp = root.formatTimestamp(new Date());
        root.rememberNotificationTimestamp(notification, timestamp);
        root.notificationSerial += 1;
        const next = [{
            "notification": notification,
            "serial": root.notificationSerial,
            "expiresAt": now + 5500,
            "summary": root.notificationSummary(notification),
            "body": root.notificationBody(notification),
            "icon": root.notificationIconSource(notification),
            "timestamp": timestamp,
            "critical": notification && notification.urgency === NotificationUrgency.Critical
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

    function dismissToastNotification(entry) {
        if (!entry) {
            return;
        }

        root.removeToastNotification(entry.serial);

        if (!entry.notification) {
            return;
        }

        try {
            entry.notification.dismiss();
        } catch (error) {
            console.warn("Unable to dismiss notification:", error);
        }
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

    Timer {
        id: notificationToastPruneTimer

        running: root.toastNotifications.length > 0
        interval: 1000
        repeat: true
        onTriggered: root.pruneToastNotifications()
    }

    Timer {
        id: powerActionCommandTimer

        interval: 150
        repeat: false
        onTriggered: {
            if (root.pendingPowerCommand.length > 0) {
                Quickshell.execDetached(root.pendingPowerCommand);
            }
        }
    }

    PwObjectTracker {
        objects: root.defaultSink ? [root.defaultSink] : []
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

                Flickable {
                    id: railViewport
                    anchors.fill: parent
                    anchors.topMargin: root.themed ? 4 : 0
                    anchors.bottomMargin: root.themed ? 4 : 0
                    contentHeight: railColumn.implicitHeight
                    interactive: root.themed && contentHeight > height
                    clip: root.themed
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: railColumn
                        width: railViewport.width
                        spacing: root.themed ? 6 : 0

                        Item {
                            id: workspaceModule
                            width: parent.width
                            height: topSection.implicitHeight + (root.themed ? 8 : 0)
                            RailCard { anchors.fill: parent }
                            // --- Top: workspaces ---
                            Column {
                                id: topSection
                                width: parent.width
                                y: root.themed ? 4 : 0
                                spacing: root.workspaceSpacingPx

                                Repeater {
                                    model: contentRoot.monitorWorkspaces

                                    Item {
                                        id: workspaceItem

                                        required property var modelData
                                        readonly property var workspace: modelData

                                        width: topSection.width
                                        height: root.workspaceHeightPx

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: parent.width - 4
                                            height: parent.height - 2
                                            radius: root.themed ? 5 : 3
                                            color: modelData.urgent ? root.warningFill
                                                : root.themed ? (modelData.active ? root.selectedColor : root.chipColor) : "transparent"
                                            border.width: root.themed && modelData.active ? 1 : 0
                                            border.color: root.fgColor
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.urgent ? ("!" + modelData.name + "!") : (modelData.active && !root.themed ? ("-" + modelData.name + "-") : String(modelData.name))
                                            color: modelData.urgent ? root.urgentColor : root.fgColor
                                            font.family: root.baseFont
                                            font.pixelSize: Math.max(8, root.fontSizePx - 2)
                                            font.bold: !!modelData.active || !!modelData.urgent
                                            renderType: Text.NativeRendering
                                        }

                                        MouseArea {
                                            z: 10
                                            anchors.fill: parent
                                            acceptedButtons: Qt.LeftButton
                                            cursorShape: Qt.PointingHandCursor

                                            onClicked: function(mouse) {
                                                root.dispatchWorkspace(workspaceItem.workspace);
                                                mouse.accepted = true;
                                            }
                                        }
                                    }
                                }
                            }

                        }

                        // --- Center: active window title ---
                        Item {
                            id: centerSection
                            width: parent.width
                            height: Math.max(0, railViewport.height - workspaceModule.height - bottomSection.implicitHeight - railColumn.spacing * 2)

                            RailCard {
                                id: titleCard
                                anchors.centerIn: parent
                                width: parent.width
                                height: Math.min(parent.height, windowTitle.implicitWidth + 16, 260)
                                visible: root.themed && height > 24 && contentRoot.monitorWindowTitle !== ""
                            }
                            Text {
                                id: windowTitle
                                anchors.centerIn: parent
                                visible: !root.themed || titleCard.visible
                                width: root.themed ? Math.max(0, titleCard.height - 12) : centerSection.height
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

                            Item {
                                id: trayModule
                                width: parent.width
                                visible: trayColumn.implicitHeight > 0
                                height: visible ? trayColumn.implicitHeight + (root.themed ? 8 : 0) : 0
                                RailCard { anchors.fill: parent }
                                // System tray
                                Column {
                                    id: trayColumn
                                    y: root.themed ? 4 : 0
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

                            }
                            // Gap between tray items and status icons.
                            Item {
                                width: parent.width
                                height: root.trayToStatusGapPx
                                visible: !root.themed
                            }

                            Item {
                                id: statusModule
                                width: parent.width
                                height: statusColumn.implicitHeight + (root.themed ? 8 : 0)
                                RailCard { anchors.fill: parent }
                                Column {
                                    id: statusColumn
                                    width: parent.width
                                    y: root.themed ? 4 : 0
                                    spacing: 6
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
                                        color: root.accentColor
                                        font.family: root.baseFont
                                        font.pixelSize: 9
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Text {
                                        text: "PTT"
                                        color: root.accentColor
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
                                        color: root.accentColor
                                        font.family: root.baseFont
                                        font.pixelSize: 8
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Text {
                                        text: "QWER"
                                        color: root.accentColor
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

                                }
                            }

                            // Clock
                            Item {
                                id: clockBlock

                                width: parent.width
                                height: clockColumn.implicitHeight + (root.themed ? 8 : 0)
                                RailCard { anchors.fill: parent }

                                Column {
                                    id: clockColumn
                                    y: root.themed ? 4 : 0

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

                    }

                // Audio output popup
                PopupWindow {
                    id: audioPopup

                    visible: false
                    color: "transparent"
                    implicitWidth: 260
                    implicitHeight: root.themed ? Math.min(panel.height - 16, Math.max(40, sinksColumn.implicitHeight + 20)) : Math.max(40, sinksColumn.implicitHeight + 10)

                    anchor {
                        window: panel
                        rect.x: -audioPopup.implicitWidth - 8
                        rect.y: panel.height - audioPopup.implicitHeight - 8
                    }

                    MenuCard {
                        id: audioCard
                        anchors.fill: parent
                        color: root.themed ? root.surfaceColor : "#99000000"
                        border.width: root.themed ? 2 : 1
                        border.color: root.edgeColor

                        Flickable {
                            id: audioViewport
                            anchors.fill: parent
                            anchors.margins: root.themed ? 10 : 4
                            contentHeight: sinksColumn.implicitHeight
                            interactive: root.themed && contentHeight > height
                            clip: root.themed
                            boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: sinksColumn
                            width: audioViewport.width
                            spacing: root.themed ? 6 : 2

                            Repeater {
                                model: Pipewire.nodes

                                MenuButton {
                                    required property var modelData
                                    id: audioSinkRow

                                    readonly property bool audioOutput: root.isAudioSink(modelData) && !root.isBlockedAudioSink(modelData)
                                    readonly property bool isDefaultOutput: root.defaultSink && modelData && root.defaultSink.id === modelData.id
                                    property bool hovered: false

                                    width: sinksColumn.width
                                    height: audioOutput ? (root.themed ? 32 : 24) : 0

                                    visible: audioOutput
                                    color: isDefaultOutput ? root.selectedColor : (hovered ? root.chipColor : "transparent")
                                    border.width: root.themed ? 2 : (hovered ? 1 : 0)
                                    border.color: root.themed ? root.theme.inactive : "#55ffffff"

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
                }

                // Clock-click controls and notification history
                PopupWindow {
                    id: controlCenterPopup

                    visible: false
                    color: "transparent"
                    implicitWidth: 320
                    implicitHeight: Math.min(panel.height - 16, Math.max(260, controlCenterColumn.implicitHeight + (root.themed ? 28 : 16)))

                    anchor {
                        window: panel
                        rect.x: -controlCenterPopup.implicitWidth - 8
                        rect.y: panel.height - controlCenterPopup.implicitHeight - 8
                    }

                    MenuCard {
                        id: controlCard
                        anchors.fill: parent
                        color: root.themed ? root.surfaceColor : "#cc11111b"
                        border.width: root.themed ? 2 : 1
                        border.color: root.edgeColor

                        Flickable {
                            id: controlsViewport
                            anchors.fill: parent
                            anchors.margins: root.themed ? 14 : 8
                            contentHeight: controlCenterColumn.implicitHeight
                            interactive: root.themed && contentHeight > height
                            clip: root.themed
                            boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: controlCenterColumn

                            width: controlsViewport.width
                            spacing: root.themed ? 10 : 8

                            Text {
                                width: parent.width
                                text: "Controls"
                                font.bold: root.themed
                                font.italic: root.themed
                                color: root.fgColor
                                font.family: root.baseFont
                                font.pixelSize: root.themed ? 16 : 14
                            }

                            Rectangle {
                                width: parent.width
                                height: root.themed ? 3 : 1
                                color: root.selectedColor
                                Row {
                                    anchors.fill: parent
                                    visible: root.themed
                                    Rectangle { width: parent.width / 3; height: parent.height; color: root.themed ? root.theme.teal : root.selectedColor }
                                    Rectangle { width: parent.width / 3; height: parent.height; color: root.themed ? root.theme.lavenderEdge : root.selectedColor }
                                    Rectangle { width: parent.width / 3; height: parent.height; color: root.warningFill }
                                }
                            }

                            Row {
                                width: parent.width
                                height: root.themed ? 32 : 28
                                spacing: 6

                                MenuButton {
                                    width: root.themed ? (parent.width - parent.spacing * 2) / 3 : 92
                                    height: parent.height

                                    color: root.audioMuted ? root.warningFill : root.chipColor

                                    Text {
                                        anchors.centerIn: parent
                                        font.weight: root.themed ? Font.DemiBold : Font.Normal
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

                                MenuButton {
                                    width: 42
                                    height: parent.height

                                    color: root.chipColor

                                    Text {
                                        anchors.centerIn: parent
                                        font.weight: root.themed ? Font.DemiBold : Font.Normal
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

                                MenuButton {
                                    width: 42
                                    height: parent.height

                                    color: root.chipColor

                                    Text {
                                        anchors.centerIn: parent
                                        font.weight: root.themed ? Font.DemiBold : Font.Normal
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
                                visible: root.sessionControlsEnabled
                                height: visible ? (root.themed ? 32 : 28) : 0
                                spacing: 6

                                MenuButton {
                                    width: root.themed ? (parent.width - parent.spacing * 2) / 3 : 92
                                    height: parent.height

                                    color: root.chipColor

                                    Text {
                                        anchors.centerIn: parent
                                        font.weight: root.themed ? Font.DemiBold : Font.Normal
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

                                MenuButton {
                                    width: root.themed ? (parent.width - parent.spacing * 2) / 3 : 92
                                    height: parent.height

                                    color: root.chipColor

                                    Text {
                                        anchors.centerIn: parent
                                        font.weight: root.themed ? Font.DemiBold : Font.Normal
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

                                MenuButton {
                                    width: root.themed ? (parent.width - parent.spacing * 2) / 3 : 92
                                    height: parent.height

                                    color: root.chipColor

                                    Text {
                                        anchors.centerIn: parent
                                        font.weight: root.themed ? Font.DemiBold : Font.Normal
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
                                visible: root.sessionControlsEnabled
                                height: visible ? (root.themed ? 32 : 28) : 0
                                spacing: 6

                                MenuButton {
                                    width: root.themed ? (parent.width - parent.spacing * 3) / 4 : 70
                                    height: parent.height

                                    color: Networking.wifiEnabled ? root.chipColor : root.warningFill

                                    Text {
                                        anchors.centerIn: parent
                                        font.weight: root.themed ? Font.DemiBold : Font.Normal
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

                                MenuButton {
                                    width: root.themed ? (parent.width - parent.spacing * 3) / 4 : 70
                                    height: parent.height

                                    color: root.chipColor

                                    Text {
                                        anchors.centerIn: parent
                                        font.weight: root.themed ? Font.DemiBold : Font.Normal
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

                                MenuButton {
                                    width: root.themed ? (parent.width - parent.spacing * 3) / 4 : 70
                                    height: parent.height

                                    color: root.chipColor

                                    Text {
                                        anchors.centerIn: parent
                                        font.weight: root.themed ? Font.DemiBold : Font.Normal
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

                                MenuButton {
                                    width: root.themed ? (parent.width - parent.spacing * 3) / 4 : 70
                                    height: parent.height

                                    color: root.warningFill

                                    Text {
                                        anchors.centerIn: parent
                                        font.weight: root.themed ? Font.DemiBold : Font.Normal
                                        text: "shutdown"
                                        color: root.fgColor
                                        font.family: root.baseFont
                                        font.pixelSize: 10
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.shutdownSession()
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
                                            root.toastNotifications = [];
                                        }
                                    }
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    model: root.notificationModel

                                    Rectangle {
                                        required property var modelData

                                        width: controlCenterColumn.width
                                        height: Math.max(58, notificationHistoryContent.implicitHeight + 12)
                                        radius: 5
                                        color: root.chipColor
                                        border.width: modelData.urgency === NotificationUrgency.Critical ? 1 : 0
                                        border.color: root.urgentColor

                                        Column {
                                            id: notificationHistoryContent

                                            anchors.fill: parent
                                            anchors.margins: 6
                                            spacing: 2

                                            Row {
                                                width: parent.width
                                                spacing: 6

                                                Text {
                                                    width: parent.width - historyTimestamp.width - parent.spacing
                                                    text: root.notificationSummary(modelData)
                                                    color: root.notificationAccent(modelData)
                                                    wrapMode: Text.Wrap
                                                    maximumLineCount: 2
                                                    font.family: root.baseFont
                                                    font.pixelSize: 11
                                                }

                                                Text {
                                                    id: historyTimestamp

                                                    text: root.notificationTimestamp(modelData)
                                                    color: root.mutedColor
                                                    font.family: root.baseFont
                                                    font.pixelSize: 9
                                                }
                                            }

                                            Text {
                                                width: parent.width
                                                text: root.notificationBody(modelData)
                                                color: root.mutedColor
                                                maximumLineCount: 4
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
                }

                PopupWindow {
                    id: powerActionPopup

                    visible: root.powerActionVisible
                    color: "transparent"
                    implicitWidth: 360
                    implicitHeight: 150

                    anchor {
                        window: panel
                        rect.x: -powerActionPopup.implicitWidth - 12
                        rect.y: Math.max(16, Math.round((panel.height - powerActionPopup.implicitHeight) / 2))
                    }

                    MenuCard {
                        anchors.fill: parent
                        color: root.themed ? root.surfaceColor : "#ee050508"
                        border.width: 1
                        border.color: root.accentColor

                        Column {
                            anchors.centerIn: parent
                            width: parent.width - 32
                            spacing: 14

                            Rectangle {
                                id: powerActionSpinner

                                width: 34
                                height: 34
                                radius: 17
                                color: "transparent"
                                border.width: 4
                                border.color: root.accentColor
                                anchors.horizontalCenter: parent.horizontalCenter

                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: root.themed ? root.surfaceColor : "#ee050508"
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                }

                                RotationAnimation on rotation {
                                    running: root.powerActionVisible
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 900
                                }
                            }

                            Text {
                                width: parent.width
                                text: root.powerActionLabel
                                color: root.fgColor
                                font.family: root.baseFont
                                font.pixelSize: 22
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                renderType: Text.NativeRendering
                            }

                            Text {
                                width: parent.width
                                text: "Waiting for system services to finish"
                                color: root.mutedColor
                                font.family: root.baseFont
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }

                // New notification toast
                PanelWindow {
                    id: notificationToast

                    visible: false
                        && root.toastNotifications.length > 0
                        && root.isPrimarySidebarScreen(panel.modelData.name, panel.monitorIndex)
                        && !root.isMonitorFullscreen(panel.modelData.name)
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
                    aboveWindows: false
                    WlrLayershell.layer: WlrLayer.Top
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
                                height: Math.max(76, toastContent.implicitHeight + 16)
                                radius: root.panelRadius
                                color: root.themed ? root.surfaceColor : "#dd11111b"
                                border.width: 1
                                border.color: modelData.critical
                                    ? root.urgentColor
                                    : root.edgeColor

                                Row {
                                    id: toastContent

                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8

                                    Rectangle {
                                        visible: !!modelData.icon
                                        width: visible ? 38 : 0
                                        height: visible ? 38 : 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        radius: 6
                                        color: root.chipColor
                                        clip: true

                                        IconImage {
                                            anchors.centerIn: parent
                                            width: 28
                                            height: root.themed ? 32 : 28
                                            source: modelData.icon || ""
                                        }
                                    }

                                    Column {
                                        width: parent.width - (modelData.icon ? 46 : 0)
                                        spacing: 3

                                        Row {
                                            width: parent.width
                                            spacing: 8

                                            Text {
                                                width: parent.width - toastTimestamp.width - parent.spacing
                                                text: modelData.summary || ""
                                                color: root.notificationEntryAccent(modelData)
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                font.family: root.baseFont
                                                font.pixelSize: 12
                                            }

                                            Text {
                                                id: toastTimestamp

                                                text: modelData.timestamp || ""
                                                color: root.mutedColor
                                                font.family: root.baseFont
                                                font.pixelSize: 9
                                            }
                                        }

                                        Text {
                                            width: parent.width
                                            text: modelData.body || ""
                                            color: root.fgColor
                                            maximumLineCount: 5
                                            wrapMode: Text.Wrap
                                            font.family: root.baseFont
                                            font.pixelSize: 10
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
}
