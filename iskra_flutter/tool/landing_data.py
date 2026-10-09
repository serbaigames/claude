#!/usr/bin/env python3
"""Собирает releases.json для лендинга из lib/version.dart.

Запуск: python3 tool/landing_data.py <файл-назначения>
"""
import json
import re
import sys
from pathlib import Path

src = (Path(__file__).resolve().parent.parent / 'lib' / 'version.dart').read_text(encoding='utf-8')
version = re.search(r"appVersion\s*=\s*'([^']+)'", src).group(1)


def strings(block):
    return [s.replace("\\'", "'") for s in re.findall(r"'((?:[^'\\]|\\.)*)'", block)]


releases = []
for m in re.finditer(r"Release\(\s*'([^']+)',\s*'([^']+)',\s*\[(.*?)\]\s*\)", src, re.S):
    releases.append({'version': m.group(1), 'date': m.group(2), 'changes': strings(m.group(3))})

out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('releases.json')
out.write_text(json.dumps({'version': version, 'releases': releases}, ensure_ascii=False, indent=1), encoding='utf-8')
print(f'{out}: {version}, выпусков {len(releases)}')
