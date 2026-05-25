{pkgs, ...}: {
  services.jellyfin = {
    enable = true;
    group = "media";
    openFirewall = true;
  };

  environment.systemPackages = [
    pkgs.jellyfin
    pkgs.jellyfin-ffmpeg
  ];

  users.groups.media.members = ["jellyfin"];

  systemd.tmpfiles.rules = [
    "d /earth/transmission 0775 transmission media - -"
  ];
}
