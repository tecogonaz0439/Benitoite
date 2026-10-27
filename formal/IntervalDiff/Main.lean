import Benitoite.Interval.Exchange

/-!
# interval-corpus の解析・評価の独立した比較入口

読者の受理と比較の一致、比較の受け入れを区別する。
（設計書07-04「区間解析の独立交換の読者」）。
-/
namespace IntervalDiff

open Lean Benitoite.Interval.Exchange

/-- 新しい報告ファイルにも、既存の親の実パスを使う。 -/
private def reportPath (path : System.FilePath) : IO System.FilePath := do
  try
    if ← path.pathExists then return ← IO.FS.realPath path
    let parent ← IO.FS.realPath (path.parent.getD ".")
    return parent / path.fileName.getD ""
  catch error =>
    throw (IO.userError s!"cannot resolve REPORT {path}: {error}")

/-- 不一致と受け入れ対象なしは1、不正入力とIOの失敗は2にする。 -/
def run (args : List String) : IO UInt32 := do
  let [mode, inputFile, reportFile] := args
    | throw (IO.userError "usage: intervalDiff analyze|eval INPUT REPORT")
  if mode != "analyze" && mode != "eval" then
    throw (IO.userError "usage: intervalDiff analyze|eval INPUT REPORT")
  if (← IO.FS.realPath inputFile) == (← reportPath reportFile) then
    throw (IO.userError "INPUT and REPORT must differ")
  try
    -- 重複欄を消す前に、生の文字列を読者へ渡す。
    let corpus ← IO.ofExcept (readCorpus (← IO.FS.readFile inputFile))
    let comparison := if mode == "analyze" then analyzeCorpus corpus else evalCorpus corpus
    IO.FS.writeFile reportFile (comparison.report.pretty ++ "\n")
    IO.println s!"intervalDiff: mode={mode} matched={comparison.matched} accepted={comparison.accepted}"
    return if comparison.accepted then 0 else 1
  catch error =>
    IO.FS.writeFile reportFile ((Json.mkObj [("kind", toJson "interval-report"),
      ("version", toJson (1 : Nat)), ("mode", toJson mode), ("accepted", toJson false),
      ("invalidInput", toJson (toString error))]).pretty ++ "\n")
    throw error

end IntervalDiff

def main (args : List String) : IO UInt32 := do
  try IntervalDiff.run args catch error =>
    (← IO.getStderr).putStrLn s!"intervalDiff: {error}"
    return 2
