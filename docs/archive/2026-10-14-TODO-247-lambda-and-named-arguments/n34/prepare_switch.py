"""正式モデルを変更せず、名前空間の移動と文書の patch を作る。"""
import difflib
import hashlib
import json
from pathlib import Path
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FAMILIES = ("Release", "Surface", "Exchange", "DesugarDiff", "BuiltinCheck",
            "CoverageDiff", "CoverageProgramDiff", "SurfaceCheck")
TOOLS = ("desugarDiff", "builtinCheck", "coverageDiff", "coverageProgramDiff",
         "surfaceCheck", "surfaceCheckAll")


def promoted(text):
    for family in FAMILIES:
        text = text.replace("Named" + family, family)
    for tool in TOOLS:
        text = text.replace("named" + tool[0].upper() + tool[1:], tool)
    return text


def sha(text):
    return hashlib.sha256(text.encode()).hexdigest()


def main():
    changes = {}
    moves = []
    theorems = []
    for family in FAMILIES:
        parent = "formal/Benitoite" if family in ("Release", "Surface", "Exchange") else "formal"
        source_dir = ROOT / parent / ("Named" + family)
        for source in sorted(source_dir.rglob("*.lean")):
            destination = Path(parent) / family / source.relative_to(source_dir)
            original = source.read_text()
            result = promoted(original)
            changes[str(destination)] = result
            moves.append(dict(source=str(source.relative_to(ROOT)), destination=str(destination),
                              sourceSha256=sha(original), promotedSha256=sha(result)))
            for match in re.finditer(r"^(?:protected |private )?theorem\s+([^\s({:]+)", original, re.M):
                statement = re.split(r":=|\n\s+\|", original[match.start():], maxsplit=1)[0].rstrip()
                theorems.append(dict(source=str(source.relative_to(ROOT)), destination=str(destination), name=match[1],
                                     beforeStatement=statement, afterStatement=promoted(statement),
                                     statementAndProof="identical after namespace substitution"))
    root = (ROOT / "formal/Benitoite.lean").read_text()
    changes["formal/Benitoite.lean"] = "\n".join(
        promoted(line) for line in root.splitlines()
        if line.startswith("import Benitoite.Core.") or line.startswith("import Benitoite.Named")) + "\n"
    lake = (ROOT / "formal/lakefile.toml").read_text()
    lake = re.sub(r'defaultTargets = .*', 'defaultTargets = ["Benitoite", ' +
                  ", ".join(json.dumps(t) for t in TOOLS) + "]", lake)
    # 移行用の実行ファイルとライブラリの登録を外す。実体の削除は次の作業で行う。
    lake = re.sub(r'\n\[\[lean_(?:exe|lib)\]\]\nname = "(?:named|Named)[^\n]+\n(?:root = [^\n]+\n)?', "\n", lake)
    changes["formal/lakefile.toml"] = lake
    doc = "docs/design/01-spec/01-12-core-calculus.md"
    original = (ROOT / doc).read_text()
    changes[doc] = original.replace("### 確かめる性質", (HERE / "core-rules.md").read_text() + "### 確かめる性質", 1)
    doc = "docs/design/07-quality/07-04-formal-semantics.md"
    original = (ROOT / doc).read_text()
    original = original.replace("型検査の出力の `surfaceCheckAll`", "型検査の出力の `surfaceCheck`・`surfaceCheckAll`")
    row = "| 契約名を持つ関数型・ラムダ・宣言と名前付き呼び出し | 段階 B・C・E の定義を拡張 | 正式モデルは `Release`・`Surface`・`Exchange` を使う。関数型・ラムダ・宣言の契約名、ソース順のラベル・式、宣言位置の対応、穴のソース順の名前と位置 0 へのパイプの挿入を保持する。`NamesWF` は長さと一意性を表す。ラムダ自身の条件は型付けから、`V_Fun`・`V_Prim`・`V_Op`・`C_Meth`・`HasTypeClauses.cons` の条件は宣言の整形式から従う。型注釈内部、内部名を連結した `coreNames`、未使用を含む `conFields`、全操作・クラス・組み込みの宣言の条件は、01-12「範囲条件と実装の名前の検査」のとおり範囲条件として保持する。型付けだけから全てを導くとは扱わない。実装の実名一致は `ImplDecl.WellTyped` の射影ではなく `checkImpl_contracts`・`checkProgram_contracts` の検査成功から得る。`CallOk.recordFields_source` は挿入を含む保存値の配置を保証する。ソース順の評価は脱糖の定義と具体例で確認し、型保存を IO 順全体の意味保存と呼ばない |\n| 内部名と利用者名の非衝突を支える字句規則、契約の推論と移行診断 | 対象外 | `%dict1` 以降と利用者名の非衝突は型付きモデルで字句規則から証明しない。性質 1 は連結後の名前の整形式を範囲条件から受け取る。一般の関数型・通常呼び出し・穴・パイプ・構成子値・操作・メソッドの型付きの規則は対象内である |\n"
    original = original.replace("| 構文 | 段階 A |", row + "| 構文 | 段階 A |", 1)
    original = original.replace("### 01-12 との対応", "六つの入口は corpus 8・組み込みと標準ライブラリの型表 2・網羅性 2 のみを受け付ける。契約名・ラベル・位置の欠落を自動補完しない。一般入力の全件と独立した網羅性の全件を同じ最終形式で比較し、対象外の理由も照合する。段階 A の `Core` は保持する。\n\n### 01-12 との対応", 1)
    changes[doc] = original
    doc = "docs/design/07-quality/07-03-compiler-testing.md"
    original = (ROOT / doc).read_text()
    marker = "### コア IR の検査"
    assert marker in original
    changes[doc] = original.replace(marker, "形式化との差分検査では、全入力を corpus 8・型表 2・網羅性 2 へ書き出し、六つの正式入口（desugarDiff・builtinCheck・coverageDiff・coverageProgramDiff・surfaceCheck・surfaceCheckAll）で比較する。入力識別子・除外理由・対象内の定義数・対象外の理由を manifest と照合する。名前・対応位置・穴・挿入の情報を壊した入力は、意図した契約の誤りとして拒否されることを確認する。\n\n" + marker, 1)
    # 実際の検査は最終形式だけに接続する。陰性の条件と件数の assertion は残す。
    checker_path = "crates/benitoite/tests/desugar_export/check_named.py"
    checker = (ROOT / checker_path).read_text()
    checker = checker.replace("    check_legacy_reports(directory, coverage_dir, manifest[\"legacyReports\"])\n", "")
    checker = checker.replace("    check_legacy(directory, manifest[\"legacy\"])\n", "")
    checker = checker.replace('    legacy = read(directory / "corpus.json")\n    require(not set(keys) & {(i["group"], i["name"]) for i in legacy["inputs"]}, "program in both versions")\n', "")
    checker = checker.replace('    check_coverage_exports(coverage_dir, manifest["coverageExports"])', '    check_coverage_exports(coverage_dir, {k: v for k, v in manifest["coverageExports"].items() if k})')
    changes[checker_path] = promoted(checker)
    changes["formal/tests/test_named_exchange.py"] = promoted((ROOT / "formal/tests/test_named_exchange.py").read_text()).replace('startswith("namedCoverage")', 'startswith("coverage")')
    script_path = "scripts/check-formal.sh"
    script = (ROOT / script_path).read_text()
    # 旧入口の独立入力は登録から外し、同じ全件の最終形式を六入口に渡す。
    script = script.replace('"$coverage_dir/corpus.json"', '"$coverage_dir/named-all-corpus.json"')
    for before, after in (("corpus.json", "named-programs-corpus.json"), ("builtins.json", "named-programs-builtins.json"),
                          ("stdlib-decls.json", "named-programs-stdlib.json"), ("coverage-matches.json", "named-programs-coverage.json")):
        script = script.replace(f'"$output_dir/{before}"', f'"$output_dir/{after}"')
    changes[script_path] = script
    width_path = "formal/tests/test_width_exchange.py"
    width = (ROOT / width_path).read_text()
    width = width.replace('"params": list(params)', '"names": ["x"] if len(params) == 1 else ["left", "right"] if len(params) == 2 else [], "params": list(params)')
    width = width.replace('return {"name": name, **header(ret, params), "kind": "pure"', 'return {"name": name, **header(ret, params), "names": (["b"] if name.startswith("UnsignedInteger8.") else ["n"]) if name.endswith(".toString") else ["value"] if len(params) == 1 else ["left", "right"] if len(params) == 2 else [], "kind": "pure"')
    width = width.replace('"version": 7', '"version": 8').replace('"version": 1', '"version": 2')
    changes[width_path] = width
    patch = []
    files = []
    for path, after in sorted(changes.items()):
        destination = ROOT / path
        before = destination.read_text() if destination.exists() else ""
        if before == after:
            continue
        patch.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                     fromfile="a/" + path if destination.exists() else "/dev/null", tofile="b/" + path))
        files.append(dict(path=path, beforeSha256=sha(before), afterSha256=sha(after)))
    (HERE / "n34a-switch.patch").write_text("".join(patch))
    for name, value in (("switch-manifest.json", dict(files=files, moves=moves, stageACoreUnchanged=True,
                         temporarySources="retain files; remove registrations now; delete in N34b")),
                        ("theorem-correspondence.json", theorems)):
        (HERE / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    print(f"patch: {len(files)} files, {len(moves)} mechanical moves, {len(theorems)} theorem declarations")


if __name__ == "__main__":
    main()
