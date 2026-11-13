#!/usr/bin/env bash
# Independent deployment scripts for Laosixok/soga-v1.
set -Eeuo pipefail
umask 077
REPO=Laosixok/soga-v1
VERSION=${1:-2.18.0}
VERSION=${VERSION#v}
[[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]] || { echo 'Invalid version' >&2; exit 1; }
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || { echo 'This release supports Linux x86_64 only.' >&2; exit 1; }
[[ $EUID == 0 ]] || { echo 'Run as root.' >&2; exit 1; }
for cmd in systemctl tar sha256sum install flock; do command -v "$cmd" >/dev/null || { echo "Missing command: $cmd" >&2; exit 1; }; done
exec 9>/run/lock/soga-v1-install.lock
flock -n 9 || { echo 'Another installation is running.' >&2; exit 1; }
WORK=$(mktemp -d)
trap 'rm -rf -- "$WORK"' EXIT
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -f "$SCRIPT_DIR/soga" && -f "$SCRIPT_DIR/soga.sh" && -f "$SCRIPT_DIR/SHA256SUMS" ]]; then
    PACKAGE=$SCRIPT_DIR
else
    command -v curl >/dev/null || { echo 'Install curl first.' >&2; exit 1; }
    ASSET=soga-linux-amd64.tar.gz
    BASE="https://github.com/$REPO/releases/download/v$VERSION"
    curl --fail --location --retry 3 --connect-timeout 15 "$BASE/$ASSET" -o "$WORK/$ASSET"
    curl --fail --location --retry 3 --connect-timeout 15 "$BASE/$ASSET.sha256" -o "$WORK/$ASSET.sha256"
    (cd "$WORK" && sha256sum -c "$ASSET.sha256")
    # Reject absolute paths, traversal, links and special entries before extraction.
    tar -tzf "$WORK/$ASSET" > "$WORK/entries"
    while IFS= read -r entry; do
        [[ $entry != /* && ! $entry =~ (^|/)\.\.(/|$) ]] || { echo 'Unsafe archive path' >&2; exit 1; }
    done < "$WORK/entries"
    if tar -tvzf "$WORK/$ASSET" | awk 'substr($1,1,1)!="-" && substr($1,1,1)!="d" {bad=1} END {exit !bad}'; then
        echo 'Archive contains links or special entries' >&2; exit 1
    fi
    mkdir "$WORK/package"
    tar -xzf "$WORK/$ASSET" --no-same-owner -C "$WORK/package"
    PACKAGE=$WORK/package
fi
(cd "$PACKAGE" && sha256sum -c SHA256SUMS)
[[ $(cat "$PACKAGE/VERSION") == "$VERSION" ]] || { echo 'Package/version mismatch' >&2; exit 1; }
chmod 755 "$PACKAGE/soga"
"$PACKAGE/soga" -v
BACKUP="/var/backups/soga-v1/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$BACKUP" /usr/local/soga /etc/soga
[[ ! -f /usr/local/soga/soga ]] || cp -a /usr/local/soga/soga "$BACKUP/soga"
[[ ! -f /usr/bin/soga ]] || cp -a /usr/bin/soga "$BACKUP/manager"
cp -a /etc/soga "$BACKUP/config"
for unit in soga.service soga@.service; do
    [[ ! -f /etc/systemd/system/$unit ]] || cp -a "/etc/systemd/system/$unit" "$BACKUP/$unit"
done
ACTIVE=()
while IFS= read -r unit; do [[ -z $unit ]] || ACTIVE+=("$unit"); done < <(
    systemctl list-units --type=service --state=active --no-legend --plain 'soga.service' 'soga@*.service' | awk '{print $1}'
)
# Stage core before stopping any running instances.
install -m 755 "$PACKAGE/soga" /usr/local/soga/soga.new
if ((${#ACTIVE[@]})); then systemctl stop "${ACTIVE[@]}"; fi
mv -f /usr/local/soga/soga.new /usr/local/soga/soga
install -m 755 "$PACKAGE/soga.sh" /usr/bin/soga
install -m 755 "$PACKAGE/install.sh" /usr/local/soga/install.sh
for unit in soga.service soga@.service; do install -m 644 "$PACKAGE/$unit" "/etc/systemd/system/$unit"; done
for name in soga.conf blockList whiteList dns.yml routes.toml; do
    [[ -e /etc/soga/$name ]] || install -m 600 "$PACKAGE/$name" "/etc/soga/$name"
done
install -m 644 "$PACKAGE/VERSION" /usr/local/soga/VERSION
systemctl daemon-reload
FAILED=0
if ((${#ACTIVE[@]})); then
    systemctl start "${ACTIVE[@]}" || FAILED=1
    for unit in "${ACTIVE[@]}"; do systemctl is-active --quiet "$unit" || FAILED=1; done
fi
if ((FAILED)); then
    echo "Some instances failed to start. Backup: $BACKUP" >&2
    echo 'Check: soga log node01. Rollback: soga rollback BACKUP_DIRECTORY' >&2
    exit 1
fi
printf 'Installed soga %s from %s. Backup: %s\n' "$VERSION" "$REPO" "$BACKUP"
echo 'Existing configurations and certificates are preserved. New installs are not started automatically.'
echo 'Create instance: soga new node01; edit: soga config node01; start: soga start node01'
