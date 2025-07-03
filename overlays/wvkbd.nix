# overlays/wvkbd-add-super.nix
self: super: {
  wvkbd = super.wvkbd.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        #— make sure the file exists —#
        test -f layout.mobintl.h || { echo "layout.mobintl.h not found"; ls -1; exit 1; }

        echo ">>> inserting Super after every Cmp key"
        sed -i '
          /{"Cmp",[[:space:]]*"Cmp",[[:space:]]*1\.0,[[:space:]]*Compose/ a\
              {"Sup", "Sup", 1.0, Mod, Super, .scheme = 1},
        ' layout.mobintl.h

        echo "---- verification ----"
        grep -n -A1 -B0 "Cmp\", \"Cmp" layout.mobintl.h
      '';
  });
}
