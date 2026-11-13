#!/bin/bash
# Fork: Laosixok/soga-v1. Official defaults plus an optional custom core URL.

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64"
else
  arch="amd64"
  echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

#os_version=""
#
## os version
#if [[ -f /etc/os-release ]]; then
#    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
#fi
#if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
#    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
#fi
#
#if [[ x"${release}" == x"centos" ]]; then
#    if [[ ${os_version} -le 6 ]]; then
#        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
#    fi
#elif [[ x"${release}" == x"ubuntu" ]]; then
#    if [[ ${os_version} -lt 16 ]]; then
#        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
#    fi
#elif [[ x"${release}" == x"debian" ]]; then
#    if [[ ${os_version} -lt 8 ]]; then
#        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
#    fi
#fi

function is_cmd_exist() {
    local cmd="$1"
    if [ -z "$cmd" ]; then
        return 1
    fi

    which "$cmd" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        return 0
    fi

	  return 2
}

install_base() {
    # HTTPS downloads need an up-to-date system CA trust store.
    if [[ x"${release}" == x"centos" ]]; then
        yum install ca-certificates -y || return 1
        update-ca-trust extract || return 1
        yum install epel-release -y || return 1
        yum install wget curl tar crontabs socat tzdata util-linux -y || return 1
    else
        apt-get update || return 1
        apt-get install -y ca-certificates wget curl tar cron socat tzdata util-linux || return 1
        update-ca-certificates || return 1
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/soga.service ]]; then
        return 2
    fi
    temp=$(systemctl status soga | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
}

install_soga() {
    cd /usr/local/

    if  [ $# == 0 ] ;then
#        last_version=$(curl -Ls "https://api.github.com/repos/vaxilu/soga/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
#        if [[ ! -n "$last_version" ]]; then
#            echo -e "${red}检测 soga 版本失败，可能是超出 Github API 限制，请稍后再试，或手动指定 soga 版本安装${plain}"
#            exit 1
#        fi
        echo -e "开始安装 soga 最新版"
        wget -O /usr/local/soga.tar.gz "${SOGA_PACKAGE_URL:-https://github.com/vaxilu/soga/releases/latest/download/soga-linux-${arch}.tar.gz}"
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 soga 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
    else
        last_version=${1#v}
        url="${SOGA_PACKAGE_URL:-https://github.com/vaxilu/soga/releases/download/${last_version}/soga-linux-${arch}.tar.gz}"
        echo -e "开始安装 soga v${last_version}"
        wget -O /usr/local/soga.tar.gz "${url}"
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 soga v${last_version} 失败，请确保此版本存在${plain}"
            exit 1
        fi
    fi

    # Leave the existing installation intact if download/archive validation fails.
    tar -tzf /usr/local/soga.tar.gz >/dev/null || { echo '安装包无效，原安装未修改'; exit 1; }
    if [[ -e /usr/local/soga/ ]]; then
        rm /usr/local/soga/ -rf
    fi

    tar zxvf soga.tar.gz || exit 1
    rm soga.tar.gz -f
    cd soga
    chmod +x soga
    if [[ -n "$CUSTOM_CORE_URL" ]]; then
        curl -fL --retry 3 https://raw.githubusercontent.com/Laosixok/soga-v1/master/replace-core.sh -o /usr/local/soga/replace-core.sh || exit 1
        SOGA_CORE_INSTALL_ONLY=1 bash /usr/local/soga/replace-core.sh "$CUSTOM_CORE_URL" "$CUSTOM_CORE_SHA256" || exit 1
    fi
    last_version="$(./soga -v)"
    mkdir /etc/soga/ -p
    rm /etc/systemd/system/soga.service -f
    rm /etc/systemd/system/soga@.service -f
    cp -f soga.service /etc/systemd/system/
    cp -f soga@.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop soga
    systemctl enable soga
    echo -e "${green}soga v${last_version}${plain} 安装完成，已设置开机自启"
    if [[ ! -f /etc/soga/soga.conf ]]; then
        cp soga.conf /etc/soga/
        echo -e ""
        echo -e "全新安装，请先配置必要的内容"
    else
        systemctl start soga
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}soga 重启成功${plain}"
        else
            echo -e "${red}soga 可能启动失败，请稍后使用 soga log 查看日志信息${plain}"
        fi
    fi

    if [[ ! -f /etc/soga/blockList ]]; then
        cp blockList /etc/soga/
    fi
    if [[ ! -f /etc/soga/whiteList ]]; then
        cp whiteList /etc/soga/
    fi
    if [[ ! -f /etc/soga/dns.yml ]]; then
        cp dns.yml /etc/soga/
    fi
    if [[ ! -f /etc/soga/routes.toml ]]; then
        cp routes.toml /etc/soga/
    fi
    curl -fL --retry 3 https://raw.githubusercontent.com/Laosixok/soga-v1/master/install_cmd.sh -o /usr/local/soga/install_cmd.sh || exit 1
    bash /usr/local/soga/install_cmd.sh || exit 1
    echo -e ""
    echo "soga 管理脚本使用方法: "
    echo "----------------------------------------------------------"
    echo "soga                              - 显示管理菜单 (功能更多)"
    echo "soga list                         - 列出已有的实例及状态"
    echo "soga new <name> [k1=v1 ...]       - 新建实例"
    echo "soga remove <name> [name...]      - 移除实例"
    echo "soga rename <old_name> <new_name> - 重命名实例"
    echo "soga start [name]                 - 启动实例"
    echo "soga stop [name]                  - 停止实例"
    echo "soga restart [name]               - 重启实例"
    echo "soga enable [name]                - 设置实例开机自启"
    echo "soga disable [name]               - 取消实例开机自启"
    echo "soga log [name]                   - 查看实例日志(默认 1000 行)"
    echo "soga log [name] -f                - 持续输出实例日志"
    echo "soga config [name]                - 查看实例配置文件"
    echo "soga config [name] k1=v1 k2=v2    - 修改或新增配置"
    echo "soga update [version]             - 安装/更新 soga"
    echo "soga uninstall                    - 完全卸载 soga"
    echo "soga self-update                  - 更新管理脚本"
    echo "soga version                      - 查看版本"
    echo "----------------------------------------------------------"
}

apply_configs() {
    local conf_file="/etc/soga/soga.conf"
    if [[ ! -f ${conf_file} ]]; then
        echo -e "${red}配置文件 ${conf_file} 不存在，跳过配置写入${plain}"
        return
    fi
    for kv in "$@"; do
        local key="${kv%%=*}"
        local value="${kv#*=}"
        if [[ -z "${key}" || "${key}" == "${kv}" ]]; then
            echo -e "${yellow}忽略无效配置参数: ${kv}${plain}"
            continue
        fi
        local esc_value
        esc_value=$(printf '%s\n' "${value}" | sed -e 's/[\/&|]/\\&/g')
        if grep -Eq "^[[:space:]]*${key}[[:space:]]*=" "${conf_file}"; then
            sed -i -E "s|^[[:space:]]*${key}[[:space:]]*=.*|${key}=${esc_value}|" "${conf_file}"
            echo -e "${green}已更新配置: ${key}=${value}${plain}"
        else
            echo "${key}=${value}" >> "${conf_file}"
            echo -e "${green}已添加配置: ${key}=${value}${plain}"
        fi
    done
}

is_cmd_exist "systemctl"
if [[ $? != 0 ]]; then
    echo "systemctl 命令不存在，请使用较新版本的系统，例如 Ubuntu 18+、Debian 9+"
    exit 1
fi

version=""
configs=()
CUSTOM_CORE_URL="${SOGA_CORE_URL:-}"
CUSTOM_CORE_SHA256="${SOGA_CORE_SHA256:-}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --core-url) [[ $# -ge 2 ]] || { echo 'Missing core URL'; exit 1; }; CUSTOM_CORE_URL=$2; shift 2 ;;
        --core-sha256) [[ $# -ge 2 ]] || { echo 'Missing SHA256'; exit 1; }; CUSTOM_CORE_SHA256=$2; shift 2 ;;
        --help|-h) echo "Usage: bash install.sh [version] [--core-url URL] [--core-sha256 SHA256] [key=value ...]"; exit 0 ;;
        --*) echo "Unknown option: $1"; exit 1 ;;
        *=*) configs+=("$1"); shift ;;
        *) [[ -z $version && $1 =~ ^v?[0-9]+[.][0-9]+[.][0-9]+$ ]] || { echo 'Invalid version'; exit 1; }; version=$1; shift ;;
    esac
done
if [[ -z $CUSTOM_CORE_URL && -f /etc/soga/custom-core-source ]]; then
    { IFS= read -r CUSTOM_CORE_URL; IFS= read -r CUSTOM_CORE_SHA256 || true; } < /etc/soga/custom-core-source
fi
if [[ -n $CUSTOM_CORE_URL ]]; then
    [[ $CUSTOM_CORE_URL == https://* || $CUSTOM_CORE_URL == http://* ]] || { echo 'Invalid core URL'; exit 1; }
    [[ $CUSTOM_CORE_URL != *$'\n'* && $CUSTOM_CORE_URL != *$'\r'* ]] || exit 1
    [[ -z $CUSTOM_CORE_SHA256 || $CUSTOM_CORE_SHA256 =~ ^[A-Fa-f0-9]{64}$ ]] || { echo 'Invalid SHA256'; exit 1; }
fi

echo -e "${green}开始安装${plain}"
install_base || { echo '基础依赖或 CA 根证书安装失败，请先修复系统软件源和证书'; exit 1; }
install_acme
install_soga ${version}

if [[ ${#configs[@]} -gt 0 ]]; then
    echo -e "${green}开始写入配置${plain}"
    apply_configs "${configs[@]}"
    systemctl restart soga
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}soga 重启成功${plain}"
    else
        echo -e "${red}soga 可能启动失败，请稍后使用 soga log 查看日志信息${plain}"
    fi
fi
