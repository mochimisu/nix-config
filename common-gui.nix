{ pkgs, inputs, ... }:

let
  pkgsPinned = import (builtins.fetchTarball {
    # bambu-studio broken in ~1/18/2025-1/25/2025, using commit from 1/12/2025
    url = "https://github.com/NixOS/nixpkgs/archive/3ffda9033335d95338e1b80171327e2965f91dd7.tar.gz";
    sha256 = "sha256:03dhmp8l2v0c5vhi83azj1258x53pmgs6k91fzw05ikgz28s3ns0";
  }) { system = "x86_64-linux"; };
in
{
  imports =
    [
      ./keymap.nix
      inputs.catppuccin.nixosModules.catppuccin
      {nixpkgs.overlays = [inputs.hyprpanel.overlay];}
    ];

  nixpkgs.config = {
    chromium = {
      enableWideVine = true;
    };
  };


  # Packages
  environment.systemPackages = with pkgs; [
    bluez
    mesa
    greetd.tuigreet
    hyprpaper
    networkmanagerapplet
    walker
    kitty
    chromium
    cliphist

    grim
    slurp
    wf-recorder
    wl-clipboard
    inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default
    xdg-desktop-portal-hyprland
    xwaylandvideobridge

    hyprpolkitagent
    libsForQt5.kwallet
    kwalletcli
    kwalletmanager

    # Apps
    discord-canary
    proton-pass
    caprine
    hyprpicker
    vlc
    signal-desktop
    ani-cli
    transmission-remote-gtk
    ledger-live-desktop
    protonvpn-gui

    # Games
    mangohud
    heroic
    inputs.nixos-xivlauncher-rb.packages.${pkgs.system}.default
    parsec-bin
    itch
    lutris
    wine
    gamescope

    # 3D Printing
    pkgsPinned.bambu-studio
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";

    # steam and other electron apps to use wayland for better perf
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    # fullscreen render bug
    WLR_DRM_NO_ATOMIC = "1";
  };

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
    nerd-fonts.ubuntu-sans
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
    pam.services.greetd.kwallet.enable = true;
  };

  # catppuccin
  catppuccin = {
    enable = true;
    flavor = "mocha";
  };
}
