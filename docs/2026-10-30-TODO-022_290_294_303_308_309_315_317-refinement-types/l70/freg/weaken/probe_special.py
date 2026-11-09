"""開発用: check_special_rejections と check_program_rejections の各変異の実際の結果を表示する。"""
import copy, json, runpy, sys, tempfile
from pathlib import Path
N = runpy.run_path(sys.argv[1]); G = N["check_programs"].__globals__
D = Path(sys.argv[2]); W = Path(sys.argv[3])
corpus = G["read"](D / "named-programs-corpus.json")
tables = {}
for p in (D / "named-programs-builtins.json", D / "named-programs-stdlib.json"):
    t = G["read"](p); tables[p] = (t, G["keyed"](t["inputs"]))
def show(label, path, item, tables_for):
    out = W / "report.json"
    import subprocess
    p = subprocess.run([str(G["BIN"] / "surfaceCheck"), str(path), *map(str, tables_for), item["group"], item["name"], str(out)],
                       text=True, capture_output=True, timeout=120)
    r = json.loads(out.read_text()) if out.exists() else None
    print(label, p.returncode, json.dumps(r["result"]) if r else None, p.stderr[:300], flush=True)
    out.unlink(missing_ok=True)
for mode in ("method-user", "method-dictionary", "operation"):
    suffix = "named_operations.bnt" if mode == "operation" else "named_methods.bnt"
    item = copy.deepcopy(next(i for i in corpus["inputs"] if i["name"].endswith(suffix)))
    c = {**corpus, "inputs": [item]}
    st = G["write_selected_tables"](W, tables, (item["group"], item["name"]))
    if mode == "unmutated": pass
    elif mode == "method-user":
        s = next(d["scope"]["inScope"]["surface"] for d in item["definitions"] if d["scope"]["inScope"]["surface"]["method"] is not None)
        s["header"]["names"][0] = "wrong"
    elif mode == "method-dictionary":
        m = next(m for cl in item["classes"] for m in cl["methods"] if m["header"]["names"][0] == "%dict1")
        m["header"]["names"][0] = "wrong"
    else:
        item["ops"][0]["header"]["names"][0] = "wrong"
    path = W / "corpus.json"; path.write_text(json.dumps(c))
    show(mode, path, item, st)
