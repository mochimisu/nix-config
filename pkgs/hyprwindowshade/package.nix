{lib, fetchFromGitHub, hyprlandPlugins, libglvnd}:
hyprlandPlugins.mkHyprlandPlugin {
  pluginName = "HyprWindowShade";
  version = "0-unstable-a4c6b8a";
  # Upstream hyprpm.toml explicitly pairs this revision with Hyprland 0.56.2.
  src = fetchFromGitHub {
    owner = "ManofJELLO";
    repo = "HyprWindowShade";
    rev = "a4c6b8af424a189072427c4c90ef2938e1b481d3";
    sha256 = "1p0c79bh7gfs9xlnv5smx8xmrgq0d5gipprwkickzsn7b40kfnw4";
  };
  patches = [./window-coordinates.patch ./blur-pass-coordinates.patch];
  buildInputs = [libglvnd];
  dontUseCmakeConfigure = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 HyprWindowShade.so $out/lib/libHyprWindowShade.so
    runHook postInstall
  '';
  meta = {
    description = "Per-window shaders and opening effects for Hyprland";
    homepage = "https://github.com/ManofJELLO/HyprWindowShade";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
