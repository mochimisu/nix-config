# SteamOS owns the system. This target manages only steamos's user environment.
{config, pkgs, lib, inputs, ...}: let
  shared = import ../../common-packages.nix {inherit pkgs inputs;};
  configsDir = "${config.home.homeDirectory}/stuff/nix-config";
  caffeine = pkgs.writeShellScriptBin "caffeine" ''
    exec ${pkgs.python3}/bin/python3 ${./caffeine.py} "$@"
  '';
  cometMpv = pkgs.mpv.override { scripts = [pkgs.mpvScripts.uosc]; };
  cometVlc = pkgs.writeShellScriptBin "comet-vlc" ''
    # Steam's bundled libavcodec omits codecs present in SteamOS's VLC build.
    unset LD_LIBRARY_PATH
    # SteamOS Freedreno registers a thread destructor that outlives VLC's
    # dlclose. Keep the native driver mapped until process exit (VLC only).
    export LD_PRELOAD="/usr/lib/libvulkan_freedreno.so''${LD_PRELOAD:+:$LD_PRELOAD}"
    # Decode PCM rather than attempting compressed passthrough to the headset.
    # Both reuse switches must be off to avoid the old polluted VLC instance.
    exec /usr/bin/vlc --codec=avcodec --no-one-instance --no-one-instance-when-started-from-file "$@"
  '';
in {
  imports = [./nested-desktop.nix ./media-apps.nix ./mpv-browser.nix ./obsidian.nix ./wikimem-secret.nix];
  variables.gitIdentity = false;
  programs.wikimem.enable = lib.mkForce false;
  # Preserve/back up an existing SteamOS-side Obsidian registration normally.
  xdg.configFile."obsidian/obsidian.json".force = lib.mkForce false;
  home.packages = shared.sharedApps ++ shared.fonts ++ [caffeine cometVlc cometMpv pkgs.ffmpeg];
  # Persistent recovery owner: dormant unless leases or a saved restore exist.
  systemd.user.services.comet-caffeine = {
    Unit = {
      Description = "Comet Steam AC sleep lease and restoration guard";
      StartLimitIntervalSec = 0;
    };
    Service = {
      ExecStart = "${caffeine}/bin/caffeine --guard";
      Restart = "on-failure";
      RestartSec = 2;
      UMask = "0077";
    };
    Install.WantedBy = ["default.target"];
  };
  # Native SteamOS launchers do not search the Nix profile data directory.
  xdg.dataFile."applications/chatgpt.desktop".source =
    "${config.home.path}/share/applications/chatgpt.desktop";
  xdg.dataFile."applications/mpv.desktop".source = pkgs.runCommand "comet-mpv.desktop" {} ''
    substitute ${cometMpv}/share/applications/mpv.desktop "$out" \
      --replace-fail 'TryExec=mpv' 'TryExec=${cometMpv}/bin/mpv' \
      --replace-fail 'Exec=mpv ' 'Exec=${cometMpv}/bin/mpv '
  '';
  xdg.dataFile."applications/vlc.desktop".source = pkgs.runCommand "comet-vlc.desktop" {} ''
    substitute ${pkgs.vlc}/share/applications/vlc.desktop "$out" \
      --replace-fail '${pkgs.vlc}/bin/vlc' '${cometVlc}/bin/comet-vlc'
  '';
  # Gamescope has no XDG_MENU_PREFIX; native KDE otherwise sees no apps.
  xdg.configFile."menus/applications.menu".source =
    config.lib.file.mkOutOfStoreSymlink "/etc/xdg/menus/plasma-applications.menu";
  fonts.fontconfig.enable = true;
  # SteamOS does not add the Nix profile to ncurses lookup paths. The empty
  # fallback preserves ncurses defaults alongside installed Kitty terminfo.
  home.sessionVariables.TERMINFO_DIRS =
    "${config.home.profileDirectory}/share/terminfo:\${TERMINFO_DIRS:-}";
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
