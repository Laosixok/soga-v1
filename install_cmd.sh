#!/usr/bin/env bash
# Compatibility entry: installs the local manager and owned release core together.
set -Eeuo pipefail
exec bash "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/install.sh" "$@"
