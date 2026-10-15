{pkgs ? import (builtins.getFlake (toString ../..)).inputs.nixpkgs {system = builtins.currentSystem;}}:
pkgs.writeShellApplication {
  name = "test-desktop-style";
  runtimeInputs = with pkgs; [(python3.withPackages (ps: [ps.pillow])) nodejs quickshell xorg-server dbus sway grim eww];
  text = ''
    export FONTCONFIG_FILE="${pkgs.makeFontsConf {fontDirectories = [pkgs.montserrat pkgs.cascadia-code pkgs.font-awesome];}}"
    export DESKTOP_QML_IMPORTS="${pkgs.qt6.qtdeclarative}/lib/qt-6/qml:${pkgs.qt6.qtmultimedia}/lib/qt-6/qml"
    export DESKTOP_QT_PLUGINS="${pkgs.qt6.qtmultimedia}/lib/qt-6/plugins"
    exec python3 ${./run.py} --fixtures ${./.} "$@"
  '';
}
