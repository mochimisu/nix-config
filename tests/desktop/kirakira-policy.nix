{flake}: let
  inherit (flake.inputs.nixpkgs) lib;
  hosts = ["blackmoon" "glasscastle" "espresso" "oasis"];
  home = os: os.config.home-manager.users.brandon;
  effectFlags = hm: let k = hm.variables.desktopStyle.kirakira; in [k.enable k.menus.enable k.volume.enable k.notifications.enable];
  hostResults = lib.genAttrs hosts (name: let
    hm = home flake.nixosConfigurations.${name};
  in assert lib.all (x: x) (effectFlags hm);
     assert hm.systemd.user.services ? sekai-volume-overlay;
     { package = hm.services.mako.package.outPath; flags = effectFlags hm; });
  off = home (flake.nixosConfigurations.glasscastle.extendModules { modules = [{
    home-manager.users.brandon.variables.desktopStyle.kirakira.enable = false;
  }]; });
  individual = home (flake.nixosConfigurations.glasscastle.extendModules { modules = [{
    home-manager.users.brandon.variables.desktopStyle.kirakira = {
      menus.enable = false; volume.enable = false; notifications.enable = false;
    };
  }]; });
  custom = home (flake.nixosConfigurations.glasscastle.extendModules { modules = [({pkgs, ...}: {
    home-manager.users.brandon.services.mako.package = pkgs.mako;
  })]; });
  ordinary = flake.nixosConfigurations.glasscastle.pkgs.mako.outPath;
  excluded = home flake.nixosConfigurations.gaia;
in assert effectFlags off == [false false false false];
   assert !(off.systemd.user.services ? sekai-volume-overlay);
   assert off.services.mako.package.outPath == ordinary;
   assert effectFlags individual == [true false false false];
   assert !(individual.systemd.user.services ? sekai-volume-overlay);
   assert custom.services.mako.package.outPath == ordinary;
   assert builtins.elem "ExecStart=${ordinary}/bin/mako"
     (lib.splitString "\n" custom.xdg.configFile."systemd/user/mako.service.d/90-blackmoon-kirakira.conf".text);
   assert !(off.xdg.configFile ? "systemd/user/mako.service.d/90-blackmoon-kirakira.conf");
   assert effectFlags flake.homeConfigurations."deck@cove".config == [false false false false];
   assert effectFlags excluded == [false false false false];
{ inherit hostResults; normalOverrides = true; nonGuiUnchanged = true; }
