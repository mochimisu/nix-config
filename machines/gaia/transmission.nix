{
  config,
  lib,
  pkgs,
  ...
}: let
  settingsPath = "/var/lib/transmission/.config/transmission-daemon/settings.json";
  secretPath = "/etc/secret/transmission-rpc-password";

  ensureSecretScript = pkgs.writeShellScriptBin "ensure-transmission-rpc-secret" ''
    set -euo pipefail

    SECRET_PATH='${secretPath}'

    if [ -f "$SECRET_PATH" ]; then
      exit 0
    fi

    prompt() {
      ${pkgs.coreutils}/bin/stty -echo
      printf "%s" "$1" >&2
      IFS= read -r value
      ${pkgs.coreutils}/bin/stty echo
      printf '\n' >&2
      printf "%s" "$value"
    }

    ask_pwd() {
      if [ -t 0 ]; then
        prompt "$1"
      else
        ${pkgs.systemd}/bin/systemd-ask-password "$1"
      fi
    }

    password=$(ask_pwd "Enter new Transmission RPC password: ")
    confirm=$(ask_pwd "Confirm password: ")

    if [ -z "$password" ]; then
      echo "Empty password not allowed." >&2
      exit 1
    fi

    if [ "$password" != "$confirm" ]; then
      echo "Passwords did not match." >&2
      exit 1
    fi

    umask 027
    dir=$(${pkgs.coreutils}/bin/dirname "$SECRET_PATH")
    ${pkgs.coreutils}/bin/install -d -m 0750 -o root -g media "$dir"
    ${pkgs.coreutils}/bin/install -m 0640 -o root -g media /dev/null "$SECRET_PATH"
    printf '%s' "$password" > "$SECRET_PATH"
    ${pkgs.coreutils}/bin/chmod 0640 "$SECRET_PATH"
    echo "Transmission RPC password stored at $SECRET_PATH." >&2
  '';

  postProcessScript = pkgs.writeShellScriptBin "transmission-postprocess" ''
    set -eo pipefail

    PATH="${lib.makeBinPath [pkgs.coreutils pkgs.findutils pkgs.unrar pkgs.unzip]}:$PATH"

    torrent_dir="$TR_TORRENT_DIR"
    torrent_name="$TR_TORRENT_NAME"

    if [ -z "$torrent_dir" ] || [ -z "$torrent_name" ]; then
      exit 0
    fi

    target_path="$torrent_dir/$torrent_name"

    if [ -d "$target_path" ]; then
      work_dir="$target_path"
    else
      work_dir="$(dirname "$target_path")"
    fi

    did_extract=0

    rar_primary=$(find "$work_dir" -maxdepth 1 -type f \( -iname '*.part1.rar' -o -iname '*.part01.rar' \) -print -quit || true)
    if [ -z "$rar_primary" ]; then
      rar_primary=$(find "$work_dir" -maxdepth 1 -type f -iname '*.rar' ! -iname '*.part*.rar' -print -quit || true)
    fi

    if [ -n "$rar_primary" ]; then
      "${pkgs.unrar}/bin/unrar" x -o+ "$rar_primary" "$work_dir" && did_extract=1
    fi

    zip_file=$(find "$work_dir" -maxdepth 1 -type f -iname '*.zip' -print -quit || true)

    if [ -n "$zip_file" ]; then
      "${pkgs.unzip}/bin/unzip" -o "$zip_file" -d "$work_dir" && did_extract=1
    fi

    if [ "$did_extract" -eq 1 ]; then
      chmod -R g+rw "$work_dir" || true
    fi

    exit 0
  '';

  transmissionSettings = {
    "download-dir" = "/gaia/transmission";
    "incomplete-dir" = "/gaia/transmission/incomplete";
    "incomplete-dir-enabled" = true;
    "umask" = 2;
    "rpc-bind-address" = "0.0.0.0";
    "rpc-host-whitelist-enabled" = false;
    "rpc-whitelist-enabled" = false;
    "script-torrent-done-enabled" = true;
    "script-torrent-done-filename" = "${postProcessScript}/bin/transmission-postprocess";
  };

  settingsSeed = pkgs.writeTextFile {
    name = "transmission-settings.json";
    text = builtins.toJSON transmissionSettings;
    executable = false;
    destination = "/transmission/settings.json";
  };
in {
  environment.systemPackages = [
    pkgs.transmission_4
    ensureSecretScript
  ];

  users.groups.media.members = ["brandon" "transmission"];

  systemd.tmpfiles.rules = [
    "d /gaia 0775 root media - -"
    "d /gaia/transmission 0775 transmission media - -"
    "d /gaia/transmission/incomplete 0775 transmission media - -"
    "d /etc/secret 0750 root media - -"
    "d /var/lib/transmission 0750 transmission media - -"
    "d /var/lib/transmission/.config 0750 transmission media - -"
    "d /var/lib/transmission/.config/transmission-daemon 0750 transmission media - -"
  ];

  system.activationScripts.transmissionSecret = ''
    if [ ! -f '${secretPath}' ]; then
      if ${ensureSecretScript}/bin/ensure-transmission-rpc-secret; then
        echo "Transmission RPC password created."
      else
        echo "Transmission RPC password not set; run 'sudo ${ensureSecretScript}/bin/ensure-transmission-rpc-secret' to create it."
      fi
    fi
  '';

  services.transmission = {
    enable = true;
    user = "transmission";
    group = "media";
    openRPCPort = true;
    package = pkgs.transmission_4;
    settings = transmissionSettings;
  };

  systemd.services.transmission-daemon.serviceConfig.ReadWritePaths = [
    "/gaia/transmission"
  ];

  systemd.services.transmission.preStart = lib.mkAfter ''
    SECRET_PATH='${secretPath}'
    SETTINGS_PATH='${settingsPath}'
    CONFIG_DIR=$(${pkgs.coreutils}/bin/dirname "$SETTINGS_PATH")

    if [ ! -d "$CONFIG_DIR" ]; then
      ${pkgs.coreutils}/bin/mkdir -p "$CONFIG_DIR"
      ${pkgs.coreutils}/bin/chmod 0750 "$CONFIG_DIR"
    fi

    if [ ! -f "$SETTINGS_PATH" ]; then
      ${pkgs.coreutils}/bin/install -m 0640 ${settingsSeed}/transmission/settings.json "$SETTINGS_PATH"
    fi

    if [ ! -f "$SECRET_PATH" ]; then
      echo "Transmission RPC password missing; run 'sudo ${ensureSecretScript}/bin/ensure-transmission-rpc-secret' to set it." >&2
      exit 1
    fi

    password=$(${pkgs.coreutils}/bin/cat "$SECRET_PATH")
    tmp=$(${pkgs.coreutils}/bin/mktemp)

    ${pkgs.jq}/bin/jq --arg pwd "$password" '
      .["rpc-authentication-required"]=true
      | .["rpc-password"]=$pwd
    ' "$SETTINGS_PATH" > "$tmp"

    ${pkgs.coreutils}/bin/install -m 0640 "$tmp" "$SETTINGS_PATH"
    ${pkgs.coreutils}/bin/chmod 0640 "$SETTINGS_PATH"
    ${pkgs.coreutils}/bin/rm -f "$tmp"
  '';
}
