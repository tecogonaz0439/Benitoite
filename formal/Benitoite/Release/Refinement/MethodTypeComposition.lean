import Benitoite.Release.Refinement.TypeSubstCallSites

/-! # メソッドの部分的な型置換と全置換（設計書 01-12「篩を含む状態の型付け」） -/
namespace Benitoite.Release.Refinement
noncomputable section

def SubstEnv.afterTypes (f : Nat → Ty) (θ : SubstEnv) : SubstEnv :=
  {θ with types := fun i => (f i).rawBind θ}

theorem SubstEnv.afterTypes_up (f : Nat → Ty) (θ : SubstEnv) :
    SubstEnv.afterTypes (fun i => (f i).shiftV 1 0) θ.up = (SubstEnv.afterTypes f θ).up := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1
  funext i
  exact Ty.rawBind_up (f i) θ

mutual
  theorem Ty.rawBind_after_types (a : Ty) (f : Nat → Ty) (θ : SubstEnv) :
      (a.rawBind (.typesOnly f)).rawBind θ = a.rawBind (.afterTypes f θ) := by
    cases a <;> simp only [Ty.rawBind]
    all_goals first | rfl | exact Ty.rawBind_after_types _ f θ |
      exact congrArg _ (Ty.rawBind_after_types _ f θ) |
      exact congrArg _ (rawBindTys_after_types _ f θ) | skip
    case «opaque» =>
      change Ty.opaque _ (RangeIx.inst θ.ranges (RangeIx.inst [] _)) = _
      rw [RangeIx.inst_nil]; rfl
    case «scoped» =>
      change Ty.scoped _ _ (RangeIx.inst θ.ranges (RangeIx.inst [] _)) = _
      rw [RangeIx.inst_nil]; rfl
    case fn => rw [rawBindTys_after_types,Ty.rawBind_after_types,Eff.rawBind_after_types]
    case cont => rw [Ty.rawBind_after_types,Ty.rawBind_after_types,Eff.rawBind_after_types]
    case map => rw [Ty.rawBind_after_types,Ty.rawBind_after_types]
    case tapp i as => rw [rawApply_rawBind,rawBindTys_after_types]; rfl
    case refined a p =>
      simp only [SubstEnv.typesOnly,upValues_id,predBind_id]
      exact congrArg (fun b => Ty.refined b (predBind (upValues θ.values) p))
        (Ty.rawBind_after_types a f θ)
    case dependentFn t => rw [Tel.rawBind_after_types]
  theorem rawBindTys_after_types (as : List Ty) (f : Nat → Ty) (θ : SubstEnv) :
      rawBindTys θ (rawBindTys (.typesOnly f) as) = rawBindTys (.afterTypes f θ) as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [rawBindTys,Ty.rawBind_after_types,rawBindTys_after_types]
  theorem Eff.rawBind_after_types (e : Eff) (f : Nat → Ty) (θ : SubstEnv) :
      Eff.rawBind θ (Eff.rawBind (.typesOnly f) e) = Eff.rawBind (.afterTypes f θ) e := by
    cases e with
    | mk ats fs =>
      simp only [Eff.rawBind, show (SubstEnv.typesOnly f).rows = [] from rfl,
        show (SubstEnv.typesOnly f).ranges = [] from rfl, instAtoms_nil,substAtoms_nil,
        show rowFails [] ats = [] from rfl,List.append_nil,rawBindTys_after_types]
      rfl
  theorem Tel.rawBind_after_types (t : Tel) (f : Nat → Ty) (θ : SubstEnv) :
      Tel.rawBind θ (Tel.rawBind (.typesOnly f) t) = Tel.rawBind (.afterTypes f θ) t := by
    cases t with
    | done a e => simp only [Tel.rawBind,Ty.rawBind_after_types,Eff.rawBind_after_types]
    | param n a t =>
      simp only [Tel.rawBind,SubstEnv.typesOnly_up,Ty.rawBind_after_types]
      rw [Tel.rawBind_after_types,SubstEnv.afterTypes_up]
end

theorem Tel.bind_after_types (t : Tel) (f : Nat → Ty) (θ : SubstEnv) :
    Tel.bind θ (Tel.bind (.typesOnly f) t) = Tel.bind (.afterTypes f θ) t := by
  simp only [Tel.bind,Tel.norm_rawBind,Tel.rawBind_after_types]

theorem Ty.bind_sameTypes_below {nr nt nv a θ τ}
    (hw : Ty.WF nr nt nv a) (ht : ∀ i, i<nt → (θ.types i).norm = (τ.types i).norm)
    (hr : θ.rows = τ.rows) (hg : θ.ranges = τ.ranges) (hv : θ.values = τ.values) :
    a.bind θ = a.bind τ := by
  let θ' := {θ with types := fun i => (θ.types i).norm}
  let τ' := {τ with types := fun i => (τ.types i).norm}
  have hθ : SubstEnv.SameTypes θ θ' := ⟨by intro i; exact (Ty.norm_idem _).symm,rfl,rfl,rfl⟩
  have hτ : SubstEnv.SameTypes τ' τ := ⟨by intro i; exact Ty.norm_idem _,rfl,rfl,rfl⟩
  exact (Ty.bind_sameTypes a hθ).trans
    ((congrArg Ty.norm (Ty.rawBind_agrees hw (θ := θ') (τ := τ') ⟨ht,hr,hg,hv⟩)).trans
      (Ty.bind_sameTypes a hτ))

theorem Tel.bind_sameTypes_below {nr nt nv t θ τ}
    (hw : Tel.WF nr nt nv t) (ht : ∀ i, i<nt → (θ.types i).norm = (τ.types i).norm)
    (hr : θ.rows = τ.rows) (hg : θ.ranges = τ.ranges) (hv : θ.values = τ.values) :
    Tel.bind θ t = Tel.bind τ t := by
  let θ' := {θ with types := fun i => (θ.types i).norm}
  let τ' := {τ with types := fun i => (τ.types i).norm}
  have hθ : SubstEnv.SameTypes θ θ' := ⟨by intro i; exact (Ty.norm_idem _).symm,rfl,rfl,rfl⟩
  have hτ : SubstEnv.SameTypes τ' τ := ⟨by intro i; exact Ty.norm_idem _,rfl,rfl,rfl⟩
  exact (Tel.bind_sameTypes t hθ).trans
    ((congrArg Tel.norm (Tel.rawBind_agrees hw (θ := θ') (τ := τ') ⟨ht,hr,hg,hv⟩)).trans
      (Tel.bind_sameTypes t hτ))

theorem Tel.shiftV_of_wf_zero {nr nt t} (hw : Tel.WF nr nt 0 t) (k c : Nat) :
    Tel.shiftV k c t = t := by
  have h := Ty.shiftV_of_wf_zero (show Ty.WF nr nt 0 (.dependentFn t) from hw) k c
  exact Ty.dependentFn.inj h

theorem tel_substAt_shiftV_closed {ts es} (ht : ∀ a ∈ ts, a.WF 0 0 0)
    (he : ∀ e ∈ es, e.WF 0 0 0) (t : Tel) (c n : Nat) :
    Tel.substAt c ts es (Tel.shiftV n 0 t) = Tel.shiftV n 0 (Tel.substAt c ts es t) := by
  have hu : (typeEnvAt c ts es).up = typeEnvAt c ts es := by
    have hh := typeEnvAt_up c ts es
    rw [map_typeImages_shiftV_closed ht,map_rowImages_shiftV_closed he] at hh
    exact hh
  induction n with
  | zero => simp only [Tel.shiftV_zero]
  | succ n ih =>
    have h := Tel.bind_up (Tel.shiftV n 0 t) (typeEnvAt c ts es)
    rw [hu] at h
    change Tel.substAt c ts es (Tel.shiftV 1 0 (Tel.shiftV n 0 t)) =
      Tel.shiftV 1 0 (Tel.substAt c ts es (Tel.shiftV n 0 t)) at h
    rw [ih] at h
    have hadd (u : Tel) : Tel.shiftV 1 0 (Tel.shiftV n 0 u) = Tel.shiftV (n+1) 0 u :=
      Ty.dependentFn.inj (Ty.shiftV_add (.dependentFn u) n 1)
    simpa only [hadd] using h

theorem Ty.subst_shift_prefix {nt nv a} (hw : a.WF 0 nt nv)
    (hr : a.RowsIn (· < 0)) (ss us : List Ty) (es : List Eff) (hn : us.length = nt) :
    (shiftTypes ss.length 0 a).subst (ss++us) es = a.subst us [] := by
  change ((shiftTypes ss.length 0 a).rawBind (typeEnvAt 0 (ss++us) es)).norm = _
  rw [Ty.rawBind_shift_source]
  let θ := {typeEnvAt 0 (ss++us) es with types := fun i => (typeEnvAt 0 (ss++us) es).types (i+ss.length)}
  have hrows : a.rawBind θ = a.rawBind {θ with rows := []} := by
    exact Ty.rawBind_rows_rowfree a hr θ θ.rows []
  rw [show a.rawBind _ = a.rawBind θ from rfl,hrows]
  apply congrArg Ty.norm
  apply Ty.rawBind_agrees hw
  refine ⟨?_,rfl,rfl,rfl⟩
  intro i hi
  have hiu : i < us.length := by omega
  change (typeEnvAt 0 (ss++us) es).types (i+ss.length) = (typeEnvAt 0 us []).types i
  simp only [typeEnvAt,Nat.not_lt_zero,↓reduceIte,Nat.sub_zero,List.length_append,
    show i+ss.length < ss.length+us.length from by omega,hiu,↓reduceIte,
    List.getElem?_append_right (show ss.length ≤ i+ss.length by omega),
    show i+ss.length-ss.length=i from by omega,
    List.getElem?_eq_getElem hiu,Option.getD_some]

theorem methodTel_comp {nt t target τ ss us es}
    (ht : Tel.WF 0 (ss.length+1) 0 t) (hu : us.length = nt)
    (hw : target.WF 0 nt 0) (hr : target.RowsIn (· < 0))
    (heq : τ.norm = (target.subst us []).norm) :
    Tel.substAt 0 (ss++us) es (Tel.bind (typeEnvAt ss.length [target] []) t) =
      instantiatedTel t (ss++[τ]) es
 := by
  change Tel.bind (typeEnvAt 0 (ss++us) es) (Tel.bind (typeEnvAt ss.length [target] []) t) = _
  let f := (typeEnvAt ss.length [target] []).types
  have hf : typeEnvAt ss.length [target] [] = SubstEnv.typesOnly f := rfl
  rw [hf,Tel.bind_after_types]
  apply Tel.bind_sameTypes_below ht
  · intro i hi
    by_cases his : i < ss.length
    · change ((f i).rawBind (typeEnvAt 0 (ss++us) es)).norm = _
      have hfi : f i = .tvar i := by simp [f,typeEnvAt,his]
      rw [hfi]
      simp only [Ty.rawBind,typeEnvAt,Nat.not_lt_zero,↓reduceIte,Nat.sub_zero,
        show i < (ss++us).length by simp; omega,
        show i < (ss++[τ]).length by simp; omega,↓reduceIte,
        List.getElem?_append_left his]
    · have hie : i = ss.length := by omega
      subst i
      have hfi : f ss.length = shiftTypes ss.length 0 target := by simp [f,typeEnvAt]
      change ((f ss.length).rawBind (typeEnvAt 0 (ss++us) es)).norm = _
      rw [hfi]
      change (shiftTypes ss.length 0 target).subst (ss++us) es = _
      rw [Ty.subst_shift_prefix hw hr ss us es hu]
      simp only [typeEnvAt,Nat.not_lt_zero,↓reduceIte,Nat.sub_zero,List.length_append,
        List.length_cons,List.length_nil,Nat.reduceAdd,Nat.lt_add_one,↓reduceIte,
        List.getElem?_append_right (Nat.le_refl _),Nat.sub_self,List.getElem?_cons_zero,
        Option.getD_some,shiftTypes_zero]
      exact (Ty.norm_idem _).symm.trans heq.symm
  · rfl
  · rfl
  · rfl

theorem method_dictionary_context {id : ImplDecl} {ss us : List Ty} {es : List Eff}
    (hn : us.length = id.tparams.length)
    (hc : ∀ p ∈ id.dictParams, p.2 < id.tparams.length)
    (ht : ∀ a ∈ ss++us, a.WF 0 0 0) (he : ∀ e ∈ es, e.WF 0 0 0) :
    (bindParams [] (id.dictTys.map (Ty.shift ss.length 0))).bindTypes (typeEnvAt 0 (ss++us) es) =
      bindParams [] (id.dictTys.map (Ty.subst us [])) := by
  rw [Ctx.bindTypes_params ht he]
  change bindParams [] _ = bindParams [] _
  congr 1
  simp only [List.map_map,ImplDecl.dictTys]
  apply List.map_congr_left
  intro p hp
  have hw : Ty.WF 0 id.tparams.length 0 (.dict p.1 (.tvar p.2)) := hc p hp
  have hr : Ty.RowsIn (· < 0) (.dict p.1 (.tvar p.2)) := trivial
  change ((Ty.shift ss.length 0 (.dict p.1 (.tvar p.2))).rawBind _).norm = _
  simp only [Ty.shift,Ty.bind,Ty.rawBind_shiftTypes,Ty.norm_rawBind]
  exact Ty.subst_shift_prefix hw hr ss us es hn

theorem dependent_result_close {nt : Nat} {a : Ty}
    (hw : a.WF 0 nt 0) (ts : List Ty) (cap : Capture) :
    cap.closeTy (a.subst ts []) = a.subst (ts.map cap.closeTy) [] :=
  Ty.subst_values_closed hw ts cap.env

end
end Benitoite.Release.Refinement
