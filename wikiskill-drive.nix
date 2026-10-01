{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.services.wikiskillDrive;
  host = config.networking.hostName;
  state = "/home/brandon/.local/state/wikiskill-drive";
  registry = pkgs.writeText "wikiskill-${host}-registry.json" (builtins.toJSON {
    version = 1;
    sync_engine = "rclone-bisync";
    sync_peers = [];
    state_dir = "/home/brandon/.local/state/wikiskill";
    hosts.${host} = { hostname = host; transport = "local"; path = "/home/brandon/stuff/wikiskill"; };
    runners.${host} = { corpus_host = host; execution_route.kind = "local"; };
    plugin_source = { inherit host; path = "/home/brandon/plugins/wikiskill"; sync_folder = "plugin"; editing_host = "blackmoon"; };
  });
  filters = pkgs.writeText "wikiskill-drive.filters" ''
    - .*
    - /.*/**
    - /_*/**
    - /node_modules/**
    - /wiki/**
    - /scripts/**
    - /bin/**
    - /test/**
    - /tests/**
    - /AGENTS.md
    - /SKILL.md
    - /agent.md
    + /RCLONE_TEST
    + *.md
    + *.md.conflict*
    + *.png
    + *.png.conflict*
    + *.jpg
    + *.jpg.conflict*
    + *.jpeg
    + *.jpeg.conflict*
    + *.webp
    + *.webp.conflict*
    + *.svg
    + *.svg.conflict*
    + *.pdf
    + *.pdf.conflict*
    - **
  '';
  pluginFilters = pkgs.writeText "wikiskill-plugin.filters" ''
    - .env
    - .env.*
    - .AGENTS.LOCAL.md
    - hosts.json
    - *.pem
    - *.key
    - node_modules/**
    - __pycache__/**
    - *.pyc
    - *.tmp
    - *.swp
    - *~
    + /.codex-plugin/**
    - .*/**
    - .*
  '';
  sync = pkgs.writeShellApplication {
    name = "wikiskill-drive-sync";
    runtimeInputs = [ pkgs.coreutils pkgs.rclone pkgs.util-linux ];
    text = ''
      umask 077
      install -d -m 700 ${state}
      exec 9>${state}/sync.lock
      flock -n 9
      # rclone refreshes tokens in this writable copy, never in /run/secrets.
      if [ ! -e ${state}/rclone.conf ]; then
        seed=$(mktemp ${state}/.seed.XXXXXX)
        trap 'rm -f "$seed"' EXIT
        install -m 600 /run/secrets/wikiskill-drive "$seed"
        mv "$seed" ${state}/rclone.conf
        trap - EXIT
      fi
      # One timer/credential, separate baselines and backups for the two trees.
      target="''${1:-all}"
      if [ "$#" -gt 0 ]; then shift; fi
      case "$target" in
        all) trees=(wiki plugin) ;;
        wiki|plugin) trees=("$target") ;;
        *) echo "Usage: wikiskill-drive-sync [all|wiki|plugin] [rclone flags]" >&2; exit 2 ;;
      esac
      failed=0
      for tree in "''${trees[@]}"; do
        case "$tree" in
          wiki) root=/home/brandon/stuff/wikiskill; filters=${filters} ;;
          plugin) root=/home/brandon/plugins/wikiskill; filters=${pluginFilters} ;;
        esac
        install -d -m 700 "${state}/$tree"
        # bisync writes a .md5 sidecar next to its filter file.
        install -m 600 "$filters" "${state}/$tree/filters"
        stamp=$(date -u +%Y%m%dT%H%M%S.%N)
        if ! rclone bisync "$root" "wikiskill-drive:$tree" \
          --config ${state}/rclone.conf \
          --drive-root-folder-id ${lib.escapeShellArg cfg.folderId} \
          --workdir "${state}/$tree/bisync" --filters-file "${state}/$tree/filters" \
          --check-access --compare size,checksum \
          --conflict-resolve none --conflict-loser num \
          --backup-dir1 "${state}/backups/$tree/$stamp" \
          --backup-dir2 "wikiskill-drive:backups/${host}/$tree/$stamp" \
          --resilient --recover --max-delete 10 --drive-skip-gdocs "$@"; then
          failed=1
        fi
      done
      exit "$failed"
    '';
  };
in {
  imports = [ inputs.sops-nix.nixosModules.sops ];

  options.services.wikiskillDrive = {
    enable = lib.mkEnableOption "direct Google Drive wiki and plugin-source sync (replaces both Syncthing folders)";
    sopsFile = lib.mkOption {
      type = lib.types.path;
      default = ./secrets/wikiskill-drive.enc;
      description = "SOPS-encrypted binary rclone config shared by all clients.";
    };
    folderId = lib.mkOption {
      type = lib.types.str;
      default = "10tbl7eQcRKXASx-wIwPVoA9trSmF3QMn";
      description = "Google Drive folder containing wiki/, plugin/ and backups/.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Preserve existing private registries and skill discovery entries.
    systemd.tmpfiles.rules = [
      "d /home/brandon/plugins 0755 brandon users - -"
      "d /home/brandon/plugins/wikiskill 0755 brandon users - -"
      "d /home/brandon/stuff/wikiskill 0755 brandon users - -"
      "d /home/brandon/.config/wikiskill 0700 brandon users - -"
      "C /home/brandon/.config/wikiskill/hosts.json 0600 brandon users - ${registry}"
      "d /home/brandon/.agents/skills 0755 brandon users - -"
      "L /home/brandon/.agents/skills/wikiskill - brandon users - /home/brandon/plugins/wikiskill/skills/wikiskill"
    ];
    # Compatibility with the current nixpkgs; upstream sops-nix still uses Go 1.25.
    sops.package = lib.mkDefault (import inputs.sops-nix {
      pkgs = pkgs.extend (_: _: { buildGo125Module = pkgs.buildGoModule; });
    }).sops-install-secrets;
    sops.secrets.wikiskill-drive = {
      sopsFile = cfg.sopsFile;
      format = "binary";
      key = "";
      owner = "brandon";
      group = "users";
      mode = "0400";
    };
    environment.systemPackages = [ sync ];
    systemd.services.wikiskill-drive = {
      description = "Sync Wikiskill directly with Google Drive";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" "syncthing.service" ]
        ++ lib.optional config.sops.useSystemdActivation "sops-install-secrets.service";
      requires = lib.optional config.sops.useSystemdActivation "sops-install-secrets.service";
      serviceConfig = {
        Type = "oneshot";
        User = "brandon";
        Group = "users";
        UMask = "0077";
        ExecStart = lib.getExe sync;
        KillSignal = "SIGINT";
        TimeoutStopSec = "100s";
        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };
    systemd.timers.wikiskill-drive = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitInactiveSec = "5m";
        RandomizedDelaySec = "30s";
      };
    };
  };
}
