import Benitoite.Release.Refinement.ContextTransport
import Benitoite.Release.Refinement.DependentBeta

/-! # 捕捉した継続の正規化（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement
noncomputable section

def normContTy : Ty → Ty
  | .cont b t e => .cont b.norm t.norm (Eff.norm e)
  | a => a

def normConts (Γ : Ctx) : Ctx := Γ.map (Option.map normContTy)

theorem normContTy_norm (a : Ty) : (normContTy a).norm = a.norm := by
  cases a <;> try rfl
  case cont => simp [normContTy,Ty.norm,Ty.norm_idem,Eff.norm_idem]

theorem normConts_normEq (Γ : Ctx) : Γ.NormEq (normConts Γ) := by
  simp only [Ctx.NormEq,normConts,List.map_map,Option.map_map,Function.comp_def,normContTy_norm]

theorem normConts_typeMap (Γ : Ctx) : Ctx.TypeMap Γ (normConts Γ) := by
  apply Ctx.TypeMap.of_map
  · intro a s h; cases a <;> exact h
  · intro a h; cases a <;> try exact h
    exact (Ty.ordinary_norm _).mpr h
  · intro a p h; cases a <;> exact h

theorem normConts_lookup {Γ : Ctx} {i : Nat} {a : Ty} (hi : (normConts Γ)[i]? = some (some a)) :
    ∃ b, Γ[i]? = some (some b) ∧ normContTy b = a := by
  simp only [normConts,List.getElem?_map] at hi
  cases hg : Γ[i]? with
  | none => simp [hg] at hi
  | some ob => cases ob with
    | none => simp [hg] at hi
    | some b => exact ⟨b,rfl,by simpa [hg] using hi⟩

theorem normContTy_subst (a : Ty) (ν : Nat → Val) :
    substTyValues ν (normContTy a) = substTyValues ν a := by
  cases a <;> try rfl
  case cont b t e => exact substTyValues_norm_source (.cont b t e) ν

theorem builderBody_image_norm {P B Ψ Q C Γ Φ R ν i a}
    (h : ImageOk P B Ψ Q C Γ Φ R ν i a) :
    ImageOk P B Ψ Q C Γ Φ R ν i (normContTy a) := by
  cases h with
  | ordinary ho hv =>
    have ha : normContTy a = a := by
      cases a <;> try rfl
      exact False.elim (ho _ _ _ rfl)
    rw [ha]
    exact .ordinary ho hv
  | hidden ho hc =>
    have ha : normContTy a = a := by
      cases a <;> try rfl
      exact False.elim (hc _ _ _ rfl)
    rw [ha]
    exact .hidden ho hc
  | contLoc hs hc hw hv hl hr =>
    subst a
    refine .contLoc rfl ?_ ?_ hv hl hr
    · rw [normContTy_subst]; exact hc
    · rw [normContTy_subst]; exact hw
  | contVar hs hv hj =>
    subst a
    obtain ⟨b',t',e',hj,heq⟩ := hj
    refine .contVar rfl hv ⟨b',t',e',hj,?_⟩
    rw [normContTy_subst]
    exact heq

theorem Ty.CaptureWF.normContTy {nr nt nv a} (h : Ty.CaptureWF nr nt nv a) :
    (normContTy a).CaptureWF nr nt nv := by
  cases a <;> try exact h
  exact ⟨Ty.wf_norm h.1,Ty.wf_norm h.2⟩

theorem Ty.CaptureSorted.normContTy {Γ a} (h : Ty.CaptureSorted Γ a) :
    (normContTy a).CaptureSorted (normConts Γ) := by
  cases a <;> try exact Ty.Sorted.context h (normConts_typeMap Γ)
  exact ⟨(Ty.sorted_norm h.1).context (normConts_typeMap Γ),
    (Ty.sorted_norm h.2).context (normConts_typeMap Γ)⟩

theorem Ty.CaptureDeclared.normContTy {P C Γ a} {B : Builtins}
    (h : Ty.CaptureDeclared P C Γ a) :
    (normContTy a).CaptureDeclared P C (normConts Γ) := by
  have hd := (normConts_normEq Γ).declaration (P := P) (C := C) (B := B)
  cases a <;> try exact Ty.Declared.context h hd
  exact ⟨h.1.norm.context hd,h.2.norm.context hd⟩

theorem CaptureContextRegular.normConts {P C Γ} {B : Builtins}
    (h : CaptureContextRegular P C Γ) : CaptureContextRegular P C (normConts Γ) := by
  constructor
  · intro i a hi
    obtain ⟨b,hb,rfl⟩ := normConts_lookup hi
    simpa [Refinement.normConts] using (h.1 i b hb).normContTy
  · intro i a hi
    obtain ⟨b,hb,rfl⟩ := normConts_lookup hi
    exact ⟨(h.2 i b hb).1.normContTy,(h.2 i b hb).2.normContTy (B := B)⟩

theorem CaptureOk.normConts {P B Ψ R Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) :
    CaptureOk P B Ψ R (normConts Γ) Φ cap := by
  have he := normConts_normEq Γ
  have hm := normConts_typeMap Γ
  have hd := he.declaration (P := P) (B := B) (C := [])
  cases h with
  | mk hw hn hv hs hf hg himg hfacts =>
    refine .mk ?_ (by simpa [Refinement.normConts] using hn) ?_ ?_ ?_ hg ?_ ?_
    · intro i a hi
      obtain ⟨b,hb,rfl⟩ := normConts_lookup hi
      simpa [Refinement.normConts] using (hw i b hb).normContTy
    · intro i a hi
      obtain ⟨b,hb,rfl⟩ := normConts_lookup hi
      exact hv i b hb
    · intro i a hi
      obtain ⟨b,hb,rfl⟩ := normConts_lookup hi
      exact ⟨(hs i b hb).1.normContTy,(hs i b hb).2.normContTy (B := B)⟩
    · intro p hp
      obtain ⟨hw,hs,hdp⟩ := hf p hp
      have hh := (Pred.WellFormed.mk hw hs hdp).map hm.values hm.references hd
      simpa only [renEnv_values,id_eq,predBind_id] using And.intro hh.wf (And.intro hh.sorted hh.declared)
    · intro i a hi
      obtain ⟨b,hb,rfl⟩ := normConts_lookup hi
      exact builderBody_image_norm (himg i b hb)
    · intro p hp
      rw [←he.facts] at hp
      exact hfacts p hp

theorem capture_normConts_value_annotation {P B Ψ R Γ Φ cap v a}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hv : HasTypeVQ P B Ψ Qempty [] (normConts Γ) Φ v a) :
    Ty.Annotation P [] [] (cap.closeTy a) :=
  capture_value_annotation hw hs hd hc.normConts hv

theorem capture_normConts_comp_annotation {P B Ψ R Γ Φ cap Rs m a e L}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hm : HasTypeCQ P B Ψ Qempty [] (normConts Γ) Φ Rs m a e L) :
    Ty.Annotation P [] [] (cap.closeTy a) :=
  capture_comp_annotation hw hs hd hc.normConts hm


theorem CaptureOk.hideBuilders_hideConts {P B Ψ R R' Γ Φ cap}
    (h : CaptureOk P B Ψ R Γ Φ cap) (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) :
    CaptureOk P B (hideBuilders Ψ) R' (hideConts Γ) Φ cap :=
  h.hideConts_any.store hA hw (StoreTy.preserves_hide Ψ)

theorem normConts_cont {Γ : Ctx} {i : Nat} {b t : Ty} {e : Eff}
    (hi : Γ[i]? = some (some (Ty.cont b t e))) :
    ∃ b' t' e', (normConts Γ)[i]? = some (some (Ty.cont b' t' e')) :=
  ⟨b.norm,t.norm,Eff.norm e,by simp [normConts,hi,normContTy]⟩

theorem HasTypeCQ.normConts {P B Ψ Q C Γ Φ R m a e L}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L)
    (hA : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF) :
    HasTypeCQ P B Ψ Q C (Refinement.normConts Γ) Φ (R.map Ty.norm)
      (m.subst Val.var LocalRef.bound) a.norm (Eff.norm e)
      (L.map (Option.map BuilderKind.norm)) :=
  (normConts_normEq Γ).comp (fun _ _ _ _ hi => normConts_cont hi) hA hw h

theorem HasTypeVQ.normConts {P B Ψ Q C Γ Φ v a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a)
    (hA : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF) :
    HasTypeVQ P B Ψ Q C (Refinement.normConts Γ) Φ (v.subst Val.var LocalRef.bound) a.norm := by
  have he := normConts_normEq Γ
  have hm := he.substOk (P := P) (B := B) (Ψ := Ψ) (Q := Q) (C := C) (Φ := Φ) (R := none)
    (fun _ _ _ _ hi => normConts_cont hi)
  simpa only [substTyValues_var] using h.subst hA hw hm
    (fun p hp => by simpa only [valEnv,Val.toTerm?,predBind_id] using
      (Entails.hyp (List.mem_append_right (Refinement.normConts Γ).facts hp))) LocalRef.bound

theorem capture_value_annotation_via_normConts {P B Ψ R Γ Φ cap v a}
    (hA : Builtins.SubstitutionAssumptions P B)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hv : HasTypeVQ P B Ψ Qempty [] Γ Φ v a) :
    Ty.Annotation P [] [] (cap.closeTy a.norm) :=
  capture_normConts_value_annotation hw hs hd hc (hv.normConts hA hw)

theorem capture_comp_annotation_via_normConts {P B Ψ R Γ Φ cap Rs m a e L}
    (hA : Builtins.SubstitutionAssumptions P B)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hm : HasTypeCQ P B Ψ Qempty [] Γ Φ Rs m a e L) :
    Ty.Annotation P [] [] (cap.closeTy a.norm) :=
  capture_normConts_comp_annotation hw hs hd hc (hm.normConts hA hw)

end
end Benitoite.Release.Refinement
