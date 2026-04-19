{
  config,
  lib,
  pkgs,
  ...
}: let
  perfHosts = [
    "blackmoon"
    "espresso"
    "oasis"
  ];
  desktopPerfHosts = [
    "blackmoon"
  ];
  mobilePerfHosts = [
    "espresso"
    "oasis"
  ];
in {
  config = lib.mkMerge [
    {
      # Pin CPU to performance governor for lower frametime variance during gaming.
      # Use sched_ext with lavd policy for gaming-oriented scheduling behavior.
      services.scx = {
        enable = true;
        scheduler = "scx_lavd";
      };

      # Prefer "none" for NVMe and "kyber" for non-rotational SATA/virt disks.
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="block", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="none"
        ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="kyber"
        ACTION=="add", SUBSYSTEM=="block", KERNEL=="vd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="kyber"
      '';
    }
    (lib.mkIf (builtins.elem config.networking.hostName desktopPerfHosts) {
      powerManagement.cpuFreqGovernor = "performance";
    })
    (lib.mkIf (builtins.elem config.networking.hostName perfHosts) {
      services.irqbalance.enable = true;
      services.ananicy = {
        enable = true;
        package = pkgs.ananicy-cpp;
        rulesProvider = pkgs.ananicy-rules-cachyos;
      };

      zramSwap = {
        enable = true;
        memoryPercent = 50;
        algorithm = "zstd";
      };

      programs.gamemode.settings = {
        general = {
          renice = 15;
          ioprio = 0;
          softrealtime = "auto";
          desiredgov = "performance";
          inhibit_screensaver = 1;
        };
      };

      boot.kernel.sysctl = {
        # Keep swap fallback less eager on gaming desktops with physical swap.
        "vm.swappiness" = 10;
        # Hold onto inode/dentry caches a bit longer to reduce disk churn.
        "vm.vfs_cache_pressure" = 50;
        # Helps avoid VM map exhaustion in some Wine/Proton titles and modded games.
        "vm.max_map_count" = 2147483642;
      };
    })
    (lib.mkIf (builtins.elem config.networking.hostName mobilePerfHosts) {
      systemd.services.ac-power-governor = {
        description = "Set CPU governor based on AC adapter state";
        wantedBy = [ "multi-user.target" ];
        after = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "ac-power-governor" ''
            set -eu

            governor="powersave"
            for supply in /sys/class/power_supply/*; do
              [ -d "$supply" ] || continue
              [ -f "$supply/type" ] || continue
              [ -f "$supply/online" ] || continue
              if [ "$(cat "$supply/type")" = "Mains" ] && [ "$(cat "$supply/online")" = "1" ]; then
                governor="performance"
                break
              fi
            done

            for cpu_gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
              [ -w "$cpu_gov" ] || continue
              printf '%s' "$governor" > "$cpu_gov"
            done
          '';
        };
      };

      services.udev.extraRules = ''
        SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ACTION=="add|change", TAG+="systemd", ENV{SYSTEMD_WANTS}+="ac-power-governor.service"
      '';
    })
  ];
}
