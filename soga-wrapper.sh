#!/usr/bin/env bash
set -Eeuo pipefail
BASE=https://raw.githubusercontent.com/Laosixok/soga-v1/master
# The official manager is binary-only. Keep provisioning in this readable wrapper.
official() { /usr/local/soga/soga-cmd "$@"; }
require_root() { [[ $EUID == 0 ]] || { echo '请使用 root 运行' >&2; return 1; }; }
valid_instance_name() { [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ && $1 != default ]]; }
read_required() {
    local label=$1
    while true; do
        IFS= read -r -p "$label" REPLY || return 1
        [[ -n $REPLY && $REPLY != *$'\r'* ]] && return 0
        echo '此项不可留空，请重新输入。' >&2
    done
}
valid_cert_domain() {
    local label domain=$1
    [[ ${#domain} -le 253 && $domain == *.* && $domain != *..* && $domain != .* && $domain != *. ]] || return 1
    local labels=()
    IFS=. read -r -a labels <<< "$domain"
    for label in "${labels[@]}"; do
        [[ ${#label} -le 63 && $label =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]] || return 1
    done
}
new_instance() {
    require_root || return 1
    [[ -x /usr/local/soga/soga ]] || { echo '请先安装 soga 核心。' >&2; return 1; }
    local name=${1:-} answer panel protocol node_id license api_url api_key domain='' cert_mode=''
    if [[ -z $name ]]; then
        read_required '请输入新实例名称 (如 node01): ' || return 1
        name=$REPLY
    fi
    valid_instance_name "$name" || { echo '实例名只允许字母、数字、下划线和横线，不能为 default。' >&2; return 1; }
    [[ ! -e /etc/soga/$name ]] || { echo '该实例已存在，未修改配置。' >&2; return 1; }
    echo '① 面板上报类型 type：1 xboard（默认） 2 xiaov2board 3 sspanel-uim 4 soga-v1 5 v2board 6 v2raysocks 7 whmcs 8 proxypanel 9 ppanel'
    while true; do
        IFS= read -r -p '请选择 [1-9，回车=1]: ' answer || return 1
        case ${answer:-1} in
            1) panel=xboard;; 2) panel=xiaov2board;; 3) panel=sspanel-uim;; 4) panel=soga-v1;; 5) panel=v2board;;
            6) panel=v2raysocks;; 7) panel=whmcs;; 8) panel=proxypanel;; 9) panel=ppanel;; *) echo '请选择 1-9'; continue;;
        esac
        break
    done
    echo '② 节点协议 server_type：1 ss（默认） 2 v2ray 3 trojan 4 vless 5 ssr 6 hysteria 7 anytls 8 mieru'
    while true; do
        IFS= read -r -p '请选择 [1-8，回车=1]: ' answer || return 1
        case ${answer:-1} in
            1) protocol=ss;; 2) protocol=v2ray;; 3) protocol=trojan;; 4) protocol=vless;; 5) protocol=ssr;;
            6) protocol=hysteria;; 7) protocol=anytls;; 8) protocol=mieru;; *) echo '请选择 1-8'; continue;;
        esac
        break
    done
    while true; do
        read_required '③ 节点 ID node_id (不可留空): ' || return 1
        node_id=$REPLY
        [[ $node_id =~ ^[1-9][0-9]*(,[1-9][0-9]*)*$ ]] && break
        echo '节点 ID 需为正整数，多个 ID 用英文逗号分隔。'
    done
    IFS= read -r -p '④ soga_key（授权码，可留空）: ' license || return 1
    while true; do
        read_required '⑥ WebAPI 根地址 webapi_url (不可留空): ' || return 1
        api_url=$REPLY
        [[ $api_url == https://* || $api_url == http://* ]] && break
        echo '地址需以 https:// 或 http:// 开头。'
    done
    read_required '⑦ WebAPI 密钥 webapi_key (不可留空): ' || return 1
    api_key=$REPLY
    while true; do
        IFS= read -r -p '⑧ 是否开启 TLS 证书自动申请？[y/N]: ' answer || return 1
        case $answer in
            y|Y|yes|YES)
                cert_mode=http
                while true; do
                    read_required '⑨ 证书域名 cert_domain（仅域名，不带 https://）: ' || return 1
                    domain=$REPLY
                    valid_cert_domain "$domain" && break
                    echo '请输入有效域名，例如 node01.example.com；HTTP 验证不支持通配符。'
                done
                break ;;
            ''|n|N|no|NO) break ;;
            *) echo '请输入 y 或 n。' ;;
        esac
    done
    official new "$name" "type=$panel" "server_type=$protocol" "api=webapi" "node_id=$node_id" \
        "soga_key=$license" "webapi_url=$api_url" "webapi_key=$api_key" \
        "cert_mode=$cert_mode" "cert_domain=$domain" 'cert_key_length=ec-256' 'dns_provider=' || return 1
    if [[ $cert_mode == http ]]; then
        echo "已开启 HTTP 证书自动申请：$domain。请确认域名解析到节点，TCP 80 可达且未被其他服务占用。"
    else
        echo '未开启自动申请。AnyTLS 等 TLS 协议仍需要有效证书，请自行配置已有证书后启动。'
    fi
    echo "配置已写入 /etc/soga/$name/soga.conf；准备好后执行：soga start $name"
}
instance_menu() {
    local name=$1 choice
    [[ $name =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]] || return 1
    while true; do
        echo "实例 [$name]：1启动 2停止 3重启 4日志 5查看配置 6开机自启 7取消自启 0返回"
        IFS= read -r -p '请选择: ' choice || return 0
        case $choice in
            0) return 0;; 1) official start "$name";; 2) official stop "$name";; 3) official restart "$name";;
            4) official log "$name";; 5) official config "$name";; 6) official enable "$name";; 7) official disable "$name";;
            *) echo '输入无效';;
        esac || true
    done
}
main_menu() {
    require_root || return 1
    local choice
    while true; do
        echo
        echo 'soga 管理菜单'
        echo '0. 退出'
        echo '1. 安装/更新 soga（本仓库入口）'
        echo '2. 完全卸载 soga（官方命令）'
        echo '3. 列出实例'
        echo '4. 更新管理脚本'
        echo '5. 新增 soga 实例（含 TLS 证书询问）'
        echo '6. 官方管理菜单（原版）'
        echo '也可输入实例名，进入实例操作菜单。'
        IFS= read -r -p '请输入选择或实例名: ' choice || return 0
        case $choice in
            0) return 0;; 1) main update;; 2) official uninstall;; 3) official list;; 4) main self-update;;
            5) new_instance;; 6) official;; '') continue;; *) instance_menu "$choice";;
        esac || true
    done
}

main() {
case "${1:-}" in
    '') main_menu ;;
    new)
        shift
        if [[ $# -le 1 && ${1:-} != -h && ${1:-} != --help ]]; then new_instance "${1:-}"
        else official new "$@"; fi ;;
    core) shift; exec bash /usr/local/soga/replace-core.sh "$@" ;;
    update|self-update)
        ACTION=$1; shift
        [[ $EUID == 0 ]] || { echo '请使用 root 运行' >&2; exit 1; }
        WORK=$(mktemp -d); trap 'rm -rf -- "$WORK"' EXIT
        if [[ $ACTION == self-update ]]; then SCRIPT=install_cmd.sh; else SCRIPT=install.sh; fi
        curl -fL --retry 3 "$BASE/$SCRIPT" -o "$WORK/$SCRIPT"
        bash "$WORK/$SCRIPT" "$@" ;;
    *) official "$@" ;;
esac
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi
