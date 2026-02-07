# overlays/wvkbd-add-super.nix
self: super: {
  wvkbd = super.wvkbd.overrideAttrs (old: {
    patches = (old.patches or []) ++ [
      ./wvkbd-nodrag.patch
    ];
    postPatch =
      (old.postPatch or "")
      + ''
        cp ${./wvkbd-layout.mobintl.h} layout.mobintl.h
        cp ${./wvkbd-config.mobintl.h} config.mobintl.h
      '';
  });
}
