{ config, lib, pkgs, specialArgs, inputs, ... }:

{
  networking.hostName = "glasscastle";
  environment.systemPackages = with pkgs; [
    framework-tool
    fw-ectool

    brightnessctl
  ];

  system.stateVersion = "24.11";
}
