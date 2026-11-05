"""群Dの変更範囲・既定import・読者・監査記録・保存記録を照合する。git は読み取りだけに使う。"""
import argparse
import ast
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess
from support import BASE, HERE, MODULES, NEW_MODULES, ROOT, closure, digest, write

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
args = parser.parse_args()


def read(file):
    return json.loads((HERE / file).read_text())


def git(*command):
    return subprocess.run(["git", *command], cwd=ROOT, check=True, capture_output=True).stdout


record_dir = str(HERE.relative_to(ROOT))
surface = "formal/Benitoite/Release/Refinement/ExternalSurfaceLeaves.lean"
selection = "formal/Benitoite/Release/Refinement/ExternalLeafSelection.lean"
root_import = "formal/Benitoite.lean"
spec = "docs/design/01-spec/01-12-core-calculus.md"
quality = "docs/design/07-quality/07-04-formal-semantics.md"
changed = set(git("diff", "--name-only", BASE).decode().split())
untracked = set(git("ls-files", "--others", "--exclude-standard").decode().split())
assert changed == {surface, root_import, spec, quality}, changed
# 取りまとめが置いた群Dの独立レビューの記録は、担当の変更の外として除く。
review = str((HERE.parents[1] / "reviews/RV-L60.d.md").relative_to(ROOT))
assert {f for f in untracked if not f.startswith(record_dir + "/")} - {review} == {selection}, untracked


def remove_between(text, start, end):
    i = text.index(start)
    j = text.index(end, i) + len(end)
    return text[:i] + text[j:]


# 追加箇所を取り除いた内容が基準の内容と一致することを確かめる。
restored = {}
s = (ROOT / root_import).read_text()
line = "import Benitoite.Release.Refinement.ExternalLeafSelection\n"
assert s.count(line) == 1
restored[root_import] = s.replace(line, "")
s = (ROOT / surface).read_text()
for line in ["import Benitoite.Release.Refinement.ExternalNominal\n",
             "import Benitoite.Release.Refinement.TelApplication\n", "import Benitoite.Surface.Lemmas.Calls\n"]:
    assert s.count(line) == 1
    s = s.replace(line, "")
start = s.index("\n/-- 行と範囲を置き換えない束縛")
restored[surface] = s[:start] + s[s.index("\nend Benitoite.Release.Refinement.ExternalSurface\n"):]
s = (ROOT / spec).read_text()
s = remove_between(s, "\n\n`ExternalSurface` の表層の葉は", "Leanの `Val.Source` は外部参照の値を拒否しない。")
s = remove_between(s, "\n\n`ExternalLeafSelection` の `StateTyE.external_args` は", "偽造の三境界の拒否を同じ表で示す。")
restored[spec] = s
s = (ROOT / quality).read_text()
s = remove_between(s, "表層の五つの接点（型IDの参照", "全表層の検査器への組込みはこれらの葉の結論に含めない。")
s = remove_between(s, "\n\n`ExternalLeafSelection` は、型付きの外部呼出しの開始から",
                   "全 progress・preservation・step_sound と逆方向の完全性はこれらの結論に含めない。")
s = s.replace("外部参照・直接呼出しの入力と表層の五つの接点の葉、", "外部参照・直接呼出しの入力、")
s = s.replace("・StoreReplyLeaves・ExternalLeafSelection | 「篩を含む状態の型付け」 |",
              "・StoreReplyLeaves | 「篩を含む状態の型付け」 |")
restored[quality] = s
for rel, text in restored.items():
    assert text.encode() == git("show", f"{BASE}:{rel}"), (rel, "追加箇所以外に差分")

modules = closure()
assert set(MODULES) <= set(modules)
write(HERE / "modules.json", {"count": len(modules), "requested": MODULES})
summary = read("audit-summary.json")
assert summary["modules"] == len(modules) and summary["new_axioms"] == summary["sorryAx"] == 0
assert all(set(k.split(" + ")) <= {"propext", "Quot.sound", "Classical.choice"}
           for k in summary["axiom_sets"] if k != "none")
rows = []
for part in summary["parts"]:
    assert digest(HERE / part["file"]) == {k: part[k] for k in ["bytes", "sha256"]}
    rows.extend(read(part["file"]))
assert len(rows) == len({r["name"] for r in rows}) == summary["declarations"]
for row in rows:
    assert hashlib.sha256(row["type"].encode()).hexdigest() == row["type_sha256"]
by_name = {r["name"]: r for r in rows}
inherited = set(read("inherited-declarations.json"))
assert inherited <= set(by_name)
assert {r["name"] for r in read("added-declarations.json")} == set(by_name) - inherited
assert digest(args.tmp / "axioms.log") == summary["raw"]

# 公開の名前付き宣言ごとに、名前付きの読者か既定ビルドで型検査した適用例を確かめる。
incoming = collections.defaultdict(set)
for row in rows:
    for dep in row["dependencies"]:
        if dep != row["name"]:
            incoming[dep].add(row["name"])
required = set(read("required-names.json"))
public = []
for module in MODULES:
    text = (ROOT / "formal" / (module.replace(".", "/") + ".lean")).read_text()
    assert not re.search(r"\b(sorry|axiom|native_decide)\b|#eval|set_option max(?:Heartbeats|RecDepth)|L60\.", text)
    examples = re.split(r"^example\b", text, flags=re.M)[1:]
    for name in sorted(r["name"] for r in rows if r["module"] == module and r["name"] in required):
        readers = sorted(incoming[name])
        tail = name.split(".")[-1]
        direct = any(re.search(r"(?<![\w])" + re.escape(tail) + r"(?![\w])", ex) for ex in examples)
        assert readers or direct, name
        public.append({"name": name, "named_readers": readers[:6], "named_reader_count": len(readers),
                       "compiled_example": direct})
write(HERE / "readers.json", public)

for f in HERE.glob("*.py"):
    ast.parse(f.read_text())
files = [f for f in HERE.rglob("*") if f.is_file() and "__pycache__" not in f.parts]
assert all(f.stat().st_size <= 100000 for f in files)
assert sum(f.stat().st_size for f in files) < 3000000
for f in files:
    if f.suffix in [".md", ".json", ".py", ".lean"]:
        text = f.read_text()
        assert "/" + "Users" + "/" not in text and not re.search(r"\]\([^)]*docs/todo", text), f.name
        if f.suffix == ".md":
            for target in re.findall(r"\]\(([^)]+)\)", text):
                if not re.match(r"https?://|#", target):
                    assert (f.parent / target.split("#")[0]).exists(), (f.name, target)
for rel, expected in read("tools.json")["inputs"].items():
    assert digest(ROOT / rel) == expected, (rel, "最終入力が変更された")
for name in ["default-build", "axioms"]:
    record = read(name + ".json")
    assert record["exit"] == 0 and record["raw"] == digest(args.tmp / (name + ".log"))
    if name == "default-build":
        assert record["cwd"] == "formal" and record["command"] == ["lake", "build"]
        raw = (args.tmp / (name + ".log")).read_text()
        assert "Build completed successfully" in raw
        for module in MODULES:
            assert not re.search(r"warning: [^\n]*" + re.escape(module.replace(".", "/")), raw), module

output = {"modules": len(modules), "requested_modules": MODULES, "new_modules": NEW_MODULES,
          "modified_existing": sorted(changed), "untracked_production": [selection],
          "public_entries": len(public), "named_readers": sum(bool(r["named_readers"]) for r in public),
          "compiled_examples": sum(r["compiled_example"] for r in public), "files": len(files),
          "record_bytes": sum(f.stat().st_size for f in files),
          "largest_bytes": max(f.stat().st_size for f in files),
          "axiom_targets": summary["targets"], "added_declarations": summary["added_declarations"]}
write(HERE / "verification.json", output)
print(json.dumps(output, ensure_ascii=False))
