# overlays/wvkbd-add-super.nix
_: super: {
  wvkbd = super.wvkbd.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ [
        ./wvkbd-nodrag.patch
        ./wvkbd-persist-mobintl-layout.patch
      ];
    postPatch =
      (old.postPatch or "")
      + ''
        cp ${./wvkbd-layout.mobintl.h} layout.mobintl.h
        cp ${./wvkbd-config.mobintl.h} config.mobintl.h
        substituteInPlace keymap.mobintl.h \
          --replace-fail 'key <AB08>               {	[           comma,      apostrophe, less, U00AB] };' 'key <AB08>               {	[           comma,            less, less, U00AB] };' \
          --replace-fail 'key <AB09>               {	[          period,        question, greater, U00BB] };' 'key <AB09>               {	[          period,         greater, greater, U00BB] };' \
          --replace-fail 'key <AB10>               {	[           slash,        greater ] };' 'key <AB10>               {	[           slash,       question ] };'
      '';
  });
}
