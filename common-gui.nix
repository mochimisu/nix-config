{pkgs, inputs, lib, ...}: {
  imports = [inputs.flatpaks.nixosModules.nix-flatpak];

  # Packages
  environment.systemPackages = (import ./common-packages.nix {inherit pkgs inputs;}).gui;

  programs = {
    steam = {
      enable = true;
      extest.enable = true;
      localNetworkGameTransfers.openFirewall = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };
    gamemode.enable = true;
  };

  home-manager.extraSpecialArgs = {inherit inputs;};
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;
  services.dbus.implementation = "broker";
  services.power-profiles-daemon.enable = true;

  # Fonts
  fonts.packages = (import ./common-packages.nix {inherit pkgs inputs;}).fonts;

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

  boot.kernelModules = [
    # Recent Proton titles are more stable when ntsync is available.
    "ntsync"
  ];
}
