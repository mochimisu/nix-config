{
  config,
  lib,
  pkgs,
  specialArgs,
  variables,
  inputs,
  ...
}: {
  networking.hostName = "oasis";
  variables.touchscreen.sddmKeyboard = true;
  networking.networkmanager.wifi.powersave = false;
  environment.systemPackages = with pkgs; [
    brightnessctl
    bolt
    bash
    acpid
    asusctl
    ydotool

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
    SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_TOUCHSCREEN}=="1", SYMLINK+="input/touchscreen"
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
      wayland.enable = lib.mkForce false; # force X11
    };
    xserver.enable = lib.mkForce true; # force X11
  };

  users.users.brandon.extraGroups = lib.mkAfter ["input"];

  systemd.services.asus-fan-curve = {
    description = "Apply custom Asus fan curve";
    wantedBy = ["multi-user.target"];
    after = ["asusd.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "asus-fan-curve" ''
        set -eu
        ${pkgs.asusctl}/bin/asusctl profile set Balanced -a -b
        ${pkgs.asusctl}/bin/asusctl profile set Balanced
        ${pkgs.asusctl}/bin/asusctl fan-curve --mod-profile balanced --enable-fan-curves true
        ${pkgs.asusctl}/bin/asusctl fan-curve --mod-profile balanced --enable-fan-curve true --fan cpu
        ${pkgs.asusctl}/bin/asusctl fan-curve --mod-profile balanced --enable-fan-curve true --fan gpu
        ${pkgs.asusctl}/bin/asusctl fan-curve --mod-profile balanced --fan cpu --data "25:2,30:4,40:8,55:18,70:60,80:85,90:100,95:100"
        ${pkgs.asusctl}/bin/asusctl fan-curve --mod-profile balanced --fan gpu --data "25:2,30:4,45:10,60:22,75:70,85:90,90:100,95:100"
      '';
    };
  };

  systemd.services.ydotoold = {
    description = "ydotool daemon";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${pkgs.ydotool}/bin/ydotoold --socket-path=/run/ydotoold.socket --socket-perm=0666";
      Restart = "on-failure";
    };
  };




  # orientation sensor
  hardware.sensor.iio.enable = true;

  system.stateVersion = "24.11";
}
