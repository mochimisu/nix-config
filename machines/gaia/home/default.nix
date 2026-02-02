{ ... }: {
  variables.isGui = false;
  variables.kitty.sshBackground = "#0a3a21";

  imports = [
    ./fastfetch.nix
  ];
}
