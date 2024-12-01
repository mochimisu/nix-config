{ config, lib, ... }:
{
  options.variables = lib.mkOption {
    type = lib.types.attrs;
    default = {
      keyboardLayout = "qwerty";
      hyprpanel = {
        hiddenMonitors = [];
        cpuTempSensor = "/dev/hwmon_aquaflow_water_temp_sensor/temp1_input";
      };
    };
  };
  config._module.args.variables = config.variables;
}
