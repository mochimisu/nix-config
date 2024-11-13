{ config, lib, pkgs, specialArgs, variables, inputs, ... }:

{
  networking.hostName = "espresso";
  environment.systemPackages = with pkgs; [
    brightnessctl
    bolt
  ];
  services.hardware.bolt.enable = true;

  system.stateVersion = "24.11";
}
