# overlays/waybar-cava.nix
(final: prev: {
  waybar = prev.waybar.override {
    # Waybar ≥ 0.11 turned every plugin into an optional Meson feature.
    # “cava”, “hyprland”, “tray”, “pulseaudio”, … are all ON by default in
    # nixpkgs right now, **but** the binary is still linked to the older
    # `libcava-0.10.1` on the 24.05 channel.  Re-enable the module and bump
    # libcava in one go:
    mesonFlags = prev.waybar.mesonFlags ++ [
      "-Dcava=enabled"
    ];
    buildInputs = (prev.waybar.buildInputs or []) ++ [ prev.libcava_0_10_3 ];
  };
})

