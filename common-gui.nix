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
    sddm
    (catppuccin-sddm.override {
      flavor = "mocha";
    })
    hyprland
    waybar
    networkmanagerapplet
    blueman
    wofi
    kitty
    chromium
    copyq
    inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default
    dconf
    xdg-desktop-portal-hyprland

    discord
    proton-pass

    steam
    heroic
    xivlauncher
    parsec-bin
  ];

  programs = {
    steam.enable = true;
    hyprland.enable = true;
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

  # SDDM
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "catppuccin-mocha";
    package = pkgs.kdePackages.sddm;
  };

}
