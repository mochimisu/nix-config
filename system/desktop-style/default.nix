{config, lib, ...}: {
  imports = [./greeter.nix ./boot.nix];
  options.desktopStyle = {
    greeter.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.services.displayManager.sddm.enable;
      description = "Style the existing NixOS-owned SDDM greeter.";
    };
    boot.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.services.displayManager.sddm.enable && config.boot.loader.grub.enable;
      description = "Style existing GRUB and console on NixOS desktops; never install a bootloader.";
    };
  };
}
