{
  config,
  pkgs,
  lib,
  ...
}: let
  gscan2pdfWithSane = pkgs.symlinkJoin {
    name = "gscan2pdf-with-sane";
    paths = [pkgs.gscan2pdf];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/gscan2pdf \
        --set SANE_CONFIG_DIR /etc/sane-config \
        --prefix LD_LIBRARY_PATH : /etc/sane-libs
    '';
  };

  brscan5-ds640 = final: prev: prev.brscan5.overrideAttrs (old: rec {
    version = "1.6.2-0";
    src = final.fetchurl {
      url = "https://download.brother.com/welcome/dlf104036/brscan5-${version}.x86_64.rpm";
      hash = "sha256-oUuZHa/QJ5zJLJgRVJAReIJRdLisISOGgDezYUuPkF4=";
    };
    unpackPhase = ''
      rpmextract $src
    '';
    nativeBuildInputs = old.nativeBuildInputs ++ [final.rpmextract];
    postPatch =
      old.postPatch
      + ''
        printf '/etc/opt/brother/scanner/models\x00' | dd of=opt/brother/scanner/brscan5/libsane-brother5.so.1.0.7 bs=1 seek=86720 conv=notrunc
      '';
    installPhase = ''
      runHook preInstall

      PATH_TO_BRSCAN5="opt/brother/scanner/brscan5"
      mkdir -p $out/$PATH_TO_BRSCAN5
      cp -rp $PATH_TO_BRSCAN5/* $out/$PATH_TO_BRSCAN5

      pushd $out/$PATH_TO_BRSCAN5
        ln -s libLxBsDeviceAccs.so.1.0.0 libLxBsDeviceAccs.so.1
        ln -s libLxBsNetDevAccs.so.1.0.0 libLxBsNetDevAccs.so.1
        ln -s "$(basename libLxBsScanCoreApi.so.3.*)" libLxBsScanCoreApi.so.3
        ln -s libLxBsUsbDevAccs.so.1.0.0 libLxBsUsbDevAccs.so.1
        ln -s libsane-brother5.so.1.0.7 libsane-brother5.so.1
      popd

      mkdir -p $out/lib/sane
      for file in $out/$PATH_TO_BRSCAN5/*.so.* ; do
        ln -s $file $out/lib/sane/
      done

      makeWrapper \
        "$out/$PATH_TO_BRSCAN5/brsaneconfig5" \
        "$out/bin/brsaneconfig5" \
        --suffix-each NIX_REDIRECT ":" "/etc/opt/brother/scanner/brscan5=$out/opt/brother/scanner/brscan5 /opt/brother/scanner/brscan5=$out/opt/brother/scanner/brscan5" \
        --set LD_PRELOAD ${final.libredirect}/lib/libredirect.so

      mkdir -p $out/etc/sane.d/dll.d
      echo "brother5" > $out/etc/sane.d/dll.d/brother5.conf

      mkdir -p $out/etc/udev/rules.d
      install -m 0444 $PATH_TO_BRSCAN5/udev-rules/NN-brother-mfp-brscan5-1.0.2-2.rules \
        $out/etc/udev/rules.d/49-brother-mfp-brscan5-1.0.2-2.rules

      ETCDIR=$out/etc/opt/brother/scanner/brscan5
      mkdir -p $ETCDIR
      cp -rp $PATH_TO_BRSCAN5/{models,brscan5.ini,brsanenetdevice.cfg} $ETCDIR/

      runHook postInstall
    '';
  });
in {
  imports = [
    ../../nvidia.nix
    ./uni-sync.nix
  ];

  networking.hostName = "blackmoon";
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
      gscan2pdfWithSane
    ]);

  services.hardware.bolt.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "dvorak";
  };

  services.hardware.openrgb.enable = true;

  nixpkgs.overlays = [
    (final: prev: {
      brscan5 = brscan5-ds640 final prev;
    })
  ];

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

  hardware.sane = {
    enable = true;
    brscan5.enable = true;
  };

  users.users.brandon.extraGroups = lib.mkAfter ["scanner" "lp"];

  system.stateVersion = "24.11";
}
