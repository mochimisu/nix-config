# Read-only Gaia automount. SteamOS system units require an explicit root install.
{pkgs, ...}: let
  mount = pkgs.writeText "home-deck-Videos-Gaia.mount" ''
    [Unit]
    Description=Cove read-only Gaia Transmission media
    [Mount]
    What=//gaia/cove-transmission
    Where=/home/deck/Videos/Gaia
    Type=cifs
    Options=ro,credentials=/home/deck/.config/cove/gaia.smb,vers=3.1.1,seal,nosuid,nodev,noexec,uid=1000,gid=1000,file_mode=0440,dir_mode=0550
    TimeoutSec=10
  '';
  automount = pkgs.writeText "home-deck-Videos-Gaia.automount" ''
    [Unit]
    Description=On-demand Gaia Transmission media
    [Automount]
    Where=/home/deck/Videos/Gaia
    TimeoutIdleSec=120
    [Install]
    WantedBy=multi-user.target
  '';
  preserve = pkgs.writeText "cove-media-atomic-update.conf" ''
    /etc/atomic-update.conf.d/cove-media.conf
    /etc/systemd/system/home-deck-Videos-Gaia.mount
    /etc/systemd/system/home-deck-Videos-Gaia.automount
    /etc/systemd/system/multi-user.target.wants/home-deck-Videos-Gaia.automount
  '';
  installHost = pkgs.writeShellScriptBin "cove-install-host-integration" ''
    set -eu
    [ "$(/usr/bin/id -u)" = 0 ]
    [ "$(/usr/bin/cat /sys/class/dmi/id/product_name)" = Fremont ]
    [ "$(/usr/bin/cat /proc/sys/kernel/hostname)" = cove ]
    /usr/bin/install -Dm644 ${mount} /etc/systemd/system/home-deck-Videos-Gaia.mount
    /usr/bin/install -Dm644 ${automount} /etc/systemd/system/home-deck-Videos-Gaia.automount
    /usr/bin/install -Dm644 ${preserve} /etc/atomic-update.conf.d/cove-media.conf
    /usr/bin/systemctl daemon-reload
    /usr/bin/systemctl enable --now home-deck-Videos-Gaia.automount
    /usr/bin/systemd-analyze verify /etc/systemd/system/home-deck-Videos-Gaia.mount /etc/systemd/system/home-deck-Videos-Gaia.automount
  '';
in {
  home.packages = [installHost];
}
