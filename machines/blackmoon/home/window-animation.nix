{config, lib, pkgs, ...}: let
  shader = "${config.xdg.configHome}/hypr/shaders/holographic-open.glsl";
  palette = lib.importJSON ../../../home/theme/sekai-palette.json;
  glslColor = color: let
    hex = lib.removePrefix "#" color;
  in "(vec3(0x${builtins.substring 0 2 hex}, 0x${builtins.substring 2 2 hex}, 0x${builtins.substring 4 2 hex}) / 255.0)";
  mkShader = closing: pkgs.replaceVars ./materialize-open.glsl {
    duration = if closing then "0.24" else "0.40";
    closing = if closing then "true" else "false";
    sekaiInk = glslColor palette.ink;
    sekaiTeal = glslColor palette.teal;
    sekaiMint = glslColor palette.mint;
    sekaiLavender = glslColor palette.lavenderEdge;
    sekaiPink = glslColor palette.pink;
    sekaiSurface = glslColor palette.surface;
  };
in {
  imports = [./workspace-card];
  xdg.configFile."hypr/shaders/holographic-open.glsl".source = mkShader false;
  xdg.configFile."hypr/shaders/holographic-close.glsl".source = mkShader true;
  wayland.windowManager.hyprland = {
    plugins = [(pkgs.callPackage ../../../pkgs/hyprwindowshade/package.nix {})];
    settings = {
      # Native border coloring only: no focus shader over the window surface.
      config.general.col.active_border = lib.mkOverride 40 {
        colors = map (color: "rgba(${lib.removePrefix "#" color}ff)") [palette.teal palette.lavenderEdge];
        angle = 45;
      };
      # This host's trial supersedes the shared shell's mkForce defaults.
      curve = lib.mkOverride 40 [
        {_args = ["sekaiEase" {type = "bezier"; points = [[0.22 1.0] [0.36 1.0]];}];}
        {_args = ["holoPop" {type = "bezier"; points = [[0.16 1.0] [0.30 1.12]];}];}
        {_args = ["borderSoft" {type = "bezier"; points = [[0.2 0.9] [0.3 1.0]];}];}
      ];
      animation = lib.mkOverride 40 [
        {leaf = "windows"; enabled = true; speed = 2.2; bezier = "holoPop"; style = "popin 82%";}
        {leaf = "windowsIn"; enabled = false; speed = 2.2; bezier = "holoPop"; style = "popin 82%";}
        {leaf = "windowsMove"; enabled = true; speed = 2.8; bezier = "sekaiEase";}
        {leaf = "windowsOut"; enabled = true; speed = 2.4; bezier = "linear"; style = "popin 100%";}
        {leaf = "border"; enabled = true; speed = 2.8; bezier = "borderSoft";}
        {leaf = "borderangle"; enabled = false; speed = 1; bezier = "default";}
        {leaf = "fade"; enabled = true; speed = 2; bezier = "default";}
        {leaf = "fadeIn"; enabled = false; speed = 1; bezier = "default";}
        {leaf = "fadeOut"; enabled = true; speed = 2.4; bezier = "linear";}
        {leaf = "workspaces"; enabled = true; speed = 4; bezier = "sekaiEase"; style = "slidefade 30%";}
      ];
      window_rule = [{
        name = "blackmoon-holographic-open";
        match.class = ".*";
        tag = "+shader_open:${shader}";
      } {
        name = "blackmoon-holographic-close";
        match.class = ".*";
        tag = "+shader_close:${config.xdg.configHome}/hypr/shaders/holographic-close.glsl";
      }];
    };
  };
}
