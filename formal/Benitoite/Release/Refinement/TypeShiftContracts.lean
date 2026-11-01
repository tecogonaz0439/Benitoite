import Benitoite.Release.Refinement.TypeShiftKinds
import Benitoite.Release.Refinement.ConstraintAssumptions
import Benitoite.Release.Refinement.AdmissibleMap
import Benitoite.Release.Refinement.NormalizedApplication

namespace Benitoite.Release.Refinement

variable {P : Program}

theorem Ty.shiftTypes_of_wf_zero {nr nv a} (hw : Ty.WF nr 0 nv a) (k c : Nat) :
    shiftTypes k c a = a := by
  have hh := Ty.rawBind_agrees (θ := .shiftTypes k c) (τ := renEnv id) hw
    ⟨fun i hi => (Nat.not_lt_zero i hi).elim,rfl,rfl,rfl⟩
  simpa only [Ty.rawBind_shiftTypes,Ty.rawBind_id] using hh

theorem Eff.shiftTypes_of_wf_zero {nr nv e} (hw : Eff.WF nr 0 nv e) (k c : Nat) :
    shiftRowsTypes k c e = e := by
  cases e with
  | mk ats fs =>
    simp only [shiftRowsTypes,shiftTypesList_eq_map]
    congr 1
    exact (List.map_congr_left (fun a hm => Ty.shiftTypes_of_wf_zero (Ty.wfList_iff.mp hw a hm) k c)).trans (List.map_id _)

theorem Ty.renameTypes_shift_of_wf {nr nt nv a} (_hw : Ty.WF nr nt nv a) (k c : Nat) :
    a.renameTypes (shiftIndex k c) = (shiftTypes k c a).norm := by
  simp only [Ty.renameTypes, Ty.rawRenameTypes_shift]

theorem Builtins.TypeAssumptions.sat_shiftTypes_raw {P B C C' Γ Δ a p k c}
    (h : Builtins.TypeAssumptions P B) (hr : TypeParamRenaming C C' (shiftIndex k c))
    (ha : Ty.Annotation P C Γ a) (hb : Ty.Annotation P C' Δ (shiftTypes k c a))
    (hs : B.sat (TypeCtx.constraints C) a.norm p) : B.sat (TypeCtx.constraints C') (shiftTypes k c a).norm p := by
  have he : a.norm.renameTypes (shiftIndex k c) = (shiftTypes k c a).norm := by
    simp only [Ty.renameTypes, Ty.rawRenameTypes_shift, Ty.norm_shiftTypes, Ty.norm_idem]
  simpa only [he] using h.sat_renameTypes C C' Γ Δ a.norm p _ hr ha.norm
    (by simpa only [he] using hb.norm) hs

theorem Builtins.TypeAssumptions.admits_shiftTypes_raw {P B C C' Γ Δ ts b sg k c}
    (h : Builtins.TypeAssumptions P B) (hr : TypeParamRenaming C C' (shiftIndex k c))
    (hl : B.sig b=some sg) (ha : TypeAnnotations P C Γ ts)
    (hb : TypeAnnotations P C' Δ (ts.map (shiftTypes k c)))
    (hs : sg.admits (TypeCtx.constraints C) (Ty.normTys ts)) : sg.admits (TypeCtx.constraints C') (Ty.normTys (ts.map (shiftTypes k c))) := by
  have he : (Ty.normTys ts).map (fun a => a.renameTypes (shiftIndex k c)) =
      Ty.normTys (ts.map (shiftTypes k c)) := by
    simp only [Ty.normTys_eq_map, List.map_map, Function.comp_def]
    apply List.map_congr_left
    intro a ha
    simp only [Ty.renameTypes, Ty.rawRenameTypes_shift, Ty.norm_shiftTypes, Ty.norm_idem]
  have hna : TypeAnnotations P C Γ (Ty.normTys ts) := by
    intro a hm; obtain ⟨x, hx, rfl⟩ := List.mem_map.mp (by simpa only [Ty.normTys_eq_map] using hm)
    exact (ha x hx).norm
  have hnb : TypeAnnotations P C' Δ (Ty.normTys (ts.map (shiftTypes k c))) := by
    intro a hm; obtain ⟨x, hx, rfl⟩ := List.mem_map.mp (by simpa only [Ty.normTys_eq_map] using hm)
    exact (hb x hx).norm
  simpa only [he] using h.admits_renameTypes b sg C C' Γ Δ (Ty.normTys ts) _ hl hr hna
    (by simpa only [he] using hnb) hs

theorem TypeCtxMap.annotations {P C C' Γ Δ ts k c} (h : TypeCtxMap k c Γ Δ)
    (hn : C'.length=C.length+k) (ha : TypeAnnotations P C Γ ts) (hC : TypeParamRenaming C C' (shiftIndex k c)) :
    TypeAnnotations P C' Δ (ts.map (shiftTypes k c)) := by
  intro a ha'
  obtain ⟨b,hb,rfl⟩ := List.mem_map.mp ha'
  exact (h.annotation hn (ha b hb) hC)

theorem TypeCtxMap.rows {P C C' Γ Δ es k c} (h : TypeCtxMap k c Γ Δ)
    (hn : C'.length=C.length+k) (ha : RowAnnotations P C Γ es) (hC : TypeParamRenaming C C' (shiftIndex k c)) :
    RowAnnotations P C' Δ (es.map (shiftRowsTypes k c)) := by
  intro e he
  obtain ⟨f,hf,rfl⟩ := List.mem_map.mp he
  simpa only [shiftTypes,shiftTypesList] using (h.annotation hn (ha f hf) hC)

theorem SatAll.shiftTypes {P B C C' Γ Δ ts tps k c} (h : SatAll B C ts tps)
    (hA : Builtins.TypeAssumptions P B) (hr : TypeParamRenaming C C' (shiftIndex k c))
    (hm : TypeCtxMap k c Γ Δ) (hn : C'.length=C.length+k) (ha : TypeAnnotations P C Γ ts) :
    SatAll B C' (ts.map (shiftTypes k c)) tps := by
  refine ⟨by simpa using h.1,?_⟩
  intro i a p hi hp
  obtain ⟨b,hb,rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [List.getElem?_map] using hi)
  exact hA.sat_shiftTypes_raw hr (ha b (List.mem_of_getElem? hb))
    ((hm.annotation hn (ha b (List.mem_of_getElem? hb)) hr)) (h.2 i b p hb hp)

theorem instantiatedTel_shiftTypes {nt t} (hw : (Ty.dependentFn t).WF 0 nt 0)
    (ts : List Ty) (es : List Eff) (hn : nt≤ts.length) (k c : Nat) :
    shiftTelTypes k c (instantiatedTel t ts es)=
      instantiatedTel t (ts.map (shiftTypes k c)) (es.map (shiftRowsTypes k c)) := by
  apply Ty.foldFn_injective
  have hh := Ty.subst_shiftTypes hw ts es hn k c
  simpa only [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm,
    instantiatedTel, Tel.bind, Ty.foldFn_shiftTypes] using hh

theorem TypeCtxMap.signature {P C C' Γ Δ t ks ts es k c} (h : TypeCtxMap k c Γ Δ)
    (hn : C'.length=C.length+k) (ha : SignatureInstance P C Γ t ks ts es) (hC : TypeParamRenaming C C' (shiftIndex k c)) :
    SignatureInstance P C' Δ t ks (ts.map (shiftTypes k c)) (es.map (shiftRowsTypes k c)) := by
  refine ⟨ha.source,(h.annotations hn ha.types hC),ha.kinds.shiftTypes hC,(h.rows hn ha.rows hC),?_,?_⟩
  · intro e he
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
    rw [← rawRenameRowsTypes_shift]
    exact kindsEff_renameTypes (ha.rowKinds f hf) hC.kindRenaming
  · have hh := (h.annotation hn ha.result hC)
    have he := instantiatedTel_shiftTypes ha.source ts es (by have hk := ha.kinds.1; omega) k c
    simpa only [shiftTypes, he] using hh

theorem NoFail.shiftTypes {Q e} (h : NoFail Q e) (k c : Nat) : NoFail Q (shiftRowsTypes k c e) := by
  cases e with
  | mk ats fs => obtain ⟨rfl,ha⟩ := h; exact ⟨rfl,ha⟩

theorem TypeCtxMap.admissible {P B C C' Γ Δ tps ne Qs Qt ts es e k c}
    (h : TypeCtxMap k c Γ Δ) (hn : C'.length=C.length+k)
    (hA : Builtins.TypeAssumptions P B) (hr : TypeParamRenaming C C' (shiftIndex k c))
    (ht : TypeAnnotations P C Γ ts) (he : RowAnnotations P C Γ es)
    (ha : Admissible B C Γ.length tps ne Qs Qt ts es e) :
    Admissible B C' Δ.length tps ne Qs Qt (ts.map (shiftTypes k c)) (es.map (shiftRowsTypes k c)) e := by
  refine ⟨ha.types.shiftTypes hA hr h hn ht,?_,by simpa using ha.rowCount,?_,(by simpa only [List.length_map] using ha.sourceRows),(by simpa only [List.length_map] using ha.sourceQ),?_⟩
  · intro a hm
    obtain ⟨b,hb,rfl⟩ := List.mem_map.mp hm
    exact ⟨((h.annotation hn (ht b hb) hr)).wf,(Ty.ordinary_shiftTypes _ _ _).mpr (ha.typeScope b hb).2⟩
  · intro f hf
    obtain ⟨g,hg,rfl⟩ := List.mem_map.mp hf
    exact ((h.annotation hn (he g hg) hr)).wf.2.2.2.1
  · exact ha.noFailRows.map _ (fun _ hf => hf.shiftTypes k c) (fun _ => rfl)

theorem TypeCtxMap.primitive {P B C C' Γ Δ b sg Q ts es k c}
    (h : TypeCtxMap k c Γ Δ) (hn : C'.length=C.length+k)
    (hA : Builtins.TypeAssumptions P B) (hr : TypeParamRenaming C C' (shiftIndex k c))
    (hb : B.sig b=some sg) (ht : TypeAnnotations P C Γ ts) (he : RowAnnotations P C Γ es)
    (ha : PrimitiveAdmissible C Γ.length sg Q ts es) :
    PrimitiveAdmissible C' Δ.length sg Q (ts.map (shiftTypes k c)) (es.map (shiftRowsTypes k c)) := by
  refine ⟨by simpa using ha.typeCount,hA.admits_shiftTypes_raw hr hb ht ((h.annotations hn ht hr)) ha.admits,
    ?_,by simpa using ha.rowCount,?_,(by simpa only [List.length_map] using ha.sourceRows),(by simpa only [List.length_map] using ha.sourceQ),?_,(by simpa only [List.length_map] using ha.sourceTelRows)⟩
  · intro a hm
    obtain ⟨b,hb,rfl⟩ := List.mem_map.mp hm
    exact ⟨((h.annotation hn (ht b hb) hr)).wf,(Ty.ordinary_shiftTypes _ _ _).mpr (ha.typeScope b hb).2⟩
  · intro f hf
    obtain ⟨g,hg,rfl⟩ := List.mem_map.mp hf
    exact ((h.annotation hn (he g hg) hr)).wf.2.2.2.1
  · exact ha.noFailRows.map _ (fun _ hf => hf.shiftTypes k c) (fun _ => rfl)

theorem TypeCtxMap.params {k c Γ Δ} (h : TypeCtxMap k c Γ Δ) (ps : List Ty) :
    TypeCtxMap k c (bindParams Γ ps) (bindParams Δ (ps.map (shiftTypes k c))) := by
  constructor
  · simp only [bindParams,List.length_append,List.length_map,List.length_reverse,h.length]
  · intro i a hi
    by_cases hil : i<ps.length
    · rw [bindParams,List.getElem?_append_left (by simpa using hil)] at hi ⊢
      simp only [List.length_map,←List.map_reverse,List.getElem?_map] at hi ⊢
      cases hp : ps.reverse[i]? with
      | none => simp [hp] at hi
      | some b =>
        simp only [hp,Option.map_some,Option.some.injEq] at hi
        cases hi
        simp only [Option.map_some,shiftTypes_shiftV]
    · rw [bindParams,List.getElem?_append_right (by simpa using Nat.le_of_not_gt hil)] at hi ⊢
      simp only [List.length_map,List.length_reverse,List.getElem?_map] at hi ⊢
      cases hg : Γ[i-ps.length]? with
      | none => simp [hg] at hi
      | some b => cases b with
        | none => simp [hg] at hi
        | some b =>
          simp only [hg,Option.map_some,Option.some.injEq] at hi
          cases hi
          rw [h.lookup _ _ hg]
          simp only [Option.map_some,shiftTypes_shiftV]

theorem TypeCtxMap.none {k c Γ Δ} (h : TypeCtxMap k c Γ Δ) :
    TypeCtxMap k c Γ.extendNone Δ.extendNone := by
  constructor
  · simp [Ctx.extendNone,h.length]
  · intro i a hi
    cases i with
    | zero => simp [Ctx.extendNone] at hi
    | succ i =>
      simp only [Ctx.extendNone,List.getElem?_cons_succ,List.getElem?_map] at hi ⊢
      cases hg : Γ[i]? with
      | none => simp [hg] at hi
      | some b => cases b with
        | none => simp [hg] at hi
        | some b =>
          simp only [hg,Option.map_some,Option.some.injEq] at hi
          cases hi
          rw [h.lookup _ _ hg]
          simp only [Option.map_some,shiftTypes_shiftV]

private theorem type_hide_lookup {Γ : Ctx} {i : Nat} {a : Ty} :
    (hideConts Γ)[i]?=some (some a) ↔ Γ[i]?=some (some a) ∧ a.Ordinary := by
  simp only [hideConts,List.getElem?_map]
  cases hi : Γ[i]? with
  | none => simp
  | some x => cases x with
    | none => simp
    | some t =>
      cases hc : t.core <;> simp [hc, Ty.Ordinary, Ordinary] <;> rintro rfl <;> simp [hc]

theorem TypeCtxMap.hide {k c Γ Δ} (h : TypeCtxMap k c Γ Δ) :
    TypeCtxMap k c (hideConts Γ) (hideConts Δ) := by
  constructor
  · simpa only [hideConts,List.length_map] using h.length
  · intro i a hi
    obtain ⟨hi,ho⟩ := type_hide_lookup.mp hi
    exact type_hide_lookup.mpr ⟨h.lookup _ _ hi,(Ty.ordinary_shiftTypes _ _ _).mpr ho⟩

theorem TypeCtxMap.many {k c Γ Δ} (h : TypeCtxMap k c Γ Δ) (ps : List Ty) :
    TypeCtxMap k c (Γ.extendMany ps) (Δ.extendMany (ps.map (shiftTypes k c))) := by
  induction ps generalizing Γ Δ with
  | nil => exact h
  | cons a as ih => exact ih (h.extend a)

theorem Ty.assume_shiftTypes (a : Ty) (k c : Nat) :
    (shiftTypes k c a).assume=a.assume := by
  unfold Ty.assume
  rw [Ty.core_shiftTypes, Ty.predicates_shiftTypes]
  cases hc : a.core <;> rfl

theorem TypeCtxMap.facts {k c Γ Δ} (h : TypeCtxMap k c Γ Δ) {p} (hp : p∈Γ.facts) : p∈Δ.facts := by
  obtain ⟨i,a,q,hi,hq,rfl⟩ := Ctx.mem_facts.mp hp
  exact Ctx.mem_facts.mpr ⟨i,shiftTypes k c a,q,h.lookup _ _ hi,by rwa [Ty.assume_shiftTypes],rfl⟩

theorem TypeCtxMap.transport {k c Γ Δ Φ} (h : TypeCtxMap k c Γ Δ) :
    Transport (.shiftTypes k c) Γ Φ Δ Φ := by
  refine ⟨h.images,h.references,?_,?_⟩
  · intro i; simp [SubstEnv.shiftTypes,Ordinary]
  · intro p hp
    rw [show (SubstEnv.shiftTypes k c).values=(fun i => some (.var i)) from rfl,predBind_id]
    rcases List.mem_append.mp hp with hp|hp
    · exact .hyp (List.mem_append_left _ (h.facts hp))
    · exact .hyp (List.mem_append_right _ hp)

theorem Ty.LeQ.shiftTypes {Γ Δ Φ a b k c} (h : Ty.LeQ P Γ Φ a b) (hm : TypeCtxMap k c Γ Δ) :
    Ty.LeQ P Δ Φ (shiftTypes k c a) (shiftTypes k c b) := by
  simpa only [Ty.rawBind_shiftTypes] using h.rawBind (.shiftTypes k c) hm.transport

theorem Eff.Covers.shiftTypes {Γ Φ Δ Ξ e f} (h : Eff.Covers Γ Φ e f) (k c : Nat) :
    Eff.Covers Δ Ξ (shiftRowsTypes k c e) (shiftRowsTypes k c f) := by
  have hh := h.bind (Δ := Δ) (Ψ := Ξ) (.shiftTypes k c)
  simp only [Eff.bind,Eff.rawBind_shiftTypes] at hh
  exact Eff.covers_norm_right.mp (Eff.covers_norm_left.mp hh)

theorem Eff.Sub.shiftTypes {e f} (h : Eff.Sub e f) (k c : Nat) :
    Eff.Sub (shiftRowsTypes k c e) (shiftRowsTypes k c f) := by
  have hh := h.bind (.shiftTypes k c)
  simp only [Eff.bind,Eff.rawBind_shiftTypes] at hh
  exact Eff.sub_norm_right.mp (Eff.sub_norm_left.mp hh)


theorem SignatureInstance.shiftTel {P C Γ t ks ts es} (hi : SignatureInstance P C Γ t ks ts es)
    (k c : Nat) : shiftTelTypes k c (instantiatedTel t ts es)=
      instantiatedTel t (ts.map (shiftTypes k c)) (es.map (shiftRowsTypes k c)) := by
  have hk := hi.kinds.1
  exact instantiatedTel_shiftTypes hi.source ts es (by omega) k c

theorem ExternalCallAdmissible.shiftTypes {P B C C' d ts} (h : ExternalCallAdmissible P B C d ts)
    (hw : d.WF P) (k c : Nat) : ExternalCallAdmissible P B C' d (ts.map (shiftTypes k c)) := by
  rw [h.types_nil hw] at *
  refine ⟨h.count,⟨h.kinds.1,?_⟩,⟨h.constraints.1,?_⟩,?_⟩
  · intro i a ki hi; simp at hi
  · intro i a p hi; simp at hi
  · intro a ha; simp at ha

theorem TypeCtxMap.entails {k c Γ Δ Φ p} (h : TypeCtxMap k c Γ Δ)
    (hp : Entails (Γ.facts++Φ) p) : Entails (Δ.facts++Φ) p :=
  hp.weaken (fun _ hq => by
    rcases List.mem_append.mp hq with hq|hq
    · exact List.mem_append_left _ (h.facts hq)
    · exact List.mem_append_right _ hq)

def LocalCtx.shiftEAt (L : LocalCtx) (k c : Nat) : LocalCtx := L.map (Option.map (shiftKindE k c))

theorem LocalCtx.shiftEAt_extend (L : LocalCtx) (x : Option BuilderKind) (k c : Nat) :
    (LocalCtx.extend x L).shiftEAt k c=
      LocalCtx.extend (x.map (shiftKindE k c)) (L.shiftEAt k c) := by
  have hk : ∀ b, shiftKindE k c (renameKind (shiftIndex 1 0) b)=
      renameKind (shiftIndex 1 0) (shiftKindE k c b) := by
    intro b
    cases b <;> simp only [shiftKindE,renameKind,←Ty.shiftV_eq_renameTy,shiftTypes_shiftV]
  simp only [LocalCtx.extend,LocalCtx.shiftEAt,List.map_cons,List.map_map,Option.map_map,Function.comp_def,hk]

theorem LocalCtx.shiftEAt_localExtend (L : LocalCtx) (n k c : Nat) :
    (localExtend n L).shiftEAt k c=localExtend n (L.shiftEAt k c) := by
  induction n with
  | zero => rfl
  | succ n ih => simpa only [localExtend,LocalCtx.shiftEAt_extend,Option.map_none] using congrArg (LocalCtx.extend none) ih

theorem LocalRef.HasKind.shiftTypes {Ψ L r b} (h : LocalRef.HasKind Ψ L r b) (hw : Ψ.WF) (k c : Nat) :
    LocalRef.HasKind Ψ (L.shiftEAt k c) r (shiftKindE k c b) := by
  induction h with
  | bound hi => exact .bound (by simp [LocalCtx.shiftEAt,List.getElem?_map,hi])
  | @loc l b hi =>
    have hh : shiftKindE k c b=b := by
      cases b with
      | string | bytes => rfl
      | list a => exact congrArg BuilderKind.list (Ty.shiftTypes_of_wf_zero (hw _ _ hi) k c)
    rw [hh]; exact .loc hi
  | @normal r b _ ih =>
    have he : shiftKindE k c b.norm = (shiftKindE k c b).norm := by
      cases b <;> simp only [shiftKindE, BuilderKind.norm, Ty.norm_shiftTypes]
    rw [he]
    exact ih.normal

end Benitoite.Release.Refinement
