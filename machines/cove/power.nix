# Desktop sleep policy; Gaming Mode retains its own saved Steam settings.
{lib, ...}: {
  # Use the native settings writer so unrelated Plasma preferences remain editable.
  home.activation.coveKeepAwake = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD /usr/bin/kwriteconfig6 --file powerdevilrc \
      --group AC --group SuspendAndShutdown --key AutoSuspendAction 0
    if [ -z "''${DRY_RUN:-}" ]; then
      /usr/bin/qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement \
        org.kde.Solid.PowerManagement.reparseConfiguration >/dev/null 2>&1 || true
    fi
  '';
}
