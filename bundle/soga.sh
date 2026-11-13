#!/usr/bin/env bash
# Local instance manager; no dependency on upstream management binaries.
set -Eeuo pipefail
umask 077
REPO=Laosixok/soga-v1
usage() {
cat <<'TXT'
soga list                         List default and named instances
soga new NAME                     Create config without starting the instance
soga config [NAME]                Edit config (default: default instance)
soga start|stop|restart [NAME]     Control instance
soga enable|disable [NAME]         Configure boot startup
soga status [NAME]                 Show service status
soga log [NAME] [-f]               Show last 100 lines; optional follow
soga version                      Show core version
soga update [VERSION]             Install from Laosixok/soga-v1 only
soga rollback BACKUP_DIRECTORY    Restore core and manager from installer backup
TXT
}
valid_name() { [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]] || { echo 'Invalid instance name' >&2; exit 1; }; }
instance() {
    local name=${1:-default}
    valid_name "$name"
    if [[ $name == default ]]; then UNIT=soga.service; DIR=/etc/soga
    else UNIT="soga@$name.service"; DIR="/etc/soga/$name"; fi
}
COMMAND=${1:-help}
shift || true
if [[ $COMMAND == help || $COMMAND == -h || $COMMAND == --help ]]; then usage; exit 0; fi
[[ $EUID == 0 ]] || { echo 'Run as root.' >&2; exit 1; }
case "$COMMAND" in
    version|-v) /usr/local/soga/soga -v ;;
    list) systemctl list-units --all --type=service 'soga.service' 'soga@*.service' --no-pager
        echo 'Configured instances:'
        for path in /etc/soga/*/soga.conf; do [[ ! -f $path ]] || basename "$(dirname "$path")"; done ;;
    new)
        [[ $# == 1 && $1 != default ]] || { echo 'Usage: soga new NAME (not default)' >&2; exit 1; }
        valid_name "$1"; DIR="/etc/soga/$1"
        [[ ! -e $DIR ]] || { echo 'Instance already exists; configuration unchanged.' >&2; exit 1; }
        mkdir -m 700 "$DIR"
        for name in soga.conf blockList whiteList dns.yml routes.toml; do
            install -m 600 "/etc/soga/$name" "$DIR/$name"
        done
        echo "Created $DIR. Set node_id, protocol, API key and certificate domain before starting." ;;
    config) instance "${1:-default}"; [[ -f $DIR/soga.conf ]] || { echo 'Instance does not exist' >&2; exit 1; }
        EDIT_CMD=${EDITOR:-vi}
        command -v "$EDIT_CMD" >/dev/null || { echo 'Set EDITOR to an installed editor executable.' >&2; exit 1; }
        "$EDIT_CMD" "$DIR/soga.conf" ;;
    start|stop|restart|enable|disable|status)
        instance "${1:-default}"
        if [[ $COMMAND == start || $COMMAND == restart ]]; then
            [[ -f $DIR/soga.conf ]] || { echo 'Instance configuration missing' >&2; exit 1; }
        fi
        systemctl "$COMMAND" "$UNIT" ;;
    log) NAME=default; FOLLOW=()
        for arg in "$@"; do if [[ $arg == -f ]]; then FOLLOW=(-f); else NAME=$arg; fi; done
        instance "$NAME"; journalctl -u "$UNIT" -n 100 --no-pager "${FOLLOW[@]}" ;;
    update)
        [[ $# -le 1 ]] || { echo 'Usage: soga update [VERSION]' >&2; exit 1; }
        VERSION=${1:-2.18.0}; VERSION=${VERSION#v}
        [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]] || exit 1
        WORK=$(mktemp -d); trap 'rm -rf -- "$WORK"' EXIT
        # Fetch the installer from the selected release, never from upstream.
        BASE="https://github.com/$REPO/releases/download/v$VERSION"
        curl --fail --location --retry 3 "$BASE/install.sh" -o "$WORK/install.sh"
        curl --fail --location --retry 3 "$BASE/install.sh.sha256" -o "$WORK/install.sh.sha256"
        (cd "$WORK" && sha256sum -c install.sh.sha256)
        bash "$WORK/install.sh" "$VERSION" ;;
    rollback)
        [[ $# == 1 && -f $1/soga ]] || { echo 'Specify an installer backup directory containing soga' >&2; exit 1; }
        BACKUP=$(cd -- "$1" && pwd)
        [[ $BACKUP == /var/backups/soga-v1/* ]] || { echo 'Use an installer backup under /var/backups/soga-v1' >&2; exit 1; }
        exec 9>/run/lock/soga-v1-install.lock; flock -n 9 || exit 1
        ACTIVE=()
        while IFS= read -r unit; do [[ -z $unit ]] || ACTIVE+=("$unit"); done < <(
          systemctl list-units --type=service --state=active --no-legend --plain 'soga.service' 'soga@*.service' | awk '{print $1}')
        "$BACKUP/soga" -v
        install -m 755 "$BACKUP/soga" /usr/local/soga/soga.new
        if ((${#ACTIVE[@]})); then systemctl stop "${ACTIVE[@]}"; fi
        mv -f /usr/local/soga/soga.new /usr/local/soga/soga
        for unit in soga.service soga@.service; do [[ ! -f $BACKUP/$unit ]] || install -m 644 "$BACKUP/$unit" "/etc/systemd/system/$unit"; done
        [[ ! -f $BACKUP/manager ]] || install -m 755 "$BACKUP/manager" /usr/bin/soga
        systemctl daemon-reload
        if ((${#ACTIVE[@]})); then systemctl start "${ACTIVE[@]}"; fi
        echo 'Core and manager restored. Configurations and certificates were not rolled back.' ;;
    *) usage; exit 1 ;;
esac
