{ ... }: {
  variables.isGui = false;
  variables.kitty.sshBackground = "#0b2a1f";

  imports = [
    ./fastfetch.nix
  ];
}
