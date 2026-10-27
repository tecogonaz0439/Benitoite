import Benitoite.Interval.BudgetPatterns

/-!
# 予算付きの局所走査の独立例

上限と期待する区間・停止理由を小さい固定値で指定し、走査の入口から確かめる。
（設計書 01-12「区間解析の予算付きの局所走査」）。
-/
namespace Benitoite.Interval.BudgetScan
open Benitoite.Surface
open Benitoite.Release (Ty)
open Budget

private def succeeded : Outcome α → Option α
  | .ok value _ => some value
  | .stopped _ _ => none

private def stopped : Outcome α → Option StopReason
  | .ok _ _ => none
  | .stopped reason _ => some reason

private def limits (operations items : Nat) : Limits :=
  ⟨⟨operations, items⟩, ⟨10000, 10000⟩⟩

-- 二つの分類訪問は共有の操作数を二回使い、枠を返して最大値だけ残す。
-- 途中の操作数超過と保持数超過で、成功した分だけを保存する。
#guard
    let input := Expr.paren (.local 0)
    let done := (indexOf input).run (limits 2 2) {}
    let operations := (indexOf input).run (limits 1 2) {}
    let items := (indexOf input).run (limits 2 1) {}
    succeeded done = some (some 0) ∧
    done.state = ⟨⟨2, 0, 0, 2⟩, ⟨2, 0, 2⟩⟩ ∧
    stopped operations = some (.exceeded ⟨.body, .operations⟩) ∧
    operations.state = ⟨⟨1, 0, 0, 2⟩, ⟨1, 0, 2⟩⟩ ∧
    stopped items = some (.exceeded ⟨.body, .items⟩) ∧
    items.state = ⟨⟨1, 0, 0, 1⟩, ⟨1, 0, 1⟩⟩

-- 入力の接尾辞を共有する更新と、更新後の参照を同じ状態で実行する。
-- 領域の返却で借りた一項を削除せず、実消費と最大値も保つ。
#guard
    let env := AbstractEnv.ofLocals [.integer top, .unknown none]
    let initial : State := ⟨⟨0, 1, 0, 1⟩, ⟨0, 0, 1⟩⟩
    let result := (region fun _ => do
      let inner ← update env 0 (normalize 0 0)
      integer inner 0).run (limits 3 3) initial
    let short := (region fun _ => do
      let inner ← update env 0 (normalize 0 0)
      integer inner 0).run (limits 2 3) initial
    stopped short = some (.exceeded ⟨.body, .operations⟩) ∧
    short.state = ⟨⟨2, 1, 0, 3⟩, ⟨2, 0, 3⟩⟩ ∧
    succeeded result = some (normalize 0 0) ∧
    result.state = ⟨⟨3, 1, 0, 3⟩, ⟨3, 0, 3⟩⟩

-- 左右の参照と各項の合流・追加を同じ予算で数える。
#guard
    let base := AbstractEnv.ofLocals [.integer top]
    let left := AbstractEnv.ofLocals [.integer (normalize 0 0)]
    let right := AbstractEnv.ofLocals [.integer (normalize 2 2)]
    let result := (region fun _ => do
      let inner ← joinEnvs base left right
      integer inner 0).run (limits 5 2) {}
    succeeded result = some (normalize 0 2) ∧
    result.state = ⟨⟨5, 0, 0, 2⟩, ⟨5, 0, 2⟩⟩

-- 巨大な位置数から replicate や length の事前走査を行わず、二回目の訪問で止まる。
#guard
    let result := (replicateOnto 1000000000000000000000000000000 (.unknown none) []).run
      (limits 1 10) {}
    stopped result = some (.exceeded ⟨.body, .operations⟩) ∧
    result.state = ⟨⟨1, 0, 0, 2⟩, ⟨1, 0, 2⟩⟩

private def boundedCondition : Expr :=
  .and (.binary .ge (.base .integer) (.local 0) (.negInt ⟨0, by decide⟩))
    (.binary .le (.base .integer) (.local 0) (.negInt ⟨1, by decide⟩))

-- 0以上かつ-1以下は到達不能であり、停止とは区別する。
-- 枝を省く入口は分類の予算が0でも到達不能を成功として返す。
#guard
    let env := AbstractEnv.ofLocals [.integer top]
    let result := (region fun _ => condition env boundedCondition true).run (limits 200 100) {}
    let skipped := (branch env boundedCondition (false, false) true).run (limits 0 0) {}
    (succeeded result).isSome = true ∧
    (succeeded result).bind id = none ∧ stopped result = none ∧
    (succeeded skipped).isSome = true ∧ (succeeded skipped).bind id = none ∧
    skipped.state = {}

-- レコードの重複欄は最初を選び、範囲外の欄を束縛数へ足さない。
-- 欄の分類用に保持した項目は終了時に返す。
#guard
    let input := Pattern.record "Example.R" 3 [2, 2, 8] [.con none "Example.Pair" [.var, .var], .var, .var]
    let result := (patternBinders input).run (limits 200 100) {}
    succeeded result = some 2 ∧ result.state.body.temporary = 0

-- 巨大なレコードの欄数でも、途中の分類停止で欄の一時表を返却する。
#guard
    let input := Pattern.record "Example.R" 1000000000000000000000000000000 [0] [.var]
    let result := (patternBinders input).run (limits 8 100) {}
    stopped result = some (.exceeded ⟨.body, .operations⟩) ∧
    result.state.body.operations = 8 ∧ result.state.body.temporary = 0

-- 選択した位置の反転と元の外側位置を、腕入口の規則で扱う。
#guard
    let env := AbstractEnv.ofLocals [.integer (normalize 5 9)]
    let alts : List Alternative := [⟨.var, [0]⟩]
    let result := (region fun _ => do
      let inner ← arm env (.local 0) (.base .integer) (normalize 6 8) alts
      match inner with
      | none => pure (top, top)
      | some inner => do
          let bound ← integer inner 0
          let outer ← integer inner 1
          pure (bound, outer)).run (limits 200 100) {}
    succeeded result = some (normalize 6 8, normalize 6 8) ∧
    result.state.body.temporary = 0

-- 後の本体にも全体の操作数を引き継ぐ。新しい本体の予算へすり替えない。
#guard
    let cap : Limits := ⟨⟨10, 10⟩, ⟨2, 10⟩⟩
    let first := (indexOf (.paren (.local 0))).run cap {}
    let second := (indexOf (.local 0)).run cap (finishBody first.state)
    stopped second = some (.exceeded ⟨.whole, .operations⟩) ∧
    second.state.body.operations = 0 ∧ second.state.whole.operations = 2 ∧
    second.state.body.temporary = 0

-- 番号未取得への変換は、枠の失敗も含む走査全体を囲う。
-- 既に割り当てた一件は保存し、次番号を再利用して続行しない。
#guard
    let scan := forNumbering fun _ => frame fun _ => do
      let (_, next) ← identify ⟨"Example.main", 7⟩
      tick .classification
      pure next
    let assigned := (identify ⟨"Example.main", 7⟩).run (limits 1 1) {}
    let result := scan.run (limits 1 10) {}
    let noFrame := scan.run (limits 10 0) {}
    succeeded assigned = some (⟨"Example.main", 7⟩, ⟨"Example.main", 8⟩) ∧
    assigned.state.body.saved = 1 ∧
    stopped result = some (.unidentified ⟨.body, .operations⟩) ∧
    result.state = ⟨⟨1, 0, 1, 2⟩, ⟨1, 0, 2⟩⟩ ∧
    stopped noFrame = some (.unidentified ⟨.body, .items⟩) ∧
    noFrame.state = {}

end Benitoite.Interval.BudgetScan
