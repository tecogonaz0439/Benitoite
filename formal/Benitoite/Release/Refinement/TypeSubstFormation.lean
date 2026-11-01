import Benitoite.Release.Refinement.TypeFormation
import Benitoite.Release.Refinement.KindTypeSubst
import Benitoite.Release.Refinement.TypeSubstContracts
import Benitoite.Release.Refinement.TypeRows

/-! 宣言の kind と注釈を使った型・行の置換の形成。 -/
namespace Benitoite.Release.Refinement
set_option maxHeartbeats 2000000

private theorem substAtoms_rowfree (es : List Eff) (a : Atom → Bool)
    (h : ∀ i, a (.rho i) = false) : substAtoms es a = a := by
  funext x
  cases x <;> simp [substAtoms, h]

private theorem rowFails_rowfree (es : List Eff) (a : Atom → Bool)
    (h : ∀ i, a (.rho i) = false) : rowFails es a = [] := by
  simp [rowFails, h]

mutual
  private theorem raw_comp {a : Ty} (ha : a.NoTapp) (hr : a.RowsIn (· < 0))
      (f : Nat → Ty) (θ : SubstEnv) (hv : θ.values = fun i => some (.var i))
      (hg : θ.ranges = []) :
      (a.rawBind (.typesOnly f)).rawBind θ =
        a.rawBind (.typesOnly (fun i => (f i).rawBind θ)) := by
    cases a <;> simp only [Ty.NoTapp] at ha <;> simp only [Ty.RowsIn] at hr <;> simp only [Ty.rawBind]
    all_goals try rfl
    case «opaque» _ _ => simp [SubstEnv.typesOnly, hg, RangeIx.inst_nil]
    case «scoped» _ _ _ => simp [SubstEnv.typesOnly, hg, RangeIx.inst_nil]
    case data _ _ => rw [raw_comp_tys ha hr f θ hv hg]
    case external _ _ => rw [raw_comp_tys ha hr f θ hv hg]
    case fn _ _ _ _ => rw [raw_comp_tys ha.1 hr.1 f θ hv hg, raw_comp ha.2.1 hr.2.1 f θ hv hg, raw_comp_eff ha.2.2 hr.2.2 f θ hv hg]
    case cont _ _ _ => rw [raw_comp ha.1 hr.1 f θ hv hg, raw_comp ha.2.1 hr.2.1 f θ hv hg, raw_comp_eff ha.2.2 hr.2.2 f θ hv hg]
    case map _ _ => rw [raw_comp ha.1 hr.1 f θ hv hg, raw_comp ha.2 hr.2 f θ hv hg]
    case dependentFn _ => rw [raw_comp_tel ha hr f θ hv hg]
    case refined a p =>
      simp only [SubstEnv.typesOnly, hv, upValues_id, predBind_id]
      exact congrArg (fun a => Ty.refined a p) (raw_comp ha hr f θ hv hg)
    all_goals rw [raw_comp ha hr f θ hv hg]
  private theorem raw_comp_tys {as} (ha : noTappTys as) (hr : Ty.RowsInList (· < 0) as)
      (f : Nat → Ty) (θ : SubstEnv) (hv : θ.values = fun i => some (.var i)) (hg : θ.ranges = []) :
      rawBindTys θ (rawBindTys (.typesOnly f) as) =
        rawBindTys (.typesOnly (fun i => (f i).rawBind θ)) as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [rawBindTys, raw_comp ha.1 hr.1 f θ hv hg, raw_comp_tys ha.2 hr.2 f θ hv hg]
  private theorem raw_comp_eff {e} (ha : noTappEff e) (hr : Eff.RowsIn (· < 0) e)
      (f : Nat → Ty) (θ : SubstEnv) (hv : θ.values = fun i => some (.var i)) (hg : θ.ranges = []) :
      Eff.rawBind θ (Eff.rawBind (.typesOnly f) e) =
        Eff.rawBind (.typesOnly (fun i => (f i).rawBind θ)) e := by
    cases e with
    | mk ats fs =>
      have hz : ∀ i, ats (.rho i) = false := by intro i; cases he : ats (.rho i) <;> simp_all [Eff.RowsIn]
      simp only [Eff.rawBind, SubstEnv.typesOnly, instAtoms_nil, substAtoms_nil,
        show rowFails [] ats = [] from rfl, List.append_nil]
      rw [hg, instAtoms_nil, substAtoms_rowfree _ _ hz, rowFails_rowfree _ _ hz,
        List.append_nil]
      exact congrArg (EffR.mk ats) (raw_comp_tys ha hr.2 f θ hv hg)

  private theorem raw_comp_tel {t} (ha : noTappTel t) (hr : t.RowsIn (· < 0))
      (f : Nat → Ty) (θ : SubstEnv) (hv : θ.values = fun i => some (.var i)) (hg : θ.ranges = []) :
      Tel.rawBind θ (Tel.rawBind (.typesOnly f) t) =
        Tel.rawBind (.typesOnly (fun i => (f i).rawBind θ)) t := by
    cases t with
    | done r e => simp only [Tel.rawBind, raw_comp ha.1 hr.1 f θ hv hg, raw_comp_eff ha.2 hr.2 f θ hv hg]
    | param n a t =>
      simp only [Tel.rawBind, SubstEnv.typesOnly_up, raw_comp ha.1 hr.1 f θ hv hg]
      rw [raw_comp_tel ha.2 hr.2 _ θ.up (by simp [SubstEnv.up, hv, upValues_id]) (by simp [SubstEnv.up, hg])]
      congr 2
      apply congrArg SubstEnv.typesOnly
      funext i
      exact Ty.rawBind_up (f i) θ
end

private theorem subst_comp {n : Nat} {a : Ty} (hw : a.WF 0 n 0)
    (ha : a.NoTapp) (hr : a.RowsIn (· < 0)) (xs : List Ty) (hn : n ≤ xs.length)
    (θ : SubstEnv) (hv : θ.values = fun i => some (.var i)) (hg : θ.ranges = []) :
    (a.subst xs []).bind θ = a.subst (xs.map (Ty.bind θ)) [] := by
  have hm : xs.map (Ty.bind θ) = Ty.normTys (rawBindTys θ xs) := by
    simp only [rawBindTys_eq_map, Ty.normTys_eq_map, List.map_map]; rfl
  rw [hm, Ty.subst_norm_images]
  change (Ty.rawBind θ (a.rawBind (typeEnvAt 0 xs [])).norm).norm =
    (a.rawBind (typeEnvAt 0 (rawBindTys θ xs) [])).norm
  rw [Ty.norm_rawBind, typeEnvAt_zero_eq_typesOnly, raw_comp ha hr _ θ hv hg]
  congr 1
  apply Ty.rawBind_agrees hw
  refine ⟨?_, rfl, rfl, rfl⟩
  intro i hi
  have hl : i < xs.length := by omega
  simp only [SubstEnv.typesOnly, typeEnvAt, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero,
    rawBindTys_eq_map, List.length_map, List.getElem?_map, hl]
  simp [List.getElem?_eq_getElem hl, shiftTypes_zero]

private theorem obs_apply (a : Ty) (as : List Ty) :
    (rawApply a as).observationType =
      (rawApply a.observationType (observationTypes as)).observationType := by
  cases a <;> try rfl
  case ctor c => cases c <;> simp [rawApply, Ty.observationType]
  case tvar i => simp [rawApply, Ty.observationType]
  case data d xs => simp [rawApply, Ty.observationType]
  case refined a p => exact obs_apply a as
  case tapp i xs => simp [rawApply, Ty.observationType]


mutual
  private theorem obs_bind (a : Ty) (θ : SubstEnv) :
      (a.rawBind θ).observationType =
        (a.rawBind (.typesOnly θ.types)).observationType := by
    cases a <;> simp only [Ty.rawBind, Ty.observationType]
    all_goals try rfl
    case data d as => rw [obs_bind_tys]
    case refined a p => exact obs_bind a θ
    case tapp i as =>
      change (rawApply (θ.types i) (rawBindTys θ as)).observationType =
        (rawApply (θ.types i) (rawBindTys (.typesOnly θ.types) as)).observationType
      rw [obs_apply, obs_apply (as := rawBindTys (.typesOnly θ.types) as)]
      rw [obs_bind_tys]
  private theorem obs_bind_tys (as : List Ty) (θ : SubstEnv) :
      observationTypes (rawBindTys θ as) = observationTypes (rawBindTys (.typesOnly θ.types) as) := by
    cases as with
    | nil => rfl
    | cons a as => simp only [rawBindTys, observationTypes, obs_bind a θ, obs_bind_tys as θ]
end

private theorem data_obs_bind {P d as bs} (h : DataObservationLe P d as bs)
    (θ : SubstEnv) (ho : ∀ i, Ordinary (θ.types i)) :
    DataObservationLe P d (as.map (Ty.bind θ)) (bs.map (Ty.bind θ)) := by
  have hh := h.bind_typesOnly θ.types ho
  have he (xs : List Ty) : observationTypes (xs.map (Ty.bind θ)) =
      observationTypes (xs.map (Ty.bind (.typesOnly θ.types))) := by
    simp only [observationTypes_eq_map, List.map_map, Function.comp_def]
    apply List.map_congr_left
    intro a _
    simp only [Ty.bind, Ty.observationType_norm]
    exact obs_bind a θ
  change TypeArgsLe _ [] [] _ _ _ at hh ⊢
  rw [he as, he bs]
  simpa only [List.length_map] using hh

private structure DeclMap (Γ Δ : Ctx) (θ : SubstEnv) : Prop where
  lookup : ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) →
    ∃ b, Δ[i]? = some (some b) ∧ b.norm = a.bind θ
  ordinary : ∀ i, Ordinary (θ.types i)

private theorem declMap_extend {Γ Δ θ} (hm : DeclMap Γ Δ θ) (a b : Ty)
    (hb : b.norm = a.bind θ) : DeclMap (Γ.extend a) (Δ.extend b) θ.up := by
  constructor
  · intro i t hi
    cases i with
    | zero =>
      cases Option.some.inj hi
      exact ⟨b.shiftV 1 0, rfl, by rw [Ty.norm_shiftV, hb, Ty.bind_up]⟩
    | succ i =>
      simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map, Option.map_eq_some_iff] at hi
      obtain ⟨_, hx, x, rfl, rfl⟩ := hi
      obtain ⟨y, hy, he⟩ := hm.lookup i x hx
      exact ⟨y.shiftV 1 0, by simp [Ctx.extend, List.getElem?_map, hy], by rw [Ty.norm_shiftV, he, Ty.bind_up]⟩
  · intro i; exact (Ty.ordinary_shiftV _ _ _).mpr (hm.ordinary i)

private theorem data_core_bind {a : Ty} {d xs} (h : a.norm.core = .data d xs) (θ : SubstEnv) :
    (a.bind θ).core = .data d (xs.map (Ty.bind θ)) := by
  cases a <;> simp only [Ty.norm, Ty.core] at h
  case data d as =>
    cases h
    simp only [Ty.bind, Ty.rawBind, Ty.norm, Ty.core, Ty.normTys_eq_map, rawBindTys_eq_map, List.map_map, Function.comp_def]
    congr 2
    funext a
    exact (Ty.norm_rawBind _ a).symm
  case refined a p =>
    simp only [Ty.core_refineNorm] at h
    simpa only [Ty.bind, Ty.rawBind, Ty.norm, Ty.core_refineNorm] using data_core_bind h θ
  case dependentFn t => exact False.elim (Ty.notDataCore_dependentFn h)
  all_goals cases h

private theorem hasData_bind {P Γ Δ t d xs θ} (h : Term.HasData P Γ t d xs)
    (hp : P.WellFormed) (valid : P.VarianceValid) (hm : DeclMap Γ Δ θ)
    (hv : θ.values = fun i => some (.var i)) (hg : θ.ranges = []) :
    Term.HasData P Δ t d (xs.map (Ty.bind θ)) := by
  match h with
  | .widen hr hs => exact .widen (hasData_bind hr hp valid hm hv hg) (data_obs_bind hs θ hm.ordinary)
  | .var hi hd =>
    obtain ⟨b, hb, he⟩ := hm.lookup _ _ hi
    exact .var hb (by rw [he]; exact data_core_bind hd θ)
  | .value hc hd hn hl => exact .value hc hd (by simpa only [List.length_map] using hn) hl
  | .field (ts := ts) hr hc hd hn ha hw hs he =>
    have hk := ((valid.2 _ _ hc).2 _ (List.mem_of_getElem? ha)).2.1
    have hrows := ((hp.cons _ _ hc).2 _ (List.mem_of_getElem? ha)).1.2.1
    have hx := subst_comp hw hk.noTapp hrows ts (by omega) θ hv hg
    refine .field (hasData_bind hr hp valid hm hv hg) hc hd (by simpa only [List.length_map] using hn) ha hw ?_ ?_
    · rw [← hx]; exact Ty.hasSort_bind hs θ
    · rw [← hx]
      simpa only [Ty.bind, Ty.norm_idem] using data_core_bind he θ

private theorem field_decl_bind {P C D Γ Δ t ref θ} (h : FieldRef.Declared P C Γ t ref)
    (hp : P.WellFormed) (valid : P.VarianceValid) (hm : DeclMap Γ Δ θ)
    (hv : θ.values = fun i => some (.var i)) (hg : θ.ranges = []) :
    FieldRef.Declared P D Δ t ref := by
  obtain ⟨xs, cd, a, ht, hc, hd, hn, ha, hw, hs⟩ := h
  have hk := ((valid.2 _ _ hc).2 _ (List.mem_of_getElem? ha)).2.1
  have hrows := ((hp.cons _ _ hc).2 _ (List.mem_of_getElem? ha)).1.2.1
  refine ⟨xs.map (Ty.bind θ), cd, a, hasData_bind ht hp valid hm hv hg, hc, hd,
    by simpa only [List.length_map] using hn, ha, hw, ?_⟩
  rw [← subst_comp hw hk.noTapp hrows xs (by omega) θ hv hg]
  exact Ty.hasSort_bind hs θ

mutual
  private theorem term_decl_bind {P C D Γ Δ t θ} (h : Term.Declared P C Γ t)
      (hp : P.WellFormed) (valid : P.VarianceValid) (hm : DeclMap Γ Δ θ)
      (hv : θ.values = fun i => some (.var i)) (hg : θ.ranges = []) : Term.Declared P D Δ t := by
    cases t <;> simp only [Term.Declared] at h ⊢
    all_goals first | trivial | exact term_decl_bind h hp valid hm hv hg | skip
    case var i =>
      obtain ⟨a, hi, ho⟩ := h
      obtain ⟨b, hb, he⟩ := hm.lookup i a hi
      exact ⟨b, hb, (Ty.ordinary_norm _).mp (he.symm ▸ Ty.ordinary_bind ho θ hm.ordinary)⟩
    case field ref t => exact ⟨term_decl_bind h.1 hp valid hm hv hg, field_decl_bind h.2 hp valid hm hv hg⟩
    case add a b => exact ⟨term_decl_bind h.1 hp valid hm hv hg, term_decl_bind h.2 hp valid hm hv hg⟩
    case listValue _ => exact slots_decl_bind h hp valid hm hv hg
    case setValue _ => exact slots_decl_bind h hp valid hm hv hg
    case mapValue _ _ => exact ⟨slots_decl_bind h.1 hp valid hm hv hg, slots_decl_bind h.2 hp valid hm hv hg⟩
    case dataValue _ _ => exact ⟨slots_decl_bind h.1 hp valid hm hv hg, h.2⟩
  private theorem slot_decl_bind {P C D Γ Δ t θ} (h : declaredSlot P C Γ t)
      (hp : P.WellFormed) (valid : P.VarianceValid) (hm : DeclMap Γ Δ θ)
      (hv : θ.values = fun i => some (.var i)) (hg : θ.ranges = []) : declaredSlot P D Δ t := by
    cases t with
    | none => trivial
    | some t => exact term_decl_bind h hp valid hm hv hg
  private theorem slots_decl_bind {P C D Γ Δ ts θ} (h : declaredSlots P C Γ ts)
      (hp : P.WellFormed) (valid : P.VarianceValid) (hm : DeclMap Γ Δ θ)
      (hv : θ.values = fun i => some (.var i)) (hg : θ.ranges = []) : declaredSlots P D Δ ts := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨slot_decl_bind h.1 hp valid hm hv hg, slots_decl_bind h.2 hp valid hm hv hg⟩
end

private theorem pred_decl_bind {P C D Γ Δ self other p θ} (h : Pred.Declared P C Γ self p)
    (hp : P.WellFormed) (valid : P.VarianceValid) (_hm : DeclMap Γ Δ θ)
    (hv : θ.values = fun i => some (.var i)) (hg : θ.ranges = [])
    (hself : DeclMap (Γ.declarationSelf self) (Δ.declarationSelf other) θ.up) :
    Pred.Declared P D Δ other p := by
  induction p <;> simp only [Pred.Declared] at h ⊢
  all_goals first
    | trivial
    | exact term_decl_bind h hp valid hself (by simp [SubstEnv.up, hv, upValues_id]) (by simp [SubstEnv.up, hg])
    | exact ⟨term_decl_bind h.1 hp valid hself (by simp [SubstEnv.up, hv, upValues_id]) (by simp [SubstEnv.up, hg]),
        term_decl_bind h.2 hp valid hself (by simp [SubstEnv.up, hv, upValues_id]) (by simp [SubstEnv.up, hg])⟩
    | exact ⟨by assumption, by assumption⟩
    | assumption
    | skip
  case constructorIs t c =>
    obtain ⟨ht, d, ts, cd, hd, hc, hn⟩ := h
    exact ⟨term_decl_bind ht hp valid hself (by simp [SubstEnv.up, hv, upValues_id]) (by simp [SubstEnv.up, hg]),
      d, ts.map (Ty.bind θ.up), cd, hasData_bind hd hp valid hself
        (by simp [SubstEnv.up, hv, upValues_id]) (by simp [SubstEnv.up, hg]), hc, hn⟩
  case and p q ih jh => exact ⟨ih h.1, jh h.2⟩
  case or p q ih jh => exact ⟨ih h.1, jh h.2⟩
  case not p ih => exact ih h

private theorem declared_apply {P D Δ a n as} (hk : Ty.HasKind P (TypeCtx.kinds D) a (.constructor n))
    (hn : as.length = n) (hs : declaredTys P D Δ as) : Ty.Declared P D Δ (rawApply a as) := by
  have hp := rawApply_proper hk hn
  cases hp with
  | «variable» i as => exact ⟨by simpa only [Ty.HasKind, ← hn] using hk, hs⟩
  | list a | set a | reference a | lazy a => exact hs.1
  | map a b => exact ⟨hs.1, hs.2.1⟩
  | data d as => exact ⟨⟨n, TyCon.dataArity_of_arity hk, hn⟩, hs⟩

private theorem declared_list_iff {P C Γ as} : declaredTys P C Γ as ↔ ∀ a ∈ as, Ty.Declared P C Γ a := by
  induction as with
  | nil => simp [declaredTys]
  | cons a as ih => simp [declaredTys, ih]

private theorem declared_rowFails {P C Γ es ats} (h : ∀ e ∈ es, declaredEff P C Γ e) :
    declaredTys P C Γ (rowFails es ats) := by
  apply declared_list_iff.mpr
  intro t ht
  obtain ⟨i, e, he, _, ht⟩ := Eff.mem_rowFails.mp ht
  cases e with
  | mk ats fs => exact declared_list_iff.mp (h _ (List.mem_of_getElem? he)) t ht

private theorem declared_outer {P C Γ a} (h : Ty.Declared P C Γ a) (b : Ty) :
    Ty.Declared P C (Γ.extend b) (a.shiftV 1 0) := by
  rw [Ty.shiftV_eq_renameTy, renameTy_eq_rawSubstV]
  exact h.rawSubstV (DeclarationRenaming.outer Γ b).images

mutual
  private theorem declared_raw {P C D Γ Δ a θ} (h : Ty.Declared P C Γ a)
      (hp : P.WellFormed) (valid : P.VarianceValid) (hm : DeclMap Γ Δ θ)
      (hv : θ.values = fun i => some (.var i)) (hg : θ.ranges = [])
      (hk : TypeImagesKinded P (TypeCtx.kinds C) (TypeCtx.kinds D) θ.types)
      (ht : ∀ i, Ty.Declared P D Δ (θ.types i))
      (he : ∀ e ∈ θ.rows, declaredEff P D Δ e) : Ty.Declared P D Δ (a.rawBind θ) := by
    cases a with
    | base _ | bytes | «opaque» _ _ | «scoped» _ _ _ | pathBases | scopePattern _ => trivial
    | tvar i => exact ht i
    | ctor c => cases c <;> exact h
    | list a | reference a | lazy a | set a | dict _ a => exact declared_raw (a := a) h hp valid hm hv hg hk ht he
    | data d as => exact ⟨by simpa only [rawBindTys_eq_map, List.length_map] using h.1,
        declared_raw_tys h.2 hp valid hm hv hg hk ht he⟩
    | external _ as => exact ⟨by simpa only [rawBindTys_eq_map, List.length_map] using h.1,
        declared_raw_tys h.2 hp valid hm hv hg hk ht he⟩
    | tapp i as =>
      exact declared_apply (hk i _ h.1).1
        (by simp only [rawBindTys_eq_map, List.length_map]) (declared_raw_tys h.2 hp valid hm hv hg hk ht he)
    | dependentFn _ => exact declared_raw_tel h hp valid hm hv hg hk ht he
    | fn _ _ _ _ => exact ⟨declared_raw_tys h.1 hp valid hm hv hg hk ht he,
        declared_raw h.2.1 hp valid hm hv hg hk ht he, declared_raw_eff h.2.2 hp valid hm hv hg hk ht he⟩
    | cont _ _ _ => exact ⟨declared_raw h.1 hp valid hm hv hg hk ht he,
        declared_raw h.2.1 hp valid hm hv hg hk ht he, declared_raw_eff h.2.2 hp valid hm hv hg hk ht he⟩
    | map _ _ => exact ⟨declared_raw h.1 hp valid hm hv hg hk ht he, declared_raw h.2 hp valid hm hv hg hk ht he⟩
    | refined a p =>
      simp only [Ty.rawBind, hv, upValues_id, predBind_id, Ty.Declared]
      exact ⟨declared_raw h.1 hp valid hm hv hg hk ht he,
        pred_decl_bind h.2 hp valid hm hv hg (declMap_extend hm a (a.rawBind θ) rfl)⟩
  private theorem declared_raw_tys {P C D Γ Δ as θ} (h : declaredTys P C Γ as)
      (hp : P.WellFormed) (valid : P.VarianceValid) (hm : DeclMap Γ Δ θ)
      (hv : θ.values = fun i => some (.var i)) (hg : θ.ranges = [])
      (hk : TypeImagesKinded P (TypeCtx.kinds C) (TypeCtx.kinds D) θ.types)
      (ht : ∀ i, Ty.Declared P D Δ (θ.types i))
      (he : ∀ e ∈ θ.rows, declaredEff P D Δ e) : declaredTys P D Δ (rawBindTys θ as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨declared_raw h.1 hp valid hm hv hg hk ht he, declared_raw_tys h.2 hp valid hm hv hg hk ht he⟩
  private theorem declared_raw_eff {P C D Γ Δ e θ} (h : declaredEff P C Γ e)
      (hp : P.WellFormed) (valid : P.VarianceValid) (hm : DeclMap Γ Δ θ)
      (hv : θ.values = fun i => some (.var i)) (hg : θ.ranges = [])
      (hk : TypeImagesKinded P (TypeCtx.kinds C) (TypeCtx.kinds D) θ.types)
      (ht : ∀ i, Ty.Declared P D Δ (θ.types i))
      (he : ∀ e ∈ θ.rows, declaredEff P D Δ e) : declaredEff P D Δ (Eff.rawBind θ e) := by
    cases e
    exact declared_list_iff.mpr (fun a ha => by
      rcases List.mem_append.mp ha with ha | ha
      · exact declared_list_iff.mp (declared_raw_tys h hp valid hm hv hg hk ht he) a ha
      · exact declared_list_iff.mp (declared_rowFails he) a ha)
  private theorem declared_raw_tel {P C D Γ Δ t θ} (h : Tel.Declared P C Γ t)
      (hp : P.WellFormed) (valid : P.VarianceValid) (hm : DeclMap Γ Δ θ)
      (hv : θ.values = fun i => some (.var i)) (hg : θ.ranges = [])
      (hk : TypeImagesKinded P (TypeCtx.kinds C) (TypeCtx.kinds D) θ.types)
      (ht : ∀ i, Ty.Declared P D Δ (θ.types i))
      (he : ∀ e ∈ θ.rows, declaredEff P D Δ e) : Tel.Declared P D Δ (Tel.rawBind θ t) := by
    cases t with
    | done r e => exact ⟨declared_raw h.1 hp valid hm hv hg hk ht he, declared_raw_eff h.2 hp valid hm hv hg hk ht he⟩
    | param n a t =>
      refine ⟨declared_raw h.1 hp valid hm hv hg hk ht he, ?_⟩
      apply declared_raw_tel h.2 hp valid (declMap_extend hm a (a.rawBind θ) rfl)
        (by simp [SubstEnv.up, hv, upValues_id]) (by simp [SubstEnv.up, hg])
      · intro i k hi
        exact ⟨(hk i k hi).1.shift_values 1 0,
          fun h => (Ty.ordinary_shiftV _ _ _).mpr ((hk i k hi).2 h)⟩
      · intro i; exact declared_outer (ht i) _
      · intro e he'
        obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he'
        cases f with
        | mk ats fs =>
          apply declared_list_iff.mpr
          intro t ht'
          obtain ⟨b, hb, rfl⟩ := List.mem_map.mp (by simpa only [Eff.shiftV, shiftVTys_eq_map] using ht')
          exact declared_outer (declared_list_iff.mp (he _ hf) b hb) _
end

private theorem declMap_bindTypes (Γ : Ctx) (θ : SubstEnv) (ho : ∀ i, Ordinary (θ.types i)) :
    DeclMap Γ (Γ.bindTypes θ) θ := by
  constructor
  · intro i a hi
    exact ⟨a.bind θ, by simp [Ctx.bindTypes, List.getElem?_map, hi], Ty.norm_idem _⟩
  · exact ho

private theorem closed_type_decl {P B C0 C1 Γ ts es}
    (h : ClosedTypeSubstInput P B C0 C1 Γ ts es) :
    ∀ i, Ty.Declared P C1 (Γ.bindTypes (typeEnvAt C1.length ts es))
      ((typeEnvAt C1.length ts es).types i) := by
  intro i
  simp only [typeEnvAt]
  split
  · trivial
  · split
    · rename_i hi
      have he := List.getElem?_eq_getElem hi
      simp only [he, Option.getD_some]
      rw [Ty.shiftTypes_of_wf_zero (h.typeWF _ (List.getElem_mem hi))]
      exact (h.typeAnnotations _ (List.getElem_mem hi)).declared.closed_context (h.typeWF _ (List.getElem_mem hi))
    · trivial

private theorem closed_row_decl {P B C0 C1 Γ ts es}
    (h : ClosedTypeSubstInput P B C0 C1 Γ ts es) :
    ∀ e ∈ (typeEnvAt C1.length ts es).rows,
      declaredEff P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) e := by
  intro e he
  obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
  rw [Eff.shiftTypes_of_wf_zero (h.rowWF f hf)]
  exact (h.rowAnnotations f hf).closed_context.declared.2.2

theorem Ty.Declared.substAt {P B} {Ψ : StoreTy} {C0 C1 Γ a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ a) :
    Ty.Declared P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (a.substAt C1.length ts es) :=
  (declared_raw ha.declared hf.1 hf.2.1.variance
    (declMap_bindTypes Γ _ (typeEnvAt_ordinary _ _ _ hi.typeKinds.ordinary)) rfl rfl
    hi.typeKinds.typeEnvAt (closed_type_decl hi) (closed_row_decl hi)).norm

theorem Tel.Declared.substAt {P B} {Ψ : StoreTy} {C0 C1 Γ t ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ (.dependentFn t)) :
    Tel.Declared P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (t.substAt C1.length ts es) :=
  (declared_raw_tel ha.declared hf.1 hf.2.1.variance
    (declMap_bindTypes Γ _ (typeEnvAt_ordinary _ _ _ hi.typeKinds.ordinary)) rfl rfl
    hi.typeKinds.typeEnvAt (closed_type_decl hi) (closed_row_decl hi)).norm

theorem declaredTys_substAt {P B} {Ψ : StoreTy} {C0 C1 Γ as ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (ha : TypeAnnotations P (C1 ++ C0) Γ as) :
    declaredTys P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (as.map (Ty.substAt C1.length ts es)) := by
  apply declared_list_iff.mpr
  intro a hm
  obtain ⟨b, hb, rfl⟩ := List.mem_map.mp hm
  exact Ty.Declared.substAt hf hi (ha b hb)

theorem declaredEff_substAt {P B} {Ψ : StoreTy} {C0 C1 Γ e ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (ha : RowAnnotations P (C1 ++ C0) Γ [e]) :
    declaredEff P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (Eff.substAt C1.length ts es e) :=
  declaredEff_norm (declared_raw_eff (ha e (by simp)).declared.2.2 hf.1 hf.2.1.variance
    (declMap_bindTypes Γ _ (typeEnvAt_ordinary _ _ _ hi.typeKinds.ordinary)) rfl rfl
    hi.typeKinds.typeEnvAt (closed_type_decl hi) (closed_row_decl hi))

private theorem declMap_sortMap {Γ Δ θ} (hm : DeclMap Γ Δ θ) : SortMap Γ Δ := by
  constructor
  intro i a hi
  obtain ⟨b, hb, he⟩ := hm.lookup i a hi
  exact ⟨b, hb, fun s hs => (Ty.hasSort_norm _ _).mp (he.symm ▸ Ty.hasSort_bind hs θ),
    fun ho => (Ty.ordinary_norm _).mp (he.symm ▸ Ty.ordinary_bind ho θ hm.ordinary)⟩

private theorem sorted_apply {P D Δ a n as} (hk : Ty.HasKind P (TypeCtx.kinds D) a (.constructor n))
    (hn : as.length = n) (hs : sortedTys Δ as) : Ty.Sorted Δ (rawApply a as) := by
  have hp := rawApply_proper hk hn
  cases hp with
  | «variable» i as => exact hs
  | list a | set a | reference a | lazy a => exact hs.1
  | map a b => exact ⟨hs.1, hs.2.1⟩
  | data d as => exact hs

private theorem sorted_list_iff {Γ as} : sortedTys Γ as ↔ ∀ a ∈ as, Ty.Sorted Γ a := by
  induction as with
  | nil => simp [sortedTys]
  | cons a as ih => simp [sortedTys, ih]

mutual
  private theorem sorted_raw {P C D Γ Δ a θ} (h : Ty.Sorted Γ a) (hd : Ty.Declared P C Γ a)
      (hm : DeclMap Γ Δ θ) (hv : θ.values = fun i => some (.var i))
      (hk : TypeImagesKinded P (TypeCtx.kinds C) (TypeCtx.kinds D) θ.types)
      (ht : ∀ i, Ty.Sorted Δ (θ.types i)) (he : ∀ e ∈ θ.rows, sortedEff Δ e) :
      Ty.Sorted Δ (a.rawBind θ) := by
    cases a <;> dsimp only [Ty.Sorted, Ty.Declared, Ty.rawBind] at h hd ⊢
    all_goals first | trivial | exact sorted_raw h hd hm hv hk ht he | skip
    case data _ _ => exact sorted_raw_tys h hd.2 hm hv hk ht he
    case external _ _ => exact sorted_raw_tys h hd.2 hm hv hk ht he
    case tvar i => exact ht i
    case fn _ _ _ _ => exact ⟨sorted_raw_tys h.1 hd.1 hm hv hk ht he,
        sorted_raw h.2.1 hd.2.1 hm hv hk ht he, sorted_raw_eff h.2.2 hd.2.2 hm hv hk ht he⟩
    case cont _ _ _ => exact ⟨sorted_raw h.1 hd.1 hm hv hk ht he,
        sorted_raw h.2.1 hd.2.1 hm hv hk ht he, sorted_raw_eff h.2.2 hd.2.2 hm hv hk ht he⟩
    case map _ _ => exact ⟨sorted_raw h.1 hd.1 hm hv hk ht he, sorted_raw h.2 hd.2 hm hv hk ht he⟩
    case tapp i as =>
      exact sorted_apply (hk i _ hd.1).1
        (by simp only [rawBindTys_eq_map, List.length_map]) (sorted_raw_tys h hd.2 hm hv hk ht he)
    case refined a p =>
      refine ⟨sorted_raw h.1 hd.1 hm hv hk ht he, ?_⟩
      simp only [hv, upValues_id, predBind_id]
      exact Pred.Sorted.sortMap (declMap_sortMap hm) h.2
        (fun _ hs => Ty.hasSort_rawBind hs θ) (fun ho => Ty.ordinary_rawBind ho θ hm.ordinary)
    case dependentFn _ => exact sorted_raw_tel h hd hm hv hk ht he
  private theorem sorted_raw_tys {P C D Γ Δ as θ} (h : sortedTys Γ as) (hd : declaredTys P C Γ as)
      (hm : DeclMap Γ Δ θ) (hv : θ.values = fun i => some (.var i))
      (hk : TypeImagesKinded P (TypeCtx.kinds C) (TypeCtx.kinds D) θ.types)
      (ht : ∀ i, Ty.Sorted Δ (θ.types i)) (he : ∀ e ∈ θ.rows, sortedEff Δ e) :
      sortedTys Δ (rawBindTys θ as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨sorted_raw h.1 hd.1 hm hv hk ht he, sorted_raw_tys h.2 hd.2 hm hv hk ht he⟩
  private theorem sorted_raw_eff {P C D Γ Δ e θ} (h : sortedEff Γ e) (hd : declaredEff P C Γ e)
      (hm : DeclMap Γ Δ θ) (hv : θ.values = fun i => some (.var i))
      (hk : TypeImagesKinded P (TypeCtx.kinds C) (TypeCtx.kinds D) θ.types)
      (ht : ∀ i, Ty.Sorted Δ (θ.types i)) (he : ∀ e ∈ θ.rows, sortedEff Δ e) :
      sortedEff Δ (Eff.rawBind θ e) := by
    cases e
    apply sorted_list_iff.mpr
    intro a ha
    rcases List.mem_append.mp ha with ha | ha
    · exact sorted_list_iff.mp (sorted_raw_tys h hd hm hv hk ht he) a ha
    · obtain ⟨i, e, he', _, ha⟩ := Eff.mem_rowFails.mp ha
      cases e with
      | mk ats fs => exact sorted_list_iff.mp (he _ (List.mem_of_getElem? he')) a ha
  private theorem sorted_raw_tel {P C D Γ Δ t θ} (h : Tel.Sorted Γ t) (hd : Tel.Declared P C Γ t)
      (hm : DeclMap Γ Δ θ) (hv : θ.values = fun i => some (.var i))
      (hk : TypeImagesKinded P (TypeCtx.kinds C) (TypeCtx.kinds D) θ.types)
      (ht : ∀ i, Ty.Sorted Δ (θ.types i)) (he : ∀ e ∈ θ.rows, sortedEff Δ e) :
      Tel.Sorted Δ (Tel.rawBind θ t) := by
    cases t with
    | done r e => exact ⟨sorted_raw h.1 hd.1 hm hv hk ht he, sorted_raw_eff h.2 hd.2 hm hv hk ht he⟩
    | param n a t =>
      refine ⟨sorted_raw h.1 hd.1 hm hv hk ht he, ?_⟩
      apply sorted_raw_tel h.2 hd.2 (declMap_extend hm a (a.rawBind θ) rfl)
        (by simp [SubstEnv.up, hv, upValues_id])
      · intro i k hi
        exact ⟨(hk i k hi).1.shift_values 1 0,
          fun h => (Ty.ordinary_shiftV _ _ _).mpr ((hk i k hi).2 h)⟩
      · intro i; exact (ht i).shift_outer _
      · intro e he'
        obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he'
        cases f with
        | mk ats fs =>
          apply sorted_list_iff.mpr
          intro t ht'
          obtain ⟨b, hb, rfl⟩ := List.mem_map.mp (by simpa only [Eff.shiftV, shiftVTys_eq_map] using ht')
          exact (sorted_list_iff.mp (he _ hf) b hb).shift_outer _
end

private theorem closed_type_sorted {P B C0 C1 Γ ts es}
    (h : ClosedTypeSubstInput P B C0 C1 Γ ts es) :
    ∀ i, Ty.Sorted (Γ.bindTypes (typeEnvAt C1.length ts es))
      ((typeEnvAt C1.length ts es).types i) := by
  intro i
  simp only [typeEnvAt]
  split
  · trivial
  · split
    · rename_i hi
      simp only [List.getElem?_eq_getElem hi, Option.getD_some]
      rw [Ty.shiftTypes_of_wf_zero (h.typeWF _ (List.getElem_mem hi))]
      exact (h.typeAnnotations _ (List.getElem_mem hi)).sorted.closed_context
    · trivial

private theorem closed_row_sorted {P B C0 C1 Γ ts es}
    (h : ClosedTypeSubstInput P B C0 C1 Γ ts es) :
    ∀ e ∈ (typeEnvAt C1.length ts es).rows,
      sortedEff (Γ.bindTypes (typeEnvAt C1.length ts es)) e := by
  intro e he
  obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
  rw [Eff.shiftTypes_of_wf_zero (h.rowWF f hf)]
  exact (h.rowAnnotations f hf).sorted.closed_context.2.2

theorem Ty.Annotation.substAt {P B} {Ψ : StoreTy} {C0 C1 Γ a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ a) :
    Ty.Annotation P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (a.substAt C1.length ts es) := by
  refine ⟨?_, ?_, Ty.Declared.substAt hf hi ha⟩
  · have h := Ty.substAt_wf (nr := 0) (n := 0) (nv := Γ.length) C1.length ts es
      (fun t ht => (hi.typeWF t ht).closed_context (C := []) (Γ := Γ))
      (fun e he => ((hi.rowAnnotations e he).closed_context (C := []) (Γ := Γ)).wf.2.2.2.1)
      hi.typeKinds.ordinary a (by simpa only [List.length_append, hi.typeCount] using ha.wf)
    simpa only [Ctx.bindTypes, List.length_map, Nat.zero_add] using h
  · exact Ty.sorted_norm (sorted_raw ha.sorted ha.declared
      (declMap_bindTypes Γ _ (typeEnvAt_ordinary _ _ _ hi.typeKinds.ordinary)) rfl
      hi.typeKinds.typeEnvAt (closed_type_sorted hi) (closed_row_sorted hi))

theorem TypeAnnotations.substAt {P B} {Ψ : StoreTy} {C0 C1 Γ as ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (ha : TypeAnnotations P (C1 ++ C0) Γ as) :
    TypeAnnotations P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (as.map (Ty.substAt C1.length ts es)) := by
  intro a hm
  obtain ⟨b, hb, rfl⟩ := List.mem_map.mp hm
  exact (ha b hb).substAt hf hi

theorem RowAnnotations.substAt {P B} {Ψ : StoreTy} {C0 C1 Γ fs ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (ha : RowAnnotations P (C1 ++ C0) Γ fs) :
    RowAnnotations P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (fs.map (Eff.substAt C1.length ts es)) := by
  intro e hm
  obtain ⟨f, hf', rfl⟩ := List.mem_map.mp hm
  have hh := (ha f hf').substAt hf hi
  simpa only [Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys,
    Ty.normTys, Eff.substAt, substRowAt, Eff.bind] using hh

private theorem closed_raw_nil {a : Ty} (hw : a.WF 0 0 0) (c : Nat) (ts : List Ty) :
    a.rawBind (typeEnvAt c ts []) = a := by
  have h := Ty.rawBind_agrees (θ := typeEnvAt c ts []) (τ := renEnv id) hw
    ⟨by intro i hi; omega, rfl, rfl, rfl⟩
  simpa only [Ty.rawBind_id] using h

private theorem closed_eff_raw_nil {e : Eff} (hw : e.WF 0 0 0) (c : Nat) (ts : List Ty) :
    Eff.rawBind (typeEnvAt c ts []) e = e := by
  have h := Eff.rawBind_agrees (θ := typeEnvAt c ts []) (τ := renEnv id) hw
    ⟨by intro i hi; omega, rfl, rfl, rfl⟩
  simpa only [Eff.rawBind_id] using h

private theorem closed_subst_nil {a : Ty} (hw : a.WF 0 0 0) (c : Nat) (ts : List Ty) :
    a.substAt c ts [] = a.norm := congrArg Ty.norm (closed_raw_nil hw c ts)

private theorem declared_closed_nil {P B} {Ψ : StoreTy} {C0 C1 Γ a ts}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts []) (hw : a.WF 0 0 0)
    (hd : Ty.Declared P (C1 ++ C0) Γ a) :
    Ty.Declared P C1 (Γ.bindTypes (typeEnvAt C1.length ts [])) a := by
  have h := declared_raw hd hf.1 hf.2.1.variance
    (declMap_bindTypes Γ _ (typeEnvAt_ordinary _ _ _ hi.typeKinds.ordinary)) rfl rfl
    hi.typeKinds.typeEnvAt (closed_type_decl hi) (closed_row_decl hi)
  rwa [closed_raw_nil hw] at h

theorem HasTypeVQ.type_subst_locRef {P B} {Ψ : StoreTy} {Q C0 C1 Γ Φ l a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (hc : TypeSubstCode es (fun nr nt ne nv => (Val.loc l).SourceScoped nr nt ne nv))
    (hl : Ψ l = some (.ref a)) (hd : Ty.Declared P (C1 ++ C0) Γ a) :
    HasTypeVQ P B Ψ Q C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ (.loc l)
      ((Ty.reference a).substAt C1.length ts es) := by
  have he : es = [] := hc.resolve_right (by rintro ⟨nr, nt, ne, nv, h⟩; exact h)
  subst es
  have hw := hf.2.2.2 l _ hl
  rw [closed_subst_nil (a := .reference a) hw C1.length ts]
  exact .V_Normal (.V_LocRef hl (declared_closed_nil hf hi hw hd))

theorem HasTypeVQ.type_subst_locLazy {P B} {Ψ : StoreTy} {Q C0 C1 Γ Φ l a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (hc : TypeSubstCode es (fun nr nt ne nv => (Val.loc l).SourceScoped nr nt ne nv))
    (hl : Ψ l = some (.lazy a)) (hd : Ty.Declared P (C1 ++ C0) Γ a) :
    HasTypeVQ P B Ψ Q C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ (.loc l)
      ((Ty.lazy a).substAt C1.length ts es) := by
  have he : es = [] := hc.resolve_right (by rintro ⟨nr, nt, ne, nv, h⟩; exact h)
  subst es
  have hw := hf.2.2.2 l _ hl
  rw [closed_subst_nil (a := .lazy a) hw C1.length ts]
  exact .V_Normal (.V_LocLazy hl (declared_closed_nil hf hi hw hd))

theorem HasTypeCQ.type_subst_resumeL {P B} {Ψ : StoreTy} {Q C0 C1 Γ Φ R L l v b t e ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (hc : TypeSubstCode es (fun nr nt ne nv => (Comp.resume (.loc l) v).SourceScoped nr nt ne nv))
    (hl : Ψ l = some (.cont b t e R)) (hd : Ty.Declared P (C1 ++ C0) Γ t)
    (hv : HasTypeVQ P B Ψ Q C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (v.substTyAt C1.length ts es) (b.substAt C1.length ts es)) :
    HasTypeCQ P B Ψ Q C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (R.map (Ty.substAt C1.length ts es)) (.resume (.loc l) (v.substTyAt C1.length ts es))
      (t.substAt C1.length ts es) (Eff.substAt C1.length ts es e) L := by
  have he : es = [] := hc.resolve_right (by rintro ⟨nr, nt, ne, nv, h⟩; exact h.1)
  subst es
  have hw := hf.2.2.2 l _ hl
  have hb : b.substAt C1.length ts [] = b.norm := closed_subst_nil hw.1 _ _
  have ht : t.substAt C1.length ts [] = t.norm := closed_subst_nil hw.2.1 _ _
  have he : Eff.substAt C1.length ts [] e = e.norm :=
    congrArg Eff.norm (closed_eff_raw_nil hw.2.2.1 _ _)
  rw [ht, he]
  refine .C_ResumeLNorm hl ?_ (hb ▸ hv) ?_
  · cases R with
    | none => rfl
    | some a =>
      simp only [Option.map_some]
      rw [closed_subst_nil (hw.2.2.2.2 a rfl), Ty.norm_idem]
  · exact (declared_closed_nil hf hi hw.2.1 hd).norm

theorem HasTypeVQ.type_subst_closure {P B} {Ψ : StoreTy} {Q C0 C1 Γ Φ runtime body t ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : ClosedTypeSubstInput P B C0 C1 Γ ts es)
    (hc : TypeSubstCode es (fun nr nt ne nv => (Val.closure runtime body).SourceScoped nr nt ne nv))
    (ha : Ty.Annotation P (C1 ++ C0) Γ (.dependentFn t))
    (hr : Tel.RuntimeShape runtime t) (hb : DependentClosureTy P B Ψ body t) :
    HasTypeVQ P B Ψ Q C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ (.closure runtime body)
      ((Ty.dependentFn t).substAt C1.length ts es) := by
  have he : es = [] := hc.resolve_right (by rintro ⟨nr, nt, ne, nv, h⟩; exact h)
  subst es
  have hw : (Ty.dependentFn t).WF 0 0 0 := hr.contract_wf
  have hs := sorted_raw ha.sorted ha.declared
    (declMap_bindTypes Γ _ (typeEnvAt_ordinary _ _ _ hi.typeKinds.ordinary)) rfl
    hi.typeKinds.typeEnvAt (closed_type_sorted hi) (closed_row_sorted hi)
  rw [closed_raw_nil hw] at hs
  have hd := declared_closed_nil hf hi hw ha.declared
  have hann : Ty.Annotation P C1 (Γ.bindTypes (typeEnvAt C1.length ts [])) (.dependentFn t) :=
    ⟨hw.closed_context, hs, hd⟩
  rw [closed_subst_nil hw]
  exact .V_Normal (.V_Closure hann hr hb)

noncomputable section
open Order

private theorem apply_absorb (t : Ty) (xs ys : List Ty) :
    rawApply (rawApply t xs) ys = rawApply t xs := by
  cases t <;> try rfl
  case ctor c => cases c <;> rfl
  case refined t p => simpa only [rawApply] using congrArg (fun a => Ty.refined a p) (apply_absorb t xs ys)

private theorem apply_bind (a : Ty) (as : List Ty) (θ : SubstEnv) :
    (rawApply a as).rawBind θ = rawApply (a.rawBind θ) (rawBindTys θ as) := by
  cases a <;> try rfl
  case ctor c =>
    cases c <;> cases as <;> simp [rawApply,Ty.rawBind,rawBindTys]
    rename_i a as
    cases as <;> rfl
  case refined a p => simp only [rawApply,Ty.rawBind,apply_bind a as θ]
  case tapp i bs =>
    simpa only [rawApply,Ty.rawBind] using (apply_absorb (θ.types i) _ _).symm

private def compose (σ τ : SubstEnv) : SubstEnv :=
  ⟨fun i => (σ.types i).bind τ, σ.rows.map (Eff.bind τ), [], fun i => some (.var i)⟩

private theorem compose_up (σ τ : SubstEnv) :
    compose σ.up τ.up = (compose σ τ).up := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1
  · funext i; exact Ty.bind_up _ _
  · simp only [compose,SubstEnv.up_rows,List.map_map,Function.comp_def]
    apply List.map_congr_left
    intro e he; exact Eff.bind_up e τ
  · exact upValues_id.symm

private theorem mem_bind (θ : SubstEnv) (hr : θ.ranges = []) (e : Eff) (x : Atom) :
    (Eff.bind θ e).mem x ↔
    (match x with
      | .name l r => e.mem (.name l r)
      | .rho i => θ.rows.length ≤ i ∧ e.mem (.rho i)) ∨
    ∃ i f, θ.rows[i]? = some f ∧ e.mem (.rho i) ∧ f.mem x := by
  rw [Eff.bind,Eff.mem_norm]
  cases e with
  | mk a fs =>
    change substAtoms θ.rows (instAtoms θ.ranges a) x = true ↔ _
    rw [hr,instAtoms_nil]
    exact Eff.mem_substAtoms θ.rows (.mk a fs) x

private theorem mem_comp (σ τ : SubstEnv) (hs : σ.ranges = []) (ht : τ.ranges = [])
    (e : Eff) (hr : e.RowsIn (· < σ.rows.length)) (x : Atom) :
    (Eff.bind τ (Eff.bind σ e)).mem x ↔ (Eff.bind (compose σ τ) e).mem x := by
  have bound : ∀ i, e.mem (.rho i) → i < σ.rows.length := by cases e; exact hr.1
  have first : ∀ x, (Eff.bind σ e).mem x ↔
      (match x with | .name l r => e.mem (.name l r) | .rho _ => False) ∨
      ∃ i f, σ.rows[i]? = some f ∧ e.mem (.rho i) ∧ f.mem x := by
    intro x; rw [mem_bind σ hs]
    cases x <;> simp only
    constructor
    · rintro (⟨h,h'⟩ | h)
      · exact False.elim (by have := bound _ h'; omega)
      · exact Or.inr h
    · rintro (h | h); contradiction; exact Or.inr h
  rw [mem_bind τ ht,mem_bind (compose σ τ) rfl]
  simp only [compose,List.length_map,List.getElem?_map,Option.map_eq_some_iff]
  simp only [first]
  cases x with
  | name l r =>
    simp only [false_or] 
    constructor
    · rintro ((h | ⟨i,f,hf,hi,hx⟩) | ⟨j,g,hg,⟨i,f,hf,hi,hj⟩,hx⟩)
      · exact Or.inl h
      · exact Or.inr ⟨i,_,⟨f,hf,rfl⟩,hi,(mem_bind τ ht f _).mpr (Or.inl hx)⟩
      · exact Or.inr ⟨i,_,⟨f,hf,rfl⟩,hi,(mem_bind τ ht f _).mpr (Or.inr ⟨j,g,hg,hj,hx⟩)⟩
    · rintro (h | ⟨i,_,⟨f,hf,rfl⟩,hi,hx⟩)
      · exact Or.inl (Or.inl h)
      · rcases (mem_bind τ ht f _).mp hx with hx | ⟨j,g,hg,hj,hx⟩
        · exact Or.inl (Or.inr ⟨i,f,hf,hi,hx⟩)
        · exact Or.inr ⟨j,g,hg,⟨i,f,hf,hi,hj⟩,hx⟩
  | rho j =>
    simp only [false_or]
    constructor
    · rintro (⟨hj,⟨i,f,hf,hi,hx⟩⟩ | ⟨k,g,hg,⟨i,f,hf,hi,hk⟩,hx⟩)
      · exact Or.inr ⟨i,_,⟨f,hf,rfl⟩,hi,(mem_bind τ ht f _).mpr (Or.inl ⟨hj,hx⟩)⟩
      · exact Or.inr ⟨i,_,⟨f,hf,rfl⟩,hi,(mem_bind τ ht f _).mpr (Or.inr ⟨k,g,hg,hk,hx⟩)⟩
    · rintro (⟨hj,he⟩ | ⟨i,_,⟨f,hf,rfl⟩,hi,hx⟩)
      · exact False.elim (by have := bound j he; omega)
      · rcases (mem_bind τ ht f _).mp hx with ⟨hj,hx⟩ | ⟨k,g,hg,hk,hx⟩
        · exact Or.inl ⟨hj,⟨i,f,hf,hi,hx⟩⟩
        · exact Or.inr ⟨k,g,hg,⟨i,f,hf,hi,hk⟩,hx⟩

private theorem fail_bind (θ : SubstEnv) (e : Eff) (t : Ty) :
    (Eff.bind θ e).memFail t ↔
    (∃ x, e.memFail x ∧ x.bind θ = t.norm) ∨
    ∃ i f, θ.rows[i]? = some f ∧ e.mem (.rho i) ∧ f.memFail t := by
  rw [Eff.bind,Eff.norm_memFail,Eff.memFail_rawBind]
  constructor
  · rintro (⟨x,hx,he⟩ | ⟨i,f,x,hf,hi,hx,he⟩)
    · exact Or.inl ⟨x,⟨x,hx,rfl⟩,he⟩
    · exact Or.inr ⟨i,f,hf,hi,⟨x,hx,he⟩⟩
  · rintro (⟨x,⟨y,hy,he⟩,hx⟩ | ⟨i,f,hf,hi,x,hx,he⟩)
    · exact Or.inl ⟨y,hy,(Ty.rawBind_norm_congr θ he).trans hx⟩
    · exact Or.inr ⟨i,f,x,hf,hi,hx,he⟩

private theorem bind_congr {a b : Ty} (h : a.norm = b.norm) (θ : SubstEnv) :
    a.bind θ = b.bind θ := Ty.rawBind_norm_congr θ h

private theorem fail_comp (σ τ : SubstEnv) (hs : σ.ranges = [])
    (e : Eff) (hr : e.RowsIn (· < σ.rows.length))
    (ih : ∀ x, e.memFail x → (x.bind σ).bind τ = x.bind (compose σ τ)) (t : Ty) :
    (Eff.bind τ (Eff.bind σ e)).memFail t ↔ (Eff.bind (compose σ τ) e).memFail t := by
  have first : ∀ j, (Eff.bind σ e).mem (.rho j) ↔
      ∃ i f, σ.rows[i]? = some f ∧ e.mem (.rho i) ∧ f.mem (.rho j) := by
    intro j
    rw [mem_bind σ hs]
    constructor
    · rintro (⟨hj,he⟩ | h)
      · have bound : j < σ.rows.length := by cases e; exact hr.1 j he
        omega
      · exact h
    · exact Or.inr
  rw [fail_bind τ,fail_bind (compose σ τ)]
  simp only [compose,List.getElem?_map,Option.map_eq_some_iff]
  constructor
  · rintro (⟨x,hx,he⟩ | ⟨j,g,hg,hj,hx⟩)
    · rcases (fail_bind σ e x).mp hx with ⟨y,hy,hey⟩ | ⟨i,f,hf,hi,hx⟩
      · left; refine ⟨y,hy,?_⟩
        change y.bind (compose σ τ) = t.norm
        rw [←ih y hy]
        exact (bind_congr (by rw [hey,Ty.norm_idem]) τ).trans he
      · right
        exact ⟨i,_,⟨f,hf,rfl⟩,hi,(fail_bind τ f t).mpr (Or.inl ⟨x,hx,he⟩)⟩
    · obtain ⟨i,f,hf,hi,hj⟩ := (first j).mp hj
      exact Or.inr ⟨i,_,⟨f,hf,rfl⟩,hi,(fail_bind τ f t).mpr (Or.inr ⟨j,g,hg,hj,hx⟩)⟩
  · rintro (⟨y,hy,he⟩ | ⟨i,_,⟨f,hf,rfl⟩,hi,hx⟩)
    · left
      refine ⟨y.bind σ,(fail_bind σ e _).mpr (Or.inl ⟨y,hy,(Ty.norm_idem _).symm⟩),?_⟩
      exact (ih y hy).trans he
    · rcases (fail_bind τ f t).mp hx with ⟨x,hx,he⟩ | ⟨j,g,hg,hj,hx⟩
      · exact Or.inl ⟨x,(fail_bind σ e _).mpr (Or.inr ⟨i,f,hf,hi,hx⟩),he⟩
      · exact Or.inr ⟨j,g,hg,(first j).mpr ⟨i,f,hf,hi,hj⟩,hx⟩

private theorem eff_ext (e f : Eff) (hn : e.norm = e) (hm : f.norm = f)
    (ha : ∀ x, e.mem x ↔ f.mem x) (hf : ∀ t, e.memFail t ↔ f.memFail t) : e = f := by
  suffices e.norm = f.norm from hn.symm.trans (this.trans hm)
  cases e with
  | mk a es => cases f with
    | mk b fs =>
      change EffR.mk a (sortUnique tyCompare (Ty.normTys es)) =
        EffR.mk b (sortUnique tyCompare (Ty.normTys fs))
      congr 1
      · funext x; exact Bool.eq_iff_iff.mpr (ha x)
      · apply sortUnique_eq_iff_mem.mpr
        intro t
        simp only [Ty.normTys_eq_map,List.mem_map]
        constructor
        · rintro ⟨x,hx,rfl⟩
          obtain ⟨y,hy,he⟩ := (hf x.norm).mp ⟨x,hx,(Ty.norm_idem _).symm⟩
          exact ⟨y,hy,he.trans (Ty.norm_idem _)⟩
        · rintro ⟨x,hx,rfl⟩
          obtain ⟨y,hy,he⟩ := (hf x.norm).mpr ⟨x,hx,(Ty.norm_idem _).symm⟩
          exact ⟨y,hy,he.trans (Ty.norm_idem _)⟩

mutual
  private theorem comp_ty (a : Ty) (σ τ : SubstEnv)
      (hs : σ.ranges = []) (ht : τ.ranges = [])
      (hv : σ.values = fun i => some (.var i)) (hu : τ.values = fun i => some (.var i))
      (hr : a.RowsIn (· < σ.rows.length)) :
      ((a.rawBind σ).rawBind τ).norm = (a.rawBind (compose σ τ)).norm := by
    cases a <;> simp only [Ty.RowsIn] at hr <;> simp only [Ty.rawBind,Ty.norm]
    all_goals try rfl
    case tvar i => exact (Ty.norm_idem _).symm
    case «opaque» o ix => simp [hs,ht,compose,RangeIx.inst_nil]
    case «scoped» o k ix => simp [hs,ht,compose,RangeIx.inst_nil]
    case fn ns ps r e => rw [comp_tys ps σ τ hs ht hv hu hr.1,comp_ty r σ τ hs ht hv hu hr.2.1,comp_eff e σ τ hs ht hv hu hr.2.2]; rfl
    case cont b t e => rw [comp_ty b σ τ hs ht hv hu hr.1,comp_ty t σ τ hs ht hv hu hr.2.1,comp_eff e σ τ hs ht hv hu hr.2.2]; rfl
    case map a b => rw [comp_ty a σ τ hs ht hv hu hr.1,comp_ty b σ τ hs ht hv hu hr.2]
    case tapp i as =>
      rw [apply_bind]
      rw [←rawApply_norm,←rawApply_norm (compose σ τ |>.types i)]
      rw [comp_tys as σ τ hs ht hv hu hr]
      simp only [compose,Ty.bind,Ty.norm_idem]
    case refined a p =>
      simp only [hv,hu,compose,upValues_id,predBind_id]
      rw [comp_ty a σ τ hs ht hv hu hr]
      rfl
    case dependentFn t => rw [comp_tel t σ τ hs ht hv hu hr]
    all_goals first
      | rw [comp_ty _ σ τ hs ht hv hu hr]
      | rw [comp_tys _ σ τ hs ht hv hu hr]
  termination_by sizeOf a
  private theorem comp_tys (as : List Ty) (σ τ : SubstEnv)
      (hs : σ.ranges = []) (ht : τ.ranges = [])
      (hv : σ.values = fun i => some (.var i)) (hu : τ.values = fun i => some (.var i))
      (hr : Ty.RowsInList (· < σ.rows.length) as) :
      Ty.normTys (rawBindTys τ (rawBindTys σ as)) = Ty.normTys (rawBindTys (compose σ τ) as) := by
    cases as with
    | nil => rfl
    | cons a as => simp only [rawBindTys,Ty.normTys,comp_ty a σ τ hs ht hv hu hr.1,comp_tys as σ τ hs ht hv hu hr.2]
  termination_by sizeOf as
  private theorem comp_tel (t : Tel) (σ τ : SubstEnv)
      (hs : σ.ranges = []) (ht : τ.ranges = [])
      (hv : σ.values = fun i => some (.var i)) (hu : τ.values = fun i => some (.var i))
      (hr : t.RowsIn (· < σ.rows.length)) :
      Tel.norm (Tel.rawBind τ (Tel.rawBind σ t)) = Tel.norm (Tel.rawBind (compose σ τ) t) := by
    cases t with
    | done r e =>
      simp only [Tel.rawBind,Tel.norm,comp_ty r σ τ hs ht hv hu hr.1,comp_eff e σ τ hs ht hv hu hr.2]
      rfl
    | param n a t =>
      have hr' : t.RowsIn (· < σ.up.rows.length) := by simpa using hr.2
      simp only [Tel.rawBind,Tel.norm,comp_ty a σ τ hs ht hv hu hr.1]
      rw [comp_tel t σ.up τ.up (by simpa using hs) (by simpa using ht)
        (by simp [hv,upValues_id]) (by simp [hu,upValues_id]) hr',compose_up]
  termination_by sizeOf t
  private theorem comp_eff (e : Eff) (σ τ : SubstEnv)
      (hs : σ.ranges = []) (ht : τ.ranges = [])
      (hv : σ.values = fun i => some (.var i)) (hu : τ.values = fun i => some (.var i))
      (hr : e.RowsIn (· < σ.rows.length)) :
      Eff.norm (Eff.rawBind τ (Eff.rawBind σ e)) = Eff.bind (compose σ τ) e := by
    have heq : Eff.bind τ (Eff.bind σ e) = Eff.bind (compose σ τ) e := by
      apply eff_ext _ _ (Eff.norm_idem _) (Eff.norm_idem _)
      · exact mem_comp σ τ hs ht e hr
      · apply fail_comp σ τ hs e hr
        intro x hx
        obtain ⟨y,hy,he⟩ := hx
        have hyr : y.RowsIn (· < σ.rows.length) := by
          cases e with
          | mk ats fs => exact Ty.RowsInList.iff.mp hr.2 y hy
        have hh := comp_ty y σ τ hs ht hv hu hyr
        change ((y.rawBind σ).rawBind τ).norm = (y.rawBind (compose σ τ)).norm at hh
        have hb : (y.bind σ).bind τ = y.bind (compose σ τ) := by
          simpa only [Ty.bind,Ty.norm_rawBind] using hh
        exact ((congrArg (Ty.bind τ) (bind_congr he σ)).symm.trans hb).trans (bind_congr he (compose σ τ))
    simpa only [Eff.bind,Eff.norm_rawBind] using heq
  termination_by sizeOf e
  decreasing_by
    cases e with
    | mk ats fs =>
      have hlt := List.sizeOf_lt_of_mem hy
      simp_all only [Eff.fails,EffR.mk.sizeOf_spec]
      omega
end

theorem instantiatedTel_substAt {nt : Nat} {t : Tel}
    (hw : (Ty.dependentFn t).WF 0 nt 0)
    (ts : List Ty) (es : List Eff) (hn : nt ≤ ts.length)
    (hr : t.RowsIn (· < es.length)) (c : Nat) (us : List Ty) (fs : List Eff) :
    Tel.substAt c us fs (instantiatedTel t ts es) =
      instantiatedTel t (ts.map (Ty.substAt c us fs)) (es.map (Eff.substAt c us fs)) := by
  change Tel.norm (Tel.rawBind (typeEnvAt c us fs) (Tel.norm (Tel.rawBind (typeEnvAt 0 ts es) t))) = _
  rw [Tel.norm_rawBind,comp_tel t (typeEnvAt 0 ts es) (typeEnvAt c us fs) rfl rfl rfl rfl
    (by simpa only [typeEnvAt,List.length_map] using hr)]
  apply congrArg Tel.norm
  apply Tel.rawBind_agrees hw
  constructor
  · intro i hi
    have hit : i < ts.length := by omega
    simp only [compose,typeEnvAt,List.length_map,Nat.not_lt_zero,↓reduceIte,Nat.sub_zero,
      hit,List.getElem?_map,shiftTypes_zero]
    cases hg : ts[i]? with
    | none => exact False.elim (by have := List.getElem?_eq_none_iff.mp hg; omega)
    | some a => simp only [Option.getD_some,Option.map_some]; rfl
  · simp only [compose,typeEnvAt,List.map_map]
    apply List.map_congr_left
    intro e he
    simp only [Function.comp_def,shiftRowsTypes_zero]
    rfl
  · rfl
  · rfl

end

end Benitoite.Release.Refinement
