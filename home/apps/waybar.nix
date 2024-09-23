{
  programs.waybar = {
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 0;
        modules-left = [
          "hyprland/workspaces"
          "custom/media"
          "hyprland/window"
        ];
        modules-right = [
          "memory"
          "cpu"
          "temperature#cpu"
          "cava"
          "pulseaudio"
          "network"
          "tray"
          "battery"
          "clock"
        ];

        "hyprland/window" = {
          max-length = 50;
        };
        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          warp-on-scroll = false;
          format = "{name}: {icon}";
          format-icons = {
            "urgent" = "";
            "focused" = "";
            "default" = "";
          };
        };

        tray.spacing = 10;

        clock = {
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          format = "{:%I:%M %p}";
        };

        cava = {
          framerate = 60;
          autosens = 1;
          bars = 6;
          lower_cutoff_freq = 1;
          higher_cutoff_freq = 10000;
          method = "pulse";
          source = "auto";
          stereo = true;
          reverse = false;
          bar_delimiter = 0;
          monstercat = true;
          waves = false;
          noise_reduction = 0.1;
          input_delay = 0;
          format-icons = [
            "▁"
            "▂"
            "▃"
            "▄"
            "▅"
            "▆"
            "▇"
            "█"
          ];
          actions= {
            on-click-right = "mode";
          };
        };
        cpu = {
          format = "{usage}%";
          tooltip = false;
        };
        memory = {
          format = "{}% ";
        };
        "temperature#cpu" = {
          hwmon-path-abs = "/sys/devices/pci0000:00/0000:00:08.1/0000:63:00.0/hwmon";
          input-filename = "temp1_input";
          critical-threshold = 80;
          format-critical = "{temperatureC}°C {icon}🔥";
          format = "{temperatureC}°C {icon}";
          format-icons = [""];
        };
        network = {
          format-wifi = "";
          format-ethernet = "🖧";
          tooltip-format = "{ifname} via {gwaddr}";
          format-linked = "(No IP)";
          format-disconnected = "D/C ⚠";
          format-alt = "{ifname}: {ipaddr}/{cidr}";
        };
        pulseaudio = {
          format = "{volume}% {icon} {format_source}";
          format-bluetooth = "{volume}% {icon} {format_source}";
          format-bluetooth-muted = " {icon} {format_source}";
          format-muted = " {format_source}";
          format-source = "";
          format-source-muted = "";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default =  [
              ""
                ""
                ""
            ];
          };
          on-click = "pavucontrol";
        };
        battery = {
          interval = 60;
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{capacity}% {icon}";
          format-charging = "{capacity}% {icon}⚡";
          format-icons = [
            ""
              ""
              ""
              ""
              ""
          ];
        };
      };
    };
    # these are catppuccin, todo: use catppuccin nix pkg
    style = ''

    @define-color rosewater #f5e0dc;
    @define-color flamingo #f2cdcd;
    @define-color pink #f5c2e7;
    @define-color mauve #cba6f7;
    @define-color red #f38ba8;
    @define-color maroon #eba0ac;
    @define-color peach #fab387;
    @define-color yellow #f9e2af;
    @define-color green #a6e3a1;
    @define-color teal #94e2d5;
    @define-color sky #89dceb;
    @define-color sapphire #74c7ec;
    @define-color blue #89b4fa;
    @define-color lavender #b4befe;
    @define-color text #cdd6f4;
    @define-color subtext1 #bac2de;
    @define-color subtext0 #a6adc8;
    @define-color overlay2 #9399b2;
    @define-color overlay1 #7f849c;
    @define-color overlay0 #6c7086;
    @define-color surface2 #585b70;
    @define-color surface1 #45475a;
    @define-color surface0 #313244;
    @define-color base #1e1e2e;
    @define-color mantle #181825;
    @define-color crust #11111b;

    * {
        font-size: 14px;
        min-height: 0;
    }

    #waybar {
        background: transparent;
        color: @text;
    }

    #workspaces {
        background-color: @surface0;
        padding: 0 0.5rem;
    }

    #window {
        background-color: @surface1;
        padding: 0 0.5rem;
    }

    #workspaces button {
        color: @lavender;
        border-radius: 1rem;
        padding: 0 0.5rem;
        margin: 0 0.25rem;
    }

    #workspaces button.active {
        color: @sky;
    }

    #workspaces button:hover {
        color: @sapphire;
    }


    #waybar box box.modules-center {
        font-weight: bold;
        text-shadow: -1px -1px 0 rgba(0,0,0,0.5), 1px -1px 0 rgba(0,0,0,0.5), -1px 1px 0 rgba(0,0,0,0.5), 1px 1px 0 rgba(0,0,0,0.5);
    }

    /* Colors */
    #cpu,
    #temperature.cpu {
        background: @sapphire;
        color: @surface0;
    }

    #memory {
        background: @yellow;
        color: @surface0;
    }

    #temperature.gpu {
        background: @green;
        color: @surface0;
    }

    #temperature.water {
        background: @blue;
        color: @surface0;
    }

    #cava,
    #pulseaudio {
        background: @peach;
        color: @surface0;
    }

    #network,
    #tray,
    #custom-pacman {
        background: @rosewater;
        color: @surface0;
    }

    #battery,
    #custom-wattage {
        background: @lavender;
        color: @surface0;
    }

    #clock {
        background: @sky;
        color: @surface0;
        font-weight: 500;
    }

    #network,
    #cava,
    #battery,
    #custom-pacman,
    #temperature.cpu,
    #tray,
    #pulseaudio,
    #clock,
    #memory,
    #temperature.gpu,
    #temperature.water,
    #custom-wattage,
    #cpu {
        padding: 0 0.75rem;
    }

    #cpu,
    #custom-wattage {
        padding: 0 0.25rem 0 0.75rem;
    }

    #temperature.cpu,
    #battery {
        padding: 0 0.75rem 0 0.25rem;
    }


    #tray widget image {
        -gtk-icon-shadow: -0.5px -0.5px #333, 0.5px -0.5px #333, -0.5px 0.5px #333, 0.5px 0.5px #333;
    }
    '';
  };
}
