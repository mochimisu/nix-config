{pkgs, ...}: {
  hardware.uni-sync = {
    enable = true;

    devices = [
      {
        device_id = "VID:3314/PID:41218/SN:6243168001";
        sync_rgb = true;
        channels = [
          {
            mode = "PWM";
            speed = 100;
          }
          {
            mode = "PWM";
            speed = 100;
          }
          {
            mode = "PWM";
            speed = 100;
          }
          {
            mode = "PWM";
            speed = 100;
          }
        ];
      }
    ];
  };

  systemd.services.uni-sync = {
    enable = true;
    serviceConfig = {
      User = "root";
      Group = "root";
      ExecStart = "${pkgs.uni-sync}/bin/uni-sync";
    };
  };

  # Add a timer that triggers the service every minute
  systemd.timers.uni-sync = {
    enable = true;
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "15sec";
      OnUnitActiveSec = "1min";
      Unit = "uni-sync.service";
    };
  };
}
