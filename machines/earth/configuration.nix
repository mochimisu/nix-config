{ config, lib, pkgs, specialArgs, variables, inputs, ... }:

{
  imports = [
    ./transmission.nix
  ];

  networking.hostName = "earth";

  # Disable the GUI stack on this host by skipping the shared GUI module.
  services.xserver.enable = lib.mkForce false;
  services.pipewire.enable = lib.mkForce false;
  variables.isGui = lib.mkForce false;

  environment.systemPackages = [
    pkgs.kitty.terminfo
  ];

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "server string" = "earth samba server";
        "workgroup" = "WORKGROUP";
        "map to guest" = "Bad User";
      };
      earth = {
        path = "/earth";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "brandon";
        "force group" = "media";
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };

  system.stateVersion = "24.11";
}
