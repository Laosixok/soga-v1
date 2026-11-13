# soga-v1 独立安装与管理

本仓库 fork 自 [vaxilu/soga](https://github.com/vaxilu/soga)，保留原有 Git 历史；当前安装、管理脚本为本仓库重新实现。核心使用仓库所有者提供的 **soga 2.18.0 Linux amd64** 文件，未修改其内容。安装包、校验文件、管理脚本全部从 **Laosixok/soga-v1** 下载，不再调用上游安装脚本、上游 Release 或 soga-cmd。

“独立”指安装与管理资源独立托管。闭源核心自身的授权、联网检查、证书申请等行为仍由该执行包决定；本项目不移除这些机制。证书申请依赖证书颁发机构，面板依赖你自己的站点。只支持 Linux x86_64、glibc 和 systemd；目前不提供 ARM64 核心。

## 安装 / 接管已有官方安装

以 root 执行（当前固定版本 2.18.0）：

```bash
curl -fL https://github.com/Laosixok/soga-v1/releases/download/v2.18.0/install.sh -o /root/soga-v1-install.sh
curl -fL https://github.com/Laosixok/soga-v1/releases/download/v2.18.0/install.sh.sha256 -o /root/soga-v1-install.sh.sha256
# 安装器校验文件中的文件名为 install.sh，按以下方式验证下载副本：
cd /root
sed 's/  install.sh$/  soga-v1-install.sh/' soga-v1-install.sh.sha256 | sha256sum -c -
bash /root/soga-v1-install.sh
```

安装前需已有 bash、curl、tar、sha256sum、install、flock、systemctl。这些来自发行版基础包及 util-linux。安装器不运行 apt/yum，不安装 acme.sh；此核心有内置证书申请功能。

已有 `/etc/soga`（含 node01 等实例及证书）完整保留。原核心、管理命令、配置和本地 service 文件备份到 `/var/backups/soga-v1/时间-进程号/`。更新会短暂停止并恢复原本运行的 soga 实例。新安装不自动启动，也不会默认开放防火墙。

离线安装：下载本 Release 的 `soga-linux-amd64.tar.gz` 与对应 `.sha256`，放在同一目录，执行：

```bash
sha256sum -c soga-linux-amd64.tar.gz.sha256
mkdir soga-local
 tar -xzf soga-linux-amd64.tar.gz -C soga-local
bash soga-local/install.sh
```

离线安装过程不下载任何上游文件。

## 管理实例

```bash
soga list
soga new node01
soga config node01
soga start node01
soga enable node01
soga status node01
soga log node01 -f
soga restart node01
soga stop node01
soga version
```

现有 node01 不要重复新建，直接 `soga config node01` / `soga restart node01`。新建实例会复制 `/etc/soga` 的默认配置，必须先编辑节点 ID、协议、密钥和证书域名。省略实例名操作默认 `/etc/soga/soga.conf`；命名实例使用 `/etc/soga/实例名/soga.conf` 和 `soga@实例名.service`。

配置示例：

```ini
type=soga-v1
server_type=anytls
api=webapi
node_id=后台实际节点ID
webapi_url=https://你的面板域名/soga/
webapi_key=你自己的面板muKey
soga_key=
cert_mode=http
cert_domain=节点证书域名
cert_key_length=ec-256
dns_provider=
```

server_type 可按节点选择 anytls / hysteria / mieru（以面板接口支持为准）。Mieru 不需 TLS 证书；请按核心协议配置要求调整。AnyTLS / Hysteria 的证书域名、DNS 和端口需配置正确；HTTP 验证使用 TCP 80，AnyTLS 本例监听 TCP 443。面板代码需已支持 soga-v1。

## 更新 / 回退

```bash
# 当前默认仍固定为 2.18.0；未来发布新版本后显式指定版本
soga update 2.18.0
# 使用安装器输出的真实备份目录
soga rollback /var/backups/soga-v1/真实备份目录
```

回退恢复核心、管理命令和备份的本地 service；保留当前配置及证书，不覆盖最新配置修改。若实例此前已失败停止，回退后需手动启动该实例。升级前后应查看日志；`systemctl is-active` 只说明检查时刻的状态，不能证明进程之后不会退出。

不要再运行上游安装/更新命令，否则会覆盖本仓库的管理工具和核心。

## 自行发布新执行包

将自有 Linux amd64 执行文件放入本项目的 `bundle/soga`，修改 `bundle/VERSION`，并按 `tools/package.py` 生成发行包。核心文件不放进 Git 历史，上传到本仓库 Release。相应 tag 命名为 `v版本号`，Release 附件应包含：

- soga-linux-amd64.tar.gz
- soga-linux-amd64.tar.gz.sha256
- install.sh
- install.sh.sha256

目前发布的二进制只验证了版本、参数和离线启动入口；未修改或审计其内部行为。测试在隔离 Linux 容器中检查安装/接管、保留配置、管理命令、校验失败和不支持架构处理；真实 systemd 服务和生产网络仍需在目标机器验证。
