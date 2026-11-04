"""75欄へ同じ前提矛盾の検査を適用し、既存証明の読解と併せた判定を保存する。"""
from pathlib import Path
import argparse, collections, json, re, subprocess, time
from inventory import HERE, STAGE, ROOT, digest, write

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tmp", type=Path, required=True)
    args = ap.parse_args()
    rows = json.loads((STAGE / "j/conditions.json").read_text())
    probe = HERE / "premise-probe.lean"
    code = (STAGE / "j/contracts.lean").read_text().replace("end ScopeModelContracts", "")
    code += probe.read_text().removeprefix("import Lean\n")
    code += "\n" + "\n".join("probe_empty " + r["contract"].removeprefix("ScopeModelContracts.") for r in rows)
    code += "\nend ScopeModelContracts\n"
    source = args.tmp / "premise-probe.lean"
    source.write_text(code)
    raw = args.tmp / "vacuity.log"
    start = time.monotonic()
    with raw.open("wb") as stream:
        run = subprocess.run(["lake", "env", "lean", "-M", "12288", str(source)], cwd=ROOT / "formal", stdout=stream, stderr=subprocess.STDOUT)
    seconds = time.monotonic() - start
    output = raw.read_text()
    assert run.returncode == 0 and not re.search(r"error:|warning:|sorry", output), output[-6000:]
    results = dict(re.findall(r"^EMPTY_PREMISES (\S+) (true|false)$", output, re.M))
    assert len(results) == len(rows) == 75
    vacant = {"delta_typed", "io_typed", "io_kind", "io_exists", "io_op", "io_target"}
    for row in rows:
        empty = results[row["contract"]] == "true"
        assert empty == (row["model"] == "Model.builtins" and row["field"] in vacant)
        row["premises_prove_false"] = empty
        row["judgment"] = "前提の否定で空疎" if empty else "実質"
        model = row["model"].split(".")[0]
        row["proof_review"] = {"Model": "../../reviews/RV-L50.h.md", "ModelTargets": "../../reviews/RV-L50.i.md", "ModelHttp": "../../reviews/RV-L50.j.md"}[model]
        if empty:
            row["basis"] = "pure/io/exitの署名不在、又は空のioResponseからFalse。前提矛盾の証明をカーネル検査済み"
        elif row["field"].startswith(("sat_", "admits_")):
            row["basis"] = "前提矛盾検査では閉じない。制約の意味・置換保存又は署名の引数個数の実際の結論を構成する本番証明と群末レビューを確認"
        else:
            row["basis"] = "前提矛盾検査では閉じない。lookupの到達枝、応答又は表の具体の結論を構成する本番証明と群末レビューを確認"
    write(HERE / "condition-judgments.json", rows)
    counts = {m: dict(collections.Counter(r["judgment"] for r in rows if r["model"] == m)) for m in dict.fromkeys(r["model"] for r in rows)}
    write(HERE / "vacuity-check.json", {"exit": run.returncode, "seconds": seconds, "rows": 75, "counts": counts, "input": digest(STAGE / "j/contracts.lean"), "probe": digest(probe), "generated_source": digest(source), "raw": digest(raw), "judgments": digest(HERE / "condition-judgments.json"), "limitation": "戦術の失敗だけから非空疎とは判定しない。実質の69欄は本番の到達枝と群H/I/Jの独立レビューに照らした判断"})
    print(json.dumps(counts, ensure_ascii=False))

if __name__ == "__main__":
    main()
