{
  lib,
  variables,
  ...
}: let
  lua = lib.generators.mkLuaInline;
in {
  imports = [../../../vars.nix];
  wayland.windowManager.hyprland.settings = lib.mkIf (variables.keyboardLayout == "dvorak") {
    bind = [
      {_args = [(lua "mod .. \" + apostrophe\"") (lua "hl.dsp.exec_cmd(terminal)")];}
      {_args = [(lua "mod .. \" + C\"") (lua "hl.dsp.window.close()")];}
      {_args = [(lua "mod .. \" + SHIFT + M\"") (lua "hl.dsp.exit()")];}
      {_args = [(lua "mod .. \" + G\"") (lua "hl.dsp.exec_cmd(fileManager)")];}
      {_args = [(lua "mod .. \" + V\"") (lua "hl.dsp.window.float({ action = \"toggle\" })")];}
      {_args = [(lua "mod .. \" + U\"") (lua "hl.dsp.window.pseudo()")];}
      {_args = [(lua "mod .. \" + P\"") (lua "hl.dsp.layout(\"togglesplit\")")];}

      # Move focus with mod + arrow keys
      {_args = [(lua "mod .. \" + a\"") (lua "hl.dsp.focus({ direction = \"left\" })")];}
      {_args = [(lua "mod .. \" + e\"") (lua "hl.dsp.focus({ direction = \"right\" })")];}
      {_args = [(lua "mod .. \" + comma\"") (lua "hl.dsp.focus({ direction = \"up\" })")];}
      {_args = [(lua "mod .. \" + o\"") (lua "hl.dsp.focus({ direction = \"down\" })")];}
      {_args = [(lua "mod .. \" + SHIFT + a\"") (lua "hl.dsp.window.swap({ direction = \"left\" })")];}
      {_args = [(lua "mod .. \" + SHIFT + e\"") (lua "hl.dsp.window.swap({ direction = \"right\" })")];}
      {_args = [(lua "mod .. \" + SHIFT + comma\"") (lua "hl.dsp.window.swap({ direction = \"up\" })")];}
      {_args = [(lua "mod .. \" + SHIFT + o\"") (lua "hl.dsp.window.swap({ direction = \"down\" })")];}
      {_args = [(lua "mod .. \" + CONTROL + a\"") (lua "hl.dsp.window.move({ direction = \"left\" })")];}
      {_args = [(lua "mod .. \" + CONTROL + e\"") (lua "hl.dsp.window.move({ direction = \"right\" })")];}
      {_args = [(lua "mod .. \" + CONTROL + comma\"") (lua "hl.dsp.window.move({ direction = \"up\" })")];}
      {_args = [(lua "mod .. \" + CONTROL + o\"") (lua "hl.dsp.window.move({ direction = \"down\" })")];}
    ];
  };
}
