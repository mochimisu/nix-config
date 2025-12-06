{ config, lib, pkgs, specialArgs, variables, inputs, ... }:

{
  nixpkgs.overlays = [
    (import ../../overlays/hyprgrass.nix)
  ];

  networking.hostName = "espresso";
  environment.systemPackages = with pkgs; [
    brightnessctl
    bolt
  ];
  services.hardware.bolt.enable = true;

  system.stateVersion = "24.11";
}
