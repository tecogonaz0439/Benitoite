# -*- coding: utf-8 -*-
"""旧判断・旧主定理・旧表層・交換の読者と、7入口の経路、削除の集合を既定環境の依存の書き出しから求める。

入力:
- `formal/` の全 Lean ファイルの import 行（モジュールの依存）。
- graph.lean の出力（宣言ごとの型と値に現れる定数。生の記録は一時領域）。
- l00a.06a/contracts.md の完全名の対照表（旧の完全名と新しい完全名の組）。

出力: inventory.json（件数と一覧）。生の記録は大きさと SHA-256 だけを残す。
使い方: python3 inventory.py --tmp <一時領域>（graph.log を置く）
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
FORMAL = ROOT / "formal"
CHANGE = HERE.parents[1]
R = "Benitoite.Release.Refinement"

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
args = parser.parse_args()

# 7入口（lakefile の既定 targets の lean_exe）と根のモジュール。
ENTRIES = {
    "desugarDiff": "DesugarDiff.Main", "builtinCheck": "BuiltinCheck.Main",
    "coverageDiff": "CoverageDiff.Main", "coverageProgramDiff": "CoverageProgramDiff.Main",
    "surfaceCheck": "SurfaceCheck.Main", "surfaceCheckAll": "SurfaceCheck.All",
    "intervalDiff": "IntervalDiff.Main",
}
lakefile = (FORMAL / "lakefile.toml").read_text()
targets = re.search(r'defaultTargets = \[(.*?)\]', lakefile).group(1)
assert sorted(t.strip(' "') for t in targets.split(",")) == sorted(["Benitoite", *ENTRIES]), targets
for exe, root in ENTRIES.items():
    assert re.search(rf'name = "{exe}"\nroot = "{re.escape(root)}"', lakefile), exe

# 1. モジュールの依存。
mods = {}
for p in sorted(FORMAL.rglob("*.lean")):
    rel = p.relative_to(FORMAL)
    if rel.parts[0] in (".lake", "tests"):
        continue
    name = ".".join(rel.with_suffix("").parts)
    mods[name] = [m.group(1) for m in re.finditer(r"^import\s+(\S+)", p.read_text(), re.M)]
lines = {m: (FORMAL / (m.replace(".", "/") + ".lean")).read_text().count("\n") for m in mods}


def group(m):
    if m.startswith(R + ".") or m == R:
        return "Refinement"
    if m.startswith("Benitoite.Release."):
        return "Release"
    for g in ["Core", "Surface", "Exchange", "Interval", "Scope", "Checked", "Shared", "Library"]:
        if m.startswith("Benitoite." + g + "."):
            return g
    if m == "Benitoite":
        return "root"
    return "entry" if m in mods else "lean"


def closure(roots):
    seen, stack = set(), list(roots)
    while stack:
        m = stack.pop()
        if m in seen or m not in mods:
            continue
        seen.add(m)
        stack.extend(mods[m])
    return seen


default = closure(["Benitoite"])
outside_default = sorted(m for m in mods if m.startswith("Benitoite.") and m not in default)

# 2. 宣言の依存。
graph = args.tmp / "graph.log"
nodes = {}
decl_line = {}
for line in graph.open():
    i = line.find("NODE ")
    if i < 0:
        continue
    n, mod, kind, ln, td, vd = json.loads(line[i + 5:])
    nodes[n] = (mod, kind, set(td) | set(vd))
    decl_line[n] = ln
decl_group = {n: group(v[0]) for n, v in nodes.items()}
OLD = {"Release", "Surface", "Core"}

# 3. 旧の判断（L00a.06a の対照表の旧の完全名のうち旧 Release の帰納的な判断と関数）と旧主定理。
contracts = (CHANGE / "l00a.06a/contracts.md").read_text()
pairs = []
for row in contracts.splitlines():
    cells = [c.strip() for c in row.split("|")]
    if len(cells) < 4 or not cells[1].startswith("`Benitoite.Release."):
        continue
    old = re.findall(r"`(Benitoite\.Release\.[^`]+)`", cells[1])
    new = re.findall(r"`(Benitoite\.Release\.Refinement\.[^`]+)`", cells[2])
    for o in old:
        if not o.startswith(R):
            pairs.append((o, new))
table = []
for o, new in pairs:
    table.append({"old": o, "old_present": o in nodes, "new": new,
                  "new_present": [n in nodes for n in new]})
judgments = sorted({o for o, _ in pairs if o in nodes})
release_theorems = sorted(n for n, v in nodes.items() if v[0] == "Benitoite.Release.Theorems" and v[1] == "theorem")
model_theorems = ["Benitoite.Release.Model.assumptions", "Benitoite.Release.ModelTargets.assumptions",
                  "Benitoite.Release.ModelHttp.assumptions", "Benitoite.Release.step_target_sound"]
surface_theorems = sorted(n for n, v in nodes.items()
                          if v[0] in ("Benitoite.Surface.Theorems", "Benitoite.Surface.CheckProgramSound") and v[1] == "theorem"
                          and not n.split(".")[-1].startswith("eq_") and not n.startswith("_private"))
old_main = release_theorems + model_theorems
assert all(n in nodes for n in old_main), [n for n in old_main if n not in nodes]
assert len(release_theorems) == 8, release_theorems  # step_target_sound は Lemmas.TargetStep にある


def readers(targets, exclude_groups):
    out = collections.defaultdict(set)
    tset = set(targets)
    for n, (mod, kind, deps) in nodes.items():
        if decl_group[n] in exclude_groups:
            continue
        hit = deps & tset
        if hit:
            out[mod] |= hit
    return {m: sorted(s) for m, s in sorted(out.items())}


judgment_readers = readers(judgments, OLD)
main_readers = readers(old_main + surface_theorems, OLD)

# 4. 埋め込み（C05）の定理群と、その旧 Release の閉包。
C05 = ["embedDefWellTyped", "embedImplWellTyped", "embedProgramWellTyped", "embedProgramWellFormed",
       "embedStateTyE", "embedContTy", "embedStoreOk"]
c05_names = [R + "." + n for n in C05]
assert all(n in nodes for n in c05_names)
c05_modules = sorted({nodes[n][0] for n in c05_names})
c05_closure = closure(c05_modules)


def decl_closure(roots):
    seen, stack = set(), list(roots)
    while stack:
        n = stack.pop()
        if n in seen or n not in nodes:
            continue
        seen.add(n)
        stack.extend(nodes[n][2])
    return seen


c05_decls = decl_closure(c05_names)
c05_old_modules = sorted({nodes[n][0] for n in c05_decls if decl_group[n] == "Release"})

# 5. 7入口の経路。
LAYERS = ["Exchange", "Interval", "Surface", "Release", "Core"]
entry_paths = {}
for exe, root in ENTRIES.items():
    cl = closure([root])
    by = collections.Counter(group(m) for m in cl)
    direct = sorted({nodes[n][0] for n, v in nodes.items() if v[0] in cl and group(v[0]) == "entry"} | {root})
    entry_paths[exe] = {"root": root, "modules": len(cl), "by_group": dict(sorted(by.items())),
                        "direct_imports": mods[root],
                        "layers": sorted(m for m in cl if group(m) in ("Exchange", "Interval")) +
                        sorted(m for m in cl if m in ("Benitoite.Surface.CheckTables", "Benitoite.Surface.CheckTablesSound",
                                                      "Benitoite.Surface.CheckAccept", "Benitoite.Surface.Check",
                                                      "Benitoite.Release.CoverageShow", "Benitoite.Release.Coverage"))}

# 入口のモジュールが直接呼ぶ旧の名前（入口のソースの完全名の参照。宣言の書き出しは入口の olean を読まないので文字で数える）。
entry_refs = {}
for root in sorted(set(ENTRIES.values()) | {"SurfaceCheck.Batch", "SurfaceCheck.Validation", "SurfaceCheck.Walk"}):
    text = (FORMAL / (root.replace(".", "/") + ".lean")).read_text()
    entry_refs[root] = sorted(set(re.findall(r"Benitoite\.(?:Surface|Release|Exchange|Interval)\.[A-Za-z0-9_.]+[A-Za-z0-9_]", text)))

# 6. 層の分類（交換・区間の各モジュールと、7入口が読む旧表層・旧 Release の層）。
JSET = set(judgments)
SURF_SYNTAX = {"Benitoite.Surface.Syntax"}
def classify(m):
    deps = set()
    for n, (mod, kind, ds) in nodes.items():
        if mod == m:
            deps |= ds
    old_mods = collections.Counter(nodes[d][0] for d in deps if d in nodes and decl_group[d] in OLD)
    reads_judgment = any(d in JSET for d in deps) or any(
        group(om) == "Surface" and om not in SURF_SYNTAX for om in old_mods)
    reads_surface_syntax = any(om in SURF_SYNTAX for om in old_mods)
    reads_release = any(group(om) == "Release" for om in old_mods)
    if group(m) in ("Surface", "Core"):
        kind = "削除（旧表層・Core そのもの）"
    elif reads_judgment:
        kind = "移植（旧の判断・旧表層の検査を読む）"
    elif reads_surface_syntax:
        kind = "移植（旧表層の構文を読む。判断は読まない）"
    elif reads_release:
        kind = "継承（旧 Release の共有の定義だけを読む）"
    else:
        kind = "継承（旧を読まない）"
    return kind, dict(old_mods.most_common())

layer_modules = sorted(m for m in default if group(m) in ("Exchange", "Interval"))
layer_modules += ["Benitoite.Surface.CheckTables", "Benitoite.Surface.CheckTablesSound",
                  "Benitoite.Surface.CheckAccept", "Benitoite.Release.CoverageShow"]
UNIT = {"Benitoite.Exchange.Convert": "L70.40a", "Benitoite.Exchange.Syntax": "L70.40a",
        "Benitoite.Exchange.Version": "L70.42・.44（旧版の読み分けを除く）",
        "Benitoite.Exchange.CheckInput": "L70.40b", "Benitoite.Exchange.Builtins": "L70.40b",
        "Benitoite.Exchange.Observe": "L70.40b", "Benitoite.Surface.CheckTables": "L70.40b",
        "Benitoite.Surface.CheckTablesSound": "L70.40b", "Benitoite.Release.CoverageShow": "L70.40b",
        "Benitoite.Surface.CheckAccept": "L70.31b", "Benitoite.Exchange.Range": "L70.40a"}
layers = {}
for m in layer_modules:
    kind, old_mods = classify(m)
    unit = UNIT.get(m)
    if unit is None:
        unit = "L70.43" if group(m) == "Interval" else ("L70.40a・.40b（例）" if "Examples" in m else "L70.40b")
    layers[m] = {"kind": kind, "unit": unit, "lines": lines.get(m, 0), "old_modules": old_mods}

# 7. 新判断のうち旧表層を読むもの（旧表層の削除の前に移す）。
refinement_surface = collections.defaultdict(set)
refinement_release_models = collections.defaultdict(set)
for n, (mod, kind, deps) in nodes.items():
    if decl_group[n] != "Refinement":
        continue
    for d in deps:
        if d in nodes and decl_group[d] == "Surface":
            refinement_surface[mod].add(d)
        if d in nodes and nodes[d][0] in ("Benitoite.Release.Model", "Benitoite.Release.ModelHttp",
                                          "Benitoite.Release.ModelTargets", "Benitoite.Release.Examples",
                                          "Benitoite.Release.Theorems", "Benitoite.Release.Lemmas.TargetStep"):
            refinement_release_models[mod].add(nodes[d][0])

# 8. 削除の集合と残す旧 Release。
# 残す側の根: 新判断・Scope・Checked・Shared・Library と、移植する交換・区間の全宣言。旧主定理と旧表層の主定理を
# 読む宣言は .44 で除くので根にしない。閉包は宣言の依存で辿り、旧表層・Core の宣言と旧主定理の先へは進まない
# （旧表層は新しい表層へ移植し、Core は削除する）。Lean の外の名前の生成宣言（List.lookup.eq_2 など、最初に
# 必要としたモジュールに属する）は旧 Release の所属に数えない。
STOP = set(old_main) | set(surface_theorems)
def bnt(n):
    return n.startswith("Benitoite.") or n.startswith("_private.Benitoite.")
kept_roots = [n for n, g in decl_group.items()
              if g in ("Refinement", "Scope", "Checked", "Shared", "Library", "Exchange", "Interval")
              and not (nodes[n][2] & STOP)]
seen, stack = set(), list(kept_roots)
while stack:
    n = stack.pop()
    if n in seen or n not in nodes:
        continue
    seen.add(n)
    if decl_group[n] in ("Surface", "Core") or n in STOP:
        continue
    stack.extend(nodes[n][2])
kept_decls = seen
needed_release = sorted({nodes[n][0] for n in kept_decls if decl_group[n] == "Release" and bnt(n)})
needed_surface = sorted({nodes[n][0] for n in kept_decls if decl_group[n] == "Surface" and bnt(n)})
release_all = sorted(m for m in default if group(m) == "Release")
c05_set = set(c05_old_modules)
keep_release = sorted(set(needed_release) | c05_set)
delete_release = sorted(set(release_all) - set(keep_release))
shared_by = collections.defaultdict(set)
for n in kept_decls:
    if decl_group[n] in ("Refinement", "Scope", "Checked", "Shared", "Library", "Exchange", "Interval"):
        for d in nodes[n][2]:
            if d in nodes and decl_group[d] == "Release" and bnt(d):
                shared_by[nodes[d][0]].add(decl_group[n])
keep_roles = {}
for m in keep_release:
    roles = []
    if m in c05_set:
        roles.append("埋め込みの定義域（C05 の閉包）")
    if shared_by.get(m):
        roles.append("直接の読者: " + "・".join(sorted(shared_by[m])))
    if not roles:
        roles.append("閉包の内側（旧 Release どうしの依存）")
    keep_roles[m] = roles
# 削除するモジュールを import する残すモジュール（.44 で import を除く辺）。
deleted = set(delete_release) | {m for m in default if group(m) in ("Surface", "Core")}
import_cuts = sorted(f"{m} -> {i}" for m in default if m not in deleted and m != "Benitoite"
                     for i in mods[m] if i in deleted)
# 削除する旧主定理の名前と、その読者（.44 で読者も除く）。
old_name_readers = {n: sorted({nodes[r][0] for r, v in nodes.items() if n in v[2] and decl_group[r] not in OLD})
                    for n in old_main + surface_theorems}
old_name_readers = {n: v for n, v in old_name_readers.items() if v}
# 旧の判断（判断の本体）を、埋め込みでない新判断の宣言が読む箇所（F09 の逆戻りの照合の現状）。
PROPER = [o for o in judgments if o.split("Benitoite.Release.")[1] in (
    "Admissible", "AltsTy", "BuiltinOnly", "CellOk", "ClosedTy", "ContTy", "Def.WellTyped", "Eff.Covers",
    "Eff.Sub", "Exhaustive", "HasFailureClause", "HasTypeArms", "HasTypeArmsQ", "HasTypeC", "HasTypeCL",
    "HasTypeCQ", "HasTypeClauses", "HasTypeClausesQ", "HasTypeEach", "HasTypeEachQ", "HasTypeV", "HasTypeVQ",
    "HasTypeVs", "HasTypeVsQ", "ImplDecl.WellTyped", "Inhabits", "InhabitsAll", "InhabitsEach",
    "LocalRef.HasKind", "LocalSubstOk", "MethodRowsAdmissible", "PrimitiveAdmissible", "Program.WellTyped",
    "StateTy", "StateTyE", "Step", "Steps", "StoreOk", "SubstOk", "Ty.Le", "step")]
def embedding(n):
    parts = n.split(".")
    return any(p.startswith("embed") or p.startswith("Legacy") for p in parts) or \
        nodes[n][0].split(".")[-1].startswith("Legacy") or nodes[n][0].endswith(".Embedding")
backflow = collections.defaultdict(set)
for n, (mod, kind, deps) in nodes.items():
    if decl_group[n] == "Refinement" and not embedding(n):
        for d in deps & set(PROPER):
            backflow[mod].add(n.split(R + ".")[-1] + " -> " + d)
backflow = {m: sorted(s) for m, s in sorted(backflow.items())}

delete = {
    "Core": sorted(m for m in default if group(m) == "Core"),
    "Surface": sorted(m for m in default if group(m) == "Surface"),
    "Release": delete_release,
}
# 代案: 旧 Release のモジュールの import を変えない場合に残る閉包（残す旧 Release の import の閉包）。
keep_closure = sorted(closure(keep_release) & set(release_all))
conservative = {"keep": len(keep_closure), "delete": sorted(set(release_all) - set(keep_closure)),
                "extra_keep": sorted(set(keep_closure) - set(keep_release))}

# 9. admit の名前（TODO-294）。
admit = sorted(n for n in nodes if n.split(".")[-1] == "admit")
admit_text = []
for p in sorted(FORMAL.rglob("*.lean")):
    if ".lake" in p.parts:
        continue
    for i, line in enumerate(p.read_text().splitlines(), 1):
        if re.search(r"\badmit\b", line):
            admit_text.append(f"{p.relative_to(ROOT)}:{i}")
design_admit = []
for d in ["docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md"]:
    for i, line in enumerate((ROOT / d).read_text().splitlines(), 1):
        if re.search(r"\badmit\b", line):
            design_admit.append(f"{d}:{i}")

# 10. 残すモジュールの全宣言を閉包に入れた削除の集合（不動点）。
# 残すモジュール: 新判断・Scope・Checked・Shared・Library・交換・区間の全モジュールと、区間解析の入力の構文として
# 残す旧 Surface の構文（`Surface.Syntax` とその旧 Surface の import の閉包）。残すモジュールの宣言が使う旧 Release の
# 宣言の所属モジュールを、削除先への依存がなくなるまで残す側へ加える。旧主定理（旧 Release の9件・旧三モデルの3件）と
# 旧表層の主定理は残さない（FORBIDDEN）。それを推移的に読む残す側の宣言は「変える宣言」として閉包から外す。
# 旧 Surface の構文以外・Core への依存は「読者の移植」として数える（削除の集合を広げない）。
SURFACE_SYNTAX = sorted(m for m in closure(["Benitoite.Surface.Syntax"]) if group(m) == "Surface")
FORBIDDEN = set(old_main) | set(surface_theorems)
by_module = collections.defaultdict(list)
for n, (mod, kind, deps) in nodes.items():
    if bnt(n):
        by_module[mod].append(n)


def fixpoint_of(surface_kept):
    K = {m for m in default if group(m) in ("Refinement", "Scope", "Checked", "Shared", "Library", "Exchange", "Interval")}
    K |= set(surface_kept)
    rounds = 0
    while True:
        rounds += 1
        inside = [n for m in K for n in by_module[m]]
        must_change = {n for n in inside if n not in FORBIDDEN and nodes[n][2] & FORBIDDEN}
        grew = True
        while grew:
            grew = False
            for n in inside:
                if n not in must_change and n not in FORBIDDEN and nodes[n][2] & must_change:
                    must_change.add(n); grew = True
        new = set()
        port = collections.defaultdict(set)
        for n in inside:
            if n in must_change or n in FORBIDDEN:
                continue
            for d in nodes[n][2]:
                if d in nodes and bnt(d) and nodes[d][0] not in K:
                    g = decl_group[d]
                    if g == "Release":
                        new.add(nodes[d][0])
                    elif g in ("Surface", "Core"):
                        port[nodes[n][0]].add(nodes[d][0])
        if not new:
            break
        K |= new
    keep = sorted(m for m in K if group(m) == "Release")
    delete = sorted(m for m in release_all if m not in K)
    deleted = set(delete) | {m for m in default if group(m) == "Core"} | \
        {m for m in default if group(m) == "Surface" and m not in surface_kept}
    return {
        "rounds": rounds, "surface_syntax_kept": list(surface_kept),
        "keep_release": keep, "delete_release": delete,
        "delete_release_lines": sum(lines[m] for m in delete),
        "forbidden_in_kept_modules": sorted(n for n in FORBIDDEN if n in nodes and nodes[n][0] in K),
        "change_release_declarations": sorted(n for n in must_change if decl_group[n] == "Release"),
        "change_other_declarations": sorted(n for n in must_change if decl_group[n] != "Release"),
        "port_edges": {m: sorted(x) for m, x in sorted(port.items())},
        "import_cuts": sorted(f"{m} -> {i}" for m in K for i in mods.get(m, []) if i in deleted),
    }


fixpoint = fixpoint_of(SURFACE_SYNTAX)
without_syntax = fixpoint_of([])
fixpoint["kept_only_for_surface_syntax"] = sorted(set(fixpoint["keep_release"]) - set(without_syntax["keep_release"]))

# 11. 埋め込みを経ない旧判断への推移的な依存（F09 の条件2）。旧判断の本体の41件へ、埋め込みの宣言を通らずに
# 辿れる宣言を逆向きの到達で求め、新判断の宣言のうちそれに当たるものを、最短の経路の例とともに記す。
reverse = collections.defaultdict(set)
for n, (mod, kind, deps) in nodes.items():
    for d in deps:
        reverse[d].add(n)
bad, stack = set(PROPER), list(PROPER)
while stack:
    d = stack.pop()
    for r in reverse[d]:
        if r not in bad and not (decl_group[r] == "Refinement" and embedding(r)):
            bad.add(r); stack.append(r)
bad_new = sorted(n for n in bad if decl_group[n] == "Refinement" and bnt(n))
def path_to_judgment(start):
    prev, queue, seen = {start: None}, [start], {start}
    while queue:
        n = queue.pop(0)
        if n in PROPER:
            out = [n]
            while prev[out[-1]] is not None:
                out.append(prev[out[-1]])
            return list(reversed(out))
        for d in sorted(nodes[n][2]):
            if d in bad and d not in seen:
                seen.add(d); prev[d] = n; queue.append(d)
    return []
backflow_transitive = {n: path_to_judgment(n) for n in bad_new}

# 12. 宣言のグラフに現れない構文の中の削除対象への参照（RV-L70.a 再重1 の処置で足した）。
# 残すモジュールのソースを走査し、匿名の example・open・export・attribute・#check などの中の識別子を、現在の名前空間と
# ファイルの open で解決して、削除対象（削除するモジュールの宣言と、残すモジュールから除く宣言）に当たるものを列挙する。
# 名前空間の open は、その名前空間の宣言が一つ以上あり、全てが削除されるときだけ参照とみなす。コメントと文字列は除く。
REMOVED = set(fixpoint["forbidden_in_kept_modules"]) | set(fixpoint["change_release_declarations"]) | \
    set(fixpoint["change_other_declarations"])
kept_modules = sorted({m for m in mods if group(m) in ("Refinement", "Scope", "Checked", "Shared", "Library",
                                                      "Exchange", "Interval")}
                      | set(fixpoint["keep_release"]) | set(SURFACE_SYNTAX))
deleted_modules = set(fixpoint["delete_release"]) | {m for m in default if group(m) == "Core"} | \
    {m for m in default if group(m) == "Surface" and m not in SURFACE_SYNTAX} | {"Benitoite.Release.LegacyCheck"}
deleted_names = {n for n, v in nodes.items() if bnt(n) and (v[0] in deleted_modules or n in REMOVED)}
kept_names = {n for n, v in nodes.items() if bnt(n) and n not in deleted_names}
namespace_decls = collections.defaultdict(set)
for n in nodes:
    if bnt(n) and not n.startswith("_private."):
        parts = n.split(".")
        for k in range(1, len(parts)):
            namespace_decls[".".join(parts[:k])].add(n)
def namespace_deleted(ns):
    ds = namespace_decls.get(ns)
    return bool(ds) and ds <= deleted_names
def strip(text):
    text = re.sub(r"/-.*?-/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    text = re.sub(r"'(?:[^'\\\n]|\\.)'", "'c'", text)
    text = re.sub(r'"(?:[^"\\]|\\.)*"', lambda m: '""' + "\n" * m.group(0).count("\n"), text)
    return re.sub(r"--[^\n]*", "", text)
TOP = re.compile(r"^(?:@\[|private |protected |noncomputable |partial |theorem |lemma |def |abbrev |instance |"
                 r"example|structure |inductive |class |mutual|end\b|namespace |section|open |export |attribute |"
                 r"#|variable |set_option |universe |deriving |macro|syntax |notation |infix|scoped |local |"
                 r"private\b|unsafe |opaque |axiom )")
IDENT = re.compile(r"(?<![\w.'])[A-Za-z_][\w']*(?:\.[A-Za-z_][\w'!?]*)*")
def resolve(token, namespaces, opens):
    cands = [token]
    for ns in namespaces + opens:
        cands.append(ns + "." + token)
    hit = [c for c in cands if c in deleted_names]
    keep = [c for c in cands if c in kept_names]
    return hit if hit and not keep else []
source_refs = collections.defaultdict(list)
for m in kept_modules:
    path = FORMAL / (m.replace(".", "/") + ".lean")
    if not path.exists():
        continue
    raw = strip(path.read_text())
    lines_src = raw.split("\n")
    stack, opens = [], []
    # 除く宣言の本文の行（宣言の始まりから次のトップレベルの行の前まで）。その中の参照は宣言と一緒に除かれる。
    removed_lines = set()
    for n in REMOVED:
        if nodes.get(n, ("",))[0] == m and decl_line.get(n):
            a = decl_line[n] - 1
            b = a
            while b < len(lines_src) and not TOP.match(lines_src[b]):
                b += 1
            b += 1
            while b < len(lines_src) and not TOP.match(lines_src[b]):
                b += 1
            removed_lines.update(range(a, b))
    # 宣言のグラフに現れる参照（移植する読者の辺）と、ファイルの中で局所の名前として束縛する綴りは「証明の中」に数えない。
    graph_refs = set()
    for n in by_module.get(m, []):
        if n not in REMOVED:
            graph_refs |= nodes[n][2]
    local_names = set(re.findall(r"(?:\bhave|\blet|\bfun|\bintro|\brename_i|\bcase|\bobtain|⟨|\(|\{|,|\|)\s*([A-Za-z_][\w']*)", raw))
    i = 0
    while i < len(lines_src):
        line = lines_src[i]
        mns = re.match(r"^namespace (\S+)", line)
        if mns:
            stack.append(mns.group(1)); i += 1; continue
        mend = re.match(r"^end (\S+)", line)
        if mend and stack and stack[-1].endswith(mend.group(1).split(".")[-1]):
            stack.pop(); i += 1; continue
        current = []
        acc = ""
        for part in stack:
            acc = part if not acc else acc + "." + part
            current.append(acc)
        current = list(reversed(current))
        kind = None
        if re.match(r"^(?:@\[[^\]]*\]\s*)?example\b", line):
            kind = "example"
        elif re.match(r"^\s*open\b", line):
            kind = "open"
        elif re.match(r"^\s*export\b", line):
            kind = "export"
        elif re.match(r"^\s*attribute\b", line):
            kind = "attribute"
        elif re.match(r"^\s*#(check|print|reduce|eval|guard)", line):
            kind = "command"
        if kind is None:
            if i not in removed_lines:
                hits = set()
                for tok in IDENT.findall(line):
                    if "." not in tok and tok in local_names:
                        continue
                    hits.update(h for h in resolve(tok, current, opens) if h not in graph_refs)
                if hits:
                    source_refs["proof"].append({"module": m, "line": i + 1, "references": sorted(hits)})
            i += 1; continue
        j = i + 1
        if kind == "example":
            while j < len(lines_src) and not TOP.match(lines_src[j]):
                j += 1
        block = "\n".join(lines_src[i:j])
        found = set()
        if kind in ("open", "export"):
            mo = re.match(r"^\s*(?:open|export)\s+(.*?)(?:\s+in)?\s*$", block.split("\n")[0])
            spec = mo.group(1) if mo else ""
            sel = re.match(r"^(\S+)\s*\(([^)]*)\)", spec)
            targets_ns = []
            if sel:
                base = sel.group(1)
                full = [c for c in [base] + [ns + "." + base for ns in current] if c in namespace_decls]
                for name in sel.group(2).split():
                    for f in full:
                        if f + "." + name in deleted_names:
                            found.add(f + "." + name)
                targets_ns = []
            else:
                targets_ns = [t for t in re.split(r"\s+", spec) if t and not t.startswith("(") and t != "hiding"]
            for t in targets_ns:
                full = [c for c in [t] + [ns + "." + t for ns in current] if c in namespace_decls]
                if full and all(namespace_deleted(f) for f in full):
                    found.update(full)
            if kind == "open" and not sel:
                for t in targets_ns:
                    full = [c for c in [t] + [ns + "." + t for ns in current] if c in namespace_decls]
                    opens.extend(full)
        else:
            for tok in IDENT.findall(block):
                for h in resolve(tok, current, opens):
                    found.add(h)
        if found:
            source_refs[kind].append({"module": m, "line": i + 1, "references": sorted(found)})
        i = j if kind == "example" else i + 1
source_scan = {"kept_modules_scanned": len(kept_modules), "counts": {k: len(source_refs.get(k, [])) for k in ("example", "open", "export", "attribute", "command", "proof")},
               "sites": {k: v for k, v in sorted(source_refs.items())}}

data = {
    "graph": {"bytes": graph.stat().st_size, "sha256": hashlib.sha256(graph.read_bytes()).hexdigest(),
              "declarations": len(nodes)},
    "modules": {"all": len(mods), "default_closure": len(default), "outside_default": outside_default,
                "by_group": dict(sorted(collections.Counter(group(m) for m in default).items()))},
    "table": table,
    "judgments": judgments,
    "old_main": old_main, "surface_theorems": surface_theorems,
    "judgment_readers_outside_old": {m: len(s) for m, s in judgment_readers.items()},
    "main_readers_outside_old": main_readers,
    "c05": {"names": c05_names, "modules": c05_modules, "old_release_modules": c05_old_modules},
    "entries": entry_paths, "entry_refs": entry_refs, "layers": layers,
    "refinement_reads_surface": {m: sorted(s) for m, s in sorted(refinement_surface.items())},
    "refinement_reads_old_models": {m: sorted(s) for m, s in sorted(refinement_release_models.items())},
    "needed_surface_by_kept": needed_surface,
    "keep_release": keep_roles, "delete": delete, "import_cuts": import_cuts,
    "conservative": conservative, "old_name_readers": old_name_readers, "proper_judgments": PROPER,
    "delete_lines": {k: sum(lines[m] for m in v) for k, v in delete.items()},
    "interval_lines": sum(lines[m] for m in default if group(m) == "Interval"),
    "backflow": backflow, "fixpoint": fixpoint, "backflow_transitive": backflow_transitive,
    "source_scan": source_scan,
    "admit": {"declarations": admit, "source_lines": admit_text, "design_lines": design_admit},
}
out = HERE / "inventory.json"
out.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
assert out.stat().st_size <= 100_000, out.stat().st_size
summary = {
    "declarations": len(nodes), "default_modules": len(default),
    "table_rows": len(table), "old_missing": [t["old"] for t in table if not t["old_present"]],
    "new_missing": [t for t in table if not all(t["new_present"])],
    "judgments": len(judgments), "old_main": len(old_main), "surface_theorems": len(surface_theorems),
    "main_readers": {m: len(s) for m, s in main_readers.items()},
    "c05_old_modules": len(c05_old_modules),
    "keep_release": len(keep_roles), "delete": {k: len(v) for k, v in delete.items()},
    "delete_lines": data["delete_lines"], "interval_lines": data["interval_lines"],
    "layers": collections.Counter(v["kind"] for v in layers.values()),
    "refinement_reads_surface": {m: len(s) for m, s in data["refinement_reads_surface"].items()},
    "refinement_reads_old_models": data["refinement_reads_old_models"],
    "needed_surface_by_kept": needed_surface, "import_cuts": len(import_cuts),
    "conservative": {k: (len(v) if isinstance(v, list) else v) for k, v in conservative.items()},
    "old_name_readers": old_name_readers, "proper_judgments": len(PROPER),
    "backflow": backflow, "admit": data["admit"],
    "fixpoint": {k: (len(v) if isinstance(v, (list, dict)) else v) for k, v in fixpoint.items()},
    "backflow_transitive": {n.split(R + ".")[-1]: len(v) for n, v in backflow_transitive.items()},
    "source_scan": source_scan["counts"],
    "inventory_bytes": out.stat().st_size,
}
print(json.dumps(summary, ensure_ascii=False, indent=1))
