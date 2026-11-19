# Preserve Gaia's existing server-issued identity and approved grant.
{ config, lib, ... }: {
  services.dot-executor = {
    enable = true;
    hostName = "gaia";
    environmentId = "ccarenv_b64_Y2NhcmVudl82YWYxMTc3ODVhMDQ4MTkxOTNlYjMwMmQzZjFhYjZmYw";
  };

  # Stop the previous unit before taking over the same identity/state lock.
  systemd.user.services.dot-executor = lib.mkIf config.services.dot-executor.enable {
    Unit = {
      Conflicts = [ "gaia-dot-executor.service" ];
      After = [ "gaia-dot-executor.service" ];
    };
  };
}
