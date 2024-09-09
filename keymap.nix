{ lib, config, pkgs, ... }:

let
  custom_symbols = pkgs.writeText "custom" ''
partial alphanumeric_keys
xkb_symbols "dvorak-custom" {
    include "us(dvorak)"
    name[Group1]= "English (Dvorak, custom)";

    key <ESC>  {[      grave,  asciitilde ]};
    key <TLDE> {[ Escape ]};
    key <RALT> {[ ISO_Level3_Shift] };
    key <CAPS> {[ Control_L ]};
    key <AD01> {[ apostrophe,    quotedbl,         Home,  dead_diaeresis ]};
    key <AD02> {[      comma,    less,            KP_Up,  dead_caron ]};
    key <AD03> {[     period,    greater,           End,  periodcentered ]};
    key <AD04> {[          p,    P,               Prior ]};
    key <AC01> {[          a,    A,             KP_Left ]};
    key <AC02> {[          o,    O,             KP_Down ]};
    key <AC03> {[          e,    E,            KP_Right ]};
    key <AC04> {[          u,    U,                Next ]};

    key <BKSL> {[ BackSpace, BackSpace,          Delete ]};
    key <BKSP> {[ backslash,       bar,      asciitilde,       asciitilde ]};

    modifier_map Control { <CAPS> };

    include "level3(ralt_switch)"
};
  '';
in
{
  services.xserver.xkb.extraLayouts.custom = {
    description ="Custom layout";
    languages = ["eng"];
    symbolsFile = custom_symbols;
  };

  services.xserver.xkb.layout = "custom";
  console.useXkbConfig = true;
}
