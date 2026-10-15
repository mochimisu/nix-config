# Distinct visual systems: charcoal app content and illustrated shell surfaces.
{lib}: let
  app = lib.importJSON ./app-palette.json;
  shell = lib.importJSON ./sekai-palette.json;
in {
  inherit app;
  shell = shell // {railForeground = app.text; railMuted = app.muted;};
}
