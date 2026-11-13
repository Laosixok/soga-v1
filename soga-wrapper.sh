#!/usr/bin/env bash
set -Eeuo pipefail
BASE=https://raw.githubusercontent.com/Laosixok/soga-v1/master
case "${1:-}" in
    core) shift; exec bash /usr/local/soga/replace-core.sh "$@" ;;
    update|self-update)
        ACTION=$1; shift
        [[ $EUID == 0 ]] || { echo '请使用 root 运行' >&2; exit 1; }
        WORK=$(mktemp -d); trap 'rm -rf -- "$WORK"' EXIT
        if [[ $ACTION == self-update ]]; then SCRIPT=install_cmd.sh; else SCRIPT=install.sh; fi
        curl -fL --retry 3 "$BASE/$SCRIPT" -o "$WORK/$SCRIPT"
        bash "$WORK/$SCRIPT" "$@" ;;
    *) exec /usr/local/soga/soga-cmd "$@" ;;
esac
