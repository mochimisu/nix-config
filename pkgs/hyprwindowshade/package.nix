{lib, fetchFromGitHub, hyprlandPlugins, libglvnd}:
hyprlandPlugins.mkHyprlandPlugin {
  pluginName = "HyprWindowShade";
  version = "0-unstable-c84e9ba";
  # Upstream hyprpm.toml explicitly pairs this revision with Hyprland 0.57.1.
  src = fetchFromGitHub {
    owner = "ManofJELLO";
    repo = "HyprWindowShade";
    rev = "c84e9bae0503773e647eee50ef3e2ea484660fd4";
    sha256 = "11sgaiqfckxxcpq4lp2j6pi44rcdvyhdrabi02vgchff07vncwbb";
  };
  patches = [./window-coordinates.patch];
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
