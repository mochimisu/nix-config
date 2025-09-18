import App from "astal/app";
import { Window, Box, Button, Label } from "astal/widget";
import GLib from "gi://GLib";
import Gio from "gi://Gio";
import Gtk from "gi://Gtk";
import Pango from "gi://Pango";
import Tray from "astal/widget/tray";

const CONFIG_PATH = GLib.build_filenamev([App.configDir, "bar.json"]);
const CONFIG = JSON.parse(readFile(CONFIG_PATH));

function readFile(path) {
  try {
    const file = Gio.File.new_for_path(path);
    const [ok, contents] = file.load_contents(null);
    if (!ok) {
      return "";
    }
    return new TextDecoder().decode(contents);
  } catch (error) {
    logError(error);
    return "";
  }
}

function runCommand(command) {
  try {
    const proc = Gio.Subprocess.new(
      ["/bin/sh", "-c", command],
      Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE,
    );
    const [, stdout] = proc.communicate_utf8(null, null);
    return stdout.trim();
  } catch (error) {
    logError(error);
    return "";
  }
}

function spawn(command) {
  try {
    Gio.Subprocess.new(
      ["/bin/sh", "-c", command],
      Gio.SubprocessFlags.NONE,
    );
  } catch (error) {
    logError(error);
  }
}

function poll(intervalSeconds, fn) {
  fn();
  GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, intervalSeconds, () => {
    fn();
    return GLib.SOURCE_CONTINUE;
  });
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

function formatTemperature(sensor, value) {
  const template = sensor.format ?? "{temperatureC}°C {icon}";
  return template
    .replace("{temperatureC}", `${Math.round(value)}`)
    .replace("{icon}", sensor.icon ?? "");
}

let lastCpu = null;
function readCpuUsage() {
  const line = runCommand("grep '^cpu ' /proc/stat");
  if (!line) return 0;
  const parts = line.trim().split(/\s+/).slice(1).map(Number);
  if (parts.some(Number.isNaN)) return 0;
  const idle = parts[3] + parts[4];
  const total = parts.reduce((acc, cur) => acc + cur, 0);
  if (!lastCpu) {
    lastCpu = { idle, total };
    return 0;
  }
  const diffIdle = idle - lastCpu.idle;
  const diffTotal = total - lastCpu.total;
  lastCpu = { idle, total };
  if (diffTotal <= 0) return 0;
  return Math.round(100 * (1 - diffIdle / diffTotal));
}

function readMemoryUsage() {
  const text = readFile("/proc/meminfo");
  if (!text) return 0;
  const map = {};
  for (const line of text.split("\n")) {
    const [key, rawValue] = line.split(":");
    if (!key || !rawValue) continue;
    map[key.trim()] = Number(rawValue.trim().split(" ")[0]);
  }
  const total = map["MemTotal"] ?? 0;
  const available = map["MemAvailable"] ?? 0;
  if (total === 0) return 0;
  const used = total - available;
  return Math.round((used / total) * 100);
}

function readTemperature(sensor) {
  if (!sensor.path || !sensor.input) return null;
  const filePath = GLib.build_filenamev([sensor.path, sensor.input]);
  const raw = readFile(filePath).trim();
  if (!raw) return null;
  const value = Number(raw) / 1000;
  if (Number.isNaN(value)) return null;
  return value;
}

function readVolume() {
  const output = runCommand("wpctl get-volume @DEFAULT_AUDIO_SINK@");
  if (!output) return { percent: 0, muted: true };
  const muted = output.toLowerCase().includes("muted");
  const match = output.match(/(\d+\.\d+|\d+)/);
  let percent = 0;
  if (match) {
    const value = Number(match[1]);
    percent = value <= 1 ? Math.round(value * 100) : Math.round(value);
  }
  return { percent: clamp(percent, 0, 150), muted };
}

function readNetwork() {
  const output = runCommand("nmcli -t -f DEVICE,TYPE,STATE dev status");
  if (!output) return { state: "disconnected" };
  const lines = output.split("\n").map(line => line.trim()).filter(Boolean);
  const wifiLine = lines.find(line => line.includes(":wifi:"));
  const ethLine = lines.find(line => line.includes(":ethernet:"));
  if (wifiLine) {
    if (wifiLine.endsWith(":connected")) return { state: "wifi" };
    if (wifiLine.endsWith(":connecting")) return { state: "linked" };
  }
  if (ethLine) {
    if (ethLine.endsWith(":connected")) return { state: "ethernet" };
    if (ethLine.endsWith(":connecting")) return { state: "linked" };
  }
  return { state: "disconnected" };
}

function readBluetooth() {
  const info = runCommand("bluetoothctl show");
  const powered = info.includes("Powered: yes");
  const connectedDevices = runCommand("bluetoothctl devices Connected")
    .split("\n")
    .filter(Boolean).length;
  return { powered, connected: powered ? connectedDevices : 0 };
}

function readBattery(device) {
  if (!device) return null;
  const base = `/sys/class/power_supply/${device}`;
  const capacityRaw = readFile(`${base}/capacity`).trim();
  const status = readFile(`${base}/status`).trim();
  if (!capacityRaw) return null;
  const capacity = Number(capacityRaw);
  if (Number.isNaN(capacity)) return null;
  return { capacity: clamp(capacity, 0, 100), status };
}

function hyprMonitors() {
  const raw = runCommand("hyprctl -j monitors");
  if (!raw) return [];
  try {
    return JSON.parse(raw);
  } catch (error) {
    logError(error);
    return [];
  }
}

function hyprActiveWindow() {
  const raw = runCommand("hyprctl -j activewindow");
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch (error) {
    return null;
  }
}

function hyprWorkspaces() {
  const raw = runCommand("hyprctl -j workspaces");
  if (!raw) return [];
  try {
    return JSON.parse(raw);
  } catch (error) {
    logError(error);
    return [];
  }
}

function createWorkspaces(monitor) {
  const icons = CONFIG.hyprland?.workspaceIcons ?? {};
  const defaultIcon = icons.default ?? "";
  const activeIcon = icons.active ?? "";
  const urgentIcon = icons.urgent ?? "";

  const box = Box({
    class_name: "module workspaces",
    vertical: true,
    spacing: 6,
  });

  function refresh() {
    const workspaces = hyprWorkspaces();
    const active = hyprActiveWindow();
    const activeWorkspaceId = active?.workspace?.id ?? active?.workspaceid ?? null;

    const filtered = monitor
      ? workspaces.filter(ws => ws.monitorID === monitor.id)
      : workspaces;

    filtered.sort((a, b) => a.id - b.id);

    box.children = filtered.map(ws => {
      const stateIcon = ws.urgent ? urgentIcon : (ws.id === activeWorkspaceId ? activeIcon : defaultIcon);
      const button = Button({
        class_name: `workspace${ws.id === activeWorkspaceId ? " active" : ""}${ws.urgent ? " urgent" : ""}`,
        on_clicked: () => spawn(`hyprctl dispatch workspace ${ws.id}`),
        child: Label({
          class_name: "workspace-label",
          label: `${ws.name}: ${stateIcon}`,
          xalign: 0,
        }),
      });
      return button;
    });
  }

  poll(1, refresh);
  return box;
}

function createStats() {
  const statsBox = Box({
    class_name: "module stats",
    vertical: true,
    spacing: 4,
  });

  const memoryLabel = Label({
    class_name: "stat memory",
    xalign: 0,
    label: `--% ${CONFIG.memory?.icon ?? ""}`,
  });
  poll(3, () => {
    const usage = readMemoryUsage();
    memoryLabel.label = `${usage}% ${CONFIG.memory?.icon ?? ""}`;
  });

  const cpuLabel = Label({
    class_name: "stat cpu",
    xalign: 0,
    label: "--% ",
  });
  poll(2, () => {
    const cpu = readCpuUsage();
    cpuLabel.label = `${cpu}%`;
  });

  statsBox.append(memoryLabel);
  statsBox.append(cpuLabel);

  const sensors = CONFIG.sensors ?? [];
  for (const sensor of sensors) {
    const sensorLabel = Label({
      class_name: "stat temperature",
      xalign: 0,
      label: formatTemperature(sensor, 0),
    });

    poll(4, () => {
      const value = readTemperature(sensor);
      if (value === null) {
        sensorLabel.label = "--°C";
        sensorLabel.remove_css_class?.("critical");
        return;
      }
      sensorLabel.label = formatTemperature(sensor, value);
      if (sensor.critical && value >= sensor.critical) {
        sensorLabel.add_css_class?.("critical");
      } else {
        sensorLabel.remove_css_class?.("critical");
      }
    });

    statsBox.append(sensorLabel);
  }

  return statsBox;
}

function createWindowTitle() {
  const label = Label({
    class_name: "module window-title",
    wrap: true,
    justification: Gtk.Justification.CENTER,
    ellipsize: Pango.EllipsizeMode.END,
    max_width_chars: 12,
    label: "",
  });

  poll(1, () => {
    const win = hyprActiveWindow();
    const title = win?.title ?? "";
    label.label = title;
  });

  return label;
}

function createVolume() {
  const label = Label({
    class_name: "module volume",
    xalign: 0,
    label: "",
  });

  function refresh() {
    const info = readVolume();
    const icons = CONFIG.audio?.icons ?? {};
    const icon = info.muted
      ? icons.muted ?? ""
      : info.percent >= 80
        ? icons.high ?? ""
        : info.percent >= 40
          ? icons.medium ?? ""
          : icons.low ?? "";
    label.label = `${info.percent}% ${icon}`;
  }

  poll(1, refresh);

  if (CONFIG.audio?.onClick) {
    return Button({
      class_name: "module interactive volume-button",
      on_clicked: () => {
        const kill = CONFIG.audio?.onClickKill ?? CONFIG.audio.onClick;
        spawn(`${CONFIG.toggleAppPath} '${CONFIG.audio.onClick}' '${kill}'`);
      },
      child: label,
    });
  }

  return label;
}

function createNetwork() {
  const label = Label({
    class_name: "module network",
    xalign: 0,
    label: CONFIG.network?.icons?.disconnected ?? "D/C ⚠",
  });

  poll(5, () => {
    const state = readNetwork().state;
    const icons = CONFIG.network?.icons ?? {};
    let text;
    switch (state) {
      case "wifi":
        text = icons.wifi ?? "";
        break;
      case "ethernet":
        text = icons.ethernet ?? "";
        break;
      case "linked":
        text = icons.linked ?? "(No IP)";
        break;
      default:
        text = icons.disconnected ?? "D/C ⚠";
        break;
    }
    label.label = text;
  });

  return label;
}

function createBluetooth() {
  const label = Label({
    class_name: "module bluetooth",
    xalign: 0,
    label: "",
  });

  poll(7, () => {
    const info = readBluetooth();
    const icon = CONFIG.bluetooth?.icon ?? "";
    if (!info.powered) {
      label.label = "";
      return;
    }
    label.label = info.connected > 0 ? `${icon} ${info.connected}` : icon;
  });

  if (CONFIG.bluetooth?.onClick?.app) {
    return Button({
      class_name: "module interactive bluetooth-button",
      on_clicked: () => {
        const kill = CONFIG.bluetooth?.onClick?.kill ?? CONFIG.bluetooth.onClick.app;
        spawn(`${CONFIG.toggleAppPath} '${CONFIG.bluetooth.onClick.app}' '${kill}'`);
      },
      child: label,
    });
  }

  return label;
}

function createTray() {
  try {
    return Tray({
      class_name: "module tray",
      icon_size: CONFIG.tray?.iconSize ?? 18,
    });
  } catch (error) {
    logError(error);
    return Box({ class_name: "module tray" });
  }
}

function createBattery() {
  const device = CONFIG.battery?.device ?? "BAT0";
  const label = Label({
    class_name: "module battery",
    xalign: 0,
    label: "",
  });

  const icons = CONFIG.battery?.icons ?? ["", "", "", "", ""];
  const chargingIcon = CONFIG.battery?.chargingIcon ?? "";

  poll(30, () => {
    const info = readBattery(device);
    if (!info) {
      label.label = "";
      return;
    }
    const index = Math.min(icons.length - 1, Math.floor((info.capacity / 100) * icons.length));
    const icon = info.status === "Charging" ? chargingIcon : icons[index];
    label.label = `${info.capacity}% ${icon}`;
  });

  return label;
}

function createClock() {
  const label = Label({
    class_name: "module clock",
    xalign: 0,
    label: "",
  });

  const format = CONFIG.clock?.format ?? "%I:%M %p";

  poll(30, () => {
    const now = GLib.DateTime.new_now_local();
    label.label = now.format(format);
  });

  if (CONFIG.clock?.onClick) {
    return Button({
      class_name: "module interactive clock-button",
      on_clicked: () => {
        const kill = CONFIG.clock?.onClickKill ?? CONFIG.clock.onClick;
        spawn(`${CONFIG.toggleAppPath} '${CONFIG.clock.onClick}' '${kill}'`);
      },
      child: label,
    });
  }

  return label;
}

function buildBar(monitor) {
  const top = Box({
    class_name: "section top",
    vertical: true,
    spacing: 12,
    children: [
      createWorkspaces(monitor),
      createStats(),
    ],
  });

  const center = Box({
    class_name: "section center",
    vertical: true,
    vexpand: true,
    halign: Gtk.Align.CENTER,
    valign: Gtk.Align.CENTER,
    children: [
      createWindowTitle(),
    ],
  });

  const bottomChildren = [
    createVolume(),
    createNetwork(),
    createBluetooth(),
    createTray(),
    createBattery(),
    createClock(),
  ].filter(Boolean);

  const bottom = Box({
    class_name: "section bottom",
    vertical: true,
    spacing: 10,
    children: bottomChildren,
  });

  return Window({
    name: "astal-bar",
    class_name: "astal-bar",
    monitor: monitor?.id ?? 0,
    anchor: ["left", "top", "bottom"],
    margins: [12, 12, 12, 12],
    exclusive: true,
    child: Box({
      class_name: "bar",
      vertical: true,
      spacing: 18,
      children: [
        top,
        center,
        bottom,
      ],
    }),
  });
}

const excludeOutputs = CONFIG.hyprland?.excludeOutputs ?? [];

const windows = (() => {
  const monitors = hyprMonitors().filter(monitor => !excludeOutputs.includes(monitor.name));
  if (monitors.length === 0) {
    return [buildBar(null)];
  }
  return monitors.map(monitor => buildBar(monitor));
})();

App.config({
  style: GLib.build_filenamev([App.configDir, "style.css"]),
  windows,
});

App.run();
