# Prepared Cove-only user relay; import after physical Back timing validation.
{pkgs, ...}: let
  python = pkgs.python3.withPackages (ps: [ps.evdev]);
in {
  systemd.user.services.cove-cec-remote = {
    Unit = {
      Description = "Cove HDMI-CEC Back hold";
      After = ["cecd.service" "graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${python}/bin/python ${./cec-remote.py}";
      Restart = "on-failure";
      RestartSec = 2;
      NoNewPrivileges = true;
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
