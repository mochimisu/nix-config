#!/usr/bin/env bash
set -euo pipefail

# Serialize rapid key presses without holding the lock for the UI lifetime.
exec 9>"${XDG_RUNTIME_DIR:?}/sekai-launcher-toggle.lock"
@flock@ -w 3 9
if @qs@ ipc -p @config@ call launcher close >/dev/null 2>&1; then
    exit 0
fi
@qs@ -n -d -p @config@ 9>&-
