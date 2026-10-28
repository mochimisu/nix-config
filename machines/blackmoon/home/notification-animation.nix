{config, lib, pkgs, ...}: let
  package = pkgs.callPackage ../../../pkgs/mako-kirakira {};
in {
  # Host-local renderer only. Mako retains delivery and notification semantics.
  config = lib.mkIf config.services.mako.enable {
    services.mako.package = package;
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
