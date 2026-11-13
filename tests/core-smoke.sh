#!/usr/bin/env bash
# Disposable Linux container only. Network/systemd are mocked.
set -Eeuo pipefail
mkdir -p /tmp/mock /usr/local/soga /etc/soga /run/lock
cat > /tmp/mock/curl <<'MOCK'
#!/bin/bash
set -e
URL=; OUT=
while (($#)); do case "$1" in -o) OUT=$2; shift 2;; --retry|--connect-timeout) shift 2;; http*) URL=$1; shift;; *) shift;; esac; done
case "$URL" in https://test.invalid/core) cp /core/soga "$OUT";; *) printf '<html>bad download</html>' > "$OUT";; esac
MOCK
cat > /tmp/mock/systemctl <<'MOCK'
#!/bin/bash
printf '%s\n' "$*" >> /tmp/service-actions
if [[ $1 == list-units ]]; then echo 'soga@node01.service loaded active running fixture'; fi
MOCK
chmod +x /tmp/mock/*
export PATH="/tmp/mock:$PATH"
printf '#!/bin/bash\necho old-core\n' > /usr/local/soga/soga
chmod +x /usr/local/soga/soga
printf 'unchanged\n' > /etc/soga/soga.conf
SHA=$(sha256sum /core/soga); SHA=${SHA%% *}
if bash /source/replace-core.sh https://test.invalid/html; then exit 1; fi
[[ $(/usr/local/soga/soga -v) == old-core ]]
if bash /source/replace-core.sh https://test.invalid/core "$(printf '%064d' 0)"; then exit 1; fi
[[ $(/usr/local/soga/soga -v) == old-core ]]
bash /source/replace-core.sh https://test.invalid/core "$SHA"
cmp /core/soga /usr/local/soga/soga
grep -q '^stop soga@node01.service$' /tmp/service-actions
grep -q '^start soga@node01.service$' /tmp/service-actions
grep -q unchanged /etc/soga/soga.conf
[[ $(head -1 /etc/soga/custom-core-source) == https://test.invalid/core ]]
[[ $(stat -c %a /etc/soga/custom-core-source) == 600 ]]
COUNT=$(wc -l < /tmp/service-actions)
SOGA_CORE_INSTALL_ONLY=1 bash /source/replace-core.sh https://test.invalid/core "$SHA"
[[ $(wc -l < /tmp/service-actions) == "$COUNT" ]]
echo 'PASS: HTML rejection, SHA256 rejection before replacement, real ELF/version, atomic replacement, service restart, installer mode, unchanged config and persisted source'
