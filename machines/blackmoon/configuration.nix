{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../nvidia.nix
    ./uni-sync.nix
  ];

  networking.hostName = "blackmoon";
  environment.systemPackages =
    (with pkgs; [
      bolt
      cage

      samba
      spacenavd
      imagemagick
    ])
    ++ [
      (pkgs.writeShellScriptBin "scanpdf" ''
        set -euo pipefail

        if [ $# -ne 1 ]; then
          echo "usage: scanpdf <output.pdf>" >&2
          exit 2
        fi

        out="$1"
        tmp="$(mktemp -d)"
        cleanup() { rm -rf "$tmp"; }
        trap cleanup EXIT

        device_arg=()
        if [ -n "''${SCANIMAGE_DEVICE:-}" ]; then
          device_arg=(-d "$SCANIMAGE_DEVICE")
        fi

        if [ -e "$out" ]; then
          read -r -p "File exists: $out. [a]ppend/[o]verwrite/[q]uit: " choice < /dev/tty || choice="q"
          case "$choice" in
            a|A) mode="append" ;;
            o|O) mode="overwrite" ;;
            q|Q|*) echo "Aborted." >&2; exit 1 ;;
          esac
        else
          mode="overwrite"
        fi

        echo "Scanning to $out"
        echo "Set SCANIMAGE_DEVICE to override the device (from scanimage -L)."
        echo "Waiting for scanner button. Press 'q' to finish."

        page=1
        while true; do
          file="$tmp/page-$(printf "%04d" "$page").pnm"
          echo "Ready for page $page..."

          ${pkgs.sane-backends}/bin/scanimage "''${device_arg[@]}" --resolution 300 --format=pnm > "$file" &
          pid=$!
          quit=0

          while kill -0 "$pid" 2>/dev/null; do
            if read -r -t 0.2 -n 1 key < /dev/tty; then
              if [ "''${key}" = "q" ] || [ "''${key}" = "Q" ]; then
                quit=1
                break
              fi
            fi
          done

          if [ "$quit" -eq 1 ]; then
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
            rm -f "$file"
            break
          fi

          if ! wait "$pid" 2>/dev/null; then
            rm -f "$file"
            echo "Scan failed (device disconnected?). Waiting..." >&2
            sleep 1
            continue
          fi

          if [ ! -s "$file" ]; then
            rm -f "$file"
          else
            page=$((page + 1))
          fi
        done

        if [ "$page" -eq 1 ]; then
          echo "No pages scanned." >&2
          exit 1
        fi

        if [ "$mode" = "append" ]; then
          tmp_pdf="$tmp/new-pages.pdf"
          ${pkgs.imagemagick}/bin/convert "$tmp"/page-*.pnm "$tmp_pdf"
          ${pkgs.imagemagick}/bin/convert "$out" "$tmp_pdf" "$out"
        else
          ${pkgs.imagemagick}/bin/convert "$tmp"/page-*.pnm "$out"
        fi
        echo "Wrote $out"
      '')
      (pkgs.writeShellScriptBin "scanpdf1" ''
        set -euo pipefail

        if [ $# -ne 1 ]; then
          echo "usage: scanpdf1 <output.pdf>" >&2
          exit 2
        fi

        out="$1"
        tmp="$(mktemp -d)"
        cleanup() { rm -rf "$tmp"; }
        trap cleanup EXIT

        device_arg=()
        if [ -n "''${SCANIMAGE_DEVICE:-}" ]; then
          device_arg=(-d "$SCANIMAGE_DEVICE")
        fi

        file="$tmp/page-0001.pnm"
        ${pkgs.sane-backends}/bin/scanimage "''${device_arg[@]}" --resolution 300 --format=pnm > "$file"

        if [ ! -s "$file" ]; then
          echo "No page scanned." >&2
          exit 1
        fi

        ${pkgs.imagemagick}/bin/convert "$file" "$out"
        echo "Wrote $out"
      '')
    ];

  services.hardware.bolt.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "dvorak";
  };

  services.hardware.openrgb.enable = true;

  #v4l2loopback for screen sharing
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=10 card_label="VirtualCam" exclusive_caps=1
  '';
  boot.kernelModules = [
    # sensors for temps
    "nct6775"
    # loopback for screen sharing
    "v4l2loopback"
  ];
  boot.kernelParams = [
    "acpi_enforce_resources=lax"
    # disable GSP for frame stuttering
    "NVreg_EnableGpuFirmware=0"
  ];

  # services for fusion360
  # hardware.spacenavd.enable = true;
  # services.samba.enable = true;
  # consistent udev for highflownext
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="hwmon", ATTRS{idVendor}=="0c70", ATTRS{idProduct}=="f012", ATTRS{serial}=="03550-34834", RUN+="/bin/sh -c 'ln -s /sys$devpath /dev/highflow_next'"
  '';

  # fix sddm, eDP-3 (ultrawide) doesnt show with wayland.
  services.xserver.enable = lib.mkForce true;
  services.displayManager.sddm.wayland.enable = lib.mkForce false;
  # flatpak
  services.flatpak.enable = true;

  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.brscan4 ];
  };

  users.users.brandon.extraGroups = lib.mkAfter [ "scanner" ];

  systemd.tmpfiles.rules = [
    "L+ /opt/brother/scanner/brscan4 - - - - ${pkgs.brscan4}/opt/brother/scanner/brscan4"
    "d /etc/opt/brother/scanner/brscan4 0755 root root - -"
    "C+ /etc/opt/brother/scanner/brscan4/brsanenetdevice4.cfg - - - - ${pkgs.brscan4}/opt/brother/scanner/brscan4/brsanenetdevice4.cfg"
    "C+ /etc/opt/brother/scanner/brscan4/Brsane4.ini - - - - ${pkgs.brscan4}/opt/brother/scanner/brscan4/Brsane4.ini"
  ];

  systemd.services.nvidia-undervolt = {
    description = "Apply slight RTX 4090 underclock/undervolt";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" "nvidia-persistenced.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "${config.system.path}/bin/nvidia-smi -pm 1"
        "${config.system.path}/bin/nvidia-smi -pl 430"
        "${config.system.path}/bin/nvidia-smi --lock-gpu-clocks=2300,2390"
      ];
    };
  };

  system.stateVersion = "24.11";
}
