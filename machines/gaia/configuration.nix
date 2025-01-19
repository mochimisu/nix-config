{ pkgs, ... }:

{
  networking.hostName = "gaia";
  environment.systemPackages = with pkgs; [
    transmission
    samba
  ];

  system.stateVersion = "24.11";
}
