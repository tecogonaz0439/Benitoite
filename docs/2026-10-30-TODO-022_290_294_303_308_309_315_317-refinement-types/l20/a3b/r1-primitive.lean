import Benitoite.Release.Refinement.TypeSubstFormation
namespace Benitoite.Release.Refinement.A3bPrimitive
noncomputable section

def inner : Ty := .fn [] [] (.base .unit) (Eff.row 0)
def sig : PrimSig := {
  tparams := [], neffs := 0, names := ["f"], params := [inner],
  ret := .base .unit, eff := Eff.empty, admits := fun _ _ => True,
  kind := .pure, opEff := none }

theorem store_shape : sig.StoreShape := trivial

theorem admissible : PrimitiveAdmissible [] 0 sig Qempty [] [] := by
  refine ⟨rfl, trivial, ?_, rfl, ?_, ?_, ?_, ?_⟩
  · intro t ht; cases ht
  · intro e he; cases he
  · simp [sig, Eff.RowsIn, Eff.empty, Ty.RowsInList]
  · intro i hi
    simp [sig, Qsig, QTys, QTy, QEff, inner, Eff.row, Eff.empty, Qempty] at hi
  · intro i hi
    simp [sig, Qsig, QTys, QTy, QEff, inner, Eff.row, Eff.empty, Qempty] at hi

theorem signature_rows_missing : ¬ sig.tel.RowsIn (· < sig.neffs) := by
  intro h
  have hh := h.1.2.2.1 0 (by rfl)
  exact Nat.not_lt_zero 0 (by simpa [sig] using hh)

theorem exchange_false :
    Tel.substAt 0 [] [Eff.empty] (instantiatedTel sig.tel [] []) ≠
      instantiatedTel sig.tel ([] : List Ty) ([] : List Eff) := by
  intro h
  have he := congrArg (fun t : Tel => match t with
    | .param _ (.fn _ _ _ e) _ => Eff.test e (.rho 0)
    | _ => false) h
  simp [Tel.substAt, instantiatedTel, Tel.bind, Tel.rawBind, Tel.norm,
    sig, PrimSig.tel, signatureTel, inner, Ty.rawBind, Ty.norm,
    rawBindTys, Ty.normTys, Eff.rawBind, Eff.norm, typeEnvAt,
    Eff.test, Eff.empty, Eff.row, Eff.atoms, substAtoms, instAtoms,
    rowFails, shiftTypes, shiftRowsTypes, shiftTypesList] at he


theorem signature (P : Program) : SignatureInstance P [] [] sig.tel [] [] [] := by
  refine ⟨?_, ?_, ⟨rfl, ?_⟩, ?_, ?_, ?_⟩
  · simp [sig, PrimSig.tel, signatureTel, inner, Ty.WF, Tel.WF,
      NamesWF, Ty.WFList, Eff.WF, Eff.row, Eff.empty, Eff.Canonical, Eff.norm]
  · intro t ht; cases ht
  · intro i a k hi; cases hi
  · intro e he; cases he
  · intro e he; cases he
  · constructor <;> simp [instantiatedTel, Tel.bind, Tel.rawBind, Tel.norm, sig,
      PrimSig.tel, signatureTel, inner, Ty.rawBind, Ty.norm, rawBindTys, Ty.normTys,
      Eff.rawBind, Eff.norm, typeEnvAt, Eff.row, Eff.empty, rowFails,
      substAtoms_nil, instAtoms_nil, Ty.WF, Tel.WF, Ty.WFList, Eff.WF,
      Eff.Canonical, NamesWF, Ty.Sorted, Tel.Sorted, sortedTys, sortedEff,
      Ty.Declared, Tel.Declared, declaredTys, declaredEff]

theorem primitive_source {P B Ψ} (hb : B.sig "bad" = some sig)
    (hr : B.RangeAdmissible "bad" sig []) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.prim "bad" [] [] [])
      (.dependentFn (instantiatedTel (Tel.instR [] sig.tel) [] [])) := by
  apply HasTypeVQ.V_Prim hb hr (by simp [sig, NamesWF]) admissible
  have hi : Tel.instR [] sig.tel = sig.tel := by
    simp [sig, PrimSig.tel, signatureTel, inner, Tel.instR, Tel.substRAt, Tel.mapRanges,
      Tel.rawMapRanges, Ty.rawMapRanges, Eff.rawMapRanges, mapRangesTys,
      mapRangeAtoms_rangeAt, instAtoms_nil, Tel.norm, Ty.norm, Ty.normTys,
      Eff.norm, Eff.row, Eff.empty]
  rw [hi]
  simpa [sig, TypeCtx.kinds] using signature P

theorem source_guard : TypeSubstCode [Eff.empty]
    (fun nr nt ne nv => (Val.prim "bad" [] [] []).SourceScoped nr nt ne nv) := by
  exact Or.inr ⟨0, 0, 0, 0, by simp [Val.SourceScoped, scopedTypes, scopedRows]⟩

-- IO の ShapeOk も関数型の引数にある自由な行を読まない。
def ioSig : PrimSig := { sig with kind := .io, opEff := some "IO", eff := Eff.single "IO" }

theorem io_shape (B : Builtins) (he : B.effects "IO" = some ["bad"])
    (hk : B.effKind "IO" = none) : B.ShapeOk "bad" ioSig :=
  ⟨"IO", ["bad"], rfl, rfl, he, by simp, hk, rfl, rfl⟩

theorem io_store_shape : ioSig.StoreShape := trivial

theorem io_signature_rows_missing : ¬ ioSig.tel.RowsIn (· < ioSig.neffs) := by
  intro h
  have hh := h.1.2.2.1 0 (by rfl)
  exact Nat.not_lt_zero 0 (by simpa [ioSig, sig] using hh)

#print axioms exchange_false
#print axioms primitive_source
#print axioms io_shape

end
end Benitoite.Release.Refinement.A3bPrimitive
