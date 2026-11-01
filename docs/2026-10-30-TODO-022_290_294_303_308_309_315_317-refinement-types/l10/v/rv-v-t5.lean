import Benitoite.Release.Refinement.ValueFacts
open Benitoite Benitoite.Release.Refinement
namespace RV
set_option maxHeartbeats 1000000
/-! 像の Sorted を要求しない単調性。総称の欄の Sorted と像の Ordinary だけで足りることを確かめる。 -/
structure Imgs (θ τ : SubstEnv) : Prop where
  l : ∀ i, Ordinary (θ.types i)
  r : ∀ i, Ordinary (τ.types i)
  vl : θ.values = fun i => some (.var i)
  vr : τ.values = fun i => some (.var i)

theorem Imgs.up {θ τ} (h : Imgs θ τ) : Imgs θ.up τ.up := by
  refine ⟨fun i => ?_, fun i => ?_, ?_, ?_⟩
  · simpa only [SubstEnv.up_types] using (Ty.ordinary_shiftV _ _ _).mpr (h.l i)
  · simpa only [SubstEnv.up_types] using (Ty.ordinary_shiftV _ _ _).mpr (h.r i)
  · show upValues θ.values = _
    rw [h.vl, upValues_id]
  · show upValues τ.values = _
    rw [h.vr, upValues_id]

theorem carrier_sort (c : Ty) (θ : SubstEnv) {s} (h : c.HasSort s) : (c.rawBind θ).HasSort s :=
  (Ty.hasSort_norm _ s).mp (Ty.hasSort_bind h θ)

theorem carrier_ord (c : Ty) {θ : SubstEnv} (ho : ∀ i, Ordinary (θ.types i)) (h : Ordinary c) :
    Ordinary (c.rawBind θ) :=
  (Ty.ordinary_norm _).mp (Ty.ordinary_bind h θ ho)

theorem sortMap_extend2 {G Γ} (h : SortMap G Γ) (a b : Ty) (hs : ∀ s, a.HasSort s → b.HasSort s)
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

theorem pred_lift {G Γ c b} {q : Pred} (hm : SortMap G Γ) (h : q.Sorted G (some c))
    (hs : ∀ s, c.HasSort s → b.HasSort s) (ho : Ordinary c → Ordinary b) : q.Sorted Γ (some b) := by
  simpa only [upValues_id, predBind_id] using
    Pred.sorted_bind h (fun i => some (.var i)) hs ho hm.values hm.references

private theorem names_rawBind {ns as θ} (h : NamesWF ns as) : NamesWF ns (rawBindTys θ as) :=
  ⟨by simpa only [rawBindTys_eq_map, List.length_map] using h.1, h.2⟩

mutual
  theorem mono' {P Γ Φ vs θ τ G} (a : Ty) (p : Polarity)
      (h : a.VarianceOK P vs p) (he : VarianceEnvRel P Γ Φ vs θ τ)
      {nr nt nv} (hw : a.WF nr nt nv)
      (hg : a.Sorted G) (hm : SortMap G Γ) (hi : Imgs θ τ) :
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
    | list a => exact Polarity.Rel.list (mono' a p h he hw hg hm hi)
    | lazy a => exact Polarity.Rel.lazy (mono' a p h he hw hg hm hi)
    | map k a =>
      exact Polarity.Rel.map (Ty.VarianceOK.invariant k h.1 he.eq)
        (mono' a p h.2 he hw.2 hg.2 hm hi)
    | fn ns ps r e =>
      exact Polarity.Rel.fn (names_rawBind hw.1) (names_rawBind hw.1)
        (tys' ps p.flip h.1 he hw.2.1 hg.1 hm hi)
        (mono' r p h.2.1 he hw.2.2.1 hg.2.1 hm hi)
        (Eff.VarianceOK.invariant e (by cases e; exact h.2.2) he.eq)
    | data d as =>
      have hr := args' (P.varianceFor d as.length) as p h he hw hg hm hi
      cases p with
      | positive => apply Ty.LeQ.data; simpa only [Polarity.ArgsRel, rawBindTys_eq_map, List.length_map] using hr
      | negative => apply Ty.LeQ.data; simpa only [Polarity.ArgsRel, rawBindTys_eq_map, List.length_map] using hr
      | both => exact False.elim (hb rfl)
    | refined a q =>
      have hr := mono' a p h he hw.1 hg.1 hm hi
      change p.Rel P Γ Φ (.refined (a.rawBind θ) (predBind (upValues θ.values) q))
        (.refined (a.rawBind τ) (predBind (upValues τ.values) q))
      simp only [hi.vl, hi.vr, upValues_id, predBind_id]
      exact Polarity.Rel.refined hr
        (pred_lift hm hg.2 (fun _ h => carrier_sort a θ h) (carrier_ord a hi.l))
        (pred_lift hm hg.2 (fun _ h => carrier_sort a τ h) (carrier_ord a hi.r))
    | dependentFn t =>
      have hr := tel' t p h he hw hg hm hi
      cases p with
      | positive => exact Ty.LeQ.dependentFn hr
      | negative => exact Ty.LeQ.dependentFn hr
      | both => exact False.elim (hb rfl)
  theorem tel' {P Γ Φ vs θ τ G} (t : Tel) (p : Polarity)
      (h : t.VarianceOK P vs p) (he : VarianceEnvRel P Γ Φ vs θ τ)
      {nr nt nv} (hw : t.WF nr nt nv)
      (hg : Tel.Sorted G t) (hm : SortMap G Γ) (hi : Imgs θ τ) :
      p.TelRel P Γ Φ (Tel.rawBind θ t) (Tel.rawBind τ t) := by
    by_cases hb : p = .both
    · subst p; exact Tel.VarianceOK.invariant t h he.eq
    cases t with
    | done r e =>
      have hr := mono' r p h.1 he hw.1 hg.1 hm hi
      have heq := Eff.VarianceOK.invariant e (by cases e; exact h.2) he.eq
      cases p with
      | positive => exact TelClosure.tail .refl (.done hr (by
          apply Eff.covers_norm_left.mp; apply Eff.covers_norm_right.mp; rw [heq]; exact Eff.Covers.refl Γ Φ _))
      | negative => exact TelClosure.tail .refl (.done hr (by
          apply Eff.covers_norm_left.mp; apply Eff.covers_norm_right.mp; rw [heq]; exact Eff.Covers.refl Γ Φ _))
      | both => exact False.elim (hb rfl)
    | param n a t =>
      have ha := mono' a p.flip h.1 he hw.1 hg.1 hm hi
      cases p with
      | positive =>
        apply TelClosure.param ha
        exact tel' t .positive h.2 (he.up (a.rawBind τ)) hw.2 hg.2
          (sortMap_extend2 hm a _ (fun _ h => carrier_sort a τ h) (carrier_ord a hi.r)) hi.up
      | negative =>
        apply TelClosure.param ha
        exact tel' t .negative h.2 (he.up (a.rawBind θ)) hw.2 hg.2
          (sortMap_extend2 hm a _ (fun _ h => carrier_sort a θ h) (carrier_ord a hi.l)) hi.up
      | both => exact False.elim (hb rfl)
  theorem tys' {P Γ Φ vs θ τ G} (as : List Ty) (p : Polarity)
      (h : varianceTysOK P vs p as) (he : VarianceEnvRel P Γ Φ vs θ τ)
      {nr nt nv} (hw : Ty.WFList nr nt nv as)
      (hg : sortedTys G as) (hm : SortMap G Γ) (hi : Imgs θ τ) :
      TyPairs (p.Rel P Γ Φ) (rawBindTys θ as) (rawBindTys τ as) := by
    cases as with
    | nil => exact .nil
    | cons a as =>
      exact .cons (mono' a p h.1 he hw.1 hg.1 hm hi) (tys' as p h.2 he hw.2 hg.2 hm hi)
  theorem args' {P Γ Φ vs θ τ G} (ws : List Variance) (as : List Ty) (p : Polarity)
      (h : varianceArgsOK P vs p ws as) (he : VarianceEnvRel P Γ Φ vs θ τ)
      {nr nt nv} (hw : Ty.WFList nr nt nv as)
      (hg : sortedTys G as) (hm : SortMap G Γ) (hi : Imgs θ τ) :
      p.ArgsRel P Γ Φ ws (rawBindTys θ as) (rawBindTys τ as) := by
    cases ws <;> cases as <;> simp only [varianceArgsOK] at h
    case nil.nil => cases p <;> first | exact TypeArgsLe.nil | rfl
    case cons.cons v ws a as =>
      exact Polarity.ArgsRel.cons (mono' a (p.compose v) h.1 he hw.1 hg.1 hm hi)
        (args' ws as p h.2 he hw.2 hg.2 hm hi)
    all_goals contradiction
end

/-- 像の Annotation を要求しない欄の単調性。 -/
theorem field_mono' (P : Program) (Γ Φ) (vs : List Variance) (a : Ty) (as bs : List Ty)
    (occurs : Ty.VarianceOK P vs .positive a) (wf : a.WF 0 vs.length 0)
    (generic : a.Sorted [])
    (oa : ∀ t ∈ as, Ordinary t) (ob : ∀ t ∈ bs, Ordinary t)
    (args : TypeArgsLe P Γ Φ vs as bs) :
    Ty.LeQ P Γ Φ (a.subst as []) (a.subst bs []) := by
  have hm : SortMap [] Γ := ⟨fun i a hi => by simp at hi⟩
  exact Ty.LeQ.norm (mono' a .positive occurs args.env wf generic hm
    ⟨typeEnvAt_ordinary 0 as [] oa, typeEnvAt_ordinary 0 bs [] ob, rfl, rfl⟩)
#print axioms field_mono'
end RV
