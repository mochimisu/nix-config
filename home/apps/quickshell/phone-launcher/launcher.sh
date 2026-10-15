#!/usr/bin/env bash
set -euo pipefail

# Serialize launch/readiness/toggle, never the lifetime of the persistent shell.
exec 9>"${XDG_RUNTIME_DIR:?}/sekai-launcher-toggle.lock"
@flock@ -w 5 9
if @qs@ ipc -p @config@ call launcher toggle >/dev/null 2>&1; then
    exit 0
fi
# -n prevents a second instance if the user service is starting concurrently.
@qs@ -n -d -p @config@ 9>&-
for ((attempt = 0; attempt < 60; attempt++)); do
    if @qs@ ipc -p @config@ call launcher toggle >/dev/null 2>&1; then
        exit 0
    fi
    @sleep@ 0.05
done
printf 'Phone launcher did not become ready\n' >&2
exit 1
