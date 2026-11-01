import Benitoite.Release.Refinement.TypeSubstFormation
namespace Benitoite.Release.Refinement.A3bPrimitiveR2
noncomputable section

def inner : Ty := .fn [] [] (.base .unit) (Eff.row 0)
def sig : PrimSig := {
  tparams := [], neffs := 0, names := ["f"], params := [inner],
  ret := .base .unit, eff := Eff.empty, admits := fun _ _ => True,
  kind := .pure, opEff := none }

theorem store_shape : sig.StoreShape := trivial

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

#print axioms io_shape

theorem rejected : ¬ PrimitiveAdmissible [] 0 sig Qempty [] [] := by
  intro ha
  exact signature_rows_missing ha.sourceTelRows

def higher : PrimSig := { sig with neffs := 1, eff := Eff.row 0 }

theorem higher_rows : higher.tel.RowsIn (· < 1) := by
  simp [higher,sig,PrimSig.tel,signatureTel,inner,Tel.RowsIn,Ty.RowsIn,
    Ty.RowsInList,Eff.RowsIn,Eff.row,Eff.empty]

theorem higher_admissible : PrimitiveAdmissible [] 0 higher Qempty [] [Eff.row 0] := by
  refine ⟨rfl,trivial,?_,rfl,?_,?_,?_,?_,higher_rows⟩
  · intro t ht; cases ht
  · intro e he; cases List.mem_singleton.mp he; trivial
  · constructor
    · intro i hi; simpa [higher,sig,Eff.row] using hi
    · trivial
  · intro i hi
    simp [higher,sig,Qsig,QTys,QTy,QEff,inner,Eff.row,Eff.empty,Qempty] at hi
  · intro i hi
    simp [higher,sig,Qsig,QTys,QTy,QEff,inner,Eff.row,Eff.empty,Qempty] at hi

theorem higher_signature (P : Program) : SignatureInstance P [] [] higher.tel [] [] [Eff.row 0] := by
  refine ⟨?_, ?_, ⟨rfl, ?_⟩, ?_, ?_, ?_⟩
  · simp [higher,sig, PrimSig.tel, signatureTel, inner, Ty.WF, Tel.WF,
      NamesWF, Ty.WFList, Eff.WF, Eff.row, Eff.empty, Eff.Canonical, Eff.norm]
  · intro t ht; cases ht
  · intro i a k hi; cases hi
  · intro e he; cases List.mem_singleton.mp he
    constructor <;> simp [NamesWF,Ty.WF,Ty.WFList,Eff.WF,Eff.Canonical,Eff.norm,Eff.row,
      Ty.Sorted,sortedTys,sortedEff,Ty.Declared,declaredTys,declaredEff]
  · intro e he; cases List.mem_singleton.mp he
    trivial
  · constructor <;> simp [Eff.fails,Eff.shiftV,shiftVTys,higher,instantiatedTel, Tel.bind, Tel.rawBind, Tel.norm, sig,
      PrimSig.tel, signatureTel, inner, Ty.rawBind, Ty.norm, rawBindTys, Ty.normTys,
      Eff.rawBind, Eff.norm, typeEnvAt, Eff.row, Eff.empty, rowFails,
      substAtoms_nil, instAtoms_nil, Ty.WF, Tel.WF, Ty.WFList, Eff.WF,
      Eff.Canonical, NamesWF, Ty.Sorted, Tel.Sorted, sortedTys, sortedEff,
      Ty.Declared, Tel.Declared, declaredTys, declaredEff]

theorem higher_exchange (c : Nat) (us : List Ty) (fs : List Eff) :
    Tel.substAt c us fs (instantiatedTel higher.tel [] [Eff.row 0]) =
      instantiatedTel higher.tel [] [(Eff.substAt c us fs (Eff.row 0))] := by
  apply instantiatedTel_substAt (nt := 0) _ [] [Eff.row 0] (by omega) higher_rows
  simp [higher,sig,PrimSig.tel,signatureTel,inner,Ty.WF,Tel.WF,
    NamesWF,Ty.WFList,Eff.WF,Eff.row,Eff.empty,Eff.Canonical,Eff.norm]

theorem higher_source {P B Ψ}
    (hb : B.sig "higher" = some higher) (hr : B.RangeAdmissible "higher" higher []) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.prim "higher" [] [Eff.row 0] [])
      (.dependentFn (instantiatedTel (Tel.instR [] higher.tel) [] [Eff.row 0])) := by
  apply HasTypeVQ.V_Prim hb hr (by simp [higher,sig,NamesWF]) higher_admissible
  have hi : Tel.instR [] higher.tel = higher.tel := by
    simp [higher,sig,PrimSig.tel,signatureTel,inner,Tel.instR,Tel.substRAt,Tel.mapRanges,
      Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,mapRangesTys,
      mapRangeAtoms_rangeAt,instAtoms_nil,Tel.norm,Ty.norm,Ty.normTys,Eff.norm,Eff.row]
  rw [hi]
  simpa [higher,sig,TypeCtx.kinds] using higher_signature P

-- V_Prim の実構成子の前提だけを受け、sourceTelRows と count で交換を閉じる。
theorem primitive_branch {P B Ψ Q Q' C Γ Φ b sg ts es rs c us fs D Δ}
    (hb : B.sig b = some sg) (hrr : B.RangeAdmissible b sg rs)
    (hn : NamesWF sg.names sg.params)
    (ha : PrimitiveAdmissible C Γ.length sg Q ts es)
    (hi : SignatureInstance P C Γ (Tel.instR rs sg.tel) (TypeCtx.kinds sg.tparams) ts es)
    (ha' : PrimitiveAdmissible D Δ.length sg Q' (ts.map (Ty.substAt c us fs)) (es.map (Eff.substAt c us fs)))
    (hi' : SignatureInstance P D Δ (Tel.instR rs sg.tel) (TypeCtx.kinds sg.tparams)
      (ts.map (Ty.substAt c us fs)) (es.map (Eff.substAt c us fs))) :
    HasTypeVQ P B Ψ Q' D Δ Φ
      ((Val.prim b ts es rs).substTyAt c us fs)
      ((Ty.dependentFn (instantiatedTel (Tel.instR rs sg.tel) ts es)).substAt c us fs) := by
  have hrows := Tel.rowsIn_instR ha.sourceTelRows rs
  have count : (TypeCtx.kinds sg.tparams).length ≤ ts.length := by
    simp only [TypeCtx.kinds,List.length_map,ha.typeCount]
    exact Nat.le_refl _
  have he := instantiatedTel_substAt hi.source ts es count hrows c us fs
  have hv := HasTypeVQ.V_Prim (Ψ := Ψ) (Φ := Φ) hb hrr hn ha' hi'
  change HasTypeVQ P B Ψ Q' D Δ Φ
    (.prim b (ts.map (Ty.substAt c us fs)) (es.map (Eff.substAt c us fs)) rs)
    (Ty.foldFn (Tel.substAt c us fs (instantiatedTel (Tel.instR rs sg.tel) ts es)))
  rw [he]
  simpa only [Ty.norm,instantiatedTel,Tel.bind,Tel.norm_idem] using hv.V_Normal

#print axioms rejected
#print axioms higher_admissible
#print axioms higher_signature
#print axioms higher_source
#print axioms higher_exchange
#print axioms primitive_branch

end
end Benitoite.Release.Refinement.A3bPrimitiveR2
