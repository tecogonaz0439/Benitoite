"""局所照合の入力、固定版、差分と証拠の対応を保存する（比較を再実行しない）。"""
import hashlib
import json
from pathlib import Path
import subprocess

BASE = Path(__file__).resolve().parent
ROOT = Path.cwd()
B_WORK = "6b333d12343f922f976e589f6a1c4ab8f2a1929e"

def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()

def fingerprint(path):
    data = path.read_bytes()
    return {"path":path.relative_to(ROOT).as_posix(), "bytes":len(data),
            "sha256":hashlib.sha256(data).hexdigest()}

corpus = json.loads((BASE/"f-local/named-declarations-corpus.json").read_text())
builtins = json.loads((BASE/"f-local/named-declarations-builtins.json").read_text())
item = corpus["inputs"][0]
table = builtins["inputs"][0]
limits = json.loads((BASE.parent/"r20.5/limits.json").read_text())["limits"]
assert item["scopeAcceptance"]["limits"] == limits
assert set(item["scopeAcceptance"]) == {"patterns", "hosts", "limits"}
assert set(limits) == {"body", "whole"}
assert all(set(cap) == {"operations", "items"} for cap in limits.values())
assert corpus["version"] == 15 and builtins["version"] == 7
assert len(item["definitions"]) == 5 and not item["excluded"]

def walk(value):
    todo = [value]
    while todo:
        value = todo.pop()
        yield value
        if isinstance(value, list): todo.extend(value)
        elif isinstance(value, dict): todo.extend(value.values())

assert all(not isinstance(v,dict) or "rvar" not in v for v in walk(item))
assert any(v == {"name":{"value":"IO.File.Read","ix":{"fixed":{"path":{"tree":["data"]}}}}}
           for v in item["candidates"])
for sig in table["prims"]:
    for node in walk(sig):
        if isinstance(node,dict) and "rvar" in node:
            assert 0 <= node["rvar"] < len(sig["rkinds"])
for tag in ["prim", "primName"]:
    for node in walk(item):
        if isinstance(node,dict) and tag in node and "tys" in node[tag]:
            call = node[tag]
            sig = next(s for s in table["prims"] if s["name"] == call["name"])
            assert len(call["ranges"]) == len(sig["rkinds"])

changed = git("diff", "--name-only", B_WORK).splitlines()
extra = git("ls-files", "--others", "--exclude-standard", "--", "crates/benitoite", "formal/tests").splitlines()
files = sorted(set(changed+extra))
assert all(p.startswith("crates/benitoite/") or p.startswith("formal/tests/") or
           p == "docs/design/07-quality/07-04-formal-semantics.md" for p in files)
lean_diff = git("diff", "--name-only", B_WORK, "--", "formal/**/*.lean", "formal/lakefile.toml", "formal/lake-manifest.json", "formal/lean-toolchain")
assert not lean_diff
fingerprints = [fingerprint(ROOT/p) for p in files]
for pattern in ["f-local/*", "f-local-first/*", "*.log", "*.exit", "*.json", "*.py"]:
    for path in sorted(BASE.glob(pattern)):
        if path.is_file() and path.name != "inputs-and-tools.json": fingerprints.append(fingerprint(path))
for path in ["Cargo.lock", "fuzz/Cargo.lock", "rust-toolchain.toml", ".cargo/config.toml",
             "formal/lakefile.toml", "formal/lake-manifest.json", "formal/lean-toolchain",
             "formal/.lake/build/bin/desugarDiff", "formal/.lake/build/bin/builtinCheck",
             "formal/.lake/build/bin/surfaceCheckAll", "formal/.lake/build/bin/surfaceCheck"]:
    fingerprints.append(fingerprint(ROOT/path))
patch = subprocess.check_output(["git", "diff", "--binary", B_WORK, "--", *files])
record = {"B_WORK":B_WORK, "head":git("rev-parse", "HEAD"), "branch":git("branch", "--show-current"),
          "changed":files, "untracked":extra, "diff_sha256":hashlib.sha256(patch).hexdigest(), "lean_source_or_settings_diff":lean_diff,
          "rustc":subprocess.check_output(["rustc", "--version"], text=True).strip(),
          "cargo":subprocess.check_output(["cargo", "--version"], text=True).strip(),
          "limits":limits, "scopeAcceptance":item["scopeAcceptance"],
          "counts":{"inputs":1,"definitions":5,"prims":len(table["prims"]),"dataDecls":len(table["dataDecls"]),
                    "constructors":sum(len(d["ctors"]) for d in table["dataDecls"]),
                    "candidates":len(item["candidates"]),
                    "nonTopCandidates":sum(a.get("name",{}).get("ix",{}).get("fixed","top") != "top" for a in item["candidates"])},
          "files":fingerprints}
(BASE/"inputs-and-tools.json").write_text(json.dumps(record, ensure_ascii=False, indent=2)+"\n")
print(json.dumps({"status":"ok", "counts":record["counts"],"changedFiles":len(files),"evidenceFiles":len(fingerprints)}, ensure_ascii=False))
