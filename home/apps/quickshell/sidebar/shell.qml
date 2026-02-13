//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
    id: root

    // ----- Config injected from Nix -----
    property var sidebarScreens: @sidebarScreensJson@
    readonly property bool pttEnabled: "@pttStateFile@" !== ""

    readonly property int sidebarWidth: 20
    readonly property int iconSize: {
        const parsed = parseInt("@iconSize@", 10);
        return isNaN(parsed) ? 16 : parsed;
    }
    readonly property int fontSizePx: {
        const parsed = parseInt("@fontSize@", 10);
        return isNaN(parsed) ? 13 : parsed;
    }

    // ----- Derived sizing / style -----
    readonly property color fgColor: "white"
    readonly property string baseFont: "Montserrat Bold"
    readonly property int tinyTextPx: Math.max(8, Math.round(fontSizePx * 0.65))
    readonly property int clockMainPx: Math.max(11, Math.round(fontSizePx * 1.2))
    readonly property int statusIconPx: Math.max(10, fontSizePx)

    // ----- Runtime state -----
    property var workspacesState: ({})
    property var windowState: ({})
    property var networkState: ({"ssid": null, "eth": null})
    property var batteryState: ({"state": "", "percent": 0, "time": "", "rate": ""})
    readonly property int bluetoothCount: (Bluetooth.devices && Bluetooth.devices.values)
        ? Bluetooth.devices.values.length
        : 0
    property int volumePercent: 0
    property string cavaBars: ""
    property var clockState: ({"hour": "00", "minute": "00", "ampm": "am", "date": "01/01"})
    property var audioSinks: ([])
    property string qwertyState: "other"
    property string pttState: "unknown"

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
        command: ["@volBin@"]
        stdout: SplitParser {
            onRead: function(data) {
                root.volumePercent = root.parseIntegerLine(data, root.volumePercent);
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
        command: ["@audioSinksBin@"]
        stdout: SplitParser {
            onRead: function(data) {
                const parsed = root.parseJsonLine(data, root.audioSinks);
                if (Array.isArray(parsed)) {
                    root.audioSinks = parsed;
                }
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

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.active ? ("-" + modelData.name + "-") : String(modelData.name)
                                    color: root.fgColor
                                    font.family: root.baseFont
                                    font.pixelSize: Math.max(8, root.fontSizePx - 2)
                                    font.bold: !!modelData.active
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

                                    width: bottomSection.width
                                    height: root.iconSize + 4

                                    IconImage {
                                        anchors.centerIn: parent
                                        implicitSize: root.iconSize
                                        source: root.trayIconSource(modelData.icon)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.AllButtons

                                        onClicked: function(mouse) {
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
                                    }
                                }
                            }
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
                                spacing: -1

                                Item {
                                    width: parent.width
                                    height: 10
                                    clip: true

                                    Text {
                                        id: cavaText
                                        text: root.cavaBars
                                        color: root.fgColor
                                        font.family: "monospace"
                                        font.pixelSize: 10
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
                                    text: String(root.volumePercent) + "%"
                                    color: root.fgColor
                                    font.family: root.baseFont
                                    font.pixelSize: 9
                                    horizontalAlignment: Text.AlignHCenter
                                    renderType: Text.NativeRendering
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    audioPopup.visible = !audioPopup.visible;
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
                            height: visible ? 28 : 0

                            Column {
                                anchors.centerIn: parent
                                spacing: -2

                                Text {
                                    text: root.batteryIcon()
                                    color: root.fgColor
                                    font.family: root.baseFont
                                    font.pixelSize: 13
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

                        // Clock
                        Column {
                            width: parent.width
                            spacing: -2

                            Text {
                                width: parent.width
                                text: String(root.clockState.hour || "00")
                                color: root.fgColor
                                font.family: root.baseFont
                                font.pixelSize: root.clockMainPx
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
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                width: parent.width
                                text: String(root.clockState.date || "01/01")
                                color: root.fgColor
                                font.family: root.baseFont
                                font.pixelSize: root.tinyTextPx
                                horizontalAlignment: Text.AlignHCenter
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
                                model: root.audioSinks

                                Rectangle {
                                    required property var modelData

                                    width: sinksColumn.width
                                    height: 22
                                    radius: 4
                                    color: modelData.state === "RUNNING" ? "#33ffffff" : "transparent"

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6
                                        anchors.right: parent.right
                                        anchors.rightMargin: 6
                                        text: String(modelData.description || modelData.name || "")
                                        elide: Text.ElideRight
                                        color: root.fgColor
                                        font.family: root.baseFont
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            Quickshell.execDetached(["pactl", "set-default-sink", String(modelData.name)]);
                                            audioPopup.visible = false;
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
