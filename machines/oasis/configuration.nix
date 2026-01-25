{
  config,
  lib,
  pkgs,
  specialArgs,
  variables,
  inputs,
  ...
}: {
  nixpkgs.overlays = [
    (import ../../overlays/wvkbd.nix)
  ];

  networking.hostName = "oasis";
  environment.systemPackages = with pkgs; [
    brightnessctl
    bolt
    bash
    acpid

    # adjust tdp
    ryzenadj
    powercap
    s-tui

    # notes
    styluslabs-write-bin

    # rotate screen
    jq
    iio-hyprland

    # on screen keyboard
    wvkbd
  ];

  # wifi usb
  # boot.extraModulePackages = with config.boot.kernelPackages; [
  #   rtl8852bu
  # ];

  # gnupg
  programs.gnupg.agent = {
    enable = true;
  };

  # fix kernel hang on suspend + prevent EC from waking on AC power changes
  boot.kernelParams = ["amdgpu.gpu_recovery=1" "acpi.ec_no_wakeup=1"];

  # fix trackpad
  environment.etc."scripts/touchpad-fix.sh".source = pkgs.writeScript "touchpad-fix" ''
    #!/run/current-system/sw/bin/bash
    # Find the device ID based on dmesg output (adjust grep if needed)
    touchpadID=$(dmesg | grep "asus 0003:0B05:1A30.* USB HID v1.10 Mouse" \
      | grep -o "0003:0B05:1A30\.[0-9A-F]*" | tail -1)
    echo -n "$touchpadID" > /sys/bus/hid/drivers/asus/unbind
    echo -n "$touchpadID" > /sys/bus/hid/drivers/hid-multitouch/bind
  '';
  # environment.etc."scripts/touchpad-fix.sh".mode = "0755";  # make it executable

  # Add a custom udev rule to trigger the script when the device is added
  services.udev.extraRules = ''
    ACTION=="add", KERNEL=="0003:0B05:1A30.*", SUBSYSTEM=="hid", \
    RUN+="${config.environment.etc."scripts/touchpad-fix.sh".source}"
  '';

  # palm rejection
  services.libinput = {
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
  # TODO figure out which device
  services.udev.extraHwdb = ''
    evdev:input:*
    KEYBOARD_KEY_5f=f13
  '';

  services.logind.settings = {
    Login = {
      HandlePowerKey = "suspend";
      HandlePowerKeyLongPress = "ignore";
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandleLidSwitchDocked = "suspend";
    };
  };

  # Prevent USB/USB4 power events (like AC unplug) from waking the system.
  systemd.services.disable-ac-wakeup = {
    description = "Disable AC-related wakeup sources before sleep";
    wantedBy = ["multi-user.target" "sleep.target"];
    before = ["sleep.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "disable-ac-wakeup" ''
        set -eu
        while read -r dev state status rest; do
          [ "$dev" = "Device" ] && continue
          [ "$status" = "*enabled" ] || continue
          case "$dev" in
            PBTN|LID|SLPB) continue ;;
          esac
          echo "$dev" > /proc/acpi/wakeup || true
        done < /proc/acpi/wakeup
      '';
    };
  };

  systemd.services.fprintd = {
    wantedBy = ["multi-user.target"];
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
    displayManager.sddm = {
      settings = {
        # TODO: fix this
        # "General" = {
        #   "InputMethod" = "qtvirtualkeyboard";
        # };
      };
      wayland.enable = lib.mkForce false; # force X11
      extraPackages = with pkgs; [
        qt6.qtvirtualkeyboard
      ];
    };
    xserver.enable = lib.mkForce true; # force X11
  };

  home-manager.extraSpecialArgs = {inherit inputs;};



  # orientation sensor
  hardware.sensor.iio.enable = true;

  system.stateVersion = "24.11";
}
