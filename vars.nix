{ config, lib, ... }:
{
  options.variables = lib.mkOption {
    type = lib.types.attrs;
    default = {
      keyboardLayout = "qwerty";
      hyprpanelHiddenMonitors = [];
    };
  };
  config._module.args.variables = config.variables;
}
