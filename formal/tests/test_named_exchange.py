"""手書きの新形式を六つの CLI で検査する。期待コアは脱糖から作らない。

JSON の必須欄、契約とラベル・位置、宣言表、比較の正規化を入口で確かめる。
契約名の導入前の版へ新版の欄を混ぜた入力の拒否も検査する。16/8 の閉じた互換入力は
別の test_extensible_exchange.py で確認する。
"""

import copy
import json
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).with_name("named-exchange")
BIN = ROOT / "formal/.lake/build/bin"
FILES = ("corpus", "builtins", "stdlib", "coverage", "coverage-program")
TOOLS = {
    "desugarDiff": ("corpus",),
    "builtinCheck": ("corpus", "builtins"),
    "coverageDiff": ("coverage",),
    "coverageProgramDiff": ("coverage-program", "builtins"),
    "surfaceCheck": ("corpus", "builtins", "stdlib"),
    "surfaceCheckAll": ("corpus", "builtins", "stdlib"),
}

# 脱糖の比較の既知の差。列挙した差だけなら一致として数え、列挙の外の差は従来どおり不一致にする。列挙した定義が
# 入力にあるのに差が消えたときは失敗にする（test_range_known_differences.py と同じ考え方）。
KNOWN_DESUGAR_DIFFERENCES = [
    {"input": "independent-named", "definition": "Pair.left (fn:12)", "path": "definition.header.ret",
     "reason": "篩付きの脱糖は取得関数の結果型に欄の関係の篩を付ける（Surface.accessorRet）が、交換の核（処理系の"
               "書き出しと同じ形）は付けない",
     "obligation": "R10b: 処理系の脱糖と書き出しが取得関数の結果型に同じ篩を付けたら、この列挙から除く",
     # 差の中身: Lean の脱糖の結果型（expected）は、交換の核の結果型（actual）に、欄の関係の述語の篩を付けた形である。
     "shape": "accessor field refinement"},
]


def _mentions_field(predicate):
    if isinstance(predicate, dict):
        return "field" in predicate or any(_mentions_field(v) for v in predicate.values())
    if isinstance(predicate, list):
        return any(_mentions_field(v) for v in predicate)
    return False


def known_shape(known, mismatch):
    """既知の差の中身の照合。取得関数の結果型の篩の差は、期待の結果型が実際の結果型に欄の関係の篩を付けた形である。"""
    if known["shape"] == "accessor field refinement":
        refined = mismatch.get("expected", {}).get("refined") if isinstance(mismatch.get("expected"), dict) else None
        return (refined is not None and refined.get("base") == mismatch.get("actual")
                and _mentions_field(refined.get("predicate")))
    return False


def known_desugar(result, report, data):
    """desugarDiff の結果から既知の差を除く。列挙した定義があるのに差がないときは AssertionError にする。"""
    present = [k for k in KNOWN_DESUGAR_DIFFERENCES
               if any(i["name"] == k["input"] and any(d["name"] == k["definition"] for d in i["definitions"])
                      for i in data["corpus"]["inputs"])]
    if report is None or not present:
        return result, report
    keys = {(k["input"], k["definition"], k["path"]) for k in present}
    by_key = {(k["input"], k["definition"], k["path"]): k for k in present}
    # 経路が同じでも中身が既知の差の形でなければ、未知の差として不一致に残す。
    found = [m for m in report["mismatches"] if (m["input"], m["definition"], m["path"]) in keys
             and known_shape(by_key[(m["input"], m["definition"], m["path"])], m)]
    if {(m["input"], m["definition"], m["path"]) for m in found} != keys:
        raise AssertionError(f"known desugar differences disappeared: {sorted(keys)}")
    report = copy.deepcopy(report)
    report["mismatches"] = [m for m in report["mismatches"] if m not in found]
    report["knownDifferences"] = found
    for m in found:
        counts = report[m["group"]]["definitions"]
        counts["mismatched"] -= 1
        counts["matched"] += 1
    for group in {m["group"] for m in found}:
        inputs = {m["input"] for m in found if m["group"] == group}
        for name in inputs:
            if not any(m["input"] == name and m["group"] == group for m in report["mismatches"]):
                programs = report[group]["programs"]
                programs["mismatched"] -= 1
                programs["matched"] += 1
    if result.returncode == 1 and not report["mismatches"] and all(
            report[g]["programs"]["mismatched"] == 0 for g in ("golden", "random") if g in report):
        result = subprocess.CompletedProcess(result.args, 0, result.stdout, result.stderr)
    return result, report


def surface(data, index):
    return data["corpus"]["inputs"][0]["definitions"][index]["scope"]["inScope"]["surface"]


def expr(data, index):
    return surface(data, index)["body"]["last"]["expr"]["returnE"]["inner"]


def effect_order_input(data, effects):
    """既存の宣言を残し、潜在効果を含む型をそのまま返す多相関数を加える。"""
    data = copy.deepcopy(data)
    ty = {"list": {"elem": {"fn": {"names": ["value"],
          "params": [{"base": {"name": "Integer"}}],
          "ret": {"base": {"name": "Integer"}}, "eff": effects}}}}
    h = {"tparams": [], "neffs": 2, "names": ["value"],
         "params": [ty], "ret": ty, "eff": [], 'tparamKinds': [], 'effParams': [{'noFail': False} for _ in range(2)], 'rangeParams': [], 'proofSteps': None}
    data["corpus"]["inputs"][0]["definitions"].append({
        "name": "effectOrder (fn:100)", "scope": {"inScope": {
            "surface": {"header": copy.deepcopy(h), "dictParams": [],
                "implementation": None, "method": None, "supers": [],
                "coverageView": [], "package": "author",
                "body": {"last": {"expr": {"returnE": {
                    "ret": copy.deepcopy(ty), "inner": {"local": {"index": 0}}}}}}},
            "core": {"header": copy.deepcopy(h), "lambdaEffects": [], "supers": [],
                "body": {"ret": {"value": {"var": {"index": 0}}}}}}}, 'annotations': {}})
    # 四形式の側の読者にも同じ潜在効果を渡す。期待値はワイルドカードによる全域である。
    data["builtins"]["inputs"][0]["prims"].append({
        "name": "effectOrder", **{k: v for k, v in copy.deepcopy(h).items() if k not in ("rangeParams", "proofSteps")}, "rkinds": [], "shape": "untargeted", "kind": "pure", "opEff": None,
        "classConstraints": [], "unconvertibleTypes": []})
    data["stdlib"]["inputs"][0]["functions"].append({
        "name": "fn:101", "header": copy.deepcopy(h), "dictParams": []})
    data["coverage"]["cases"][0]["ty"]["eff"] = copy.deepcopy(effects)
    data["coverage-program"]["inputs"][0]["matches"][0]["scrutineeTy"]["fn"]["eff"] = copy.deepcopy(effects)
    return data


class ExchangeTests(unittest.TestCase):
    def setUp(self):
        self.data = {name: json.loads((FIXTURES / f"{name}.json").read_text()) for name in FILES}
        self.tmp = tempfile.TemporaryDirectory(prefix="benitoite-named-exchange-")
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)

    def run_tool(self, tool, data=None, selected=None, input_name="independent-named"):
        data = self.data if data is None else data
        paths = {}
        for name, value in data.items():
            path = self.directory / f"{name}.json"
            path.write_text(json.dumps(value) + "\n")
            paths[name] = str(path)
        report = self.directory / "report.json"
        report.unlink(missing_ok=True)
        args = [paths[name] for name in TOOLS[tool]]
        if tool == "surfaceCheck":
            args += ["golden", input_name]
        args.append(str(report))
        if selected is not None:
            args += [selected, "2"]
        # 書き出しの全件の検査（batch3 の47定義で約9秒）が収まる上限にする。
        result = subprocess.run([str(BIN / tool), *args], text=True, capture_output=True, timeout=60)
        loaded = json.loads(report.read_text()) if report.exists() else None
        if tool == "desugarDiff":
            return known_desugar(result, loaded, data)
        return result, loaded

    def test_six_entries_accept_independent_input(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                result, report = self.run_tool(tool)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
                if tool == "desugarDiff":
                    self.assertEqual(report["golden"]["definitions"],
                                     {"matched": 18, "mismatched": 0, "outside": 0, "excluded": 0})
                    self.assertEqual(report["mismatches"], [])
                elif tool == "builtinCheck":
                    self.assertEqual(report["errors"], [])
                    self.assertEqual(report["summaryMismatchCount"], 0)
                elif tool.startswith("coverage"):
                    self.assertEqual((report["matched"], report["mismatched"], report["fuelExhausted"]), (2, 0, 0))
                elif tool == "surfaceCheck":
                    self.assertEqual(report["result"], {"ok": True})
                else:
                    self.assertEqual(report["counts"], {"matched": 17, "q11": 0, "outOfScope": 0,
                                     "lazyRestriction": 0, "mismatched": 0, "preparationFailure": 0})
                    self.assertTrue(report["q11Agrees"])

    def test_selected_definition(self):
        result, report = self.run_tool("surfaceCheck", selected="fn:2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(report["result"], {"ok": True})
        self.assertEqual(report["definition"], "fn:2")
        self.assertEqual(len(report["checkNanos"]), 2)

    def test_effect_order_and_membership(self):
        # Atom.code の順序。Python側にその符号の実装は置かない。
        effects = [{"rho": {"index": 0}}, {"rho": {"index": 1}},
                   {"name": {"value": "Ask", 'ix': {'fixed': 'top'}}}, {"name": {"value": "Console", 'ix': {'fixed': 'top'}}}]
        for version in (16,):
            for order in (effects, list(reversed(effects)) + effects[:1]):
                data = effect_order_input(self.data, order)
                core = data["corpus"]["inputs"][0]["definitions"][-1]["scope"]["inScope"]["core"]
                core["header"]["params"][0]["list"]["elem"]["fn"]["eff"] = list(reversed(effects))
                data["corpus"]["version"] = version
                for tool in TOOLS:
                    with self.subTest(version=version, order=order, tool=tool):
                        result, report = self.run_tool(tool, data, selected="fn:100" if tool == "surfaceCheck" else None)
                        self.assertEqual(result.returncode, 0, result.stderr + result.stdout + json.dumps(report))
                        if tool == "desugarDiff":
                            self.assertEqual(report["golden"]["definitions"],
                                             dict(matched=19, mismatched=0, outside=0, excluded=0))
                            self.assertEqual(report["mismatches"], [])
                        elif tool == "builtinCheck":
                            self.assertEqual(report["errors"], [])
                            self.assertEqual(report["summaryMismatchCount"], 0)
                        elif tool.startswith("coverage"):
                            self.assertEqual((report["matched"], report["mismatched"], report["fuelExhausted"]), (2, 0, 0))
                        elif tool == "surfaceCheck":
                            self.assertEqual(report["result"], {"ok": True})
                        else:
                            self.assertEqual(report["counts"], dict(matched=18, mismatched=0, outOfScope=0,
                                             q11=0, lazyRestriction=0, preparationFailure=0))
                # 並びと重複だけをそろえ、実際の要素の欠落を消さない。
                core = data["corpus"]["inputs"][0]["definitions"][-1]["scope"]["inScope"]["core"]
                core["header"]["params"][0]["list"]["elem"]["fn"]["eff"] = effects[:-1]
                with self.subTest(version=version, order=order, missing=True):
                    result, report = self.run_tool("desugarDiff", data)
                    self.assertEqual(result.returncode, 1, result.stderr + result.stdout)
                    self.assertEqual(report["golden"]["definitions"],
                                     dict(matched=18, mismatched=1, outside=0, excluded=0))
                    self.assertEqual(len(report["mismatches"]), 1)
                    mismatch = report["mismatches"][0]
                    self.assertEqual(mismatch["definition"], "effectOrder (fn:100)")
                    self.assertIn("header.params[0].list.elem.fn.eff", mismatch["path"])
                    self.assertNotEqual(mismatch["expected"], mismatch["actual"])
                    # 名前の原子は明示の Top の範囲の位置を持つ。
                    explicit_top = [{"name": {**a["name"], "ix": {"fixed": "top"}}} if "name" in a else a
                                    for a in effects]
                    self.assertEqual(mismatch["expectedDefinition"]["header"]["params"][0]["list"]["elem"]["fn"]["eff"],
                                     explicit_top)

    def test_implementation_and_method_dictionaries(self):
        # 実装の T: Show とメソッドの U: Show は別の束縛である。
        # 辞書数から作るメソッド名に、実装の辞書を混ぜる退行を入口で検出する。
        result, report = self.run_tool("surfaceCheck", input_name="implementation-dictionaries")
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual(report["result"], {"ok": True})
        data = copy.deepcopy(self.data)
        method = data["corpus"]["inputs"][1]["definitions"][0]["scope"]["inScope"]["surface"]
        method["header"]["names"] = ["other"]
        for tool in ("surfaceCheck", "surfaceCheckAll"):
            with self.subTest(tool=tool):
                result, report = self.run_tool(tool, data, input_name="implementation-dictionaries")
                self.assertEqual(result.returncode, 1, result.stderr + result.stdout)
                if tool == "surfaceCheck":
                    self.assertEqual(report["result"], {"ok": False, "error": {"path": [1, 0],
                                     "reason": "implementation declaration or body is invalid"}})
                else:
                    self.assertEqual(report["counts"]["mismatched"], 1)
                    self.assertEqual(report["mismatchExamples"][0]["error"], {"path": [1, 0], "ancestors": [],
                                     "reason": "implementation declaration or body is invalid"})

    def test_old_versions_are_rejected(self):
        for tool, files in TOOLS.items():
            for field in files:
                for version in (range(0, 16) if field == 'corpus' else range(0, 8)):
                    data = copy.deepcopy(self.data)
                    data[field]['version'] = version
                    with self.subTest(tool=tool, field=field, version=version):
                        result, _ = self.run_tool(tool, data)
                        self.assertEqual(result.returncode, 2, result.stdout)
                        self.assertIn('version', result.stderr)

    def test_required_names_are_not_filled(self):
        for tool in ("desugarDiff", "builtinCheck", "surfaceCheck", "surfaceCheckAll"):
            with self.subTest(tool=tool):
                data = copy.deepcopy(self.data)
                del surface(data, 0)["header"]["names"]
                result, report = self.run_tool(tool, data)
                self.assertEqual(result.returncode, 2)
                # The batch reports preparation errors per input rather than stderr.
                message = result.stderr if tool != "surfaceCheckAll" else json.dumps(report["preparationErrors"])
                self.assertIn("Header.names", message)
        for tool, key in (("builtinCheck", "builtins"), ("surfaceCheck", "builtins"),
                          ("coverageDiff", "coverage"), ("coverageProgramDiff", "coverage-program")):
            with self.subTest(tool=tool, nested=True):
                data = copy.deepcopy(self.data)
                if key == "builtins":
                    del data[key]["inputs"][0]["prims"][0]["params"][1]["fn"]["names"]
                elif key == "coverage":
                    del data[key]["cases"][0]["ty"]["names"]
                else:
                    del data[key]["inputs"][0]["matches"][0]["scrutineeTy"]["fn"]["names"]
                result, _ = self.run_tool(tool, data)
                self.assertEqual(result.returncode, 2)
                self.assertIn("names", result.stderr)

    def test_stdlib_contract_and_sidecar_identity_are_required(self):
        for mode in ("names", "identity", "record-fields"):
            with self.subTest(mode=mode):
                data = copy.deepcopy(self.data)
                if mode == "names":
                    del data["stdlib"]["inputs"][0]["functions"][0]["header"]["names"]
                    reason = "missing exchange field: names"
                elif mode == "identity":
                    data["stdlib"]["inputs"][0]["name"] = "another-program"
                    reason = "missing input: golden/independent-named"
                else:
                    data["builtins"]["inputs"][0]["dataDecls"][1]["ctors"][0]["fields"] = ["right", "left"]
                    reason = "record fields mismatch"
                result, _ = self.run_tool("surfaceCheck", data)
                self.assertEqual(result.returncode, 2)
                self.assertIn(reason, result.stderr)

    def test_checker_rejects_false_contracts(self):
        # 篩付きの検査器は、呼出しの契約の偽りを案内の再検査の失敗として定義の本体の位置で断り、実装の宣言の偽りは
        # 実装の宣言の誤りとして断る。演算子の組込みの名前の偽りは、準備の段の標準表との照合で断る（終了2）。
        cases = (
            ("label", 1, [0, 1, 1], "type or certificate check failed"),
            ("position", 1, [0, 1, 1], "type or certificate check failed"),
            ("partial", 3, [0, 3, 1], "type or certificate check failed"),
            ("hole", 3, [0, 3, 1], "type or certificate check failed"),
            ("pipe", 4, [0, 4, 1], "type or certificate check failed"),
            ("callback", 5, [0, 5, 1], "type or certificate check failed"),
            ("method", 7, [1, 0], "implementation declaration or body is invalid"),
            ("operator", 12, None, "builtin signature disagrees with the standard table: [%eq]"),
        )
        for mode, index, path, reason in cases:
            with self.subTest(mode=mode):
                data = copy.deepcopy(self.data)
                e = expr(data, index)
                if mode == "label": e["call"]["labels"][0] = "fake"
                elif mode == "position": e["call"]["positions"] = [0, 0]
                elif mode == "partial": e["partialCall"]["names"] = ["right", "left"]
                elif mode == "hole": e["partialCall"]["args"][0]["hole"]["label"] = "fake"
                elif mode == "pipe": e["pipe"]["rhs"]["call"]["positions"] = [0]
                elif mode == "callback": e["call"]["args"][0]["lam"]["names"] = ["n"]
                elif mode == "method": surface(data, index)["header"]["names"] = ["y"]
                elif mode == "operator": data["builtins"]["inputs"][0]["prims"][1]["names"] = ["a", "b"]
                result, report = self.run_tool("surfaceCheck", data)
                if path is None:
                    self.assertEqual(result.returncode, 2, result.stderr)
                    self.assertIn(reason, result.stderr)
                    continue
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual(report["result"], {"ok": False, "error": {"path": path, "reason": reason}})

    def test_batch_retains_method_names(self):
        data = copy.deepcopy(self.data)
        surface(data, 7)["header"]["names"] = ["y"]
        result, report = self.run_tool("surfaceCheckAll", data)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(report["counts"]["mismatched"], 1)
        failure = report["mismatchExamples"][0]
        self.assertEqual(failure["kind"], "implementation")
        self.assertEqual(failure["error"]["reason"], "implementation declaration or body is invalid")
        self.assertEqual(failure["error"]["path"], [1, 0])

    def test_implementation_dictionary_names_preserve_the_user_contract(self):
        data = copy.deepcopy(self.data)
        program = data["corpus"]["inputs"][0]
        data["corpus"]["inputs"] = [program]
        for name in ("builtins", "stdlib"):
            data[name]["inputs"] = data[name]["inputs"][:1]
        method = program["definitions"][7]
        program["definitions"] = [method]
        header = program["classes"][0]["methods"][0]["header"]
        header["tparams"] = [[False, False]]
        header["tparamKinds"] = ["value"]
        header["names"] = ["%dict1", "x"]
        header["params"].insert(0, {"dict": {"cls": "Show", "arg": {"tvar": {"index": 0}}}})
        implementation = method["scope"]["inScope"]
        implementation["surface"]["header"]["tparams"] = [[False, False]]
        implementation["surface"]["header"]["tparamKinds"] = ["value"]
        implementation["surface"]["dictParams"] = [["Show", 0]]
        implementation["core"]["header"] = copy.deepcopy(header)
        for tool in ("desugarDiff", "surfaceCheck", "surfaceCheckAll"):
            with self.subTest(tool=tool):
                result, report = self.run_tool(tool, data)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
                if tool == "desugarDiff":
                    self.assertEqual(report["golden"]["definitions"],
                                     {"matched": 1, "mismatched": 0, "outside": 0, "excluded": 0})
                elif tool == "surfaceCheck":
                    self.assertEqual(report["result"], {"ok": True})
                else:
                    self.assertEqual(report["counts"], {"matched": 1, "q11": 0, "outOfScope": 0,
                                     "lazyRestriction": 0, "mismatched": 0, "preparationFailure": 0})
        implementation["surface"]["header"]["names"] = ["other"]
        for tool in ("surfaceCheck", "surfaceCheckAll"):
            with self.subTest(tool=tool, mismatched=True):
                result, report = self.run_tool(tool, data)
                self.assertEqual(result.returncode, 1, result.stderr + result.stdout)
                if tool == "surfaceCheck":
                    self.assertEqual(report["result"], {"ok": False, "error": {"path": [1, 0],
                                     "reason": "implementation declaration or body is invalid"}})
                else:
                    self.assertEqual(report["counts"]["mismatched"], 1)
                    self.assertEqual(report["mismatchExamples"][0]["error"], {"path": [1, 0], "ancestors": [],
                                     "reason": "implementation declaration or body is invalid"})

    def test_comparison_preserves_names_and_source_positions(self):
        for mode in ("header", "lambda", "positions", "source-order", "dictionary-name"):
            with self.subTest(mode=mode):
                data = copy.deepcopy(self.data)
                ds = data["corpus"]["inputs"][0]["definitions"]
                if mode == "header": ds[0]["scope"]["inScope"]["core"]["header"]["names"] = ["right", "left"]
                elif mode == "lambda": ds[2]["scope"]["inScope"]["core"]["body"]["ret"]["value"]["lam"]["names"] = ["other"]
                elif mode == "positions": expr(data, 1)["call"]["positions"] = [0, 1]
                elif mode == "source-order": expr(data, 1)["call"]["args"].reverse()
                else: ds[13]["scope"]["inScope"]["core"]["header"]["names"] = ["dictionary", "value"]
                result, report = self.run_tool("desugarDiff", data)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual(len(report["mismatches"]), 1)
                mismatch = report["mismatches"][0]
                self.assertNotEqual(mismatch["expected"], mismatch["actual"])
                if mode in ("header", "lambda", "dictionary-name"):
                    self.assertIn("names", mismatch["path"])

    def test_builtin_operation_contract_matches_the_table(self):
        data = copy.deepcopy(self.data)
        data["corpus"]["inputs"][0]["primOps"][0]["names"] = ["other"]
        result, report = self.run_tool("builtinCheck", data)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(report["errors"], ["golden/independent-named: Console.writeLine: operation signature mismatch"])

    def test_coverage_rejects_malformed_contract_instead_of_excluding_it(self):
        data = copy.deepcopy(self.data)
        data["coverage-program"]["inputs"][0]["matches"][0]["scrutineeTy"]["fn"]["names"] = []
        result, _ = self.run_tool("coverageProgramDiff", data)
        self.assertEqual(result.returncode, 2)
        self.assertIn("invalid parameter names", result.stderr)
        data = copy.deepcopy(self.data)
        data["coverage"]["cases"][0]["expected"]["exhaustive"] = False
        result, report = self.run_tool("coverageDiff", data)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(report["mismatched"], 1)


if __name__ == "__main__":
    unittest.main()
