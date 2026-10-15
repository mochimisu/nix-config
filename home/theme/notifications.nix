{config, lib, ...}: let
  app = (import ./palettes.nix {inherit lib;}).app;
in {
  config = lib.mkIf config.variables.desktopStyle.notifications.enable {
    services.mako.settings = {
      width = 340;
      height = 140;
      max-icon-size = 32;
      icon-border-radius = 8;
      format = "<b>%s</b>\\n%b";
      background-color = lib.mkForce "${app.background}99";
      text-color = lib.mkForce app.text;
      border-color = lib.mkForce app.teal;
      border-size = lib.mkForce 2;
      border-radius = lib.mkForce 16;
      padding = "12,14";
      progress-color = lib.mkForce "over ${app.teal}";
      "urgency=low" = {
        background-color = lib.mkForce "${app.background}99";
        text-color = lib.mkForce app.text;
        border-color = app.lavender;
      };
      "urgency=critical" = {
        background-color = lib.mkForce "${app.background}99";
        text-color = lib.mkForce app.text;
        border-color = lib.mkForce app.red;
        border-size = lib.mkForce 2;
      };
    };
  };
}
