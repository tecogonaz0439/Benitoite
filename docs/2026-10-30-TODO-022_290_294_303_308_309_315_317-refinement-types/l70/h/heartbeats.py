# -*- coding: utf-8 -*-
"""`set_option maxHeartbeats`・`maxRecDepth` の全箇所の一覧と、段で足した箇所の要否の確認（L70.46 (f)）。

全箇所は既定 import の対象の Lean ソース（formal/ の .lake と tests を除く）から数える。段の開始版にない行を「段で足した」
とし、既定値での timeout の記録（改造の文書の名前）を RECORDED に置く。記録のない箇所は、その一行だけを外した写しを
一時領域に置き、`lake env lean -M 12288` で一つずつ検査する（--run）。写しは元のモジュールと同じ import を読む。
段の前からの箇所（段の開始版の同じファイルにある箇所）は、段で変えていないファイルなら段の開始版で既にあったことを
示すだけとし、段で変えたファイルなら、記録がなければ段で足した箇所と同じ方法（その一行だけを外した写しを単独の Lean で
検査する）で確かめる（--run-inherited。共有ロックの下で一件ずつ）。検査の結果は ../h3/heartbeats-tests.json に一件ずつ
足す。記録は ../h3/heartbeats.json（群 H の --run の結果は ../h/heartbeats.json の tests を引き継ぐ）。
使い方: python3 heartbeats.py --tmp <一時領域> [--run] [--run-inherited --lock <共有ロック>] [--out <記録>]"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
from support import B_STAGE, HERE, ROOT, digest, git, write

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
parser.add_argument("--run", action="store_true")
parser.add_argument("--run-inherited", action="store_true")
parser.add_argument("--lock", type=Path)
parser.add_argument("--out", type=Path, default=HERE.parent / "h3")
args = parser.parse_args()
TESTS = HERE.parent / "h3" / "heartbeats-tests.json"
TIMEOUT = re.compile(r"maximum number of heartbeats|deterministic\) timeout|maximum recursion depth")

OPTION = re.compile(r"^\s*set_option (maxHeartbeats|maxRecDepth) (\d+)( in)?\s*$")
SOURCES = ["Benitoite", "DesugarDiff", "BuiltinCheck", "CoverageDiff", "CoverageProgramDiff", "SurfaceCheck",
           "IntervalDiff"]
# 段で足した箇所の既定値での timeout の記録（改造の中の記録の名前と節）。
RECORDED = {
    ("Benitoite/Release/Refinement/StandardModelComposedRows.lean", 1):
        "l70/c/results.md「検査」・reviews/RV-L70.c.md の検査6（外した写しが既定の200000で停止）",
    ("Benitoite/Release/Refinement/Surface/OpenSurfaceProperty1.lean", 1):
        "l70/d/resume5-7-details.md・l70/d/resume7-limits.json（外した写しが既定の200000で timeout）",
    ("Benitoite/Release/Refinement/Surface/OpenSurfaceScoped.lean", 1):
        "l70/d/resume5-7-details.md・l70/d/resume7-limits.json（外した写しが既定の200000で timeout）",
    ("Benitoite/Release/Refinement/Surface/Property1.lean", 1):
        "l70/d/results.md「群 D の判断」の3・reviews/RV-L70.d.md の検査4（外した写しが既定の上限で時間切れ）",
    ("Benitoite/Release/Refinement/Surface/ScopedProof.lean", 1):
        "l70/d/results.md「群 D の判断」の3・reviews/RV-L70.d.md の検査4（外した写しが既定の上限で時間切れ）",
    ("Benitoite/Release/Refinement/Surface/PredicateProjectSource.lean", 1):
        "l70/d/results.md・l70/d/resume8-design.md（投影の型付けの逆転二件が既定の200000を超えた）",
    ("Benitoite/Release/Refinement/Surface/PredicateProjectSource.lean", 2):
        "l70/d/results.md・l70/d/resume8-design.md（投影の型付けの逆転二件が既定の200000を超えた）",
    ("Benitoite/Release/Refinement/Surface/PredicateSimulationPipeSafety.lean", 1):
        "l70/d/resume9-10.md（モジュールに一か所。外した写しが既定の200000で timeout）",
}


def occurrences(text):
    return [(i, m[1], int(m[2]), bool(m[3])) for i, line in enumerate(text.splitlines(), 1)
            if (m := OPTION.match(line))]


files = sorted(p for d in SOURCES for p in (ROOT / "formal" / d).rglob("*.lean")) + [ROOT / "formal/Benitoite.lean"]
base_files = set(git("ls-tree", "-r", "--name-only", B_STAGE, "formal/").split())
rows = []
for path in files:
    rel = str(path.relative_to(ROOT / "formal"))
    found = occurrences(path.read_text())
    if not found:
        continue
    base = occurrences(git("show", f"{B_STAGE}:formal/{rel}")) if "formal/" + rel in base_files else []
    base_options = [(o, v, s) for _, o, v, s in base]
    # 段の開始版の同じファイルにある同じ設定の数を、出現の順に段の前からの箇所として数える。
    remaining = list(base_options)
    ordinal = 0
    for line, option, value, scoped in found:
        key = (option, value, scoped)
        inherited = key in remaining
        if inherited:
            remaining.remove(key)
        ordinal += 0 if inherited else 1
        rows.append({"file": rel, "line": line, "option": option, "value": value, "scoped": scoped,
                     "stage": "段の前から" if inherited else "段で足した",
                     "ordinal": None if inherited else ordinal,
                     "record": None if inherited else RECORDED.get((rel, ordinal))})
added = [r for r in rows if r["stage"] == "段で足した"]
# 段で足した15箇所のうち、外した写しが既定値で通った1箇所（REMOVED）は本番から外した。残りは14箇所。
REMOVED = [{"file": "Benitoite/Release/Refinement/Surface/PredicateSimulationAlgebra.lean", "line": 189,
            "option": "maxHeartbeats", "value": 400000, "reason": "外した写しが既定の上限で終了0（tests の該当行）"}]
# 群 H の後（群 H のコミット B_H の後）に変えた・足したファイルの箇所は、群 H の記録の対象の外なので、段の前からの
# 変えたファイルの箇所と同じ方法で検査する（下の needed）。
B_H = json.loads((HERE.parent / "h2" / "changes.json").read_text())["base"]
after_h = {p.removeprefix("formal/") for p in git("diff", "--name-only", B_H, "--", "formal/").split()} | \
    {p.removeprefix("formal/") for p in git("ls-files", "--others", "--exclude-standard", "formal/").split()}
later_added = [r for r in added if r["file"] in after_h]
added = [r for r in added if r["file"] not in after_h]
assert len(added) == 15 - len(REMOVED), len(added)
assert all(r["option"] == "maxHeartbeats" for r in added)
untested = [r for r in added if r["record"] is None]
if not args.run:
    # 外した後は、元の行番号で記録した tests をそのまま残す（--run は外す前の状態でだけ行った）。
    untested = []

results = {}
# 群 H の --run の結果（段で足した箇所の検査7件）は群 H の記録から引き継ぐ。
previous = HERE / "heartbeats.json"
# 検査（--run）は外す前の状態の行番号で行った。
if previous.exists():
    results = {(t["file"], t["line"]): t for t in json.loads(previous.read_text()).get("tests", [])}
if args.run:
    work = args.tmp / "heartbeats"
    work.mkdir(parents=True, exist_ok=True)
    results = {}
    for r in untested:
        source = (ROOT / "formal" / r["file"]).read_text().splitlines(keepends=True)
        assert OPTION.match(source[r["line"] - 1])
        copy = work / (Path(r["file"]).stem + f"_without_{r['line']}.lean")
        copy.write_text("".join(source[:r["line"] - 1] + source[r["line"]:]))
        log = work / (copy.stem + ".log")
        start = time.monotonic()
        with log.open("wb") as out:
            done = subprocess.run(["lake", "env", "lean", "-M", "12288", str(copy)], cwd=ROOT / "formal",
                                  stdout=out, stderr=subprocess.STDOUT)
        text = log.read_text()
        timeout = re.search(r"maximum number of heartbeats|deterministic\) timeout", text) is not None
        results[(r["file"], r["line"])] = {
            "file": r["file"], "line": r["line"], "exit": done.returncode, "timeout": timeout,
            "first_error_line": next((int(m[1]) for m in re.finditer(r":(\d+):\d+: error", text)), None),
            "seconds": round(time.monotonic() - start, 1), "copy": digest(copy), "log": digest(log),
            "judgement": "要る（既定値で timeout）" if timeout else
            ("要らない（外しても終了0）" if done.returncode == 0 else "未確定（timeout 以外の失敗）")}
        print(json.dumps(results[(r["file"], r["line"])], ensure_ascii=False), flush=True)
record = {"base": B_STAGE, "total": len(rows), "by_stage": {s: sum(r["stage"] == s for r in rows)
                                                         for s in ["段の前から", "段で足した"]},
          "inherited_by_file": {}, "added": added, "removed": REMOVED, "tests": list(results.values())}
for r in rows:
    if r["stage"] == "段の前から":
        record["inherited_by_file"][r["file"]] = record["inherited_by_file"].get(r["file"], 0) + 1
# 段の前からの箇所の照合。段で変えていないファイルは、段の開始版と同じ内容であること（その箇所が段の開始版に
# 既にあったこと）を示す。段で変えたファイルは、外した写しを単独の Lean で検査した結果を照らす。
changed_files = {p.removeprefix("formal/") for p in git("diff", "--name-only", B_STAGE, "--", "formal/").split()}
untracked = {p.removeprefix("formal/") for p in git("ls-files", "--others", "--exclude-standard", "formal/").split()}
inherited = [r for r in rows if r["stage"] == "段の前から"]
unchanged = [r for r in inherited if r["file"] not in changed_files | untracked]
for r in unchanged:
    assert (ROOT / "formal" / r["file"]).read_text() == git("show", f"{B_STAGE}:formal/{r['file']}"), r["file"]
needed = [r for r in inherited if r["file"] in changed_files | untracked] + later_added
tests = json.loads(TESTS.read_text()) if TESTS.exists() else []
done_keys = {(t["file"], t["line"], t["source_sha256"]) for t in tests}
if args.run_inherited:
    work = args.tmp / "heartbeats-inherited"
    work.mkdir(parents=True, exist_ok=True)
    for r in needed:
        text = (ROOT / "formal" / r["file"]).read_text()
        key = (r["file"], r["line"], hashlib.sha256(text.encode()).hexdigest())
        if key in done_keys:
            continue
        source = text.splitlines(keepends=True)
        assert OPTION.match(source[r["line"] - 1])
        copy = work / (Path(r["file"]).stem + f"_without_{r['line']}.lean")
        copy.write_text("".join(source[:r["line"] - 1] + source[r["line"]:]))
        log = work / (copy.stem + ".log")
        start = time.monotonic()
        with log.open("wb") as out:
            done = subprocess.run(["/usr/bin/lockf", "-t", "3600", str(args.lock), "lake", "env", "lean", "-M",
                                   "12288", str(copy)], cwd=ROOT / "formal", stdout=out, stderr=subprocess.STDOUT)
        log_text = log.read_text()
        timeout = TIMEOUT.search(log_text) is not None
        tests.append({
            "file": r["file"], "line": r["line"], "option": r["option"], "value": r["value"],
            "source_sha256": key[2], "exit": done.returncode, "timeout": timeout,
            "first_error_line": next((int(m[1]) for m in re.finditer(r":(\d+):\d+: error", log_text)), None),
            "seconds": round(time.monotonic() - start, 1), "copy": digest(copy), "log": digest(log),
            "judgement": "要る（既定値で上限に達する）" if timeout else
            ("要らない（外しても終了0）" if done.returncode == 0 else "未確定（上限以外の失敗）")})
        TESTS.write_text(json.dumps(tests, ensure_ascii=False, indent=1) + "\n")
        print(json.dumps(tests[-1], ensure_ascii=False), flush=True)
current = {(r["file"], r["line"], hashlib.sha256((ROOT / "formal" / r["file"]).read_text().encode()).hexdigest())
           for r in needed}
inherited_tests = [t for t in tests if (t["file"], t["line"], t["source_sha256"]) in current]
record["inherited"] = {
    "unchanged_files": {"sites": len(unchanged), "files": len({r["file"] for r in unchanged}),
                        "check": "段の開始版の同じファイルと内容が同じ（その箇所は段の開始版に既にあった）"},
    "added_after_group_h": len(later_added),
    "changed_files": {"sites": len(needed), "files": len({r["file"] for r in needed}),
                      "tested": len(inherited_tests),
                      "judgements": dict(collections.Counter(t["judgement"] for t in inherited_tests)),
                      "untested": [(r["file"], r["line"]) for r in needed
                                   if (r["file"], r["line"], hashlib.sha256((ROOT / "formal" / r["file"]).read_text()
                                                                            .encode()).hexdigest()) not in
                                   {(t["file"], t["line"], t["source_sha256"]) for t in inherited_tests}]},
    "tests": digest(TESTS) if TESTS.exists() else None}
REMOVED_H3 = HERE.parent / "h3" / "heartbeats-removed.json"
if REMOVED_H3.exists():
    record["removed_h3"] = {"count": len(json.loads(REMOVED_H3.read_text())["removed"]), "record": digest(REMOVED_H3)}
args.out.mkdir(parents=True, exist_ok=True)
write(args.out / "heartbeats.json", record)
print(json.dumps({"total": len(rows), "added": len(added), "untested": len(untested),
                  "tests": len(results)}, ensure_ascii=False))
