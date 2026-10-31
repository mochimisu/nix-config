# Evaluate native policy; --arg includeComet true additionally needs an ARM builder.
{includeComet ? false}:
let
  f = builtins.getFlake (toString ../..);
  lib = f.inputs.nixpkgs.lib;
  home = c: let s = c.variables.desktopStyle; in {
    apps = s.apps.enable;
    desktopIntegration = s.apps.enable && s.apps.desktopIntegration.enable;
    notifications = s.notifications.enable;
    shell = s.shell.enable;
    launcher = s.launcher.enable;
    media = s.mediaFeedback.enable;
  };
  system = c: home c.home-manager.users.brandon // {
    greeter = c.desktopStyle.greeter.enable or false;
    boot = c.desktopStyle.boot.enable or false;
  };
  native = lib.genAttrs ["blackmoon" "oasis" "espresso" "glasscastle"] (n: system f.nixosConfigurations.${n}.config);
  expectedNative = {apps=true; desktopIntegration=true; notifications=true; shell=true; launcher=true; media=true; greeter=true; boot=true;};
  cove = home f.homeConfigurations."deck@cove".config;
  comet = home f.homeConfigurations."steamos@comet".config;
  gaia = system f.nixosConfigurations.gaia.config;
  darwin = home f.darwinConfigurations.oai-dev.config.home-manager.users.brandonw;
  standalone = home f.homeConfigurations.brandon.config;
in
assert builtins.all (n: native.${n} == expectedNative) (builtins.attrNames native);
assert cove == {apps=true; desktopIntegration=false; notifications=false; shell=false; launcher=false; media=false;};
assert !includeComet || comet == cove // {notifications=true;};
assert builtins.all (v: !v) (builtins.attrValues gaia);
assert builtins.all (v: !v) (builtins.attrValues darwin);
assert standalone == {apps=true; desktopIntegration=true; notifications=true; shell=false; launcher=false; media=false;};
native // {inherit cove gaia standalone darwin;} // lib.optionalAttrs includeComet {inherit comet;}
