final: prev: {
  # Hyprland 0.51 bumped the plugin API; pin to a post-fix hyprgrass commit so it builds.
  hyprlandPlugins = prev.hyprlandPlugins // {
    hyprgrass = prev.hyprlandPlugins.hyprgrass.overrideAttrs (old: {
      version = "0.8.2-unstable-2025-09-02";
      src = prev.fetchFromGitHub {
        owner = "horriblename";
        repo = "hyprgrass";
        rev = "9b341353a91c23ced96e5ed996dda62fbe426a32";
        hash = "sha256-Nwd8JwGEEdGBJthxiopK51Fwva5TbM1PEOQDe+NAZEw=";
      };
    });
  };
}
