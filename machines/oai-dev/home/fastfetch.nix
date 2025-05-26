{ pkgs, ... }:
let
  oaiLogo = pkgs.writeText "oai.txt" ''
             .l0NMMNk:
           c0MMN0OOKWMWO;
         :NMK:.      ,XMMWMMMWKx:.
       .lMMc      ,dXMW0l;'.';lOMMk.
    :OWMMMd   .l0WMXd,          .xMMc
  oWM0c:MM:  .MWk:.    ;xXNx:.    lMM,
 0MN'  .MM:  .Mx   'oKNx;.l0MMXd'  WMx
lMM.   .MM:  .MOckNOOWOc.    ,dXMW0MMo
OMX    .MM:  .MNo,    ,oNXd;    .:0MMd
lMM.   .MMl  .Mx        xMlkN0o.   'XM0
 0MN'   .l0NkoMx        xM.  lMM.   .MMl
  dMM0c.    ,dXNd,    ,dNM.  :MM.    XMO
  oMMOWMNx;    .:kW00Nk:OM.  :MM.   .MMl
  xMW  'oKMM0o':kN0l.   xM.  :MM.  ,NMO
  'MMl     ;xXXd,    .:kWM.  :MM:cKMWl
   cMMx.          ,dXMWOc.   dMMMNk:
    .kMM0o;'.';o0MMKo'      lMMl
       ;x0NWMWWMMX,      .cKMN;
               ;kWMWK0OKNMW0:
                  :kNMMNOc'';
in
{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        source = oaiLogo;
        type = "file";
        height = 20;
        padding = {
          top = 4;
          left = 2;
        };
        color = {
          "1" = "white";
        };
      };
      modules = [
        "title"
        "separator"
        "os"
        "host"
        "kernel"
        "uptime"
        "packages"
        "shell"
        "display"
        "de"
        "wm"
        "wmtheme"
        "theme"
        "icons"
        "font"
        "cursor"
        "terminal"
        "terminalfont"
        "cpu"
        "gpu"
        "memory"
        "swap"
        "disk"
        "localip"
        "battery"
        "poweradapter"
        "locale"
        "break"
        "colors"
        ];
    };
  };
}
