{ pkgs, inputs, ... }:

let
  pkgsPinned = import (builtins.fetchTarball {
    # walker broken on 2/13/2025, use a commit from 2/3/2025
    url = "https://github.com/NixOS/nixpkgs/archive/9d962cd4ad268f64d125aa8c5599a87a374af78a.tar.gz";
    sha256 = "sha256:1a1917f9qvg5agx2vhlsrhj3yyjrznpcnlkwcqk4ampzdby6nzhi";
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
    pkgsPinned.walker
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
    bambu-studio
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
