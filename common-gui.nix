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
    blueman
    wofi
    kitty
    chromium
    cliphist
    wl-clipboard
    inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default
    xdg-desktop-portal-hyprland

    polkit-kde-agent
    swaynotificationcenter

    discord
    proton-pass
    caprine

    steam
    heroic
    xivlauncher
    parsec-bin
  ];

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  programs = {
    steam.enable = true;
    hyprland.enable = true;
    hyprlock.enable = true;
  };

  # Fonts
  fonts.packages = with pkgs; [
    font-awesome
    powerline-fonts
    powerline-symbols
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
