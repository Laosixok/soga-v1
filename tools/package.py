#!/usr/bin/env python3
"""Build deterministic release assets from bundle/ and a user-supplied core."""
from pathlib import Path
import hashlib, tarfile, gzip, io
root = Path(__file__).resolve().parents[1]
bundle = root / 'bundle'
required = ['soga', 'install.sh', 'soga.sh', 'VERSION', 'soga.conf', 'blockList', 'whiteList', 'dns.yml', 'routes.toml', 'soga.service', 'soga@.service']
for name in required:
    if not (bundle / name).is_file(): raise SystemExit('Missing bundle/' + name)
checksum = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
(bundle / 'SHA256SUMS').write_text(''.join(checksum(bundle / name) + '  ' + name + '\n' for name in sorted(required)))
out = root / 'assets'; out.mkdir(exist_ok=True)
archive = out / 'soga-linux-amd64.tar.gz'
with archive.open('wb') as raw, gzip.GzipFile(filename='', fileobj=raw, mode='wb', mtime=0) as gz, tarfile.open(fileobj=gz, mode='w') as tar:
    for name in sorted(required + ['SHA256SUMS']):
        data = (bundle / name).read_bytes(); info = tarfile.TarInfo(name)
        info.size = len(data); info.mtime = 0; info.mode = 0o755 if name in ['soga', 'install.sh', 'soga.sh'] else 0o644
        tar.addfile(info, io.BytesIO(data))
(out / 'install.sh').write_bytes((bundle / 'install.sh').read_bytes())
for name in ['soga-linux-amd64.tar.gz', 'install.sh']:
    (out / (name + '.sha256')).write_text(checksum(out / name) + '  ' + name + '\n')
print('Built', archive, archive.stat().st_size, 'bytes')
