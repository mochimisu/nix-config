{ config, lib, pkgs, ... }: let
  p = lib.importJSON ./app-palette.json;
  css = ''
    @define-color window_bg_color ${p.background};
    @define-color window_fg_color ${p.text};
    @define-color view_bg_color ${p.background};
    @define-color view_fg_color ${p.text};
    @define-color headerbar_bg_color ${p.surface};
    @define-color headerbar_fg_color ${p.text};
    @define-color card_bg_color ${p.surface};
    @define-color card_fg_color ${p.text};
    @define-color dialog_bg_color ${p.surface};
    @define-color dialog_fg_color ${p.text};
    @define-color popover_bg_color ${p.surface};
    @define-color popover_fg_color ${p.text};
    @define-color sidebar_bg_color ${p.surface};
    @define-color sidebar_fg_color ${p.text};
    @define-color accent_bg_color ${p.selection};
    @define-color accent_fg_color ${p.text};
    @define-color accent_color ${p.teal};
    @define-color theme_bg_color ${p.background};
    @define-color theme_fg_color ${p.text};
    @define-color theme_base_color ${p.background};
    @define-color theme_text_color ${p.text};
    @define-color theme_selected_bg_color ${p.selection};
    @define-color theme_selected_fg_color ${p.text};
    selection { background-color: ${p.selection}; color: ${p.text}; }
    .dim-label { color: ${p.muted}; opacity: 1; }
  '';
  # QPalette roles in enum order, from WindowText through Accent.
  colors = text: [ text p.surface "#435159" p.raised "#101518" p.raised text p.text text
    p.background p.surface "#000000" p.selection p.text p.teal p.lavender
    "#20282d" "#000000" p.surface p.text p.muted p.teal ];
  qtPalette = pkgs.writeText "blackmoon-qt-colors.conf" ''
    [ColorScheme]
    active_colors=${lib.concatStringsSep ", " (colors p.text)}
    inactive_colors=${lib.concatStringsSep ", " (colors p.text)}
    disabled_colors=${lib.concatStringsSep ", " (colors p.muted)}
  '';
  qtSettings.Appearance = {
    style = "Fusion";
    custom_palette = true;
    color_scheme_path = "${qtPalette}";
    icon_theme = "Papirus-Dark";
  };
  qtPluginPaths = [
    "${pkgs.libsForQt5.qt5ct}/${pkgs.qt5.qtbase.qtPluginPrefix}"
    "${pkgs.qt6Packages.qt6ct}/${pkgs.qt6.qtbase.qtPluginPrefix}"
  ];
  hl = fg: bg: { inherit fg bg; };
in {
  # Blackmoon-only app content palette; the illustrated shell stays independent.
  gtk.theme = { name = "adw-gtk3-dark"; package = pkgs.adw-gtk3; };
  gtk.iconTheme = { name = "Papirus-Dark"; package = pkgs.papirus-icon-theme; };
  gtk.gtk4.theme = lib.mkForce null;
  gtk.gtk4.extraCss = css;
  # Replace the shared Thunar transparency rules: content should be opaque.
  xdg.configFile."gtk-3.0/gtk.css".source = lib.mkForce (pkgs.writeText "blackmoon-gtk.css" css);
  dconf.settings."org/gnome/desktop/interface" = {
    gtk-theme = "adw-gtk3-dark";
    icon-theme = "Papirus-Dark";
    color-scheme = "prefer-dark";
    accent-color = "teal";
  };
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    qt5ctSettings = qtSettings;
    qt6ctSettings = qtSettings;
  };
  # Explicit store paths also work before the next NixOS profile activation.
  home.sessionSearchVariables.QT_PLUGIN_PATH = lib.mkForce qtPluginPaths;
  systemd.user.sessionVariables.QT_PLUGIN_PATH = lib.mkForce (lib.concatStringsSep ":" qtPluginPaths);
  xdg.dataFile."themes/adw-gtk3-dark".source = "${pkgs.adw-gtk3}/share/themes/adw-gtk3-dark";
  xdg.dataFile."icons/Papirus-Dark".source = "${pkgs.papirus-icon-theme}/share/icons/Papirus-Dark";
  xdg.dataFile."icons/Papirus".source = "${pkgs.papirus-icon-theme}/share/icons/Papirus";
  programs.kitty.settings = {
    background = p.background;
    foreground = p.text;
    background_opacity = lib.mkForce 1.0;
    cursor = p.teal;
    cursor_text_color = p.background;
    selection_background = p.selection;
    selection_foreground = p.text;
    url_color = p.teal;
    active_border_color = p.teal;
    inactive_border_color = p.raised;
    active_tab_background = p.selection;
    active_tab_foreground = p.text;
    inactive_tab_background = p.surface;
    inactive_tab_foreground = p.muted;
    color0 = p.background; color8 = "#63747d";
    color1 = p.red; color9 = "#ff9aa8";
    color2 = "#76c7a4"; color10 = "#98dfbd";
    color3 = "#d8c178"; color11 = "#ead494";
    color4 = "#82b7d9"; color12 = "#a6d2ee";
    color5 = p.lavender; color13 = "#d0c3f0";
    color6 = p.teal; color14 = "#93e0d9";
    color7 = "#dedede"; color15 = p.text;
  };
  programs.nixvim.colorschemes.ayu.settings.overrides = lib.mkForce {
    Normal = hl p.text p.background;
    NormalFloat = hl p.text p.surface;
    SignColumn = hl p.muted p.background;
    FoldColumn = hl p.muted p.background;
    Folded = hl p.muted p.surface;
    CursorLine = { bg = p.surface; };
    CursorColumn = { bg = p.surface; };
    ColorColumn = { bg = p.surface; };
    Visual = hl p.text p.selection;
    Pmenu = hl p.text p.surface;
    PmenuSel = hl p.text p.selection;
    FloatBorder = hl p.teal p.surface;
    WinSeparator = hl p.raised p.background;
    StatusLine = hl p.text p.selection;
    StatusLineNC = hl p.muted p.surface;
    Comment = { fg = p.muted; italic = true; };
    Function = { fg = p.teal; };
    Keyword = { fg = p.lavender; };
  };
  # Retain the existing Rofi layout while replacing its palette variables.
  programs.rofi.theme = lib.mkForce "blackmoon";
  xdg.configFile."rofi/themes/blackmoon.rasi".text = ''
    @import "mochi.rasi"
    * {
      bg0: ${p.background}ee; bg1: ${p.surface}; bg2: ${p.raised};
      bg3: ${p.lavender}; bg4: ${p.selection};
      fg0: ${p.text}; fg1: ${p.text}; fg2: ${p.teal};
    }
  '';
}
