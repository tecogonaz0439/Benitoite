# -*- coding: utf-8 -*-
"""全宣言の監査・既定import・308言明と群Eの差・変更範囲・検査入力を照合する。"""
import argparse
import collections
import hashlib
import json
import re
from pathlib import Path
from inventory import (HERE, ROOT, CHANGE, TOOLS, code_only, digest, fingerprint,
                       save, sources, changed_paths, reachable, signatures, statements)

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
args = parser.parse_args()
tmp = args.tmp
assert TOOLS["signature_selftest"]() == 8
_, _, changed, added = changed_paths(tmp)
modules = sorted(p[7:-5].replace("/", ".") for p in changed + added
                 if p.startswith("formal/") and p.endswith(".lean"))
assert modules == json.loads((HERE / "audit-modules.json").read_text())
assert set(modules) <= reachable(), "追加・変更モジュールが既定importから到達できない"
copy = (ROOT / "docs/design/07-quality/07-04-formal-semantics.md").read_text()
for path in added:
    if path.startswith("formal/") and path.endswith(".lean"):
        module = path[7:-5].replace("/", ".")
        assert module.removeprefix("Benitoite.Release.Refinement.") in copy, ("新モジュールの対応の写しの不足", module)
old_root = (tmp / "baseline-root.lean").read_text().splitlines()
new_root = (ROOT / "formal/Benitoite.lean").read_text().splitlines()
assert all(line in new_root for line in old_root), "根の既存importの除外"
assert len([x for x in new_root if x.startswith("import ")]) == len(set(x for x in new_root if x.startswith("import ")))
for p, h in json.loads((tmp / "protected-records.json").read_text()).items():
    assert digest(ROOT / p) == h, ("対象外の改造文書の変更", p)
for p in changed + added:
    if not p.endswith(".lean"):
        continue
    code = code_only((ROOT / p).read_text())
    assert not re.search(r"\b(?:sorry|axiom|native_decide)\b|#eval", code), ("禁止した証明又は評価", p)
    assert not re.search(r"(?:L[0-9]{2}|I\.[1-5]|RV-L70)", (ROOT / p).read_text()), ("本番の工程ID", p)

# 群Dの固定した308件と、前段の266件を別々に全件照合する。
d_baseline = json.loads((HERE.parent / "d/resume7-signatures.json").read_text())
assert sum(map(len, d_baseline.values())) == 308
ledger = json.loads((HERE.parent / "k-int/theorem-signatures.json").read_text())
assert sum(map(len, ledger.values())) == 266
expected = json.loads((HERE.parent / "d/resume7-signature-differences.json").read_text())
actual = {}
for p, rows in d_baseline.items():
    current = signatures((ROOT / p).read_text())
    for name, old in rows.items():
        assert name in current, ("台帳の言明の削除", p, name)
        if current[name] != old:
            actual.setdefault(p, {})[name] = dict(before=old, after=current[name])
assert actual == expected, ("308件の許可済み二差以外の変更", actual)
for p, rows in ledger.items():
    for name, h in rows.items():
        assert d_baseline[p][name] == h

diffs, current = statements(tmp)
assert diffs == json.loads((tmp / "statement-differences.json").read_text()), "記録後の言明の変更"
# 群Eの全既存言明を比較し、名前の欠落を個別に報告する。
e_paths = {p: rows for p, rows in json.loads((tmp / "baseline-signatures.json").read_text()).items()
           if Path(p).stem.startswith("Check")}
e_count = sum(map(len, e_paths.values()))
e_changed = {p: d for p, d in diffs.items() if Path(p).stem.startswith("Check")}
for p, rows in e_paths.items():
    assert set(rows) <= set(current.get(p, {})), ("群Eの既存言明の削除", p, sorted(set(rows)-set(current.get(p, {}))))

# 通常の95場合は名前と順序を保ち、空範囲の包含のclosedだけを追加する。
def constructors(path):
    code = code_only(path.read_text())
    decls = list(re.finditer(r"\binductive\s+(\w+)\s", code))
    result = {}
    for i, match in enumerate(decls):
        end = decls[i + 1].start() if i + 1 < len(decls) else len(code)
        result[match[1]] = re.findall(r"(?m)^\s*\|\s*(\w+)\s*(?:\{|:)", code[match.end():end])
    return result
prefix = ROOT / "formal/Benitoite/Release/Refinement/Surface"
regular, opened = constructors(prefix / "Rules.lean"), constructors(prefix / "OpenSurface.lean")
for name in ["HasTypeQ", "HasTypesQ", "HasEachQ", "HasFixedQ", "HasArmsQ", "HasClausesQ", "HasBlockQ"]:
    assert regular[name] == [x for x in opened[name] if not (name == "HasClausesQ" and x == "closed")], name
assert opened["BodyTy"] == ["done", "param"]
lookup_rows = re.findall(r"(?m)^private theorem lookup_(p\d+) : primitive ",
    (ROOT / "formal/Benitoite/Release/Refinement/StandardModelPrimitiveLookup.lean").read_text())
assert len(lookup_rows) == len(set(lookup_rows)) == 377

for group in [HERE, HERE.parent / "d"]:
    files = [p for p in group.rglob("*") if p.is_file() and "__pycache__" not in p.parts]
    assert all(p.stat().st_size <= 100_000 for p in files), "記録ファイルが100KBを超える"
    assert sum(p.stat().st_size for p in files) < 3_000_000, "群の記録が3MBを超える"
for p in HERE.rglob("*"):
    if p.is_file() and p.suffix in [".md", ".py", ".lean", ".json"]:
        content = p.read_text()
        assert "/Us" + "ers/" not in content and "/priv" + "ate/tmp" not in content, p
        assert not re.search(r"\]\([^)]*docs/todo", content), p

checks = {kind: json.loads((HERE / (kind + "-summary.json")).read_text()) for kind in ["build", "axioms"]}
for kind, record in checks.items():
    log = tmp / (kind + ".log")
    assert record["exit_code"] == 0 and record["same_inputs"]
    assert record["bytes"] == log.stat().st_size and record["sha256"] == digest(log)
    assert record["fingerprint"] == record["after_fingerprint"] == fingerprint(sources())
    assert re.search(r"^rc=0$", log.read_text(), re.M)
build = (tmp / "build.log").read_text()
assert "error:" not in build
for m in modules:
    assert not any("warning:" in line and m.replace(".", "/") + ".lean:" in line for line in build.splitlines()), m
jobs = int(re.search(r"Build completed successfully \((\d+) jobs\)", build)[1])
audit = (tmp / "axioms.log").read_text()
assert not re.search(r"error:|sorryAx|AUDIT_(MISSING|AXIOM|FIXED_POINT_LIMIT|REQUIRED_MISSING|MODULE_MISSING)", audit)
targets = re.findall(r"^AUDIT_TARGET (.+)$", audit, re.M)
assert len(targets) == len(set(targets)) == int(re.search(r"^AUDIT_COUNT (\d+)$", audit, re.M)[1])
axioms = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", audit, re.M | re.S)
assert collections.Counter(n for n, _ in axioms) == collections.Counter(targets)
sets = collections.Counter(tuple(sorted(x.strip() for x in a.split(",") if x.strip())) for _, a in axioms)
assert all(set(s) <= {"propext", "Classical.choice", "Quot.sound"} for s in sets)
per_module = dict((m, int(c)) for m, c in re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", audit, re.M))
assert set(modules) <= set(per_module) and sum(per_module.values()) == len(targets)
owned_module = dict((m, int(c)) for m, c in re.findall(r"^OWN_MODULE (\S+) (\d+)$", audit, re.M))
assert sorted(owned_module) == modules
owned_names = {n for m, _, _, n in re.findall(r"^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$", audit, re.M) if m in owned_module}
assert sum(owned_module.values()) == len(owned_names)
decls = re.findall(r"^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$", audit, re.M)
assert len(decls) == len(targets)
assert set(json.loads((HERE / "required-names.json").read_text())) <= set(targets)
names = ("\n".join(sorted(targets)) + "\n").encode()
summary = dict(b_work="601a52cae1ffc9bbef9be71e3b56c83f0afdfa4d", changed=changed, added=added,
               modules=len(modules), default_imports=True, d_statements=308, d_unchanged=306,
               d_approved_differences=2, earlier_ledger=266, e_statements=e_count,
               e_changed=sum(len(x["changed"]) for x in e_changed.values()),
               declarations=len(targets), private=sum(x.startswith("_private.") for x in targets),
               names_bytes=len(names), names_sha256=hashlib.sha256(names).hexdigest(),
               environment_modules=len(per_module), environment_modules_sha256=fingerprint(per_module),
               owned_declarations=len(owned_names), owned_private=sum(x.startswith("_private.") for x in owned_names),
               per_module=owned_module, axiom_sets={",".join(k) or "(none)":v for k,v in sorted(sets.items())},
               jobs=jobs, primitive_rows=len(lookup_rows), fingerprint=fingerprint(sources()))
save(HERE / "verification.json", summary)
print(json.dumps({k:v for k,v in summary.items() if k not in ["changed", "added", "per_module"]}, ensure_ascii=False, indent=1))
