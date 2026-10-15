{config, lib, pkgs, ...}: let
  app = (import ./palettes.nix {inherit lib;}).app;
in {
  config = lib.mkIf config.variables.desktopStyle.mediaFeedback.enable {
    home.packages = [(import ./media-osd {inherit pkgs;})];
    services.mako.settings = {
      "category=sekai.volume" = {
        anchor = "bottom-center";
        output = "";
        width = 280;
        height = 70;
        margin = "24";
        padding = "14,18";
        font = "Montserrat Semi-Bold 12";
        format = "%s";
        history = false;
      };
      "category=sekai.brightness" = {
        anchor = "bottom-center";
        output = "";
        width = 280;
        height = 90;
        margin = "24";
        padding = "14,18";
        font = "Montserrat Semi-Bold 12";
        progress-color = "over ${app.lavender}";
        history = false;
      };
    };
  };
}
