{ config, lib, pkgs, specialArgs, variables, inputs, ... }:

{

  networking.hostName = "espresso";
  variables.touchscreen.sddmKeyboard = true;
  environment.systemPackages = with pkgs; [
    brightnessctl
    bolt
    ydotool
  ];
  services.hardware.bolt.enable = true;

  users.users.brandon.extraGroups = lib.mkAfter ["input"];

  services.udev.extraRules = ''
    SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_TOUCHSCREEN}=="1", SYMLINK+="input/touchscreen"
  '';

  systemd.services.ydotoold = {
    description = "ydotool daemon";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${pkgs.ydotool}/bin/ydotoold --socket-path=/run/ydotoold.socket --socket-perm=0666";
      Restart = "on-failure";
    };
  };

  system.stateVersion = "24.11";
}
