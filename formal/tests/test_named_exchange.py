"""手書きの新形式を六つの CLI で検査する。期待コアは脱糖から作らない。

JSON の必須欄、契約とラベル・位置、宣言表、比較の正規化を入口で確かめる。
契約名の導入前の版へ新版の欄を混ぜた入力の拒否も検査する。8/2/2 の閉じた互換入力は
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
         "params": [ty], "ret": ty, "eff": []}
    data["corpus"]["inputs"][0]["definitions"].append({
        "name": "effectOrder (fn:100)", "scope": {"inScope": {
            "surface": {"header": copy.deepcopy(h), "dictParams": [],
                "implementation": None, "method": None, "supers": [],
                "coverageView": [], "package": "author",
                "body": {"last": {"expr": {"returnE": {
                    "ret": copy.deepcopy(ty), "inner": {"local": {"index": 0}}}}}}},
            "core": {"header": copy.deepcopy(h), "lambdaEffects": [], "supers": [],
                "body": {"ret": {"value": {"var": {"index": 0}}}}}}}})
    # 四形式の側の読者にも同じ潜在効果を渡す。期待値はワイルドカードによる全域である。
    data["builtins"]["inputs"][0]["prims"].append({
        "name": "effectOrder", **copy.deepcopy(h), "kind": "pure", "opEff": None,
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
        result = subprocess.run([str(BIN / tool), *args], text=True, capture_output=True, timeout=10)
        return result, json.loads(report.read_text()) if report.exists() else None

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

    def test_legacy_effect_order_and_membership(self):
        legacy = runpy.run_path(str(Path(__file__).with_name("test_extensible_exchange.py")))["legacy"]
        # Atom.code の順序。Python側にその符号の実装は置かない。
        effects = [{"rho": {"index": 0}}, {"rho": {"index": 1}},
                   {"name": {"value": "Ask"}}, {"name": {"value": "Console"}}]
        for version in (8, 9, 10):
            for order in (effects, list(reversed(effects)) + effects[:1]):
                data = effect_order_input(self.data, order)
                core = data["corpus"]["inputs"][0]["definitions"][-1]["scope"]["inScope"]["core"]
                core["header"]["params"][0]["list"]["elem"]["fn"]["eff"] = list(reversed(effects))
                if version == 8:
                    data = legacy(data)
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
                    # 旧版の名前の原子は明示の Top の範囲の位置を加えて読む（corpus 15 の報告の形。L50.1）。
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
                    self.assertEqual(report["result"], {"ok": False, "error": {"path": [1, 0, 0, 0],
                                     "reason": "implementation method parameter names mismatch"}})
                else:
                    self.assertEqual(report["counts"]["mismatched"], 1)
                    self.assertEqual(report["mismatchExamples"][0]["error"], {"path": [0, 0], "ancestors": [],
                                     "reason": "implementation method parameter names mismatch"})

    def test_pre_contract_versions_reject_new_contract_fields(self):
        for tool, files in TOOLS.items():
            with self.subTest(tool=tool):
                data = copy.deepcopy(self.data)
                data[files[0]]["version"] = 7 if files[0] == "corpus" else 1
                result, _ = self.run_tool(tool, data)
                self.assertEqual(result.returncode, 2, result.stdout)
                field = "positions" if tool == "coverageProgramDiff" else "names"
                self.assertEqual(result.stderr, f"{tool}: field requires new exchange version: {field}\n")
                # 版そのものの拒否も保持し、新版の欄を混ぜた拒否と区別する。
                kind = files[0]
                version = data[kind]["version"]
                data[kind] = {"version": version}
                result, _ = self.run_tool(tool, data)
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertIn("unsupported", result.stderr)
                self.assertEqual(result.stderr, f"{tool}: unsupported {kind} exchange version: {version}\n")

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
                    reason = "Header.names"
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
        cases = (
            ("label", 1, [0, 1, 0, 0, 0], "call labels and positions do not match the contract"),
            ("position", 1, [0, 1, 0, 0, 0], "call labels and positions do not match the contract"),
            ("partial", 3, [0, 3, 0, 0, 0], "partial call contract annotation mismatch"),
            ("hole", 3, [0, 3, 0, 0, 0], "partial call labels and positions do not match the contract"),
            ("pipe", 4, [0, 4, 0, 0, 0, 1], "pipe labels and positions do not match the contract"),
            ("callback", 5, [0, 5, 0, 0, 0, 1, 0], "type is not included in the expected type"),
            ("method", 7, [1, 0, 0, 0], "implementation method parameter names mismatch"),
            ("operator", 12, [0, 10, 0, 0, 0], "binary operator parameter names mismatch"),
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
        self.assertEqual(failure["error"]["reason"], "implementation method parameter names mismatch")
        self.assertEqual(failure["error"]["path"], [0, 0])

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
        header["names"] = ["%dict1", "x"]
        header["params"].insert(0, {"dict": {"cls": "Show", "arg": {"tvar": {"index": 0}}}})
        implementation = method["scope"]["inScope"]
        implementation["surface"]["header"]["tparams"] = [[False, False]]
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
                    self.assertEqual(report["result"], {"ok": False, "error": {"path": [1, 0, 0, 0],
                                     "reason": "implementation method parameter names mismatch"}})
                else:
                    self.assertEqual(report["counts"]["mismatched"], 1)
                    self.assertEqual(report["mismatchExamples"][0]["error"], {"path": [0, 0], "ancestors": [],
                                     "reason": "implementation method parameter names mismatch"})

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
