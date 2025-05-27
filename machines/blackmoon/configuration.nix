{ config, pkgs, lib, ... }:

{
  imports = [
    ../../nvidia.nix
    ./uni-sync.nix
  ];
    
  networking.hostName = "blackmoon";
  environment.systemPackages = with pkgs; [
    bolt
    cage

    samba
    spacenavd
  ];

  services.hardware.bolt.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "dvorak";
  };

  services.hardware.openrgb.enable = true;

  #v4l2loopback for screen sharing
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];
  boot.extraModprobeConfig = ''
  options v4l2loopback devices=1 video_nr=10 card_label="VirtualCam" exclusive_caps=1
'';
  boot.kernelModules= [ 
    # sensors for temps
    "nct6775"
    # loopback for screen sharing
    "v4l2loopback"
  ];
  boot.kernelParams = [
    "acpi_enforce_resources=lax" 
    # disable GSP for frame stuttering
    "NVreg_EnableGpuFirmware=0"
  ];


  # services for fusion360
  hardware.spacenavd.enable = true;
  services.samba.enable = true;

  # consistent udev for highflownext 
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="hwmon", ATTRS{idVendor}=="0c70", ATTRS{idProduct}=="f012", ATTRS{serial}=="03550-34834", RUN+="/bin/sh -c 'ln -s /sys$devpath /dev/highflow_next'"
  '';


  # fix sddm, eDP-3 (ultrawide) doesnt show with wayland.
  services.xserver.enable = lib.mkForce true;
  services.displayManager.sddm.wayland.enable = lib.mkForce false;

  system.stateVersion = "24.11";
}
