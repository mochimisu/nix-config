{ pkgs, ... }:
let
  moonLogo = pkgs.writeText "moon.txt" ''
⠀⠀⠀⠀⠀⠀⠀⢀⡠⠔⠚⠉⠩⠍⠩⠍⢩⣶⣦⣤⡀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⡠⡲⠑⢈⣨⠵⠊⠁⠀⠀⠀⠈⠲⢌⡻⣿⣶⣄⡀⠀⠀⠀⠀
⠀⠀⠀⣠⡾⠊⠈⠉⠉⣑⣀⣀⠀⠀⠀⠀⠀⡶⢄⡈⢻⣿⠟⠻⣄⠀⠀⠀
⠀⠀⡐⡑⠁⢀⠏⢠⢞⠕⠚⠉⢻⣏⠀⠀⠀⠑⠀⢱⠀⠉⢇⠀⢹⣦⠀⠀
⠀⠰⣼⠀⠀⠀⢰⡎⠁⠀⠀⠀⠀⠁⠀⠀⠀⠀⠀⠃⠀⠀⠈⠘⡟⢿⡇⠀
⠀⢷⡿⢰⠓⠀⠀⢣⠀⠀⠀⠀⠀⠀⡄⠀⠀⠀⠀⠐⠀⢄⠄⠄⢣⣸⡿⠀
⠘⣸⠁⠸⠔⢀⡀⠀⠳⠦⢤⡶⠂⠀⠀⠀⠀⠀⠀⠀⠀⡀⠣⡆⠀⣿⣷⠂
⠀⣿⠀⠀⠀⠈⠁⠀⠀⠀⠀⠓⠀⠀⠀⠀⠀⠀⠀⠐⠁⠀⣀⢀⠿⢿⣿⠀
⠀⠸⡇⢀⠀⠀⡀⠀⠀⠀⠀⢄⠀⠀⠀⡄⠀⠀⠀⠀⢀⡞⢁⠄⠀⣼⡇⠀
⠀⠀⠻⡌⢆⠰⡠⠐⠈⠀⣤⠜⠒⢢⠀⠀⠀⠢⠄⢀⣈⣄⢾⢴⡿⡟⠀⠀
⠀⠀⠀⠹⣌⡿⢄⠀⠀⠀⠣⣄⢀⠶⠃⠀⢀⣀⣀⣤⣿⢿⣶⣯⠊⠀⠀⠀
⠀⠀⠀⠀⠈⠛⢷⣝⡢⢔⡀⠈⠂⠤⠤⠀⢉⣹⠿⣫⣴⡿⠛⠁⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠉⠛⠲⠤⣷⣦⣶⣶⣞⣛⠛⠿⠛⠋⠀⠀⠀⠀⠀⠀⠀'';
in
{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        source = moonLogo;
        type = "file";
        height = 13;
        padding = {
          top = 4;
          left = 2;
        };
        color = {
          "1" = "cyan";
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
