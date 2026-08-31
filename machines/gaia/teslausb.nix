{
  config,
  pkgs,
  ...
}: let
  archiveDir = "/earth/blackvue/tesla-redbean";
  teslaUsbUid = 1500;
  teslaUsbGid = 1500;
in {
  environment.systemPackages = [pkgs.rsync];

  users.groups.teslausb.gid = teslaUsbGid;
  users.users.teslausb = {
    isNormalUser = true;
    uid = teslaUsbUid;
    group = "teslausb";
    extraGroups = ["media"];
    home = "/var/lib/teslausb";
    homeMode = "0700";
    createHome = true;
    shell = pkgs.bashInteractive;
    hashedPasswordFile = config.sops.secrets."teslausb-password-hash".path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE+TwpXxuVhyx4IYrgo4bdSM2ZhOhMwk0Izsyj3d4M3s teslausb-redbean-archive"
    ];
  };

  systemd.services.teslausb-archive-directory = {
    description = "Create the TeslaUSB Redbean archive directory";
    wantedBy = ["multi-user.target"];
    requiredBy = ["samba-smbd.service" "nfs-server.service"];
    before = ["samba-smbd.service" "nfs-server.service"];
    unitConfig.RequiresMountsFor = ["/earth"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.coreutils}/bin/install -d -m 2775 -o teslausb -g media '${archiveDir}'
    '';
  };

  services.samba.settings."tesla-redbean" = {
    path = archiveDir;
    browseable = "yes";
    "read only" = "no";
    "guest ok" = "no";
    "valid users" = "teslausb";
    "force user" = "teslausb";
    "force group" = "media";
    "create mask" = "0664";
    "force create mode" = "0660";
    "directory mask" = "2775";
    "force directory mode" = "2770";
  };

  systemd.services.teslausb-samba-password = {
    description = "Set the TeslaUSB Samba password";
    requiredBy = ["samba-smbd.service"];
    before = ["samba-smbd.service"];
    restartTriggers = [./secrets/teslausb.yaml];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      password="$(${pkgs.coreutils}/bin/cat '${config.sops.secrets."teslausb-password".path}')"
      ${pkgs.coreutils}/bin/printf '%s\n%s\n' "$password" "$password" \
        | ${pkgs.samba}/bin/smbpasswd -s -a teslausb
    '';
  };

  services.nfs.server = {
    enable = true;
    exports = ''
      ${archiveDir} 192.168.1.0/24(rw,sync,no_subtree_check,all_squash,anonuid=${toString teslaUsbUid},anongid=${toString teslaUsbGid})
    '';
  };
  services.nfs.settings.nfsd.vers3 = "n";

  networking.firewall.allowedTCPPorts = [2049];
}
