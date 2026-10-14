"""手書きの JSON を交換形式の実行器へ渡し、数の追加と旧形式の互換を検査する。

各幅の脱糖・型検査が交換の境界で抜ける退行を捕まえる。既存の Rust の
出力には新しい数がまだ含まれないため、この入力で接続を独立に検査する。
期待するコアは JSON の固定した束縛の形であり、Lean の脱糖から生成しない。
"""

import json
from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]
FIXTURE = Path(__file__).with_name("width-exchange.json")
OUTPUT = ROOT / "target/p3a-gate/width-exchange"
BIN = ROOT / "formal/.lake/build/bin"


def base(name):
    return {"base": {"name": name}}


def header(ret, params=()):
    return {"tparams": [], "neffs": 0, "params": list(params), "ret": ret, "eff": []}


def primitive(name, params, ret):
    return {"name": name, **header(ret, params), "kind": "pure", "opEff": None,
            "classConstraints": [], "unconvertibleTypes": []}


def definition(index, name, ret, expr, core, params=()):
    h = header(ret, params)
    return {"name": f"{name} (fn:{index})", "scope": {"inScope": {
        "surface": {"header": h, "body": {"last": {"expr": {"returnE": {"ret": ret, "inner": expr}}}},
                    "dictParams": [], "implementation": None, "method": None, "supers": []},
        "core": {"header": h, "body": core, "lambdaEffects": [], "supers": []}}}}


def inputs():
    fixture = json.loads(FIXTURE.read_text())
    defs, prims = [], []
    for row in fixture["literals"] + fixture["directNegations"]:
        expr = row.get("surface", {"literal": {"value": row["value"]}})
        defs.append(definition(len(defs), row["name"], base(row["type"]), expr,
                               {"ret": {"value": {"const": {"value": row["value"]}}}}))
    for op in fixture["operators"]:
        ty = op["operand"]
        unary = op["op"] == "neg"
        params = [ty] if unary else [ty, ty]
        expr = ({"neg": {"operand": ty, "inner": {"local": {"index": 0}}}} if unary else
                {"binary": {"op": op["op"], "operand": ty,
                            "lhs": {"local": {"index": 1}}, "rhs": {"local": {"index": 0}}}})
        core = json.loads(json.dumps(fixture["negCore" if unary else "binaryCore"])
                          .replace("$primitive", op["name"]))
        defs.append(definition(len(defs), op["name"], ty, expr, core, params))
        prims.append(primitive(op["name"], params, ty))
    # 別名で宣言した演算子を、主の名前の式からも選択できることを確かめる。
    defs[-1]["scope"]["inScope"]["surface"]["body"]["last"]["expr"]["returnE"]["inner"]["neg"]["operand"] = base("Integer")
    # 補間には各幅の変換の型と純粋性が必要であり、名前の受理だけでは足りない。
    for ty in ["Integer8", "Integer16", "Integer32", "UnsignedInteger16",
               "UnsignedInteger32", "UnsignedInteger64", "Float32", "UnsignedInteger8"]:
        name = f"{ty}.toString"
        expr = {"interpolation": {"parts": [{"converted": {"ty": base(ty)}}],
                                  "es": [{"local": {"index": 0}}],
                                  "converters": [{"primName": {"name": name, "tys": [], "effs": []}}]}}
        core = json.loads(json.dumps(fixture["interpolationCore"]).replace("$primitive", name))
        defs.append(definition(len(defs), name, base("String"), expr, core, [base(ty)]))
        prims.append(primitive(name, [base(ty)], base("String")))
    identity = {"group": "golden", "name": "width-exchange"}
    corpus = {"version": 7, "operators": fixture["operators"], "annotations": {"tailMatch": [0, 0]},
              "inputs": [{**identity, "excluded": [], "definitions": defs, "constants": [],
                          "ops": [], "effects": [], "primOps": [], "classes": [], "impls": []}]}
    builtins = {"version": 1, "inputs": [{**identity, "prims": prims,
                "effects": [{"name": "State", "ops": []}], "resources": [], "dataDecls": [],
                "summaries": [], "statePure": [], "supplementalData": [], "supplementalPrims": []}]}
    stdlib = {"version": 1, "inputs": [{**identity, "functions": [], "impls": []}]}
    return corpus, builtins, stdlib


class WidthExchangeTests(unittest.TestCase):
    def run_input(self, name, corpus, builtins, stdlib):
        directory = OUTPUT / name
        directory.mkdir(parents=True, exist_ok=True)
        paths = []
        for file, value in [("corpus.json", corpus), ("builtins.json", builtins), ("stdlib-decls.json", stdlib)]:
            path = directory / file
            path.write_text(json.dumps(value) + "\n")
            paths.append(str(path))
        results = {}
        for tool, args in [("desugarDiff", paths[:1]), ("builtinCheck", paths[:2]),
                           ("surfaceCheckAll", paths)]:
            report = directory / f"{tool}-report.json"
            report.unlink(missing_ok=True)
            result = subprocess.run([str(BIN / tool), *args, str(report)],
                                    capture_output=True, text=True, timeout=5)
            results[tool] = (result, json.loads(report.read_text()) if report.exists() else None)
        return results

    def test_literals_negation_operators_and_interpolation(self):
        corpus, builtins, stdlib = inputs()
        results = self.run_input("valid", corpus, builtins, stdlib)
        for tool, (result, _) in results.items():
            with self.subTest(tool=tool):
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        count = len(corpus["inputs"][0]["definitions"])
        desugar = results["desugarDiff"][1]["golden"]
        self.assertEqual(desugar["definitions"], {"matched": count, "mismatched": 0, "outside": 0, "excluded": 0})
        builtin = results["builtinCheck"][1]
        self.assertEqual(builtin["errors"], [])
        self.assertEqual(builtin["inputs"][0]["converted"], len(builtins["inputs"][0]["prims"]))
        surface = results["surfaceCheckAll"][1]
        self.assertEqual(surface["counts"]["matched"], count)
        self.assertEqual(surface["fullyCheckedInputs"], 1)
        self.assertEqual(surface["excludedInputs"], 0)

    def test_invalid_width_and_unsigned_values(self):
        cases = [("unknown-type", "Integer128", {"integer": {"value": 1}}, "unknown base type"),
                 ("unknown-constant", "Integer8", {"integer128": {"value": 1}}, "no inductive constructor matched"),
                 ("negative-byte", "Byte", {"byte": {"value": -1}}, "Nat"),
                 ("negative-u16", "UnsignedInteger16", {"unsignedInteger16": {"value": -1}}, "negative unsigned"),
                 ("negative-u32", "UnsignedInteger32", {"unsignedInteger32": {"value": -1}}, "negative unsigned"),
                 ("negative-u64", "UnsignedInteger64", {"unsignedInteger64": {"value": -1}}, "negative unsigned"),
                 ("wide-float-bits", "Float32", {"float32": {"bits": 4294967296}}, "outside 32-bit"),
                 ("negative-float-bits", "Float32", {"float32": {"bits": -1}}, "Nat")]
        for name, ty, value, reason in cases:
            with self.subTest(case=name):
                corpus, builtins, stdlib = inputs()
                corpus["inputs"][0]["definitions"] = [definition(0, name, base(ty),
                    {"literal": {"value": value}}, {"ret": {"value": {"const": {"value": value}}}})]
                results = self.run_input(name, corpus, builtins, stdlib)
                for tool in ["desugarDiff", "surfaceCheckAll"]:
                    result, report = results[tool]
                    self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                    self.assertIn(reason, result.stderr + json.dumps(report))

    def test_unsigned_zero_negation_is_rejected(self):
        corpus, builtins, stdlib = inputs()
        expr = {"neg": {"operand": base("UnsignedInteger16"),
                "inner": {"literal": {"value": {"unsignedInteger16": {"value": 0}}}}}}
        corpus["inputs"][0]["definitions"] = [definition(0, "unsigned-negation", base("UnsignedInteger16"),
            expr, {"ret": {"value": {"const": {"value": "unit"}}}})]
        result, report = self.run_input("unsigned-negation", corpus, builtins, stdlib)["surfaceCheckAll"]
        self.assertEqual(result.returncode, 1)
        self.assertEqual(report["counts"]["mismatched"], 1)
        self.assertIn("not allowed", json.dumps(report))

    def test_numeric_constant_patterns_are_rejected(self):
        fixture = json.loads(FIXTURE.read_text())
        kinds = {"byte", "integer8", "integer16", "integer32", "unsigned16", "unsigned32", "unsigned64", "float32"}
        for row in (r for r in fixture["literals"] if r["name"] in kinds):
            with self.subTest(case=row["name"]):
                corpus, builtins, stdlib = inputs()
                d = definition(0, "pattern", base("Unit"), "unit",
                               {"ret": {"value": {"const": {"value": "unit"}}}})
                d["scope"]["inScope"]["surface"]["body"] = {"lastPat": {
                    "shadow": False, "pattern": {"const": {"value": row["value"]}},
                    "ty": base(row["type"]), "expr": {"literal": {"value": row["value"]}}}}
                corpus["inputs"][0]["definitions"] = [d]
                results = self.run_input(f"pattern-{row['name']}", corpus, builtins, stdlib)
                for tool in ["desugarDiff", "surfaceCheckAll"]:
                    result, report = results[tool]
                    self.assertEqual(result.returncode, 2)
                    self.assertIn("constant pattern is not supported", result.stderr + json.dumps(report))


if __name__ == "__main__":
    unittest.main()
