# SteamOS owns the host; this is a standalone Home Manager configuration.
{config, pkgs, lib, inputs, ...}: let
  shared = import ../../common-packages.nix {inherit pkgs inputs;};
  repo = "${config.home.homeDirectory}/stuff/nix-config";
in {
  imports = [
    ./media-apps.nix
    ./mpv.nix
    ./mounts.nix
    ./power.nix
  ];
  home.username = "deck";
  home.homeDirectory = "/home/deck";
  home.stateVersion = lib.mkForce "26.05";
  variables.gitIdentity = false;
  programs.wikimem.enable = lib.mkForce false;
  xdg.configFile."obsidian/obsidian.json".force = lib.mkForce false;
  home.packages = shared.sharedApps ++ shared.fonts;
  fonts.fontconfig.enable = true;
  targets.genericLinux.enable = true;
  targets.genericLinux.gpu.enable = false;
  programs.home-manager.enable = true;
  programs.tmux.shell = lib.mkForce "${pkgs.zsh}/bin/zsh";
  home.activation.cloneRepo = lib.mkForce (lib.hm.dag.entryAfter ["writeBoundary"] "");
  home.shellAliases = {
    nix-rs = lib.mkForce "home-manager switch --flake ${repo}#deck@cove";
    nix-rsf = lib.mkForce "home-manager switch --flake ${repo}#deck@cove";
    nix-up = lib.mkForce "(cd ${repo} && nix flake update)";
    steam = lib.mkForce "steam";
  };
}
