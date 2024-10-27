{ config, lib, pkgs, specialArgs, variables, inputs, ... }:

{
  networking.hostName = "glasscastle";
  environment.systemPackages = with pkgs; [
    framework-tool
    fw-ectool

    brightnessctl

    bolt
  ];

  systemd.services.fprintd = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "simple";
  };

  services.fprintd.enable = true;
  security.pam.services.hyprlock.fprintAuth = true;
  security.pam.services.sudo.fprintAuth = true;
  security.pam.services.login.fprintAuth = true;

  services.hardware.bolt.enable = true;

  boot.kernelParams = [
    "video=eDP-1,2880x1920@120"
  ];

  services.xserver.xkb = {
    layout = "custom";
    variant = "dvorak-custom";
  };

  system.stateVersion = "24.11";
}
