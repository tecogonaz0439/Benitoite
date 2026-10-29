import Benitoite.Release.TargetReachExamples

/-!
# 効果の上限の被覆による包含の例（L40.6c）

C-Sub・C-Eff と関数の型の効果の包含（`Ty.Le`）は、判断 5 の一原子の被覆（`Eff.Covers`）で効果を広げる。L20.7 の
実例の表 `ModelTargets.Examples.B` と本番の型付け・遷移の上で、構造上の包含では型付かず被覆だけで型付く閉じた
プログラムに、到達先の対象健全性（`reachable_target_sound`）が当たることを確かめる。

- 組み込みの関数の直接の呼び出し: `File.writeTextIn[;;/data/a.txt](checked(/data/a.txt), "x")` の効果は
  `{File.Write[/data/a.txt]}` であり、上限 `{File.Write[/data/**]}` に被覆で含まれるが、構造上の包含では含まれない
  （`bound_covers_narrow`・`not_sub_narrow`）。上限 `{File.Write[/data/**]}` を宣言した関数 `f` の本体がこの呼び出しで
  あるプログラムは型付き（`progCover_wellTyped`）、`f()` から到達した書き込みの事象の観測 `/data/a.txt` は上限が許す。
- 利用者の関数の呼び出し: 狭い効果 `{File.Write[/data/a.txt]}` を宣言した関数 `g` を、上限 `{File.Write[/data/**]}` を
  宣言した関数 `h` の本体から呼ぶ。`h()` から二回の関数の呼び出しを経て到達した書き込みの事象の観測も、`h` の上限が
  許す。
-/

namespace Benitoite.Release.CoverExamples

open Benitoite.Release
open Benitoite.Release.ModelTargets
open Benitoite.Release.ModelTargets.Examples
open Benitoite.Release.HandlerTargetExamples
open Scope.Domain (Range Target)

/-! ## 被覆だけで成り立つ包含 -/

/-- `/data/a.txt` だけの範囲。 -/
def exactR : Range := .path (.exact ["data", "a.txt"])

/-- 呼び出しの効果 `{File.Write[/data/a.txt]}`。 -/
abbrev narrowEff : Eff := Eff.singleAt "File.Write" (.fixed exactR)

theorem range_covers_exact : range.Covers exactR := (Scope.Domain.Range.covers?_spec _ _).mp rfl

/-- 上限 `{File.Write[/data/**]}` は `{File.Write[/data/a.txt]}` を被覆で含む。 -/
theorem bound_covers_narrow : bodyData.Covers narrowEff := by
  refine ⟨fun a ha => ?_, fun t ht => ?_⟩
  · rw [Eff.mem_singleAt] at ha
    subst ha
    exact ⟨_, (Eff.mem_singleAt _ _ _).mpr rfl, Atom.covers_fixed_fixed.mpr ⟨rfl, range_covers_exact⟩⟩
  · simp [narrowEff, Eff.singleAt, Eff.ofAtoms, Eff.memFail, Eff.fails] at ht

/-- 同じ二つの効果は、構造上の包含（L40.6c の前の C-Sub の前提）では含まれない。 -/
theorem not_sub_narrow : ¬ Eff.Sub narrowEff bodyData := by
  intro h
  have := h.1 _ ((Eff.mem_singleAt _ _ _).mpr rfl)
  rw [Eff.mem_singleAt] at this
  simp [dataTree, range, exactR] at this

theorem write_admissible_exact : B.RangeAdmissible "File.writeTextIn" TargetTable.writeTextIn [exactR] := by
  refine ⟨⟨?_, ?_, Or.inr ⟨Or.inl rfl, rfl⟩⟩, ?_⟩
  · exact ⟨by decide, Scope.Domain.Range.fitsKinds_nil⟩
  · intro r hr; simp only [List.mem_singleton] at hr; subst hr; decide
  · intro r hr; simp only [List.mem_singleton] at hr; subst hr; decide

/-- `File.writeTextIn[;;/data/a.txt](checked(/data/a.txt), "x")`。 -/
def narrowCall : Comp := .app (.prim "File.writeTextIn" [] [] [exactR]) [.checked target, str "x"]

theorem narrowCall_typed {P : Program} {Ψ : StoreTy} {Γ : List (Option Ty)} {R : Option Ty} :
    HasTypeCQ P B Ψ Qempty [] Γ R narrowCall writeRet narrowEff :=
  writeCall_typed write_admissible_exact (.V_Checked rfl (by decide)) .V_Const

/-- 上限 `{File.Write[/data/**]}` での型付け。C-Eff が被覆で効果を広げる。 -/
theorem narrowCall_bound {P : Program} {Ψ : StoreTy} {Γ : List (Option Ty)} {R : Option Ty} :
    HasTypeCQ P B Ψ Qempty [] Γ R narrowCall writeRet bodyData :=
  .C_Eff narrowCall_typed bound_covers_narrow

theorem narrowCall_closed : narrowCall.ClosedNoEffVars := by
  simp [narrowCall, str, Comp.ClosedNoEffVars, Comp.VarsIn, Val.VarsIn, Ty.VarsInList, Eff.VarsInList, Val.VarsInList]

/-! ## 関数の本体と利用者の関数の呼び出し -/

/-- 型の変数・引数を持たず、結果 `Result[Unit, IOError]` と効果 eff を宣言した定義。 -/
def defOf (eff : Eff) (body : Comp) : Def where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := writeRet
  eff := eff
  body := body

/-- `g()` と `f()`。 -/
def callG : Comp := .app (.fnRef "g" [] []) []
def callF : Comp := .app (.fnRef "f" [] []) []
def callH : Comp := .app (.fnRef "h" [] []) []

/-- `f() : Result[Unit, IOError] uses File.Write[/data/**]`（本体は `/data/a.txt` への書き込み）、
`g() : Result[Unit, IOError] uses File.Write[/data/a.txt]`（同じ本体）、`h() : Result[Unit, IOError] uses
File.Write[/data/**]`（本体は `g()`）。 -/
def fnTable : FunName → Option Def := fun f =>
  if f = "f" then some (defOf bodyData narrowCall)
  else if f = "g" then some (defOf narrowEff narrowCall)
  else if f = "h" then some (defOf bodyData callG) else none

def progCover : Program :=
  ⟨fnTable, resultCons, fun _ => none, fun _ => none, fun _ => none, fun _ => none⟩

theorem progCover_defs {f d} (h : progCover.defs f = some d) :
    (f = "f" ∧ d = defOf bodyData narrowCall) ∨ (f = "g" ∧ d = defOf narrowEff narrowCall) ∨
      (f = "h" ∧ d = defOf bodyData callG) := by
  simp only [progCover, fnTable] at h
  split at h
  · cases h; exact .inl ⟨by assumption, rfl⟩
  · split at h
    · cases h; exact .inr (.inl ⟨by assumption, rfl⟩)
    · split at h
      · cases h; exact .inr (.inr ⟨by assumption, rfl⟩)
      · cases h

theorem progCover_hasResult : HasResult progCover := by
  simp [HasResult, progCover, resultCons]

theorem writeRet_varsIn : Ty.VarsIn 0 0 (fun _ => True) writeRet := by
  simp [writeTys, TargetTable.ioErrorTy, Ty.VarsIn, Ty.VarsInList]

theorem eff_varsIn (r : Range) : Eff.VarsIn 0 0 (· < 0) (Eff.singleAt "File.Write" (.fixed r)) :=
  writeDef_eff_wf (.fixed r) (Atom.ix_wf_fixed 0 r)

theorem progCover_wellFormed : progCover.WellFormed := by
  refine ⟨?_, ?_, fun _ _ h => (by cases h), fun _ _ h => (by cases h), fun _ _ h => (by cases h)⟩
  · intro f d h
    rcases progCover_defs h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩
    · exact ⟨by simp [NamesWF, defOf], by simp [defOf, Ty.VarsInList], writeRet_varsIn, eff_varsIn range,
        by simp [defOf, narrowCall, str, Comp.VarsIn, Val.VarsIn, Val.VarsInList, Ty.VarsInList, Eff.VarsInList]⟩
    · exact ⟨by simp [NamesWF, defOf], by simp [defOf, Ty.VarsInList], writeRet_varsIn, eff_varsIn exactR,
        by simp [defOf, narrowCall, str, Comp.VarsIn, Val.VarsIn, Val.VarsInList, Ty.VarsInList, Eff.VarsInList]⟩
    · exact ⟨by simp [NamesWF, defOf], by simp [defOf, Ty.VarsInList], writeRet_varsIn, eff_varsIn range,
        by simp [defOf, callG, Comp.VarsIn, Val.VarsIn, Val.VarsInList, Ty.VarsInList, Eff.VarsInList]⟩
  · intro c cd h
    simp only [progCover, resultCons] at h
    split at h
    · cases h; simp [ConDecl.Scoped, okDecl, Ty.VarsInList, Ty.VarsIn]
    · split at h
      · cases h; simp [ConDecl.Scoped, errDecl, Ty.VarsInList, Ty.VarsIn]
      · cases h

/-- 結果と効果に Fail の型を持たない定義の Fail の文脈は空である。 -/
theorem qsig_empty (ix : Scope.Signature.Ix) : Qsig [] writeRet (Eff.singleAt "File.Write" ix) = Qempty := by
  funext i; apply propext
  simp [Qsig, QTys, QTy, QEff, Qempty, writeTys, TargetTable.ioErrorTy, Eff.singleAt, Eff.ofAtoms]

theorem defOf_admissible (ix : Scope.Signature.Ix) :
    Admissible B [] [] 0 (Qsig [] writeRet (Eff.singleAt "File.Write" ix)) Qempty [] []
      (Eff.singleAt "File.Write" ix) := by
  rw [qsig_empty]
  exact
    { types := ⟨rfl, fun i _ _ h => by simp at h⟩
      typeScope := fun t h => by simp at h
      rowCount := rfl
      rowScope := fun f h => by simp at h
      sourceRows := by
        simp only [Eff.singleAt, Eff.ofAtoms, Eff.RowsIn, Ty.RowsInList]
        refine ⟨fun i h => ?_, trivial⟩
        simp at h
      sourceQ := fun i h => by simp [Qempty] at h
      noFailRows := fun i h => by simp [Qempty] at h }

theorem defOf_ret_subst : Ty.subst [] [] writeRet = writeRet :=
  Ty.substAt_nil_of_wf [] writeRet (by simp [writeTys, TargetTable.ioErrorTy, Ty.WF, Ty.WFList])

/-- 定義 `defOf eff body` の関数の値 `fnRef f [] []` の呼び出しは、結果 `Result[Unit, IOError]` と宣言の効果を持つ。 -/
theorem call_typed {Ψ : StoreTy} {Γ : List (Option Ty)} {R : Option Ty} {f : FunName} {ix : Scope.Signature.Ix}
    {body : Comp} (hf : progCover.defs f = some (defOf (Eff.singleAt "File.Write" ix) body)) :
    HasTypeCQ progCover B Ψ Qempty [] Γ R (.app (.fnRef f [] []) []) writeRet (Eff.singleAt "File.Write" ix) := by
  have h := HasTypeCQ.C_App (Δ := []) (R := R) (args := [])
    (HasTypeVQ.V_Fun (Ψ := Ψ) (Γ := Γ) (f := f) (ts := []) (es := []) hf (by simp [NamesWF, defOf])
      (defOf_admissible ix)) .nil
  have hr : Ty.substAt 0 [] [] (defOf (Eff.singleAt "File.Write" ix) body).ret = writeRet := defOf_ret_subst
  have he : Eff.substAt 0 [] [] (defOf (Eff.singleAt "File.Write" ix) body).eff = Eff.singleAt "File.Write" ix :=
    substAt_singleAt _ _
  rw [hr, he] at h
  exact h

/-- `g()` の型付け。効果は `g` の宣言の狭い効果 `{File.Write[/data/a.txt]}` である。 -/
theorem callG_typed {Ψ : StoreTy} {Γ : List (Option Ty)} {R : Option Ty} :
    HasTypeCQ progCover B Ψ Qempty [] Γ R callG writeRet narrowEff :=
  call_typed (body := narrowCall) (by simp [progCover, fnTable])

/-- 狭い効果の利用者の関数の呼び出しを、広い上限 `{File.Write[/data/**]}` で型付ける（C-Eff の被覆）。 -/
theorem callG_bound {Ψ : StoreTy} {Γ : List (Option Ty)} {R : Option Ty} :
    HasTypeCQ progCover B Ψ Qempty [] Γ R callG writeRet bodyData :=
  .C_Eff callG_typed bound_covers_narrow

theorem progCover_wellTyped : progCover.WellTyped B := by
  refine ⟨?_, fun _ _ h => (by cases h)⟩
  intro f d h
  rcases progCover_defs h with ⟨-, rfl⟩ | ⟨-, rfl⟩ | ⟨-, rfl⟩
  · refine ⟨by simp [NamesWF, defOf], ?_⟩
    change HasTypeCQ _ _ _ (Qsig [] writeRet bodyData) [] _ _ _ _ _ _
    rw [qsig_empty]
    exact narrowCall_bound
  · refine ⟨by simp [NamesWF, defOf], ?_⟩
    change HasTypeCQ _ _ _ (Qsig [] writeRet narrowEff) [] _ _ _ _ _ _
    rw [qsig_empty]
    exact narrowCall_typed
  · refine ⟨by simp [NamesWF, defOf], ?_⟩
    change HasTypeCQ _ _ _ (Qsig [] writeRet bodyData) [] _ _ _ _ _ _
    rw [qsig_empty]
    exact callG_bound

theorem progCover_effectsOk : progCover.EffectsOk B :=
  ⟨fun _ _ _ h => (by cases h), fun _ _ h => (by cases h), fun _ _ h => (by cases h)⟩

theorem progCover_assumptions : B.Assumptions progCover :=
  assumptions pat tgt progCover progCover_hasResult

/-! ## 到達先の対象健全性 -/

/-- 書き込みの事象。 -/
theorem narrow_io_step {k : Cont} {σ : Store} (hk : NoHandler k (.prim "File.writeTextIn")) :
    Step progCover B (.run narrowCall k σ)
      (some (.io "File.writeTextIn" [.checked target, str "x"] (.val (.con "Ok" writeTys [.const .unit])) [target]))
      (.run (.ret (.con "Ok" writeTys [.const .unit])) k σ) :=
  .E_IO (s := TargetTable.writeTextIn) sig_write rfl hk (.inr (.inr (.inl ⟨rfl, .inl rfl, rfl⟩)))

theorem narrowCall_inst : (narrowCall.substTy [] []).instantiate [] = narrowCall := by
  simp [narrowCall, str, Comp.substTy, Comp.instantiate, Comp.substTyAt, Val.substTyAt, Comp.subst, Val.subst,
    Val.substList, Val.substTyAtList]

theorem callG_inst : (callG.substTy [] []).instantiate [] = callG := by
  simp [callG, Comp.substTy, Comp.instantiate, Comp.substTyAt, Val.substTyAt, Comp.subst, Val.subst,
    Val.substList, Val.substTyAtList]

theorem noHandler_marks (k : Cont) (hk : ∀ f ∈ k, f = .mark) : NoHandler k (.prim "File.writeTextIn") := by
  intro hs hin
  cases hk _ hin

/-- `f()` の開始状態から関数の呼び出しを一回経て、書き込みの事象に到達する。 -/
theorem callF_reach :
    Steps progCover B (.run callF [] Store.empty) (.run narrowCall [.mark] Store.empty) := by
  have h := Step.E_Fun (P := progCover) (B := B) (f := "f") (ts := []) (es := []) (ws := []) (k := [])
    (σ := Store.empty) (d := defOf bodyData narrowCall) (by simp [progCover, fnTable]) rfl rfl rfl
  rw [show (defOf bodyData narrowCall).body = narrowCall from rfl, narrowCall_inst] at h
  exact .step h .refl

/-- `h()` の開始状態から関数の呼び出しを二回経て（`h` の本体の `g()`）、書き込みの事象に到達する。 -/
theorem callH_reach :
    Steps progCover B (.run callH [] Store.empty) (.run narrowCall (markPush (markPush [])) Store.empty) := by
  have h1 := Step.E_Fun (P := progCover) (B := B) (f := "h") (ts := []) (es := []) (ws := []) (k := [])
    (σ := Store.empty) (d := defOf bodyData callG) (by simp [progCover, fnTable]) rfl rfl rfl
  rw [show (defOf bodyData callG).body = callG from rfl, callG_inst] at h1
  have h2 := Step.E_Fun (P := progCover) (B := B) (f := "g") (ts := []) (es := []) (ws := [])
    (k := markPush []) (σ := Store.empty) (d := defOf narrowEff narrowCall) (by simp [progCover, fnTable])
    rfl rfl rfl
  rw [show (defOf narrowEff narrowCall).body = narrowCall from rfl, narrowCall_inst] at h2
  exact .step h1 (.step h2 .refl)

/-- 上限 `{File.Write[/data/**]}` を宣言した関数 `f` の本体が `/data/a.txt` へ書く（被覆だけで型付く）とき、`f()` から
到達した書き込みの事象の観測 `/data/a.txt` は、`f` の上限が許す。 -/
theorem callF_reach_target_sound : ∀ t ∈ [target], B.Allows bodyData "File.Write" t := by
  have hm : HasTypeC progCover B StoreTy.empty [] [] none callF writeRet bodyData :=
    call_typed (body := narrowCall) (by simp [progCover, fnTable])
  obtain ⟨e, l, he, hl, h⟩ := reachable_target_sound progCover_wellFormed progCover_wellTyped progCover_effectsOk
    progCover_assumptions.core progCover_assumptions.target hm
    (by simp [callF, Comp.ClosedNoEffVars, Comp.VarsIn, Val.VarsIn, Ty.VarsInList, Eff.VarsInList, Val.VarsInList])
    callF_reach (narrow_io_step (noHandler_marks _ (by simp)))
  rw [sig_write] at he
  cases he
  cases hl
  exact h

/-- 狭い効果を宣言した利用者の関数 `g` を、上限 `{File.Write[/data/**]}` を宣言した関数 `h` から呼ぶとき、`h()` から
到達した書き込みの事象の観測 `/data/a.txt` は、`h` の上限が許す。 -/
theorem callH_reach_target_sound : ∀ t ∈ [target], B.Allows bodyData "File.Write" t := by
  have hm : HasTypeC progCover B StoreTy.empty [] [] none callH writeRet bodyData :=
    call_typed (body := callG) (by simp [progCover, fnTable])
  obtain ⟨e, l, he, hl, h⟩ := reachable_target_sound progCover_wellFormed progCover_wellTyped progCover_effectsOk
    progCover_assumptions.core progCover_assumptions.target hm
    (by simp [callH, Comp.ClosedNoEffVars, Comp.VarsIn, Val.VarsIn, Ty.VarsInList, Eff.VarsInList, Val.VarsInList])
    callH_reach (narrow_io_step (noHandler_marks _ (by simp [markPush])))
  rw [sig_write] at he
  cases he
  cases hl
  exact h

end Benitoite.Release.CoverExamples
