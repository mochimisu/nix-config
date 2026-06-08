{
  config,
  lib,
  pkgs,
  ...
}: let
  hostName = config.networking.hostName;
  hostLabel = lib.toUpper hostName;
  sambaShares = builtins.attrNames (builtins.removeAttrs config.services.samba.settings ["global"]);
  sambaShare = lib.head sambaShares;
  statsMounts = ["/"] ++ lib.optionals (config.fileSystems ? "/earth") ["/earth"];
  statsMountsJson = builtins.toJSON statsMounts;
  btrfsMounts = builtins.filter (mount: (config.fileSystems.${mount}.fsType or "") == "btrfs") (builtins.attrNames config.fileSystems);
  btrfsMountsJson = builtins.toJSON btrfsMounts;
  homepageListen = [
    # OTBR's own web process is moved to 127.0.0.1:8080 in
    # home-assistant/default.nix, so nginx can own normal HTTP everywhere.
    { addr = "0.0.0.0"; port = 80; }
    { addr = "[::]"; port = 80; extraParameters = ["ipv6only=on"]; }
  ];
  otbrUpstreamPort = 8080;
  otbrWebPort = 8088;
  matterjsWebPort = config.gaia.homeAssistant.matterjs.port;
  proxiedServiceHeaders = prefix: ''
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Forwarded-Prefix ${prefix};
    proxy_set_header Accept-Encoding "";
    proxy_redirect off;
  '';
  matterLayerSubstitutions = ''
    sub_filter_once off;
    sub_filter_types text/html application/javascript text/javascript;
    sub_filter 'src="/assets/' 'src="/matter-layer/assets/';
    sub_filter 'href="/assets/' 'href="/matter-layer/assets/';
    sub_filter 'src="/src/' 'src="/matter-layer/src/';
    sub_filter 'from "/src/' 'from "/matter-layer/src/';
    sub_filter 'import "/src/' 'import "/matter-layer/src/';
    sub_filter 'src="/@vite/' 'src="/matter-layer/@vite/';
    sub_filter '"/@vite/' '"/matter-layer/@vite/';
    sub_filter '"/@fs/' '"/matter-layer/@fs/';
    sub_filter 'from "/@fs/' 'from "/matter-layer/@fs/';
    sub_filter 'import "/@fs/' 'import "/matter-layer/@fs/';
    sub_filter '"/api/' '"/matter-layer/api/';
    sub_filter 'fetch("/api/' 'fetch("/matter-layer/api/';
    sub_filter '`/api/' '`/matter-layer/api/';
    sub_filter 'host}/events' 'host}/matter-layer/events';
  '';
  blackvueSubstitutions = ''
    sub_filter_once off;
    sub_filter_types text/html application/javascript text/javascript application/json;
    sub_filter 'src="/assets/' 'src="/blackvue/assets/';
    sub_filter 'href="/assets/' 'href="/blackvue/assets/';
    sub_filter 'fetch("/api/' 'fetch("/blackvue/api/';
    sub_filter '"/api/video/' '"/blackvue/api/video/';
  '';
  otbrWebListen = [
    { addr = "0.0.0.0"; port = otbrWebPort; }
    { addr = "[::]"; port = otbrWebPort; extraParameters = ["ipv6only=on"]; }
  ];
  statsCollector = pkgs.writeTextFile {
    name = "gaia-homepage-stats.py";
    executable = true;
    text = ''
      #!${pkgs.python3}/bin/python3
      import asyncio
      import ipaddress
      import json
      import os
      import subprocess
      import time
      from pathlib import Path

      out_dir = Path("/run/gaia-homepage")
      out_file = out_dir / "stats.json"
      clients = set()
      latest_payload = None

      def read_cpu():
          with open("/proc/stat", "r", encoding="utf-8") as f:
              parts = f.readline().split()[1:]
          vals = [int(x) for x in parts]
          idle = vals[3] + (vals[4] if len(vals) > 4 else 0)
          return sum(vals), idle

      def read_mem():
          data = {}
          with open("/proc/meminfo", "r", encoding="utf-8") as f:
              for line in f:
                  k, v = line.split(":", 1)
                  data[k] = int(v.strip().split()[0]) * 1024
          total = data.get("MemTotal", 0)
          available = data.get("MemAvailable", 0)
          used = max(total - available, 0)
          pct = (used / total * 100) if total else 0
          return {"total": total, "used": used, "available": available, "percent": pct}

      def read_df():
          mounts = ${statsMountsJson}
          rows = []
          output = subprocess.check_output(["${pkgs.coreutils}/bin/df", "-h", *mounts], text=True)
          for line in output.splitlines()[1:]:
              parts = line.split()
              if len(parts) >= 6:
                  rows.append({
                      "filesystem": parts[0],
                      "size": parts[1],
                      "used": parts[2],
                      "available": parts[3],
                      "percent": parts[4],
                      "mount": parts[5],
                  })
          return rows

      def run_text(cmd, timeout=10):
          return subprocess.check_output(cmd, text=True, stderr=subprocess.STDOUT, timeout=timeout)

      def read_btrfs_device_stats(mount):
          errors = []
          try:
              output = run_text(["${pkgs.btrfs-progs}/bin/btrfs", "device", "stats", mount])
          except Exception as e:
              return {"ok": False, "error": str(e), "errors": []}
          for line in output.splitlines():
              if " " not in line:
                  continue
              key, value = line.rsplit(None, 1)
              try:
                  count = int(value)
              except ValueError:
                  continue
              name = key.split(".", 1)[-1]
              if count:
                  errors.append({"name": name, "count": count})
          return {"ok": not errors, "errors": errors}

      def read_btrfs_scrub(mount):
          try:
              output = run_text(["${pkgs.btrfs-progs}/bin/btrfs", "scrub", "status", "-R", mount])
          except Exception as e:
              return {"ok": False, "status": "unknown", "error": str(e)}
          scrub = {"ok": True, "status": "unknown"}
          error_total = 0
          for raw in output.splitlines():
              line = raw.strip()
              if not line or ":" not in line:
                  continue
              key, value = [part.strip() for part in line.split(":", 1)]
              key_l = key.lower().replace(" ", "_")
              if key_l == "status":
                  scrub["status"] = value
              elif key_l == "duration":
                  scrub["duration"] = value
              elif key_l == "total_to_scrub":
                  scrub["totalToScrub"] = value
              elif key_l == "rate":
                  scrub["rate"] = value
              elif key_l.endswith("_errors"):
                  try:
                      count = int(value.split()[0])
                  except Exception:
                      continue
                  if count:
                      error_total += count
          scrub["errorCount"] = error_total
          scrub["ok"] = error_total == 0 and "aborted" not in scrub.get("status", "").lower()
          return scrub

      def read_btrfs_usage(mount):
          usage = {}
          try:
              output = run_text(["${pkgs.btrfs-progs}/bin/btrfs", "filesystem", "usage", "-h", mount])
          except Exception as e:
              return {"ok": False, "error": str(e)}
          for raw in output.splitlines():
              line = raw.strip()
              if ":" not in line:
                  continue
              key, value = [part.strip() for part in line.split(":", 1)]
              if key == "Device size":
                  usage["deviceSize"] = value
              elif key == "Device allocated":
                  usage["deviceAllocated"] = value
              elif key == "Device unallocated":
                  usage["deviceUnallocated"] = value
              elif key == "Used":
                  usage["used"] = value
              elif key == "Free (estimated)":
                  usage["freeEstimated"] = value
          usage["ok"] = True
          return usage

      def read_btrfs_health():
          rows = []
          for mount in ${btrfsMountsJson}:
              if not os.path.ismount(mount):
                  rows.append({"mount": mount, "ok": False, "status": "not mounted"})
                  continue
              device_stats = read_btrfs_device_stats(mount)
              scrub = read_btrfs_scrub(mount)
              usage = read_btrfs_usage(mount)
              ok = device_stats.get("ok", False) and scrub.get("ok", False) and usage.get("ok", False)
              rows.append({
                  "mount": mount,
                  "ok": ok,
                  "status": "healthy" if ok else "attention",
                  "deviceStats": device_stats,
                  "scrub": scrub,
                  "usage": usage,
              })
          return rows

      def read_top():
          output = subprocess.check_output([
              "${pkgs.procps}/bin/ps", "-eo", "pid=,pcpu=,comm=", "--sort=-pcpu"
          ], text=True)
          rows = []
          for line in output.splitlines()[:5]:
              parts = line.split(None, 2)
              if len(parts) == 3:
                  try:
                      rows.append({"pid": parts[0], "command": parts[2], "cpu": float(parts[1])})
                  except ValueError:
                      continue
          return rows

      def read_temp():
          candidates = []
          for path in Path("/sys/class/hwmon").glob("hwmon*/temp*_input"):
              try:
                  raw = int(path.read_text().strip())
                  if 1000 <= raw <= 125000:
                      label_path = path.with_name(path.name.replace("_input", "_label"))
                      label = label_path.read_text().strip() if label_path.exists() else path.parent.name
                      candidates.append((label, raw / 1000.0))
              except Exception:
                  pass
          for path in Path("/sys/class/thermal").glob("thermal_zone*/temp"):
              try:
                  raw = int(path.read_text().strip())
                  if 1000 <= raw <= 125000:
                      type_path = path.with_name("type")
                      label = type_path.read_text().strip() if type_path.exists() else path.parent.name
                      candidates.append((label, raw / 1000.0))
              except Exception:
                  pass
          if not candidates:
              return None
          preferred = [c for c in candidates if any(x in c[0].lower() for x in ["cpu", "package", "core", "k10", "tctl", "tdie"])]
          label, temp = max(preferred or candidates, key=lambda x: x[1])
          return {"label": label, "celsius": temp}

      def read_uptime():
          with open("/proc/uptime", "r", encoding="utf-8") as f:
              return int(float(f.readline().split()[0]))

      def read_addresses():
          try:
              output = subprocess.check_output(["${pkgs.iproute2}/bin/ip", "-j", "-4", "addr", "show", "scope", "global"], text=True)
              data = json.loads(output)
          except Exception:
              return {"lan": None, "tailnet": None}
          lan = None
          tailnet = None
          tailnet_net = ipaddress.ip_network("100.64.0.0/10")
          for iface in data:
              ifname = iface.get("ifname", "")
              for addr in iface.get("addr_info", []):
                  ip = addr.get("local")
                  if not ip:
                      continue
                  ip_obj = ipaddress.ip_address(ip)
                  if ip_obj in tailnet_net or ifname.startswith("tailscale"):
                      tailnet = tailnet or ip
                  elif ip_obj.is_private:
                      lan = lan or ip
          return {"lan": lan, "tailnet": tailnet}

      def sse_event(message):
          return ("data: " + message.replace("\n", "\ndata: ") + "\n\n").encode("utf-8")

      async def broadcast(message):
          dead = []
          packet = sse_event(message)
          for writer in list(clients):
              try:
                  writer.write(packet)
                  await writer.drain()
              except Exception:
                  dead.append(writer)
          for writer in dead:
              clients.discard(writer)
              try:
                  writer.close()
                  await writer.wait_closed()
              except Exception:
                  pass

      async def keepalive_loop():
          while True:
              await asyncio.sleep(15)
              dead = []
              for writer in list(clients):
                  try:
                      writer.write(b": keepalive\n\n")
                      await writer.drain()
                  except Exception:
                      dead.append(writer)
              for writer in dead:
                  clients.discard(writer)
                  try:
                      writer.close()
                      await writer.wait_closed()
                  except Exception:
                      pass

      async def stats_loop():
          global latest_payload
          previous_total, previous_idle = read_cpu()
          await asyncio.sleep(1)
          while True:
              total, idle = read_cpu()
              total_delta = total - previous_total
              idle_delta = idle - previous_idle
              cpu_percent = (100.0 * (total_delta - idle_delta) / total_delta) if total_delta else 0.0
              previous_total, previous_idle = total, idle

              payload = {
                  "updatedAt": int(time.time()),
                  "cpuPercent": round(cpu_percent, 1),
                  "memory": read_mem(),
                  "topProcesses": read_top(),
                  "filesystems": read_df(),
                  "btrfsHealth": read_btrfs_health(),
                  "cpuTemp": read_temp(),
                  "uptimeSeconds": read_uptime(),
                  "networkAddresses": read_addresses(),
              }
              latest_payload = json.dumps(payload, separators=(",", ":"))
              tmp = out_file.with_suffix(".json.tmp")
              out_dir.mkdir(parents=True, exist_ok=True)
              tmp.write_text(latest_payload, encoding="utf-8")
              os.replace(tmp, out_file)
              await broadcast(latest_payload)
              await asyncio.sleep(5)

      async def handle_sse(reader, writer):
          try:
              data = await reader.readuntil(b"\r\n\r\n")
              request = data.decode("latin1")
              request_line = request.split("\r\n", 1)[0]
              if not request_line.startswith("GET "):
                  writer.write(b"HTTP/1.1 405 Method Not Allowed\r\nConnection: close\r\n\r\n")
                  await writer.drain()
                  writer.close()
                  return
              writer.write((
                  "HTTP/1.1 200 OK\r\n"
                  "Content-Type: text/event-stream; charset=utf-8\r\n"
                  "Cache-Control: no-store\r\n"
                  "Connection: keep-alive\r\n"
                  "X-Accel-Buffering: no\r\n\r\n"
              ).encode("ascii"))
              await writer.drain()
              clients.add(writer)
              if latest_payload:
                  writer.write(sse_event(latest_payload))
                  await writer.drain()
              while True:
                  data = await reader.read(1024)
                  if not data:
                      break
          except Exception:
              pass
          finally:
              clients.discard(writer)
              try:
                  writer.close()
                  await writer.wait_closed()
              except Exception:
                  pass

      async def main():
          out_dir.mkdir(parents=True, exist_ok=True)
          server = await asyncio.start_server(handle_sse, "127.0.0.1", 8090)
          async with server:
              await asyncio.gather(server.serve_forever(), stats_loop(), keepalive_loop())

      asyncio.run(main())
    '';
  };
  homepage = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>// ${hostLabel}</title>
        <style>
          :root {
            color-scheme: light;
            --bg: #e9e9e5;
            --paper: #f4f3ef;
            --tile: #f8f7f2;
            --ink: #25292c;
            --muted: #71787d;
            --line: #cfd2cf;
            --line-dark: #9ea4a4;
            --black: #1e2021;
            --yellow: #ffd91f;
            --yellow-deep: #f0b400;
            --cyan: #21a4c6;
            --purple: #8d5be8;
            --green: #9bc245;
            --orange: #f08a24;
          }

          * { box-sizing: border-box; }

          body {
            margin: 0;
            min-height: 100vh;
            font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            color: var(--ink);
            background:
              linear-gradient(rgba(70, 76, 80, 0.045) 1px, transparent 1px),
              linear-gradient(90deg, rgba(70, 76, 80, 0.045) 1px, transparent 1px),
              radial-gradient(circle at 18% 18%, rgba(255,255,255,0.9), transparent 28rem),
              var(--bg);
            background-size: 44px 44px, 44px 44px, auto, auto;
          }

          body::before {
            content: "";
            position: fixed;
            inset: 0;
            pointer-events: none;
            background:
              repeating-linear-gradient(-28deg, transparent 0 7px, rgba(40,42,43,0.018) 7px 8px),
              linear-gradient(180deg, rgba(255,255,255,0.62), transparent 32%);
          }

          main {
            position: relative;
            width: 100vw;
            min-height: 100vh;
            margin: 0;
            padding: 0;
          }

          .hero {
            position: relative;
            min-height: 5.3rem;
            display: grid;
            align-items: center;
            margin-bottom: 1.15rem;
            padding: 0.9rem 1.25rem;
            overflow: hidden;
            background:
              linear-gradient(135deg, #58c2dc, #1d8faa 58%, #157590);
            border: 1px solid rgba(20,88,108,0.20);
            box-shadow: 0 0.55rem 1.25rem rgba(28,138,166,0.16);
          }

          .hero::after {
            content: "";
            position: absolute;
            inset: 0;
            pointer-events: none;
            background: repeating-linear-gradient(90deg, transparent 0 2.5rem, rgba(255,255,255,0.08) 2.5rem 2.56rem);
          }

          .hero-copy {
            position: relative;
            z-index: 1;
            color: rgba(255,255,255,0.82);
            display: flex;
            flex-direction: column;
            justify-content: center;
          }

          h1 {
            margin: 0;
            color: white;
            font-size: clamp(1.5rem, 3.5vw, 2.8rem);
            font-weight: 620;
            letter-spacing: -0.035em;
          }

          .subtitle {
            margin-top: 0.08rem;
            font-size: 0.68rem;
            letter-spacing: 0.18em;
            text-transform: uppercase;
            color: rgba(255,255,255,0.72);
          }

          .workspace {
            display: grid;
            grid-template-columns: 3.1rem minmax(0, 1fr);
            column-gap: 1.25rem;
            row-gap: 2.2rem;
            padding-right: 1rem;
            padding-bottom: 2rem;
          }

          .section-icon {
            display: flex;
            justify-content: flex-end;
            align-items: flex-start;
            padding-top: 0.1rem;
            border-right: 1px solid var(--line);
          }

          .rail-item {
            position: sticky;
            top: 0.9rem;
            width: 2.25rem;
            height: 2.25rem;
            display: grid;
            place-items: center;
            background: #2f3335;
            color: white;
            box-shadow: 0 0.35rem 0.75rem rgba(0,0,0,0.16);
            border: 0;
            cursor: pointer;
            transition: background 140ms ease, color 140ms ease, transform 140ms ease;
          }

          .rail-item:hover,
          .rail-item:focus-visible {
            transform: translateY(-0.08rem);
            outline: none;
          }

          .rail-item.active {
            background: var(--yellow);
            color: var(--ink);
          }


          .rail-item svg { width: 1.25rem; height: 1.25rem; stroke: currentColor; fill: none; stroke-width: 2; }

          .content {
            min-width: 0;
          }

          .category {
            margin: 0;
          }

          .category-title {
            display: flex;
            align-items: center;
            gap: 0.7rem;
            margin: 0 0 1.15rem;
            color: rgba(37,41,44,0.78);
            font-size: 1.25rem;
            font-weight: 620;
          }

          .category-title::after {
            content: "";
            height: 1px;
            flex: 1;
            background: linear-gradient(90deg, var(--line), transparent);
          }

          .cards {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(8.4rem, 9.4rem));
            gap: 0.9rem;
            align-items: start;
          }

          .service-card {
            position: relative;
            min-height: 8.4rem;
            display: grid;
            grid-template-rows: 1fr auto auto;
            color: inherit;
            text-decoration: none;
            background: var(--tile);
            border: 1px solid rgba(62,67,70,0.16);
            box-shadow: 0 0.35rem 0.8rem rgba(45,49,51,0.10);
            transition: transform 140ms ease, box-shadow 140ms ease;
          }

          .service-card:hover,
          .service-card:focus-visible {
            transform: translateY(-0.18rem);
            box-shadow: 0 0.65rem 1.1rem rgba(45,49,51,0.14);
            outline: none;
          }

          .stock {
            position: absolute;
            top: 0.45rem;
            left: 0.45rem;
            z-index: 2;
            padding: 0.08rem 0.28rem;
            color: rgba(37,41,44,0.58);
            background: rgba(255,255,255,0.56);
            border: 1px solid rgba(37,41,44,0.10);
            border-radius: 0.12rem;
            font-size: 0.62rem;
            font-weight: 650;
          }

          .art {
            min-height: 5.45rem;
            display: grid;
            place-items: center;
            padding: 1.25rem 0.6rem 0.35rem;
            background:
              radial-gradient(circle at 50% 48%, rgba(255,255,255,0.95), transparent 42%),
              repeating-linear-gradient(-20deg, transparent 0 6px, rgba(35,40,42,0.026) 6px 7px);
          }

          .plate {
            width: 3.25rem;
            height: 3.25rem;
            display: grid;
            place-items: center;
            background: transparent;
          }

          .plate.yellow {
            background: transparent;
          }

          .plate svg {
            width: 2rem;
            height: 2rem;
            stroke: #2b2f31;
            stroke-width: 1.85;
            fill: none;
            stroke-linecap: square;
            stroke-linejoin: miter;
          }

          .service-name {
            min-height: 2rem;
            display: grid;
            place-items: center;
            padding: 0.25rem 0.4rem;
            background: rgba(30, 32, 33, 0.76);
            color: rgba(255,255,255,0.94);
            text-align: center;
            font-size: 0.78rem;
            line-height: 1.05;
            font-weight: 620;
          }

          .accent {
            height: 0.18rem;
            background: var(--cyan);
            align-self: end;
          }
          .accent.home { background: var(--orange); }
          .accent.media { background: var(--purple); }
          .accent.agent { background: var(--cyan); }
          .accent.automation { background: var(--green); }
          .accent.sync { background: var(--green); }
          .accent.transfer { background: var(--yellow-deep); }
          .accent.video { background: var(--cyan); }
          .accent.storage { background: #9aa1a3; }


          .stats-panel {
            padding: 0 1rem 1.2rem 0;
          }

          .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(10.5rem, 1fr));
            gap: 0.75rem;
          }

          .stat-card {
            min-height: 5.4rem;
            padding: 0.75rem 0.85rem;
            background: rgba(248,247,242,0.86);
            border: 1px solid rgba(62,67,70,0.15);
            box-shadow: 0 0.25rem 0.65rem rgba(45,49,51,0.08);
          }

          .stat-label {
            color: rgba(37,41,44,0.54);
            font-size: 0.62rem;
            font-weight: 720;
            letter-spacing: 0.14em;
            text-transform: uppercase;
          }

          .stat-value {
            margin-top: 0.35rem;
            font-size: 1.35rem;
            font-weight: 620;
            letter-spacing: -0.035em;
          }

          .meter {
            height: 0.22rem;
            margin-top: 0.55rem;
            background: rgba(37,41,44,0.10);
          }

          .meter span {
            display: block;
            width: var(--value, 0%);
            max-width: 100%;
            height: 100%;
            background: var(--cyan);
          }

          .stat-list {
            margin: 0.55rem 0 0;
            padding: 0;
            list-style: none;
            color: rgba(37,41,44,0.72);
            font-size: 0.72rem;
            line-height: 1.45;
          }

          .stat-list li {
            display: flex;
            justify-content: space-between;
            gap: 0.7rem;
            border-top: 1px solid rgba(37,41,44,0.07);
            padding-top: 0.18rem;
            margin-top: 0.18rem;
          }

          .stat-list code {
            font-family: "SFMono-Regular", ui-monospace, Menlo, Consolas, monospace;
            color: rgba(37,41,44,0.78);
          }

          .stats-wide { grid-column: span 2; }

          .stat-combo {
            display: grid;
            gap: 0.55rem;
          }

          .stat-cell + .stat-cell {
            border-top: 1px solid rgba(37,41,44,0.08);
            padding-top: 0.55rem;
          }

          .health-list {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(17rem, 1fr));
            gap: 0.75rem;
          }

          .health-card {
            display: grid;
            gap: 0.7rem;
            padding: 0.85rem;
            background: rgba(248,247,242,0.86);
            border: 1px solid rgba(62,67,70,0.15);
            box-shadow: 0 0.25rem 0.65rem rgba(45,49,51,0.08);
          }

          .health-head {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 0.8rem;
          }

          .health-mount {
            font-family: "SFMono-Regular", ui-monospace, Menlo, Consolas, monospace;
            font-size: 1rem;
            font-weight: 680;
          }

          .health-pill {
            flex: 0 0 auto;
            padding: 0.18rem 0.45rem;
            background: rgba(155,194,69,0.18);
            border: 1px solid rgba(94,133,33,0.24);
            color: #4f7219;
            font-size: 0.62rem;
            font-weight: 760;
            letter-spacing: 0.12em;
            text-transform: uppercase;
          }

          .health-card.attention .health-pill {
            background: rgba(240,138,36,0.18);
            border-color: rgba(174,87,18,0.28);
            color: #99530e;
          }

          .health-facts {
            display: grid;
            grid-template-columns: repeat(2, minmax(0, 1fr));
            gap: 0.6rem;
          }

          .health-fact {
            min-width: 0;
            padding-top: 0.45rem;
            border-top: 1px solid rgba(37,41,44,0.08);
          }

          .health-fact strong {
            display: block;
            color: rgba(37,41,44,0.54);
            font-size: 0.58rem;
            font-weight: 740;
            letter-spacing: 0.12em;
            text-transform: uppercase;
          }

          .health-fact span {
            display: block;
            margin-top: 0.2rem;
            color: rgba(37,41,44,0.76);
            font-size: 0.76rem;
            line-height: 1.3;
            overflow-wrap: anywhere;
          }

          @media (max-width: 760px) {
            .stats-wide { grid-column: span 1; }
          }

          @media (max-width: 760px) {
            .workspace { grid-template-columns: 1fr; }
            .section-icon { display: none; }
            .cards { grid-template-columns: repeat(auto-fill, minmax(8.2rem, 1fr)); }
          }
        </style>
      </head>
      <body>
        <main>
          <section class="hero" aria-label="Gaia portal header">
            <div class="hero-copy">
              <h1>// ${hostLabel}</h1>
              <div class="subtitle">LAN <span id="lan-address">detecting</span> · Tailnet <span id="tailnet-address">detecting</span> · HTTP :80</div>
            </div>
          </section>

          <section class="workspace">
            <div class="section-icon" aria-hidden="true"><button class="rail-item active" type="button" data-target="core-title" aria-label="Core"><svg viewBox="0 0 24 24"><rect x="5" y="5" width="5" height="5"/><rect x="14" y="5" width="5" height="5"/><rect x="5" y="14" width="5" height="5"/><path d="M16.5 14v5M14 16.5h5"/></svg></button></div>
            <section class="category" aria-labelledby="core-title">
                <h2 class="category-title" id="core-title">Core</h2>
                <div class="cards">
                  <a class="service-card" href="http://${hostName}:8123/">
                    <span class="stock">Port 8123</span><span class="art"><span class="plate yellow"><svg viewBox="0 0 24 24"><path d="M4 11 12 4l8 7"/><path d="M6 10v9h12v-9"/><path d="M10 19v-5h4v5"/></svg></span></span><span class="accent home"></span><span class="service-name">Home Assistant</span>
                  </a>
                  <a class="service-card" href="/matter-layer/" data-lan-href="http://${hostName}:3010/" data-lan-label="Port 3010" data-wan-href="/matter-layer/" data-wan-label="/matter-layer">
                    <span class="stock">/matter-layer</span><span class="art"><span class="plate"><svg viewBox="0 0 24 24"><path d="M5 12h4"/><path d="M15 12h4"/><path d="M12 5v4"/><path d="M12 15v4"/><circle cx="12" cy="12" r="3"/><path d="M7.5 7.5 9.8 9.8"/><path d="m14.2 14.2 2.3 2.3"/><path d="m16.5 7.5-2.3 2.3"/><path d="m9.8 14.2-2.3 2.3"/></svg></span></span><span class="accent automation"></span><span class="service-name">Matter Layer</span>
                  </a>
                  <a class="service-card" href="/matterjs/" data-lan-href="http://${hostName}:${toString matterjsWebPort}/" data-lan-label="Port ${toString matterjsWebPort}" data-wan-href="/matterjs/" data-wan-label="/matterjs">
                    <span class="stock">/matterjs</span><span class="art"><span class="plate"><svg viewBox="0 0 24 24"><path d="M4 12h4"/><path d="M16 12h4"/><path d="M12 4v4"/><path d="M12 16v4"/><circle cx="12" cy="12" r="2.5"/><path d="M7 7l2 2"/><path d="M15 15l2 2"/><path d="M17 7l-2 2"/><path d="M9 15l-2 2"/></svg></span></span><span class="accent automation"></span><span class="service-name">Matter.js</span>
                  </a>
                  <a class="service-card" href="https://${hostName}:18789/">
                    <span class="stock">Port 18789</span><span class="art"><span class="plate"><svg viewBox="0 0 24 24"><rect x="5" y="7" width="14" height="10"/><path d="M9 7V4h6v3"/><path d="M9 12h.1M15 12h.1"/><path d="M10 16h4"/></svg></span></span><span class="accent agent"></span><span class="service-name">OpenClaw</span>
                  </a>
                  <a class="service-card" href="/otbr/" data-lan-href="http://${hostName}:${toString otbrWebPort}/" data-lan-label="Port ${toString otbrWebPort}" data-wan-href="/otbr/" data-wan-label="/otbr">
                    <span class="stock">/otbr</span><span class="art"><span class="plate"><svg viewBox="0 0 24 24"><path d="M12 5v4"/><path d="M12 15v4"/><path d="M5 12h4"/><path d="M15 12h4"/><circle cx="12" cy="12" r="3"/><path d="M6.5 6.5 9 9"/><path d="m15 15 2.5 2.5"/><path d="m17.5 6.5-2.5 2.5"/><path d="m9 15-2.5 2.5"/></svg></span></span><span class="accent sync"></span><span class="service-name">OpenThread BR</span>
                  </a>
                  <a class="service-card" href="http://${hostName}:9091/">
                    <span class="stock">Port 9091</span><span class="art"><span class="plate"><svg viewBox="0 0 24 24"><path d="M12 4v12"/><path d="m7 11 5 5 5-5"/><path d="M5 20h14"/></svg></span></span><span class="accent transfer"></span><span class="service-name">Transmission</span>
                  </a>
                  <a class="service-card" href="/blackvue/" data-lan-href="http://${hostName}:3000/" data-lan-label="Port 3000" data-wan-href="/blackvue/" data-wan-label="/blackvue">
                    <span class="stock">/blackvue</span><span class="art"><span class="plate"><svg viewBox="0 0 24 24"><rect x="4" y="7" width="11" height="10"/><path d="m15 10 5-2v8l-5-2"/><path d="M8 17v3h4v-3"/></svg></span></span><span class="accent video"></span><span class="service-name">BlackVue Viewer</span>
                  </a>
                  <a class="service-card" href="/jellyfin/" data-lan-href="http://${hostName}:8096/" data-lan-label="Port 8096" data-wan-href="/jellyfin/" data-wan-label="/jellyfin">
                    <span class="stock">/jellyfin</span><span class="art"><span class="plate"><svg viewBox="0 0 24 24"><rect x="4" y="6" width="16" height="12" rx="1"/><path d="m10 10 5 2-5 2z"/><path d="M7 21h10"/><path d="M12 18v3"/></svg></span></span><span class="accent media"></span><span class="service-name">Jellyfin</span>
                  </a>
                  <a class="service-card" href="http://${hostName}:8083/">
                    <span class="stock">Port 8083</span><span class="art"><span class="plate"><svg viewBox="0 0 24 24"><path d="M5 5h11a3 3 0 0 1 3 3v11H8a3 3 0 0 1-3-3z"/><path d="M8 5v11a3 3 0 0 0 3 3"/><path d="M9 9h6"/><path d="M9 12h5"/></svg></span></span><span class="accent media"></span><span class="service-name">Kavita</span>
                  </a>
                </div>
            </section>

            <div class="section-icon" aria-hidden="true"><button class="rail-item" type="button" data-target="utility-title" aria-label="Sync"><svg viewBox="0 0 24 24"><path d="M7 8a6 6 0 0 1 10 2"/><path d="m17 6 1 4-4 1"/><path d="M17 16a6 6 0 0 1-10-2"/><path d="m7 18-1-4 4-1"/></svg></button></div>
            <section class="category" aria-labelledby="utility-title">
                <h2 class="category-title" id="utility-title">Sync</h2>
                <div class="cards">
                  <a class="service-card" href="http://${hostName}:2283/">
                    <span class="stock">Port 2283</span><span class="art"><span class="plate"><svg viewBox="0 0 24 24"><rect x="4" y="5" width="16" height="14"/><circle cx="9" cy="10" r="1.5"/><path d="m6 17 4-4 3 3 2-2 3 3"/></svg></span></span><span class="accent media"></span><span class="service-name">Immich</span>
                  </a>
                  <a class="service-card" href="http://${hostName}:8384/">
                    <span class="stock">Port 8384</span><span class="art"><span class="plate yellow"><svg viewBox="0 0 24 24"><path d="M7 8a6 6 0 0 1 10 2"/><path d="m17 6 1 4-4 1"/><path d="M17 16a6 6 0 0 1-10-2"/><path d="m7 18-1-4 4-1"/></svg></span></span><span class="accent sync"></span><span class="service-name">Syncthing</span>
                  </a>
                  <a class="service-card" href="smb://${hostName}/${sambaShare}/">
                    <span class="stock">Port 445</span><span class="art"><span class="plate"><svg viewBox="0 0 24 24"><path d="M4 7h16v10H4z"/><path d="M7 7V5h10v2"/><path d="M8 17v2h8v-2"/></svg></span></span><span class="accent storage"></span><span class="service-name">Samba Share</span>
                  </a>
                  <a class="service-card" href="http://${hostName}:17200/healthcheck">
                    <span class="stock">Port 17200</span><span class="art"><span class="plate yellow"><svg viewBox="0 0 24 24"><path d="M7 8a6 6 0 0 1 10 2"/><path d="m17 6 1 4-4 1"/><path d="M17 16a6 6 0 0 1-10-2"/><path d="m7 18-1-4 4-1"/><path d="M12 8v5l3 2"/></svg></span></span><span class="accent sync"></span><span class="service-name">KOReader Sync</span>
                  </a>
                </div>
            </section>

            <div class="section-icon" aria-hidden="true"><button class="rail-item" type="button" data-target="stats-title" aria-label="Stats"><svg viewBox="0 0 24 24"><path d="M4 15h3l2-6 3 10 2-7h6"/><path d="M5 20h14"/></svg></button></div>
            <section class="stats-panel" aria-labelledby="stats-title">
                <h2 class="category-title" id="stats-title">Stats</h2>
                <div class="stats-grid">
                  <div class="stat-card stat-combo">
                    <div class="stat-cell"><div class="stat-label">CPU</div><div class="stat-value" id="cpu">--%</div><div class="meter"><span id="cpu-meter"></span></div></div>
                    <div class="stat-cell"><div class="stat-label">RAM</div><div class="stat-value" id="ram">--%</div><div class="meter"><span id="ram-meter"></span></div></div>
                    <div class="stat-cell"><div class="stat-label">Temp</div><div class="stat-value" id="temp">--</div></div>
                  </div>
                  <div class="stat-card"><div class="stat-label">Uptime</div><div class="stat-value" id="uptime">--</div></div>
                  <div class="stat-card stats-wide"><div class="stat-label">Top CPU</div><ul class="stat-list" id="top-procs"></ul></div>
                  <div class="stat-card stats-wide"><div class="stat-label">Disk</div><ul class="stat-list" id="df"></ul></div>
                </div>
            </section>

            <div class="section-icon" aria-hidden="true"><button class="rail-item" type="button" data-target="btrfs-title" aria-label="BTRFS Health"><svg viewBox="0 0 24 24"><rect x="5" y="4" width="14" height="16"/><path d="M8 8h8"/><path d="M8 12h8"/><path d="M8 16h3"/><path d="m14 16 1.6 1.6L19 14"/></svg></button></div>
            <section class="stats-panel" aria-labelledby="btrfs-title">
                <h2 class="category-title" id="btrfs-title">BTRFS Health</h2>
                <div class="health-list" id="btrfs-health"></div>
            </section>
          </section>
        </main>

        <script>
          const isPrivateIpv4 = (hostname) => {
            const parts = hostname.split('.').map((part) => Number(part));
            if (parts.length !== 4 || parts.some((part) => !Number.isInteger(part) || part < 0 || part > 255)) return false;
            return parts[0] === 10 ||
              parts[0] === 127 ||
              (parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31) ||
              (parts[0] === 192 && parts[1] === 168);
          };
          const isLanHostname = (hostname) => {
            const host = hostname.toLowerCase().replace(/^\[/, "").replace(/\]$/, "");
            return host === '${hostName}' ||
              host === '${hostName}.local' ||
              host === 'localhost' ||
              host.startsWith('fe80:') ||
              host.startsWith('fd') ||
              isPrivateIpv4(host);
          };
          const applyServiceLinkMode = () => {
            const mode = isLanHostname(window.location.hostname) ? 'lan' : 'wan';
            document.querySelectorAll('[data-lan-href][data-wan-href]').forEach((card) => {
              const href = card.dataset[mode + 'Href'];
              const label = card.dataset[mode + 'Label'];
              const stock = card.querySelector('.stock');
              if (href) card.href = href;
              if (label && stock) stock.textContent = label;
            });
          };
          applyServiceLinkMode();
          const fmtBytes = (bytes) => {
            const gib = bytes / 1024 / 1024 / 1024;
            return gib.toFixed(gib >= 10 ? 0 : 1) + " GiB";
          };
          const fmtUptime = (seconds) => {
            const d = Math.floor(seconds / 86400);
            const h = Math.floor((seconds % 86400) / 3600);
            const m = Math.floor((seconds % 3600) / 60);
            return d ? (d + "d " + h + "h") : (h + "h " + m + "m");
          };
          const setMeter = (id, value) => {
            document.getElementById(id).style.setProperty('--value', Math.max(0, Math.min(100, value)) + '%');
          };
          const addFact = (parent, label, value) => {
            const fact = document.createElement('div');
            fact.className = 'health-fact';
            const strong = document.createElement('strong');
            strong.textContent = label;
            const span = document.createElement('span');
            span.textContent = value || 'n/a';
            fact.append(strong, span);
            parent.appendChild(fact);
          };

          const renderBtrfsHealth = (items) => {
            const root = document.getElementById('btrfs-health');
            root.textContent = "";
            if (!items || !items.length) {
              const empty = document.createElement('div');
              empty.className = 'health-card attention';
              empty.textContent = 'No BTRFS mounts are declared for this host.';
              root.appendChild(empty);
              return;
            }
            items.forEach((item) => {
              const card = document.createElement('article');
              card.className = 'health-card' + (item.ok ? "" : ' attention');
              const head = document.createElement('div');
              head.className = 'health-head';
              const mount = document.createElement('div');
              mount.className = 'health-mount';
              mount.textContent = item.mount;
              const pill = document.createElement('div');
              pill.className = 'health-pill';
              pill.textContent = item.status || (item.ok ? 'healthy' : 'attention');
              head.append(mount, pill);
              const facts = document.createElement('div');
              facts.className = 'health-facts';
              const usage = item.usage || {};
              const scrub = item.scrub || {};
              const deviceStats = item.deviceStats || {};
              const errors = deviceStats.errors || [];
              const errorText = errors.length ? errors.map((err) => err.name + ': ' + err.count).join(', ') : '0';
              addFact(facts, 'Used', usage.used || 'unknown');
              addFact(facts, 'Free est.', usage.freeEstimated || 'unknown');
              addFact(facts, 'Scrub', scrub.status || 'unknown');
              addFact(facts, 'Errors', errorText);
              if (scrub.errorCount) addFact(facts, 'Scrub errors', String(scrub.errorCount));
              if (usage.error) addFact(facts, 'Usage check', usage.error);
              if (scrub.error) addFact(facts, 'Scrub check', scrub.error);
              if (deviceStats.error) addFact(facts, 'Device stats', deviceStats.error);
              card.append(head, facts);
              root.appendChild(card);
            });
          };

          const railItems = Array.from(document.querySelectorAll('.rail-item'));
          const sections = railItems.map((item) => document.getElementById(item.dataset.target)).filter(Boolean);
          railItems.forEach((item) => {
            item.addEventListener('click', () => {
              document.getElementById(item.dataset.target).scrollIntoView({ behavior: 'smooth', block: 'start' });
            });
          });
          const setActiveRail = () => {
            const current = sections.reduce((best, section) => {
              const top = Math.abs(section.getBoundingClientRect().top - 16);
              return !best || top < best.top ? { id: section.id, top } : best;
            }, null);
            railItems.forEach((item) => item.classList.toggle('active', current && item.dataset.target === current.id));
          };
          setActiveRail();
          document.addEventListener('scroll', setActiveRail, { passive: true });
          window.addEventListener('resize', setActiveRail);
          function renderStats(stats) {
            document.getElementById('cpu').textContent = stats.cpuPercent.toFixed(1) + '%';
            setMeter('cpu-meter', stats.cpuPercent);
            document.getElementById('ram').textContent = stats.memory.percent.toFixed(1) + '%';
            document.getElementById('ram').title = fmtBytes(stats.memory.used) + ' / ' + fmtBytes(stats.memory.total);
            setMeter('ram-meter', stats.memory.percent);
            document.getElementById('temp').textContent = stats.cpuTemp ? (stats.cpuTemp.celsius.toFixed(1) + '°C') : 'n/a';
            document.getElementById('uptime').textContent = fmtUptime(stats.uptimeSeconds);
            document.getElementById('top-procs').innerHTML = stats.topProcesses.map((p) => '<li><code>' + p.command + '</code><span>' + p.cpu.toFixed(1) + '%</span></li>').join("");
            document.getElementById('df').innerHTML = stats.filesystems.map((fs) => '<li><code>' + fs.mount + '</code><span>' + fs.used + '/' + fs.size + ' · ' + fs.percent + '</span></li>').join("");
            renderBtrfsHealth(stats.btrfsHealth);
            if (stats.networkAddresses) {
              document.getElementById('lan-address').textContent = stats.networkAddresses.lan || 'n/a';
              document.getElementById('tailnet-address').textContent = stats.networkAddresses.tailnet || 'n/a';
            }
          }
          async function refreshStatsSnapshot() {
            try {
              const res = await fetch('/stats.json', { cache: 'no-store' });
              if (!res.ok) throw new Error("stats " + res.status);
              renderStats(await res.json());
            } catch (err) {
              document.getElementById('cpu').textContent = 'offline';
            }
          }
          function connectStatsEvents() {
            const events = new EventSource('/stats-events');
            events.onmessage = (event) => renderStats(JSON.parse(event.data));
            events.onerror = () => {
              events.close();
              setTimeout(connectStatsEvents, 2500);
            };
          }
          refreshStatsSnapshot();
          connectStatsEvents();
        </script>
      </body>
    </html>
  '';
in {
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts.gaia-home = {
      default = true;
      listen = homepageListen;
      root = homepage;
      locations."= /stats.json" = {
        alias = "/run/gaia-homepage/stats.json";
        extraConfig = ''
          add_header Cache-Control "no-store";
          add_header X-Content-Type-Options nosniff;
        '';
      };
      locations."/stats-events" = {
        proxyPass = "http://127.0.0.1:8090";
        extraConfig = ''
          proxy_buffering off;
          proxy_cache off;
          add_header Cache-Control "no-store";
          add_header X-Accel-Buffering no;
          add_header X-Content-Type-Options nosniff;
        '';
      };
      locations."= /matter-layer" = {
        return = "302 /matter-layer/";
      };
      locations."/matter-layer/" = {
        proxyPass = "http://127.0.0.1:3010/";
        extraConfig = (proxiedServiceHeaders "/matter-layer") + matterLayerSubstitutions;
      };
      locations."/matter-layer/assets/" = {
        proxyPass = "http://127.0.0.1:3010/assets/";
        extraConfig = (proxiedServiceHeaders "/matter-layer") + matterLayerSubstitutions;
      };
      locations."/matter-layer/src/" = {
        proxyPass = "http://127.0.0.1:3010/src/";
        extraConfig = (proxiedServiceHeaders "/matter-layer") + matterLayerSubstitutions;
      };
      locations."/matter-layer/@vite/" = {
        proxyPass = "http://127.0.0.1:3010/@vite/";
        proxyWebsockets = true;
        extraConfig = (proxiedServiceHeaders "/matter-layer") + matterLayerSubstitutions;
      };
      locations."/matter-layer/@fs/" = {
        proxyPass = "http://127.0.0.1:3010/@fs/";
        extraConfig = (proxiedServiceHeaders "/matter-layer") + matterLayerSubstitutions;
      };
      locations."/matter-layer/node_modules/" = {
        proxyPass = "http://127.0.0.1:3010/node_modules/";
        extraConfig = (proxiedServiceHeaders "/matter-layer") + matterLayerSubstitutions;
      };
      locations."/matter-layer/api/" = {
        proxyPass = "http://127.0.0.1:3010/api/";
        extraConfig = proxiedServiceHeaders "/matter-layer";
      };
      locations."/matter-layer/events" = {
        proxyPass = "http://127.0.0.1:3010/events";
        proxyWebsockets = true;
        extraConfig = proxiedServiceHeaders "/matter-layer";
      };
      locations."= /blackvue" = {
        return = "302 /blackvue/";
      };
      locations."/blackvue/" = {
        proxyPass = "http://127.0.0.1:3000/";
        extraConfig = (proxiedServiceHeaders "/blackvue") + blackvueSubstitutions;
      };
      locations."/blackvue/assets/" = {
        proxyPass = "http://127.0.0.1:3000/assets/";
        extraConfig = (proxiedServiceHeaders "/blackvue") + blackvueSubstitutions;
      };
      locations."/blackvue/api/" = {
        proxyPass = "http://127.0.0.1:3000/api/";
        extraConfig = (proxiedServiceHeaders "/blackvue") + blackvueSubstitutions;
      };
      locations."= /jellyfin" = {
        return = "302 /jellyfin/";
      };
      locations."/jellyfin/" = {
        proxyPass = "http://127.0.0.1:8096/";
        proxyWebsockets = true;
        extraConfig = proxiedServiceHeaders "/jellyfin";
      };
      locations."= /otbr" = {
        return = "302 /otbr/";
      };
      locations."/otbr/" = {
        proxyPass = "http://127.0.0.1:${toString otbrUpstreamPort}/";
        extraConfig = proxiedServiceHeaders "/otbr";
      };
      locations."= /matterjs" = {
        return = "302 /matterjs/";
      };
      locations."/matterjs/" = {
        proxyPass = "http://127.0.0.1:${toString matterjsWebPort}/";
        proxyWebsockets = true;
        extraConfig = proxiedServiceHeaders "/matterjs";
      };
      extraConfig = ''
        add_header X-Content-Type-Options nosniff;
      '';
    };

    virtualHosts.otbr-web = {
      listen = otbrWebListen;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString otbrUpstreamPort}";
      };
      extraConfig = ''
        add_header X-Content-Type-Options nosniff;
      '';
    };
  };

  systemd.services.gaia-homepage-stats = {
    description = "Gaia homepage live stats writer";
    wantedBy = ["multi-user.target"];
    after = ["local-fs.target"];
    serviceConfig = {
      ExecStart = statsCollector;
      Restart = "always";
      RestartSec = "2s";
      RuntimeDirectory = "gaia-homepage";
      RuntimeDirectoryMode = "0755";
    };
  };

  networking.firewall.allowedTCPPorts = [80 otbrWebPort];
}
