#!/usr/bin/env bash
# Build a separate package; never rebuild or replace the Node prebuild.
set -euo pipefail
PORT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$PORT_DIR/tools/electron_oh.py" "$@"
