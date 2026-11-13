# soga-v1

Fork 自 [vaxilu/soga](https://github.com/vaxilu/soga)。保留官方默认安装流程、配置模板和管理工具，只增加自定义核心下载直链。**不托管任何自定义核心，不内置 node01 或站点密钥。**

## 安装并自动替换核心

下载本仓库脚本，再把示例链接换成你自己的 Linux amd64 执行文件直链：

```bash
curl -fL https://raw.githubusercontent.com/Laosixok/soga-v1/master/install.sh -o /root/install-soga.sh
bash /root/install-soga.sh --core-url 'https://你的下载站/soga-v2.18.0'
```

可选校验：

```bash
bash /root/install-soga.sh --core-url 'https://你的下载站/soga-v2.18.0' --core-sha256 '文件的64位SHA256'
```

安装先按官方方式部署默认安装包，再在启动服务前替换核心。自定义下载失败会终止安装，不会将官方核心作为自定义核心报告成功。

## 只替换已安装核心

首次将管理入口切换到本仓库（不修改节点配置）：

```bash
curl -fL https://raw.githubusercontent.com/Laosixok/soga-v1/master/install_cmd.sh -o /root/install-soga-cmd.sh
bash /root/install-soga-cmd.sh
soga core 'https://你的下载站/soga-v2.18.0'
```

也可以指定校验：`soga core '下载直链' 'SHA256'`。

链接必须直接返回 Linux x86_64 ELF 执行文件，不能返回登录页、HTML 或 tar/zip。文件先下载、验证格式和版本，之后才停止运行中的实例并原子替换核心；配置、证书不参与替换。

下载来源以纯文本保存在 `/etc/soga/custom-core-source`（权限 600），不作为 shell 脚本执行。以后通过本仓库的 `soga update` 更新时，会继续使用此自定义链接。若提供 SHA256，发布新文件后需用 `soga core 新链接 新SHA256` 更新来源。

## 原有管理方式

```bash
soga
soga list
soga new node01
soga config node01
soga restart node01
soga log node01 -f
soga update
soga self-update
```

默认 `soga` 菜单由本仓库脚本提供，选择 **5. 新增 soga 实例** 使用含 TLS 询问的向导；选择 **6. 官方管理菜单（原版）** 可进入原界面，原界面的新增实例流程不含 TLS 询问。普通子命令仍使用官方管理程序。顶层 `soga update` / `soga self-update` 通过本仓库脚本执行；**不要使用官方程序交互菜单内的安装/更新/卸载/管理程序升级项**，这些内部行为可能仍使用上游 URL。日常启动、停止、配置和日志操作不受影响。

## 下载来源和独立性

- 安装入口、核心替换脚本和更新包装入口来自 `Laosixok/soga-v1`。
- 自定义核心来自你提供的 URL，仓库不上传该核心。
- 默认基础安装包、默认配置模板及官方管理程序仍下载自官方；这是保留官方默认安装方式的组成部分。
- 若要让安装下载也完全不依赖官方服务器，可通过 `SOGA_PACKAGE_URL` 指定你自己托管的完整官方格式安装包，通过 `SOGA_CMD_URL` 指定你自己托管的官方管理执行文件。例如：

```bash
SOGA_PACKAGE_URL='https://你的下载站/soga-linux-amd64.tar.gz' \
SOGA_CMD_URL='https://你的下载站/soga-cmd-linux-amd64' \
bash /root/install-soga.sh --core-url 'https://你的下载站/soga-v2.18.0'
```

镜像地址需在后续更新时重新提供。这些文件都可托管在自己的下载站，不必上传 GitHub。保留官方安装器对系统软件源及 acme.sh 的安装步骤；核心自身的授权/联网检查未修改。

默认配置与官方一致，新装后按你的面板填写 type、server_type、node_id、webapi_url、webapi_key、证书等。安装器没有定制 node01 迁移或回退逻辑；覆盖安装对既有配置的处理沿用官方行为。替换正在运行的核心会短暂停服。

已在隔离 Linux 容器验证自定义核心格式、版本、校验失败保护、替换及来源记录。未连接用户生产服务器执行安装。

## 新建实例时询问 TLS 证书申请

更新服务器上的管理入口后，执行 `soga` 并选 **5**，或直接执行 `soga new node01`，会在第⑦项 WebAPI 密钥之后询问：

```text
⑦ WebAPI 密钥 webapi_key (不可留空):
⑧ 是否开启 TLS 证书自动申请？[y/N]:
⑨ 证书域名 cert_domain（仅域名，不带 https://）:
```

选择 y 并填写域名后，向对应实例写入：

```ini
cert_mode=http
cert_domain=你填写的节点域名
cert_key_length=ec-256
dns_provider=
```

选择 n 或直接回车，不开启自动申请；仍使用 TLS 的协议需自行配置有效证书，这不等于关闭协议 TLS。HTTP 验证要求节点域名解析正确、TCP 80 可达，并避免端口占用。

向导仅创建实例配置，不自动启动；检查后执行 `soga start node01`。已有实例不会覆盖。中途按 Ctrl+C 或输入结束，不创建实例。带完整键值参数的 `soga new NAME key=value ...` 保持原非交互方式，不额外询问。

仅更新管理包装脚本（不重装核心）：

```bash
curl -fL https://raw.githubusercontent.com/Laosixok/soga-v1/master/soga-wrapper.sh -o /tmp/soga-wrapper.sh
bash -n /tmp/soga-wrapper.sh && install -m 755 /tmp/soga-wrapper.sh /usr/bin/soga
soga
```
