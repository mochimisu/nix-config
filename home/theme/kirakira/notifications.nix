{config, lib, pkgs, ...}: let
  package = config.services.mako.package;
in {
  # Shared renderer opt-in. Mako retains delivery and notification semantics.
  config = lib.mkIf config.variables.desktopStyle.kirakira.notifications.enable {
    services.mako.package = lib.mkDefault (pkgs.callPackage ../../../pkgs/mako-kirakira {});
    # Keep the legacy filename so an existing Blackmoon deployment is replaced.
    # Always follow the resolved package, including ordinary user overrides.
    # Explicit Home Manager ownership also permits a scoped live deployment
    # without switching unrelated pending home configuration.
    xdg.configFile."systemd/user/mako.service.d/90-blackmoon-kirakira.conf".text = ''
      [Service]
      ExecStart=
      ExecStart=${package}/bin/mako
      ExecReload=
      ExecReload=${package}/bin/makoctl reload
    '';
  };
}
