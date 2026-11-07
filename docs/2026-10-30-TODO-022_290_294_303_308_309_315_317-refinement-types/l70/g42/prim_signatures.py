#!/usr/bin/env python3
"""全ての組込みの表の書き出しで、同じ名前の組込みの署名が同じ型を持つかを数える。

data の型は表の data の宣言（`dataDecls`）と補った宣言（`supplementalData`）の名前へ、不透明型は
`opaqueNames` の公開名へ写して比べる。名前が写せない data・不透明型の出現も数える。
data 型として宣言された標準の型を不透明型として書いた出現（公開名が data の宣言にもある不透明型）も数える。

使い方: `prim_signatures.py <書き出しのディレクトリ> <出力の JSON>`
"""
import collections
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "g"))
from stream_json import events  # noqa: E402


def tables(directory):
    for path in sorted(directory.rglob("*.json")):
        with path.open("rb") as f:
            head = f.read(4096).decode("utf-8", "replace")
        if '"prims"' not in head and '"inputs":[{"admitsR"' not in head:
            continue
        for kind, key, _, item in events(path):
            if key == "inputs" and kind == "item" and isinstance(item, dict) and "prims" in item:
                yield path, item


def main():
    directory, output = Path(sys.argv[1]), Path(sys.argv[2])
    renderings = collections.defaultdict(collections.Counter)
    files = collections.defaultdict(set)
    counts = collections.Counter()
    data_as_opaque = collections.Counter()
    for path, item in tables(directory):
        counts["tableInputs"] += 1
        data = {d["name"]: d["typeName"] for d in item["dataDecls"]}
        qualified = {name: public for name, public in item["supplementalData"]}
        opaque = dict(item["opaqueNames"])
        declared = set(qualified.values())

        def rename(value):
            if isinstance(value, dict):
                if len(value) == 1 and isinstance(value.get("data"), dict):
                    name = value["data"]["name"]
                    shown = data.get(name) or qualified.get(name)
                    if shown is None:
                        counts["unnamedData"] += 1
                        shown = "?" + name
                    return {"data": {"name": shown, "args": [rename(a) for a in value["data"]["args"]]}}
                if len(value) == 1 and isinstance(value.get("opaque"), dict):
                    name = value["opaque"]["name"]
                    shown = opaque.get(name)
                    if shown is None:
                        counts["unnamedOpaque"] += 1
                        shown = "?" + name
                    elif shown in declared:
                        data_as_opaque[shown] += 1
                    return {"opaque": {"name": shown, "ix": value["opaque"]["ix"]}}
                return {k: rename(v) for k, v in value.items()}
            if isinstance(value, list):
                return [rename(v) for v in value]
            return value

        for p in item["prims"]:
            counts["prims"] += 1
            signature = json.dumps(rename({k: p[k] for k in ("tparams", "tparamKinds", "names", "params", "ret",
                                                              "eff", "rkinds", "shape")}), sort_keys=True)
            renderings[p["name"]][signature] += 1
            files[(p["name"], signature)].add(str(path.relative_to(directory)))
    differing = {}
    for name, seen in sorted(renderings.items()):
        if len(seen) > 1:
            differing[name] = [{"count": n, "files": sorted(files[(name, s)])[:5], "signature": s[:400]}
                               for s, n in seen.most_common()]
    result = {"counts": dict(counts), "primNames": len(renderings),
              "dataTypesWrittenAsOpaque": dict(data_as_opaque), "differingPrimitives": differing}
    output.write_text(json.dumps(result, ensure_ascii=False, indent=1) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "differingPrimitives"}, ensure_ascii=False))
    print("differing:", {k: len(v) for k, v in differing.items()})


if __name__ == "__main__":
    main()
