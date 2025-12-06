{
  pkgs,
  inputs,
  lib,
  ...
}: let
  # pkgsPinned = import (builtins.fetchTarball {
  #   # walker broken on 2/13/2025, use a commit from 2/3/2025
  #   url = "https://github.com/NixOS/nixpkgs/archive/9d962cd4ad268f64d125aa8c5599a87a374af78a.tar.gz";
  #   sha256 = "sha256:1a1917f9qvg5agx2vhlsrhj3yyjrznpcnlkwcqk4ampzdby6nzhi";
  # }) { system = "x86_64-linux"; };
in {
  imports = [
    ./keymap.nix
    inputs.catppuccin.nixosModules.catppuccin
    inputs.flatpaks.nixosModules.nix-flatpak
    inputs.aagl.nixosModules.default
  ];

  # Packages
  environment.systemPackages = with pkgs; [
    bluez
    mesa
    # greetd.tuigreet
    hyprpaper
    networkmanagerapplet
    (chromium.override {enableWideVine = true;})
    cliphist

    grim
    slurp
    wf-recorder
    wl-clipboard
    inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default
    xdg-desktop-portal-hyprland

    hyprpolkitagent
    gnome-keyring
    # gnome-keyring management ui
    seahorse

    # for pactl
    pulseaudio

    # Apps
    # discord-canary
    # High CPU usage
    vesktop
    proton-pass
    caprine
    hyprpicker
    inputs.zen-browser.packages.${pkgs.system}.default
    vlc
    signal-desktop
    ani-cli
    transmission-remote-gtk
    ledger-live-desktop
    protonvpn-gui
    xfce.thunar
    signal-desktop

    # Games
    mangohud
    inputs.nixos-xivlauncher-rb.packages.${pkgs.system}.default
    parsec-bin
    itch
    lutris
    wine
    gamescope
    antimicrox
    sc-controller
    obs-studio
    appimage-run
    seventeenlands
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";

    # steam and other electron apps to use wayland for better perf
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    # fullscreen render bug
    WLR_DRM_NO_ATOMIC = "1";
  };

  programs = {
    steam = {
      enable = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };
    gamemode.enable = true;
    hyprland.enable = true;
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
    # coding font
    cascadia-code
    # general sans font
    montserrat
  ];

  # Touchpad support
  services.libinput.enable = true;

  # Gamepad remapping
  services.input-remapper.enable = true;

  # Audio
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.flatpak = {
    enable = lib.mkDefault true;
    packages = [
      {
        appId = "com.bambulab.BambuStudio";
        origin = "flathub";
      }
    ];
  };

  # sddm
  services.xserver.enable = false;
  services.displayManager.sddm = {
    enable = true;
    package = pkgs.kdePackages.sddm;
    wayland.enable = true;
  };

  # login to start ssh-agent
  services.gnome.gnome-keyring.enable = true;
  security = {
    polkit.enable = true;
    pam = {
      services = {
        login.enableGnomeKeyring = true;
        sddm = {
          enable = true;
          enableGnomeKeyring = true;
        };
      };
    };
  };

  # catppuccin
  catppuccin = {
    enable = true;
    flavor = "mocha";
  };

  # zzz
  nix.settings = inputs.aagl.nixConfig;
  programs.sleepy-launcher.enable = true;
}
