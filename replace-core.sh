#!/usr/bin/env bash
# Replace only the core. Does not change node configuration or certificates.
set -Eeuo pipefail
umask 077
[[ $EUID == 0 ]] || { echo '请使用 root 运行' >&2; exit 1; }
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || { echo '当前自定义核心仅支持 Linux x86_64' >&2; exit 1; }
URL=${1:-}; EXPECTED=${2:-}
[[ $URL == https://* || $URL == http://* ]] || { echo '用法：soga core 下载直链 [SHA256]' >&2; exit 1; }
[[ $URL != *$'\n'* && $URL != *$'\r'* ]] || exit 1
[[ -z $EXPECTED || $EXPECTED =~ ^[A-Fa-f0-9]{64}$ ]] || { echo 'SHA256 格式无效' >&2; exit 1; }
[[ -x /usr/local/soga/soga ]] || { echo '请先安装 soga' >&2; exit 1; }
command -v flock >/dev/null || { echo '请安装 util-linux（flock）' >&2; exit 1; }
exec 9>/run/lock/soga-custom-core.lock
flock -n 9 || { echo '另一个核心替换正在运行' >&2; exit 1; }
STAGE=$(mktemp /usr/local/soga/.core.XXXXXX)
trap 'rm -f -- "$STAGE"' EXIT
curl --fail --location --retry 3 --connect-timeout 15 "$URL" -o "$STAGE"
if [[ -n $EXPECTED ]]; then
    ACTUAL=$(sha256sum "$STAGE"); ACTUAL=${ACTUAL%% *}
    [[ ${ACTUAL,,} == ${EXPECTED,,} ]] || { echo 'SHA256 校验失败，原核心未修改' >&2; exit 1; }
fi
MAGIC=$(od -An -tx1 -N6 "$STAGE" | tr -d ' \n')
MACHINE=$(od -An -tx1 -j18 -N2 "$STAGE" | tr -d ' \n')
[[ $MAGIC == 7f454c460201 && $MACHINE == 3e00 ]] || { echo '文件必须为 Linux amd64 ELF 执行文件，不能是压缩包或网页' >&2; exit 1; }
chmod 755 "$STAGE"
"$STAGE" -v
ACTIVE=()
if [[ ${SOGA_CORE_INSTALL_ONLY:-0} != 1 ]]; then
    while IFS= read -r unit; do [[ -z $unit ]] || ACTIVE+=("$unit"); done < <(
      systemctl list-units --type=service --state=active --no-legend --plain 'soga.service' 'soga@*.service' | awk '{print $1}')
    if ((${#ACTIVE[@]})); then systemctl stop "${ACTIVE[@]}"; fi
fi
mv -f -- "$STAGE" /usr/local/soga/soga
# Plain data, never sourced as shell code; makes future wrapper updates reuse the URL.
mkdir -p /etc/soga
SOURCE=$(mktemp /etc/soga/.core-source.XXXXXX)
printf '%s\n%s\n' "$URL" "$EXPECTED" > "$SOURCE"
chmod 600 "$SOURCE"
mv -f "$SOURCE" /etc/soga/custom-core-source
if ((${#ACTIVE[@]})); then systemctl start "${ACTIVE[@]}"; fi
echo '自定义核心替换完成，节点配置和证书未修改'
