{
  config,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/54f66482-8716-4ee5-9f4d-52a508fcde34";
    fsType = "ext4";
    options = [
      "relatime"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/9FFC-5F7F";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
      "codepage=437"
      "iocharset=ascii"
      "shortname=mixed"
      "utf8"
      "errors=remount-ro"
    ];
  };

  swapDevices = [
    {
      device = "/dev/disk/by-uuid/7501d5d2-4af4-45e6-84b8-a6fe3f22e8bb";
    }
  ];

  fileSystems."/gaia" = {
    device = "/dev/disk/by-uuid/b0ab60d8-938b-41af-8b02-781154ed8f4e";
    fsType = "btrfs";
    options = [
      "noatime"
      "autodefrag"
      "compress=zstd"
    ];
  };

  fileSystems."/europa" = {
    device = "/dev/disk/by-uuid/47130f83-0b35-4428-b58d-3f06b30d0f52";
    fsType = "btrfs";
    options = [
      "noatime"
      "autodefrag"
      "compress=zstd"
    ];
  };

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
