{pkgs, ...}: let
  ebookLibrary = "/earth/books";
  kavitaData = "/earth/kavita";
  kavitaTokenKey = "/etc/secret/kavita-token-key";
  koreaderSyncState = "/earth/koreader-sync";
  kavitaBookDropOrganizer = pkgs.writeShellApplication {
    name = "kavita-book-drop-organize";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
    ];
    text = ''
      set -euo pipefail

      hash_file() {
        sha256sum "$1" | cut -d ' ' -f 1
      }

      find_existing_duplicate() {
        local candidate="$1"
        local candidate_hash existing
        candidate_hash="$(hash_file "$candidate")"

        while IFS= read -r -d "" existing; do
          if [ "$(hash_file "$existing")" = "$candidate_hash" ]; then
            printf '%s\n' "$existing"
            return 0
          fi
        done < <(find ${ebookLibrary} -mindepth 2 -type f -iname '*.epub' -print0)

        return 1
      }

      find ${ebookLibrary} -maxdepth 1 -type f -iname '*.epub' -print0 | while IFS= read -r -d "" file; do
        base="$(basename "$file")"
        stem="''${base%.*}"
        dir="${ebookLibrary}/$stem"
        target="$dir/$base"

        if duplicate="$(find_existing_duplicate "$file")"; then
          echo "Removing duplicate EPUB drop: $file matches $duplicate"
          rm -f -- "$file"
          continue
        fi

        if [ -e "$target" ]; then
          if [ "$(hash_file "$file")" = "$(hash_file "$target")" ]; then
            echo "Removing duplicate EPUB drop: $file matches $target"
            rm -f -- "$file"
            continue
          fi

          suffix="$(date -u +%Y%m%dT%H%M%SZ)-$(stat -c %i "$file")"
          dir="${ebookLibrary}/$stem-$suffix"
          target="$dir/$base"
        fi

        install -d -m 0775 -o kavita -g media "$dir"
        mv "$file" "$target"
        chown kavita:media "$target"
        chmod 0664 "$target"
      done

      declare -A kept_by_hash=()
      while IFS= read -r -d "" record; do
        file="''${record#* }"
        hash="$(hash_file "$file")"

        if [ -n "''${kept_by_hash[$hash]+set}" ]; then
          echo "Removing duplicate organized EPUB: $file matches ''${kept_by_hash[$hash]}"
          rm -f -- "$file"
          rmdir --ignore-fail-on-non-empty "$(dirname "$file")" || true
        else
          kept_by_hash[$hash]="$file"
        fi
      done < <(find ${ebookLibrary} -mindepth 2 -type f -iname '*.epub' -printf '%T@ %p\0' | sort -z -n)
    '';
  };
in {
  services.kavita = {
    enable = true;
    dataDir = kavitaData;
    tokenKeyFile = kavitaTokenKey;
    settings = {
      Port = 8083;
      IpAddresses = "0.0.0.0,::";
    };
  };

  virtualisation.oci-containers.containers.koreader-sync = {
    image = "docker.io/koreader/kosync:latest";
    autoStart = true;
    ports = [
      "7200:7200"
      "17200:17200"
    ];
    volumes = [
      "${koreaderSyncState}/redis:/var/lib/redis"
      "${koreaderSyncState}/logs/app:/app/koreader-sync-server/logs"
      "${koreaderSyncState}/logs/redis:/var/log/redis"
    ];
    environment = {
      ENABLE_USER_REGISTRATION = "true";
    };
  };

  networking.firewall.allowedTCPPorts = [
    8083
    7200
    17200
  ];

  users.groups.media.members = ["kavita"];

  systemd.services.kavita-book-drop-organize = {
    description = "Move root-level ebook drops into Kavita-readable book folders";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${kavitaBookDropOrganizer}/bin/kavita-book-drop-organize";
    };
  };

  systemd.paths.kavita-book-drop-organize = {
    description = "Watch for EPUB drops in ${ebookLibrary}";
    wantedBy = ["multi-user.target"];
    pathConfig = {
      PathExistsGlob = "${ebookLibrary}/*.epub";
      Unit = "kavita-book-drop-organize.service";
    };
  };

  systemd.timers.kavita-book-drop-organize = {
    description = "Periodically organize missed Kavita ebook drops";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "5m";
      Unit = "kavita-book-drop-organize.service";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${ebookLibrary} 0775 kavita media - -"
    "d ${kavitaData} 0770 kavita media - -"
    "d ${koreaderSyncState} 0750 root root - -"
    "d ${koreaderSyncState}/redis 0750 root root - -"
    "d ${koreaderSyncState}/logs 0750 root root - -"
    "d ${koreaderSyncState}/logs/app 0750 root root - -"
    "d ${koreaderSyncState}/logs/redis 0750 root root - -"
  ];

  system.activationScripts.kavitaDataAccess = ''
    if [ -d ${kavitaData} ]; then
      chown kavita:media ${kavitaData}
      chmod 0770 ${kavitaData}
      ${pkgs.acl}/bin/setfacl -R -m u:brandon:rwX,u:kavita:rwX,g:media:rwX ${kavitaData}
      ${pkgs.acl}/bin/setfacl -R -d -m u:brandon:rwX,u:kavita:rwX,g:media:rwX ${kavitaData}
    fi
  '';

  system.activationScripts.kavitaTokenKey = ''
    install -d -m 0750 /etc/secret
    if [ ! -f ${kavitaTokenKey} ]; then
      ${pkgs.coreutils}/bin/head -c 64 /dev/urandom | ${pkgs.coreutils}/bin/base64 --wrap=0 > ${kavitaTokenKey}
      chmod 0600 ${kavitaTokenKey}
    fi
  '';
}
