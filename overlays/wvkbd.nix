# overlays/wvkbd-add-super.nix
self: super: {
  wvkbd = super.wvkbd.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        cp ${./wvkbd-layout.mobintl.h} layout.mobintl.h
      '';
  });
}
