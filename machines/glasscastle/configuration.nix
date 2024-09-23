{ config, lib, pkgs, specialArgs, variables, inputs, ... }:

{
  networking.hostName = "glasscastle";
  environment.systemPackages = with pkgs; [
    framework-tool
    fw-ectool

    brightnessctl
  ];

  systemd.services.fprintd = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "simple";
  };

  services.fprintd.enable = true;
  security.pam.services.hyprlock.fprintAuth = true;
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.login.fprintAuth = true;


  system.stateVersion = "24.11";
}
