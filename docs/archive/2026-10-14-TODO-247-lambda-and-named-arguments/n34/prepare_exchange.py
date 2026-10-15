"""N33 の基準から、全入力を新形式へ移す manifest を導く。"""
import collections
import copy
import json
from pathlib import Path
import sys

BASE = Path(__file__).resolve().parents[1]
ROOT = BASE.parents[1]
sys.path.insert(0, str(ROOT / "crates/benitoite/tests/desugar_export"))
import check_named as check


def write(name, value):
    (BASE / "n34" / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def main():
    directory = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    manifest = check.read(BASE / "n33/exchange-manifest.json")
    previous = check.read(BASE / "n33/routing-manifest.json")
    expected = [{**entry, "version": 8} for entry in previous]
    if directory is not None:
        actual = check.routing_entries(directory)
        check.compare_routing(actual, expected)
    old_programs = check.keyed(manifest["programs"])
    programs = []
    for baseline in previous:
        key = baseline["group"], baseline["name"]
        if key in old_programs:
            programs.append(old_programs[key])
            continue
        assert baseline["version"] == 7
        assert set(baseline["scopes"]) <= {"inScope", "accessor"}
        programs.append(dict(group=key[0], name=key[1], excluded=baseline["excluded"],
                             definitions=sum(baseline["scopes"].values()), scopes=baseline["scopes"],
                             coverage=baseline["coverage"], implementations=0,
                             surfaceChecks=baseline["scopes"].get("inScope", 0)))
    old = copy.deepcopy(manifest["legacyReports"])
    pr = manifest["programReports"]
    pr["desugarDefinitions"]["matched"] += old["desugar"]["golden"]["definitions"]["matched"]
    pr["surfaceCounts"]["matched"] += old["surface"]["counts"]["matched"]
    pr["coverage"]["matched"] += old["programCoverage"]["matched"]
    pr["definitions"] += old["desugar"]["golden"]["definitions"]["matched"]
    pr["surfaceChecks"] += sum(old["surface"]["counts"].values())
    pr["coverageEntries"] += old["programCoverage"]["matched"]
    pr["desugarPrograms"] = {
        group: dict(matched=sum(e["group"] == group and not e["excluded"] for e in expected),
                    excluded=sum(e["group"] == group and bool(e["excluded"]) for e in expected),
                    outside=0, mismatched=0) for group in ("golden", "random")}
    manifest["programs"] = programs
    manifest["legacy"] = {**manifest["legacy"], "golden": 1, "excluded": 0,
                          "singleSurfaceInput": "independent-legacy.bnt"}
    legacy = manifest["legacyReports"]
    legacy["desugar"]["golden"]["programs"].update(matched=1, excluded=0)
    legacy["desugar"]["golden"]["definitions"]["matched"] = 1
    legacy["builtin"]["checkedInputs"] = 1
    legacy["coverage"]["matched"] = 1
    legacy["programCoverage"].update(inputs=1, cases=1, matched=1)
    legacy["programCoverage"]["matches"].update(cases=1, matched=1)
    legacy["surface"].update(inputs=1, excludedInputs=0, fullyCheckedInputs=1)
    legacy["surface"]["counts"]["matched"] = 1
    manifest["allCoverageReport"] = old["coverage"]
    manifest["coverageExports"]["named-all-"] = {**manifest["coverageExports"][""], "version": 2}
    manifest["coverageExports"][""] = dict(version=1, seedXor=0, boundaryCases=1, randomCases=0,
                                             boundaryNames=["independent-legacy/wild"])
    manifest["generalNamedCallRouting"] = "all-programs"
    manifest["width"] = dict(inputs=[["width-signed.bnt", 12], ["width-unsigned.bnt", 13], ["width-float.bnt", 5]],
                            desugarDefinitions=dict(matched=30, mismatched=0, outside=0, excluded=0),
                            surfaceCounts=dict(matched=30, mismatched=0, outOfScope=0, q11=0, lazyRestriction=0, preparationFailure=0))
    write("exchange-manifest.json", manifest)
    write("routing-manifest.json", expected)
    write("routing-changes.json", [dict(group=e["group"], name=e["name"], before=e["version"], after=8)
                                  for e in previous if e["version"] != 8])
    write("exchange-derivation.json", dict(inputs=len(expected),
          moved=collections.Counter("excluded" if e["excluded"] else "successful" for e in previous if e["version"] == 7),
          definitions=pr["definitions"], surfaceChecks=pr["surfaceChecks"], coverageEntries=pr["coverageEntries"],
          identifiers_unchanged=True, classifications_unchanged=True, independentCoverage=old["coverage"]["matched"]))


if __name__ == "__main__":
    main()
