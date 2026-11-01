import Benitoite.Release.Refinement.TypeSubstFormation
import Benitoite.Release.Refinement.LegacyInput

namespace Benitoite.Release.Refinement.A3bConnections

/-- 呼出しの既存の入力だけで九欄を供給する。 -/
theorem function_input {P B Q f d ts es}
    (_hd : P.defs f = some d)
    (ha : Admissible B [] 0 (TypeCtx.constraints d.tparams) d.neffs
      (Qsig d.params d.ret d.eff) Q ts es d.eff)
    (hs : SignatureInstance P [] [] d.tel (TypeCtx.kinds d.tparams) ts es) :
    ClosedTypeSubstInput P B d.tparams [] [] ts es := by
  refine ⟨?_, ?_, hs.kinds, hs.types, ha.types, ?_, hs.rows, hs.rowKinds, ?_⟩
  · simpa [TypeCtx.kinds] using hs.kinds.1
  · intro t ht; simpa using (hs.types t ht).wf
  · intro e he; simpa using ha.rowScope e he
  · exact ⟨fun i a hi => by simp at hi, fun i a hi => by simp at hi⟩

/-- Tel の次の引数を読むときも元の捕捉文脈の形成を残す。 -/
theorem telescope_input {P B C0 C1 Γ ts es n a t}
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ (.dependentFn (.param n a t))) :
    ClosedTypeSubstInput P B C0 C1 (Γ.extend a) ts es :=
  hi.extend ⟨ha.wf.1, ha.sorted.1, ha.declared.1⟩

/-- 旧入力の同じ kind 文脈から三包装へ渡す行の証拠を取り出す。 -/
theorem legacy_rows {K P0 Δ es} (h : LegacyRowsInput K P0 Δ es) :
    ∀ e ∈ es, kindsEff (embedProgramWithKinds K P0) Δ.kinds (embedEff e) := h.rowKinds

#print axioms function_input
#print axioms telescope_input
#print axioms legacy_rows
end Benitoite.Release.Refinement.A3bConnections
