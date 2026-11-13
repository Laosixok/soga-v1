#!/usr/bin/env bash
set -Eeuo pipefail
VERSION=${1:-2.18.0}; VERSION=${VERSION#v}
[[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]] || exit 1
WORK=$(mktemp -d); trap 'rm -rf -- "$WORK"' EXIT
BASE="https://github.com/Laosixok/soga-v1/releases/download/v$VERSION"
curl --fail --location --retry 3 "$BASE/install.sh" -o "$WORK/install.sh"
curl --fail --location --retry 3 "$BASE/install.sh.sha256" -o "$WORK/install.sh.sha256"
(cd "$WORK" && sha256sum -c install.sh.sha256)
bash "$WORK/install.sh" "$VERSION"
