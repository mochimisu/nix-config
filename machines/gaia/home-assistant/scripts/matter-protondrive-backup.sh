#!/usr/bin/env bash
set -euo pipefail

SOURCE_PATH="${MATTER_BACKUP_SOURCE:-/earth/home-assistant/matter-server/.matter_server/chip.json}"
BACKUP_DIR="${MATTER_BACKUP_DIR:-/earth/backups/matter}"
OUTPUT_NAME="${MATTER_BACKUP_NAME:-chip.json.zst.age}"
RECIPIENTS_FILE="${MATTER_BACKUP_AGE_RECIPIENTS_FILE:-}"
IDENTITY_FILE="${MATTER_BACKUP_AGE_IDENTITY_FILE:-}"
SOPS_CONFIG="${MATTER_BACKUP_SOPS_CONFIG:-}"
ARCHIVE_OLD="${MATTER_BACKUP_ARCHIVE_OLD:-1}"

usage() {
  cat <<'EOF'
Encrypt a Matter state file locally and store it in a backup directory.

Usage:
  matter-protondrive-backup [options]

Options:
  --source PATH             Source file to back up
  --backup-dir PATH         Local backup directory (default: /earth/backups/matter)
  --output-name NAME        Output file name (default: chip.json.zst.age)
  --recipients-file PATH    age recipients file with one public recipient per line
  --identity-file PATH      age private key file; derives recipient with age-keygen -y
  --sops-config PATH        Extract age recipients from a .sops.yaml/.sops.yml file
  --archive-old             Move current backup into archive/ before overwrite
  --no-archive-old          Do not archive current remote file before overwrite
  -h, --help                Show this help

Examples:
  sudo matter-protondrive-backup \
    --identity-file /root/.config/sops/age/keys.txt

  sudo matter-protondrive-backup \
    --backup-dir /earth/backups/matter \
    --sops-config /home/brandon/stuff/nix-config/.sops.yaml \
    --archive-old
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE_PATH="$2"
      shift 2
      ;;
    --backup-dir)
      BACKUP_DIR="$2"
      shift 2
      ;;
    --output-name)
      OUTPUT_NAME="$2"
      shift 2
      ;;
    --recipients-file)
      RECIPIENTS_FILE="$2"
      shift 2
      ;;
    --identity-file)
      IDENTITY_FILE="$2"
      shift 2
      ;;
    --sops-config)
      SOPS_CONFIG="$2"
      shift 2
      ;;
    --archive-old)
      ARCHIVE_OLD=1
      shift
      ;;
    --no-archive-old)
      ARCHIVE_OLD=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$BACKUP_DIR" ]]; then
  echo "--backup-dir is required" >&2
  exit 1
fi

if [[ ! -r "$SOURCE_PATH" ]]; then
  echo "Source file not readable: $SOURCE_PATH" >&2
  exit 1
fi

if [[ -n "$RECIPIENTS_FILE" && ! -r "$RECIPIENTS_FILE" ]]; then
  echo "Recipients file not readable: $RECIPIENTS_FILE" >&2
  exit 1
fi

if [[ -n "$IDENTITY_FILE" && ! -r "$IDENTITY_FILE" ]]; then
  echo "Identity file not readable: $IDENTITY_FILE" >&2
  exit 1
fi

if [[ -n "$SOPS_CONFIG" && ! -r "$SOPS_CONFIG" ]]; then
  echo "SOPS config not readable: $SOPS_CONFIG" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

base_name="$(basename "$SOURCE_PATH")"
host_name="$(hostname -s 2>/dev/null || hostname)"
created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
archive_stamp="$(date -u +%Y%m%d-%H%M%S)"
source_sha256="$(sha256sum "$SOURCE_PATH" | awk '{print $1}')"
source_bytes="$(stat -c %s "$SOURCE_PATH")"
source_mtime_epoch="$(stat -c %Y "$SOURCE_PATH")"

compressed_path="$tmp_dir/${base_name}.zst"
encrypted_path="$tmp_dir/${OUTPUT_NAME}"
manifest_path="$tmp_dir/${OUTPUT_NAME}.manifest.json"
recipient_args=()

if [[ -n "$RECIPIENTS_FILE" ]]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    recipient_args+=("-r" "$line")
  done < "$RECIPIENTS_FILE"
fi

if [[ -n "$SOPS_CONFIG" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    recipient_args+=("-r" "$line")
  done < <(grep -Eo 'age1[0-9ac-hj-np-z]+' "$SOPS_CONFIG" | awk '!seen[$0]++')
fi

if [[ -n "$IDENTITY_FILE" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    recipient_args+=("-r" "$line")
  done < <(age-keygen -y "$IDENTITY_FILE")
fi

if [[ ${#recipient_args[@]} -eq 0 ]]; then
  echo "No age recipients configured. Use --recipients-file or --identity-file." >&2
  exit 1
fi

zstd -q -T0 -19 -f -c -- "$SOURCE_PATH" > "$compressed_path"
age "${recipient_args[@]}" -o "$encrypted_path" "$compressed_path"
encrypted_sha256="$(sha256sum "$encrypted_path" | awk '{print $1}')"
encrypted_bytes="$(stat -c %s "$encrypted_path")"

jq -n \
  --arg created_at "$created_at" \
  --arg host_name "$host_name" \
  --arg source_path "$SOURCE_PATH" \
  --arg source_name "$base_name" \
  --arg source_sha256 "$source_sha256" \
  --arg encrypted_sha256 "$encrypted_sha256" \
  --arg backup_dir "$BACKUP_DIR" \
  --arg output_name "$OUTPUT_NAME" \
  --argjson source_bytes "$source_bytes" \
  --argjson source_mtime_epoch "$source_mtime_epoch" \
  --argjson encrypted_bytes "$encrypted_bytes" \
  '{
    created_at: $created_at,
    host_name: $host_name,
    source: {
      path: $source_path,
      name: $source_name,
      sha256: $source_sha256,
      bytes: $source_bytes,
      mtime_epoch: $source_mtime_epoch
    },
    encrypted: {
      sha256: $encrypted_sha256,
      bytes: $encrypted_bytes
    },
    backup: {
      dir: $backup_dir,
      name: $output_name
    }
  }' > "$manifest_path"

backup_file="${BACKUP_DIR%/}/${OUTPUT_NAME}"
backup_manifest="${backup_file}.manifest.json"
backup_archive_dir="${BACKUP_DIR%/}/archive"

existing_manifest_sha=""
if [[ -r "$backup_manifest" ]]; then
  existing_manifest_sha="$(jq -r '.source.sha256 // empty' "$backup_manifest" 2>/dev/null || true)"
fi

if [[ -n "$existing_manifest_sha" && "$existing_manifest_sha" == "$source_sha256" ]]; then
  echo "matter-protondrive-backup: unchanged sha256=$source_sha256; skipping upload"
  exit 0
fi

mkdir -p "$BACKUP_DIR"

if [[ "$ARCHIVE_OLD" == "1" ]] && [[ -e "$backup_file" || -e "$backup_manifest" ]]; then
  archive_base="${archive_stamp}-${OUTPUT_NAME}"
  mkdir -p "$backup_archive_dir"
  if [[ -e "$backup_file" ]]; then
    mv "$backup_file" "${backup_archive_dir}/${archive_base}"
  fi
  if [[ -e "$backup_manifest" ]]; then
    mv "$backup_manifest" "${backup_archive_dir}/${archive_base}.manifest.json"
  fi
fi

install -m 600 "$encrypted_path" "$backup_file"
install -m 600 "$manifest_path" "$backup_manifest"

echo "matter-protondrive-backup: wrote $SOURCE_PATH -> $backup_file"
echo "matter-protondrive-backup: source_sha256=$source_sha256 encrypted_sha256=$encrypted_sha256"
