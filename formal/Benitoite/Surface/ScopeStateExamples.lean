import Benitoite.Surface.ScopeState

/-!
# Scope の局所解析の小例

`Surface.ScopeState` の本番の値・規則の表・予算を、小さな解析器と出現の解決で具体化して確かめる
（設計書 01-12「Scope の局所解析の状態と規則の表」「Scope の局所解析の予算と忘却」）。文字列の解析器と出現の
解決はこの例のためのものであり、処理系の解析器・名前解決との一致の証拠ではない。
-/

namespace Benitoite.Surface.ScopeStateExamples

open Benitoite.Scope.Inference
open Benitoite.Surface.ScopeState
open Benitoite.Scope.Domain (Range Target)

/-- `/data/**`。 -/
def dataTree : Range := .path (.tree ["data"])

/-- `/**`（根の木）。 -/
def rootTree : Range := .path (.tree [])

/-- `/data/a.txt`。 -/
def target : Target := .path ["data", "a.txt"]

/-- 例の解析器。`/data/**` だけをパターンとして、`/data/a.txt` と `/etc/x` を対象として解析する。 -/
def toyParsers : Parsers where
  pattern
    | "/data/**" => some dataTree
    | _ => none
  target
    | "/data/a.txt" => some target
    | "/etc/x" => some (.path ["etc", "x"])
    | _ => none

/-- 例の境界。Result の構成子は `Ok`・`Err`、型引数と失敗の値は局所解析に現れないので単純にした。 -/
def boundary : Boundary where
  ok := "Ok"
  err := "Err"
  pathTys _ := []
  requestTys _ := []
  pathFailure := .const .unit
  requestFailure := .const .unit
  parsers := toyParsers
  hostPattern _ := none
  endpointOf _ := none
  requestBound _ := .unknown
  pathText _ := "/data/a.txt"
  requestValueRun _ _ := none

def keyCheck : Key := ⟨"main.store", 3⟩
def keyCheck2 : Key := ⟨"main.store", 9⟩
def keyValue : Key := ⟨"main.store", 8⟩
def keyWiden : Key := ⟨"main.store", 10⟩
def keyUser : Key := ⟨"main.store", 11⟩

/-- 出現の解決。`keyUser` は利用者のモジュール `main` の同じ綴りの関数 `Scope.checkPathIn` に解決する。 -/
def resolve (key : Key) : Option Resolved :=
  if key = keyCheck ∨ key = keyCheck2 then some ⟨.standard, checkPathName⟩
  else if key = keyValue then some ⟨.standard, pathValueName⟩
  else if key = keyWiden then some ⟨.standard, widenPathName⟩
  else if key = keyUser then some ⟨.user "main", checkPathName⟩
  else none

def table : ScopeTable Release.Val := standardTable resolve boundary.rules.lookup

theorem table_sound : TableSound boundary.models table :=
  Rules.lookup_sound (boundary.rules_sound (by decide)
    (requestCheck_unknown_boundSound _ _ _ _)) resolve

/-- 関数の入口。引数 `raw` の一つの位置（番号 0）だけを持ち、由来はない。 -/
def entry : ScopeState := ScopeState.empty ⟨[0], 1⟩

/-- `let r = Scope.checkPathIn(pattern: "/data/**", path: raw)` と、その `case Result.Ok(p)`。 -/
def checkSteps : List Step := [.call keyCheck [.lit "/data/**", .loc 0], .okArm 0]

/-! ## 規則の表と必須の判定 -/

-- 直接の検査の結果は既知の範囲の由来を持ち、同じ Ok 値（番号 2）は同じ由来を持つ。
#guard (absSteps table entry (checkSteps.take 1)).facts[0]? ==
  some (some (.result ⟨keyCheck, .path, .known dataTree⟩))
#guard (absSteps table entry checkSteps).facts[0]? ==
  some (some (.checked ⟨keyCheck, .path, .known dataTree⟩ 2))
#guard (absSteps table entry checkSteps).requiredIndex 0 == dataTree
-- 元の引数 raw（番号 0）は Top のまま。
#guard (absSteps table entry checkSteps).requiredIndex 2 == .top
-- 明示拡大と射影が抽象の引数から選ぶ範囲は、引数の必須の判定と同じ（再照合を含む）。
#guard boundary.rules.widenPath.index [(absSteps table entry checkSteps).readLocal 0] == [dataTree]
#guard boundary.rules.pathValue.index [(absSteps table entry checkSteps).readLocal 0] == [dataTree]
-- 型検査器が検査へ渡す範囲は、抽象の結果の由来の添字と同じ。
#guard boundary.rules.checkPath.index [.lit "/data/**", .unknown] == [dataTree]
-- 射影と拡大の結果は由来を持たない（結果の型は署名と戻り値の注釈が決める）。
#guard (absSteps table entry (checkSteps ++ [.call keyWiden [.loc 0]])).requiredIndex 0 == .top
#guard (absSteps table entry (checkSteps ++ [.call keyValue [.loc 0]])).requiredIndex 0 == .top

/-! ## 精度を失う境界 -/

-- 未知のパターン（局所の文字列）では Top。検査の δ は動的なパターンだけを実質に確かめる。
#guard (absSteps table entry [.call keyCheck [.loc 0, .loc 0], .okArm 0]).requiredIndex 0 == .top
-- 別名は由来を写さない。
#guard (absSteps table entry (checkSteps ++ [.alias 0])).requiredIndex 0 == .top
-- 再包装（未知の値）の Ok の腕は別個体であり、由来を持たない。
#guard (absSteps table entry (checkSteps ++ [.unknown, .okArm 0])).requiredIndex 0 == .top
-- 合流と本体の境界で忘れる。位置の数は保つ。
#guard (absSteps table entry (checkSteps ++ [.join])).requiredIndex 0 == .top
#guard (absSteps table entry (checkSteps ++ [.join])).facts.length == 3
-- 同じ綴りの利用者の関数は同定されず、由来を作らない。
#guard (absSteps table entry [.call keyUser [.lit "/data/**", .loc 0], .okArm 0]).requiredIndex 0 == .top
-- 成功値番号と読んだ位置の番号が食い違う事実は使わない（再照合）。
#guard ScopeState.requiredIndex ⟨⟨[5], 6⟩, [some (.checked ⟨keyCheck, .path, .known dataTree⟩ 4)]⟩ 0 == .top
#guard argIndex (.loc 5 (some (.checked ⟨keyCheck, .path, .known dataTree⟩ 4))) == .top

/-- 同じ綴りの利用者の関数の出現からは抽象の結果を作らず、標準の規則を適用する導出もない。 -/
theorem user_not_identified :
    (∀ aargs, absApply table keyUser aargs = none) ∧ ∀ rs vs v, ¬ EvalScope table keyUser rs vs v :=
  standardTable_user (m := "main") (d := checkPathName) (by decide)

/-- 例の具体の評価で得た位置 0 の値は、`/data/**` に属する対象を保持する値である（同じ値と条件の対応）。 -/
theorem check_checked {env env' : Locals} {v : Release.Val}
    (hev : StepsEval boundary.ok table env checkSteps env') (found : env'[0]? = some (some v)) :
    ∃ t, v.target? = some t ∧ dataTree.Mem t := by
  have hm := absSteps_sound table_sound (ScopeState.empty_models _ _ _) hev (st := entry)
  have hidx : (absSteps table entry checkSteps).requiredIndex 0 = dataTree := by decide
  obtain ⟨_, t, ht, -, -, hmem⟩ := requiredIndex_checked hm found (by rw [hidx]; decide)
  exact ⟨t, ht, hidx ▸ hmem⟩

/-! ## 検査・拡大の δ -/

/-- 範囲に属する対象の検査は、同じ対象の検査済みの対象の値を `Ok` で返す。 -/
theorem delta_ok :
    (boundary.rules.checkPath.run [dataTree]
      [.const (.string "/data/**"), .const (.string "/data/a.txt")]).map (okPayload "Ok") =
        some (some (.checked target)) := by
  rfl

/-- 範囲の外の対象の検査は `Ok` を返さない。 -/
theorem delta_outside :
    (boundary.rules.checkPath.run [dataTree]
      [.const (.string "/data/**"), .const (.string "/etc/x")]).map (okPayload "Ok") = some none := by
  rfl

/-- 動的なパターンを Top で具体化しても、成否と成功値は変わらない（案 A の冗長性）。 -/
theorem delta_top_same :
    (boundary.rules.checkPath.run [.top]
      [.const (.string "/data/**"), .const (.string "/data/a.txt")]).map (okPayload "Ok") =
        some (some (.checked target)) := by
  rfl

/-- `/data/**` から `/**` への明示拡大は同じ値を返し、その値は `PathIn["/**"]` の型を持つ。 -/
theorem widen_root {P : Release.Program} {Ψ : Release.StoreTy} :
    widenRun [dataTree, rootTree] [.checked target] = some (.checked target) ∧
      Release.HasTypeV P Release.MembershipExample.builtins Ψ [] [] (.checked target)
        (.opaque "Scope.PathIn" (.fixed rootTree)) := by
  have hw : widenRun [dataTree, rootTree] [.checked target] = some (.checked target) := by rfl
  exact ⟨hw, widenRun_hasTypeV Release.MembershipExample.checked_typed hw⟩

/-- 行き先が元の範囲を覆わない拡大（`/data/**` から `/database/**`）は値を返さない。 -/
theorem widen_not_covered :
    widenRun [dataTree, .path (.tree ["database"])] [.checked target] = none := by
  rfl

/-! ## 予算と忘却 -/

/-- 十分に大きい上限の例。 -/
def wide : Limits := ⟨⟨100, 100⟩, ⟨1000, 1000⟩⟩

def runFrom (L : Limits) (ss : List Step) : Run := Run.steps table L (.running entry .initial) ss

-- 上限の内では、予算のない解析と同じ結果になる。
#guard (runFrom wide checkSteps).state.requiredIndex 0 == dataTree
#guard (runFrom wide checkSteps).exceeded == none
-- 計上: 呼び出しは同定 1・局所の読み取り 1・事実の書き込み 1 の 3、Ok の腕は読み取り 1・由来の写し 1 の 2。
#guard (runFrom wide checkSteps).budget == ⟨5, 5, 0⟩
#guard heldItems (runFrom wide checkSteps).state == 2
-- 忘却の操作数は事実を持つ位置の数（2）。
#guard (runFrom wide (checkSteps ++ [.join])).budget == ⟨7, 7, 0⟩
-- 本体の操作数の超過。理由を残し、全ての位置で Top。拒否した計上は予算の状態を変えない。
#guard (runFrom ⟨⟨3, 100⟩, ⟨1000, 1000⟩⟩ checkSteps).exceeded == some (.budgetExceeded ⟨.body, .operations⟩)
#guard (runFrom ⟨⟨3, 100⟩, ⟨1000, 1000⟩⟩ checkSteps).state.requiredIndex 0 == .top
#guard (runFrom ⟨⟨3, 100⟩, ⟨1000, 1000⟩⟩ checkSteps).budget == ⟨3, 3, 0⟩
-- 位置の数は超過の後も保つ（束縛番号は通常の一段と同じに進む）。
#guard (runFrom ⟨⟨3, 100⟩, ⟨1000, 1000⟩⟩ checkSteps).state.facts.length == 3
-- 全体の操作数の超過。
#guard (runFrom ⟨⟨100, 100⟩, ⟨4, 1000⟩⟩ checkSteps).exceeded == some (.budgetExceeded ⟨.whole, .operations⟩)
-- 本体の保持数の超過（事実を持つ位置が 2 になる Ok の腕で超える）。
#guard (runFrom ⟨⟨100, 1⟩, ⟨1000, 1000⟩⟩ checkSteps).exceeded == some (.budgetExceeded ⟨.body, .items⟩)
-- 全体の保持数の超過（外側の本体の 2 項と内側の 1 項）。内側が全体の上限を超えたら外側も止まる。
#guard (Run.steps table ⟨⟨100, 100⟩, ⟨1000, 2⟩⟩ ((runFrom wide checkSteps).enter ⟨[0], 3⟩)
  [.call keyCheck [.lit "/data/**", .loc 0]]).exceeded == some (.budgetExceeded ⟨.whole, .items⟩)
#guard ((runFrom wide checkSteps).leave (Run.steps table ⟨⟨100, 100⟩, ⟨1000, 2⟩⟩
  ((runFrom wide checkSteps).enter ⟨[0], 3⟩) [.call keyCheck [.lit "/data/**", .loc 0]])).exceeded ==
    some (.budgetExceeded ⟨.whole, .items⟩)
#guard ((runFrom wide checkSteps).leave (Run.steps table ⟨⟨100, 100⟩, ⟨1000, 2⟩⟩
  ((runFrom wide checkSteps).enter ⟨[0], 3⟩) [.call keyCheck [.lit "/data/**", .loc 0]])).state.requiredIndex 0 ==
    .top
-- 内側の本体の上限の超過は外側に及ばない。外側は全体の操作数だけを引き継ぐ。
#guard ((runFrom wide checkSteps).leave (Run.steps table ⟨⟨1, 100⟩, ⟨1000, 1000⟩⟩
  ((runFrom wide checkSteps).enter ⟨[0], 3⟩) [.call keyCheck [.lit "/data/**", .loc 0]])).exceeded == none
#guard ((runFrom wide checkSteps).leave (Run.steps table ⟨⟨1, 100⟩, ⟨1000, 1000⟩⟩
  ((runFrom wide checkSteps).enter ⟨[0], 3⟩) [.call keyCheck [.lit "/data/**", .loc 0]])).state.requiredIndex 0 ==
    dataTree

/-- 上限の値によらず、予算付きの解析は具体の評価に対応する（超過して Top を返す場合を含む）。 -/
theorem budgeted_sound (L : Limits) {env env' : Locals}
    (hev : StepsEval boundary.ok table env checkSteps env') :
    (runFrom L checkSteps).state.Models boundary.models env' :=
  Run.steps_models table_sound L (ScopeState.empty_models _ _ _) hev

end Benitoite.Surface.ScopeStateExamples
