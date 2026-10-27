"""run-17585 の保存済み出力で routing・programs・programReports だけを照合する。"""
from collections import Counter
import hashlib
import json
from pathlib import Path
import runpy
import subprocess
import time


ROOT = Path(__file__).resolve().parents[3]
CHECKER = ROOT / "crates/benitoite/tests/desugar_export/check_named.py"
DIRECTORY = ROOT / "target/desugar-diff/run-17585"
BASE = "6db695e16bc21eedda2002630f3474632f8b64a1"


def main():
    started = time.monotonic()
    checker = runpy.run_path(str(CHECKER))
    read, require, keyed = (checker[k] for k in ("read", "require", "keyed"))
    manifest = read(checker["MANIFEST"])
    actual = checker["routing_entries"](DIRECTORY)
    baseline = json.loads(subprocess.check_output([
        "git", "show", f"{BASE}:crates/benitoite/tests/desugar_export/routing-manifest.json"
    ], cwd=ROOT, text=True))
    try:
        checker["compare_routing"](actual, baseline)
    except AssertionError as error:
        before = str(error)
        require(before == "routing identifiers: missing [], extra [('golden', 'testdata/warnings/skill-local-intervals.bnt')]",
                "unexpected baseline failure")
        print("baseline:", before, flush=True)
    else:
        raise AssertionError("baseline unexpectedly passed")
    checker["check_routing"](DIRECTORY, manifest)

    # check_programs の生成を伴わない照合と同じ条件を保存済みの入力・報告へ適用する。
    corpus = read(DIRECTORY / "named-programs-corpus.json")
    versions = manifest["namedVersions"]
    require(corpus["version"] == versions["corpus"], "general corpus version")
    expected = keyed(manifest["programs"])
    keys = [(i["group"], i["name"]) for i in corpus["inputs"]]
    require(len(keys) == len(expected) and set(keys) == set(expected), "general program routing")
    independent = read(DIRECTORY / "independent-program-corpus.json")
    require(not set(keys) & set(keyed(independent["inputs"])), "program in both general and independent inputs")
    successful = [key for key in keys if not expected[key].get("excluded")]
    for filename in ("named-programs-builtins.json", "named-programs-stdlib.json"):
        table = read(DIRECTORY / filename)
        require(table["version"] == versions["table"], filename)
        require([(i["group"], i["name"]) for i in table["inputs"]] == successful, filename)
    definitions = surface_checks = 0
    for item in corpus["inputs"]:
        entry = expected[item["group"], item["name"]]
        require(item["excluded"] == entry.get("excluded", []), item["name"])
        if item["excluded"]:
            require(item["definitions"] == [], item["name"])
            continue
        require(len(item["definitions"]) == entry["definitions"], item["name"])
        require(all(len(d["scope"]) == 1 for d in item["definitions"]), "ambiguous scope")
        scopes = dict(Counter(next(iter(d["scope"])) for d in item["definitions"]))
        require(scopes == entry.get("scopes", {"inScope": entry["definitions"]}), item["name"])
        definitions += entry["definitions"]
        surfaces = [d["scope"]["inScope"]["surface"] for d in item["definitions"] if "inScope" in d["scope"]]
        implementations = {s["implementation"] for s in surfaces if s["implementation"] is not None}
        count = sum(s["implementation"] is None for s in surfaces) + len(implementations)
        require(len(implementations) == entry.get("implementations", 0), f"{item['name']}: implementations")
        require(count == entry.get("surfaceChecks", scopes.get("inScope", 0)), f"{item['name']}: surface checks")
        surface_checks += count
    reports = manifest["programReports"]
    report = read(DIRECTORY / "report.json")
    require({g: report[g]["programs"] for g in ("golden", "random")} == reports["desugarPrograms"],
            "all program classifications")
    require(report["golden"]["definitions"] == reports["desugarDefinitions"], "general desugar")
    require(report["random"]["definitions"] == reports["randomDesugarDefinitions"], "generated desugar")
    require(read(DIRECTORY / "builtin-report.json")["errors"] == [], "general builtins")
    report = read(DIRECTORY / "surface-check/report.json")
    require(report["counts"] == reports["surfaceCounts"], "general surface")
    require(sorted((o for o in report["outcomes"] if o["category"] != "matched"),
                   key=lambda o: json.dumps(o, sort_keys=True)) == reports["surfaceOutcomes"],
            "general surface classification reasons changed")
    coverage = read(DIRECTORY / "named-programs-coverage.json")
    require(coverage["version"] == versions["coverage"], "general coverage version")
    require([(i["group"], i["name"]) for i in coverage["inputs"]] == successful, "general coverage routing")
    matches = 0
    for item in coverage["inputs"]:
        for kind, count in expected[item["group"], item["name"]]["coverage"].items():
            require(len(item[kind]) == count, f"{item['name']}: {kind}")
            matches += count
    report = read(DIRECTORY / "coverage/report.json")
    require({k: report[k] for k in reports["coverage"]} == reports["coverage"], "general coverage")
    require(definitions == reports["definitions"] and surface_checks == reports["surfaceChecks"]
            and matches == reports["coverageEntries"], "general input totals")
    print(f"programs/programReports: {len(keys)} inputs, {definitions} definitions, "
          f"{surface_checks} surface checks, {matches} coverage entries agree", flush=True)
    paths = [CHECKER, checker["MANIFEST"], CHECKER.with_name("routing-manifest.json"),
             ROOT / "crates/benitoite/testdata/warnings/skill-local-intervals.bnt", Path(__file__).resolve()]
    paths += [DIRECTORY / filename for filename in (
        "named-programs-corpus.json", "named-programs-builtins.json", "named-programs-stdlib.json",
        "named-programs-coverage.json", "independent-program-corpus.json", "report.json",
        "builtin-report.json", "surface-check/report.json", "coverage/report.json")]
    hashes = {}
    for path in paths:
        with path.open("rb") as stream:
            digest = hashlib.sha256()
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
            hashes[str(path.relative_to(ROOT))] = digest.hexdigest()
    result = dict(base=BASE, head=subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
                  before=before, inputs=len(keys), golden=len(checker["discover_golden"]()),
                  definitions=definitions, surfaceChecks=surface_checks, coverageEntries=matches,
                  exit=0, seconds=round(time.monotonic()-started, 3), sha256=hashes)
    Path(__file__).with_name("replay-summary.json").write_text(json.dumps(result, indent=2)+"\n")


if __name__ == "__main__":
    main()
