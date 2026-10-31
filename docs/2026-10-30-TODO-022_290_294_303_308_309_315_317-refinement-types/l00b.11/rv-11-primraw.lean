import Benitoite.Release.Refinement.BuiltinResponse
import Benitoite.Release.Refinement.Canonical
import Benitoite.Release.Refinement.Capture
namespace Benitoite.Release.Refinement.PrimRaw
noncomputable section
abbrev U : Ty := .base .unit
abbrev raw : Ty := .refined U .truth
def sg : PrimSig :=
  { tparams := [{}], neffs := 0, names := [], params := [], ret := U, eff := Eff.empty,
    admits := fun _ _ => True, kind := .pure, opEff := none }
def B : Builtins :=
  { sig := fun _ => some sg, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
    isResource := fun _ => false, effects := fun _ => none,
    sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def P : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }

theorem raw_annotation : Ty.Annotation P [] [] raw :=
  ⟨⟨trivial,trivial,by simp [Ty.NotContCore,Ty.core]⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩

theorem src_eq : Tel.instR [] sg.tel = .done U Eff.empty := by
  simp [Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.rawMapRanges, PrimSig.tel, sg, signatureTel,
    Tel.norm, Ty.rawMapRanges, Ty.norm, Eff.rawMapRanges, Eff.norm, Eff.empty, Ty.normTys,
    Order.sortUnique, U]
  funext x
  simp [mapRangeAtoms]

theorem tel_eq : instantiatedTel (Tel.instR [] sg.tel) [raw] [] = .done U Eff.empty := by
  rw [src_eq]
  simp [instantiatedTel, Tel.bind, Tel.rawBind, Tel.norm, Ty.rawBind, Ty.norm, U,
      Eff.rawBind, Eff.norm, Eff.empty, typeEnvAt, rowFails, rawBindTys,
      instAtoms_nil, substAtoms_nil, Ty.normTys, Order.sortUnique]

theorem prim_typed (Ψ : StoreTy) :
    HasTypeV P B Ψ [] [] [] (.prim "p" [raw] [] []) (.dependentFn (.done U Eff.empty)) := by
  have h := HasTypeVQ.V_Prim (P := P) (B := B) (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := []) (Φ := [])
    (b := "p") (s := sg) (ts := [raw]) (es := []) (rs := []) rfl ?_ ?_ ?_ ?_
  · rwa [tel_eq] at h
  · exact ⟨rfl, by simp, by simp, Or.inl (by simp)⟩
  · exact ⟨rfl, List.nodup_nil⟩
  · refine ⟨rfl, trivial, ?_, rfl, by simp, ?_, ?_, ?_⟩
    · intro t ht
      simp only [List.mem_singleton] at ht
      subst t
      exact ⟨raw_annotation.wf, by simp [Ordinary, Ty.core]⟩
    · simp [sg, Eff.RowsIn, Eff.empty, Ty.RowsInList]
    · intro i h; exfalso; simpa [Qsig, QTys, QTy, QEff, sg, Eff.empty, U, Qempty] using h
    · intro i h; exfalso; simpa [Qsig, QTys, QTy, QEff, sg, Eff.empty, U, Qempty] using h
  · refine ⟨?_, ?_, ?_, ?_, ?_⟩
    · rw [src_eq]; exact ⟨trivial, trivial, rfl⟩
    · intro t ht; simp only [List.mem_singleton] at ht; subst t; exact raw_annotation
    · refine ⟨rfl, [], rfl, ?_⟩
      intro i a k ha hk
      cases i with
      | zero =>
        simp only [List.getElem?_cons_zero, Option.some.injEq] at ha
        have hk' : k = .value := by simpa [sg] using hk.symm
        subst a; subst k
        simp [Ty.HasKind, Ty.NotContCore, Ty.core]
      | succ i => simp at ha
    · intro e he; cases he
    · rw [tel_eq]; exact ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩

theorem args_rejected (Ψ a e) : ¬ BuiltinArgs P B Ψ "p" sg [raw] [] [] [] a e := by
  intro h
  have := (h.types raw (by simp)).2
  exact absurd this (by intro h; cases h)

theorem view_raw : (Closure.mk (.mk [some (.prim "p" [raw] [] [])]) (.app (.var 0) [])).view =
    .app (.prim "p" [raw] [] []) [] := rfl
end
end Benitoite.Release.Refinement.PrimRaw
#print axioms Benitoite.Release.Refinement.PrimRaw.prim_typed
#print axioms Benitoite.Release.Refinement.PrimRaw.args_rejected
