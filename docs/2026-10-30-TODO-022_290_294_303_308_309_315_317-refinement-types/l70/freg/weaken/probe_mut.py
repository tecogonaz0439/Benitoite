"""開発用: 変異の検査の require を記録に変え、各変異の実際の結果を表示する。"""
import json, runpy, sys
from pathlib import Path
N = runpy.run_path(sys.argv[1]); G = N["check_programs"].__globals__
D = Path(sys.argv[2])
orig_rs, orig_run = G["run_surface"], G["run"]
def rs(tool, args, report, status=0):
    try:
        r = orig_rs(tool, args, report, status)
    except AssertionError as e:
        print("  run_surface failed:", str(e)[:300]); return {"result": {"ok": None, "error": {"reason": None}}}
    print("  ", tool, json.dumps(r["result"]) if r and "result" in r else ("None" if r is None else "report"), flush=True); return r
def rq(c, m):
    if not c: print("  REQUIRE FAILED:", m, flush=True)
G["run_surface"] = rs; G["require"] = rq
corpus = G["read"](D / "named-programs-corpus.json")
tables = {}
for p in (D / "named-programs-builtins.json", D / "named-programs-stdlib.json"):
    t = G["read"](p); tables[p] = (t, G["keyed"](t["inputs"]))
print("== program rejections"); G["check_program_rejections"](D, corpus, tables, G["read"](G["MANIFEST"])["programReports"]["desugarKnownDifferences"]["counts"])
m = G["read"](G["MANIFEST"])
outs = {e["stem"]: G["check_named"](D, e, m["namedVersions"]) for e in m["named"] if e["stem"] in ("named-calls", "named-static-calls")}
print("== rejections"); G["check_rejections"](D, outs["named-calls"], outs["named-static-calls"])
