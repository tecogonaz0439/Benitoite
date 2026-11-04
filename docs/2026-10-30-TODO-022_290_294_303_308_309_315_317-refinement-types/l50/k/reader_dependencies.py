"""Lean の型と値から依存の閉包を作り、一行表の読者を再現・照合する。"""
from pathlib import Path
import argparse
import collections
import hashlib
import json
import subprocess
from functools import lru_cache

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def graph(tmp):
    raw = tmp / "reader-dependencies.log"
    with raw.open("wb") as stream:
        result = subprocess.run(
            ["lake", "env", "lean", "-M", "12288", str(HERE / "reader-dependencies.lean")],
            cwd=ROOT / "formal", stdout=stream, stderr=subprocess.STDOUT)
    assert result.returncode == 0, raw.read_text()[-6000:]
    nodes = [json.loads(line.removeprefix("READER_NODE "))
             for line in raw.read_text().splitlines() if line.startswith("READER_NODE ")]
    assert nodes and len(nodes) == len({n[0] for n in nodes})
    return {n[0]: n for n in nodes}, {
        "bytes": raw.stat().st_size, "sha256": hashlib.sha256(raw.read_bytes()).hexdigest()}


def selector(nodes):
    reverse = collections.defaultdict(set)
    for name, _, _, _, deps in nodes.values():
        for dep in deps:
            reverse[dep].add(name)
    @lru_cache(maxsize=None)
    def paths_from(proof):
        assert proof in nodes, proof
        paths, queue = {proof: [proof]}, collections.deque([proof])
        while queue:
            dep = queue.popleft()
            for reader in sorted(reverse[dep]):
                if reader not in paths:
                    paths[reader] = [reader] + paths[dep]
                    queue.append(reader)
        return {n: path for n, path in paths.items() if n != proof and nodes[n][3]}

    def select(row):
        """各証拠から逆向きBFS。元の候補を優先し、なければ最短の名前付き宣言を選ぶ。"""
        proofs, preferred, hits = set(row["proofs"]), row["reader_candidates"], {}
        for proof in sorted(proofs):
            paths = paths_from(proof)
            eligible = [n for n in paths if n not in proofs]
            # private も選ぶ。生成宣言は経路として辿り、欄にはソース位置のある宣言を置く。
            chosen = [n for n in preferred if n in eligible]
            if not chosen and eligible:
                chosen = [min(eligible, key=lambda n: (len(paths[n]), n))]
            for reader in chosen:
                hits.setdefault(reader, {})[proof] = paths[reader]
        return {r: hits[r] for r in sorted(hits)}
    return select


def collect(tmp):
    nodes, raw = graph(tmp)
    select = selector(nodes)
    result = []
    for filename in ["trace.json", "connections.json"]:
        for row in json.loads((HERE / filename).read_text()):
            if "reader_candidates" not in row:
                continue
            hits = select(row)
            result.append({"kind": row["kind"], "id": row["id"], "dependencies": hits})
    return result, {"nodes": len(nodes), "raw": raw}


def verify(tmp):
    rows, source = collect(tmp)
    recorded = json.loads((HERE / "reader-dependencies.json").read_text())
    assert rows == recorded["rows"]
    assert source == recorded["source"]
    indexed = {(r["kind"], r["id"]): r for r in rows}
    for filename in ["trace.json", "connections.json"]:
        for row in json.loads((HERE / filename).read_text()):
            if "reader_candidates" not in row:
                continue
            assert row["readers"] == list(indexed[row["kind"], row["id"]]["dependencies"])
            assert row["relation"] and (row["readers"] or row["relation_kind"] != "依存する読者あり")
    return {"rows": len(rows), "with_readers": sum(bool(r["dependencies"]) for r in rows),
            "nodes": source["nodes"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    if args.verify:
        print(json.dumps(verify(args.tmp), ensure_ascii=False))
    else:
        rows, source = collect(args.tmp)
        (HERE / "reader-dependencies.json").write_text(json.dumps(
            {"source": source, "rows": rows}, ensure_ascii=False, indent=2) + "\n")
        print(json.dumps({"rows": len(rows), **source}, ensure_ascii=False))


if __name__ == "__main__":
    main()
