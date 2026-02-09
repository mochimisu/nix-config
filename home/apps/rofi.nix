{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (config.catppuccin) flavor accent sources;
  palette = (lib.importJSON "${sources.palette}/palette.json").${flavor}.colors;
  variables = config.variables or {};
  isLinuxGui = pkgs.stdenv.isLinux && (variables.isGui or true);
in {
  programs.rofi = lib.mkIf isLinuxGui {
    enable = true;
    extraConfig = {
      modi = "drun,run,window,ssh,calc";
      show-icons = true;
      drun-display-format = "{icon} {name}";
      matching = "fuzzy";
      sort = true;
      icon-theme = "Papirus-Dark";
      transparency = "real";
      "click-to-exit" = false;
      "kb-mode-next" = "Super+Right";
      "kb-mode-previous" = "Super+Left";
    };
    theme = "mochi";
    plugins = with pkgs; [
      rofi-calc
    ];
  };
  xdg = lib.mkIf isLinuxGui {
    configFile."rofi/themes/mochi.rasi".text = ''
      /* Theme based off of Nord-Dark-Rounded by Newman Sanchez (https://github.com/newmanls) */
      * {
        bg0: ${palette.base.hex}AA;      /* background color */
        bg1: ${palette.surface0.hex};    /* input background color */
        bg2: ${palette.surface1.hex};    /* message background color */
        bg3: ${palette.surface2.hex};    /* input border color */
        bg4: ${palette.surface0.hex};    /* selected item color */
        fg0: ${palette.subtext0.hex};    /* text color */
        fg1: ${palette.text.hex};        /* selected text color */
        fg2: ${palette.${accent}.hex};   /* prompt text color */
      }

      element selected {
        text-color: @fg1;
      }

      * {
        font: "Roboto 12";
        background-color: transparent;
        text-color: @fg0;

        margin: 0px;
        padding: 0px;
        spacing: 0px;
      }

      window {
        location: north;
        y-offset: calc(50% - 176px);
        width: 480;
        border-radius: 10px;
        background-color: @bg0;
      }

      mainbox {
        padding: 12px;
      }

      inputbar {
        background-color: @bg1;
        border-color: @bg3;

        border: 2px;
        border-radius: 16px;

        padding: 8px 16px;
        spacing: 8px;
        children: [ prompt, entry ];
      }

      prompt {
        text-color: @fg2;
      }

      message {
        margin: 12px 0 0;
        border-radius: 16px;
        border-color: @bg2;
        background-color: @bg2;
      }

      textbox {
        padding: 8px 24px;
      }

      listview {
        background-color: transparent;

        margin: 12px 0 0;
        lines: 8;
        columns: 1;

        fixed-height: false;
      }

      element {
        padding: 8px 16px;
        spacing: 8px;
        border-radius: 16px;
      }

      element normal active {
        text-color: @bg3;
      }

      element alternate active {
        text-color: @bg3;
      }

      element selected normal, element selected active {
        background-color: @bg4;
      }

      element-icon {
        size: 1em;
        vertical-align: 0.5;
      }

      element-text {
        text-color: inherit;
      }  '';
  };

  wayland.windowManager.hyprland = lib.mkIf isLinuxGui {
    settings = {
      "$menu" = "rofi-toggle -show drun";
      "$menuAll" = "rofi-toggle -show run";
      layerrule = [
        "match:namespace ^(rofi)$, animation fade, blur on, ignore_alpha 0, dim_around on"
        "match:namespace ^(wvkbd)$, order 0"
        "match:namespace ^(rofi)$, order 1"
      ];
    };
  };
  # catppuccin.rofi.enable = true;
  home = lib.mkIf isLinuxGui {
    packages = with pkgs; [
      (writeShellScriptBin "rofi-toggle" ''
        #!/usr/bin/env bash
        if pgrep -x rofi > /dev/null; then
          pkill rofi
        else
          rofi -no-click-to-exit "$@"
        fi
      '')
    ];
  };
}
