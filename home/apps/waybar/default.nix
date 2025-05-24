{ pkgs, ... }:

{
  nixpkgs.overlays = [ (import ./waybar-cava-overlay.nix) ];

  programs.waybar = {
    enable  = true;
    package = pkgs.waybar;

    settings = {
      mainBar = {
        layer   = "top";
        output  = "!HDMI-A-1";
        height  = 30;
        spacing = 0;

        "modules-left"   = [ "hyprland/workspaces" "custom/media" ];
        "modules-center" = [ "hyprland/window" ];
        "modules-right"  = [
          "memory" "cpu" "temperature#cpu" "temperature#gpu"
            "temperature#water" "cava" "pulseaudio" "network"
            "custom/pacman" "tray" "battery" "clock"
        ];

        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs    = true;
          warp-on-scroll = false;
          format         = "{name}: {icon}";
          format-icons   = {
            urgent  = "";
            focused = "";
            default = "";
          };
        };

        "custom/pacman" = {
          format       = "{icon}{}";
          return-type  = "json";
          format-icons = { "pending-updates" = " "; updated = ""; };
          "exec-if"    = "which waybar-updates";
          exec         = "waybar-updates";
        };

        "keyboard-state" = {
          numlock = true; capslock = true;
          format  = "{name} {icon}";
          format-icons = { locked = ""; unlocked = ""; };
        };

        tray  = { spacing = 10; };
        clock = {
          "tooltip-format" = "{:%Y %B}\n`{calendar}`";
          format           = "{:%I:%M %p}";
        };

        cava = {
          framerate           = 60;
          autosens            = 1;
          bars                = 6;
          lower_cutoff_freq   = 1;
          higher_cutoff_freq  = 10000;
          method              = "pulse";
          source              = "auto";
          stereo              = true;
          reverse             = false;
          bar_delimiter       = 0;
          monstercat          = true;
          waves               = false;
          noise_reduction     = 0.1;
          input_delay         = 0;
          "format-icons"      = [ "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█" ];
          actions             = { "on-click-right" = "mode"; };
        };

        cpu    = { format = "{usage}%"; tooltip = false; };
        memory = { format = "{}% "; };

        "temperature#cpu" = {
          "hwmon-path-abs"  = "/sys/devices/platform/coretemp.0/hwmon";
          "input-filename"  = "temp1_input";
          "critical-threshold" = 80;
          "format-critical" = "{temperatureC}°C {icon}";
          format            = "{temperatureC}°C {icon}";
          "format-icons"    = [ "" ];
        };

        "temperature#gpu" = {
          "hwmon-path-abs"  =
            "/sys/devices/pci0000:00/0000:00:1d.0/0000:72:00.0/nvme/nvme1";
          "input-filename"  = "temp1_input";
          "critical-threshold" = 80;
          "format-critical" = "{temperatureC}°C {icon}";
          format            = "{temperatureC}°C {icon}";
          "format-icons"    = [ "" ];
        };

        "temperature#water" = {
          "hwmon-path-abs"  =
            "/sys/devices/pci0000:00/0000:00:14.0/usb1/1-10/1-10.2/1-10.2.4/1-10.2.4:1.1/0003:0C70:F012.000B/hwmon";
          "input-filename"  = "temp1_input";
          "critical-threshold" = 40;
          "format-critical" = "{temperatureC}°C {icon}";
          format            = "{temperatureC}°C {icon}";
          "format-icons"    = [ "" ];
        };

        network = {
          "format-wifi"        = "";
          "format-ethernet"    = "";
          "tooltip-format"     = "{ifname} via {gwaddr}";
          "format-linked"      = "(No IP)";
          "format-disconnected"= "D/C ⚠";
          "format-alt"         = "{ifname}: {ipaddr}/{cidr}";
        };

        battery = {
          bat      = "ps-controller-battery-58:10:31:1d:a2:43";
          interval = 60;
          states   = { warning = 30; critical = 15; };
          format   = "{capacity}% {icon}";
          "format-icons" = [ "" "" "" "" "" ];
          "max-length" = 25;
        };

        pulseaudio = {
          format                    = "{volume}% {icon} {format_source}";
          "format-bluetooth"        = "{volume}% {icon} {format_source}";
          "format-bluetooth-muted"  = " {icon} {format_source}";
          "format-muted"            = " {format_source}";
          "format-source"           = "";
          "format-source-muted"     = "";
          "format-icons" = {
            headphone   = "";
            "hands-free"= "";
            headset     = "";
            phone       = "";
            portable    = "";
            car         = "";
            default     = [ "" "" "" ];
          };
          "on-click" = "pavucontrol";
        };
      };
    };
  # Optional – you can inline your CSS as well:
  style = ''
window#waybar {
  background-color: rgba(30, 30, 46, 0.5);
  font-family: "Montserrat";
  font-size: 13px;
}

.modules-right > * >.module {
  margin: 0 0.5rem;
}
'';
  };

  # Optional: keep the CLI `cava` program for quick testing
  home.packages = [ pkgs.cava ];

  # Start waybar on login
  wayland.windowManager.hyprland.settings."exec-once" = [
    "waybar"
  ];
}

