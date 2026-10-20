"""Rust の新形式の出力を版・件数の manifest と独立した Lean の入口で検査する。"""
import copy
from collections import Counter
import json
import runpy
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[4]
BIN = ROOT / "formal/.lake/build/bin"
MANIFEST = Path(__file__).with_name("exchange-manifest.json")


def read(path):
    return json.loads(path.read_text())


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def run(tool, args, report, status=0):
    report.unlink(missing_ok=True)
    process = subprocess.run([str(BIN / tool), *map(str, args), str(report)],
                             text=True, capture_output=True, timeout=60)
    report.with_suffix(".log").write_text(process.stdout + process.stderr)
    require(process.returncode == status,
            f"{tool}: expected {status}, got {process.returncode}: {process.stdout}{process.stderr}")
    return read(report) if report.exists() else None


def keyed(items, name="name"):
    result = {(i["group"], i[name]): i for i in items}
    require(len(result) == len(items), f"duplicate input identifiers: {name}")
    return result


def routing_entries(directory):
    entries = []
    for stem, coverage_file in (("named-programs-", "named-programs-coverage.json"),):
        corpus = read(directory / f"{stem}corpus.json")
        inputs = keyed(corpus["inputs"])
        coverage = keyed(read(directory / coverage_file)["inputs"])
        successful = {key for key, item in inputs.items() if not item["excluded"]}
        require(set(coverage) == successful, f"{stem}coverage input coverage")
        for filename in ("named-programs-builtins.json", "named-programs-stdlib.json"):
            require(set(keyed(read(directory / filename)["inputs"])) == successful,
                    f"{filename}: declaration input coverage")
        for key, item in inputs.items():
            scopes = Counter()
            for definition in item["definitions"]:
                require(len(definition["scope"]) == 1, f"{key}: ambiguous scope")
                scope, value = next(iter(definition["scope"].items()))
                # 対象外の理由も残し、件数だけを合わせた除外の付け替えを拒否する。
                reason = scope if scope in ("inScope", "accessor") else f"{scope}:{json.dumps(value, sort_keys=True)}"
                scopes[reason] += 1
            cov = coverage.get(key)
            entries.append({"group": key[0], "name": key[1], "version": corpus["version"],
                            "excluded": item["excluded"], "scopes": dict(scopes),
                            "coverage": None if cov is None else {k: len(cov[k]) for k in ("matches", "bindings")}})
    return entries


def compare_routing(actual, expected):
    actual, expected = keyed(actual), keyed(expected)
    require(actual.keys() == expected.keys(),
            f"routing identifiers: missing {sorted(expected.keys() - actual.keys())}, extra {sorted(actual.keys() - expected.keys())}")
    for key, entry in expected.items():
        require(actual[key] == entry, f"{key}: routing classification: {actual[key]} != {entry}")


def discover_golden():
    root = ROOT / "crates/benitoite"
    pending = [root / "testdata"]
    names = set()
    while pending:
        for path in pending.pop().iterdir():
            if path.is_dir():
                if path.name.endswith((".files", ".formatted")):
                    continue
                if Path(f"{path}.mode").is_file():
                    names.add(str(path.relative_to(root)))
                else:
                    pending.append(path)
            elif path.suffix == ".bnt":
                names.add(str(path.relative_to(root)))
    return names


def check_routing(directory, manifest):
    actual = routing_entries(directory)
    compare_routing(actual, read(MANIFEST.parent / manifest["routingManifest"]))
    require({i["name"] for i in actual if i["group"] == "golden"} == discover_golden(),
            "discovered golden input missing from final corpus")
    require({i["name"] for i in actual if i["group"] == "random"} ==
            {f"random-{seed}.bnt" for seed in range(1000)}, "generated input missing from final corpus")
    print(f"final input routing: {len(actual)} inputs, identifiers, exclusions, scopes and coverage agree")


def check_coverage_exports(directory, expected):
    for stem, entry in expected.items():
        corpus = read(directory / f"{stem}corpus.json")
        for key in ("version", "boundaryCases", "randomCases", "seedXor"):
            require(corpus[key] == entry[key], f"{stem}coverage export: {key}")
        names = [case["name"] for case in corpus["cases"]]
        require(len(names) == len(set(names)), f"{stem}coverage export: duplicate cases")
        prefix = entry.get("randomPrefix", "random/")
        require(set(names) == set(entry["boundaryNames"]) |
                {f"{prefix}{seed}" for seed in range(entry["randomCases"])},
                f"{stem}coverage export: missing or unexpected cases")


def check_named(directory, entry, versions):
    stem = entry["stem"]
    corpus_path = directory / f"{stem}-corpus.json"
    builtins = directory / f"{stem}-builtins.json"
    stdlib = directory / f"{stem}-stdlib.json"
    corpus = read(corpus_path)
    require(corpus["version"] == versions["corpus"], stem)
    require(len(corpus["inputs"]) == 1, stem)
    item = corpus["inputs"][0]
    require(item["name"] == stem and item["group"] == "golden" and not item["excluded"], stem)
    require(len(item["definitions"]) == entry["definitions"], f"{stem}: definition count")
    if "scopes" in entry:
        require(all(len(d["scope"]) == 1 for d in item["definitions"]), f"{stem}: ambiguous scope")
        scopes = Counter(next(iter(d["scope"])) for d in item["definitions"])
        require(dict(scopes) == entry["scopes"], f"{stem}: scopes")
    else:
        require(all("inScope" in d["scope"] for d in item["definitions"]), f"{stem}: outside")
    for path in (builtins, stdlib):
        table = read(path)
        require(table["version"] == versions["table"], str(path))
        require([(i["group"], i["name"]) for i in table["inputs"]] == [("golden", stem)], str(path))
    tools = {
        "desugarDiff": [corpus_path],
        "builtinCheck": [corpus_path, builtins],
        "surfaceCheck": [corpus_path, builtins, stdlib, "golden", stem],
        "surfaceCheckAll": [corpus_path, builtins, stdlib],
    }
    reports = {}
    for tool, args in tools.items():
        reports[tool] = run(tool, args, directory / f"{stem}-{tool}-report.json")
    require(reports["desugarDiff"]["golden"]["definitions"] == {
        "matched": entry["definitions"], "mismatched": 0, "outside": 0, "excluded": 0}, stem)
    require(reports["builtinCheck"]["errors"] == [], stem)
    require(reports["surfaceCheck"]["result"] == {"ok": True}, stem)
    # 実装のメソッドと上位辞書は表層では実装一件として検査するので、実装を含む例は surfaceChecks で数える。
    surface_checks = entry.get("surfaceChecks", entry.get("scopes", {}).get("inScope", entry["definitions"]))
    require(reports["surfaceCheckAll"]["counts"] == {
        "matched": surface_checks, "q11": 0, "outOfScope": 0, "lazyRestriction": 0,
        "mismatched": 0, "preparationFailure": 0}, stem)
    if entry["coverage"] is not None:
        path = directory / f"{stem}-coverage.json"
        coverage = read(path)
        require(coverage["version"] == versions["coverage"], stem)
        require(len(coverage["inputs"]) == 1, stem)
        require(coverage["inputs"][0]["name"] == stem and coverage["inputs"][0]["group"] == "golden", stem)
        for key, count in entry["coverage"].items():
            require(len(coverage["inputs"][0][key]) == count, f"{stem}: {key}")
        if sum(entry["coverage"].values()) > 0:
            report = run("coverageProgramDiff", [path, builtins], directory / f"{stem}-coverage-report.json")
            require(report["matched"] == sum(entry["coverage"].values()) and report["mismatched"] == 0
                    and report["outOfScope"] == 0 and report["fuelExhausted"] == 0, stem)
    return corpus, builtins, stdlib


def check_width(directory, expected):
    # 幅付きの実際の型検査・脱糖の出力を、全件の書き出しによる上書きから分ける。
    directory = directory / "width-smoke"
    corpus_path = directory / "corpus.json"
    builtins = directory / "builtins.json"
    stdlib = directory / "stdlib-decls.json"
    corpus = read(corpus_path)
    require(corpus["version"] == 13, "width corpus version")
    require([(i["name"], len(i["definitions"])) for i in corpus["inputs"]] ==
            [tuple(entry) for entry in expected["inputs"]], "width inputs and definitions")
    for item in corpus["inputs"]:
        require(item["excluded"] == [], item["name"])
        report = run("surfaceCheck", [corpus_path, builtins, stdlib, "golden", item["name"]],
                     directory / f"{item['name']}-surface-report.json")
        require(report["result"] == {"ok": True}, item["name"])
    report = run("desugarDiff", [corpus_path], directory / "desugar-report.json")
    require(report["golden"]["definitions"] == expected["desugarDefinitions"], "width desugar")
    report = run("builtinCheck", [corpus_path, builtins], directory / "builtin-report.json")
    require(report["errors"] == [] and report["checkedInputs"] == len(expected["inputs"]), "width builtin")
    report = run("surfaceCheckAll", [corpus_path, builtins, stdlib], directory / "surface-report.json")
    require(report["counts"] == expected["surfaceCounts"], "width surface")
    # この独立入力には照合・束縛がない。空の比較を成功として数えない入口の終了状態も保つ。
    report = run("coverageProgramDiff", [directory / "coverage.json", builtins], directory / "coverage-report.json", 1)
    require(report["matched"] == 0 and report["mismatched"] == 0 and report["outOfScope"] == 0
            and report["fuelExhausted"] == 0, "width coverage")
    print("width export: three inputs and all 30 definitions agree")


def write_selected_tables(directory, tables, key):
    paths = []
    for source, (table, inputs) in tables.items():
        path = directory / source.name
        path.write_text(json.dumps({**table, "inputs": [inputs[key]]}))
        paths.append(path)
    return paths


def check_programs(directory, manifest):
    stem = "named-programs"
    corpus_path = directory / f"{stem}-corpus.json"
    builtins = directory / f"{stem}-builtins.json"
    stdlib = directory / f"{stem}-stdlib.json"
    coverage_path = directory / f"{stem}-coverage.json"
    corpus = read(corpus_path)
    versions = manifest["namedVersions"]
    require(corpus["version"] == versions["corpus"], "general corpus version")
    expected = {(i["group"], i["name"]): i for i in manifest["programs"]}
    keys = [(i["group"], i["name"]) for i in corpus["inputs"]]
    require(len(keys) == len(expected) and set(keys) == set(expected), "general program routing")
    independent = read(directory / "independent-program-corpus.json")
    require(not set(keys) & {(i["group"], i["name"]) for i in independent["inputs"]}, "program in both general and independent inputs")
    tables = {}
    for path in (builtins, stdlib):
        table = read(path)
        require(table["version"] == versions["table"], str(path))
        require([(i["group"], i["name"]) for i in table["inputs"]] ==
                [key for key in keys if not expected[key].get("excluded")], str(path))
        tables[path] = (table, keyed(table["inputs"]))
    definitions = 0
    surface_definitions = 0
    for index, item in enumerate(corpus["inputs"]):
        if index % 100 == 0:
            print(f"single surface checks: {index}/{len(keys)} inputs", flush=True)
        entry = expected[item["group"], item["name"]]
        require(item["excluded"] == entry.get("excluded", []), item["name"])
        if item["excluded"]:
            require(item["definitions"] == [], item["name"])
            continue
        require(len(item["definitions"]) == entry["definitions"], item["name"])
        scopes = {}
        for definition in item["definitions"]:
            require(len(definition["scope"]) == 1, item["name"])
            scope = next(iter(definition["scope"]))
            scopes[scope] = scopes.get(scope, 0) + 1
        require(scopes == entry.get("scopes", {"inScope": entry["definitions"]}), item["name"])
        definitions += entry["definitions"]
        # 実装のメソッドと上位辞書は、表層では実装一件として独立に検査する。
        surfaces = [d["scope"]["inScope"]["surface"] for d in item["definitions"] if "inScope" in d["scope"]]
        implementations = {s["implementation"] for s in surfaces if s["implementation"] is not None}
        surface_checks = sum(s["implementation"] is None for s in surfaces) + len(implementations)
        require(len(implementations) == entry.get("implementations", 0), f"{item['name']}: implementations")
        require(surface_checks == entry.get("surfaceChecks", scopes.get("inScope", 0)), f"{item['name']}: surface checks")
        surface_definitions += surface_checks
        path = directory / f"{Path(item['name']).stem}-surface-report.json"
        # 単一入力の入口には対応する表だけを渡す。全件の入口は下で元の corpus を読む。
        # 各回に全入力を読み直す費用を避け、全入力の独立した単一検査を維持する。
        with tempfile.TemporaryDirectory(prefix=".named-single-", dir=directory) as temporary:
            selected = Path(temporary)
            single_corpus = selected / "corpus.json"
            single_corpus.write_text(json.dumps({**corpus, "inputs": [item]}))
            single_tables = write_selected_tables(selected, tables, (item["group"], item["name"]))
            args = [single_corpus, *single_tables, item["group"], item["name"]]
            if "singleSurfaceFailure" in entry:
                report = run("surfaceCheck", args, path, 1)
                require(report["result"] == entry["singleSurfaceFailure"], item["name"])
            else:
                report = run("surfaceCheck", args, path)
                require(report["result"] == {"ok": True}, item["name"])
    report = run("desugarDiff", [corpus_path], directory / f"{stem}-desugar-report.json")
    require({group: report[group]["programs"] for group in ("golden", "random")} ==
            manifest["programReports"]["desugarPrograms"], "all program classifications")
    require(report["golden"]["definitions"] == manifest["programReports"]["desugarDefinitions"], "general desugar")
    require(report["random"]["definitions"] == manifest["programReports"]["randomDesugarDefinitions"], "generated desugar")
    report = run("builtinCheck", [corpus_path, builtins], directory / f"{stem}-builtin-report.json")
    require(report["errors"] == [], "general builtins")
    report = run("surfaceCheckAll", [corpus_path, builtins, stdlib], directory / f"{stem}-surface-report.json")
    require(report["counts"] == manifest["programReports"]["surfaceCounts"], "general surface")
    require(sorted((o for o in report["outcomes"] if o["category"] != "matched"),
                   key=lambda o: json.dumps(o, sort_keys=True)) == manifest["programReports"]["surfaceOutcomes"],
            "general surface classification reasons changed")
    coverage = read(coverage_path)
    require(coverage["version"] == versions["coverage"], "general coverage version")
    require([(i["group"], i["name"]) for i in coverage["inputs"]] ==
            [key for key in keys if not expected[key].get("excluded")], "general coverage routing")
    matches = 0
    for item in coverage["inputs"]:
        counts = expected[item["group"], item["name"]]["coverage"]
        for kind, count in counts.items():
            require(len(item[kind]) == count, f"{item['name']}: {kind}")
            matches += count
    report = run("coverageProgramDiff", [coverage_path, builtins], directory / f"{stem}-coverage-report.json")
    require({k: report[k] for k in manifest["programReports"]["coverage"]} ==
            manifest["programReports"]["coverage"], "general coverage")
    require(definitions == manifest["programReports"]["definitions"]
            and surface_definitions == manifest["programReports"]["surfaceChecks"]
            and matches == manifest["programReports"]["coverageEntries"], "general input totals")
    print(f"named programs: {len(keys)} inputs, {definitions} definitions, {matches} coverage entries agree")
    check_special_rejections(directory, corpus, tables)
    check_program_rejections(directory, corpus, tables)


def nodes(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from nodes(child)
    elif isinstance(value, list):
        for child in value:
            yield from nodes(child)


def check_program_rejections(directory, original, tables):
    # 静的な準備入力だけでなく、一般の解析・型検査を通った穴・挿入も壊す。
    results = []
    with tempfile.TemporaryDirectory(prefix="named-program-mutations-", dir=directory) as temp:
        temp = Path(temp)
        original_item = next(i for i in original["inputs"] if i["name"].endswith("named_partials.bnt"))
        key = original_item["group"], original_item["name"]
        single_tables = write_selected_tables(temp, tables, key)
        for mode in ("hole-label", "hole-position", "hole-contract", "hole-order", "pipe-label", "pipe-position"):
            item = copy.deepcopy(original_item)
            # 全件の正の比較は上で済ませる。破損箇所以外は複製せず、順序の
            # 脱糖比較では元の全入力と注釈の件数も保持する。
            inputs = ([item if i is original_item else i for i in original["inputs"]]
                      if mode == "hole-order" else [item])
            corpus = {**original, "inputs": inputs}
            surfaces = [d["scope"]["inScope"]["surface"] for d in item["definitions"]]
            expressions = [n for surface in surfaces for n in nodes(surface["body"])]
            if mode.startswith("hole-"):
                partial = next(n["partialCall"] for n in expressions if "partialCall" in n
                               and n["partialCall"]["names"] == ["a", "b"]
                               and (mode != "hole-order" or all("hole" in a for a in n["partialCall"]["args"])))
                hole = next(a["hole"] for a in partial["args"] if "hole" in a)
                reason = "partial call labels and positions do not match the contract"
                if mode == "hole-label":
                    hole["label"] = "fake"
                elif mode == "hole-position":
                    hole["position"] = 0
                elif mode == "hole-contract":
                    partial["names"].reverse()
                    reason = "partial call contract annotation mismatch"
                else:
                    partial["args"].reverse()
            else:
                call = next(n["pipe"]["rhs"]["call"] for n in expressions if "pipe" in n
                            and n["pipe"]["rhs"].get("call", {}).get("positions") == [1])
                if mode == "pipe-label":
                    call["labels"][0] = "a"
                else:
                    call["positions"][0] = 0
                reason = "pipe labels and positions do not match the contract"
            path = temp / "corpus.json"
            path.write_text(json.dumps(corpus))
            if mode == "hole-order":
                report = run("desugarDiff", [path], temp / "report.json", 1)
                require(len(report["mismatches"]) == 1, mode)
                results.append({"mutation": mode, "tool": "desugarDiff", "mismatches": 1})
            else:
                report = run("surfaceCheck", [path, *single_tables, item["group"], item["name"]],
                             temp / "report.json", 1)
                require(report["result"]["ok"] is False and report["result"]["error"]["reason"] == reason, mode)
                results.append({"mutation": mode, "tool": "surfaceCheck", "error": report["result"]["error"]})
    (directory / "named-program-mutations-report.json").write_text(json.dumps(results, indent=2) + "\n")
    print("named checked programs: six hole/pipe mutations rejected for the intended reason")


def check_special_rejections(directory, original, tables):
    # 宣言名・実装の実名・辞書の内部名を独立に壊し、名前の検査そのものを確かめる。
    with tempfile.TemporaryDirectory(prefix="named-special-", dir=directory) as temp:
        temp = Path(temp)
        for mode in ("method-user", "method-dictionary", "operation"):
            suffix = "named_operations.bnt" if mode == "operation" else "named_methods.bnt"
            item = copy.deepcopy(next(i for i in original["inputs"] if i["name"].endswith(suffix)))
            corpus = {**original, "inputs": [item]}
            single_tables = write_selected_tables(temp, tables, (item["group"], item["name"]))
            if mode == "method-user":
                surface = next(d["scope"]["inScope"]["surface"] for d in item["definitions"]
                               if d["scope"]["inScope"]["surface"]["method"] is not None)
                surface["header"]["names"][0] = "wrong"
            elif mode == "method-dictionary":
                method = next(m for c in item["classes"] for m in c["methods"]
                              if m["header"]["names"][0] == "%dict1")
                method["header"]["names"][0] = "wrong"
            else:
                item["ops"][0]["header"]["names"][0] = "wrong"
            path = temp / "corpus.json"
            path.write_text(json.dumps(corpus))
            report = run("surfaceCheck", [path, *single_tables, item["group"], item["name"]],
                         temp / "report.json", 1)
            reason = ("call labels and positions do not match the contract" if mode == "operation"
                      else "implementation method parameter names mismatch")
            require(report["result"]["ok"] is False and report["result"]["error"]["reason"] == reason, mode)
    print("named special export: three contract mutations rejected for the intended reason")


def calls(corpus):
    return corpus["inputs"][0]["definitions"]


def expression(definition):
    return definition["scope"]["inScope"]["surface"]["body"]["last"]["expr"]["returnE"]["inner"]


def check_rejections(directory, ordinary, static):
    # Rust が書き出した正常入力を一欄ずつ壊す。別の型エラーでの拒否にはしない。
    with tempfile.TemporaryDirectory(prefix="named-export-", dir=directory) as temp:
        temp = Path(temp)
        for mode in ("label", "position", "source-order", "hole", "partial", "inserted"):
            original, builtins, stdlib = static if mode in ("hole", "partial", "inserted") else ordinary
            corpus = copy.deepcopy(original)
            if mode in ("hole", "partial"):
                c = expression(calls(corpus)[0])["partialCall"]
                if mode == "hole": c["args"][0]["hole"]["label"] = "fake"
                else: c["names"] = ["b", "a"]
                reason = "partial call labels and positions" if mode == "hole" else "partial call contract annotation"
            elif mode == "inserted":
                expression(calls(corpus)[1])["pipe"]["rhs"]["call"]["positions"] = [0]
                reason = "pipe labels and positions"
            else:
                definition = next(d for d in calls(corpus) if d["name"].startswith("sample ("))
                c = expression(definition)["call"]
                if mode == "label": c["labels"][0] = "fake"
                elif mode == "position": c["positions"] = [0, 0]
                else: c["args"].reverse()
                reason = "call labels and positions"
            path = temp / "corpus.json"
            path.write_text(json.dumps(corpus))
            if mode == "source-order":
                report = run("desugarDiff", [path], temp / "report.json", 1)
                require(len(report["mismatches"]) == 1, mode)
            else:
                stem = corpus["inputs"][0]["name"]
                report = run("surfaceCheck", [path, builtins, stdlib, "golden", stem], temp / "report.json", 1)
                require(report["result"]["ok"] is False and reason in report["result"]["error"]["reason"], mode)
    print("named export: six mutations rejected for the intended reason")


def check_extensible_package(directory):
    stem = 'extensible-package'
    corpus = read(directory / f'{stem}-corpus.json')
    item = corpus['inputs'][0]
    info = next(d for d in item['dataTypes'] if d['typeName'] == 'IOErrorKind')
    require(info['package'] == 'stdlib' and info['extensible'], 'external IO type metadata')
    standard = [d for d in item['dataTypes'] if d['package'] == 'stdlib' and d['extensible']]
    require([(d['typeName'], d['isRecord']) for d in standard] ==
            [('IOErrorKind', False), ('NetworkErrorKind', False), ('ParseError', True), ('ParseError', True), ('ConversionError', True)],
            'five extensible standard failure types')
    body = next(d['scope']['inScope']['surface'] for d in item['definitions']
                if 'inspect (' in d['name'])
    require(body['package'] == 'package:Dep' and body['coverageView'] == [d['name'] for d in standard],
            'dependency body must include external IOErrorKind')
    require(item['constants'][0]['package'] == 'package:Dep', 'constant declaration package')
    with tempfile.TemporaryDirectory(prefix='benitoite-export-view-') as temp:
        temp = Path(temp)
        for tool in ('desugarDiff', 'builtinCheck', 'surfaceCheck', 'surfaceCheckAll'):
            broken = copy.deepcopy(corpus)
            target = next(d['scope']['inScope']['surface'] for d in broken['inputs'][0]['definitions']
                          if 'inspect (' in d['name'])
            target['coverageView'].remove(info['name'])
            path = temp / 'corpus.json'
            path.write_text(json.dumps(broken))
            args = [path]
            if tool != 'desugarDiff': args.append(directory / f'{stem}-builtins.json')
            if tool.startswith('surface'): args.append(directory / f'{stem}-stdlib.json')
            if tool == 'surfaceCheck': args += ['golden', stem]
            report = temp / f'{tool}.json'
            run(tool, args, report, status=2)
            require('coverage view/package mismatch' in report.with_suffix('.log').read_text(),
                    f'{tool}: omitted external IOErrorKind rejection')
        broken = read(directory / f'{stem}-coverage.json')
        broken['inputs'][0]['matches'][0]['coverageView'].remove(info['name'])
        path = temp / 'coverage.json'
        path.write_text(json.dumps(broken))
        report = temp / 'coverageProgramDiff.json'
        run('coverageProgramDiff', [path, directory / f'{stem}-builtins.json'], report, status=2)
        require('coverage view/package mismatch' in report.with_suffix('.log').read_text(),
                'coverageProgramDiff: omitted external IOErrorKind rejection')
    print('external package export: IOErrorKind view and constant declaration package agree')


def main():
    directory, coverage_dir = map(Path, sys.argv[1:])
    manifest = read(MANIFEST)
    batch2 = runpy.run_path(str(ROOT / "formal/tests/test_batch2_exchange.py"))
    for feature in ("op", "failure", "character"):
        batch2["check_rust"](ROOT / f"target/formal-batch2-{feature}")
    failure = runpy.run_path(str(Path(__file__).with_name("check_failure.py")))
    failure["check"](ROOT / "target/formal-batch2-failure")
    character = read(ROOT / "target/formal-batch2-character/corpus.json")
    require({i["name"]: len(i["definitions"]) for i in character["inputs"]} == manifest["batch2Character"]["definitions"], "batch2 character definitions")
    check_routing(directory, manifest)
    check_coverage_exports(coverage_dir, manifest["coverageExports"])
    check_width(directory, manifest["width"])
    check_programs(directory, manifest)
    outputs = {entry["stem"]: check_named(directory, entry, manifest["namedVersions"])
               for entry in manifest["named"]}
    coverage = coverage_dir / "named-corpus.json"
    data = read(coverage)
    # 独立Coverageの版4と、corpus13に付くプログラムsidecarの版5は別契約。
    require(data["version"] == manifest["coverageExports"]["named-"]["version"], "coverage version")
    require(len(data["cases"]) == manifest["namedCoverageCases"], "coverage cases")
    report = run("coverageDiff", [coverage], coverage_dir / "named-report.json")
    require(report["matched"] == manifest["namedCoverageCases"] and report["mismatched"] == 0
            and report["fuelExhausted"] == 0, "named coverage")
    check_extensible_package(directory)
    check_rejections(directory, outputs["named-calls"], outputs["named-static-calls"])
    print("final routing, per-program exports and rejection checks passed; checking all independent coverage", flush=True)
    # 独立した全件の網羅性に差があっても、先に他の六入口と固定記録を照合する。
    # 全件一致の条件と失敗の終了状態は維持する（設計書 07-04「01-12 との対応」）。
    report = run("coverageDiff", [coverage_dir / "named-all-corpus.json"], coverage_dir / "named-all-report.json")
    require({k: report[k] for k in manifest["allCoverageReport"]} == manifest["allCoverageReport"], "all independent coverage")
    # view付きの全件はcheck-formal.shが先に比較済みであり、その報告の件数も固定する。
    future = read(coverage_dir / "future-report.json")
    require({k: future[k] for k in manifest["futureCoverageReport"]} == manifest["futureCoverageReport"],
            "all independent coverage with views")
    print("named export: manifest agrees; corpus 13, tables/program coverage 5 and independent coverage 4 match all six entries")


if __name__ == "__main__":
    main()
