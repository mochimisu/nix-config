{ config, lib, ... }:
{
  options.variables = lib.mkOption {
    type = lib.types.attrs;
    default = {
      keyboardLayout = "qwerty";
    };
  };
  config._module.args.variables = config.variables;
}
