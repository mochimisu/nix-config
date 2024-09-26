{ config, lib, pkgs, specialArgs, inputs, ... }:
{
  # Nix
  nix = {
    package = pkgs.nixFlakes;
    extraOptions = "experimental-features = nix-command flakes";
  };
  nixpkgs.config = {
    allowUnfree = true;
  };

  # Packages
  environment.systemPackages = with pkgs; [
    dhcpcd
    networkmanager
    neovim
    wget
    git
    nerdfetch

    fzf
    nodejs
    openssh
  ];

  programs = {
    git.enable = true;
    zsh.enable = true;
  };

  # Locale
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";
  services.automatic-timezoned.enable = true;

  # Networking
  networking.networkmanager.enable = true;

  # User
  users.users.brandon = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    packages = with pkgs; [
      tree
   ];
   shell = pkgs.zsh;
  };
}
