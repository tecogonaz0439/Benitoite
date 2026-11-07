import Benitoite.Release.Refinement.Surface.CheckDeclarations
import Benitoite.Release.Refinement.Surface.CheckEffects
import Benitoite.Release.Refinement.Surface.CheckPreparation

/-! 全プログラムの有限検査。定義とメソッドの予算と view は本体ごとに選ぶ。 -/
noncomputable section

namespace Benitoite.Release.Refinement.Surface.CheckTables

/-- 変性と効果の所属を検査し、一覧にある全ての定義と実装の本体を検査する。 -/
def checkPreparedProgram (q : Check.Input) (p : Program) : Check.Result Unit := do
  Check.require [] "invalid data variance"
    (CheckVariance.check q.formation q.D.core q.dataNames q.ctorNames)
  Check.require [] "invalid effect declarations" (effectsCheck q)
  checkNamed p.defs (fun path n d =>
    CheckDeclarations.checkDef {q with D := q.D.withView (p.functionViews n), proofSteps := q.functionSteps n} path d) [0] q.defs 0
  checkNamed p.impls (fun path n id =>
    CheckDeclarations.checkImpl q n path id (p.methodViews n)) [1] q.impls 0

/-- 元の全本体から内部行を収集して解決し、その同じ表で全プログラムを検査する。 -/
def checkProgram (q : Check.Input) (p : Program) : Check.Result Unit :=
  let ready := CheckPreparation.prepare q p
  checkPreparedProgram ready.input ready.program

private theorem bind_error {r s : Check.Result Unit} {error}
    (h : (r >>= fun _ => s) = .error error) :
    r = .error error ∨ (r = .ok () ∧ s = .error error) := by
  cases r with
  | error err => exact Or.inl (Except.error.inj h ▸ rfl)
  | ok value => cases value; exact Or.inr ⟨rfl, h⟩

private theorem checkNamed_error {table : String → Option α} {check path names index error}
    (h : checkNamed table check path names index = .error error) :
    ∃ n ∈ names, ∃ a location, table n = some a ∧ check location n a = .error error := by
  induction names generalizing index with
  | nil => cases h
  | cons n ns ih =>
    cases ht : table n with
    | none =>
      obtain ⟨name, hn, a, location, ha, he⟩ := ih (by simpa only [checkNamed, ht] using h)
      exact ⟨name, List.mem_cons_of_mem _ hn, a, location, ha, he⟩
    | some a =>
      have hb : (check (path ++ [index]) n a >>= fun _ =>
        checkNamed table check path ns (index + 1)) = .error error := by
          simpa only [checkNamed, ht] using h
      rcases bind_error hb with hc | ⟨_, ht'⟩
      · exact ⟨n, List.mem_cons_self, a, path ++ [index], ht, hc⟩
      · obtain ⟨name, hn, a', location, ha, he⟩ := ih ht'
        exact ⟨name, List.mem_cons_of_mem _ hn, a', location, ha, he⟩

/-- 関数又はメソッドの本体で、実際の推論か証明書の会計が停止した。 -/
def ProgramStopped (q : Check.Input) (p : Program) : Prop :=
  (∃ n d path, p.defs n = some d ∧
    CheckDeclarations.DefinitionStopped
      {q with D := q.D.withView (p.functionViews n), proofSteps := q.functionSteps n} path d) ∨
  (∃ n id path cd, p.impls n = some id ∧ q.D.classes id.cls = some cd ∧
    CheckDeclarations.MethodsStopped q n (path ++ [1]) id cd (p.methodViews n))

/-- 関数の範囲列が空であるときの、本体の停止の存在形。 -/
def ClosedProgramStopped (q : Check.Input) (p : Program) : Prop :=
  (∃ n d path, p.defs n = some d ∧
    CheckDeclarations.BodyTelStopped
      (CheckDeclarations.definitionInput
        {q with D := q.D.withView (p.functionViews n), proofSteps := q.functionSteps n} d)
      (CheckAdmissible.telQ d.neffs d.toFunDecl.tel) d.tparams [] [] (path ++ [1]) d.toFunDecl.tel d.body) ∨
  (∃ n id path cd, p.impls n = some id ∧ q.D.classes id.cls = some cd ∧
    CheckDeclarations.MethodsStopped q n (path ++ [1]) id cd (p.methodViews n))

/-- 全関数の範囲列が空なら、本体の停止を元の存在形へ戻せる。 -/
theorem programStopped_no_ranges {q p}
    (hk : ∀ n d, p.defs n = some d → d.rangeParams = [])
    (h : ProgramStopped q p) : ClosedProgramStopped q p := by
  rcases h with ⟨n, d, path, hd, hs⟩ | hs
  · left
    refine ⟨n, d, path, hd, ?_⟩
    simpa only [CheckDeclarations.DefinitionStopped, hk n d hd, ite_true] using hs
  · exact Or.inr hs

private theorem require_not_unknown {path reason test error}
    (h : Check.require path reason test = .error error) (hu : error.kind = .unknown) : False := by
  unfold Check.require at h
  split at h
  · cases h
  · cases h; cases hu

/-- プログラムの入口の unknown は、一覧にある実際の本体の打ち切りに由来する。 -/
theorem checkPreparedProgram_unknown {q p error} (h : checkPreparedProgram q p = .error error)
    (hu : error.kind = .unknown) : ProgramStopped q p := by
  unfold checkPreparedProgram at h
  rcases bind_error h with hv | ⟨_, hr⟩
  · exact (require_not_unknown hv hu).elim
  · rcases bind_error hr with he | ⟨_, hr⟩
    · exact (require_not_unknown he hu).elim
    · rcases bind_error hr with hd | ⟨_, hi⟩
      · obtain ⟨n, _, d, path, hn, hc⟩ := checkNamed_error hd
        exact Or.inl ⟨n, d, path, hn, CheckDeclarations.checkDef_unknown hc hu⟩
      · obtain ⟨n, _, id, path, hn, hc⟩ := checkNamed_error hi
        obtain ⟨cd, hcd, hs⟩ := CheckDeclarations.checkImpl_unknown hc hu
        exact Or.inr ⟨n, id, path, cd, hn, hcd, hs⟩

/-- 実入口の unknown は、同じ入口が解決した本体の実際の打ち切りに由来する。 -/
theorem checkProgram_unknown {q p error} (h : checkProgram q p = .error error)
    (hu : error.kind = .unknown) :
    ProgramStopped (CheckPreparation.prepare q p).input (CheckPreparation.prepare q p).program :=
  checkPreparedProgram_unknown h hu

end Benitoite.Release.Refinement.Surface.CheckTables
