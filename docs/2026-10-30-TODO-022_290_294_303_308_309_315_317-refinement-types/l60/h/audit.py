# -*- coding: utf-8 -*-
"""段の公理監査（../axioms.lean）の出力を照合し、段の全宣言の型のハッシュと実署名を保存する。

段で足した37モジュールと変えた既存の5モジュールの全宣言（private・生成宣言を含む）について、型の
SHA-256 を群A〜Gの記録の型と照合する。群Aの記録は型の文字列か型のハッシュ、群B〜Gは型のハッシュを持つ。
同じ名前を後の群が記録し直したときは後の群の記録を正とする。F01〜F08・旧主定理・後段の受け口の実署名と
主な定義の本体は signatures-NN.md・definitions.md に一回分だけ置く。
使い方: python3 audit.py --tmp <一時領域>（axioms.log を置く）"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess
import families
from support import EDITED, HERE, L60, L60_BASE, MODULES, NEW, PREFIX, ROOT, closure, digest, module_path, show, \
    write

GENERATED = r"\.(match_\d+|_sparseCasesOn_\d+|eq_\d+|eq_def|_unfold|proof_\d+|splitter|_simp_\d+_\d+|_f|" \
            r"_flat_ctor|_sizeOf_\d+|_sizeOf_inst|ctorElim|ctorElimType|elim|else_eq)$"

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
args = parser.parse_args()
raw = args.tmp / "axioms.log"
record = json.loads((HERE / "axioms.json").read_text())
assert record["exit"] == 0 and record["raw"] == digest(raw)
text = raw.read_text()
assert not re.search(r"error:|warning:|sorryAx|AUDIT_(MISSING|AXIOM|FIXED_POINT_LIMIT|REQUIRED_MISSING|MODULE_MISSING)",
                     text)
targets = re.findall(r"^AUDIT_TARGET (.+)$", text, re.M)
assert len(targets) == len(set(targets)) == int(re.search(r"^AUDIT_COUNT (\d+)$", text, re.M)[1])
axioms = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", text, re.M | re.S)
assert collections.Counter(n for n, _ in axioms) == collections.Counter(targets)
by_target = {n: tuple(sorted(x.strip() for x in ax.split(",") if x.strip())) for n, ax in axioms}
sets = collections.Counter(by_target.values())
assert all(set(x) <= {"propext", "Quot.sound", "Classical.choice"} for x in sets), sets
declarations = [{"module": m, "kind": k, "line": int(l) or None, "name": n}
                for m, k, l, n in re.findall(r"^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$", text, re.M)]
modules = {m: int(c) for m, c in re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", text, re.M)}
assert set(MODULES) <= set(modules) and set(modules) == set(closure()) and sum(modules.values()) == len(targets)
assert len(declarations) == len({r["name"] for r in declarations}) == sum(modules[m] for m in MODULES)
signatures = {n: typ.strip() for _, n, _, typ in
              re.findall(r"^SIGNATURE_BEGIN (\S+) (\S+) (\d+)\n(.*?)^SIGNATURE_END \2$", text, re.M | re.S)}
assert {r["name"] for r in declarations} <= set(signatures)
assert not any("⋯" in t for t in signatures.values())
required = json.loads((HERE / "required-names.json").read_text())
assert set(required) <= set(signatures) and set(required) <= set(targets)

# 群A〜Gの記録の型。後の群の記録を正とする。
recorded = {}
for group in ["a", "b", "c", "d", "e", "f1", "f2", "g"]:
    for part in sorted((L60 / group).glob("declarations-[0-9][0-9].json")):
        for row in json.loads(part.read_text()):
            if "type_sha256" in row:
                recorded[row["name"]] = (group, row["type_sha256"])
    for part in sorted((L60 / group).glob("signatures-[0-9][0-9].json")):
        for row in json.loads(part.read_text()):
            if row.get("type") is not None:
                recorded[row["name"]] = (group, hashlib.sha256(row["type"].strip().encode()).hexdigest())
            elif "type_sha256" in row:
                recorded[row["name"]] = (group, row["type_sha256"])
# 群Aの宣言の記録（名前だけ）にある名前。
named_in_a = set()
for part in sorted((L60 / "a").glob("declarations-[0-9][0-9].json")):
    named_in_a.update(r["name"] for r in json.loads(part.read_text()))


# 既存の5モジュールの宣言の、段の開始版との比較（edited.py の記録）。
edited = json.loads((HERE / "edited.json").read_text())
EDITED_STATE = {"新規": "既存のモジュールに段で足した宣言", "変更": "既存のモジュールで段に型が変わった宣言",
                "継承": "既存のモジュールの宣言（段の前から）"}
edited_state = {}
for change in edited["changes"]:
    if change["final_name"] is not None:
        edited_state[change["final_name"]] = EDITED_STATE[change["state"]]

# 段の各モジュールを変えた群（取り込みのコミットの件名の「(L60 group X)」から読む）。
ORDER = ["a", "b", "c", "d", "e", "f1", "f2", "g"]
touched = {}
for module in MODULES:
    rel = str(module_path(module).relative_to(ROOT))
    log = subprocess.run(["git", "-C", str(ROOT), "log", "--format=%s", L60_BASE + "..HEAD", "--", rel],
                         capture_output=True, text=True, check=True).stdout
    touched[module] = sorted({g.lower() for g in re.findall(r"\(L60 group (\w+)", log)}, key=ORDER.index)

rows, status = [], collections.Counter()
for row in declarations:
    typ = signatures[row["name"]]
    sha = hashlib.sha256(typ.encode()).hexdigest()
    generated = row["name"].startswith("_private.") is False and re.search(GENERATED, row["name"]) is not None
    group, recorded_sha = recorded.get(row["name"], (None, None))
    if row["module"] in EDITED:
        state = edited_state.get(row["name"], EDITED_STATE["継承"])
    elif recorded_sha is None and row["name"] in named_in_a:
        state = "群Aの名前の記録"
    elif recorded_sha is None and len(touched[row["module"]]) > 1:
        # 最初の群の後に別の群が同じモジュールへ足した宣言（その群の記録は新しいモジュールだけを持つ）。
        state = "記録の後の群が足した宣言"
    elif recorded_sha is None:
        state = "群の記録なし"
    elif recorded_sha == sha:
        state = "群の記録と一致"
    elif ORDER.index(touched[row["module"]][-1]) > ORDER.index(group):
        # 記録した群より後の群が同じモジュールを変えた（例: 組込みの行の構成子を足して再帰原理の型が変わる）。
        state = "記録の後の群が変えた宣言"
    else:
        state = "群の記録と差"
    status[state] += 1
    rows.append([row["name"], row["module"].removeprefix(PREFIX), row["kind"], row["line"], sha,
                 bool(generated), row["name"].startswith("_private."), group, state])
assert status["群の記録と差"] == status["群の記録なし"] == 0, \
    [r[0] for r in rows if r[8] in ("群の記録と差", "群の記録なし")][:5]

# 段の宣言（段の前からある既存のモジュールの宣言を除く）を、モジュールごとの行の列で保存する。
# 行は [接頭辞を除く名前, 種類, 行番号, 型のSHA-256, 生成, private, 記録した群, 照合の状態]。
STATES = sorted(set(EDITED_STATE.values()) - {"既存のモジュールの宣言（段の前から）"} | set(status) - {"既存のモジュールの宣言（段の前から）"})
stage_rows = [r for r in rows if r[8] != "既存のモジュールの宣言（段の前から）"]
parts, page, size = [], {}, 0


def flush():
    global page, size
    file = HERE / f"declarations-{len(parts) + 1:02}.json"
    data = "{\n" + ",\n".join(json.dumps(m, ensure_ascii=False) + ": [\n" + ",\n".join(
        json.dumps(r, ensure_ascii=False) for r in rs) + "]" for m, rs in page.items()) + "\n}\n"
    assert len(data.encode()) <= 100000
    file.write_text(data)
    parts.append({"file": file.name, **digest(file)})
    page, size = {}, 0


for r in stage_rows:
    row = [r[0].removeprefix(PREFIX), r[2], r[3], r[4], r[5], r[6], r[7], STATES.index(r[8])]
    cost = len(json.dumps(row, ensure_ascii=False).encode()) + 2
    if size + cost > 95000 and page:
        flush()
    page.setdefault(r[1], []).append(row)
    size += cost
flush()
for old in HERE.glob("declarations-[0-9][0-9].json"):
    if old.name not in {p["file"] for p in parts}:
        old.unlink()

# F01〜F08・旧主定理・後段の受け口の実署名と、主な定義の本体。
named = []
seen = set()
for title, group in (list(families.F_FAMILIES.items()) + [("旧主定理", list(families.OLD_MAIN))] +
                     list(families.C_FAMILIES.items()) + [(k, v) for k, v in families.HANDOFFS.items()]):
    for n in group:
        full = n if n.startswith("Benitoite.") else PREFIX + n
        if full not in seen:
            seen.add(full)
            named.append((title, full))
pages, lines = [], []
for title, full in named:
    block = [f"### `{full.removeprefix(PREFIX)}`（{title}）", "", "```lean", signatures[full], "```", ""]
    if len("\n".join(lines + block).encode()) > 90000 and lines:
        pages.append(lines)
        lines = []
    lines.extend(block)
pages.append(lines)
signature_files, signature_index = [], {}
for i, body in enumerate(pages, 1):
    file = HERE / f"signatures-{i:02}.md"
    head = [f"# 段末の実署名（{i}/{len(pages)}）", "",
            "生成物（[audit.py](audit.py)）。段の公理監査（[../axioms.lean](../axioms.lean)）の型の印字であり、"
            "接頭辞 `Benitoite.Release.Refinement.` を見出しでだけ省く。", ""]
    file.write_text("\n".join(head + body) + "\n")
    assert file.stat().st_size <= 100000
    signature_index.update({full: file.name for full in re.findall(r"^### `([^`]+)`", "\n".join(body), re.M)})
    signature_files.append({"file": file.name, **digest(file)})
definitions = re.findall(r"^DEFINITION_BEGIN (\S+)\n(.*?)^DEFINITION_END \1$", text, re.M | re.S)
assert len(definitions) == 17
body = ["# 段末の主な定義の本体", "", "生成物（[audit.py](audit.py)）。`#print` の出力。", ""]
for name, value in definitions:
    body += [f"## `{name.removeprefix(PREFIX)}`", "", "```lean", value.strip(), "```", ""]
(HERE / "definitions.md").write_text("\n".join(body) + "\n")
assert (HERE / "definitions.md").stat().st_size <= 100000

target_file = args.tmp / "targets.txt"
target_file.write_text("\n".join(targets) + "\n")
kinds = collections.Counter(r[2] for r in rows)
summary = {
    "targets": len(targets), "target_list": digest(target_file), "raw": digest(raw), "modules": len(modules),
    "stage_modules": {m.removeprefix(PREFIX): modules[m] for m in MODULES},
    "declarations": len(rows), "stage_declarations": len(stage_rows), "states": STATES,
    "row_fields": ["名前", "種類", "行番号", "型のSHA-256", "生成", "private", "記録した群", "照合の状態（statesの番号）"],
    "new_module_declarations": sum(modules[m] for m in NEW),
    "edited_module_declarations": sum(modules[m] for m in EDITED),
    "edited_comparison": {"record": digest(HERE / "edited.json"), "counts": edited["counts"],
                          "removed": [c["module"] + ":" + ("private " if c["private"] else "") + c["name"].removeprefix(PREFIX)
                                      for c in edited["changes"] if c["state"] == "削除"]},
    "by_kind": dict(sorted(kinds.items())), "private": sum(r[6] for r in rows), "generated": sum(r[5] for r in rows),
    "without_source_position": sum(r[3] is None for r in rows),
    "record_status": dict(sorted(status.items())),
    "changed_after_record": [r[0].removeprefix(PREFIX) for r in rows if r[8] == "記録の後の群が変えた宣言"],
    "touched_by_groups": {m.removeprefix(PREFIX): v for m, v in touched.items()},
    "closure_rounds": int(re.search(r"^AUDIT_ROUNDS (\d+)$", text, re.M)[1]),
    "axiom_sets": {" + ".join(k) or "none": v for k, v in sorted(sets.items())},
    "stage_by_kind": dict(sorted(collections.Counter(r[2] for r in stage_rows).items())),
    "stage_private": sum(r[6] for r in stage_rows), "stage_generated": sum(r[5] for r in stage_rows),
    "stage_named": sum(not r[5] and not r[6] for r in stage_rows),
    "stage_axiom_sets": {" + ".join(k) or "none": v for k, v in
                         sorted(collections.Counter(by_target[r[0]] for r in stage_rows).items())},
    "required": len(required), "sorryAx": 0, "new_axioms": 0, "parts": parts, "signatures": signature_files,
    "definitions": digest(HERE / "definitions.md"), "signature_index": signature_index,
    "inputs": {"axioms.lean": digest(L60 / "axioms.lean"), "audit.py": digest(Path(__file__))}}
write(HERE / "audit-summary.json", summary)
print(json.dumps({k: summary[k] for k in ["targets", "modules", "declarations", "by_kind", "private", "generated",
                                          "record_status", "axiom_sets"]}, ensure_ascii=False))
