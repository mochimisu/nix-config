{ pkgs, ... }:

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

  boot.kernelModules= [ "nct6775" ];
  boot.kernelParams = [ "acpi_enforce_resources=lax" ];

  system.stateVersion = "24.11";
}
