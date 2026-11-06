import Benitoite.Release.Refinement.Surface.CheckMaterials
import Benitoite.Release.Refinement.Surface.CheckAccept

/-! 有限材料から導いた名前の完全性と表の保存を使う、検査と実入口の健全性。 -/
namespace Benitoite.Release.Refinement.Surface.CheckTables
open CheckDeclarations

/-- 有限の同じ材料から全件性と宣言の保存を導き、型付けを得る。 -/
theorem Materials.checkProgram_sound {m : Materials} {base : Check.Input}
    (hq : (m.input base).Sound)
    (hd : ∀ n d, m.program.defs n = some d → DefSupport (m.input base) d)
    (hi : ∀ n id, m.program.impls n = some id → ImplSupport (m.input base) id)
    (h : checkProgram (m.input base) m.program = .ok ()) :
    CheckedUnder m.program (m.input base) :=
  CheckTables.checkProgram_sound (q := m.input base) hq (m.names_complete base) hd hi (fun _ _ h => Materials.impl_names_complete h) (m.extends base) h

/-- 外部の署名による補完が無い材料では、自身の表の下で型付く。 -/
theorem Materials.checkProgram_empty {m : Materials} {base : Check.Input}
    (hq : (m.input base).Sound)
    (hd : ∀ n d, m.program.defs n = some d → DefSupport (m.input base) d)
    (hi : ∀ n id, m.program.impls n = some id → ImplSupport (m.input base) id)
    (hf : m.trustedFuns = []) (hit : m.trustedImpls = [])
    (h : checkProgram (m.input base) m.program = .ok ()) :
    m.program.WellTyped base.B base.opPrim :=
  CheckTables.checkProgram_empty (q := m.input base) hq (m.names_complete base) hd hi (fun _ _ h => Materials.impl_names_complete h)
    (Materials.declarations_empty hf hit) h

/-- 型付けと、材料の実際のメソッド名と宣言の契約名の一致を得る。 -/
theorem Materials.checkProgram_sound_contracts {m : Materials} {base : Check.Input}
    (hq : (m.input base).Sound)
    (hd : ∀ n d, m.program.defs n = some d → DefSupport (m.input base) d)
    (hi : ∀ n id, m.program.impls n = some id → ImplSupport (m.input base) id)
    (h : checkProgram (m.input base) m.program = .ok ()) :
    CheckedUnder m.program (m.input base) ∧
      ∀ i id, m.program.impls i = some id → ContractsMatch (m.input base) i id :=
  CheckTables.checkProgram_sound_contracts (q := m.input base) hq (m.names_complete base) hd hi (fun _ _ h => Materials.impl_names_complete h) (m.extends base) h

/-- 補完のない材料でも、型付けと実名の一致を同じ成功から得る。 -/
theorem Materials.checkProgram_empty_contracts {m : Materials} {base : Check.Input}
    (hq : (m.input base).Sound)
    (hd : ∀ n d, m.program.defs n = some d → DefSupport (m.input base) d)
    (hi : ∀ n id, m.program.impls n = some id → ImplSupport (m.input base) id)
    (hf : m.trustedFuns = []) (hit : m.trustedImpls = [])
    (h : checkProgram (m.input base) m.program = .ok ()) :
    m.program.WellTyped base.B base.opPrim ∧
      ∀ i id, m.program.impls i = some id → ContractsMatch (m.input base) i id :=
  CheckTables.checkProgram_empty_contracts (q := m.input base) hq (m.names_complete base) hd hi (fun _ _ h => Materials.impl_names_complete h)
    (Materials.declarations_empty hf hit) h

/-- 全ての定義と実装メソッドを含む有限材料で、型付けと受理を同時に得る。 -/
theorem Materials.checkProgramAccepted_sound {m : Materials} {base : Check.Input}
    (hq : (m.input base).Sound)
    (hd : ∀ n d, m.program.defs n = some d → DefSupport (m.input base) d)
    (hi : ∀ n id, m.program.impls n = some id → ImplSupport (m.input base) id)
    {A : CheckAccept.AcceptInput}
    (h : CheckAccept.checkProgramAccepted (m.input base) A m.program = .ok ()) :
    CheckedUnder m.program (m.input base) ∧
      CheckAccept.Accepted A (m.input base) m.program :=
  CheckAccept.checkProgramAccepted_sound (q := m.input base) hq (m.names_complete base) hd hi (fun _ _ h => Materials.impl_names_complete h)
    (m.extends base) (m.accept_names_complete base) h

/-- 全ての定義と実装メソッドを含む有限材料で、型付けと受理を同時に得る。 -/
theorem Materials.checkProgramAccepted_empty {m : Materials} {base : Check.Input}
    (hq : (m.input base).Sound)
    (hd : ∀ n d, m.program.defs n = some d → DefSupport (m.input base) d)
    (hi : ∀ n id, m.program.impls n = some id → ImplSupport (m.input base) id)
    {A : CheckAccept.AcceptInput}
    (hf : m.trustedFuns = []) (hit : m.trustedImpls = [])
    (h : CheckAccept.checkProgramAccepted (m.input base) A m.program = .ok ()) :
    m.program.WellTyped base.B base.opPrim ∧
      CheckAccept.Accepted A (m.input base) m.program :=
  CheckAccept.checkProgramAccepted_empty (q := m.input base) hq (m.names_complete base) hd hi (fun _ _ h => Materials.impl_names_complete h)
    (Materials.declarations_empty hf hit) (m.accept_names_complete base) h

end Benitoite.Release.Refinement.Surface.CheckTables
