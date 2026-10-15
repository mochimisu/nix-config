# Platform-independent option/type tests; no GUI package or ARM IFD is forced.
let
  flake = builtins.getFlake (toString ../..);
  lib = flake.inputs.nixpkgs.lib;
  keys = ["apps" "notifications" "shell" "launcher" "mediaFeedback"];
  eval = values: (lib.evalModules {modules = [../../vars.nix {variables.desktopStyle = values;}];}).config.variables.desktopStyle;
  enabled = cfg: builtins.filter (key: cfg.${key}.enable) keys;
  defaults = eval {};
  independent = builtins.all (key: enabled (eval {${key}.enable = true;}) == [key]) keys;
  invalid = builtins.tryEval (builtins.deepSeq (enabled (eval {apps.enable = "yes";})) true);
in
assert enabled defaults == [];
assert !defaults.apps.desktopIntegration.enable;
assert defaults.launcher.wallpaperPackage == null;
assert independent;
assert !invalid.success;
{defaultsOff = true; independent = true; rejectsInvalidType = true; optionalWallpaper = true;}
