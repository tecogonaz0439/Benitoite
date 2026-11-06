#!/usr/bin/env python3
"""コーパスを一入力ずつ読み、名前の照合に必要な情報だけをLeanへ渡す。"""
import argparse
import hashlib
import json
from pathlib import Path
from records import HERE, ROOT, digest, write
from stream_json import events


def builtin_meta(value):
    return {"dataDecls": [{k: d[k] for k in ["builtin", "package", "name", "typeName", "isRecord", "extensible"]} |
                {"ctors": [{"name": c["name"], "constructorName": c.get("constructorName")}
                           for c in d["ctors"]]} for d in value["dataDecls"]],
            "prims": [{"name": p["name"]} for p in value["prims"]],
            "effects": [{"name": e["name"]} for e in value["effects"]],
            "opaqueNames": value.get("opaqueNames", [])}


def input_meta(value, table):
    ctor_table = {d["name"]: [(c["name"], c.get("constructorName") or c["name"]) for c in d["ctors"]]
                  for d in table["dataDecls"]}
    data_types = [{**d, "constructors": d.get("constructors", ctor_table.get(d["name"], []))}
                  for d in value["dataTypes"]]
    return {"group": value["group"], "name": value["name"], "dataTypes": data_types,
            "definitions": [{"name": d["name"], "scope": {"outOfScope": {"elements": []}}}
                            for d in value["definitions"]],
            "effects": [{"name": e["name"], "ops": []} for e in value["effects"]],
            "excluded": [], "constants": [], "ops": [], "primOps": [], "classes": [], "impls": [],
            "scopeAcceptance": {}, "aliases": [], "records": [], "testers": [], "externals": [],
            "logicCertificates": [], "candidates": []}


def prepare(root, destination):
    sources = sorted(p for p in root.rglob("*.json") if p.name.endswith("corpus.json"))
    rows, missing, effect_names, metadata = [], [], set(), {}
    unmatched = []
    other = 0
    with destination.open("w") as output:
        for source in sources:
            builtin = source.with_name(source.name.removesuffix("corpus.json") + "builtins.json")
            if not builtin.is_file():
                missing.append(str(source.relative_to(root)))
            builtins = {(v["group"], v["name"]): builtin_meta(v)
                        for kind, key, _, v in events(builtin) if kind == "item" and key == "inputs"} if builtin.is_file() else {}
            for kind, key, _, value in events(source):
                if kind != "item" or key != "inputs": continue
                if "dataTypes" not in value:
                    other += 1
                    continue
                name = (value["group"], value["name"])
                if name not in builtins: unmatched.append({"file":str(source.relative_to(root)),"group":name[0],"name":name[1]})
                table = builtins.get(name, {"dataDecls":[],"prims":[],"effects":[],"opaqueNames":[]})
                request = {"input": input_meta(value, table), "builtin": table}
                output.write(json.dumps(request, ensure_ascii=False, separators=(",", ":")) + "\n")
                rows.append({"file": str(source.relative_to(root)), "group": name[0], "name": name[1]})
                effect_names.update(e["name"] for e in table["effects"])
                for entry in value["dataTypes"]:
                    if entry["package"] == "stdlib" or entry["builtin"] != "ordinary":
                        metadata[json.dumps(entry, sort_keys=True)] = entry
    return {"rows": rows, "files": len(sources), "unpaired": missing, "unmatched": unmatched, "other_schema_inputs": other,
            "effects": sorted(effect_names), "standard_metadata": list(metadata.values()),
            "requests": digest(destination)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT / "target/l70-g/old-desugar")
    parser.add_argument("--requests", type=Path, required=True)
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--results", type=Path)
    args = parser.parse_args()
    if args.results:
        source = json.loads(args.summary.read_text())
        results = [json.loads(line) for line in args.results.read_text().splitlines()]
        assert len(results) == len(source["rows"]), (len(results), len(source["rows"]))
        failures = [{**source["rows"][i], "reason": row["reason"]}
                    for i, row in enumerate(results) if not row["ok"]]
        summary = {"inputs": len(results), "files": source["files"], "unpaired": source["unpaired"],
                   "accepted": sum(r["ok"] for r in results), "failed": failures,
                   "mapped_data": sum(len(r["mapping"]["data"]) for r in results if r["ok"]),
                   "mapped_constructors": sum(len(r["mapping"]["constructors"]) for r in results if r["ok"]),
                   "effects": source["effects"], "requests": digest(args.requests),
                   "results": digest(args.results)}
        write(HERE / "canonical-corpus.json", summary)
        print(json.dumps({k: summary[k] for k in ["inputs", "accepted", "files", "failed"]}, ensure_ascii=False))
    else:
        summary = prepare(args.root, args.requests)
        args.summary.write_text(json.dumps(summary, ensure_ascii=False) + "\n")
        print(json.dumps({"inputs": len(summary["rows"]), "files": summary["files"],
                          "unpaired": summary["unpaired"], "effects": summary["effects"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
