{ lib, ... }: {
  options.me = {
    keyboardLayout = lib.mkEnableOption "keyboard layout";
  };
  imports = [
    ./hyprland.nix
    ./hyprpaper.nix
    ./hyprlock.nix
    ./hypridle.nix
    ./hyprland-binds-common.nix
    ./hyprland-binds-dvorak.nix
    ./hyprland-binds-qwerty.nix
    ./hyprpanel.nix
  ];
}
