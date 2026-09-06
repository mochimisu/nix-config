{ config, ... }: {
  variables.isGui = false;
  variables.kitty.sshBackground = "#0a3a21";
  variables.obsidianVaultPath = "/earth/syncthing/obsidian";

  imports = [
    ./fastfetch.nix
  ];

  home.shellAliases = {
    matter-backup-sync = "sudo matter-protondrive-backup --backup-dir /earth/backups/matter --sops-config /home/brandon/stuff/nix-config/.sops.yaml";
  };

  # Codex Remote needs the standalone installer-managed package tree so its
  # app-server daemon and updater agree on the active release. The standalone
  # installer owns ~/.local/bin/codex and ~/.codex/packages/standalone/current.
  systemd.user.services.codex-remote-control = {
    Unit = {
      Description = "Codex managed app-server with remote control";
      After = ["network-online.target"];
      Wants = ["network-online.target"];
      ConditionPathExists = "${config.home.homeDirectory}/.local/bin/codex";
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.homeDirectory}/.local/bin/codex app-server daemon bootstrap --remote-control";
      ExecStop = "${config.home.homeDirectory}/.local/bin/codex app-server daemon stop";
      RemainAfterExit = true;
      WorkingDirectory = config.home.homeDirectory;
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "CODEX_HOME=${config.home.homeDirectory}/.codex"
        "RUST_LOG=codex_app_server_transport::transport::remote_control=info"
      ];
    };

    Install.WantedBy = ["default.target"];
  };
}
