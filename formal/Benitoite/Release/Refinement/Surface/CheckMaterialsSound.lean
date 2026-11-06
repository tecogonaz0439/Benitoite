import Benitoite.Release.Refinement.Surface.CheckMaterials
import Benitoite.Release.Refinement.Surface.CheckAccept

/-! 有限材料から導いた全件性と宣言の保存を、判定の呼出しを解決する実入口へ渡す。 -/
namespace Benitoite.Release.Refinement.Surface.CheckTables
open CheckDeclarations

/-- 有限材料の全件性から、実入口が解決した同じ全本体の型付けを得る。 -/
theorem Materials.checkProgram_sound {m : Materials} {base : Check.Input}
    (hq : (m.input base).Sound)
    (hd : ∀ n d, (CheckPreparation.prepare (m.input base) m.program).program.defs n = some d → DefSupport (CheckPreparation.prepare (m.input base) m.program).input d)
    (hi : ∀ n id, (CheckPreparation.prepare (m.input base) m.program).program.impls n = some id → ImplSupport (CheckPreparation.prepare (m.input base) m.program).input id)
    (h : checkProgram (m.input base) m.program = .ok ()) :
    CheckedUnder (CheckPreparation.prepare (m.input base) m.program).program (CheckPreparation.prepare (m.input base) m.program).input := by
  exact CheckTables.checkProgram_sound (q := m.input base) (p := m.program)
    (CheckPreparation.prepare_sound hq _) (prepare_names (m.names_complete base)) hd hi
    (prepare_impl_names (fun _ _ h => Materials.impl_names_complete h))
    (prepare_extension (m.extends base)) h

/-- 有限材料の全件性から、実入口が解決した同じ全本体の型付けを得る。 -/
theorem Materials.checkProgram_empty {m : Materials} {base : Check.Input}
    (hq : (m.input base).Sound)
    (hd : ∀ n d, (CheckPreparation.prepare (m.input base) m.program).program.defs n = some d → DefSupport (CheckPreparation.prepare (m.input base) m.program).input d)
    (hi : ∀ n id, (CheckPreparation.prepare (m.input base) m.program).program.impls n = some id → ImplSupport (CheckPreparation.prepare (m.input base) m.program).input id)
    (hf : m.trustedFuns = []) (hit : m.trustedImpls = [])
    (h : checkProgram (m.input base) m.program = .ok ()) :
    (CheckPreparation.prepare (m.input base) m.program).program.WellTyped (CheckPreparation.prepare (m.input base) m.program).input.B (CheckPreparation.prepare (m.input base) m.program).input.opPrim := by
  have hD : (CheckPreparation.prepare (m.input base) m.program).input.D = (CheckPreparation.prepare (m.input base) m.program).program.declarations := by
    rw [CheckPreparation.prepare_declarations]
    rcases CheckPreparation.prepare_cases (m.input base) m.program with ready | ⟨rows,ready⟩
    · rw [ready]; exact Materials.declarations_empty hf hit
    · rw [ready]; exact Materials.declarations_empty hf hit
  exact CheckTables.checkProgram_empty (q := m.input base) (p := m.program)
    (CheckPreparation.prepare_sound hq _) (prepare_names (m.names_complete base)) hd hi
    (prepare_impl_names (fun _ _ h => Materials.impl_names_complete h))
    hD h

/-- 有限材料の全件性から、実入口が解決した同じ全本体の型付けを得る。 -/
theorem Materials.checkProgram_sound_contracts {m : Materials} {base : Check.Input}
    (hq : (m.input base).Sound)
    (hd : ∀ n d, (CheckPreparation.prepare (m.input base) m.program).program.defs n = some d → DefSupport (CheckPreparation.prepare (m.input base) m.program).input d)
    (hi : ∀ n id, (CheckPreparation.prepare (m.input base) m.program).program.impls n = some id → ImplSupport (CheckPreparation.prepare (m.input base) m.program).input id)
    (h : checkProgram (m.input base) m.program = .ok ()) :
    CheckedUnder (CheckPreparation.prepare (m.input base) m.program).program (CheckPreparation.prepare (m.input base) m.program).input ∧ ∀ i id, (CheckPreparation.prepare (m.input base) m.program).program.impls i = some id → ContractsMatch (CheckPreparation.prepare (m.input base) m.program).input i id := by
  exact CheckTables.checkProgram_sound_contracts (q := m.input base) (p := m.program)
    (CheckPreparation.prepare_sound hq _) (prepare_names (m.names_complete base)) hd hi
    (prepare_impl_names (fun _ _ h => Materials.impl_names_complete h))
    (prepare_extension (m.extends base)) h

/-- 有限材料の全件性から、実入口が解決した同じ全本体の型付けを得る。 -/
theorem Materials.checkProgram_empty_contracts {m : Materials} {base : Check.Input}
    (hq : (m.input base).Sound)
    (hd : ∀ n d, (CheckPreparation.prepare (m.input base) m.program).program.defs n = some d → DefSupport (CheckPreparation.prepare (m.input base) m.program).input d)
    (hi : ∀ n id, (CheckPreparation.prepare (m.input base) m.program).program.impls n = some id → ImplSupport (CheckPreparation.prepare (m.input base) m.program).input id)
    (hf : m.trustedFuns = []) (hit : m.trustedImpls = [])
    (h : checkProgram (m.input base) m.program = .ok ()) :
    (CheckPreparation.prepare (m.input base) m.program).program.WellTyped (CheckPreparation.prepare (m.input base) m.program).input.B (CheckPreparation.prepare (m.input base) m.program).input.opPrim ∧ ∀ i id, (CheckPreparation.prepare (m.input base) m.program).program.impls i = some id → ContractsMatch (CheckPreparation.prepare (m.input base) m.program).input i id := by
  have hD : (CheckPreparation.prepare (m.input base) m.program).input.D = (CheckPreparation.prepare (m.input base) m.program).program.declarations := by
    rw [CheckPreparation.prepare_declarations]
    rcases CheckPreparation.prepare_cases (m.input base) m.program with ready | ⟨rows,ready⟩
    · rw [ready]; exact Materials.declarations_empty hf hit
    · rw [ready]; exact Materials.declarations_empty hf hit
  exact CheckTables.checkProgram_empty_contracts (q := m.input base) (p := m.program)
    (CheckPreparation.prepare_sound hq _) (prepare_names (m.names_complete base)) hd hi
    (prepare_impl_names (fun _ _ h => Materials.impl_names_complete h))
    hD h

/-- 有限材料の全件性から、実入口が解決した同じ全本体の型付けを得る。 -/
theorem Materials.checkProgramAccepted_sound {m : Materials} {base : Check.Input}
    (hq : (m.input base).Sound)
    (hd : ∀ n d, (CheckPreparation.prepare (m.input base) m.program).program.defs n = some d → DefSupport (CheckPreparation.prepare (m.input base) m.program).input d)
    (hi : ∀ n id, (CheckPreparation.prepare (m.input base) m.program).program.impls n = some id → ImplSupport (CheckPreparation.prepare (m.input base) m.program).input id)
    {A : CheckAccept.AcceptInput}
    (h : CheckAccept.checkProgramAccepted (m.input base) A m.program = .ok ()) :
    CheckedUnder (CheckPreparation.prepare (m.input base) m.program).program (CheckPreparation.prepare (m.input base) m.program).input ∧ CheckAccept.Accepted A (m.input base) m.program := by
  exact CheckAccept.checkProgramAccepted_sound (q := m.input base) (p := m.program)
    (CheckPreparation.prepare_sound hq _) (prepare_names (m.names_complete base)) hd hi
    (prepare_impl_names (fun _ _ h => Materials.impl_names_complete h))
    (prepare_extension (m.extends base)) (m.accept_names_complete base) h

/-- 有限材料の全件性から、実入口が解決した同じ全本体の型付けを得る。 -/
theorem Materials.checkProgramAccepted_empty {m : Materials} {base : Check.Input}
    (hq : (m.input base).Sound)
    (hd : ∀ n d, (CheckPreparation.prepare (m.input base) m.program).program.defs n = some d → DefSupport (CheckPreparation.prepare (m.input base) m.program).input d)
    (hi : ∀ n id, (CheckPreparation.prepare (m.input base) m.program).program.impls n = some id → ImplSupport (CheckPreparation.prepare (m.input base) m.program).input id)
    {A : CheckAccept.AcceptInput}
    (hf : m.trustedFuns = []) (hit : m.trustedImpls = [])
    (h : CheckAccept.checkProgramAccepted (m.input base) A m.program = .ok ()) :
    (CheckPreparation.prepare (m.input base) m.program).program.WellTyped (CheckPreparation.prepare (m.input base) m.program).input.B (CheckPreparation.prepare (m.input base) m.program).input.opPrim ∧ CheckAccept.Accepted A (m.input base) m.program := by
  have hD : (CheckPreparation.prepare (m.input base) m.program).input.D = (CheckPreparation.prepare (m.input base) m.program).program.declarations := by
    rw [CheckPreparation.prepare_declarations]
    rcases CheckPreparation.prepare_cases (m.input base) m.program with ready | ⟨rows,ready⟩
    · rw [ready]; exact Materials.declarations_empty hf hit
    · rw [ready]; exact Materials.declarations_empty hf hit
  exact CheckAccept.checkProgramAccepted_empty (q := m.input base) (p := m.program)
    (CheckPreparation.prepare_sound hq _) (prepare_names (m.names_complete base)) hd hi
    (prepare_impl_names (fun _ _ h => Materials.impl_names_complete h))
    hD (m.accept_names_complete base) h

end Benitoite.Release.Refinement.Surface.CheckTables
