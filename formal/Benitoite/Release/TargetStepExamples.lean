import Benitoite.Release.Lemmas.TargetStep
import Benitoite.Release.HandlerTargetExamples

/-!
# 一段の対象健全性の例（L30.4）

一段の対象健全性（`step_target_sound`）を、L20.7 の実例の表 `ModelTargets.Examples.B`（`CoreAssumptions` と
`TargetAgreement` を満たす）と L30.3 の例 3a の状態に当てる。

- 範囲付きの IO（Top でない）: `File.writeTextIn[;;/data/**](checked(/data/a.txt), "x")` の状態（L20.7 の `ioState`）の
  E-IO の事象の観測 `/data/a.txt` は、末尾の効果 `{File.Write[/data/**]}` の `File.Write` の原子が許す。
- 節の IO: 例 3a の節の本体の IO の状態（初期状態から E-Handle と E-OpPrim で到達し、保存の定理で初期の上限
  `{File.Write[/logs/**]}` を末尾に持つ）の事象の観測 `/logs/l.txt` は、その上限が許す。L30.3 の `sIO_obs_allowed` を
  一般の定理から得る。
- 節の型付けの反転: E-Handle の後の状態（捕捉される呼び出しと節を持つ枠）で、節の本体の型付けから、節が書く
  `/logs/l.txt` が初期の上限に許されることを、保存の定理を通さずに示す（`StateTyE.clause_allows`）。
- RV-L00 中1 の反例: 上限 `{File.Write[/data/**], File.Read}` は、`File.Read` の名前で `/etc/passwd` を許し、名前を
  落とした形（`∃ l, …`）も満たす。しかし `File.Write` の名前では許さないので、この上限を末尾に持つ型の付いた状態から、
  観測に `/etc/passwd` を含む書き込みの事象の遷移はない。
-/

namespace Benitoite.Release.TargetStepExamples

open Benitoite.Release
open Benitoite.Release.ModelTargets
open Benitoite.Release.ModelTargets.Examples
open Benitoite.Release.HandlerTargetExamples
open Scope.Domain (Range Target)

/-! ## 範囲付きの IO の事象 -/

/-- 範囲付きの IO の呼び出しの状態は、末尾に `{File.Write[/data/**]}` を固定した状態の型付けを持つ。 -/
theorem ioState_typedE : StateTyE (progOf dataTree) B (Eff.singleAt "File.Write" dataTree) ioState := by
  have h := stateTyE_init_eff (progOf_wellFormed dataTree_wf) (progOf_assumptions dataTree).core ioCall_typed
    ioCall_closed
  rwa [write_eff] at h

/-- 一段の対象健全性を範囲付きの IO の事象に当てる。事象の操作の名前は `File.Write` で、観測 `/data/a.txt` は末尾の
効果の `File.Write` の原子が許す。 -/
theorem ioState_target_sound :
    ∀ t ∈ [target], B.Allows (Eff.singleAt "File.Write" dataTree) "File.Write" t := by
  obtain ⟨e, l, he, hl, h⟩ := step_target_sound (progOf_effectsOk dataTree) (progOf_assumptions dataTree).core
    (progOf_assumptions dataTree).target ioState_typedE ioState_step
  rw [sig_write] at he
  cases he
  cases hl
  exact h

/-! ## 例 3a の節の IO の事象 -/

/-- 例 3a の節の本体の IO の事象の観測 `/logs/l.txt` は、初期の上限 `{File.Write[/logs/**]}` が許す。L30.3 の
`sIO_obs_allowed` を一般の定理から得る。 -/
theorem sIO_target_sound : ∀ t ∈ [logT], B.Allows logsBound "File.Write" t := by
  obtain ⟨e, l, he, hl, h⟩ := step_target_sound (progOf_effectsOk dataTree) (progOf_assumptions dataTree).core
    (progOf_assumptions dataTree).target sIO_typed sIO_step
  rw [sig_write] at he
  cases he
  cases hl
  exact h

/-! ## 節の型付けの反転（E-OpPrim の前の状態） -/

/-- 組み込みの呼び出しの型付けの、任意の文脈での効果の反転。 -/
theorem inv_prim_app_eff {P : Program} {Ψ : StoreTy} {C : List TParam} {Γ : List (Option Ty)} {R : Option Ty}
    {b : PrimName} {ts : List Ty} {es : List Eff} {rs : List Range} {ws : List Val} {a : Ty} {ε : Eff}
    (h : HasTypeC P B Ψ C Γ R (.app (.prim b ts es rs) ws) a ε) :
    ∃ s, B.sig b = some s ∧ Eff.Covers ε (Eff.substAt 0 ts es (s.inst rs).eff) := by
  obtain ⟨names, as, b', ε', hf, -, -, hsub⟩ := h.inv_app rfl
  obtain ⟨s, hs, -, -, -, -, -, hle2⟩ := hf.inv_prim rfl
  rw [fnTy_eq] at hle2
  obtain ⟨-, -, -, hsub2⟩ := Ty.Le.fn_fn' hle2
  exact ⟨s, hs, hsub.trans hsub2⟩

/-- E-Handle の後の状態 `s1` で、`File.writeTextIn` を処理する枠は `hLog` の枠であり、その下の継続は空である。 -/
theorem s1_split : SplitAt (.prim "File.writeTextIn") [.handleF hLog] [] hLog [] :=
  ⟨rfl, rfl, fun _ h => by cases h⟩

theorem s1_find : findClause hLog (.prim "File.writeTextIn") = some logClause := rfl

/-- 節の型付けの反転から: 例 3a の節の本体（`/logs/l.txt` への書き込み）の効果が許す対象 `/logs/l.txt` は、
初期の上限 `{File.Write[/logs/**]}` が許す。保存の定理を通さず、E-Handle の後の状態の節の型付けだけから示す。 -/
theorem s1_clause_allows_log : B.Allows logsBound "File.Write" logT := by
  obtain ⟨Ψ, Rh, t, εh, εc, sg, -, -, -, hbody, hall⟩ := s1_typed.clause_allows (by simp) s1_split s1_find
  -- 節の本体は `logCall` であり、その型付けの効果は `{File.Write[/logs/**]}` を含む。
  change HasTypeC P3 B Ψ _ _ _ logCall _ _ at hbody
  obtain ⟨s, hs, hsub⟩ := inv_prim_app_eff hbody
  rw [sig_write] at hs
  cases hs
  rw [write_eff_at] at hsub
  obtain ⟨a1, ha1, ha1c⟩ := hsub.1 _ ((Eff.mem_singleAt _ _ _).mpr rfl)
  obtain ⟨jx, rfl⟩ := ha1c.name_right
  refine hall "File.Write" logT (Eff.allows_of_mem_covers rfl ha1 ha1c (by decide))
    (fun _ h => by cases h)

/-- 同じ状態で、捕捉される呼び出しの対象 `/data/a.txt` は、節の添字を選ぶ枠の穴の効果が許し、許す名前は
`File.Write` だけである（`StateTyE.opPrim_clause_allows`）。 -/
theorem s1_captured_allows : ∃ εh sg, ClauseSig P3 B εh (.prim "File.writeTextIn") sg ∧
    B.Allows εh "File.Write" target ∧
    ∀ l' t, B.Allows (TargetTable.writeTextIn.inst [range]).eff l' t → l' = "File.Write" := by
  obtain ⟨l, εh, εc, sg, hl, hsg, hcap, -⟩ := s1_typed.opPrim_clause_allows (progOf_effectsOk dataTree)
    (progOf_assumptions dataTree).core sig_write (.inl rfl) s1_split s1_find
  cases hl
  have hmem : Eff.mem (TargetTable.writeTextIn.inst [range]).eff (.name "File.Write" (.fixed range)) := by
    rw [PrimSig.inst_eff]
    simp only [TargetTable.writeTextIn, TargetTable.ioIn, Eff.instR_singleAt]
    exact (Eff.mem_singleAt _ _ _).mpr rfl
  exact ⟨εh, sg, hsg, (hcap _ target ⟨.path, range, rfl, hmem, by decide⟩).2, fun l' t h => (hcap l' t h).1⟩

/-! ## RV-L00 中1 の反例 -/

/-- `/etc/passwd`。 -/
def passwd : Target := .path ["etc", "passwd"]

/-- 上限 `{File.Write[/data/**], File.Read}`。`File.Read` は範囲のない（Top の）原子で、種類 path の全対象を許す。 -/
noncomputable abbrev readBound : Eff := Eff.union (Eff.singleAt "File.Write" dataTree) (Eff.single "File.Read")

theorem readBound_allows_read_passwd : B.Allows readBound "File.Read" passwd :=
  Eff.allows_union.mpr (.inr (Eff.allows_of_nameTop ((Eff.mem_single _ _).mpr rfl) rfl))

/-- 名前を落とした形（RV-L00 中1 の言明の案 `∃ l, allows ε l t`）は、`/etc/passwd` について成り立ってしまう。 -/
theorem readBound_exists_name_allows_passwd : ∃ l, B.Allows readBound l passwd :=
  ⟨_, readBound_allows_read_passwd⟩

/-- `File.Write` の名前では、上限は `/etc/passwd` を許さない。足した `File.Read` の原子は別の名前なので許可を足さない
（`Eff.allows_union_other_name`）。 -/
theorem readBound_not_allows_write_passwd : ¬ B.Allows readBound "File.Write" passwd := by
  intro ha
  have ha' : B.Allows (Eff.union (Eff.singleAt "File.Write" dataTree)
      (Eff.singleAt "File.Read" Scope.Signature.Ix.top)) "File.Write" passwd := ha
  obtain ⟨k, r, hk, hm, ht⟩ := (Eff.allows_union_other_name (by decide)).mp ha'
  rw [Eff.mem_singleAt] at hm
  simp only [Atom.name.injEq, dataTree, Scope.Signature.Ix.fixed.injEq, true_and] at hm
  subst hm
  cases hk
  exact absurd ht (by decide)

/-- 一段の対象健全性から: 末尾に `{File.Write[/data/**], File.Read}` を持つどの型の付いた状態からも、観測に
`/etc/passwd` を含む書き込みの事象の遷移はない。 -/
theorem no_write_event_passwd {s s' : State} {ws : List Val} {o : Outcome} {obs : List Target}
    (hs : StateTyE (progOf dataTree) B readBound s) (hobs : passwd ∈ obs) :
    ¬ Step (progOf dataTree) B s (some (.io "File.writeTextIn" ws o obs)) s' := by
  intro hst
  obtain ⟨e, l, he, hl, h⟩ := step_target_sound (progOf_effectsOk dataTree) (progOf_assumptions dataTree).core
    (progOf_assumptions dataTree).target hs hst
  rw [sig_write] at he
  cases he
  cases hl
  exact readBound_not_allows_write_passwd (h passwd hobs)

/-- 同じ上限を末尾に持つ状態は実際にある（範囲付きの IO の呼び出しの状態）。その状態の事象の観測 `/data/a.txt` は、
`File.Write` の名前で許される。 -/
theorem ioState_readBound_typed : StateTyE (progOf dataTree) B readBound ioState :=
  ioState_typedE.mono ⟨fun a ha => (Eff.mem_union _ _ a).mpr (.inl ha), fun t ht => (Eff.memFail_union _ _ t).mpr (.inl ht)⟩

theorem ioState_readBound_allows : B.Allows readBound "File.Write" target := by
  obtain ⟨e, l, he, hl, h⟩ := step_target_sound (progOf_effectsOk dataTree) (progOf_assumptions dataTree).core
    (progOf_assumptions dataTree).target ioState_readBound_typed ioState_step
  rw [sig_write] at he
  cases he
  cases hl
  exact h target (List.mem_singleton_self _)

end Benitoite.Release.TargetStepExamples
