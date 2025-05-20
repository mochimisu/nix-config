{ pkgs, ... }:
let
  sshAddScript = pkgs.writeShellScript "ssh-add.sh" ''
    for key in ~/.ssh/id_rsa ~/.ssh/id_ed25519; do
      if [ -f "$key" ]; then
        ssh-add "$key";
      fi;
    done
  '';
in
{
  wayland.windowManager.hyprland.settings."exec-once" = [
    "${sshAddScript}/bin/ssh-add.sh"
  ];
}


