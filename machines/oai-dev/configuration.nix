{ pkgs, inputs, ... }:
{
  system.primaryUser = "brandonw";
  imports = [
    ./aerospace.nix
  ];
  nixpkgs.config = {
    allowUnfree = true;
  };
  nix.settings.experimental-features = "nix-command flakes";
  programs.zsh.enable = true;
  system.stateVersion = 5;

  users.users.brandonw = {
    home = "/Users/brandonw";
    shell = pkgs.zsh;
  };
}
