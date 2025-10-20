{ config, lib, pkgs, specialArgs, variables, inputs, ... }:

{
  networking.hostName = "earth";

  # Disable the GUI stack on this host by skipping the shared GUI module.
  services.xserver.enable = lib.mkForce false;
  services.pipewire.enable = lib.mkForce false;
  variables.isGui = lib.mkForce false;

  environment.systemPackages = [
    pkgs.kitty.terminfo
  ];

  system.stateVersion = "24.11";
}
