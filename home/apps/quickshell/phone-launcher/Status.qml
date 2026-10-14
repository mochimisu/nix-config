import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

Item {
    id: status
    visible: false
    readonly property var devices: Networking.devices.values
    readonly property var connected: devices.filter(d => d.connected)
    readonly property string networkLabel: Networking.backend === NetworkBackendType.None ? "Unavailable" : connected.length ? connected.map(d => {
        const net = d.networks.values.find(n => n.connected);
        return net ? net.name : d.name;
    }).join(", ") : "Disconnected"
    readonly property string bluetoothLabel: Bluetooth.defaultAdapter
        ? (Bluetooth.defaultAdapter.enabled ? "On · " + Bluetooth.devices.values.filter(d => d.connected).length + " connected" : "Off")
        : "Unavailable"
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool audioReady: !!(sink && sink.audio)
    readonly property bool muted: audioReady ? sink.audio.muted : false
    readonly property real volume: audioReady ? sink.audio.volume : 0
    readonly property string audioLabel: audioReady ? (muted ? "Muted" : Math.round(volume * 100) + "%") : "Unavailable"
    readonly property string wallpaper: "file://" + Quickshell.env("HOME") + "/.config/hypr/dusk.jpg"
    property string hostname: ""
    FileView {
        path: "/proc/sys/kernel/hostname"
        onLoaded: status.hostname = text().trim().toUpperCase()
    }
    property date now: new Date()
    property string download: "—"
    property string upload: "—"
    property var previous: null
    PwObjectTracker { objects: status.sink ? [status.sink] : [] }
    function toggleMute() { if (audioReady) sink.audio.muted = !sink.audio.muted; }
    function setVolume(value) { if (audioReady) sink.audio.volume = Math.max(0, Math.min(1, value)); }
    function rate(bytes) {
        return bytes < 1024 ? Math.round(bytes) + " B/s" : bytes < 1048576
            ? (bytes / 1024).toFixed(1) + " KiB/s" : (bytes / 1048576).toFixed(1) + " MiB/s";
    }
    function sample(text) {
        const names = connected.map(d => d.name).sort();
        let rx = 0, tx = 0, found = 0;
        for (const line of text.split("\n")) {
            const parts = line.trim().split(/[:\s]+/);
            if (!names.includes(parts[0]) || parts.length < 17) continue;
            rx += Number(parts[1]); tx += Number(parts[9]); found++;
        }
        const time = Date.now(), key = names.join(",");
        if (found && previous && previous.key === key && time > previous.time && rx >= previous.rx && tx >= previous.tx) {
            download = rate((rx - previous.rx) * 1000 / (time - previous.time));
            upload = rate((tx - previous.tx) * 1000 / (time - previous.time));
        } else { download = "—"; upload = "—"; }
        previous = found ? {rx, tx, time, key} : null;
    }
    FileView {
        id: counters
        path: "/proc/net/dev"
        onLoaded: status.sample(text())
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: { status.now = new Date(); counters.reload(); } }
}
