# Home Manager desktop/session settings, separate from shared applications.
{config, pkgs, lib, ...}: let
  nestedDesktop = config.variables.nestedDesktop or false;
  isLinuxGui = pkgs.stdenv.isLinux && (config.variables.isGui or true);
in {
  imports = [
    ./apps/quickshell
    ./apps/mako.nix
  ];

  programs.zsh.sessionVariables = lib.mkIf (!nestedDesktop) {
    SDL_VIDEODRIVER = "wayland";
    SSH_AUTH_SOCK = lib.optionalString pkgs.stdenv.isLinux "/run/user/$(id -u)/gcr/ssh";
  };

  xdg.mimeApps = lib.mkIf (isLinuxGui && !nestedDesktop) {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = "chromium.desktop";
      "x-scheme-handler/https" = "chromium.desktop";
      "text/html" = "chromium.desktop";
    };
  };

  # Dark mode
  dconf.settings = lib.mkIf (isLinuxGui && !nestedDesktop) {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  gtk = lib.mkIf isLinuxGui {
    enable = true;
    gtk4.theme = config.gtk.theme;
    gtk3.extraConfig = {
      "gtk-application-prefer-dark-theme" = "1";
    };

    gtk4.extraConfig = {
      "gtk-application-prefer-dark-theme" = "1";
    };
  };

  # per-app translucency
  xdg.configFile."gtk-3.0/gtk.css" = lib.mkIf isLinuxGui {
    source = builtins.toFile "gtk.css" ''
      .thunar .sidebar .view {
        background-color: rgba(0,0,0,0.3);
      }
      .thunar .standard-view .view {
        background-color: rgba(0,0,0,0.2);
      }
      .thunar toolbar {
        background-color: rgba(0,0,0,0.1);
      }
      .thunar,
      .thunar menubar,
      .thunar .shortcuts-pane
      {
        background-color: rgba(0,0,0,0.5);
      }
      .thunar toolbar > * > * > * > *
      {
        background-color: rgba(0,0,0,0.3);
      }
    '';
  };

  xdg.desktopEntries = lib.mkIf isLinuxGui {
    "xivlauncher-rb" = {
      name = "XIVLauncher-RB";
      icon = "xivlauncher";
      exec = "sh -c \"SDL_VIDEODRIVER=wayland XIVLauncher.Core\"";
      terminal = false;
      type = "Application";
      categories = ["Game"];
    };
  };
}
