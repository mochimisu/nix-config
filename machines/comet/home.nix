# SteamOS owns the system. This target manages only steamos's user environment.
{config, pkgs, lib, inputs, ...}: let
  shared = import ../../common-packages.nix {inherit pkgs inputs;};
  configsDir = "${config.home.homeDirectory}/stuff/nix-config";
  caffeine = pkgs.writeShellApplication {
    name = "caffeine";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      if [[ "''${1:-}" == "--help" || "''${1:-}" == "-h" ]]; then
        echo "Usage: caffeine [COMMAND [ARG...]]"
        echo "Hold a temporary logind idle inhibitor; default: sleep infinity."
        echo "Stop with Ctrl-C or let COMMAND finish. No permanent power changes."
        echo "Valve headset-specific auto-suspend is not verified."
        exit 0
      fi
      if (( $# == 0 )); then
        set -- sleep infinity
      fi
      exec /usr/bin/systemd-inhibit --no-ask-password \
        --what=idle --mode=block --who=caffeine \
        --why="Temporary user-requested idle inhibition" "$@"
    '';
  };
in {
  variables.gitIdentity = false;
  programs.wikimem.enable = lib.mkForce false;
  # Preserve/back up an existing SteamOS-side Obsidian registration normally.
  xdg.configFile."obsidian/obsidian.json".force = lib.mkForce false;
  home.packages = shared.sharedApps ++ shared.fonts ++ [caffeine];
  fonts.fontconfig.enable = true;
  home.stateVersion = lib.mkForce "26.05";
  programs.tmux.shell = lib.mkForce "${pkgs.zsh}/bin/zsh";
  home.activation.cloneRepo = lib.mkForce (lib.hm.dag.entryAfter ["writeBoundary"] "");
  home.shellAliases = {
    nix-rs = lib.mkForce "home-manager switch --flake ${configsDir}#steamos@comet";
    nix-rsf = lib.mkForce "home-manager switch --flake ${configsDir}#steamos@comet";
    nix-up = lib.mkForce "(cd ${configsDir} && nix flake update)";
    steam = lib.mkForce "steam";
  };

  home.username = "steamos";
  home.homeDirectory = "/home/steamos";

  targets.genericLinux.enable = true;
  # SteamOS owns the VR graphics stack; GUI apps do not imply GPU/session ownership.
  targets.genericLinux.gpu.enable = false;
  programs.home-manager.enable = true;
  programs.bash = {
    enable = true;
    # Preserve the stock SteamOS .bashrc behavior reviewed before activation.
    shellAliases = {
      ls = "ls --color=auto";
      grep = "grep --color=auto";
    };
    initExtra = ''
      PS1='[\u@\h \W]\$ '
    '';
  };
}
