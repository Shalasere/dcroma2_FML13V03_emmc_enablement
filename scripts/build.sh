#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${BUILD_OPENSBI:-0}" == "1" ]]; then
  "$ROOT/scripts/build_opensbi.sh"
fi

"$ROOT/scripts/build_uboot.sh"
"$ROOT/scripts/build_linux.sh"

echo "Builds complete"
