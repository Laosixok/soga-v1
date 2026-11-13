#!/usr/bin/env bash
# Disposable Linux container only; uses the actual official manager with systemd mocked.
set -Eeuo pipefail
mkdir -p /etc/soga /etc/systemd/system /usr/local/soga /tmp/mock /tmp/official
# /official is the read-only official release directory used by the local test.
tar -xzf /official/official-amd64.tar.gz -C /tmp/official
cp /tmp/official/soga/soga.conf /etc/soga/soga.conf
cp /tmp/official/soga/soga@.service /etc/systemd/system/soga@.service
cp /tmp/official/soga/soga@.service /usr/local/soga/soga@.service
cp /official/assets/soga-cmd-linux-amd64 /usr/local/soga/soga-cmd
chmod +x /usr/local/soga/soga-cmd
printf '#!/bin/sh\necho 2.18.0\n' > /usr/local/soga/soga
chmod +x /usr/local/soga/soga
printf '#!/bin/sh\necho "$*" >> /tmp/systemctl-actions\nexit 0\n' > /tmp/mock/systemctl
chmod +x /tmp/mock/systemctl
export PATH="/tmp/mock:$PATH"
source /source/soga-wrapper.sh
printf '4\n7\n19\n\nhttps://panel.example.com/soga/\nsynthetic-key\ny\nhttps://invalid.example.com\nnode01.example.com\n' | new_instance tlsyes
CONFIG=/etc/soga/tlsyes/soga.conf
grep -Eq '^cert_mode[[:space:]]*=[[:space:]]*http[[:space:]]*$' "$CONFIG"
grep -Eq '^cert_domain[[:space:]]*=[[:space:]]*node01.example.com[[:space:]]*$' "$CONFIG"
grep -Eq '^cert_key_length[[:space:]]*=[[:space:]]*ec-256[[:space:]]*$' "$CONFIG"
grep -Eq '^dns_provider[[:space:]]*=[[:space:]]*$' "$CONFIG"
grep -Eq '^webapi_key[[:space:]]*=[[:space:]]*synthetic-key[[:space:]]*$' "$CONFIG"
printf '4\n7\n20\n\nhttps://panel.example.com/soga/\nsynthetic-key\nn\n' | new_instance tlsno
grep -Eq '^cert_mode[[:space:]]*=[[:space:]]*$' /etc/soga/tlsno/soga.conf
grep -Eq '^cert_domain[[:space:]]*=[[:space:]]*$' /etc/soga/tlsno/soga.conf
if printf '4\n7\n21\n\nhttps://panel.example.com/soga/\nsynthetic-key\ny\n' | new_instance tlscancel; then echo 'EOF incorrectly succeeded'; exit 1; fi
[[ ! -d /etc/soga/tlscancel ]]
if new_instance ../escape </dev/null; then exit 1; fi
if new_instance tlsyes </dev/null; then exit 1; fi
if grep -Eq '^start ' /tmp/systemctl-actions; then echo 'Wizard started instance unexpectedly'; exit 1; fi
printf '0\n' | main
if valid_cert_domain '*.example.com' || valid_cert_domain 'a..example.com'; then exit 1; fi
echo 'PASS: real official new command, TLS yes/no, domain validation, EOF cancellation, existing instance protection, no automatic start and menu exit'
