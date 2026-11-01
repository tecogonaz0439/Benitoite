import Benitoite.Release.Refinement.VarianceValidation
import Benitoite.Release.Refinement.AdmissibleMap
import Benitoite.Release.Refinement.VarianceFormation

namespace Benitoite.Release.Refinement
set_option maxHeartbeats 1000000

theorem Ty.LeQ.dataCore {P Γ Φ a b d as} (h : Ty.LeQ P Γ Φ a b)
    (hd : a.norm.core = .data d as) :
    ∃ bs, b.norm.core = .data d bs ∧ TypeArgsLe P Γ Φ (P.varianceFor d as.length) as bs := by
  match h with
  | .refl => exact ⟨as, hd, .refl _ _ (P.varianceFor_length d as.length).symm⟩
  | .convert he => exact ⟨as, he ▸ hd, .refl _ _ (P.varianceFor_length d as.length).symm⟩
  | .trans h g =>
    obtain ⟨ms, hm, hs⟩ := h.dataCore hd
    obtain ⟨bs, hb, ht⟩ := g.dataCore hm
    have hl : ms.length = as.length := hs.length.2.trans hs.length.1.symm
    rw [hl] at ht
    exact ⟨bs, hb, hs.trans ht⟩
  | .data hs =>
    simp only [Ty.norm, Ty.core, Ty.data.injEq] at hd
    obtain ⟨rfl, rfl⟩ := hd
    exact ⟨_, rfl, by simpa only [Ty.normTys_eq_map, List.length_map] using hs.norm⟩
  | .forget | .introduce .. => exact ⟨as, by simpa only [Ty.refined_norm_core] using hd,
      .refl _ _ (P.varianceFor_length d as.length).symm⟩
  | .refine h .. =>
    obtain ⟨bs, hb, hs⟩ := h.dataCore (by simpa only [Ty.refined_norm_core] using hd)
    exact ⟨bs, by simpa only [Ty.refined_norm_core] using hb, hs⟩
  | .fn_effect _ | .list _ | .lazy _ | .map_value _ _ | .dependentFn _ | .scoped _ | .scoped_forget =>
    first | exact False.elim (Ty.notDataCore_dependentFn hd) | cases hd

theorem Ty.LeQ.dataCore_source {P Γ Φ a b d bs} (h : Ty.LeQ P Γ Φ a b)
    (hd : b.norm.core = .data d bs) :
    ∃ as, a.norm.core = .data d as ∧ TypeArgsLe P Γ Φ (P.varianceFor d as.length) as bs := by
  match h with
  | .refl => exact ⟨bs, hd, .refl _ _ (P.varianceFor_length d bs.length).symm⟩
  | .convert he => exact ⟨bs, he.symm ▸ hd, .refl _ _ (P.varianceFor_length d bs.length).symm⟩
  | .trans h g =>
    obtain ⟨ms, hm, ht⟩ := g.dataCore_source hd
    obtain ⟨as, ha, hs⟩ := h.dataCore_source hm
    have hl : ms.length = as.length := hs.length.2.trans hs.length.1.symm
    rw [hl] at ht
    exact ⟨as, ha, hs.trans ht⟩
  | .data hs =>
    simp only [Ty.norm, Ty.core, Ty.data.injEq] at hd
    obtain ⟨rfl, rfl⟩ := hd
    exact ⟨_, rfl, by simpa only [Ty.normTys_eq_map, List.length_map] using hs.norm⟩
  | .forget | .introduce .. => exact ⟨bs, by simpa only [Ty.refined_norm_core] using hd,
      .refl _ _ (P.varianceFor_length d bs.length).symm⟩
  | .refine h .. =>
    obtain ⟨as, ha, hs⟩ := h.dataCore_source (by simpa only [Ty.refined_norm_core] using hd)
    exact ⟨as, by simpa only [Ty.refined_norm_core] using ha, hs⟩
  | .fn_effect _ | .list _ | .lazy _ | .map_value _ _ | .dependentFn _ | .scoped _ | .scoped_forget =>
    first | exact False.elim (Ty.notDataCore_dependentFn hd) | cases hd

theorem Ty.LeQ.hasSort_source {P Γ Φ a b sort} (h : Ty.LeQ P Γ Φ a b) (hs : b.HasSort sort) :
    a.HasSort sort := by
  match h with
  | .refl => exact hs
  | .convert he =>
    apply (Ty.hasSort_norm a sort).mp
    rw [he]
    exact (Ty.hasSort_norm b sort).mpr hs
  | .trans h g => exact h.hasSort_source (g.hasSort_source hs)
  | .data _ | .fn_effect _ | .list _ | .lazy _ | .map_value _ _ => exact hs
  | .forget | .introduce .. => exact hs
  | .refine h .. => exact h.hasSort_source hs
  | .dependentFn _ | .scoped _ => exact hs
  | .scoped_forget => cases hs

theorem SortMap.narrow {P Γ Φ a b} (h : Ty.LeQ P Γ Φ b a) : SortMap (Γ.extend a) (Γ.extend b) := by
  constructor
  intro i t hi
  cases i with
  | zero =>
    cases Option.some.inj hi
    exact ⟨_, rfl, fun s hs => (Ty.hasSort_shiftV _ _ _ _).mpr
      (h.hasSort_source ((Ty.hasSort_shiftV _ _ _ _).mp hs)),
      fun ho => (Ty.ordinary_shiftV _ _ _).mpr
        (h.notContCore.mpr ((Ty.ordinary_shiftV _ _ _).mp ho))⟩
  | succ i => exact ⟨t, hi, fun _ hs => hs, fun ho => ho⟩

theorem Ty.LeQ.lift {P Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) (x : Ty) :
    Ty.LeQ P (Γ.extend x) (Φ.map Pred.lift) (a.shiftV 1 0) (b.shiftV 1 0) := by
  apply (h.shiftV 1 0).context
  constructor
  intro i t hi
  cases i with
  | zero => simp [Ctx.shiftV] at hi
  | succ i => exact ⟨t, hi, fun _ hs => hs, fun ho => ho, fun _ hp => hp⟩

theorem TelClosure.sameParam {P Δ Ψ t u} (h : TelClosure P Δ Ψ t u) :
    ∀ {Γ Φ n b}, Δ = Γ.extend b → Ψ = Φ.map Pred.lift →
      TelClosure P Γ Φ (.param n b t) (.param n b u) := by
  match h with
  | .refl => intro Γ Φ n b hc hf; exact .refl
  | .tail h hs =>
    intro Γ Φ n b hc hf
    have ih := h.sameParam (n := n) hc hf
    subst Δ Ψ
    exact .tail ih (.param .refl hs)

theorem TelClosure.param {P Γ Φ n a b t u} (ha : Ty.LeQ P Γ Φ b a)
    (ht : TelClosure P (Γ.extend b) (Φ.map Pred.lift) t u) :
    TelClosure P Γ Φ (.param n a t) (.param n b u) := by
  have hfirst : TelClosure P Γ Φ (.param n a t) (.param n b t) :=
    .tail .refl (.param ha (TelLe.of_norm_eq rfl))
  exact hfirst.trans (ht.sameParam rfl rfl)

inductive TyPairs (R : Ty → Ty → Prop) : List Ty → List Ty → Prop where
  | nil : TyPairs R [] []
  | cons {a b as bs} : R a b → TyPairs R as bs → TyPairs R (a :: as) (b :: bs)

theorem TelClosure.toTel {P Γ Φ ns as bs r s e f}
    (hp : TyPairs (fun a b => Ty.LeQ P Γ Φ b a) as bs)
    (hr : Ty.LeQ P Γ Φ r s) (he : Eff.Covers Γ Φ f e) :
    TelClosure P Γ Φ (Ty.toTel ns as r e) (Ty.toTel ns bs s f) := by
  induction ns generalizing Γ Φ as bs r s e f with
  | nil => exact .tail .refl (.done hr he)
  | cons n ns ih =>
    cases hp with
    | nil => exact .tail .refl (.done hr he)
    | @cons a b as bs ha hs =>
      apply TelClosure.param ha
      apply ih (hr := hr.lift b) (he := he.shiftV 1 0)
      clear ih
      induction hs with
      | nil => exact .nil
      | cons h hs ih => exact .cons (h.lift b) ih

theorem Ty.LeQ.fn {P Γ Φ ns as bs r s e f}
    (hns : NamesWF ns as) (hnt : NamesWF ns bs)
    (hp : TyPairs (fun a b => Ty.LeQ P Γ Φ b a) as bs)
    (hr : Ty.LeQ P Γ Φ r s) (he : Eff.Covers Γ Φ f e) :
    Ty.LeQ P Γ Φ (.fn ns as r e) (.fn ns bs s f) :=
  .trans (.convert (Ty.norm_toTel hns).symm)
    (.trans (.dependentFn (TelClosure.toTel hp hr he)) (.convert (Ty.norm_toTel hnt)))

def Polarity.Rel (P : Program) (Γ : Ctx) (Φ : List Pred) : Polarity → Ty → Ty → Prop
  | .positive, a, b => Ty.LeQ P Γ Φ a b
  | .negative, a, b => Ty.LeQ P Γ Φ b a
  | .both, a, b => a.norm = b.norm

def Polarity.TelRel (P : Program) (Γ : Ctx) (Φ : List Pred) : Polarity → Tel → Tel → Prop
  | .positive, t, u => TelClosure P Γ Φ t u
  | .negative, t, u => TelClosure P Γ Φ u t
  | .both, t, u => Tel.norm t = Tel.norm u

theorem Polarity.Rel.norm {P Γ Φ} {p : Polarity} {a b : Ty} (h : p.Rel P Γ Φ a b) : p.Rel P Γ Φ a.norm b.norm := by
  cases p
  · exact Ty.LeQ.norm h
  · exact Ty.LeQ.norm h
  · simpa only [Polarity.Rel, Ty.norm_idem] using h

structure VarianceEnvEq (vs : List Variance) (θ τ : SubstEnv) : Prop where
  types : ∀ i, vs[i]? = some .invariant → (θ.types i).norm = (τ.types i).norm
  rows : θ.rows = τ.rows
  ranges : θ.ranges = τ.ranges
  values : θ.values = τ.values

theorem VarianceEnvEq.up {vs θ τ} (h : VarianceEnvEq vs θ τ) : VarianceEnvEq vs θ.up τ.up := by
  refine ⟨?_, congrArg (List.map (Eff.shiftV 1 0)) h.rows, h.ranges, congrArg upValues h.values⟩
  intro i hi
  simp only [SubstEnv.up_types, Ty.norm_shiftV, h.types i hi]

private theorem accepts_both {v : Variance} (h : v.accepts .both) : v = .invariant := by
  cases v <;> simp_all [Variance.accepts]

@[simp] theorem Polarity.both_compose (v : Variance) : Polarity.both.compose v = .both := by
  cases v <;> rfl

private theorem apply_norm_eq {a b : Ty} {as bs : List Ty}
    (ha : a.norm = b.norm) (hs : Ty.normTys as = Ty.normTys bs) :
    (rawApply a as).norm = (rawApply b bs).norm := by
  rw [←rawApply_norm, ←rawApply_norm b bs, ha, hs]

mutual
  theorem Ty.VarianceOK.invariant {P vs θ τ} (a : Ty)
      (h : a.VarianceOK P vs .both) (he : VarianceEnvEq vs θ τ) :
      (a.rawBind θ).norm = (a.rawBind τ).norm := by
    cases a <;> simp only [Ty.VarianceOK] at h <;> simp only [Ty.rawBind, Ty.norm]
    all_goals first | rfl | exact Ty.VarianceOK.invariant _ h he | exact varianceTys_invariant _ h he | skip
    case list a | reference a | lazy a | set a | dict _ a => exact congrArg _ (Ty.VarianceOK.invariant a h he)
    case tvar i =>
      obtain ⟨v, hv, ha⟩ := h
      cases accepts_both ha
      exact he.types i hv
    case «opaque» o ix => rw [he.ranges]
    case «scoped» o k ix => rw [he.ranges]
    case data d as => exact congrArg (Ty.data d) (varianceArgs_invariant _ _ h he)
    case external id as => exact congrArg (Ty.external id) (varianceTys_invariant _ h he)
    case fn ns ps r e => rw [varianceTys_invariant _ h.1 he, Ty.VarianceOK.invariant _ h.2.1 he, Eff.VarianceOK.invariant _ h.2.2 he]
    case cont a b e => rw [Ty.VarianceOK.invariant _ h.1 he, Ty.VarianceOK.invariant _ h.2.1 he, Eff.VarianceOK.invariant _ h.2.2 he]
    case map a b => rw [Ty.VarianceOK.invariant _ h.1 he, Ty.VarianceOK.invariant _ h.2 he]
    case tapp i as =>
      obtain ⟨⟨v, hv, ha⟩, hs⟩ := h
      cases accepts_both ha
      exact apply_norm_eq (he.types i hv) (varianceTys_invariant _ hs he)
    case refined a p => rw [Ty.VarianceOK.invariant _ h he, he.values]
    case dependentFn t => rw [Tel.VarianceOK.invariant _ h he]
  theorem Tel.VarianceOK.invariant {P vs θ τ} (t : Tel)
      (h : t.VarianceOK P vs .both) (he : VarianceEnvEq vs θ τ) :
      Tel.norm (Tel.rawBind θ t) = Tel.norm (Tel.rawBind τ t) := by
    cases t with
    | done r e => simp only [Tel.rawBind, Tel.norm, Ty.VarianceOK.invariant _ h.1 he, Eff.VarianceOK.invariant _ h.2 he]
    | param n a t => simp only [Tel.rawBind, Tel.norm, Ty.VarianceOK.invariant _ h.1 he, Tel.VarianceOK.invariant _ h.2 he.up]
  theorem varianceTys_invariant {P vs θ τ} (as : List Ty)
      (h : varianceTysOK P vs .both as) (he : VarianceEnvEq vs θ τ) :
      Ty.normTys (rawBindTys θ as) = Ty.normTys (rawBindTys τ as) := by
    cases as with
    | nil => rfl
    | cons a as => simp only [rawBindTys, Ty.normTys, Ty.VarianceOK.invariant _ h.1 he, varianceTys_invariant _ h.2 he]
  theorem varianceArgs_invariant {P vs θ τ} (ws : List Variance) (as : List Ty)
      (h : varianceArgsOK P vs .both ws as) (he : VarianceEnvEq vs θ τ) :
      Ty.normTys (rawBindTys θ as) = Ty.normTys (rawBindTys τ as) := by
    cases ws <;> cases as <;> simp only [varianceArgsOK] at h
    case nil.nil => rfl
    case cons.cons v ws a as =>
      have ha : a.VarianceOK P vs .both := by simpa only [Polarity.both_compose] using h.1
      simp only [rawBindTys, Ty.normTys, Ty.VarianceOK.invariant _ ha he, varianceArgs_invariant _ _ h.2 he]
    all_goals contradiction
  theorem Eff.VarianceOK.invariant {P vs θ τ} (e : Eff)
      (h : Eff.VarianceOK P vs .both e) (he : VarianceEnvEq vs θ τ) :
      (Eff.rawBind θ e).norm = (Eff.rawBind τ e).norm := by
    cases e with
    | mk ats fs => simp only [Eff.rawBind, Eff.norm, he.rows, he.ranges, Ty.normTys_append, varianceTys_invariant _ h he]
end

def Variance.polarity : Variance → Polarity
  | .covariant => .positive
  | .contravariant => .negative
  | .invariant => .both

structure VarianceEnvRel (P : Program) (Γ : Ctx) (Φ : List Pred)
    (vs : List Variance) (θ τ : SubstEnv) : Prop where
  types : ∀ (i : Nat) (v : Variance), vs[i]? = some v → v.polarity.Rel P Γ Φ (θ.types i) (τ.types i)
  rows : θ.rows = τ.rows
  ranges : θ.ranges = τ.ranges
  values : θ.values = τ.values

theorem VarianceEnvRel.eq {P Γ Φ vs θ τ} (h : VarianceEnvRel P Γ Φ vs θ τ) : VarianceEnvEq vs θ τ :=
  ⟨fun i hi => h.types i .invariant hi, h.rows, h.ranges, h.values⟩

theorem Polarity.Rel.of_norm_eq {P Γ Φ} (p : Polarity) {a b : Ty} (h : a.norm = b.norm) :
    p.Rel P Γ Φ a b := by
  cases p
  · exact Ty.LeQ.convert h
  · exact Ty.LeQ.convert h.symm
  · exact h

theorem VarianceEnvRel.up {P Γ Φ vs θ τ} (h : VarianceEnvRel P Γ Φ vs θ τ) (x : Ty) :
    VarianceEnvRel P (Γ.extend x) (Φ.map Pred.lift) vs θ.up τ.up := by
  refine ⟨?_, h.eq.up.rows, h.eq.up.ranges, h.eq.up.values⟩
  intro i v hi
  have hr := h.types i v hi
  cases v
  · exact Ty.LeQ.lift hr x
  · exact Ty.LeQ.lift hr x
  · simpa only [Variance.polarity, Polarity.Rel, SubstEnv.up_types, Ty.norm_shiftV] using congrArg (Ty.shiftV 1 0) hr

theorem VarianceEnvRel.param {P Γ Φ vs θ τ} (h : VarianceEnvRel P Γ Φ vs θ τ)
    {i p} (ha : Ty.VarianceOK P vs p (.tvar i)) : p.Rel P Γ Φ (θ.types i) (τ.types i) := by
  obtain ⟨v, hv, hp⟩ := ha
  have hr := h.types i v hv
  cases v <;> cases p <;> simp only [Variance.accepts] at hp
  all_goals first | contradiction | exact hr | exact Polarity.Rel.of_norm_eq _ hr

private theorem covers_of_norm_eq {Γ Φ e f} (h : Eff.norm e = Eff.norm f) : Eff.Covers Γ Φ f e := by
  apply Eff.covers_norm_left.mp
  apply Eff.covers_norm_right.mp
  rw [h]
  exact Eff.Covers.refl Γ Φ _

theorem Polarity.Rel.list {P Γ Φ} {p : Polarity} {a b : Ty} (h : p.Rel P Γ Φ a b) :
    p.Rel P Γ Φ (.list a) (.list b) := by
  cases p
  · exact Ty.LeQ.list h
  · exact Ty.LeQ.list h
  · exact congrArg Ty.list h

theorem Polarity.Rel.lazy {P Γ Φ} {p : Polarity} {a b : Ty} (h : p.Rel P Γ Φ a b) :
    p.Rel P Γ Φ (.lazy a) (.lazy b) := by
  cases p
  · exact Ty.LeQ.lazy h
  · exact Ty.LeQ.lazy h
  · exact congrArg Ty.lazy h

theorem Polarity.Rel.refined {P Γ Φ} {p : Polarity} {a b : Ty} {q : Pred}
    (h : p.Rel P Γ Φ a b) (ha : q.Sorted Γ (some a)) (hb : q.Sorted Γ (some b)) :
    p.Rel P Γ Φ (.refined a q) (.refined b q) := by
  cases p
  · exact Ty.LeQ.refine h ha hb (.hyp List.mem_cons_self)
  · exact Ty.LeQ.refine h hb ha (.hyp List.mem_cons_self)
  · exact congrArg (fun a => a.refineNorm q) h

private theorem congr2 {α β γ : Type} (f : α → β → γ) {a b : α} {c d : β}
    (h : a = b) (g : c = d) : f a c = f b d := by cases h; cases g; rfl
private theorem congr3 {α β γ δ : Type} (f : α → β → γ → δ)
    {a b : α} {c d : β} {e f' : γ} (h : a = b) (g : c = d) (k : e = f') :
    f a c e = f b d f' := by cases h; cases g; cases k; rfl

theorem Polarity.Rel.map {P Γ Φ} {p : Polarity} {k l a b : Ty}
    (hk : k.norm = l.norm) (h : p.Rel P Γ Φ a b) : p.Rel P Γ Φ (.map k a) (.map l b) := by
  have hn := h.norm
  cases p
  · exact Ty.LeQ.trans (.convert (by simp only [Ty.norm, Ty.norm_idem]))
      (.trans (.map_value hk hn) (.convert (by simp only [Ty.norm, Ty.norm_idem])))
  · exact Ty.LeQ.trans (.convert (by simp only [Ty.norm, Ty.norm_idem]))
      (.trans (.map_value hk.symm hn) (.convert (by simp only [Ty.norm, Ty.norm_idem])))
  · exact congr2 Ty.map hk h

theorem TyPairs.norm_eq {as bs} (h : TyPairs (fun a b => a.norm = b.norm) as bs) :
    Ty.normTys as = Ty.normTys bs := by
  induction h with
  | nil => rfl
  | cons h hs ih => exact congr2 List.cons h ih

theorem Polarity.Rel.fn {P Γ Φ} {p : Polarity} {ns as bs r s e f}
    (hns : NamesWF ns as) (hnt : NamesWF ns bs)
    (hp : TyPairs (p.flip.Rel P Γ Φ) as bs)
    (hr : p.Rel P Γ Φ r s) (he : Eff.norm e = Eff.norm f) :
    p.Rel P Γ Φ (.fn ns as r e) (.fn ns bs s f) := by
  cases p
  · exact Ty.LeQ.fn hns hnt hp hr (covers_of_norm_eq he)
  · apply Ty.LeQ.fn hnt hns (hr := hr) (he := covers_of_norm_eq he.symm)
    clear hns hnt
    induction hp with
    | nil => exact .nil
    | cons h hs ih => exact .cons h ih
  · exact congr3 (Ty.fn ns) (TyPairs.norm_eq hp) hr he

def Polarity.ArgsRel (P : Program) (Γ : Ctx) (Φ : List Pred) :
    Polarity → List Variance → List Ty → List Ty → Prop
  | .positive, vs, as, bs => TypeArgsLe P Γ Φ vs as bs
  | .negative, vs, as, bs => TypeArgsLe P Γ Φ vs bs as
  | .both, _, as, bs => Ty.normTys as = Ty.normTys bs

theorem Polarity.ArgsRel.cons {P Γ Φ} {p : Polarity} {v vs a b as bs}
    (h : (p.compose v).Rel P Γ Φ a b) (hs : p.ArgsRel P Γ Φ vs as bs) :
    p.ArgsRel P Γ Φ (v :: vs) (a :: as) (b :: bs) := by
  cases p <;> cases v
  all_goals first
    | exact TypeArgsLe.covariant_cons h hs
    | exact TypeArgsLe.contravariant_cons h hs
    | exact TypeArgsLe.invariant_cons h hs
    | exact TypeArgsLe.invariant_cons h.symm hs
    | exact congr2 List.cons h hs

structure OrdinaryTypeImages (θ τ : SubstEnv) : Prop where
  l : ∀ i, Ordinary (θ.types i)
  r : ∀ i, Ordinary (τ.types i)
  vl : θ.values = fun i => some (.var i)
  vr : τ.values = fun i => some (.var i)

theorem OrdinaryTypeImages.up {θ τ} (h : OrdinaryTypeImages θ τ) : OrdinaryTypeImages θ.up τ.up := by
  refine ⟨fun i => ?_, fun i => ?_, ?_, ?_⟩
  · simpa only [SubstEnv.up_types] using (Ty.ordinary_shiftV _ _ _).mpr (h.l i)
  · simpa only [SubstEnv.up_types] using (Ty.ordinary_shiftV _ _ _).mpr (h.r i)
  · show upValues θ.values = _
    rw [h.vl, upValues_id]
  · show upValues τ.values = _
    rw [h.vr, upValues_id]

theorem variance_carrier_sort (c : Ty) (θ : SubstEnv) {s} (h : c.HasSort s) : (c.rawBind θ).HasSort s :=
  (Ty.hasSort_norm _ s).mp (Ty.hasSort_bind h θ)

theorem variance_carrier_ord (c : Ty) {θ : SubstEnv} (ho : ∀ i, Ordinary (θ.types i)) (h : Ordinary c) :
    Ordinary (c.rawBind θ) :=
  (Ty.ordinary_norm _).mp (Ty.ordinary_bind h θ ho)

theorem SortMap.extend {G Γ} (h : SortMap G Γ) (a b : Ty) (hs : ∀ s, a.HasSort s → b.HasSort s)
    (ho : Ordinary a → Ordinary b) : SortMap (G.extend a) (Γ.extend b) := by
  constructor
  intro i t hi
  cases i with
  | zero =>
    cases Option.some.inj hi
    exact ⟨_, rfl, fun s h => (Ty.hasSort_shiftV _ _ _ _).mpr (hs s ((Ty.hasSort_shiftV _ _ _ _).mp h)),
      fun h => (Ty.ordinary_shiftV _ _ _).mpr (ho ((Ty.ordinary_shiftV _ _ _).mp h))⟩
  | succ i =>
    simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map, Option.map_eq_some_iff] at hi
    obtain ⟨x, hx, hxt⟩ := hi
    cases x with
    | none => simp at hxt
    | some x =>
      obtain ⟨_, rfl, rfl⟩ := by simpa using hxt
      obtain ⟨y, hy, hsy, hoy⟩ := h.lookup i x hx
      refine ⟨y.shiftV 1 0, by simp [Ctx.extend, hy], ?_, ?_⟩
      · exact fun s h' => (Ty.hasSort_shiftV _ _ _ _).mpr (hsy s ((Ty.hasSort_shiftV _ _ _ _).mp h'))
      · exact fun h' => (Ty.ordinary_shiftV _ _ _).mpr (hoy ((Ty.ordinary_shiftV _ _ _).mp h'))

theorem Pred.Sorted.sortMap {G Γ c b} {q : Pred} (hm : SortMap G Γ) (h : q.Sorted G (some c))
    (hs : ∀ s, c.HasSort s → b.HasSort s) (ho : Ordinary c → Ordinary b) : q.Sorted Γ (some b) := by
  simpa only [upValues_id, predBind_id] using
    Pred.sorted_bind h (fun i => some (.var i)) hs ho hm.values hm.references

private theorem names_rawBind {ns as θ} (h : NamesWF ns as) : NamesWF ns (rawBindTys θ as) :=
  ⟨by simpa only [rawBindTys_eq_map, List.length_map] using h.1, h.2⟩

mutual
  theorem Ty.VarianceOK.mono {P Γ Φ vs θ τ G} (a : Ty) (p : Polarity)
      (h : a.VarianceOK P vs p) (he : VarianceEnvRel P Γ Φ vs θ τ)
      {nr nt nv} (hw : a.WF nr nt nv)
      (hg : a.Sorted G) (hm : SortMap G Γ) (hi : OrdinaryTypeImages θ τ) :
      p.Rel P Γ Φ (a.rawBind θ) (a.rawBind τ) := by
    by_cases hb : p = .both
    · subst p; exact Ty.VarianceOK.invariant a h he.eq
    cases a with
    | tvar i => exact he.param h
    | base _ | bytes | ctor _ | pathBases | scopePattern _ => exact .of_norm_eq p rfl
    | «opaque» o ix => apply Polarity.Rel.of_norm_eq p; simp only [Ty.rawBind, he.ranges]
    | «scoped» o k ix => apply Polarity.Rel.of_norm_eq p; simp only [Ty.rawBind, he.ranges]
    | reference a => exact .of_norm_eq p (Ty.VarianceOK.invariant (.reference a) h he.eq)
    | set a => exact .of_norm_eq p (Ty.VarianceOK.invariant (.set a) h he.eq)
    | dict cl a => exact .of_norm_eq p (Ty.VarianceOK.invariant (.dict cl a) h he.eq)
    | cont a b e => exact .of_norm_eq p (Ty.VarianceOK.invariant (.cont a b e) h he.eq)
    | external id as => exact .of_norm_eq p (Ty.VarianceOK.invariant (.external id as) h he.eq)
    | tapp i as => exact .of_norm_eq p (Ty.VarianceOK.invariant (.tapp i as) h he.eq)
    | list a => exact Polarity.Rel.list (Ty.VarianceOK.mono a p h he hw hg hm hi)
    | lazy a => exact Polarity.Rel.lazy (Ty.VarianceOK.mono a p h he hw hg hm hi)
    | map k a =>
      exact Polarity.Rel.map (Ty.VarianceOK.invariant k h.1 he.eq)
        (Ty.VarianceOK.mono a p h.2 he hw.2 hg.2 hm hi)
    | fn ns ps r e =>
      exact Polarity.Rel.fn (names_rawBind hw.1) (names_rawBind hw.1)
        (varianceTys_mono ps p.flip h.1 he hw.2.1 hg.1 hm hi)
        (Ty.VarianceOK.mono r p h.2.1 he hw.2.2.1 hg.2.1 hm hi)
        (Eff.VarianceOK.invariant e (by cases e; exact h.2.2) he.eq)
    | data d as =>
      have hr := varianceArgs_mono (P.varianceFor d as.length) as p h he hw hg hm hi
      cases p with
      | positive => apply Ty.LeQ.data; simpa only [Polarity.ArgsRel, rawBindTys_eq_map, List.length_map] using hr
      | negative => apply Ty.LeQ.data; simpa only [Polarity.ArgsRel, rawBindTys_eq_map, List.length_map] using hr
      | both => exact False.elim (hb rfl)
    | refined a q =>
      have hr := Ty.VarianceOK.mono a p h he hw.1 hg.1 hm hi
      change p.Rel P Γ Φ (.refined (a.rawBind θ) (predBind (upValues θ.values) q))
        (.refined (a.rawBind τ) (predBind (upValues τ.values) q))
      simp only [hi.vl, hi.vr, upValues_id, predBind_id]
      exact Polarity.Rel.refined hr
        (Pred.Sorted.sortMap hm hg.2 (fun _ h => variance_carrier_sort a θ h) (variance_carrier_ord a hi.l))
        (Pred.Sorted.sortMap hm hg.2 (fun _ h => variance_carrier_sort a τ h) (variance_carrier_ord a hi.r))
    | dependentFn t =>
      have hr := Tel.VarianceOK.mono t p h he hw hg hm hi
      cases p with
      | positive => exact Ty.LeQ.dependentFn hr
      | negative => exact Ty.LeQ.dependentFn hr
      | both => exact False.elim (hb rfl)
  theorem Tel.VarianceOK.mono {P Γ Φ vs θ τ G} (t : Tel) (p : Polarity)
      (h : t.VarianceOK P vs p) (he : VarianceEnvRel P Γ Φ vs θ τ)
      {nr nt nv} (hw : t.WF nr nt nv)
      (hg : Tel.Sorted G t) (hm : SortMap G Γ) (hi : OrdinaryTypeImages θ τ) :
      p.TelRel P Γ Φ (Tel.rawBind θ t) (Tel.rawBind τ t) := by
    by_cases hb : p = .both
    · subst p; exact Tel.VarianceOK.invariant t h he.eq
    cases t with
    | done r e =>
      have hr := Ty.VarianceOK.mono r p h.1 he hw.1 hg.1 hm hi
      have heq := Eff.VarianceOK.invariant e (by cases e; exact h.2) he.eq
      cases p with
      | positive => exact TelClosure.tail .refl (.done hr (by
          apply Eff.covers_norm_left.mp; apply Eff.covers_norm_right.mp; rw [heq]; exact Eff.Covers.refl Γ Φ _))
      | negative => exact TelClosure.tail .refl (.done hr (by
          apply Eff.covers_norm_left.mp; apply Eff.covers_norm_right.mp; rw [heq]; exact Eff.Covers.refl Γ Φ _))
      | both => exact False.elim (hb rfl)
    | param n a t =>
      have ha := Ty.VarianceOK.mono a p.flip h.1 he hw.1 hg.1 hm hi
      cases p with
      | positive =>
        apply TelClosure.param ha
        exact Tel.VarianceOK.mono t .positive h.2 (he.up (a.rawBind τ)) hw.2 hg.2
          (SortMap.extend hm a _ (fun _ h => variance_carrier_sort a τ h) (variance_carrier_ord a hi.r)) hi.up
      | negative =>
        apply TelClosure.param ha
        exact Tel.VarianceOK.mono t .negative h.2 (he.up (a.rawBind θ)) hw.2 hg.2
          (SortMap.extend hm a _ (fun _ h => variance_carrier_sort a θ h) (variance_carrier_ord a hi.l)) hi.up
      | both => exact False.elim (hb rfl)
  theorem varianceTys_mono {P Γ Φ vs θ τ G} (as : List Ty) (p : Polarity)
      (h : varianceTysOK P vs p as) (he : VarianceEnvRel P Γ Φ vs θ τ)
      {nr nt nv} (hw : Ty.WFList nr nt nv as)
      (hg : sortedTys G as) (hm : SortMap G Γ) (hi : OrdinaryTypeImages θ τ) :
      TyPairs (p.Rel P Γ Φ) (rawBindTys θ as) (rawBindTys τ as) := by
    cases as with
    | nil => exact .nil
    | cons a as =>
      exact .cons (Ty.VarianceOK.mono a p h.1 he hw.1 hg.1 hm hi) (varianceTys_mono as p h.2 he hw.2 hg.2 hm hi)
  theorem varianceArgs_mono {P Γ Φ vs θ τ G} (ws : List Variance) (as : List Ty) (p : Polarity)
      (h : varianceArgsOK P vs p ws as) (he : VarianceEnvRel P Γ Φ vs θ τ)
      {nr nt nv} (hw : Ty.WFList nr nt nv as)
      (hg : sortedTys G as) (hm : SortMap G Γ) (hi : OrdinaryTypeImages θ τ) :
      p.ArgsRel P Γ Φ ws (rawBindTys θ as) (rawBindTys τ as) := by
    cases ws <;> cases as <;> simp only [varianceArgsOK] at h
    case nil.nil => cases p <;> first | exact TypeArgsLe.nil | rfl
    case cons.cons v ws a as =>
      exact Polarity.ArgsRel.cons (Ty.VarianceOK.mono a (p.compose v) h.1 he hw.1 hg.1 hm hi)
        (varianceArgs_mono ws as p h.2 he hw.2 hg.2 hm hi)
    all_goals contradiction
end

theorem TypeArgsLe.get {P Γ Φ vs as bs} (h : TypeArgsLe P Γ Φ vs as bs) (i : Nat) (v : Variance)
    (hv : vs[i]? = some v) : ∃ a b, as[i]? = some a ∧ bs[i]? = some b ∧
      v.polarity.Rel P Γ Φ a b := by
  match h with
  | .nil => simp at hv
  | .covariant_cons hh hs | .contravariant_cons hh hs | .invariant_cons hh hs =>
    cases i with
    | zero => cases Option.some.inj hv; exact ⟨_, _, rfl, rfl, hh⟩
    | succ i => exact hs.get i v hv

theorem TypeArgsLe.env {P Γ Φ vs as bs} (h : TypeArgsLe P Γ Φ vs as bs) :
    VarianceEnvRel P Γ Φ vs (typeEnvAt 0 as []) (typeEnvAt 0 bs []) := by
  refine ⟨?_, rfl, rfl, rfl⟩
  intro i v hv
  obtain ⟨a, b, ha, hb, hr⟩ := h.get i v hv
  have hia := (List.getElem?_eq_some_iff.mp ha).1
  have hib := (List.getElem?_eq_some_iff.mp hb).1
  simpa only [typeEnvAt, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero, hia, hib, ha, hb,
    Option.getD_some, shiftTypes_zero] using hr

theorem variance_field_mono (P : Program) (Γ Φ) (vs : List Variance) (a : Ty) (as bs : List Ty)
    (occurs : Ty.VarianceOK P vs .positive a) (wf : a.WF 0 vs.length 0)
    (generic : a.Sorted [])
    (oa : ∀ t ∈ as, Ordinary t) (ob : ∀ t ∈ bs, Ordinary t)
    (args : TypeArgsLe P Γ Φ vs as bs) :
    Ty.LeQ P Γ Φ (a.subst as []) (a.subst bs []) := by
  have hm : SortMap [] Γ := ⟨fun i a hi => by simp at hi⟩
  exact Ty.LeQ.norm (Ty.VarianceOK.mono a .positive occurs args.env wf generic hm
    ⟨typeEnvAt_ordinary 0 as [] oa, typeEnvAt_ordinary 0 bs [] ob, rfl, rfl⟩)

end Benitoite.Release.Refinement