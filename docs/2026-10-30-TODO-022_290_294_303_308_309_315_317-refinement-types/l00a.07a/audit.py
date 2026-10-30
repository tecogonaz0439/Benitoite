#!/usr/bin/env python3
"""保存物の構文・件数・ハッシュ・相対リンクを読み取りで自己点検する。"""

import ast
import collections
import gzip
import hashlib
import json
import pathlib
import re

HERE = pathlib.Path(__file__).resolve().parent
CHANGE = HERE.parent
ROOT = HERE.parents[2]
raw = gzip.decompress((HERE / "inventory.json.gz").read_bytes())
data = json.loads(raw)
doc = (HERE / "inventory.md").read_text()
assert hashlib.sha256(raw).hexdigest() in doc
assert str(len(raw)) in doc and str((HERE / "inventory.json.gz").stat().st_size) in doc
protected = gzip.decompress((HERE / "protected-inputs.json.gz").read_bytes())
assert hashlib.sha256(protected).hexdigest() in doc
assert str(len(protected)) in doc
assert all(hashlib.sha256((ROOT / e["path"]).read_bytes()).hexdigest() == e["sha256"]
           for e in json.loads(protected))
groups = data["groups"]
es = data["old_candidates"]
assert len(es) == sum(g["candidates"] for g in groups) == 962
assert sum(g["N_g"] for g in groups) == 955
assert sum(g["completed"] for g in groups) == 7
assert collections.Counter(e["origin"] for e in es) == {
    "P3b": 819, "independent-subsumption": 28, "mutual-companion": 115}
assert collections.Counter(e["companion_reason"] for e in es if e["origin"] == "mutual-companion") == {
    "named-family": 39, "mutual-block": 76}
pending_stages = collections.Counter(e["stage"] for e in es if e["status"] == "pending-candidate")
assert pending_stages == {"L10": 151, "L20": 394, "L40": 82, "L50": 36, "L70": 292}
table = (CHANGE / "l00a.07b/groups.md").read_text().strip()
assert table in (CHANGE / "l00a.07b/inventory.md").read_text()
members = (CHANGE / "l00a.07b/members.md").read_text()
assert sum(line.startswith("| `") for line in members.splitlines()) == 962
assert len(data["new_declarations"]) == 177
assert sum(bool(e["judgment_mentions"]) for e in data["new_declarations"]) == 18
assert sum(e["role"] == "bridge" for e in data["new_declarations"]) == 2
assert sum(e["kind"] == "theorem" and not e["private"] for e in data["new_declarations"]) == 22
assert len(data["unrelated_names"]) == 2
links = 0
scripts = 0
files = sorted(HERE.iterdir()) + sorted((CHANGE / "l00a.07b").iterdir())
for p in files:
    if p.suffix == ".py":
        ast.parse(p.read_text(), filename=str(p.relative_to(ROOT)))
        scripts += 1
    if p.suffix in {".md", ".py", ".json", ".log"}:
        text = p.read_text()
        assert not re.search(r"/(?:Users|private/tmp|private/var|home)/", text), p.name
        if p.suffix == ".md":
            for target in re.findall(r"\]\(([^\s)]+)\)", text):
                if re.match(r"[A-Za-z]+://|#", target):
                    continue
                path = target.split("#", 1)[0]
                assert (p.parent / path).is_file(), (p.name, target)
                links += 1
    if p.name.endswith(".json.gz"):
        text = gzip.decompress(p.read_bytes()).decode()
        assert not re.search(r"/(?:Users|private/tmp|private/var|home)/", text), p.name
    if p.suffix == ".json":
        assert p.stat().st_size <= 200 * 1024, p.name
print(json.dumps(dict(exit_code=0, protected_inputs=len(json.loads(protected)),
                      candidates=len(es), pending=955, pending_stages=dict(pending_stages),
                      scripts_parsed=scripts, relative_links_checked=links,
                      inventory_sha256=hashlib.sha256(raw).hexdigest()), ensure_ascii=False, indent=2))
