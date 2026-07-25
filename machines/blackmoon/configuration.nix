{
  config,
  pkgs,
  lib,
  ...
}: let
  mkGaiaSshfsService = {
    remote,
    mountPoint,
  }: {
    description = "Mount ${remote} at ${mountPoint}";
    wants = ["network-online.target"];
    after = ["network-online.target"];
    wantedBy = ["default.target"];
    unitConfig.ConditionUser = "brandon";
    path = [
      pkgs.fuse3
      pkgs.openssh
      pkgs.sshfs
    ];
    serviceConfig = {
      Type = "exec";
      ExecStart = "${pkgs.sshfs}/bin/sshfs -f -o reconnect -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ConnectTimeout=10 -o ConnectionAttempts=3 ${remote} ${mountPoint}";
      ExecStop = "${pkgs.fuse3}/bin/fusermount3 -uz ${mountPoint}";
      Restart = "always";
      RestartSec = "10s";
      TimeoutStopSec = "15s";
    };
  };
in {
  imports = [
    ../../nvidia.nix
    ./scanner.nix
    ./uni-sync.nix
  ];

  networking.hostName = "blackmoon";
  # GeoClue has occasionally alternated between Los Angeles and New York while
  # this stationary desktop is under load, making every local-time display jump
  # by three hours. Keep location-based timezone changes for mobile hosts only.
  services.automatic-timezoned.enable = false;
  time.timeZone = "America/Los_Angeles";

  gaming.performance = {
    enable = true;
    desktopGovernor = true;
  };
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_xanmod;
  environment.systemPackages =
    (with pkgs; [
      bolt
      cage

      samba
      spacenavd
    ]);

  users.users.brandon.extraGroups = ["fuse"];
  systemd.user.services = {
    gaia-earth-sshfs = mkGaiaSshfsService {
      remote = "gaia:/earth";
      mountPoint = "/home/brandon/earth";
    };
    gaia-stuff-sshfs = mkGaiaSshfsService {
      remote = "gaia:/home/brandon/stuff";
      mountPoint = "/home/brandon/gaia-stuff";
    };
  };
  systemd.tmpfiles.rules = [
    "d /home/brandon/earth 0755 brandon users - -"
    "d /home/brandon/gaia-stuff 0755 brandon users - -"
  ];

  services.hardware.bolt.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "dvorak";
  };

  services.hardware.openrgb.enable = true;

  #v4l2loopback for screen sharing
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=10 card_label="VirtualCam" exclusive_caps=1
  '';
  boot.kernelModules = [
    # sensors for temps
    "nct6775"
    # loopback for screen sharing
    "v4l2loopback"
  ];
  boot.kernelParams = [
    "acpi_enforce_resources=lax"
    # disable GSP for frame stuttering
    "NVreg_EnableGpuFirmware=0"
  ];
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 1048576;
  };

  # services for fusion360
  # hardware.spacenavd.enable = true;
  # services.samba.enable = true;
  # consistent udev for highflownext
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="hwmon", ATTRS{idVendor}=="0c70", ATTRS{idProduct}=="f012", ATTRS{serial}=="03550-34834", RUN+="/bin/sh -c 'ln -s /sys$devpath /dev/highflow_next'"
  '';

  # fix sddm, eDP-3 (ultrawide) doesnt show with wayland.
  services.xserver.enable = lib.mkForce true;
  services.displayManager.sddm.wayland.enable = lib.mkForce false;
  # flatpak
  services.flatpak.enable = true;

  system.stateVersion = "24.11";
}
