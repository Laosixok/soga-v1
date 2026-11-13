#!/usr/bin/env bash
# Keep the official manager; route update commands and custom core replacement locally.
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo '请使用 root 运行' >&2; exit 1; }
case $(uname -m) in x86_64|amd64) ARCH=amd64 ;; *) echo '当前仅支持 Linux amd64' >&2; exit 1 ;; esac
BASE=https://raw.githubusercontent.com/Laosixok/soga-v1/master
WORK=$(mktemp -d); trap 'rm -rf -- "$WORK"' EXIT
CMD_URL=${SOGA_CMD_URL:-https://github.com/vaxilu/soga-cmd/releases/latest/download/soga-cmd-linux-$ARCH}
curl -fL --retry 3 "$CMD_URL" -o "$WORK/soga-cmd"
curl -fL --retry 3 "$BASE/soga-wrapper.sh" -o "$WORK/wrapper"
curl -fL --retry 3 "$BASE/replace-core.sh" -o "$WORK/replace-core.sh"
bash -n "$WORK/wrapper"
bash -n "$WORK/replace-core.sh"
chmod 755 "$WORK/soga-cmd"
"$WORK/soga-cmd" --help >/dev/null
mkdir -p /usr/local/soga
install -m 755 "$WORK/soga-cmd" /usr/local/soga/soga-cmd
install -m 755 "$WORK/replace-core.sh" /usr/local/soga/replace-core.sh
install -m 755 "$WORK/wrapper" /usr/bin/soga
echo '管理命令安装完成：soga（原管理功能）/ soga core 下载链接 [SHA256]'
