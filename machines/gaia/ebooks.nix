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

      find ${ebookLibrary} -maxdepth 1 -type f -iname '*.epub' -print0 | while IFS= read -r -d "" file; do
        base="$(basename "$file")"
        stem="''${base%.*}"
        dir="${ebookLibrary}/$stem"
        target="$dir/$base"

        if [ -e "$target" ]; then
          suffix="$(date -u +%Y%m%dT%H%M%SZ)-$(stat -c %i "$file")"
          dir="${ebookLibrary}/$stem-$suffix"
          target="$dir/$base"
        fi

        install -d -m 0775 -o kavita -g media "$dir"
        mv "$file" "$target"
        chown kavita:media "$target"
        chmod 0664 "$target"
      done
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
    "d ${kavitaData} 0750 kavita kavita - -"
    "d ${koreaderSyncState} 0750 root root - -"
    "d ${koreaderSyncState}/redis 0750 root root - -"
    "d ${koreaderSyncState}/logs 0750 root root - -"
    "d ${koreaderSyncState}/logs/app 0750 root root - -"
    "d ${koreaderSyncState}/logs/redis 0750 root root - -"
  ];

  system.activationScripts.kavitaTokenKey = ''
    install -d -m 0750 /etc/secret
    if [ ! -f ${kavitaTokenKey} ]; then
      ${pkgs.coreutils}/bin/head -c 64 /dev/urandom | ${pkgs.coreutils}/bin/base64 --wrap=0 > ${kavitaTokenKey}
      chmod 0600 ${kavitaTokenKey}
    fi
  '';
}
