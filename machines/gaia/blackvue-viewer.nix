{pkgs, ...}: let
  appDir = "/home/brandon/stuff/blackvue-viewer";
in {
  systemd.services.blackvue-viewer = {
    description = "BlackVue archive web viewer";
    wantedBy = ["multi-user.target"];
    after = ["network.target" "earth.mount"];
    requires = ["earth.mount"];

    environment = {
      PORT = "3000";
      BLACKVUE_VIDEO_ROOT = "/earth/blackvue";
    };

    path = [pkgs.nodejs_22];

    serviceConfig = {
      Type = "simple";
      User = "brandon";
      Group = "users";
      WorkingDirectory = appDir;
      ExecStart = "${pkgs.nodejs_22}/bin/node server/index.js";
      Restart = "on-failure";
      RestartSec = "5s";
      ReadOnlyPaths = [appDir "/earth/blackvue"];
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };

  networking.firewall.allowedTCPPorts = [3000];
}
