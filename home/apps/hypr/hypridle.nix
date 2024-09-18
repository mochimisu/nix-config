{ pkgs, config, ...}:
{
  home.file.".config/hypr/hypridle.conf".source = pkgs.writeText "hypridle.conf" ''
  general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = hyprlock
    after_sleep_cmd = hyprctl dispatch dpms on
  }

  listener {
    timeout = 1800
    on-timeout = brightnessctl -s set 10
    on-resume = brightnessctl -r
  }
  '';
}

