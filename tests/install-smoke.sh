#!/usr/bin/env bash
# Run only inside a disposable Linux container. systemd is mocked.
set -Eeuo pipefail
mkdir -p /tmp/package /tmp/mock /run/lock /etc/soga/node01 /usr/local/soga
cp -a /source/bundle/. /tmp/package/
cat > /tmp/mock/systemctl <<'MOCK'
#!/bin/bash
printf '%s\n' "$*" >> /tmp/systemctl-calls
if [[ $1 == list-units ]]; then echo 'soga@node01.service loaded active running node01'; fi
MOCK
chmod +x /tmp/mock/systemctl
export PATH="/tmp/mock:$PATH"
printf '# preserved existing config\nnode_id=99\n' > /etc/soga/node01/soga.conf
printf 'certificate-fixture\n' > /etc/soga/example.crt
printf '#!/bin/bash\necho old-core\n' > /usr/local/soga/soga
chmod +x /usr/local/soga/soga
bash /tmp/package/install.sh
cmp /tmp/package/soga /usr/local/soga/soga
grep -q node_id=99 /etc/soga/node01/soga.conf
grep -q certificate-fixture /etc/soga/example.crt
grep -q 'stop soga@node01.service' /tmp/systemctl-calls
grep -q 'start soga@node01.service' /tmp/systemctl-calls
bash /usr/bin/soga new test02
[[ -f /etc/soga/test02/soga.conf ]]
if bash /usr/bin/soga new test02; then echo 'Duplicate instance was accepted' >&2; exit 1; fi
if bash /usr/bin/soga start ../escape; then echo 'Path traversal was accepted' >&2; exit 1; fi
BACKUP=$(find /var/backups/soga-v1 -mindepth 1 -maxdepth 1 -type d | head -1)
bash /usr/bin/soga rollback "$BACKUP"
[[ $(/usr/local/soga/soga -v) == old-core ]]
printf '\ncorruption\n' >> /tmp/package/soga.sh
if bash /tmp/package/install.sh; then echo 'Invalid checksum was accepted' >&2; exit 1; fi
[[ $(/usr/local/soga/soga -v) == old-core ]]
echo 'PASS: install, existing instance restart, config/cert preservation, new instance, invalid name, rollback, checksum rejection'
