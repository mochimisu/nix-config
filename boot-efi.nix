{ config, lib, pkgs, ... }:

{
  # GRUB to use os-prober
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
    grub = {
      efiSupport = true;
      devices = [ "nodev" ];
      enable = true;
      useOSProber = true;
    };
  };
}
