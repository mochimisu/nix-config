{ config, lib, pkgs, specialArgs, inputs, ... }:

{
  networking.hostName = "glasscastle";
  environment.systemPackages = with pkgs; [
    framework-tool
  ];

  system.stateVersion = "24.11";
}
