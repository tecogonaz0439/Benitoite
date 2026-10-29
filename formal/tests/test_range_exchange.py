"""corpus 15/sidecar 7 の範囲の独立入力を六入口で検査する（L50.2）。Cargo は起動しない。

範囲付きの原子と不透明型・組み込みの呼び出しの範囲の列・型表の範囲の変数と表のデータ・必須の判定の入力
（scopeAcceptance）を、Rust の書き出しや Lean の脱糖から作らずに手で書く。原子の種類別（パス・endpoint）、
Top でない範囲、拒否と理由（notCovered・unknownSource・budgetExceeded）、予算の停止による忘却を確かめる。
全 Top だけ・空の入力の一致を成功の証拠に数えない（Top でない範囲を持つ比較の件数を確かめる）。
"""

import argparse
import copy
import json
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest

shared = runpy.run_path(str(Path(__file__).with_name("test_named_exchange.py")))
FILES, TOOLS = shared["FILES"], shared["TOOLS"]

OUTPUT = None

STR = {"base": {"name": "String"}}
INT = {"base": {"name": "Integer"}}
UNIT = {"base": {"name": "Unit"}}
TOP = "top"
TREE = {"path": {"tree": ["data"]}}
ATREE = {"path": {"tree": ["data", "a"]}}
API = {"name": {"exact": ["api", "example", "com"]}}
EP443 = {"endpoint": {"host": API, "ports": {"lo": 443, "hi": 443}}}
EP444 = {"endpoint": {"host": API, "ports": {"lo": 443, "hi": 444}}}
EP80_443 = {"endpoint": {"host": API, "ports": {"lo": 80, "hi": 443}}}
# 最小のポートが最大より大きい区間（整形式でない範囲。交換の読者は拒否する）。
INVERTED = {"endpoint": {"host": API, "ports": {"lo": 443, "hi": 80}}}
# 192.168.1.0/24（host bits が 0、prefix が最大長より短い正規形）。
LAN = {"host": {"ip": {"cidr": {"family": "v4", "network": 3232235776, "prefixLen": 24}}}}
EPLAN = {"endpoint": {"host": LAN["host"], "ports": {"lo": 443, "hi": 443}}}


# 交換の不透明型の名前は「識別番号:型引数の JSON」の形である（Exchange.Builtins の Ty.hasOpaqueArguments）。
# 表のデータ（valKinds など）も同じ名前で引く。
PATH_IN, SCOPE_ERROR_T, IO_ERROR_T, REQUEST_IN = "101:[]", "102:[]", "103:[]", "105:[]"


def opaque(name, r=TOP):
    return {"opaque": {"name": name, "ix": {"fixed": r}}}


def opaque_var(name, i=0):
    return {"opaque": {"name": name, "ix": {"rvar": i}}}


def atom(name, r=TOP):
    return {"name": {"value": name, "ix": {"fixed": r}}}


def result(a, e):
    return {"data": {"name": "Result", "args": [a, e]}}


SCOPE_ERROR = opaque(SCOPE_ERROR_T)
IO_ERROR = opaque(IO_ERROR_T)
# Http.ClientRequest は五つの欄のレコード（Rust の Http.bnt と同じ欄）。検査済みの要求の値はこのレコードの値を保持し、
# 表のデータ valContents は Http.RequestIn にこの型を与える（L40.3c）。
CLIENT_REQUEST = {"data": {"name": "Http.ClientRequest", "args": []}}
PAIR_SS = {"data": {"name": "Pair", "args": [STR, STR]}}
CHECK_ERROR = {"data": {"name": "Http.RequestCheckError", "args": []}}


def header(names, params, ret, eff=()):
    return {"tparams": [], "neffs": 0, "effParams": [], "names": list(names), "params": list(params),
            "ret": ret, "eff": list(eff)}


def lit(s):
    return {"literal": {"value": {"string": {"value": s}}}}


def ilit(n):
    return {"literal": {"value": {"integer": {"value": n}}}}


def local(i):
    return {"local": {"index": i}}


def prim_call(name, ranges, labels, args):
    return {"call": {"callee": {"primName": {"name": name, "tys": [], "effs": [], "ranges": ranges}},
                     "labels": labels, "positions": list(range(len(args))), "args": args}}


def core_const(s):
    return {"ret": {"value": {"const": {"value": {"string": {"value": s}}}}}}


def core_var(i):
    return {"ret": {"value": {"var": {"index": i}}}}


def core_app(name, ranges, n):
    # 引数は全て束縛した後で番号 n-1,…,0 になる（Surface.Desugar.boundVars）。
    return {"app": {"callee": {"prim": {"name": name, "tys": [], "effs": [], "ranges": ranges}},
                    "args": [{"var": {"index": i}} for i in reversed(range(n))]}}


def let_chain(bounds, body):
    for b in reversed(bounds):
        body = {"letIn": {"bound": b, "body": body}}
    return body


def definition(key, h, body, core_body, lambda_effects=()):
    return {"name": f"{key[3:]}Def ({key})", "scope": {"inScope": {
        "surface": {"header": h, "body": body, "dictParams": [], "implementation": None, "method": None,
                    "supers": [], "coverageView": [], "package": "author"},
        "core": {"header": copy.deepcopy(h), "body": core_body, "lambdaEffects": list(lambda_effects),
                 "supers": []}}}}


def check_path_def(key, pattern, ranges, params=("raw",), param_types=(STR,)):
    """`let r = Scope.checkPathIn[R](pattern: P, path: raw); ()`。"""
    raw = local(0)
    pat = lit(pattern) if isinstance(pattern, str) else pattern
    ty = result(opaque(PATH_IN, ranges[0]), SCOPE_ERROR)
    call = prim_call("Scope.checkPathIn", ranges, ["pattern", "path"], [pat, raw])
    body = {"bind": {"shadow": False, "ty": ty, "expr": call, "rest": {"last": {"expr": "unit"}}}}
    # ソース順に一度ずつ評価する（リテラルは定数、局所は変数を一つずらして読む）。
    first = core_const(pattern) if isinstance(pattern, str) else core_var(pattern["local"]["index"])
    bound = let_chain([first, core_var(1)], core_app("Scope.checkPathIn", ranges, 2))
    core = {"letIn": {"bound": bound, "body": {"ret": {"value": {"const": {"value": "unit"}}}}}}
    return definition(key, header(params, param_types, UNIT), body, core)


def write_def(key, bound_range, call_range):
    """`File.writeTextIn[R](path: p, text: "x")` を、上限 `File.Write[S]` の関数の本体で返す。"""
    ret = result(UNIT, IO_ERROR)
    call = prim_call("File.writeTextIn", [call_range], ["path", "text"], [local(0), lit("x")])
    body = {"last": {"expr": {"returnE": {"ret": ret, "inner": call}}}}
    core = let_chain([core_var(0), core_const("x")], core_app("File.writeTextIn", [call_range], 2))
    return definition(key, header(["p"], [opaque(PATH_IN, call_range)], ret, [atom("File.Write", bound_range)]),
                      body, core)


def check_request_def(key, host, lo, hi, ranges):
    """`let r = Http.checkRequestIn[R](hostPattern: H, minimumPort: lo, maximumPort: hi, request: req); ()`。"""
    ty = result(opaque(REQUEST_IN, ranges[0]), CHECK_ERROR)
    call = prim_call("Http.checkRequestIn", ranges, ["hostPattern", "minimumPort", "maximumPort", "request"],
                     [lit(host), ilit(lo), ilit(hi), local(0)])
    body = {"bind": {"shadow": False, "ty": ty, "expr": call, "rest": {"last": {"expr": "unit"}}}}
    consts = [core_const(host), {"ret": {"value": {"const": {"value": {"integer": {"value": lo}}}}}},
              {"ret": {"value": {"const": {"value": {"integer": {"value": hi}}}}}}, core_var(3)]
    bound = let_chain(consts, core_app("Http.checkRequestIn", ranges, 4))
    core = {"letIn": {"bound": bound, "body": {"ret": {"value": {"const": {"value": "unit"}}}}}}
    return definition(key, header(["req"], [CLIENT_REQUEST], UNIT), body, core)


RESULT_DATA = {"name": "Result", "typeName": "Result", "isRecord": False, "extensible": False, "package": "stdlib",
               "builtin": "result", "ntys": 2, "ctors": [
                   {"name": "Ok", "constructorName": "Ok", "args": [{"tvar": {"index": 0}}], "fields": None},
                   {"name": "Error", "constructorName": "Error", "args": [{"tvar": {"index": 1}}], "fields": None}]}
CHECK_ERROR_DATA = {"name": "Http.RequestCheckError", "typeName": "Http.RequestCheckError", "isRecord": False,
                    "extensible": False, "package": "stdlib", "builtin": "ordinary", "ntys": 0, "ctors": [
                        {"name": "Http.RequestCheckError.InvalidUrl", "constructorName": "InvalidUrl",
                         "args": [STR], "fields": None},
                        {"name": "Http.RequestCheckError.Scope", "constructorName": "Scope",
                         "args": [SCOPE_ERROR], "fields": None}]}
PAIR_DATA = {"name": "Pair", "typeName": "Pair", "isRecord": True, "extensible": False, "package": "stdlib",
             "builtin": "ordinary", "ntys": 2, "ctors": [
                 {"name": "Pair", "constructorName": "Pair", "args": [{"tvar": {"index": 0}}, {"tvar": {"index": 1}}],
                  "fields": ["first", "second"]}]}
CLIENT_REQUEST_DATA = {"name": "Http.ClientRequest", "typeName": "Http.ClientRequest", "isRecord": True,
                       "extensible": False, "package": "stdlib", "builtin": "ordinary", "ntys": 0, "ctors": [
                           {"name": "Http.ClientRequest", "constructorName": "ClientRequest",
                            "args": [STR, STR, {"list": {"elem": PAIR_SS}}, "bytes", INT],
                            "fields": ["method", "url", "headers", "body", "timeoutMilliseconds"]}]}
DATA_DECLS = [RESULT_DATA, CHECK_ERROR_DATA, PAIR_DATA, CLIENT_REQUEST_DATA]
DATA_TYPES = [{k: d[k] for k in ("name", "typeName", "isRecord", "extensible", "package", "builtin")}
              for d in DATA_DECLS]
# 等値と鍵の導出の要約。always が真のときは常に導出できない（satisfiesB は !s.eq.always を求める）。Result と Pair は
# 二つの型引数に依存する。Http.RequestCheckError は不透明型の欄を持つので等値は常に導出できない（鍵も等値を要するので
# 導出できない）。Http.ClientRequest の欄は文字列・Pair のリスト・Bytes・整数だけなので、
# 要約は等値・鍵とも always が偽で、型引数への依存を持たない（Lean の summarizeTy が計算する値。導出を妨げる欄がない）。
SUMMARIES = [
    {"name": "Result", "eq": {"always": False, "dependsOn": [0, 1]}, "key": {"always": False, "dependsOn": [0, 1]}},
    {"name": "Http.RequestCheckError", "eq": {"always": True, "dependsOn": []},
     "key": {"always": False, "dependsOn": []}},
    {"name": "Pair", "eq": {"always": False, "dependsOn": [0, 1]}, "key": {"always": False, "dependsOn": [0, 1]}},
    {"name": "Http.ClientRequest", "eq": {"always": False, "dependsOn": []},
     "key": {"always": False, "dependsOn": []}},
]


def prim(name, names, params, ret, eff, kind, op_eff, rkinds, shape):
    return {"name": name, "tparams": [], "neffs": 0, "effParams": [], "names": names, "params": params, "ret": ret,
            "eff": eff, "kind": kind, "opEff": op_eff, "classConstraints": [], "unconvertibleTypes": [],
            "rkinds": rkinds, "shape": shape}


PRIMS = [
    prim("Scope.checkPathIn", ["pattern", "path"], [STR, STR],
         result(opaque_var(PATH_IN), SCOPE_ERROR), [], "pure", None, ["path"], "untargeted"),
    prim("File.writeTextIn", ["path", "text"], [opaque_var(PATH_IN), STR], result(UNIT, IO_ERROR),
         [{"name": {"value": "File.Write", "ix": {"rvar": 0}}}], "io", "File.Write", ["path"],
         {"single": {"kind": "path", "position": 0}}),
    prim("Http.checkRequestIn", ["hostPattern", "minimumPort", "maximumPort", "request"],
         [STR, INT, INT, CLIENT_REQUEST], result(opaque_var(REQUEST_IN), CHECK_ERROR), [], "pure", None,
         ["endpoint"], "untargeted"),
]
TABLE_DATA = {
    "effKinds": [{"name": "File.Write", "kind": "path"}, {"name": "Http.Connect", "kind": "endpoint"}],
    "valKinds": [{"name": PATH_IN, "kind": "path"}, {"name": REQUEST_IN, "kind": "endpoint"}],
    "admitsR": [{"name": "Scope.checkPathIn", "rule": "any"}, {"name": "File.writeTextIn", "rule": "any"},
                {"name": "Http.checkRequestIn", "rule": "any"}],
    "valContents": [{"name": REQUEST_IN, "content": CLIENT_REQUEST}],
}
WIDE = {"body": {"operations": 1000, "items": 1000}, "whole": {"operations": 10000, "items": 10000}}
ZERO = {"body": {"operations": 0, "items": 0}, "whole": {"operations": 0, "items": 0}}
SCOPE = {"patterns": [{"text": "/data/**", "range": TREE}],
         "hosts": [{"text": "api.example.com", "pattern": API}, {"text": "192.168.1.0/24", "pattern": LAN["host"]}],
         "limits": WIDE}

# 定義の鍵と、入口が返す結果（None は受理、それ以外は拒否の理由）。
PATH_CASES = {
    "fn:1": (check_path_def("fn:1", "/data/**", [TREE]), None),
    "fn:2": (check_path_def("fn:2", "/data/**", [ATREE]), "notCovered"),
    "fn:3": (check_path_def("fn:3", local(1), [TREE], ("pattern", "raw"), (STR, STR)), "unknownSource"),
    "fn:4": (check_path_def("fn:4", local(1), [TOP], ("pattern", "raw"), (STR, STR)), None),
    "fn:5": (write_def("fn:5", TREE, ATREE), None),
    "fn:6": (check_request_def("fn:6", "api.example.com", 443, 443, [EP443]), None),
    "fn:7": (check_request_def("fn:7", "api.example.com", 443, 444, [EP443]), "notCovered"),
    "fn:8": (check_request_def("fn:8", "192.168.1.0/24", 443, 443, [EPLAN]), None),
    # 最小が最大より大きいリテラルのポートは整形式の範囲を作らないので、必須の判定は未知（Top）になる。狭い契約は
    # unknownSource で拒否し、Top の契約は受理する。正しい順のリテラルは既知のまま読む（L40.3d）。
    "fn:9": (check_request_def("fn:9", "api.example.com", 443, 80, [EP80_443]), "unknownSource"),
    "fn:10": (check_request_def("fn:10", "api.example.com", 443, 80, [TOP]), None),
    "fn:11": (check_request_def("fn:11", "api.example.com", 80, 443, [EP80_443]), None),
}
# 予算の上限 0 の入力。解析は最初の一段で予算を超えて全ての由来を忘れ（forgetAll）、局所に由来を持つ位置は Top に
# なる。狭い契約は budgetExceeded で拒否する。リテラルのパターンは事実によらず既知なので、予算の超過の後も受理する。
BUDGET_CASES = {
    "fn:21": (check_path_def("fn:21", local(1), [TREE], ("pattern", "raw"), (STR, STR)), "budgetExceeded"),
    "fn:22": (check_path_def("fn:22", local(1), [TOP], ("pattern", "raw"), (STR, STR)), None),
    "fn:23": (check_path_def("fn:23", "/data/**", [TREE]), None),
}


def corpus_input(name, cases, limits):
    return {"group": "golden", "name": name, "excluded": [], "dataTypes": DATA_TYPES,
            "definitions": [copy.deepcopy(d) for d, _ in cases.values()], "constants": [], "ops": [],
            "effects": [], "primOps": [], "classes": [], "impls": [],
            "scopeAcceptance": {**copy.deepcopy(SCOPE), "limits": limits}}


def builtin_input(name):
    return {"group": "golden", "name": name, "prims": copy.deepcopy(PRIMS),
            "effects": [{"name": "State", "ops": []}, {"name": "File.Write", "ops": ["File.writeTextIn"]}],
            "resources": [], "dataDecls": copy.deepcopy(DATA_DECLS), "summaries": copy.deepcopy(SUMMARIES),
            "statePure": [], "supplementalData": [], "supplementalPrims": [], **copy.deepcopy(TABLE_DATA)}


def fixtures():
    names = [("range-paths", PATH_CASES, WIDE), ("range-budget", BUDGET_CASES, ZERO)]
    return {
        "corpus": {"version": 15, "operators": [], "annotations": {"tailMatch": [0, 0]},
                   "inputs": [corpus_input(n, c, lim) for n, c, lim in names]},
        "builtins": {"version": 7, "inputs": [builtin_input(n) for n, _, _ in names]},
        "stdlib": {"version": 7, "inputs": [{"group": "golden", "name": n, "functions": [], "impls": []}
                                            for n, _, _ in names]},
        # 範囲付きの原子を潜在効果に持つ関数の型の照合（通常の網羅性）。
        "coverage": {"version": 7, "seedXor": 0, "randomCases": 0, "boundaryCases": 1, "kinds": {}, "cases": [
            {"name": "ranged-function", "decls": [], "ty": {"kind": "function", "names": ["value"],
             "params": [{"kind": "integer", "args": []}], "ret": {"kind": "integer", "args": []},
             "eff": [atom("File.Write", TREE)]}, "arms": [{"guarded": False, "alts": [{"kind": "wild"}]}],
             "pattern": {"kind": "wild"}, "expected": {"exhaustive": True, "uncovered": None, "unreachable": []},
             "irrefutable": True, "irrefutableWitness": None, "coverageView": [], "package": "author"}]},
        # 範囲付きの値型の照合（プログラムの網羅性）。Ok と Error の二つの腕で網羅する。
        "coverage-program": {"version": 7, "inputs": [
            {"group": "golden", "name": "range-paths", "matches": [{"node": 1,
             "scrutineeTy": result(opaque(PATH_IN, TREE), SCOPE_ERROR),
             "arms": [{"alts": [{"con": {"name": "Ok", "args": ["wild"]}}], "guarded": False},
                      {"alts": [{"con": {"name": "Error", "args": ["wild"]}}], "guarded": False}],
             "coverageView": [], "package": "author"}], "bindings": []},
            {"group": "golden", "name": "range-budget", "matches": [], "bindings": []}]},
    }


def non_top_ranges(value):
    """Top でない範囲の数（範囲の位置の閉じた範囲と、呼び出しの範囲の列の要素）。"""
    if isinstance(value, list):
        return sum(non_top_ranges(v) for v in value)
    if not isinstance(value, dict):
        return 0
    count = 0
    for k, v in value.items():
        if k == "ix" and v.get("fixed", TOP) != TOP:
            count += 1
        if k == "ranges":
            count += sum(1 for r in v if r != TOP)
        count += non_top_ranges(v)
    return count


class RangeExchangeTests(unittest.TestCase):
    def setUp(self):
        self.data = fixtures()
        self.tmp = tempfile.TemporaryDirectory(prefix="benitoite-range-exchange-")
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)

    def run_tool(self, tool, data=None, selected=None, input_name="range-paths"):
        result, report = shared["ExchangeTests"].run_tool(self, tool, data, selected, input_name)
        if OUTPUT is not None:
            sequence = len(list(OUTPUT.glob("call-*")))
            saved = OUTPUT / f"call-{sequence:03d}-{self._testMethodName}-{tool}"
            saved.mkdir()
            for file in self.directory.glob("*.json"):
                (saved / file.name).write_bytes(file.read_bytes())
            (saved / "process.json").write_text(json.dumps({"exit":result.returncode,
                "stdout":result.stdout,"stderr":result.stderr,"tool":tool,
                "selected":selected,"input":input_name},indent=2)+"\n")
        return result, report

    def test_fixture_is_not_all_top(self):
        # 全 Top だけの入力を成功の証拠にしない。種類別に Top でない範囲を持つ。
        self.assertGreaterEqual(non_top_ranges(self.data["corpus"]), 20)
        text = json.dumps(self.data["corpus"])
        for kind in ('"path"', '"endpoint"', '"ip"'):
            self.assertIn(kind, text)

    def test_six_entries(self):
        for tool in TOOLS:
            with self.subTest(tool=tool):
                if tool == "surfaceCheck":
                    continue
                result, report = self.run_tool(tool)
                if tool == "surfaceCheckAll":
                    # 拒否を期待する定義は Rust が受理しない入力なので、不一致として数える（1 で終わる）。
                    self.assertEqual(result.returncode, 1, result.stderr + result.stdout)
                    # Top でない範囲を持つ比較であることを報告の件数で確かめる（corpus の数え方と同じ）。
                    self.assertEqual(report["nonTopRanges"], non_top_ranges(self.data["corpus"]["inputs"]))
                    outcomes = {o["definition"]: o for o in report["outcomes"]}
                    for key, (_, reason) in {**PATH_CASES, **BUDGET_CASES}.items():
                        name = next(n for n in outcomes if n.endswith(f"({key})") or n == key)
                        if reason is None:
                            self.assertEqual(outcomes[name]["category"], "matched", (key, outcomes[name]))
                        else:
                            self.assertEqual(outcomes[name]["category"], "mismatched", key)
                            self.assertIn(f'required check is not covered:', json.dumps(outcomes[name]))
                            self.assertIn(reason, json.dumps(outcomes[name]))
                    continue
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout + json.dumps(report))
                if tool == "desugarDiff":
                    total = len(PATH_CASES) + len(BUDGET_CASES)
                    self.assertEqual(report["golden"]["definitions"],
                                     dict(matched=total, mismatched=0, outside=0, excluded=0))
                    self.assertEqual(report["nonTopRanges"], non_top_ranges(self.data["corpus"]))
                    self.assertGreater(report["nonTopRanges"], 0)
                elif tool == "builtinCheck":
                    self.assertEqual(report["errors"], [])
                    self.assertEqual(report["checkedInputs"], 2)
                elif tool == "coverageDiff":
                    self.assertEqual((report["matched"], report["mismatched"]), (1, 0))
                elif tool == "coverageProgramDiff":
                    self.assertEqual((report["matched"], report["mismatched"]), (1, 0))

    def test_groups_are_non_top_at_both_entries(self):
        # 候補以外の範囲が群ごとに残ることを、両入口の個別報告で確かめる。
        for name, cases in (("range-paths", PATH_CASES), ("range-budget", BUDGET_CASES)):
            data = copy.deepcopy(self.data)
            for field in ("corpus", "builtins", "stdlib", "coverage-program"):
                data[field]["inputs"] = [i for i in data[field]["inputs"] if i["name"] == name]
            count = non_top_ranges(data["corpus"])
            self.assertGreater(count, 0, name)
            rejected = sum(reason is not None for _, reason in cases.values())
            for tool in ("desugarDiff", "surfaceCheckAll"):
                with self.subTest(input=name, tool=tool):
                    process, report = self.run_tool(tool, data, input_name=name)
                    self.assertEqual(process.returncode, 0 if tool == "desugarDiff" else 1, process.stderr)
                    self.assertEqual(report["nonTopRanges"], count)
                    self.assertGreater(report["nonTopRanges"], 0)
                    if tool == "desugarDiff":
                        self.assertEqual(report["golden"]["definitions"],
                                         dict(matched=len(cases), mismatched=0, outside=0, excluded=0))
                    else:
                        self.assertEqual(report["counts"], dict(matched=len(cases)-rejected,
                            mismatched=rejected, q11=0, outOfScope=0, lazyRestriction=0, preparationFailure=0))

    def test_surface_check_reasons(self):
        for input_name, cases in (("range-paths", PATH_CASES), ("range-budget", BUDGET_CASES)):
            for key, (_, reason) in cases.items():
                with self.subTest(input=input_name, key=key):
                    result, report = self.run_tool("surfaceCheck", selected=key, input_name=input_name)
                    if reason is None:
                        self.assertEqual(result.returncode, 0, result.stderr + json.dumps(report))
                        self.assertEqual(report["result"], {"ok": True})
                    else:
                        self.assertEqual(result.returncode, 1, result.stderr + json.dumps(report))
                        self.assertEqual(report["result"]["cover"]["reason"], reason)
                        self.assertEqual(report["result"]["cover"]["key"]["surfacePreorder"], 0)
        # 選んだ定義でなく入口全体でも、最初に拒否した定義と理由を返す。
        result, report = self.run_tool("surfaceCheck")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(report["result"]["cover"]["reason"], "notCovered")

    def test_cover_only_effect_bound(self):
        # 上限 File.Write[/data/**] の本体が /data/a/** へ書く（被覆だけの包含）。上限が覆わなければ拒否する。
        data = copy.deepcopy(self.data)
        d = data["corpus"]["inputs"][0]["definitions"][4]
        for part in ("surface", "core"):
            d["scope"]["inScope"][part]["header"]["eff"] = [atom("File.Write", ATREE)]
        d["scope"]["inScope"]["surface"]["body"]["last"]["expr"]["returnE"]["inner"]["call"]["callee"]["primName"]["ranges"] = [TREE]
        d["scope"]["inScope"]["surface"]["header"]["params"] = [opaque(PATH_IN, TREE)]
        result, report = self.run_tool("surfaceCheck", data, selected="fn:5")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(report["result"]["error"]["reason"], "effect exceeds the allowed effect")
        # Top の原子は範囲付きの上限に覆われない。
        data = copy.deepcopy(self.data)
        d = data["corpus"]["inputs"][0]["definitions"][4]
        for part in ("surface", "core"):
            d["scope"]["inScope"][part]["header"]["eff"] = [atom("File.Write", TREE)]
        d["scope"]["inScope"]["surface"]["body"]["last"]["expr"]["returnE"]["inner"]["call"]["callee"]["primName"]["ranges"] = [TOP]
        d["scope"]["inScope"]["surface"]["header"]["params"] = [opaque(PATH_IN, TOP)]
        result, report = self.run_tool("surfaceCheck", data, selected="fn:5")
        self.assertEqual(result.returncode, 1, result.stderr)

    def test_all_top_input_reports_no_ranges(self):
        # 範囲を全て Top にした入力では、比較が一致しても Top でない範囲の数は 0 と報告する。
        data = copy.deepcopy(self.data)

        def to_top(value):
            if isinstance(value, list):
                return [to_top(v) for v in value]
            if not isinstance(value, dict):
                return value
            out = {k: to_top(v) for k, v in value.items()}
            if "ix" in out and "fixed" in out["ix"]:
                out["ix"] = {"fixed": TOP}
            if "ranges" in out:
                out["ranges"] = [TOP for _ in out["ranges"]]
            return out
        data["corpus"]["inputs"] = to_top(data["corpus"]["inputs"])
        result, report = self.run_tool("desugarDiff", data)
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual(report["nonTopRanges"], 0)

    def test_input_validation(self):
        cases = {
            # 正規形でない CIDR（prefix が最大長）と、host bits が 0 でない CIDR（整形式でない）。
            "noncanonical cidr": ("scopeAcceptance", {"hosts": [{"text": "h", "pattern": {"ip": {"cidr": {
                "family": "v4", "network": 3232235777, "prefixLen": 32}}}}]}),
            "host bits": ("scopeAcceptance", {"hosts": [{"text": "h", "pattern": {"ip": {"cidr": {
                "family": "v4", "network": 3232235777, "prefixLen": 24}}}}]}),
            "missing scope": ("scopeAcceptance", None),
        }
        for label, (field, value) in cases.items():
            with self.subTest(label=label):
                data = copy.deepcopy(self.data)
                target = data["corpus"]["inputs"][0]
                if value is None:
                    target[field] = None
                else:
                    target[field] = {**target[field], **value}
                outcome, _ = self.run_tool("desugarDiff", data)
                self.assertEqual(outcome.returncode, 2, outcome.stdout)
        # プログラムの型に範囲の変数を置かせない。型表でも項目の範囲の変数の個数を超える番号は拒否する。
        data = copy.deepcopy(self.data)
        data["corpus"]["inputs"][0]["definitions"][0]["scope"]["inScope"]["surface"]["header"]["params"] = [
            opaque_var(PATH_IN)]
        outcome, _ = self.run_tool("desugarDiff", data)
        self.assertEqual(outcome.returncode, 2)
        self.assertIn("rvar", outcome.stderr)
        data = copy.deepcopy(self.data)
        data["builtins"]["inputs"][0]["prims"][0]["ret"] = result(opaque_var(PATH_IN, 1), SCOPE_ERROR)
        outcome, _ = self.run_tool("builtinCheck", data)
        self.assertEqual(outcome.returncode, 2)
        self.assertIn("range variable index out of bounds", outcome.stderr)
        data = copy.deepcopy(self.data)
        data["builtins"]["inputs"][0]["admitsR"][0]["rule"] = {"covers": {"inner": 0, "outer": 1}}
        outcome, _ = self.run_tool("builtinCheck", data)
        self.assertEqual(outcome.returncode, 2)
        self.assertIn("admitsR range index out of bounds", outcome.stderr)
        # 最小のポートが最大より大きい区間（整形式でない範囲）は、呼び出しの範囲の列に書いても拒否する（L40.3d）。
        data = copy.deepcopy(self.data)
        d = data["corpus"]["inputs"][0]["definitions"][5]
        d["scope"]["inScope"]["surface"]["body"]["bind"]["expr"]["call"]["callee"]["primName"]["ranges"] = [INVERTED]
        outcome, _ = self.run_tool("desugarDiff", data)
        self.assertEqual(outcome.returncode, 2, outcome.stdout)
        self.assertIn("range is not well formed or not canonical", outcome.stderr)
        # 保持する要求の型は型として書く。L40.3c より前の、型の名前の文字列を書いた入力は読まない。
        data = copy.deepcopy(self.data)
        data["builtins"]["inputs"][0]["valContents"][0]["content"] = "104:[]"
        outcome, _ = self.run_tool("builtinCheck", data)
        self.assertEqual(outcome.returncode, 2, outcome.stdout)
        self.assertIn("unknown type constructor", outcome.stderr)
        # 旧版の入力に必須の判定の入力を置かせない。
        data = copy.deepcopy(self.data)
        data["corpus"]["version"] = 14
        outcome, _ = self.run_tool("desugarDiff", data)
        self.assertEqual(outcome.returncode, 2)


def with_explicit_ranges(value):
    """Surface 14 の名前の原子・不透明型・組み込みの呼び出しに明示の Top と空の範囲の列を書いた Surface 15 の形。"""
    if isinstance(value, list):
        return [with_explicit_ranges(v) for v in value]
    if not isinstance(value, dict):
        return value
    out = {k: with_explicit_ranges(v) for k, v in value.items()}
    if list(out) == ["name"] and isinstance(out["name"], dict) and "value" in out["name"]:
        out["name"] = {**out["name"], "ix": {"fixed": TOP}}
    if list(out) == ["opaque"] and isinstance(out["opaque"], dict) and "name" in out["opaque"]:
        out["opaque"] = {**out["opaque"], "ix": {"fixed": TOP}}
    for key in ("prim", "primName"):
        if list(out) == [key] and isinstance(out[key], dict) and "tys" in out[key]:
            out[key] = {**out[key], "ranges": []}
    return out


class IntervalSurfaceVersionTests(unittest.TestCase):
    """区間解析の独立交換（intervalDiff）が埋め込みの Surface 15 を読む。範囲は区間解析に影響しない。"""

    def setUp(self):
        self.interval = runpy.run_path(str(Path(__file__).with_name("test_interval_exchange.py")))
        self.tmp = tempfile.TemporaryDirectory(prefix="benitoite-range-interval-")
        self.addCleanup(self.tmp.cleanup)
        self.directory = Path(self.tmp.name)

    def run_interval(self, label, corpus, mode="analyze"):
        source, report = self.directory / f"{label}.json", self.directory / f"{label}.report.json"
        source.write_text(json.dumps(corpus))
        result = subprocess.run([str(shared["BIN"] / "intervalDiff"), mode, str(source), str(report)],
                                text=True, capture_output=True, timeout=30)
        if OUTPUT is not None:
            saved = OUTPUT / f"interval-{label}"
            saved.mkdir(exist_ok=True)
            (saved / "corpus.json").write_bytes(source.read_bytes())
            if report.exists():
                (saved / "report.json").write_bytes(report.read_bytes())
            (saved / "process.json").write_text(json.dumps({"exit":result.returncode,
                "stdout":result.stdout,"stderr":result.stderr,"mode":mode},indent=2)+"\n")
        return result, (json.loads(report.read_text()) if report.exists() else None)

    def domain(self):
        # domain の profile は組み込みの呼び出し（primName）を持つ。範囲の列の欄を書き足す節点がある。
        return self.interval["extra_fixtures"]()[2]

    def test_surface15_same_analysis(self):
        base = self.domain()
        # 埋め込みの Surface に範囲の位置を持つ節点があること（全て Top の変換だけの一致を成功と数えない）。
        explicit = with_explicit_ranges(base)
        self.assertNotEqual(json.dumps(explicit), json.dumps(base))
        for mode in ("analyze", "eval"):
            with self.subTest(mode=mode):
                old, old_report = self.run_interval(f"v14-{mode}", base, mode)
                new = {**copy.deepcopy(explicit), "surfaceVersion": 15}
                fresh, new_report = self.run_interval(f"v15-{mode}", new, mode)
                # 単独の profile の受け入れの条件（全 profile の照合）は test_interval_exchange.py が受け持つ。ここでは
                # 版14と版15の報告と終了状態が同じであること（範囲の欄は区間解析の結果を変えない）を確かめる。
                self.assertIn(old.returncode, (0, 1), old.stderr)
                self.assertEqual(fresh.returncode, old.returncode, fresh.stderr)
                self.assertEqual(old_report, new_report)
                self.assertNotIn("invalidInput", json.dumps(new_report))

    def test_surface_version_boundaries(self):
        base = self.domain()
        # 版14に範囲の欄、版15に欠けた範囲の欄・範囲の変数・正規形でない範囲を置かせない。
        cases = [("v14-ix", {**with_explicit_ranges(base), "surfaceVersion": 14}),
                 ("v15-missing", {**copy.deepcopy(base), "surfaceVersion": 15})]
        rvar = with_explicit_ranges(base)
        rvar["surfaceVersion"] = 15
        rvar["inputs"][0]["modules"][0]["definitions"][0]["params"] = [opaque_var(PATH_IN)]
        cases.append(("v15-rvar", rvar))
        for label, corpus in cases:
            with self.subTest(label=label):
                result, _ = self.run_interval(label, corpus)
                self.assertEqual(result.returncode, 2, result.stdout)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    args, rest = parser.parse_known_args()
    OUTPUT = args.output
    if OUTPUT is not None:
        OUTPUT.mkdir(parents=True, exist_ok=True)
        for name, value in fixtures().items():
            (OUTPUT / f"independent-{name}.json").write_text(json.dumps(value,indent=2)+"\n")
    suite = unittest.defaultTestLoader.loadTestsFromModule(__import__(__name__))
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if OUTPUT is not None:
        (OUTPUT / "summary.json").write_text(json.dumps({"testsRun":result.testsRun,
            "failures":len(result.failures),"errors":len(result.errors),
            "skipped":len(result.skipped),"status":"passed" if result.wasSuccessful() else "failed"},indent=2)+"\n")
    raise SystemExit(0 if result.wasSuccessful() else 1)
