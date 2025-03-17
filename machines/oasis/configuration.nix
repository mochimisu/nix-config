{ config, lib, pkgs, specialArgs, variables, inputs, ... }:

{
  networking.hostName = "oasis";
  environment.systemPackages = with pkgs; [
    brightnessctl
    bolt
    bash
    acpid

    # notes
    xournalpp
  ];

  # wifi usb
  boot.extraModulePackages = with config.boot.kernelPackages; [
    rtl8852bu
  ];

  # gnupg
  programs.gnupg.agent = {
    enable = true;
  };

  # fix speakers
  boot.kernelPatches = [
    {
      name = "rog-ally-audio";
      patch = ./rog-ally-x-audio-fix.patch;
    }
  ];

  # fix kernel hang on suspend
  boot.kernelParams = [ "amdgpu.gpu_recovery=1" ];

  # fix trackpad
  environment.etc."scripts/touchpad-fix.sh".text = ''
    #!/run/current-system/sw/bin/bash
    # Find the device ID based on dmesg output (adjust grep if needed)
    touchpadID=$(dmesg | grep "asus 0003:0B05:1A30.* USB HID v1.10 Mouse" \
      | grep -o "0003:0B05:1A30\.[0-9A-F]*" | tail -1)
    echo -n "$touchpadID" > /sys/bus/hid/drivers/asus/unbind
    echo -n "$touchpadID" > /sys/bus/hid/drivers/hid-multitouch/bind
  '';
  environment.etc."scripts/touchpad-fix.sh".mode = "0755";  # make it executable

  # Add a custom udev rule to trigger the script when the device is added
  services.udev.extraRules = ''
    ACTION=="add", KERNEL=="0003:0B05:1A30.*", SUBSYSTEM=="hid", \
      RUN+="$(pkgs.bash) -c 'sh /etc/scripts/touchpad-fix.sh'"
  '';

  # palm rejection
  services.xserver.libinput = {
    enable = true;
    touchpad = {
      additionalOptions = ''
        Option "PalmDetection" "on"
        Option "PalmSizeThreshold" "10"
        Option "PalmEdgeWidth" "5"
        '';
    };
  };

  # Ignore wifi button
  networking.networkmanager = {
    settings = {
      main = {
        "ignore-carrier" = "*";
      };
    };
  };

  systemd.services.fprintd = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "simple";
  };

  services.xserver.xkb = {
    layout = "custom";
    variant = "dvorak-custom";
  };

  services = {
    asusd = {
      enable = true;
      enableUserService = true;
    };
    pipewire = {
      audio.enable = true;
      pulse.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = true;
    };
  };

  # orientation sensor
  hardware.sensor.iio.enable = true;

  system.stateVersion = "24.11";
}
