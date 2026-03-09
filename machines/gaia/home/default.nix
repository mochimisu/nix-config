{ ... }: {
  variables.isGui = false;
  variables.kitty.sshBackground = "#0a3a21";

  imports = [
    ./fastfetch.nix
  ];

  home.shellAliases = {
    matter-backup-sync = "sudo matter-protondrive-backup --backup-dir /earth/backups/matter --sops-config /home/brandon/stuff/nix-config/.sops.yaml";
  };
}
