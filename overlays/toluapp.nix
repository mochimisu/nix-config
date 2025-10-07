# Work around legacy CMake minimums in upstream packages until nixpkgs updates them.
final: prev: let
  ensureCmake35 = pkg:
    pkg.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + "\n" + ''
        perl -0pi -e 's/cmake_minimum_required\s*\(\s*VERSION\s+[0-9.]+\s*\)\s*\n?//i' CMakeLists.txt
        perl -0pi -e 's/(project\s*\([^\n]+\))/cmake_minimum_required(VERSION 3.5)\n$1/i' CMakeLists.txt
      '';
      cmakeFlags = (old.cmakeFlags or []) ++ ["-DCMAKE_POLICY_VERSION_MINIMUM=3.5"];
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [prev.perl];
    });

  patched = attrs:
    builtins.listToAttrs (map (name: {
      inherit name;
      value = ensureCmake35 (builtins.getAttr name prev);
    }) (builtins.filter (name: builtins.hasAttr name prev) attrs));
in
  {
    toluapp = ensureCmake35 prev.toluapp;
  }
  // patched ["allegro" "allegro4" "allegro_4"]
