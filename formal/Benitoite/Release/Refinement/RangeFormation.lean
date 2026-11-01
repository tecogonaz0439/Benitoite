import Benitoite.Release.Refinement.TypeVariables
import Benitoite.Release.Refinement.PrimitiveScoped
import Benitoite.Release.Refinement.Context.Declarations

/-! # 四名前空間の上限と同時置換（設計書 01-12「コア計算と脱糖」） -/
namespace Benitoite.Release.Refinement

theorem RangeIx.wf_inst {nr : Nat} {ix : RangeIx} {rs : List RangeExpr}
    (h : ix.WF nr) (hn : rs.length = nr) : (ix.inst rs).WF 0 := by
  cases ix with
  | fixed r => trivial
  | rvar i =>
    have hi : i < rs.length := by simpa only [hn, RangeIx.WF] using h
    simp only [RangeIx.inst, List.getElem?_eq_getElem hi, RangeIx.WF]

theorem Ty.SourceScoped.bind {nr nt ne nv mr mt me mv : Nat} {a : Ty} {θ : SubstEnv}
    (h : a.SourceScoped nr nt ne nv) (hw : θ.WFImages nr nt nv mr mt mv)
    (he : SupportTransport (rowCondition (· < ne)) (rowCondition (· < me)) θ)
    (hr : SupportTransport (rangeCondition nr) (rangeCondition mr) θ) :
    (a.bind θ).SourceScoped mr mt me mv := by
  have wf := a.bind_wf h.1 hw
  exact ⟨wf,
    (Ty.rowsIn_iff_support _ _).mpr
      (Ty.norm_support _ (Ty.rawBind_support _ _ θ a
        ((Ty.rowsIn_iff_support _ _).mp h.2.1) he)),
    (Ty.rangesScoped_iff_support _ wf).mpr
      (Ty.norm_support _ (Ty.rawBind_support _ _ θ a
        ((Ty.rangesScoped_iff_support _ h.1).mp h.2.2) hr))⟩

noncomputable section

mutual
  private theorem obs_ranges (a : Ty) (ρ : Nat → RangeIx) :
      (a.rawMapRanges ρ).observationType = a.observationType := by
    cases a <;> simp only [Ty.rawMapRanges, Ty.observationType]
    all_goals first | rfl | exact obs_ranges _ ρ | rw [obs_ranges_tys]
  private theorem obs_ranges_tys (as : List Ty) (ρ : Nat → RangeIx) :
      observationTypes (mapRangesTys ρ as) = observationTypes as := by
    cases as <;> simp only [mapRangesTys, observationTypes, obs_ranges, obs_ranges_tys]
end

private theorem data_core_ranges {a : Ty} {d ts} (h : a.norm.core = .data d ts)
    (ρ : Nat → RangeIx) :
    (a.rawMapRanges ρ).norm.core = .data d (Ty.normTys (mapRangesTys ρ ts)) := by
  have hh := congrArg (fun t => (t.rawMapRanges ρ).norm) h
  simp only [Ty.core_norm, Ty.norm_rawMapRanges] at hh
  rw [Ty.core_norm, Ty.core_rawMapRanges, hh]
  rfl

private theorem data_ranges {P Γ t d ts} (h : Term.HasData P Γ t d ts)
    (ρ : Nat → RangeIx) : Term.HasData P (Γ.rawMapRanges ρ) t d ts := by
  match h with
  | .widen hr hs => exact .widen (data_ranges hr ρ) hs
  | .var (i := i) (a := a) hi hd =>
    have hl : (Γ.rawMapRanges ρ)[i]? = some (some (a.rawMapRanges ρ)) := by
      simp only [Ctx.rawMapRanges, List.getElem?_map, hi, Option.map_some]
    refine .widen (.var hl (data_core_ranges hd ρ)) ?_
    change TypeArgsLe P [] [] _ _ _
    rw [observationTypes_norm, obs_ranges_tys]
    simpa only [DataObservationLe, Ty.normTys_eq_map, mapRangesTys_eq_map, List.length_map] using
      DataObservationLe.refl P d ts
  | .value hc hd hn hl => exact .value hc hd hn hl
  | .field hr hc hd hn ha hw hs hv => exact .field (data_ranges hr ρ) hc hd hn ha hw hs hv

private theorem field_ranges {P C Γ t ref} (h : FieldRef.Declared P C Γ t ref)
    (ρ : Nat → RangeIx) : FieldRef.Declared P C (Γ.rawMapRanges ρ) t ref := by
  obtain ⟨ts,cd,a,ht,hc,hd,hn,ha,hw,hs⟩ := h
  exact ⟨ts,cd,a,data_ranges ht ρ,hc,hd,hn,ha,hw,hs⟩

mutual
  private theorem term_ranges {P C Γ t} (h : Term.Declared P C Γ t)
      (ρ : Nat → RangeIx) : Term.Declared P C (Γ.rawMapRanges ρ) t := by
    cases t <;> simp only [Term.Declared] at h ⊢
    all_goals first
      | trivial
      | exact term_ranges h ρ
      | exact ⟨term_ranges h.1 ρ, term_ranges h.2 ρ⟩
      | skip
    case var i =>
      obtain ⟨a,hi,ho⟩ := h
      exact ⟨a.rawMapRanges ρ, by simp [Ctx.rawMapRanges, List.getElem?_map, hi],
        (Ty.ordinary_rawMapRanges a ρ).mpr ho⟩
    case field ref t => exact ⟨term_ranges h.1 ρ, field_ranges h.2 ρ⟩
    case listValue xs => exact slots_ranges h ρ
    case setValue xs => exact slots_ranges h ρ
    case mapValue ks vs => exact ⟨slots_ranges h.1 ρ, slots_ranges h.2 ρ⟩
    case dataValue c xs => exact ⟨slots_ranges h.1 ρ,h.2⟩
  private theorem slots_ranges {P C Γ xs} (h : declaredSlots P C Γ xs)
      (ρ : Nat → RangeIx) : declaredSlots P C (Γ.rawMapRanges ρ) xs := by
    cases xs with
    | nil => trivial
    | cons x xs =>
      refine ⟨?_,slots_ranges h.2 ρ⟩
      cases x with
      | none => trivial
      | some t => exact term_ranges h.1 ρ
end

private theorem pred_ranges {P C Γ self p} (h : Pred.Declared P C Γ self p)
    (ρ : Nat → RangeIx) :
    Pred.Declared P C (Γ.rawMapRanges ρ) (self.map (Ty.rawMapRanges ρ)) p := by
  have ctx : (Γ.rawMapRanges ρ).declarationSelf (self.map (Ty.rawMapRanges ρ)) =
      (Γ.declarationSelf self).rawMapRanges ρ := by
    cases self <;> simp only [Ctx.declarationSelf, Option.map, Ctx.rawMapRanges_extend]
  induction p <;> simp only [Pred.Declared, ctx] at h ⊢
  all_goals first
    | trivial
    | exact term_ranges h ρ
    | exact ⟨term_ranges h.1 ρ,term_ranges h.2 ρ⟩
    | exact ⟨by assumption,by assumption⟩
    | assumption
    | skip
  case constructorIs t c =>
    obtain ⟨ht,d,ts,cd,hd,hc,hn⟩ := h
    exact ⟨term_ranges ht ρ,d,ts,cd,data_ranges hd ρ,hc,hn⟩
  case and p q ih jh => exact ⟨ih h.1,jh h.2⟩
  case or p q ih jh => exact ⟨ih h.1,jh h.2⟩
  case not p ih => exact ih h

mutual
  theorem Ty.Declared.rawMapRanges {P C Γ a} (h : Ty.Declared P C Γ a)
      (ρ : Nat → RangeIx) : Ty.Declared P C (Γ.rawMapRanges ρ) (a.rawMapRanges ρ) := by
    cases a <;> simp only [Ty.rawMapRanges,Ty.Declared] at h ⊢
    case ctor c => cases c <;> exact h
    all_goals first
      | trivial | exact h
      | exact Ty.Declared.rawMapRanges h ρ
      | exact declaredTys_ranges h ρ
      | exact ⟨by simpa only [mapRangesTys_eq_map,List.length_map] using h.1,declaredTys_ranges h.2 ρ⟩
      | skip
    case fn ns ps r e => exact ⟨declaredTys_ranges h.1 ρ,h.2.1.rawMapRanges ρ,declaredEff_ranges h.2.2 ρ⟩
    case cont b t e => exact ⟨h.1.rawMapRanges ρ,h.2.1.rawMapRanges ρ,declaredEff_ranges h.2.2 ρ⟩
    case map a b => exact ⟨h.1.rawMapRanges ρ,h.2.rawMapRanges ρ⟩
    case dependentFn t => exact Tel.Declared.rawMapRanges h ρ
    case refined a p => exact ⟨h.1.rawMapRanges ρ,pred_ranges h.2 ρ⟩
  termination_by sizeOf a
  theorem Tel.Declared.rawMapRanges {P C Γ t} (h : Tel.Declared P C Γ t)
      (ρ : Nat → RangeIx) : Tel.Declared P C (Γ.rawMapRanges ρ) (t.rawMapRanges ρ) := by
    cases t with
    | done r e => exact ⟨h.1.rawMapRanges ρ,declaredEff_ranges h.2 ρ⟩
    | param n a t =>
      exact ⟨h.1.rawMapRanges ρ, by simpa only [Ctx.rawMapRanges_extend] using h.2.rawMapRanges ρ⟩
  termination_by sizeOf t
  private theorem declaredTys_ranges {P C Γ as} (h : declaredTys P C Γ as)
      (ρ : Nat → RangeIx) : declaredTys P C (Γ.rawMapRanges ρ) (mapRangesTys ρ as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨h.1.rawMapRanges ρ,declaredTys_ranges h.2 ρ⟩
  termination_by sizeOf as
  private theorem declaredEff_ranges {P C Γ e} (h : declaredEff P C Γ e)
      (ρ : Nat → RangeIx) : declaredEff P C (Γ.rawMapRanges ρ) (Eff.rawMapRanges ρ e) := by
    cases e; exact declaredTys_ranges h ρ
  termination_by sizeOf e
end

private theorem pred_sorted_ranges {Γ : Ctx} {a : Ty} {p : Pred}
    (h : p.Sorted Γ (some a)) (ρ : Nat → RangeIx) :
    p.Sorted (Γ.rawMapRanges ρ) (some (a.rawMapRanges ρ)) := by
  have hm : Ctx.TypeMap Γ (Γ.rawMapRanges ρ) := Ctx.TypeMap.of_map Γ (Ty.rawMapRanges ρ)
    (fun a s h => (Ty.hasSort_rawMapRanges a ρ s).mpr h)
    (fun a h => (Ty.ordinary_rawMapRanges a ρ).mpr h)
    (fun a p h => by simpa only [Ty.assume_rawMapRanges] using h)
  simpa only [renEnv_values, id_eq, upValues_id, predBind_id] using
    Pred.sorted_bind h (renEnv id).values
      (fun s hi => (Ty.hasSort_rawMapRanges _ _ _).mpr hi)
      (fun hi => (Ty.ordinary_rawMapRanges _ _).mpr hi) hm.values hm.references

mutual
  theorem Ty.Sorted.rawMapRanges {Γ a} (h : Ty.Sorted Γ a) (ρ : Nat → RangeIx) :
      Ty.Sorted (Γ.rawMapRanges ρ) (a.rawMapRanges ρ) := by
    cases a <;> simp only [Ty.rawMapRanges,Ty.Sorted] at h ⊢
    all_goals first | trivial | exact Ty.Sorted.rawMapRanges h ρ | exact sortedTys_ranges h ρ | skip
    case fn ns ps r e => exact ⟨sortedTys_ranges h.1 ρ,h.2.1.rawMapRanges ρ,sortedEff_ranges h.2.2 ρ⟩
    case cont b t e => exact ⟨h.1.rawMapRanges ρ,h.2.1.rawMapRanges ρ,sortedEff_ranges h.2.2 ρ⟩
    case map a b => exact ⟨h.1.rawMapRanges ρ,h.2.rawMapRanges ρ⟩
    case refined a p => exact ⟨h.1.rawMapRanges ρ,pred_sorted_ranges h.2 ρ⟩
    case dependentFn t => exact Tel.Sorted.rawMapRanges h ρ
  theorem Tel.Sorted.rawMapRanges {Γ t} (h : Tel.Sorted Γ t) (ρ : Nat → RangeIx) :
      Tel.Sorted (Γ.rawMapRanges ρ) (t.rawMapRanges ρ) := by
    cases t with
    | done a e => exact ⟨h.1.rawMapRanges ρ,sortedEff_ranges h.2 ρ⟩
    | param n a t => exact ⟨h.1.rawMapRanges ρ,by simpa only [Ctx.rawMapRanges_extend] using h.2.rawMapRanges ρ⟩
  private theorem sortedTys_ranges {Γ as} (h : sortedTys Γ as) (ρ : Nat → RangeIx) :
      sortedTys (Γ.rawMapRanges ρ) (mapRangesTys ρ as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨h.1.rawMapRanges ρ,sortedTys_ranges h.2 ρ⟩
  private theorem sortedEff_ranges {Γ e} (h : sortedEff Γ e) (ρ : Nat → RangeIx) :
      sortedEff (Γ.rawMapRanges ρ) (Eff.rawMapRanges ρ e) := by
    cases e; exact sortedTys_ranges h ρ
end

mutual
  theorem Ty.HasKind.rawMapRanges {P K a k} (h : Ty.HasKind P K a k) (ρ : Nat → RangeIx) :
      Ty.HasKind P K (a.rawMapRanges ρ) k := by
    cases k with
    | constructor n => cases a <;> exact h
    | value =>
      cases a <;> simp only [Ty.HasKind,Ty.rawMapRanges] at h ⊢
      all_goals first | trivial | exact h | exact Ty.HasKind.rawMapRanges h ρ | exact kindsList_ranges h ρ | skip
      case data d as => exact ⟨by simpa only [mapRangesTys_eq_map,List.length_map] using h.1,kindsList_ranges h.2 ρ⟩
      case tapp i as => exact ⟨by simpa only [mapRangesTys_eq_map,List.length_map] using h.1,kindsList_ranges h.2 ρ⟩
      case fn ns ps r e => exact ⟨by simpa only [NamesWF,mapRangesTys_eq_map,List.length_map] using h.1,
        kindsList_ranges h.2.1 ρ,h.2.2.1.rawMapRanges ρ,kindsEff_ranges h.2.2.2 ρ⟩
      case cont b t e => exact ⟨h.1.rawMapRanges ρ,h.2.1.rawMapRanges ρ,kindsEff_ranges h.2.2 ρ⟩
      case map a b => exact ⟨h.1.rawMapRanges ρ,h.2.rawMapRanges ρ⟩
      case dict cl a => obtain ⟨cd,hc,ha⟩ := h; exact ⟨cd,hc,ha.rawMapRanges ρ⟩
      case refined a p => exact ⟨h.1.rawMapRanges ρ,(Ty.ordinary_rawMapRanges a ρ).mpr h.2⟩
      case dependentFn t => exact kindsTel_ranges h ρ
  private theorem kindsList_ranges {P K as} (h : kindsList P K as) (ρ : Nat → RangeIx) :
      kindsList P K (mapRangesTys ρ as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨h.1.rawMapRanges ρ,kindsList_ranges h.2 ρ⟩
  private theorem kindsEff_ranges {P K e} (h : kindsEff P K e) (ρ : Nat → RangeIx) :
      kindsEff P K (Eff.rawMapRanges ρ e) := by
    cases e; exact kindsList_ranges h ρ
  private theorem kindsTel_ranges {P K t} (h : kindsTel P K t) (ρ : Nat → RangeIx) :
      kindsTel P K (t.rawMapRanges ρ) := by
    cases t with
    | done a e => exact ⟨h.1.rawMapRanges ρ,kindsEff_ranges h.2 ρ⟩
    | param n a t => exact ⟨h.1.rawMapRanges ρ,kindsTel_ranges h.2 ρ⟩
end

theorem SupportTransport.rangesOnly {p q : Atom → Prop} (rs : List RangeExpr)
    (h : ∀ a, p a → q (a.instR rs)) : SupportTransport p q (.rangesOnly rs) := by
  refine ⟨fun _ => trivial, by simp [SubstEnv.rangesOnly], ?_⟩
  intro a ha
  constructor
  · intro b hb
    rcases (Eff.mem_rawBind (.rangesOnly rs) (.mk (fun x => decide (x=a)) []) b).mp hb with
      ⟨x,hx,he,_⟩ | ⟨i,f,hf,_,_⟩
    · have hx' : x = a := by simpa [Eff.mem,Eff.test,Eff.atoms] using hx
      subst x
      subst b
      exact h a ha
    · simp [SubstEnv.rangesOnly] at hf
  · simp [SubstEnv.rangesOnly,rawBindTys,rowFails,Ty.SupportList]

theorem SubstEnv.rangesOnly_wfImages {nr nt nv : Nat} {rs : List RangeExpr}
    (hn : rs.length = nr) : (SubstEnv.rangesOnly rs).WFImages nr nt nv 0 nt nv := by
  refine ⟨fun _ hi => hi, by simp [SubstEnv.rangesOnly], ?_, ?_, ?_⟩
  · intro ix hi; exact RangeIx.wf_inst hi hn
  · intro i hi t ht; cases ht; exact hi
  · intro i; simp [SubstEnv.rangesOnly, Ordinary, Ty.core]

theorem Tel.sourceScoped_bind {nr nt ne nv mr mt me mv : Nat} {t : Tel} {θ : SubstEnv}
    (h : (Ty.dependentFn t).SourceScoped nr nt ne nv)
    (hw : θ.WFImages nr nt nv mr mt mv)
    (he : SupportTransport (rowCondition (· < ne)) (rowCondition (· < me)) θ)
    (hr : SupportTransport (rangeCondition nr) (rangeCondition mr) θ) :
    (Ty.dependentFn (Tel.bind θ t)).SourceScoped mr mt me mv := by
  have wf := Tel.rawBind_norm_wf t h.1 hw
  exact ⟨wf,
    (Tel.rowsIn_iff_support _ _).mpr
      (Tel.norm_support _ (Tel.rawBind_support _ _ θ t
        ((Tel.rowsIn_iff_support _ _).mp h.2.1) he)),
    (Tel.rangesScoped_iff_support _ wf).mpr
      (Tel.norm_support _ (Tel.rawBind_support _ _ θ t
        ((Tel.rangesScoped_iff_support _ h.1).mp h.2.2) hr))⟩

theorem PrimSig.Scoped.inst_source {P : Program} {s : PrimSig} (h : s.Scoped P)
    {rs : List RangeExpr} (hn : rs.length = s.rkinds.length) :
    (Ty.dependentFn (Tel.instR rs s.tel)).SourceScoped 0 s.tparams.length s.neffs 0 := by
  rw [Tel.instR_eq_bind]
  refine Tel.sourceScoped_bind h.source (SubstEnv.rangesOnly_wfImages hn)
    (SupportTransport.rangesOnly rs ?_) (SupportTransport.rangesOnly rs ?_)
  · intro a ha; cases a <;> exact ha
  · intro a ha; cases a with
    | name l ix => exact RangeIx.wf_inst ha hn
    | rho i => trivial


theorem PrimSig.Scoped.inst {P : Program} {s : PrimSig} (h : s.Scoped P)
    {rs : List RangeExpr} (hn : rs.length = s.rkinds.length) :
    SignatureScoped P s.tparams s.neffs (Tel.instR rs s.tel) := by
  have hs := h.inst_source hn
  refine ⟨hs,hs.2.1,?_,⟨hs.1,?_,?_⟩⟩
  · exact kindsTel_norm (kindsTel_ranges h.kinds _)
  · exact Tel.sorted_norm (h.sorted.rawMapRanges _)
  · exact Tel.Declared.norm (h.declared.rawMapRanges _)

theorem Builtins.CoreAssumptions.opSignaturesWF {P B} (h : Builtins.CoreAssumptions P B) :
    B.OpSignaturesWF := fun b s hs ho => ((h.sig_scoped b s hs).operation ho).1

theorem Eff.SourceScoped.bind {nr nt ne nv mr mt me mv : Nat} {e : Eff} {θ : SubstEnv}
    (h : e.SourceScoped nr nt ne nv) (hw : θ.WFImages nr nt nv mr mt mv)
    (he : SupportTransport (rowCondition (· < ne)) (rowCondition (· < me)) θ)
    (hr : SupportTransport (rangeCondition nr) (rangeCondition mr) θ) :
    (Eff.bind θ e).SourceScoped mr mt me mv := by
  have wf := Eff.rawBind_norm_wf e h.1 hw
  exact ⟨wf,
    (Eff.rowsIn_iff_support _ _).mpr
      (Eff.norm_support _ (Eff.rawBind_support _ _ θ e
        ((Eff.rowsIn_iff_support _ _).mp h.2.1) he)),
    (Eff.rangesScoped_iff_support _ wf).mpr
      (Eff.norm_support _ (Eff.rawBind_support _ _ θ e
        ((Eff.rangesScoped_iff_support _ h.1).mp h.2.2) hr))⟩

theorem Ty.SourceScoped.instR {nr nt ne nv : Nat} {a : Ty} {rs : List RangeExpr}
    (h : a.SourceScoped nr nt ne nv) (hn : rs.length = nr) :
    (a.instR rs).SourceScoped 0 nt ne nv := by
  rw [Ty.instR_eq_bind]
  refine Ty.SourceScoped.bind h (SubstEnv.rangesOnly_wfImages hn)
    (SupportTransport.rangesOnly rs ?_) (SupportTransport.rangesOnly rs ?_)
  · intro a ha; cases a <;> exact ha
  · intro a ha; cases a with
    | name l ix => exact RangeIx.wf_inst ha hn
    | rho i => trivial

theorem Eff.SourceScoped.instR {nr nt ne nv : Nat} {e : Eff} {rs : List RangeExpr}
    (h : e.SourceScoped nr nt ne nv) (hn : rs.length = nr) :
    (Eff.instR rs e).SourceScoped 0 nt ne nv := by
  rw [Eff.instR_eq_bind]
  refine Eff.SourceScoped.bind h (SubstEnv.rangesOnly_wfImages hn)
    (SupportTransport.rangesOnly rs ?_) (SupportTransport.rangesOnly rs ?_)
  · intro a ha; cases a <;> exact ha
  · intro a ha; cases a with
    | name l ix => exact RangeIx.wf_inst ha hn
    | rho i => trivial

end
end Benitoite.Release.Refinement
