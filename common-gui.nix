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

  # Packages
  environment.systemPackages = with pkgs; [
    bluez
    mesa
    greetd.tuigreet
    hyprpaper
    networkmanagerapplet
    pkgsPinned.walker
    (chromium.override { enableWideVine = true; })
    cliphist

    grim
    slurp
    wf-recorder
    wl-clipboard
    inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default
    xdg-desktop-portal-hyprland
    kdePackages.xwaylandvideobridge

    hyprpolkitagent
    kdePackages.kwallet
    kwalletcli
    kdePackages.kwalletmanager
    kdePackages.ksshaskpass
    kdePackages.kwallet-pam


    # for pactl
    pulseaudio

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
    xfce.thunar
    signal-desktop

    # Games
    mangohud
    heroic
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
    steam = {
      enable = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };
    gamemode.enable = true;
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
    cascadia-code
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

  # login to start ssh-agent
  security = {
    polkit.enable = true;
    pam.services = {
      hyprlock = {};
      greetd.kwallet.enable = true;
      login.enableKwallet = true;
    };
  };
  programs.ssh.startAgent = true;
  programs.ssh.askPassword = "${pkgs.ksshaskpass}/bin/ksshaskpass";
  environment.sessionVariables = {
    SSH_ASKPASS_REQUIRE = "prefer";
  };

  # catppuccin
  catppuccin = {
    enable = true;
    flavor = "mocha";
  };
}
