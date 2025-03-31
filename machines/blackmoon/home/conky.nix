{ pkgs, ... }:
let
config-file = pkgs.writeTextFile {
  name = "blackmoon-conky.conf";
  text = ''
  -- Conky, a system monitor https://github.com/brndnmtthws/conky
  --
  -- This configuration file is Lua code. You can write code in here, and it will
  -- execute when Conky loads. You can use it to generate your own advanced
  -- configurations.
  --
  -- Try this (remove the `--`):
  --
  --   print("Loading Conky config")
  --
  -- For more on Lua, see:
  -- https://www.lua.org/pil/contents.html

  conky.config = {
      alignment = 'top_left',
      background = false,
      border_width = 1,
      cpu_avg_samples = 2,
      default_color = 'ffffff',
      default_outline_color = 'ffffff',
      default_shade_color = 'ffffff',
      double_buffer = true,
      draw_borders = false,
      draw_graph_borders = true,
      draw_outline = false,
      draw_shades = false,
      extra_newline = false,
      font = 'DejaVu Sans Mono:size=24',
      gap_x = 4404,
      gap_y = 1240,
      minimum_height = 5,
      minimum_width = 5,
      net_avg_samples = 2,
      no_buffers = true,
      out_to_console = false,
      out_to_ncurses = false,
      out_to_stderr = false,
      out_to_wayland = false,
      out_to_x = true,
      own_window = true,
      own_window_class = 'Conky',
      own_window_transparent = true,
      own_window_type = 'desktop',
      show_graph_range = false,
      show_graph_scale = false,
      stippled_borders = 0,
      update_interval = 1.0,
      uppercase = false,
      use_spacer = 'none',
      use_xft = true,
  }

  conky.text = [[
  ''${color b0b0b0}Uptime:$color $uptime ''${goto 800} CPU:   ''${execi 5 sensors coretemp-isa-0000 | ag "Package id 0:" | cut -c 17-20}°C ''${goto 1500} ''${time %r}
  ''${color b0b0b0}GHz:$color $freq_g ''${goto 800} GPU:   ''${execi 5 sensors nvme-pci-7200 | ag "Composite:" | cut -c 16-19}°C
  ''${color b0b0b0}RAM:$color $mem/$memmax - $memperc% ''${membar 4,100} ''${goto 800} Water: ''${execi 5 sensors highflownext-hid-3-* | ag "Coolant temp:" | cut -c 25-28}°C
  ''${color b0b0b0}Swap:$color $swap/$swapmax - $swapperc% ''${swapbar 4,100} ''${goto 800} Flow:  ''${execi 5 sensors highflownext-hid-3-* | ag "Flow \[dL/h\]:" | cut -c 23-26 | awk '{$1=$1};1'} dL/h
  ''${color b0b0b0}CPU:$color $cpu% ''${cpubar 4, 280} ''${goto 800} Fans:  ''${execi 5 sensors nct6798-isa-0290 | ag "fan3:" | cut -c 26-34 | awk '{$1=$1};1'}
  ''${color b0b0b0}Processes:$color $processes  ''${color b0b0b0}Running:$color $running_processes ''${goto 800} Pump:  ''${execi 5 sensors nct6798-isa-0290 | ag "fan6:" | cut -c 27-34 | awk '{$1=$1};1'}
  ''${color b0b0b0}/ $color''${fs_used /}/''${fs_size /} ''${fs_bar 4, 250 /}
  ''${color b0b0b0}Up:$color ''${upspeed} ''${color b0b0b0} - Down:$color ''${downspeed}
  ''${color b0b0b0}Name                PID    CPU%   MEM%
  ''${color d3d3d3} ''${top name 1} ''${top pid 1} ''${top cpu 1} ''${top mem 1}
  ''${color d3d3d3} ''${top name 2} ''${top pid 2} ''${top cpu 2} ''${top mem 2}
  ''${color d3d3d3} ''${top name 3} ''${top pid 3} ''${top cpu 3} ''${top mem 3}
  ]]
'';
};
in
{
  home.packages = with pkgs; [
    conky
  ];
  wayland.windowManager.hyprland.settings = {
    "exec-once" = [
      "conky -c ${config-file}"
    ];
    defaultwindows = {
      windowrule = [
        "workspace 10 silent, title:^Conky$"
        "fullscreen, title:^Conky$"
      ];
    };
  };
}
