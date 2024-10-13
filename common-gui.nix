{ config, lib, pkgs, specialArgs, inputs, ... }:

{
  imports =
    [
      ./keymap.nix
    ];

  # Packages
  environment.systemPackages = with pkgs; [
    bluez
    mesa
    greetd.tuigreet
    hyprpaper
    waybar
    networkmanagerapplet
    wofi
    kitty
    chromium
    cliphist
    wl-clipboard
    inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default
    xdg-desktop-portal-hyprland

    polkit-kde-agent
    swaynotificationcenter

    # Apps
    discord
    proton-pass
    caprine

    # Games
    steam
    heroic
    xivlauncher
    parsec-bin
    itch
    lutris
    wine
    
    # 3D Printing
    bambu-studio
    blender
  ];

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  programs = {
    steam.enable = true;
    hyprland.enable = true;
    hyprlock.enable = true;
  };
  services.hypridle.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true; 

  # Fonts
  fonts.packages = with pkgs; [
    font-awesome
    powerline-fonts
    powerline-symbols
    liberation_ttf
    wqy_zenhei
  ];

  # Touchpad support
  services.libinput.enable = true;

  # Audio
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Greetd
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --time-format '%I:%M %p | %a - %h | %F' --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  security = {
    polkit.enable = true;
    pam.services.hyprlock = {};
  };
}
