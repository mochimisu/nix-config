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
    wantedBy = ["multi-user.target"];
    enable = true;
    serviceConfig = {
      User = "root";
      Group = "root";
      ExecStart = "${pkgs.uni-sync}/bin/uni-sync";
      ExecStartPre = "/bin/sleep 5";
    };
  };
}
