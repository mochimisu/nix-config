{ config, lib, pkgs, specialArgs, variables, inputs, ... }:

{
  imports = [
    ../../nvidia.nix
  ];
    
  networking.hostName = "blackmoon";
  environment.systemPackages = with pkgs; [
    uni-sync
    bolt
  ];

  systemd.services.fprintd = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "simple";
  };
  services.hardware.bolt.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "dvorak";
  };

  system.stateVersion = "24.11";
}
