#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""7入口の main から定数の依存の閉包を辿り、新しい判断だけを読むことを照合する。

方法: 既定ビルドの .olean を読む（.olean を書かない）。入口ごとに確認用の .lean を一時領域に作り、
`lake env lean -M 12288` で実行する。閉包の辺は、型と値（不透明な定数の値を含む）に現れる定数、
`partial` の実体 `._unsafe_rec`、`implemented_by` の先、コンパイラの `csimp` の置き換え先、
帰納型とその構成子の相互の辺である。`csimp` の定理そのものは辿らず、名前だけを記録する。

照合: 閉包に現れる定数の所属モジュールを集め、次と照らす。
(a) 旧 Surface（`Benitoite.Surface.*`）は区間解析の入力の構文の3モジュールだけ。
(b) 旧 Release（`Benitoite.Release.*` のうち `Refinement` 以外）は retained-release.md の74モジュールだけ。
(c) `Benitoite.Core.*` は0。
(d) 群 A の棚卸し（../a/inventory.json）の旧の完全名・旧の判断・旧主定理・旧表層の主定理は0。
    当たった名前には、属する集合（判断の本体 `proper_judgments` を含む）と、閉包の中でその名前を読む宣言と辺を添える。
入口のソース（入口の根と、その import の閉包のうち `Benitoite` の外のモジュール）が直接書く完全名も
文字で数え、同じ基準で分ける。

出力: entries-closure.json（要約。生の出力は --tmp に置き、大きさと SHA-256 だけを残す）。
使い方: python3 entries_closure.py --tmp <一時領域> --single-lock <単独の Lean の順番のロック>
        --build-lock <既定ビルドの共有ロック>
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
FORMAL = ROOT / "formal"
R = "Benitoite.Release.Refinement"

ENTRIES = {
    "desugarDiff": "DesugarDiff.Main", "builtinCheck": "BuiltinCheck.Main",
    "coverageDiff": "CoverageDiff.Main", "coverageProgramDiff": "CoverageProgramDiff.Main",
    "surfaceCheck": "SurfaceCheck.Main", "surfaceCheckAll": "SurfaceCheck.All",
    "intervalDiff": "IntervalDiff.Main",
}
SURFACE_KEEP = {"Benitoite.Surface.Syntax", "Benitoite.Surface.BuilderSyntax", "Benitoite.Surface.FormatSpec"}

LEAN = r'''import {root}
import Lean

/- 入口の main から定数の依存の閉包を幅優先で辿り、各定数の所属モジュールと最初に見つけた辺を書き出す。 -/
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let csimp := (Lean.Compiler.CSimp.ext.getState env).map
  let modOf (n : Name) : String :=
    match env.getModuleIdxFor? n with
    | some idx => (env.header.moduleNames[idx.toNat]?.map Name.toString).getD "?"
    | none => "<here>"
  let kindOf (ci : ConstantInfo) : String := match ci with
    | .thmInfo _ => "theorem" | .defnInfo _ => "def" | .opaqueInfo _ => "opaque"
    | .axiomInfo _ => "axiom" | .inductInfo _ => "inductive" | .ctorInfo _ => "constructor"
    | .recInfo _ => "recursor" | .quotInfo _ => "quot"
  let mut parent : Std.HashMap Name (Name × String) := {{}}
  parent := parent.insert `main (`main, "root")
  let mut queue : Array Name := #[`main]
  let mut csimpThms : Array String := #[]
  let watch : Std.HashSet Name := ({old} : List String).foldl (fun s t => s.insert t.toName) {{}}
  let mut referrers : Array String := #[]
  let mut i := 0
  while h : i < queue.size do
    let n := queue[i]
    i := i + 1
    let some ci := env.find? n | continue
    let mut edges : Array (Name × String) := #[]
    for d in ci.type.getUsedConstants do edges := edges.push (d, "type")
    if let some v := ci.value? (allowOpaque := true) then
      for d in v.getUsedConstants do edges := edges.push (d, "value")
    let ur := n ++ `_unsafe_rec
    if env.contains ur then edges := edges.push (ur, "unsafe_rec")
    if let some t := Compiler.getImplementedBy? env n then edges := edges.push (t, "implemented_by")
    if let some e := csimp.find? n then
      edges := edges.push (e.toDeclName, "csimp")
      csimpThms := csimpThms.push s!"{{n}} -> {{e.toDeclName}} by {{e.thmName}}"
    match ci with
    | .inductInfo v => for c in v.ctors do edges := edges.push (c, "ctor")
    | .ctorInfo v => edges := edges.push (v.induct, "induct")
    | _ => pure ()
    for (d, k) in edges do
      if watch.contains d then referrers := referrers.push s!"R\t{{d}}\t{{n}}\t{{k}}\n"
      unless parent.contains d do
        parent := parent.insert d (n, k)
        queue := queue.push d
  let mut out : String := ""
  for n in queue do
    let kind := (env.find? n).map kindOf |>.getD "missing"
    let (p, k) := parent.getD n (`main, "root")
    out := out ++ s!"C\t{{n}}\t{{modOf n}}\t{{kind}}\t{{p}}\t{{k}}\n"
  for s in csimpThms do out := out ++ s!"S\t{{s}}\n"
  for s in referrers do out := out ++ s
  for t in ({names} : List String) do
    let n := t.toName
    let st := if parent.contains n then "closure" else if env.contains n then "env" else "absent"
    let m := if env.contains n then modOf n else "-"
    out := out ++ s!"T\t{{t}}\t{{st}}\t{{m}}\n"
  IO.FS.writeFile {out} out
  logInfo m!"TOTAL {{queue.size}}"
'''


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def module_imports():
    mods = {}
    for p in sorted(FORMAL.rglob("*.lean")):
        rel = p.relative_to(FORMAL)
        if rel.parts[0] in (".lake", "tests"):
            continue
        mods[".".join(rel.with_suffix("").parts)] = [
            m.group(1) for m in re.finditer(r"^import\s+(\S+)", p.read_text(), re.M)]
    return mods


def local_closure(mods, root):
    seen, stack = [], [root]
    while stack:
        m = stack.pop()
        if m in seen or m not in mods or m.startswith("Benitoite"):
            continue
        seen.append(m)
        stack.extend(mods[m])
    return sorted(seen)


def strip_comments(text):
    # ブロックコメント（入れ子あり）と行コメントを除いた本文。文字で数える完全名は本文とコメントを分ける。
    out, depth, i = [], 0, 0
    while i < len(text):
        if text.startswith("/-", i):
            depth += 1
            i += 2
        elif depth and text.startswith("-/", i):
            depth -= 1
            i += 2
        elif depth:
            i += 1
        elif text.startswith("--", i):
            j = text.find("\n", i)
            i = len(text) if j < 0 else j
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


NAME_RE = re.compile(r"Benitoite(?:\.[A-Za-z_][A-Za-z0-9_']*)+")


def classify_module(m, retained):
    if m == "Benitoite.Surface" or m.startswith("Benitoite.Surface."):
        return "a_ok" if m in SURFACE_KEEP else "a_violation"
    if m == "Benitoite.Core" or m.startswith("Benitoite.Core."):
        return "c_violation"
    if m.startswith("Benitoite.Release.") and not (m == R or m.startswith(R + ".")):
        return "b_ok" if m in retained else "b_violation"
    return None


def group(m):
    if m == R or m.startswith(R + "."):
        return "Release.Refinement"
    if m.startswith("Benitoite."):
        parts = m.split(".")
        return parts[1] if len(parts) > 1 else m
    return m.split(".")[0] if m not in ("<here>", "?") else m


def git_state():
    head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
    diff = subprocess.run(["git", "diff", "HEAD", "--", "formal"], cwd=ROOT, capture_output=True, check=True).stdout
    untracked = subprocess.run(["git", "ls-files", "--others", "--exclude-standard", "--", "formal"], cwd=ROOT,
                               capture_output=True, text=True, check=True).stdout.split()
    h = hashlib.sha256()
    for p in sorted(untracked):
        h.update(p.encode() + b"\0" + (ROOT / p).read_bytes() + b"\0")
    return {"head": head, "formal_diff_sha256": sha(diff), "formal_diff_bytes": len(diff),
            "formal_untracked": len(untracked), "formal_untracked_sha256": h.hexdigest()}


def no_build(lock):
    # 既定の対象を書かずに、生成物が最新であることを確かめる（.olean を書かない）。
    r = subprocess.run(["/usr/bin/lockf", "-t", "3600", str(lock), "lake", "build", "--no-build"], cwd=FORMAL,
                       capture_output=True, text=True)
    last = [l for l in r.stdout.splitlines() if l.strip()][-1:] or [""]
    return {"exit": r.returncode, "last_line": last[0]}


def chain(parent, n, limit=40):
    out = [n]
    while n in parent and parent[n][0] != n and len(out) < limit:
        p, k = parent[n]
        out.append(f"<-{k}- {p}")
        n = p
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tmp", type=Path, required=True)
    ap.add_argument("--single-lock", type=Path, required=True)
    ap.add_argument("--build-lock", type=Path, required=True)
    args = ap.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)

    lakefile = (FORMAL / "lakefile.toml").read_text()
    targets = re.search(r'defaultTargets = \[(.*?)\]', lakefile).group(1)
    assert sorted(t.strip(' "') for t in targets.split(",")) == sorted(["Benitoite", *ENTRIES]), targets
    for exe, root in ENTRIES.items():
        assert re.search(rf'name = "{exe}"\nroot = "{re.escape(root)}"', lakefile), exe

    retained_rows = re.findall(r"^\| `([A-Za-z0-9_.]+)` \|", (HERE / "retained-release.md").read_text(), re.M)
    retained = {"Benitoite.Release." + m for m in retained_rows}
    assert len(retained_rows) == len(retained) == 74, len(retained_rows)

    inv = json.loads((HERE.parent / "a" / "inventory.json").read_text())
    old_sets = {
        "table_old": sorted({r["old"] for r in inv["table"]}),
        "judgments": sorted(inv["judgments"]),
        "old_main": sorted(inv["old_main"]),
        "surface_theorems": sorted(inv["surface_theorems"]),
        "proper_judgments": sorted(inv["proper_judgments"]),
    }
    old_names = set().union(*old_sets.values())
    # 残すモジュールの共有の構文。新しい表層が共有すると対照表（L00a.06a）が定めた構文の名前であり、判断・主定理の
    # 名前でない（proper_judgments・old_main・surface_theorems に入らない）ので、照合の対象から外す。
    shared_syntax = {"Benitoite.Release.Const", "Benitoite.Release.Ty.lazy"}
    assert not (shared_syntax & (set(old_sets["proper_judgments"]) | set(old_sets["old_main"]) | set(old_sets["surface_theorems"])))
    old_names -= shared_syntax

    mods = module_imports()
    state_before = git_state()
    nobuild_before = no_build(args.build_lock)
    assert nobuild_before["exit"] == 0, nobuild_before

    summary = {"method": "main からの幅優先の閉包。辺は型・値（不透明を含む）・_unsafe_rec・implemented_by・csimp の置き換え先・帰納型と構成子。csimp の定理は辿らない",
               "state_before": state_before, "no_build_before": nobuild_before,
               "retained_release_modules": len(retained), "old_name_sets": {k: len(v) for k, v in old_sets.items()},
               "old_names_total": len(old_names), "excluded_shared_syntax": sorted(shared_syntax), "entries": {}}
    totals = collections.Counter()
    for exe, root in ENTRIES.items():
        files = local_closure(mods, root)
        texts = {}
        for m in files:
            raw = (FORMAL / (m.replace(".", "/") + ".lean")).read_text()
            body = strip_comments(raw)
            texts[m] = (sorted(set(NAME_RE.findall(body))), sorted(set(NAME_RE.findall(raw)) - set(NAME_RE.findall(body))))
        names = sorted({n for b, _ in texts.values() for n in b})
        outp = args.tmp / f"closure-{exe}.tsv"
        lean = args.tmp / f"closure-{exe}.lean"
        lean.write_text(LEAN.format(root=root, names=json.dumps(names), old=json.dumps(sorted(old_names)), out=json.dumps(str(outp))))
        t0 = time.time()
        r = subprocess.run(["/usr/bin/lockf", "-t", "3600", str(args.single_lock), "/usr/bin/time", "-l",
                            "lake", "env", "lean", "-M", "12288", str(lean)], cwd=FORMAL, capture_output=True, text=True)
        wall = round(time.time() - t0, 2)
        (args.tmp / f"closure-{exe}.log").write_text(r.stdout + r.stderr)
        assert r.returncode == 0, (exe, r.stdout[-2000:], r.stderr[-2000:])
        rss = re.search(r"(\d+)\s+maximum resident set size", r.stderr)
        data = outp.read_bytes()
        consts, parent, csimps, tnames = {}, {}, [], []
        refs = collections.defaultdict(list)
        for line in data.decode().splitlines():
            f = line.split("\t")
            if f[0] == "C":
                _, n, mod, kind, p, k = f
                consts[n] = (mod, kind)
                parent[n] = (p, k)
            elif f[0] == "S":
                csimps.append(f[1])
            elif f[0] == "T":
                tnames.append(f[1:])
            elif f[0] == "R":
                refs[f[1]].append(f"{f[2]} ({f[3]})")
        by_mod = collections.Counter(m for m, _ in consts.values())
        by_group = collections.Counter()
        for m, c in by_mod.items():
            by_group[group(m)] += c
        cls = collections.defaultdict(dict)
        for m, c in sorted(by_mod.items()):
            k = classify_module(m, retained)
            if k:
                cls[k][m] = c
        missing = sorted(n for n, (_, kind) in consts.items() if kind == "missing")
        d_hits = sorted(n for n in consts if n in old_names)
        d_detail = {n: {"module": consts[n][0], "kind": consts[n][1],
                        "sets": [k for k, v in old_sets.items() if n in v],
                        "referrers": sorted(refs[n])[:30], "referrers_total": len(refs[n])} for n in d_hits}
        e = {"root": root, "source_modules": files, "lean_exit": r.returncode, "wall_seconds": wall,
             "max_rss_bytes": int(rss.group(1)) if rss else None,
             "constants": len(consts), "modules": len(by_mod), "by_group": dict(sorted(by_group.items())),
             "missing_constants": missing,
             "a_surface_modules": cls.get("a_ok", {}), "a_violations": cls.get("a_violation", {}),
             "b_release_modules": len(cls.get("b_ok", {})), "b_release_constants": sum(cls.get("b_ok", {}).values()),
             "b_release_by_module": cls.get("b_ok", {}), "b_violations": cls.get("b_violation", {}),
             "c_core": cls.get("c_violation", {}), "d_old_names": d_hits, "d_detail": d_detail,
             "csimp_replacements": csimps,
             "raw": {"file": outp.name, "bytes": len(data), "sha256": sha(data)}}
        # 違反の経路: 違反のモジュールごとに最初に見つけた定数の、main までの辺の連鎖。
        paths = {}
        for k in ("a_violation", "b_violation", "c_violation"):
            for m in cls.get(k, {}):
                first = next(n for n in consts if consts[n][0] == m)
                paths[m] = chain(parent, first)
        for n in d_hits[:20]:
            paths[n] = chain(parent, n)
        e["violation_paths"] = paths
        # 入口のソースが直接書く完全名。
        text_rows = []
        tv = collections.Counter()
        for name, st, mod in tnames:
            k = classify_module(mod, retained) if mod != "-" else None
            pre = classify_module(name, retained)  # 定数でない名前（名前空間など）は名前の接頭辞で分ける
            label = k or pre
            if name in old_names:
                label = "d_violation"
            row = {"name": name, "status": st, "module": mod, "class": label}
            if label and label.endswith("violation"):
                text_rows.append(row)
            tv[label or "new_or_other"] += 1
        e["source_names"] = {"in_code": len(tnames), "by_class": dict(sorted(tv.items())),
                             "violations": text_rows,
                             "comment_only": {m: c for m, (_, c) in texts.items() if c},
                             "per_file": {m: len(b) for m, (b, _) in texts.items()}}
        for k in ("a_violations", "b_violations", "c_core"):
            totals[k] += sum(e[k].values())
        totals["d_old_names"] += len(d_hits)
        totals["d_proper_judgments_or_main"] += sum(1 for n in d_hits if set(d_detail[n]["sets"]) & {"proper_judgments", "old_main", "surface_theorems"})
        totals["source_violations"] += len(text_rows)
        summary["entries"][exe] = e
    summary["no_build_after"] = no_build(args.build_lock)
    summary["state_after"] = git_state()
    summary["state_unchanged"] = summary["state_before"] == summary["state_after"]
    summary["totals"] = dict(totals)
    summary["pass"] = (all(v == 0 for v in totals.values()) and summary["state_unchanged"]
                       and summary["no_build_after"]["exit"] == 0)
    text = json.dumps(summary, ensure_ascii=False, indent=1) + "\n"
    (HERE / "entries-closure.json").write_text(text)
    print(json.dumps({"pass": summary["pass"], "totals": summary["totals"], "bytes": len(text.encode())}, ensure_ascii=False))


if __name__ == "__main__":
    main()
