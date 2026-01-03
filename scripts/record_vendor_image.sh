#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: record_vendor_image.sh --distro <debian|ubuntu> --image <path> [--label <label>] [--out <dir>]

Records metadata about a vendor image without copying the image.
USAGE
}

require_arg() {
  local name="$1"
  local value="$2"
  if [[ -z "$value" ]]; then
    echo "Missing required arg: $name" >&2
    usage
    exit 1
  fi
}

DISTRO=""
IMAGE=""
LABEL=""
OUT_ROOT="vendor"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --distro)
      DISTRO="$2"
      shift 2
      ;;
    --image)
      IMAGE="$2"
      shift 2
      ;;
    --label)
      LABEL="$2"
      shift 2
      ;;
    --out)
      OUT_ROOT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

require_arg "--distro" "$DISTRO"
require_arg "--image" "$IMAGE"

if [[ ! -f "$IMAGE" ]]; then
  echo "Image not found: $IMAGE" >&2
  exit 1
fi

TS="$(date +%F_%H%M%S)"
if [[ -n "$LABEL" ]]; then
  OUT_DIR="$OUT_ROOT/$DISTRO/${TS}_${LABEL}"
else
  OUT_DIR="$OUT_ROOT/$DISTRO/$TS"
fi

mkdir -p "$OUT_DIR"

MANIFEST="$OUT_DIR/manifest.txt"
{
  echo "timestamp=$(date -u +%F_%H%M%SZ)"
  echo "distro=$DISTRO"
  echo "image_path=$IMAGE"
  echo "image_size_bytes=$(stat -c %s "$IMAGE" 2>/dev/null || wc -c < "$IMAGE")"
  if command -v sha256sum >/dev/null 2>&1; then
    echo "sha256=$(sha256sum "$IMAGE" | awk '{print $1}')"
  fi
} > "$MANIFEST"

echo "Vendor image recorded: $MANIFEST"
