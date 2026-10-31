{pkgs, ...}: let
  passwordFile = "/var/lib/nut-private/monitor-password";
in {
  # Local USB UPS only; no network clients or firewall opening.
  power.ups = {
    enable = true;
    mode = "standalone";
    ups.gaia = {
      driver = "usbhid-ups";
      port = "auto";
      description = "Gaia USB UPS";
      directives = [
        "vendorid = 075d"
        "productid = 0300"
        # Request return-on-mains, never fall back to permanently staying off.
        "sdcommands = shutdown.return"
      ];
    };
    upsd.listen = [{address = "127.0.0.1";}];
    users.monitor = {
      inherit passwordFile;
      upsmon = "primary";
    };
    upsmon.monitor.gaia = {
      system = "gaia@127.0.0.1";
      user = "monitor";
      type = "primary";
      powerValue = 1;
    };
    # Keep native OB + LB shutdown policy. Do not trust unverified runtime or
    # voltage readings from this USB family to synthesize a low-battery state.
  };

  # Generate the local protocol credential on the host, never in the Nix store.
  systemd.services.nut-local-password = {
    description = "Create local UPS monitor credential";
    before = ["upsd.service" "upsmon.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "nut-private";
      StateDirectoryMode = "0700";
      UMask = "0077";
    };
    script = ''
      if [ ! -s ${passwordFile} ]; then
        ${pkgs.openssl}/bin/openssl rand -hex 32 > ${passwordFile}.tmp
        ${pkgs.coreutils}/bin/mv ${passwordFile}.tmp ${passwordFile}
      fi
    '';
  };
  systemd.services.upsd.requires = ["nut-local-password.service"];
  systemd.services.upsmon.requires = ["nut-local-password.service"];
}
