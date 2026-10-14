# Import only for hosts that use the patched touchscreen packages.
{inputs, ...}: {
  nixpkgs.overlays = [
    (import ./wvkbd.nix)
    inputs.hyprgrass.overlays.default
    (_: prev: {
      hyprlandPlugins = prev.hyprlandPlugins // {
        hyprgrass = prev.hyprlandPlugins.hyprgrass.overrideAttrs (old: {
          patches = (old.patches or []) ++ [./hyprgrass-tap-count.patch];
        });
      };
    })
  ];
}
