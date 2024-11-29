{ config, pkgs, ... }:

{
  imports = [
    ../../nvidia.nix
    ./uni-sync.nix
  ];
    
  networking.hostName = "blackmoon";
  environment.systemPackages = with pkgs; [
    bolt
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


  system.stateVersion = "24.11";
}
