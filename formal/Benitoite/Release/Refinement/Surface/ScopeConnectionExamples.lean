import Benitoite.Release.Refinement.Surface.ScopeConnection
import Benitoite.Release.Refinement.Surface.CheckOpenExamples
import Benitoite.Release.Refinement.ModelTargets

/-!
# Scope の接続定理の具体の適用例

検査の結果を局所に保存し、`Ok` の腕で成功値を射影へ渡す本体

```
let x = Example.check()            -- 番号 0
match x { Ok(y) => Example.project(y) }
```

を、検査の規則（型検査器は既知の範囲 `/data/**` を読み、実行は核の組み込みの関数の δ）と射影の規則の表で受理し、
表層の具体の評価の到達から、検査の成功値・射影が指す値・核の実行の形・プログラムの受理からの接続を得る
（設計書 01-12「Scope の局所解析の接続定理」）。
-/

namespace Benitoite.Release.Refinement.Surface.ScopeConnectionExamples

open Benitoite.Scope.Inference
open ScopeState ScopeLower ScopeAccept ScopeSound
open Benitoite.Scope.Domain (Range Target)

noncomputable section

private def dataRange : Range := .path (.tree ["data"])
private def dataTarget : Target := .path ["data", "x"]
private def okValue : Refinement.Val := .con "Ok" [] [.checked dataTarget]

private def checkSig : PrimSig where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := Eff.empty
  admits := fun _ _ => True
  kind := .pure
  opEff := none

/-- 検査の組み込みの関数 `Example.check` を加えた表。δ は `/data/**` の具体化でだけ成功値 `Ok(/data/x)` を返す。 -/
private def builtins : Builtins :=
  { ModelTargets.builtins with
    sig := fun b => if b = "Example.check" then some checkSig else ModelTargets.builtins.sig b
    delta := fun b ts es rs ws =>
      if b = "Example.check" then (if rs = [.absolute dataRange] then some (.val okValue) else none)
      else ModelTargets.builtins.delta b ts es rs ws }

private def spec : CheckSpec where
  kind := .path
  pattern := fun _ => some dataRange
  target := fun _ => some dataTarget
  bound := fun _ => .known dataRange

private def checkR : ScopeRule Refinement.Val := checkRule spec (deltaRunAt builtins "Example.check" [] [])
private def projectR : ScopeRule Refinement.Val := projectRule (fun _ vs => vs.head?)

private def input : CheckAccept.AcceptInput where
  ok := "Ok"
  rules := fun d => if d = "Example.check" then some checkR else if d = "Example.project" then some projectR else none
  limits := ⟨⟨100, 100⟩, ⟨100, 100⟩⟩
  methodKey := fun _ _ => ""

private def checkCall : Expr := .call (.primName "Example.check" [] [] (fixedRanges [dataRange])) [] [] .nil
private def projectCall : Expr :=
  .call (.primName "Example.project" [] [] (fixedRanges [dataRange])) [none] [0] (.cons (.local 0) .nil)
private def arms : Arms := .cons [⟨.con none "Ok" [.var], [0]⟩] none (.last projectCall) .nil
private def body : Block := .bind .bind (.base .unit) checkCall (.last (.matchE (.base .unit) (.local 0) arms))

private def key : Key := CheckAccept.bodyKey "main"
private def table : ScopeTable Refinement.Val := CheckAccept.tableFor input key body

private theorem run_ok {rs : List Range} {vs : List Refinement.Val} {v : Refinement.Val}
    (h : deltaRunAt builtins "Example.check" [] [] rs vs = some v) : rs = [dataRange] ∧ v = okValue := by
  have hd := deltaRunAt_eq_some.mp h
  simp only [builtins, ↓reduceIte] at hd
  split at hd
  · next hr =>
    cases rs with
    | nil => cases hr
    | cons r rest =>
      simp only [List.map_cons, List.cons.injEq] at hr
      obtain ⟨hr1, hr2⟩ := hr
      cases hr1
      cases rest with
      | nil => cases hd; exact ⟨rfl, rfl⟩
      | cons _ _ => cases hr2
  · cases hd

private theorem table_sound : TableSound (models "Ok" (fun _ => none)) table := by
  intro d rule h
  change input.rules d = some rule at h
  simp only [input] at h
  split at h
  · cases h
    refine checkRule_sound (fun _ _ r _ hb => by cases hb; rfl) ?_
    intro rs vs v w hrun hw
    obtain ⟨rfl, rfl⟩ := run_ok hrun
    simp only [okValue, okPayload, ↓reduceIte, Option.some.injEq] at hw
    subst hw
    exact ⟨dataRange, dataRange, dataTarget, rfl, rfl, rfl, rfl, rfl, ⟨["x"], rfl⟩, ⟨["x"], rfl⟩⟩
  · split at h
    · cases h; exact projectRule_sound _ _
    · cases h

private theorem accepted : ScopeAccept.acceptBody "Ok" table input.limits key (CheckAccept.entryScope 0) body = .ok () := by
  rfl

private theorem check_rhs : RhsEval table key [] checkCall (some okValue) :=
  .callStd rfl .nil rfl (.apply (rs := [dataRange]) checkR okValue rfl rfl)

/-- 受理した本体の検査の呼び出しの成功値は、推論した範囲 `/data/**` と受理した契約に属する対象 `/data/x` を保持する。 -/
theorem check_connection :
    ∃ st xs vs, (key, st) ∈ (analyzeBody "Ok" table input.limits key (CheckAccept.entryScope 0) body).2 ∧
      contractOrder [] (lowerArgs (argsKey key (.primName "Example.check" [] [] (fixedRanges [dataRange]))) .nil) =
        some xs ∧
      (∃ rs', deltaRunAt builtins "Example.check" [] [] rs' vs = some okValue) ∧
      ∃ t, (Refinement.Val.checked dataTarget).target? = some t ∧ t.kind = spec.kind ∧
        (spec.bound (xs.map (absArg table st))).index.Mem t ∧
        ∃ S, [dataRange][0]? = some S ∧ S.Covers (spec.bound (xs.map (absArg table st))).index ∧ S.Mem t :=
  scope_check_connection_at table_sound accepted (.here rfl) check_rhs rfl rfl

/-- 局所に保存した検査の結果を `Ok` の腕で取り出し、射影へ渡す文へ到達する。 -/
private theorem project_reach :
    ReachAtBlock table key [] body ⟨"main", 4⟩
      [some (.checked dataTarget), some okValue, some okValue] projectCall :=
  .bind check_rhs (.rhs rfl (.matchArms (v := some okValue) (.body (.con rfl rfl) (.here rfl))))

/-- 射影の文の始まりの記録が Top でない添字を付けた位置の値は、その範囲に属する対象を保持する。 -/
theorem project_required :
    ∃ st, (⟨"main", 4⟩, st) ∈ (analyzeBody "Ok" table input.limits key (CheckAccept.entryScope 0) body).2 ∧
      ∀ i v, [some (.checked dataTarget), some okValue, some okValue][i]? = some (some v) →
        st.requiredIndex i ≠ .top → ∃ t, v.target? = some t ∧ (st.requiredIndex i).Mem t :=
  analyzeBody_requiredIndex table_sound ⟨_, project_reach⟩

/-- 射影の引数の位置の必須の判定は、検査で推論した範囲 `/data/**` を添字に付け、その値は対象を保持する。 -/
theorem project_connection :
    ∃ st S, (⟨"main", 4⟩, st) ∈ (analyzeBody "Ok" table input.limits key (CheckAccept.entryScope 0) body).2 ∧
      [dataRange][0]? = some S ∧ S.Covers (st.requiredIndex 0) ∧ (st.requiredIndex 0 = .top → S = .top) ∧
      (st.requiredIndex 0 ≠ .top →
        ∃ t, (Refinement.Val.checked dataTarget).target? = some t ∧ (st.requiredIndex 0).Mem t ∧ S.Mem t) :=
  scope_local_connection_at table_sound accepted project_reach rfl rfl (projectRule_index _) rfl

/-- 同じ射影の引数の値は、核の範囲付きの型 `Scope.PathIn[/data/**]` を持つ。 -/
theorem project_typed (P : Refinement.Program) (Ψ : StoreTy) :
    HasTypeVQ P ModelTargets.builtins Ψ Qempty [] [] [] (.checked dataTarget)
      (.scoped "Scope.PathIn" .path (.fixed (.absolute dataRange))) :=
  scope_local_typed table_sound (OccurrenceAccepted.of_body accepted (reachAt_occurrences project_reach))
    ⟨_, project_reach⟩ rfl rfl (projectRule_index _) rfl rfl (by intro h; cases h) rfl rfl
    (fun t ht => by cases ht; exact Or.inl ⟨rfl, rfl⟩)

/-- 同じ射影の引数の値の型付け（Top の範囲付きの型）から、接続定理が狭い型 `Scope.PathIn[/data/**]` を与える。 -/
theorem project_typed_of_typed (P : Refinement.Program) (Ψ : StoreTy) :
    HasTypeVQ P ModelTargets.builtins Ψ Qempty [] [] [] (.checked dataTarget)
      (.scoped "Scope.PathIn" .path (.fixed (.absolute dataRange))) :=
  scope_local_typed_of_typed table_sound (OccurrenceAccepted.of_body accepted (reachAt_occurrences project_reach))
    ⟨_, project_reach⟩ rfl rfl (projectRule_index _) rfl rfl (by intro h; cases h) rfl rfl
    (Q' := Qempty) (C' := []) (Γ' := []) (Φ' := [])
    (.V_Checked (o := "Scope.PathIn") (range := .top) rfl rfl ((Scope.Domain.Range.memK_top_iff _ _).mpr rfl))
    (Or.inl rfl) (by intro r snap t req h; cases h)

/-- 空のストア型での値の型付けから、値の信頼条件のもとで、任意のストア型での狭い型 `Scope.PathIn[/data/**]` を得る。 -/
theorem project_typed_of_typed_extend (P : Refinement.Program) (Ψ : StoreTy)
    (hA : Builtins.ValueAssumptions P ModelTargets.builtins) :
    HasTypeVQ P ModelTargets.builtins Ψ Qempty [] [] [] (.checked dataTarget)
      (.scoped "Scope.PathIn" .path (.fixed (.absolute dataRange))) :=
  scope_local_typed_of_typed_extend table_sound (OccurrenceAccepted.of_body accepted (reachAt_occurrences project_reach))
    ⟨_, project_reach⟩ rfl rfl (projectRule_index _) rfl rfl (by intro h; cases h) rfl rfl
    hA StoreTy.WF.empty (fun _ _ h => by cases h)
    (Q' := Qempty) (C' := []) (Γ' := []) (Φ' := [])
    (.V_Checked (o := "Scope.PathIn") (range := .top) rfl rfl ((Scope.Domain.Range.memK_top_iff _ _).mpr rfl))
    (Or.inl rfl) (by intro r snap t req h; cases h)

/-- 脱糖した核の項 `Example.check[/data/**]()` は E_Prim で成功値へ進み、その成功値は推論した範囲に属する。 -/
theorem check_core (P : Refinement.Program) (σ : PathEnv) :
    Benitoite.Release.Refinement.Step P builtins σ
      (.run (Closure.pure (.app (.prim "Example.check" [] [] (fixedRanges [dataRange])) [])) [] Store.empty) none
      (.run (Closure.pure (.ret okValue)) [] Store.empty) ∧
    ∃ t, (Refinement.Val.checked dataTarget).target? = some t ∧ dataRange.Mem t := by
  obtain ⟨-, -, hstep, hok⟩ := scope_check_core table_sound
    (OccurrenceAccepted.of_body accepted (reachAt_occurrences (.here rfl : ReachAtBlock table key [] body key [] checkCall)))
    (env := []) (env' := []) ⟨_, .here rfl⟩ (vals := []) .nil rfl (B := builtins) rfl (show builtins.delta "Example.check" (Ty.normTys [])
      ([].map Eff.norm) ([dataRange].map .absolute) [] = some (.val okValue) by simp [builtins])
    (show builtins.sig "Example.check" = some checkSig by simp [builtins]) rfl (fun _ _ => none) .other P σ
    (q := Closure.pure (.app (.prim "Example.check" [] [] (fixedRanges [dataRange])) [])) rfl [] Store.empty
  obtain ⟨_, _, -, -, t, ht, -, -, S, hS, -, hm⟩ := hok _ rfl
  cases hS
  exact ⟨hstep, t, ht, hm⟩

private def mainDef : Def where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := Eff.empty
  body := body

private def program : Program where
  defs := fun f => if f = "main" then some mainDef else none
  cons := fun _ => none

private def checkInput : Check.Input := { CheckOpenExamples.input .path with defs := ["main"] }

/-- プログラムの受理（`acceptProgram`）から、定義の本体の検査の成功値の接続を得る。 -/
theorem program_check_connection :
    ∃ t, (Refinement.Val.checked dataTarget).target? = some t ∧ t.kind = .path ∧
      ∃ S, [dataRange][0]? = some S ∧ S.Mem t := by
  have hn : CheckAccept.NamesComplete checkInput program := by
    refine ⟨?_, ?_, ?_⟩
    · intro n d h
      simp only [program] at h
      split at h
      · next he => subst he; simp [checkInput]
      · cases h
    · intro i id h; simp [program] at h
    · intro i id h; simp [program] at h
  have hp : CheckAccept.acceptProgram input checkInput program = .ok () := by rfl
  exact accepted_check_connection hn hp (n := "main") (d := mainDef) rfl table_sound (.here rfl) rfl check_rhs rfl rfl

/-! ## `Http.checkRequestIn` -/

private def requestBody : Block :=
  .last (.call (.primName "Http.checkRequestIn" [] [] (fixedRanges [.top])) [none, none, none, none] [0, 1, 2, 3]
    (.cons (.local 0) (.cons (.local 1) (.cons (.local 2) (.cons (.local 3) .nil)))))

private def requestTable : ScopeTable Refinement.Val :=
  standardTable (fun _ => some ⟨.standard, checkRequestName⟩) (productionRules (fun _ => none) (fun _ => none)).lookup

private theorem request_accepted :
    ScopeAccept.acceptBody "Result.Ok" requestTable input.limits key (CheckAccept.entryScope 4) requestBody = .ok () := by
  rfl

/-- 本番の規則の表で、局所の値を引数にする要求の検査の呼び出しを受理した本体では、δ が返す成功値は渡された要求を
保持する検査済みの要求の値であり、実効の endpoint は受理した契約（ここでは Top）に属する。 -/
theorem request_connection (pattern lo hi req : Refinement.Val) (r : Range) (v w : Refinement.Val)
    (hrun : deltaRun ModelHttp.builtins checkRequestName [r] [pattern, lo, hi, req] = some v)
    (hw : okPayload "Result.Ok" v = some w) :
    ∃ R t req', w = .checkedRequest (.endpoint t) req' ∧ req'.reqTarget = some (.endpoint t) ∧
      R.Mem (.endpoint t) ∧ ∃ S, [Range.top][0]? = some S ∧ S.Covers R ∧ S.Mem (.endpoint t) := by
  have hreach : ReachAtBlock requestTable key [some pattern, some lo, some hi, some req] requestBody key
      [some pattern, some lo, some hi, some req]
      (.call (.primName "Http.checkRequestIn" [] [] (fixedRanges [.top])) [none, none, none, none] [0, 1, 2, 3]
        (.cons (.local 0) (.cons (.local 1) (.cons (.local 2) (.cons (.local 3) .nil))))) := .here rfl
  have hrhs : RhsEval requestTable key [some pattern, some lo, some hi, some req]
      (.call (.primName "Http.checkRequestIn" [] [] (fixedRanges [.top])) [none, none, none, none] [0, 1, 2, 3]
        (.cons (.local 0) (.cons (.local 1) (.cons (.local 2) (.cons (.local 3) .nil))))) (some v) :=
    .callStd rfl (.cons (.loc rfl) (.cons (.loc rfl) (.cons (.loc rfl) (.cons (.loc rfl) .nil)))) rfl
      (.apply (rs := [r]) _ v rfl hrun)
  exact http_check_connection (show "Result.Ok" ≠ "Result.Error" by decide)
    (OccurrenceAccepted.of_body request_accepted (reachAt_occurrences hreach)) ⟨_, hreach⟩ hrhs rfl hw

end
end Benitoite.Release.Refinement.Surface.ScopeConnectionExamples
