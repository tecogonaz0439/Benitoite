import Benitoite.Release.Theorems
import Benitoite.Release.TargetStepExamples

/-!
# 到達先の対象健全性の例と反例（L30.5）

到達先の対象健全性（`reachable_target_sound`）を、L20.7 の実例の表 `ModelTargets.Examples.B`（`CoreAssumptions` と
`TargetAgreement` を満たす）と本番の型付け・遷移の上の閉じたプログラムに当てる。

- 範囲付きの IO（Top でない）: `File.writeTextIn[;;/data/**](checked(/data/a.txt), "x")` を初期の効果
  `{File.Write[/data/**]}` で型付けると、初期状態から到達したどの書き込みの事象の観測も `/data/**` に属し、
  `/etc/passwd` を観測する書き込みの事象はない。
- 別の対象の節（L30.3 の例 3a）: 初期の効果 `{File.Write[/logs/**]}` で型付く `handleLog` から到達した節の IO の事象の
  観測 `/logs/l.txt` は初期の効果が許す。到達したどの書き込みの事象も、保護本体の対象 `/data/a.txt` を観測しない。
- 誤った節の規則の反例: 節の添字を判断 11 の規則の値（`/data/**`）でも Top でもない `/etc/**` にする。本番の規則
  `ClauseIxOk` はこれを許さない（許す添字は Top と `/data/**` だけ）。添字の許容を問わない誤った規則
  （`WrongHandleTyped`）は、捕捉した引数を `File.writeTextIn[;;/etc/**]` へ渡す節を初期の効果 `{File.Write[/etc/**]}`
  で型付けるが、実行は `/data/a.txt` を観測する書き込みの事象へ到達し、その観測は初期の効果に許されない。到達先の
  対象健全性から、本番の型付けはこのプログラムをその効果で型付けない。
-/

namespace Benitoite.Release.TargetReachExamples

open Benitoite.Release
open Benitoite.Release.ModelTargets
open Benitoite.Release.ModelTargets.Examples
open Benitoite.Release.HandlerTargetExamples
open Benitoite.Release.TargetStepExamples
open Scope.Domain (Range Target)

/-! ## 範囲付きの IO -/

/-- 範囲付きの IO の呼び出しの初期状態から、E-IO の事象の観測 `/data/a.txt` は初期の効果 `{File.Write[/data/**]}` の
`File.Write` の原子が許す。 -/
theorem ioCall_reach_target_sound : ∀ t ∈ [target], B.Allows bodyData "File.Write" t := by
  obtain ⟨e, l, he, hl, h⟩ := reachable_target_sound (progOf_wellFormed dataTree_wf) (progOf_wellTyped dataTree)
    (progOf_effectsOk dataTree) (progOf_assumptions dataTree).core (progOf_assumptions dataTree).target
    ioCall_typed' ioCall_closed .refl ioState_step
  rw [sig_write] at he
  cases he
  cases hl
  exact h

/-- 同じプログラムの初期状態から到達したどの書き込みの事象も、`/etc/passwd` を観測しない。 -/
theorem ioCall_no_passwd {s s' : State} {ws : List Val} {o : Outcome} {obs : List Target}
    (hsteps : Steps P3 B (.run ioCall [] Store.empty) s)
    (hst : Step P3 B s (some (.io "File.writeTextIn" ws o obs)) s') : passwd ∉ obs := by
  intro hp
  obtain ⟨e, l, he, hl, h⟩ := reachable_target_sound (progOf_wellFormed dataTree_wf) (progOf_wellTyped dataTree)
    (progOf_effectsOk dataTree) (progOf_assumptions dataTree).core (progOf_assumptions dataTree).target
    ioCall_typed' ioCall_closed hsteps hst
  rw [sig_write] at he
  cases he
  cases hl
  have ha : B.Allows readBound "File.Write" passwd :=
    Eff.allows_union.mpr (.inl (h passwd hp))
  exact readBound_not_allows_write_passwd ha

/-! ## 別の対象の節（例 3a） -/

/-- 例 3a の初期状態から E-Handle・E-OpPrim で到達した節の IO の事象の観測 `/logs/l.txt` は、初期の効果
`{File.Write[/logs/**]}` が許す（L30.4 の `sIO_target_sound` を到達先の定理から得る）。 -/
theorem handleLog_reach_target_sound : ∀ t ∈ [logT], B.Allows logsBound "File.Write" t := by
  obtain ⟨e, l, he, hl, h⟩ := reachable_target_sound (progOf_wellFormed dataTree_wf) (progOf_wellTyped dataTree)
    (progOf_effectsOk dataTree) (progOf_assumptions dataTree).core (progOf_assumptions dataTree).target
    (handleLog_typed rfl) handleLog_closed reach_io sIO_step
  rw [sig_write] at he
  cases he
  cases hl
  exact h

/-- 例 3a の初期状態から到達したどの書き込みの事象も、保護本体の対象 `/data/a.txt` を観測しない（保護本体の
書き込みは節が捕捉し、節は `/logs/**` へ書く）。 -/
theorem handleLog_never_observes_data {s s' : State} {ws : List Val} {o : Outcome} {obs : List Target}
    (hsteps : Steps P3 B (.run handleLog [] Store.empty) s)
    (hst : Step P3 B s (some (.io "File.writeTextIn" ws o obs)) s') : target ∉ obs := by
  intro hd
  obtain ⟨e, l, he, hl, h⟩ := reachable_target_sound (progOf_wellFormed dataTree_wf) (progOf_wellTyped dataTree)
    (progOf_effectsOk dataTree) (progOf_assumptions dataTree).core (progOf_assumptions dataTree).target
    (handleLog_typed rfl) handleLog_closed hsteps hst
  rw [sig_write] at he
  cases he
  cases hl
  exact logsBound_not_allows_data (h target hd)

/-! ## 誤った節の規則の反例 -/

/-- `/etc/**`。 -/
def etcR : Range := .path (.tree ["etc"])

/-- 初期の効果 `{File.Write[/etc/**]}`。 -/
abbrev etcBound : Eff := Eff.singleAt "File.Write" (.fixed etcR)

/-- 本番の規則が `File.writeTextIn` の節に許す添字は、保護本体の効果 `{File.Write[/data/**]}` のもとで、Top と規則の値
`/data/**` だけである（判断 11）。 -/
theorem clauseIxOk_bodyData_iff (S : Range) :
    ClauseIxOk B bodyData (.prim "File.writeTextIn") S ↔ S = .top ∨ S = range := by
  constructor
  · rintro (h | ⟨b, s, l, hb, hs, hl, hr⟩)
    · exact .inl h
    · cases hb
      rw [sig_write] at hs
      cases hs
      simp only [TargetTable.writeTextIn, TargetTable.ioIn] at hl
      cases hl
      have hm := hr.2.1
      rw [Eff.mem_singleAt] at hm
      simp only [Atom.name.injEq, dataTree, Scope.Signature.Ix.fixed.injEq, true_and] at hm
      exact .inr hm
  · rintro (h | h)
    · exact .inl h
    · subst h
      exact .inr ⟨"File.writeTextIn", TargetTable.writeTextIn, "File.Write", rfl, sig_write, rfl, bodyData_rule⟩

/-- 本番の規則は、節の添字 `/etc/**`（規則の値でも Top でもない）を許さない。 -/
theorem etc_not_clauseIxOk : ¬ ClauseIxOk B bodyData (.prim "File.writeTextIn") etcR := by
  intro h
  rcases (clauseIxOk_bodyData_iff etcR).mp h with h | h
  · cases h
  · simp [etcR, range] at h

/-- 誤った節の規則（反例のためのモデル）による、一つの節を持つ `handle` の型付け。本番の `C_Handle` と
`HasTypeClausesQ.cons` の前提のうち、節の操作の型 `ClauseSig`（節の添字 S の許容 `ClauseIxOk` と具体化
`opSigAt`）だけを、許容を問わない `opSigAt P B S o = some sg` に替えた。ほかの前提（保護本体の型付け、
`εm ⊆ ε ∪ handled(H)`、節の本体を出力の上限 ε で型付けること）は本番と同じである。 -/
def WrongHandleTyped (P : Program) (B : Builtins) (Ψ : StoreTy) (m : Comp) (o : OpRef) (n k : Nat) (body : Comp)
    (t : Ty) (ε : Eff) : Prop :=
  ∃ εm S sg, HasTypeC P B Ψ [] [] none m t εm ∧ Eff.Sub εm (Eff.union ε (handled P B [.mk o n k body])) ∧
    opSigAt P B S o = some sg ∧ NamesWF sg.names sg.params ∧ n = sg.params.length ∧ k = sg.tparams.length ∧
    Eff.WF 0 0 ε ∧
    HasTypeC P B Ψ.hideBuilders (sg.tparams ++ [])
      (some (.cont sg.ret (t.shift k 0) (Eff.shift k 0 ε)) :: (binds sg.params ++ shiftEnv k []))
      none body (t.shift k 0) (Eff.shift k 0 ε)

/-- 本番の節の操作の型は、誤った規則の節の操作の型でもある（誤った規則は許容の条件を外しただけである）。 -/
theorem wrong_of_clauseSig {P : Program} {e : Eff} {o : OpRef} {sg : OpSig} (h : ClauseSig P B e o sg) :
    ∃ S, opSigAt P B S o = some sg :=
  let ⟨S, _, hs⟩ := h; ⟨S, hs⟩

/-- 節の本体: 捕捉した引数 `path`（番号 2）と `text`（番号 1）を `File.writeTextIn[;;/etc/**]` へ渡す。 -/
def etcCall : Comp := .app (.prim "File.writeTextIn" [] [] [etcR]) [.var 2, .var 1]

def etcClause : Clause := .mk (.prim "File.writeTextIn") 2 0 etcCall

def hEtc : List Clause := [etcClause]

/-- `handle File.writeTextIn[;;/data/**](checked(/data/a.txt), "x") with { writeTextIn(p, s) k ⇒ etcCall }`。 -/
def handleEtc : Comp := .handle ioCall hEtc

/-- 節の添字 `/etc/**` で具体化した `File.writeTextIn` の操作の型。捕捉した引数は `PathIn["/etc/**"]` を持つ。 -/
def sgEtc : OpSig :=
  ⟨[], ["path", "text"], [.opaque "Scope.PathIn" (.fixed etcR), .base .string], writeRet, "File.Write"⟩

theorem opSigAt_etc {P : Program} : opSigAt P B etcR (.prim "File.writeTextIn") = some sgEtc := by
  simp [opSigAt, sig_write, sgEtc, TargetTable.writeTextIn, TargetTable.ioIn, TargetTable.pathIn,
    TargetTable.resultTy, TargetTable.ioErrorTy, writeTys, PrimSig.nranges, Ty.instTarget, Scope.Signature.Ix.inst]

theorem write_admissible_etc : B.RangeAdmissible "File.writeTextIn" TargetTable.writeTextIn [etcR] := by
  refine ⟨⟨?_, ?_, Or.inr ⟨Or.inl rfl, rfl⟩⟩, ?_⟩
  · exact ⟨by decide, Scope.Domain.Range.fitsKinds_nil⟩
  · intro r hr; simp only [List.mem_singleton] at hr; subst hr; decide
  · intro r hr; simp only [List.mem_singleton] at hr; subst hr; decide

/-- 誤った規則は、添字 `/etc/**` の節で `handleEtc` を初期の効果 `{File.Write[/etc/**]}` で型付ける。 -/
theorem wrong_rule_admits :
    WrongHandleTyped P3 B StoreTy.empty ioCall (.prim "File.writeTextIn") 2 0 etcCall writeRet etcBound := by
  refine ⟨bodyData, etcR, sgEtc, ioCall_typed', ⟨fun a ha => ?_, fun t ht => ?_⟩, opSigAt_etc,
    by simp [NamesWF, sgEtc], rfl, rfl, singleAt_wf _ _, ?_⟩
  · rw [Eff.mem_singleAt] at ha
    subst ha
    exact (Eff.mem_union _ _ _).mpr (Or.inr (mem_handled_write rfl rfl _))
  · simp [Eff.memFail, Eff.singleAt, Eff.ofAtoms, Eff.fails] at ht
  · rw [writeRet_shift, singleAt_shift]
    exact writeCall_typed write_admissible_etc (.V_Var (by simp [sgEtc, binds, shiftEnv]) (by simp))
      (.V_Var (by simp [sgEtc, binds, shiftEnv]) (by simp))

theorem handleEtc_closed : handleEtc.ClosedNoEffVars := by
  simp [handleEtc, hEtc, etcClause, etcCall, ioCall, str, Comp.ClosedNoEffVars, Comp.VarsIn, Val.VarsIn,
    Ty.VarsInList, Eff.VarsInList, Val.VarsInList, Clause.VarsInList]

/-- E-OpPrim の後のストア（継続の場所 0 に捕捉した継続）。 -/
def σEtc : Store := Store.empty.set 0 (.cont [.handleF hEtc])

/-- 節の本体の IO の状態。捕捉した引数 `checked(/data/a.txt)` が `/etc/**` の書き込みへ渡る。 -/
def sEtc : State := .run (.app (.prim "File.writeTextIn" [] [] [etcR]) [.checked target, str "x"]) [.drop 0] σEtc

theorem etcCall_inst : (etcCall.substTy [] []).instantiate ([.checked target, str "x"] ++ [.loc 0]) =
    .app (.prim "File.writeTextIn" [] [] [etcR]) [.checked target, str "x"] := by
  simp [etcCall, Comp.substTy, Comp.instantiate, str, Comp.substTyAt, Val.substTyAt, Val.substTyAtList, Comp.subst,
    Val.subst, Val.substList, instSubst]

/-- 初期状態から、E-Handle と E-OpPrim で節の本体の IO の状態へ進む（遷移は型付けによらない）。 -/
theorem reach_etc : Steps P3 B (.run handleEtc [] Store.empty) sEtc := by
  have hop : Step P3 B (.run ioCall [.handleF hEtc] Store.empty) none
      (.run ((etcCall.substTy [] []).instantiate ([.checked target, str "x"] ++ [.loc 0])) (.drop 0 :: [])
        (Store.empty.set 0 (.cont ([] ++ [.handleF hEtc])))) :=
    .E_OpPrim (s := TargetTable.writeTextIn) (k1 := []) (k2 := []) (c := etcClause) sig_write (.inl rfl)
      ⟨rfl, rfl, fun _ h => by cases h⟩ rfl rfl
  rw [etcCall_inst, List.nil_append] at hop
  exact .step .E_Handle (.step hop .refl)

/-- 節の本体の IO の事象。観測は `/data/a.txt` である（実装は引数の対象を報告する）。 -/
theorem sEtc_step :
    Step P3 B sEtc
      (some (.io "File.writeTextIn" [.checked target, str "x"] (.val (.con "Ok" writeTys [.const .unit])) [target]))
      (.run (.ret (.con "Ok" writeTys [.const .unit])) [.drop 0] σEtc) :=
  .E_IO (s := TargetTable.writeTextIn) sig_write rfl (fun _ h => by simp at h) (.inr (.inr (.inl ⟨rfl, .inl rfl, rfl⟩)))

/-- 初期の効果 `{File.Write[/etc/**]}` は `/data/a.txt` を許さない。 -/
theorem etcBound_not_allows_data : ¬ B.Allows etcBound "File.Write" target := by
  rintro ⟨kd, r, hk, hm, ht⟩
  have hk' : kd = .path := by simp [B, builtins, TargetTable.effKind] at hk; exact hk.symm
  subst hk'
  rw [Eff.mem_singleAt] at hm
  simp only [Atom.name.injEq, Scope.Signature.Ix.fixed.injEq, true_and] at hm
  subst hm
  revert ht
  decide

/-- 誤った規則のもとでは到達先の対象健全性が破れる。誤った規則は `handleEtc` を `{File.Write[/etc/**]}` で型付け、
初期状態から到達した書き込みの事象は `/data/a.txt` を観測し、その観測は初期の効果に許されない。 -/
theorem wrong_rule_unsound :
    WrongHandleTyped P3 B StoreTy.empty ioCall (.prim "File.writeTextIn") 2 0 etcCall writeRet etcBound ∧
    Steps P3 B (.run handleEtc [] Store.empty) sEtc ∧
    Step P3 B sEtc
      (some (.io "File.writeTextIn" [.checked target, str "x"] (.val (.con "Ok" writeTys [.const .unit])) [target]))
      (.run (.ret (.con "Ok" writeTys [.const .unit])) [.drop 0] σEtc) ∧
    ¬ B.Allows etcBound "File.Write" target :=
  ⟨wrong_rule_admits, reach_etc, sEtc_step, etcBound_not_allows_data⟩

/-- 本番の型付けでは、`handleEtc` をどの効果 ε で型付けても、ε は `File.Write` の名前で `/data/a.txt` を許す
（到達先の対象健全性から）。 -/
theorem handleEtc_typed_allows {a : Ty} {ε : Eff} (h : HasTypeC P3 B StoreTy.empty [] [] none handleEtc a ε) :
    B.Allows ε "File.Write" target := by
  obtain ⟨e, l, he, hl, hall⟩ := reachable_target_sound (progOf_wellFormed dataTree_wf) (progOf_wellTyped dataTree)
    (progOf_effectsOk dataTree) (progOf_assumptions dataTree).core (progOf_assumptions dataTree).target
    h handleEtc_closed reach_etc sEtc_step
  rw [sig_write] at he
  cases he
  cases hl
  exact hall target (List.mem_singleton_self _)

/-- 本番の型付けは、誤った規則が認めた `handleEtc` の型付け（効果 `{File.Write[/etc/**]}`）を認めない。 -/
theorem handleEtc_rejected {a : Ty} : ¬ HasTypeC P3 B StoreTy.empty [] [] none handleEtc a etcBound :=
  fun h => etcBound_not_allows_data (handleEtc_typed_allows h)

end Benitoite.Release.TargetReachExamples
