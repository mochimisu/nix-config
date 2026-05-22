{ lib, variables, ... }: let
  lua = lib.generators.mkLuaInline;
in {
  imports = [ ../../../vars.nix ];
  wayland.windowManager.hyprland.settings = lib.mkIf (variables.keyboardLayout == "qwerty") {
    bind = [
      {_args = [(lua "mod .. \" + q\"") (lua "hl.dsp.exec_cmd(terminal)")];}
      {_args = [(lua "mod .. \" + C\"") (lua "hl.dsp.window.close()")];}
      {_args = [(lua "mod .. \" + M\"") (lua "hl.dsp.exit()")];}
      {_args = [(lua "mod .. \" + G\"") (lua "hl.dsp.exec_cmd(fileManager)")];}
      {_args = [(lua "mod .. \" + l\"") (lua "hl.dsp.window.float({ action = \"toggle\" })")];}
      {_args = [(lua "mod .. \" + o\"") (lua "hl.dsp.exec_cmd(menu)")];}
      {_args = [(lua "mod .. \" + SHIFT + o\"") (lua "hl.dsp.exec_cmd(menuAll)")];}
      {_args = [(lua "mod .. \" + r\"") (lua "hl.dsp.window.pseudo()")];}
      {_args = [(lua "mod .. \" + f\"") (lua "hl.dsp.layout(\"togglesplit\")")];}

      # Move focus with mainMod + movement keys
      {_args = [(lua "mod .. \" + a\"") (lua "hl.dsp.focus({ direction = \"left\" })")];}
      {_args = [(lua "mod .. \" + d\"") (lua "hl.dsp.focus({ direction = \"right\" })")];}
      {_args = [(lua "mod .. \" + w\"") (lua "hl.dsp.focus({ direction = \"up\" })")];}
      {_args = [(lua "mod .. \" + s\"") (lua "hl.dsp.focus({ direction = \"down\" })")];}
      {_args = [(lua "mod .. \" + SHIFT + a\"") (lua "hl.dsp.window.swap({ direction = \"left\" })")];}
      {_args = [(lua "mod .. \" + SHIFT + d\"") (lua "hl.dsp.window.swap({ direction = \"right\" })")];}
      {_args = [(lua "mod .. \" + SHIFT + w\"") (lua "hl.dsp.window.swap({ direction = \"up\" })")];}
      {_args = [(lua "mod .. \" + SHIFT + s\"") (lua "hl.dsp.window.swap({ direction = \"down\" })")];}
      {_args = [(lua "mod .. \" + CONTROL + a\"") (lua "hl.dsp.window.move({ direction = \"left\" })")];}
      {_args = [(lua "mod .. \" + CONTROL + d\"") (lua "hl.dsp.window.move({ direction = \"right\" })")];}
      {_args = [(lua "mod .. \" + CONTROL + w\"") (lua "hl.dsp.window.move({ direction = \"up\" })")];}
      {_args = [(lua "mod .. \" + CONTROL + s\"") (lua "hl.dsp.window.move({ direction = \"down\" })")];}
      {_args = [(lua "mod .. \" + up\"") (lua "hl.dsp.focus({ direction = \"up\" })")];}
      {_args = [(lua "mod .. \" + left\"") (lua "hl.dsp.focus({ direction = \"left\" })")];}
      {_args = [(lua "mod .. \" + right\"") (lua "hl.dsp.focus({ direction = \"right\" })")];}
      {_args = [(lua "mod .. \" + down\"") (lua "hl.dsp.focus({ direction = \"down\" })")];}
      ];
    config.input = {
      kb_options = "ctrl:nocaps";
    };
  };
}
