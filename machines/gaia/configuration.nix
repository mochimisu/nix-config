{
  config,
  lib,
  pkgs,
  specialArgs,
  variables,
  inputs,
  ...
}: let
  mountDocs = pkgs.writeShellScriptBin "mountdocs" ''
    set -euo pipefail

    ENC_DIR=/earth/documents_enc
    MOUNT_DIR=/earth/documents

    if ! [ -d "$ENC_DIR" ]; then
      echo "Encrypted directory $ENC_DIR does not exist." >&2
      exit 1
    fi

    if ! [ -d "$MOUNT_DIR" ]; then
      ${pkgs.coreutils}/bin/install -d -m 0770 "$MOUNT_DIR"
    fi

    if ${pkgs.util-linux}/bin/mountpoint -q "$MOUNT_DIR"; then
      echo "$MOUNT_DIR is already mounted."
      exit 0
    fi

    exec ${pkgs.gocryptfs}/bin/gocryptfs "$ENC_DIR" "$MOUNT_DIR" "$@"
  '';

  umountDocs = pkgs.writeShellScriptBin "umountdocs" ''
    set -euo pipefail

    MOUNT_DIR=/earth/documents

    if ! ${pkgs.util-linux}/bin/mountpoint -q "$MOUNT_DIR"; then
      echo "$MOUNT_DIR is not currently mounted."
      exit 0
    fi

    if command -v fusermount3 >/dev/null 2>&1; then
      exec fusermount3 -u "$MOUNT_DIR"
    else
      exec ${pkgs.fuse}/bin/fusermount -u "$MOUNT_DIR"
    fi
  '';
in {
  imports = [
    ./transmission.nix
    ./home-assistant.nix
  ];

  networking.hostName = "gaia";

  # Disable the GUI stack on this host by skipping the shared GUI module.
  services.xserver.enable = lib.mkForce false;
  services.pipewire.enable = lib.mkForce false;
  variables.isGui = lib.mkForce false;

  environment.systemPackages = [
    pkgs.kitty.terminfo
    pkgs.gocryptfs
    pkgs.fuse
    mountDocs
    umountDocs
  ];

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "server string" = "gaia samba server";
        "workgroup" = "WORKGROUP";
        "map to guest" = "Bad User";
      };
      gaia = {
        path = "/earth";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "brandon";
        "force group" = "media";
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };

  services.immich = {
    enable = true;
    host = "0.0.0.0";
    port = 2283;
    openFirewall = true;
    mediaLocation = "/earth/immich-app";
    accelerationDevices = null;
  };

  # Keep the Immich database on the same disk as the media so it can be moved as
  # a unit (note: raw PGDATA reuse requires the same Postgres major version).
  services.postgresql = {
    # Immich module enables PostgreSQL; we override the storage location.
    # Keep it outside the Immich media folder to avoid permission/cleanup issues.
    dataDir = "/earth/immich-db";
    package = pkgs.postgresql_16;
  };

  users.users.brandon.extraGroups = ["fuse"];

  systemd.tmpfiles.rules = [
    "d /earth/documents 0770 brandon media - -"
    "d /earth/documents_enc 0770 brandon media - -"
    "d /earth/immich-app 0775 immich media - -"
    "d /earth/immich-app/library 0775 immich media - -"
    "d /earth/immich-db 0700 postgres postgres - -"
  ];

  system.stateVersion = "24.11";
}
