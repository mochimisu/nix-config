{ config, lib, pkgs, specialArgs, variables, inputs, ... }:

{
  imports = [
    ../../nvidia.nix
    ./uni-sync.nix
  ];
    
  networking.hostName = "blackmoon";
  environment.systemPackages = with pkgs; [
    bolt
  ];

  services.hardware.bolt.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "dvorak";
  };

  services.hardware.openrgb.enable = true;

  system.stateVersion = "24.11";
}
