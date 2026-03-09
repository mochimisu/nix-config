#!/usr/bin/env bash
set -euo pipefail

retry_delay="${MATTER_PAIR_RETRY_DELAY:-10}"
max_attempts="${MATTER_PAIR_MAX_ATTEMPTS:-0}"

usage() {
  cat <<'EOF'
Usage: matter-pair-retry [commissioner args...]

Retries Matter commissioning until success unless MATTER_PAIR_MAX_ATTEMPTS is set > 0.

Examples:
  sudo matter-pair-retry --name "MBR Bathroom Fan" --yes
  sudo matter-pair-retry --select '9,12-14' --yes
  sudo matter-pair-retry --all --yes

Env:
  MATTER_PAIR_RETRY_DELAY   Seconds between failed attempts. Default: 10
  MATTER_PAIR_MAX_ATTEMPTS  0 means retry forever. Default: 0
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

attempt=1
while true; do
  echo "matter-pair-retry: attempt $attempt"
  if matter-pair-interactive "$@"; then
    echo "matter-pair-retry: success on attempt $attempt"
    exit 0
  fi

  if [[ "$max_attempts" -gt 0 && "$attempt" -ge "$max_attempts" ]]; then
    echo "matter-pair-retry: reached max attempts ($max_attempts)" >&2
    exit 1
  fi

  echo "matter-pair-retry: sleeping ${retry_delay}s before retry"
  sleep "$retry_delay"
  attempt=$((attempt + 1))
done
