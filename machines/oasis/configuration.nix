{ config, lib, pkgs, specialArgs, variables, inputs, ... }:

{
  networking.hostName = "oasis";
  environment.systemPackages = with pkgs; [
    brightnessctl
    bolt
  ];

  systemd.services.fprintd = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "simple";
  };

  services.xserver.xkb = {
    layout = "custom";
    variant = "dvorak-custom";
  };

  system.stateVersion = "24.11";
}
