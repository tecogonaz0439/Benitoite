#!/usr/bin/env python3
"""L16 の接続前に固定二形の予算への影響を調べる。一時ファイルだけを実行する。"""

from pathlib import Path
import subprocess
import tempfile
import time


ROOT = Path(__file__).resolve().parents[3]
FORMAL = ROOT / "formal"
source = (FORMAL / "Benitoite/Interval/BudgetAnalyze.lean").read_text()
reference = (ROOT / "crates/benitoite/testdata/interval-budget/budget-reference.lean").read_text()

# 本番の BudgetAnalyze は変更しない。構造的な予算の差だけを再現する。
# 乗算の例は右辺が Bottom なので own へ到達せず、乗算本体を要しない。
# 負号の例は除算結果の Top を受け取り、全域外の警告を要しない。
namespace = "Benitoite.Interval.L16BudgetProbe"
start = source.index("namespace Benitoite.Interval.BudgetAnalysis")
end = source.index("/-- 忘却後の環境を受け取り、本体の初期化や終了を挟まず走査する。 -/")
probe = source[start:end].replace(
    "namespace Benitoite.Interval.BudgetAnalysis",
    f"namespace {namespace}\nopen Benitoite.Interval.BudgetAnalysis",
    1,
)
old = "decide (op = .add ∨ IntegerDivisionOp op ∨ (Comparison.ofBinOp op).isSome = true)"
assert probe.count(old) == 1
probe = probe.replace(old, old.replace("op = .add ∨", "op = .add ∨ op = .mul ∨"), 1)
old = "  let result := baseOwn key op type left right"
assert probe.count(old) == 1
probe = probe.replace(old, """  -- 乗算本体に到達する入力には、未実装の演算結果を返さない。
  if op == .mul then throw .depth
""" + old, 1)
old = "    | .paren child => expr fuel env child"
assert probe.count(old) == 1
probe = probe.replace(old, """    | .neg (.base .integer) child => do
      let value ← expr fuel env child
      if !value.live then pure value.abrupt
      else if negAlwaysOverflows (kind := .integer64) (by decide) value.integer then
        -- この試行は警告の必要な負号を対象にせず、誤った成功値を返さない。
        throw .depth
      else
        let normal := negNormal (kind := .integer64) (by decide) value.integer
        pure (baseThen value (baseInteger normal true))
""" + old, 1)
body_start = source.index("/-- 本体の根も式として数え、入口環境の一時項目は解析の終了まで保持する。 -/")
body_end = source.index("end Benitoite.Interval.BudgetAnalysis", body_start)
probe += source[body_start:body_end] + f"end {namespace}\n"

# A11 の既存の入力、入口の準備、行の射影をそのまま使う。
ref_start = reference.index("open Benitoite.Surface")
ref_end = reference.index("-- 各資源の全停止位置")
driver = reference[ref_start:ref_end]
driver = driver.replace(
    "private def bodyRow (name : String)",
    "private def bodyRow (probe : Bool) (name : String)",
    1,
)
old = "let output := analyzeBody limits ctx.budget 200 name seed"
assert driver.count(old) == 1
driver = driver.replace(old, """let output := if probe then L16BudgetProbe.analyzeBody limits ctx.budget 200 name seed
        else BudgetAnalysis.analyzeBody limits ctx.budget 200 name seed""", 1)
driver += """
-- 前提を満たす固定二形だけを試す。新しい固定表の生成には使わない。
#eval do
  for (name, params, body) in cases do
    if name == "unsupported" || name == "negate" then
      for probe in ([false, true] : List Bool) do
        for kind in [0, 1, 2, 3] do
          for cap in [0, 16, 20, 200] do
            IO.println (s!"{if probe == true then "probe" else "baseline"}\\t" ++
              bodyRow probe name params body kind cap)
"""

with tempfile.TemporaryDirectory(prefix="benitoite-l16-") as temp:
    lean = Path(temp) / "BudgetImpact.lean"
    lean.write_text("import Benitoite.Interval.BudgetWhole\n" + probe + driver)
    started = time.monotonic()
    result = subprocess.run(
        ["lake", "env", "lean", "-M", "12288", str(lean)],
        cwd=FORMAL, text=True, capture_output=True, check=False,
    )
    output = (result.stdout + result.stderr).replace(str(lean), "<tmp>/BudgetImpact.lean")
    print(output, end="")
    print(f"PROBE_EXIT_STATUS={result.returncode}")
    print(f"ELAPSED_SECONDS={time.monotonic() - started:.3f}")
    raise SystemExit(result.returncode)
