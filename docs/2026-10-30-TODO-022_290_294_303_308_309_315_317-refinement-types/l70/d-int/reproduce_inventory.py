# -*- coding: utf-8 -*-
"""取りまとめ用: 固定開始版のGitオブジェクトから監査対象と旧言明を再生成する。

読み取りだけのGitを使う。実装担当の検査では実行せず、開始時に採取した一覧を使う。
ソースの作業木・index・ブランチは変更しない。
"""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from inventory import HERE, ROOT, save, signatures

BASE = "601a52cae1ffc9bbef9be71e3b56c83f0afdfa4d"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
args = parser.parse_args()
args.tmp.mkdir(parents=True, exist_ok=True)
raw = subprocess.check_output(["git", "ls-tree", "-r", "-z", BASE, "--", "formal"], cwd=ROOT)
entries = {}
for row in raw.split(b"\0"):
    if not row:
        continue
    meta, path = row.split(b"\t", 1)
    mode, kind, obj = meta.split()
    if path.endswith(b".lean") and kind == b"blob":
        entries[path.decode()] = obj
objects = subprocess.Popen(["git", "cat-file", "--batch"], cwd=ROOT,
                           stdin=subprocess.PIPE, stdout=subprocess.PIPE)
before = {}
old_statements = {}
for path, obj in sorted(entries.items()):
    objects.stdin.write(obj + b"\n")
    objects.stdin.flush()
    line = objects.stdout.readline().split()
    assert line[1] == b"blob", line
    data = objects.stdout.read(int(line[2]))
    assert objects.stdout.read(1) == b"\n"
    before[path] = hashlib.sha256(data).hexdigest()
    if path.startswith("formal/Benitoite/Release/Refinement/Surface/"):
        old_statements[path] = signatures(data.decode())
objects.stdin.close()
assert objects.wait() == 0
current = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
           for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts}
assert set(before) <= set(current), "既存モジュールの削除"
paths = sorted(p for p in current if current[p] != before.get(p))
modules = sorted(p[7:-5].replace("/", ".") for p in paths)
save(args.tmp / "reproduced-audit-modules.json", modules)
save(args.tmp / "reproduced-before-statements.json", old_statements)
assert modules == json.loads((HERE / "audit-modules.json").read_text())
print(json.dumps(dict(b_work=BASE, modules=len(modules), statements=sum(map(len, old_statements.values())))))
