"""Rust の新形式の出力を版・件数の manifest と独立した Lean の入口で検査する。"""
import copy
from collections import Counter
import json
import re
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


def run(tool, args, report, status=0, timeout=60):
    report.unlink(missing_ok=True)
    process = subprocess.run([str(BIN / tool), *map(str, args), str(report)],
                             text=True, capture_output=True, timeout=timeout)
    report.with_suffix(".log").write_text(process.stdout + process.stderr)
    # 終了状態は一つか、結果の中身で判定を続ける入口のための組で指定する。
    allowed = status if isinstance(status, tuple) else (status,)
    require(process.returncode in allowed,
            f"{tool}: expected {status}, got {process.returncode}: {process.stdout}{process.stderr}")
    return read(report) if report.exists() else None


# 標準表との差で準備の段が断った表層の検査。最初の準備の失敗で止めず、原因とともに残す。
# 分類の表と残りの入力の照合は formal/tests/test_range_sources.py の preparation_gaps・classified_all を使う。
PREPARATION_REJECTED = []
_SOURCES = []


def sources():
    if not _SOURCES:
        _SOURCES.append(runpy.run_path(str(ROOT / "formal/tests/test_range_sources.py")))
    return _SOURCES[0]


def preparation_gaps(text):
    return sources()["preparation_gaps"](text)


def run_surface(tool, args, report, status=0):
    """表層の検査の入口を実行する。準備の段が標準表との差（分類の表の原因）だけで断ったときは、その原因を
    PREPARATION_REJECTED に残す。単独の入口は None を返す。全件の入口は、残りの入力の照合（不一致0・準備の失敗の
    件数・末尾の照合の件数）を行い、報告に分類（欄 classified）を付けて返す。ほかの失敗は run と同じく止める。"""
    try:
        return run(tool, args, report, status)
    except AssertionError as error:
        if f"got 2:" not in str(error):
            raise
        if tool == "surfaceCheck":
            gaps = preparation_gaps(str(error))
            if gaps is None:
                raise
            PREPARATION_REJECTED.append({"tool": tool, "report": report.name, **gaps})
            return None
        if not report.exists():
            raise
        result = classify_all(tool, report, read(report), Path(args[0]))
        if result is None:
            raise
        return result


def classify_all(tool, report, result, corpus_path):
    """全件の入口の報告の準備の拒否が全て分類の表の原因なら、残りの入力を照合し、分類（欄 classified）を付けて返す。
    分類できない拒否があれば None を返す。"""
    gaps = sources()["classified_all"](result, read(corpus_path))
    if gaps is None:
        return None
    PREPARATION_REJECTED.append({"tool": tool, "report": report.name, **gaps})
    result["classified"] = gaps
    return result


def remaining_counts(expected, outcomes, report, checks):
    """全件の入口の期待の件数から、分類した拒否で準備の段が断った入力の分を除く。outcomes は期待の一致以外の
    結果（欄 input と category）、checks は入力ごとの表層の検査の件数である。"""
    gaps = report.get("classified")
    if gaps is None:
        return expected, outcomes
    rejected = set(gaps["rejected"])
    kept = [o for o in outcomes if o["input"] not in rejected]
    counts = {k: 0 for k in expected}
    for o in kept:
        counts[o["category"]] = counts.get(o["category"], 0) + 1
    counts["matched"] = expected["matched"] - sum(checks[n] - sum(o["input"] == n for o in outcomes)
                                                  for n in rejected)
    counts["preparationFailure"] = len(rejected)
    return counts, kept


def preparation_summary():
    causes = Counter(c for entry in PREPARATION_REJECTED for c in entry["causes"])
    return {"rejected": len(PREPARATION_REJECTED), "causes": dict(sorted(causes.items())),
            "entries": PREPARATION_REJECTED}


def non_top_ranges(value):
    """候補の欄を除き、比較する型・項に現れる非Topの範囲を数える。"""
    if isinstance(value, list):
        return sum(non_top_ranges(v) for v in value)
    if not isinstance(value, dict):
        return 0
    total = 0
    for key, child in value.items():
        if key == "candidates":
            continue
        if key == "ix" and isinstance(child, dict) and child.get("fixed", "top") != "top":
            total += 1
        if key == "ranges":
            # 範囲の実引数は範囲の位置（`fixed`・`rvar`）で書く。
            total += sum(r != {"fixed": "top"} for r in child)
        total += non_top_ranges(child)
    return total


def without_candidates(value):
    # 版16の入力は candidates を必須の欄とするので、欄を除かず空にする。
    if isinstance(value, list):
        return [without_candidates(v) for v in value]
    if isinstance(value, dict):
        return {k: ([] if k == "candidates" else without_candidates(v)) for k, v in value.items()}
    return value


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


def relocation_independent_routing(entry):
    """NoMainFileが指す同じ入力の場所だけを、リポジトリの移動に依存しない形にする。"""
    excluded = []
    for reason in entry["excluded"]:
        found = re.fullmatch(r'entry: NoMainFile \{ dir: (".*") \}', reason)
        if found:
            directory = json.loads(found[1])
            suffix = (Path("crates/benitoite") / entry["name"]).as_posix()
            require(directory == suffix or (Path(directory).is_absolute() and directory.endswith("/" + suffix)),
                    f"{entry['name']}: NoMainFile does not refer to the input directory")
            reason = 'entry: NoMainFile { dir: ' + json.dumps(suffix) + ' }'
        excluded.append(reason)
    return {**entry, "excluded": excluded}


def compare_routing(actual, expected):
    actual = keyed([relocation_independent_routing(entry) for entry in actual])
    expected = keyed([relocation_independent_routing(entry) for entry in expected])
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
    range_count = None
    if entry.get("rangeComparison"):
        # 候補だけに非Topが残る退行も拒む。報告の件数は候補を除いた実際の入力で得る。
        range_corpus = without_candidates(corpus)
        range_count = non_top_ranges(range_corpus)
        require(range_count > 0, f"{stem}: all-Top range comparison")
        corpus_path = directory / f"{stem}-ranges-corpus.json"
        corpus_path.write_text(json.dumps(range_corpus) + "\n")
    tools = {
        "desugarDiff": [corpus_path],
        "builtinCheck": [corpus_path, builtins],
        "surfaceCheck": [corpus_path, builtins, stdlib, "golden", stem],
        "surfaceCheckAll": [corpus_path, builtins, stdlib],
    }
    reports = {}
    single_rejections = []
    for tool, args in tools.items():
        runner = run_surface if tool.startswith("surface") else run
        before = len(PREPARATION_REJECTED)
        # 脱糖の比較は既知の差（KNOWN_PROGRAM_DESUGAR_DIFFERENCES）があると 1 で終わるので、中身で判定する。
        reports[tool] = runner(tool, args, directory / f"{stem}-{tool}-report.json",
                               (0, 1) if tool == "desugarDiff" else 0)
        if tool == "surfaceCheck" and reports[tool] is None:
            single_rejections = PREPARATION_REJECTED[before:]
    # 既知の差を除き、除いた件数を manifest の entry（欄 desugarKnownDifferences。なければ0件）と照らす。
    reports["desugarDiff"], known = classify_program_desugar(reports["desugarDiff"], read(corpus_path))
    require(known == entry.get("desugarKnownDifferences", {group: {"programs": 0, "definitions": 0}
                                                           for group in ("golden", "random")}),
            f"{stem}: known desugar differences {known}")
    require(reports["desugarDiff"]["golden"]["definitions"] == {
        "matched": entry["definitions"], "mismatched": 0, "outside": 0, "excluded": 0}, stem)
    surface_rejected = "classified" in reports["surfaceCheckAll"]
    # 準備の段の分類した拒否は、programs と同じく entry ごとに原因を manifest（欄 preparationRejected）へ記録して
    # 照合する。単独と全件の入口が同じ入力を同じ原因で断ったことも確かめる。
    recorded = entry.get("preparationRejected")
    classified = reports["surfaceCheckAll"].get("classified")
    require(([e["causes"] for e in single_rejections] == [recorded] if recorded is not None else not single_rejections)
            and ((classified["rejected"], classified["causes"]) == ([stem], recorded)
                 if recorded is not None else classified is None or classified["rejected"] == []),
            f"{stem}: preparation rejections differ from the manifest: single "
            f"{[e['causes'] for e in single_rejections]}, all {classified and classified['causes']}")
    if range_count is not None:
        for tool in ("desugarDiff", "surfaceCheckAll"):
            if tool == "desugarDiff" or not surface_rejected:
                require(reports[tool]["nonTopRanges"] == range_count > 0,
                        f"{stem}: {tool}: range count differs or all Top")
    require(reports["builtinCheck"]["errors"] == [], stem)
    if reports["surfaceCheck"] is not None:
        require(reports["surfaceCheck"]["result"] == {"ok": True}, stem)
    # 実装のメソッドと上位辞書は表層では実装一件として検査するので、実装を含む例は surfaceChecks で数える。
    surface_checks = entry.get("surfaceChecks", entry.get("scopes", {}).get("inScope", entry["definitions"]))
    expected_counts, _ = remaining_counts({
        "matched": surface_checks, "q11": 0, "outOfScope": 0, "lazyRestriction": 0,
        "mismatched": 0, "preparationFailure": 0}, [], reports["surfaceCheckAll"], {stem: surface_checks})
    require(reports["surfaceCheckAll"]["counts"] == expected_counts, stem)
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
    require(corpus["version"] == 16, "width corpus version")
    require([(i["name"], len(i["definitions"])) for i in corpus["inputs"]] ==
            [tuple(entry) for entry in expected["inputs"]], "width inputs and definitions")
    for item in corpus["inputs"]:
        require(item["excluded"] == [], item["name"])
        report = run_surface("surfaceCheck", [corpus_path, builtins, stdlib, "golden", item["name"]],
                             directory / f"{item['name']}-surface-report.json")
        if report is not None:
            require(report["result"] == {"ok": True}, item["name"])
    report = run("desugarDiff", [corpus_path], directory / "desugar-report.json")
    require(report["golden"]["definitions"] == expected["desugarDefinitions"], "width desugar")
    report = run("builtinCheck", [corpus_path, builtins], directory / "builtin-report.json")
    require(report["errors"] == [] and report["checkedInputs"] == len(expected["inputs"]), "width builtin")
    report = run_surface("surfaceCheckAll", [corpus_path, builtins, stdlib], directory / "surface-report.json")
    counts, _ = remaining_counts(expected["surfaceCounts"], [], report,
                                 {name: definitions for name, definitions in expected["inputs"]})
    require(report["counts"] == counts, "width surface")
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


# 全件の脱糖の比較の既知の差。名前を一つずつ挙げず、経路・定義の種類・中身の形で数える。分類した件数は manifest の
# programReports.desugarKnownDifferences と照合し、差が増えても消えても失敗にする。列挙の外の差は不一致のまま失敗にする。
KNOWN_PROGRAM_DESUGAR_DIFFERENCES = [
    {"path": "definition.header.ret", "scope": "accessor", "shape": "accessor field refinement",
     "reason": "篩付きの脱糖は取得関数の結果型に欄の関係の篩を付ける（Surface.accessorRet）が、処理系の書き出しの"
               "コアは付けない（formal/tests/test_named_exchange.py の KNOWN_DESUGAR_DIFFERENCES と同じ差）",
     "obligation": "R10b（R 段への義務6）: 処理系の脱糖と書き出しが取得関数の結果型に同じ篩を付けたら、この列挙と "
                   "manifest の desugarKnownDifferences を除く"},
]
_NAMED_EXCHANGE = []


def known_shape(known, mismatch):
    # 差の中身の形の判定は、手書きの交換の既知の差と同じ関数を使い、二つの判定が分かれないようにする。
    if not _NAMED_EXCHANGE:
        _NAMED_EXCHANGE.append(runpy.run_path(str(ROOT / "formal/tests/test_named_exchange.py")))
    return _NAMED_EXCHANGE[0]["known_shape"](known, mismatch)


def known_program_difference(mismatch, definitions):
    """既知の差の行に当たれば、その行を返す。定義の種類と中身の形に加え、定義の全体で差が結果型だけにあることを
    確かめ、同じ経路で別の差が隠れることを防ぐ。"""
    definition = definitions.get((mismatch["group"], mismatch["input"], mismatch["definition"]))
    for known in KNOWN_PROGRAM_DESUGAR_DIFFERENCES:
        if (mismatch["path"] != known["path"] or definition is None or set(definition["scope"]) != {known["scope"]}
                or not known_shape(known, mismatch)):
            continue
        expected, actual = copy.deepcopy(mismatch["expectedDefinition"]), mismatch["actualDefinition"]
        if expected["header"]["ret"] != mismatch["expected"] or actual["header"]["ret"] != mismatch["actual"]:
            continue
        expected["header"]["ret"] = mismatch["actual"]
        if expected == actual:
            return known
    return None


def classify_program_desugar(report, corpus):
    """全件の desugarDiff の報告から既知の差を除いた報告と、群ごとの分類した件数を返す。"""
    definitions = {(i["group"], i["name"], d["name"]): d for i in corpus["inputs"] for d in i["definitions"]}
    unknown = [m for m in report["mismatches"] if known_program_difference(m, definitions) is None]
    require(not unknown, f"general desugar: {len(unknown)} differences outside the known shapes; "
            f"first: {json.dumps(unknown[:1])[:2000]}")
    report = copy.deepcopy(report)
    classified = {}
    for group in ("golden", "random"):
        found = [m for m in report["mismatches"] if m["group"] == group]
        keys = {(m["input"], m["definition"]) for m in found}
        programs = {m["input"] for m in found}
        counts = report[group]
        # 不一致の定義ごとに差の記録が一件ずつあり、不一致のプログラムが全て差の記録を持つことを確かめる。
        # 記録の省略で、分類していない不一致が件数だけ一致に移ることを防ぐ。
        require(len(keys) == len(found) == counts["definitions"]["mismatched"]
                and len(programs) == counts["programs"]["mismatched"],
                f"general desugar: {group}: mismatch records do not cover the mismatched counts")
        for kind, moved in (("definitions", len(found)), ("programs", len(programs))):
            counts[kind]["matched"] += moved
            counts[kind]["mismatched"] -= moved
        classified[group] = {"programs": len(programs), "definitions": len(found)}
    report["mismatches"] = []
    return report, classified


def full_report(tool, args, shared, fallback, status=0):
    """check-formal.sh が同じ入力で書いた全件の報告を読む。新しい Lean では全件の入口が長い（surfaceCheckAll は
    数時間）ので再実行しない。報告がなければ従来どおりこの台本で実行する。"""
    if not shared.exists():
        runner = run_surface if tool.startswith("surface") else run
        return runner(tool, args, fallback, status)
    # 報告は scripts/check-formal.sh の同じ入力のパスへの実行の出力である（同じ出力ディレクトリ・同じ入力ファイル）。
    # 入力の書き出しより古い報告は、別の入力に対する結果のおそれがあるので使わない。
    # 入口の終了状態は報告にも check-formal.sh の出力にも残らない（status は最後の非0で上書きされる）ので照らさない。
    # 終了状態が表す結果は、呼び出し側が報告の中身で判定する: desugarDiff は不一致の記録と群ごとの件数、builtinCheck は
    # errors と入力の一覧、surfaceCheckAll は counts（mismatched・preparationFailure を含む）・preparationErrors・outcomes。
    # 入口が途中で失敗して報告を書かなければ、報告は入力より古いか存在しないので、上の時刻の照合か従来の実行に落ちる。
    stale = [str(Path(a).name) for a in args if shared.stat().st_mtime < Path(a).stat().st_mtime]
    require(not stale, f"{tool}: {shared.name} is older than its inputs {stale}")
    print(f"{tool}: reading the report written by check-formal.sh ({shared.relative_to(shared.parents[1])})", flush=True)
    result = read(shared)
    if tool == "surfaceCheckAll" and (result["counts"]["preparationFailure"] or result.get("preparationErrors")):
        result = classify_all(tool, shared, result, Path(args[0]))
        require(result is not None, f"{tool}: preparation rejection outside the classified causes")
    return result


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
    checks_by_input = {}
    single_rejected = []
    for index, item in enumerate(corpus["inputs"]):
        if index % 100 == 0:
            print(f"single surface checks: {index}/{len(keys)} inputs", flush=True)
        entry = expected[item["group"], item["name"]]
        expected_entry = {**entry, "excluded": entry.get("excluded", [])}
        require(relocation_independent_routing(item)["excluded"] ==
                relocation_independent_routing(expected_entry)["excluded"], item["name"])
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
        checks_by_input[item["name"]] = surface_checks
        path = directory / f"{Path(item['name']).stem}-surface-report.json"
        # 単一入力の入口には対応する表だけを渡す。全件の入口は下で元の corpus を読む。
        # 各回に全入力を読み直す費用を避け、全入力の独立した単一検査を維持する。
        with tempfile.TemporaryDirectory(prefix=".named-single-", dir=directory) as temporary:
            selected = Path(temporary)
            single_corpus = selected / "corpus.json"
            single_corpus.write_text(json.dumps({**corpus, "inputs": [item]}))
            single_tables = write_selected_tables(selected, tables, (item["group"], item["name"]))
            args = [single_corpus, *single_tables, item["group"], item["name"]]
            report = run_surface("surfaceCheck", args, path, 1 if "singleSurfaceFailure" in entry else 0)
            # 準備の段の分類した拒否は、入力ごとに原因を manifest（欄 preparationRejected）へ記録して照合する。
            # 記録のない拒否と、記録した拒否が消えたことは、どちらも失敗にする。
            if report is None:
                require(entry.get("preparationRejected") == PREPARATION_REJECTED[-1]["causes"],
                        f"{item['name']}: preparation rejection not recorded in the manifest: "
                        f"{PREPARATION_REJECTED[-1]['causes']}")
                single_rejected.append(item["name"])
                continue
            require("preparationRejected" not in entry, f"{item['name']}: recorded preparation rejection disappeared")
            if "singleSurfaceFailure" in entry:
                require(report["result"] == entry["singleSurfaceFailure"], item["name"])
                # 標準表にない組込みの呼び出しの拒否は、理由の文が一般の頭の検査の文なので、未知の組込みの一覧も照合し、
                # 別の原因の拒否と区別する。
                if "singleSurfaceUnknownBuiltins" in entry:
                    require(sorted(report["unknownBuiltins"]) == entry["singleSurfaceUnknownBuiltins"],
                            f"{item['name']}: unknown builtins")
            else:
                require(report["result"] == {"ok": True}, item["name"])
    reports = manifest["programReports"]
    raw = full_report("desugarDiff", [corpus_path], directory / "report.json",
                      directory / f"{stem}-desugar-report.json", (0, 1))
    # 報告の件数が、この corpus の入力と定義の数と一致することも確かめる（別の入力に対する報告を拒む）。
    for group in ("golden", "random"):
        items = [i for i in corpus["inputs"] if i["group"] == group]
        require(sum(raw[group]["programs"].values()) == len(items)
                and sum(raw[group]["definitions"].values()) == sum(len(i["definitions"]) for i in items),
                f"general desugar: {group}: report does not cover the corpus")
    report, known = classify_program_desugar(raw, corpus)
    require(reports["desugarKnownDifferences"]["shapes"] == [k["shape"] for k in KNOWN_PROGRAM_DESUGAR_DIFFERENCES]
            and known == reports["desugarKnownDifferences"]["counts"], f"general desugar: known differences {known}")
    require({group: report[group]["programs"] for group in ("golden", "random")} ==
            reports["desugarPrograms"], "all program classifications")
    require(report["golden"]["definitions"] == reports["desugarDefinitions"], "general desugar")
    require(report["random"]["definitions"] == reports["randomDesugarDefinitions"], "generated desugar")
    checked = [key for key in keys if not expected[key].get("excluded")]
    report = full_report("builtinCheck", [corpus_path, builtins], directory / "builtin-report.json",
                         directory / f"{stem}-builtin-report.json")
    require(report["errors"] == [], "general builtins")
    # 報告の入力の一覧が、この corpus の除外されない入力と一致することも確かめる（別の入力に対する報告を拒む）。
    require([(i["group"], i["name"]) for i in report["inputs"]] == checked
            and report["checkedInputs"] == len(checked), "general builtins: report does not cover the corpus")
    report = full_report("surfaceCheckAll", [corpus_path, builtins, stdlib], directory / "surface-check/report.json",
                         directory / f"{stem}-surface-report.json")
    recorded = sorted(key[1] for key in checked if "preparationRejected" in expected[key])
    classified = report.get("classified")
    rejected = sorted(classified["rejected"]) if classified else []
    # 全件の入口と単独の入口が断った入力は、manifest に記録した入力と一致する。
    require(rejected == sorted(single_rejected) == recorded,
            "general surface: rejected inputs differ between the full check, the single checks and the manifest")
    require(report["inputs"] + len(rejected) == len(checked)
            and report["excludedInputs"] == len(keys) - len(checked), "general surface: report does not cover the corpus")
    counts = report["counts"]
    require(counts == reports["surfaceCounts"], "general surface")
    # 件数の変化が準備の分類した拒否だけで説明できること: 残りの入力の検査の件数の和が、全入力の検査の件数から
    # 断った入力の分を引いた数に等しい。
    require(counts["preparationFailure"] == len(rejected)
            and sum(v for k, v in counts.items() if k != "preparationFailure") ==
            surface_definitions - sum(checks_by_input[name] for name in rejected),
            "general surface: counts are not explained by the classified rejections")
    outcomes = sorted((o for o in report["outcomes"] if o["category"] != "matched"),
                      key=lambda o: json.dumps(o, sort_keys=True))
    require(outcomes == reports["surfaceOutcomes"], "general surface classification reasons changed")
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
    check_program_rejections(directory, corpus, tables, reports["desugarKnownDifferences"]["counts"])


def nodes(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from nodes(child)
    elif isinstance(value, list):
        for child in value:
            yield from nodes(child)


# 契約の欄を壊した入力の拒否の理由と経路。篩付きの検査器（Refinement/Surface）は、名前の契約の不一致を個別の文で
# 報告せず、再検査の失敗（CheckEntrypoints.lean の proofFailure）か実装の宣言の検査（CheckDeclarationBase.lean の
# checkImplWith）の一般の文で断る。理由の文だけでは原因を区別できないので、壊した定義を指す経路も合わせて照合する。
# 壊さない同じ入力が通ることは、check_programs の単独の検査と check_named の各 entry が確かめる。
MUTATION_REJECTIONS = {
    "hole-label": ("type or certificate check failed", [0, 4, 1]),
    "hole-position": ("type or certificate check failed", [0, 4, 1]),
    "hole-contract": ("type or certificate check failed", [0, 4, 1]),
    "pipe-label": ("type or certificate check failed", [0, 8, 1]),
    "pipe-position": ("type or certificate check failed", [0, 8, 1]),
    "method-user": ("implementation declaration or body is invalid", [1, 0]),
    "method-dictionary": ("implementation declaration or body is invalid", [1, 1]),
    "operation": ("type or certificate check failed", [0, 1, 1]),
    "label": ("type or certificate check failed", [0, 3, 1]),
    "position": ("type or certificate check failed", [0, 3, 1]),
    "hole": ("type or certificate check failed", [0, 0, 1]),
    "partial": ("type or certificate check failed", [0, 0, 1]),
    "inserted": ("type or certificate check failed", [0, 1, 1]),
}


def rejected_as_expected(report, mode):
    reason, path = MUTATION_REJECTIONS[mode]
    return report["result"] == {"ok": False, "error": {"reason": reason, "path": path}}


def check_program_rejections(directory, original, tables, known_counts):
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
                if mode == "hole-label":
                    hole["label"] = "fake"
                elif mode == "hole-position":
                    hole["position"] = 0
                elif mode == "hole-contract":
                    partial["names"].reverse()
                else:
                    partial["args"].reverse()
            else:
                call = next(n["pipe"]["rhs"]["call"] for n in expressions if "pipe" in n
                            and n["pipe"]["rhs"].get("call", {}).get("positions") == [1])
                if mode == "pipe-label":
                    call["labels"][0] = "a"
                else:
                    call["positions"][0] = 0
            path = temp / "corpus.json"
            path.write_text(json.dumps(corpus))
            if mode == "hole-order":
                # 全入力の脱糖の比較は新しい Lean で約90秒かかるので、この一回だけ上限を延ばす。全入力には既知の差
                # （KNOWN_PROGRAM_DESUGAR_DIFFERENCES）も含まれるので、既知の差を除いた残りが壊した一件だけであることを
                # 確かめる。既知の差の件数も manifest と照らし、壊したことで既知の差の分類が変わらないことを確かめる。
                report = run("desugarDiff", [path], temp / "report.json", 1, timeout=600)
                definitions = {(i["group"], i["name"], d["name"]): d for i in corpus["inputs"] for d in i["definitions"]}
                unknown = [m for m in report["mismatches"] if known_program_difference(m, definitions) is None]
                require(len(unknown) == 1 and unknown[0]["input"] == original_item["name"], mode)
                known = {group: {"programs": len({m["input"] for m in report["mismatches"]
                                                   if m["group"] == group and m not in unknown}),
                                 "definitions": sum(m["group"] == group and m not in unknown
                                                    for m in report["mismatches"])}
                         for group in ("golden", "random")}
                require(known == known_counts and report[original_item["group"]]["definitions"]["mismatched"] ==
                        known[original_item["group"]]["definitions"] + 1, f"{mode}: known differences {known}")
                results.append({"mutation": mode, "tool": "desugarDiff", "mismatches": 1,
                                "knownDifferences": known})
            else:
                report = run_surface("surfaceCheck", [path, *single_tables, item["group"], item["name"]],
                                     temp / "report.json", 1)
                # 壊さない入力は準備の段で断られない（manifest に preparationRejected がない）ので、壊した入力が
                # 分類した拒否になったら、変異の照合を飛ばさずに失敗にする。
                require(report is not None, f"{mode}: mutation rejected at preparation instead of the check")
                require(rejected_as_expected(report, mode), f"{mode}: {report['result']}")
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
            report = run_surface("surfaceCheck", [path, *single_tables, item["group"], item["name"]],
                                 temp / "report.json", 1)
            # 壊した入力が準備の段の分類した拒否になったら、変異の照合を飛ばさずに失敗にする。
            require(report is not None, f"{mode}: mutation rejected at preparation instead of the check")
            require(rejected_as_expected(report, mode), f"{mode}: {report['result']}")
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
            elif mode == "inserted":
                expression(calls(corpus)[1])["pipe"]["rhs"]["call"]["positions"] = [0]
            else:
                definition = next(d for d in calls(corpus) if d["name"].startswith("sample ("))
                c = expression(definition)["call"]
                if mode == "label": c["labels"][0] = "fake"
                elif mode == "position": c["positions"] = [0, 0]
                else: c["args"].reverse()
            path = temp / "corpus.json"
            path.write_text(json.dumps(corpus))
            if mode == "source-order":
                report = run("desugarDiff", [path], temp / "report.json", 1)
                require(len(report["mismatches"]) == 1, mode)
            else:
                stem = corpus["inputs"][0]["name"]
                report = run_surface("surfaceCheck", [path, builtins, stdlib, "golden", stem], temp / "report.json", 1)
                # 壊した入力が準備の段の分類した拒否になったら、変異の照合を飛ばさずに失敗にする。
                require(report is not None, f"{mode}: mutation rejected at preparation instead of the check")
                require(rejected_as_expected(report, mode), f"{mode}: {report['result']}")
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


def check_remaining_batch3(directory):
    # シェルの既存4入口に加え、残る旧Scope/Range/辞書/解決の4群を最終読者で照合する。
    # 外側の失敗を握りつぶさず、同じcheck_batch3の六入口とmanifestを再利用する。
    batch3 = runpy.run_path(str(Path(__file__).with_name("check_batch3.py")))
    for profile in ("k3", "k4", "m1", "t3"):
        batch3["check"](directory / "batch3" / profile,
                        directory / "batch3" / f"{profile}-exchange-results.json")
    # check_batch3 は check_named を別の名前空間で読むので、そこで記録した分類した拒否を最後の集計へ移す。
    PREPARATION_REJECTED.extend(batch3["SHARED"]["PREPARATION_REJECTED"])


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
    check_remaining_batch3(directory)
    check_routing(directory, manifest)
    check_coverage_exports(coverage_dir, manifest["coverageExports"])
    check_width(directory, manifest["width"])
    check_programs(directory, manifest)
    outputs = {entry["stem"]: check_named(directory, entry, manifest["namedVersions"])
               for entry in manifest["named"]}
    coverage = coverage_dir / "named-corpus.json"
    data = read(coverage)
    # 独立Coverageも、corpus16に付くプログラムsidecarと同じ版8で書く。
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
    # 準備の段で断った表層の検査は、原因ごとの件数とともに残す（後段の受け入れで0件にする）。
    summary = preparation_summary()
    (directory / "surface-preparation-rejections.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"surface checks rejected at preparation: {summary['rejected']} {summary['causes']}")
    print("named export: manifest agrees; corpus 16, tables/program coverage 8 and independent coverage 8 match all six entries")


if __name__ == "__main__":
    main()
