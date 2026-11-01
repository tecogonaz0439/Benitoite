import Benitoite.Release.Refinement.VarianceTransport

/-! 値の意味の移送に使う構造上の比較。
設計書 01-12「篩を読む網羅性と値の意味」に対応する。 -/
namespace Benitoite.Release.Refinement
namespace MeaningTransport

mutual
  inductive MeaningLe (P : Program) : Ctx → List Pred → Ty → Ty → Prop where
    | convert {Γ Φ a b} : a.norm = b.norm → MeaningLe P Γ Φ a b
    | trans {Γ Φ a b c} : MeaningLe P Γ Φ a b → MeaningLe P Γ Φ b c → MeaningLe P Γ Φ a c
    | list {Γ Φ a b} : MeaningLe P Γ Φ a b → MeaningLe P Γ Φ (.list a) (.list b)
    | lazy {Γ Φ a b} : MeaningLe P Γ Φ (.lazy a) (.lazy b)
    | map {Γ Φ k l a b} : MeaningLe P Γ Φ (.map k a) (.map l b)
    | fn {Γ Φ ns ms as bs a b e f} : MeaningLe P Γ Φ (.fn ns as a e) (.fn ms bs b f)
    | dependentFn {Γ Φ t u} : MeaningLe P Γ Φ (.dependentFn t) (.dependentFn u)
    | forget {Γ Φ a p} : MeaningLe P Γ Φ (.refined a p) a
    | introduce {Γ Φ a p} : Entails (assumptions Γ Φ a) p → MeaningLe P Γ Φ a (.refined a p)
    | refine {Γ Φ a b p q} : MeaningLe P Γ Φ a b →
        Entails (p :: assumptions Γ Φ a) q → MeaningLe P Γ Φ (.refined a p) (.refined b q)
    | scoped {Γ Φ o k inner outer} : RangeIx.Covers outer inner →
        MeaningLe P Γ Φ (.scoped o k inner) (.scoped o k outer)
    | scoped_forget {Γ Φ o k ix} : MeaningLe P Γ Φ (.scoped o k ix) (.opaque o ix)
    | data {Γ Φ d as bs} : MeaningArgs P Γ Φ (P.varianceFor d as.length) as bs →
        MeaningLe P Γ Φ (.data d as) (.data d bs)
  inductive MeaningArgs (P : Program) : Ctx → List Pred → List Variance → List Ty → List Ty → Prop where
    | nil {Γ Φ} : MeaningArgs P Γ Φ [] [] []
    | covariant_cons {Γ Φ vs a b as bs} : MeaningLe P Γ Φ a b → MeaningArgs P Γ Φ vs as bs →
        MeaningArgs P Γ Φ (.covariant :: vs) (a :: as) (b :: bs)
    | contravariant_cons {Γ Φ vs a b as bs} : MeaningLe P Γ Φ b a → MeaningArgs P Γ Φ vs as bs →
        MeaningArgs P Γ Φ (.contravariant :: vs) (a :: as) (b :: bs)
    | invariant_cons {Γ Φ vs a b as bs} : a.norm = b.norm → MeaningArgs P Γ Φ vs as bs →
        MeaningArgs P Γ Φ (.invariant :: vs) (a :: as) (b :: bs)
end

mutual
  theorem of_le {P Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) : MeaningLe P Γ Φ a b := by
    match h with
    | .refl => exact .convert rfl
    | .convert he => exact .convert he
    | .trans h g => exact .trans (of_le h) (of_le g)
    | .list h => exact .list (of_le h)
    | .lazy _ => exact .lazy
    | .map_value .. => exact .map
    | .fn_effect .. => exact .fn
    | .dependentFn .. => exact .dependentFn
    | .forget => exact .forget
    | .introduce _ he => exact .introduce he
    | .refine h _ _ he => exact .refine (of_le h) he
    | .scoped h => exact .scoped h
    | .scoped_forget => exact .scoped_forget
    | .data h => exact .data (of_args h)
  theorem of_args {P Γ Φ vs as bs} (h : TypeArgsLe P Γ Φ vs as bs) : MeaningArgs P Γ Φ vs as bs := by
    match h with
    | .nil => exact .nil
    | .covariant_cons h hs => exact .covariant_cons (of_le h) (of_args hs)
    | .contravariant_cons h hs => exact .contravariant_cons (of_le h) (of_args hs)
    | .invariant_cons he hs => exact .invariant_cons he (of_args hs)
end

theorem MeaningLe.norm {P Γ Φ a b} (h : MeaningLe P Γ Φ a b) : MeaningLe P Γ Φ a.norm b.norm :=
  .trans (.convert (Ty.norm_idem a)) (.trans h (.convert (Ty.norm_idem b).symm))

theorem MeaningArgs.norm {P Γ Φ vs as bs} (h : MeaningArgs P Γ Φ vs as bs) :
    MeaningArgs P Γ Φ vs (Ty.normTys as) (Ty.normTys bs) := by
  match h with
  | .nil => exact .nil
  | .covariant_cons h hs => exact .covariant_cons h.norm hs.norm
  | .contravariant_cons h hs => exact .contravariant_cons h.norm hs.norm
  | .invariant_cons he hs =>
    exact .invariant_cons (by simpa only [Ty.norm_idem] using he) hs.norm

def PolarRel (P : Program) (Γ : Ctx) (Φ : List Pred) : Polarity → Ty → Ty → Prop
  | .positive, a, b => MeaningLe P Γ Φ a b
  | .negative, a, b => MeaningLe P Γ Φ b a
  | .both, a, b => a.norm = b.norm

def PolarArgs (P : Program) (Γ : Ctx) (Φ : List Pred) : Polarity → List Variance → List Ty → List Ty → Prop
  | .positive, vs, as, bs => MeaningArgs P Γ Φ vs as bs
  | .negative, vs, as, bs => MeaningArgs P Γ Φ vs bs as
  | .both, _, as, bs => Ty.normTys as = Ty.normTys bs

structure MeaningEnvRel (P : Program) (Γ : Ctx) (Φ : List Pred)
    (vs : List Variance) (θ τ : SubstEnv) : Prop where
  types : ∀ (i : Nat) (v : Variance), vs[i]? = some v → PolarRel P Γ Φ v.polarity (θ.types i) (τ.types i)
  rows : θ.rows = τ.rows
  ranges : θ.ranges = τ.ranges
  values : θ.values = τ.values

theorem MeaningEnvRel.eq {P Γ Φ vs θ τ} (h : MeaningEnvRel P Γ Φ vs θ τ) : VarianceEnvEq vs θ τ :=
  ⟨fun i hi => h.types i .invariant hi, h.rows, h.ranges, h.values⟩

theorem MeaningEnvRel.param {P Γ Φ vs θ τ i p} (h : MeaningEnvRel P Γ Φ vs θ τ)
    (hi : ∃ v, vs[i]? = some v ∧ v.accepts p) : PolarRel P Γ Φ p (θ.types i) (τ.types i) := by
  obtain ⟨v, hv, hp⟩ := hi
  have hr := h.types i v hv
  cases v <;> cases p <;> simp only [Variance.accepts] at hp <;> try contradiction
  all_goals first | exact hr | exact MeaningLe.convert hr | exact MeaningLe.convert hr.symm

theorem PolarRel.of_norm_eq {P Γ Φ} (p : Polarity) {a b : Ty} (h : a.norm = b.norm) :
    PolarRel P Γ Φ p a b := by
  cases p
  · exact .convert h
  · exact .convert h.symm
  · exact h

theorem PolarArgs.cons {P Γ Φ p v a b vs as bs}
    (h : PolarRel P Γ Φ (p.compose v) a b) (hs : PolarArgs P Γ Φ p vs as bs) :
    PolarArgs P Γ Φ p (v :: vs) (a :: as) (b :: bs) := by
  cases p <;> cases v
  all_goals first | exact .covariant_cons h hs | exact .contravariant_cons h hs |
    exact .invariant_cons h hs | exact .invariant_cons h.symm hs |
    exact (show a.norm :: Ty.normTys as = b.norm :: Ty.normTys bs from
      congr (congrArg List.cons h) hs)

mutual
  theorem variance_meaning (a : Ty) (p : Polarity) {P Γ Φ vs θ τ}
      (h : a.VarianceOK P vs p) (he : MeaningEnvRel P Γ Φ vs θ τ) :
      PolarRel P Γ Φ p (a.rawBind θ) (a.rawBind τ) := by
    by_cases hb : p = .both
    · subst p; exact Ty.VarianceOK.invariant a h he.eq
    cases a with
    | tvar i => exact he.param h
    | base _ | bytes | ctor _ | pathBases | scopePattern _ => exact .of_norm_eq p rfl
    | «opaque» o ix => apply PolarRel.of_norm_eq p; simp only [Ty.rawBind, he.ranges]
    | «scoped» o k ix => apply PolarRel.of_norm_eq p; simp only [Ty.rawBind, he.ranges]
    | reference a => exact .of_norm_eq p (Ty.VarianceOK.invariant (.reference a) h he.eq)
    | set a => exact .of_norm_eq p (Ty.VarianceOK.invariant (.set a) h he.eq)
    | dict cl a => exact .of_norm_eq p (Ty.VarianceOK.invariant (.dict cl a) h he.eq)
    | cont a b e => exact .of_norm_eq p (Ty.VarianceOK.invariant (.cont a b e) h he.eq)
    | external id as => exact .of_norm_eq p (Ty.VarianceOK.invariant (.external id as) h he.eq)
    | tapp i as => exact .of_norm_eq p (Ty.VarianceOK.invariant (.tapp i as) h he.eq)
    | list a =>
      have hr := variance_meaning a p h he
      cases p
      · exact .list hr
      · exact .list hr
      · exact False.elim (hb rfl)
    | lazy a | map _ a | fn _ _ a _ | dependentFn a =>
      cases p
      all_goals first | exact .lazy | exact .map | exact .fn | exact .dependentFn | exact False.elim (hb rfl)
    | refined a q =>
      have hr := variance_meaning a p h he
      change PolarRel P Γ Φ p (.refined (a.rawBind θ) (predBind (upValues θ.values) q))
        (.refined (a.rawBind τ) (predBind (upValues τ.values) q))
      rw [he.values]
      cases p
      · exact .refine hr (.hyp List.mem_cons_self)
      · exact .refine hr (.hyp List.mem_cons_self)
      · exact False.elim (hb rfl)
    | data d as =>
      have hr := variance_meaning_args (P.varianceFor d as.length) as p h he
      cases p
      · apply MeaningLe.data; simpa only [PolarArgs, rawBindTys_eq_map, List.length_map] using hr
      · apply MeaningLe.data; simpa only [PolarArgs, rawBindTys_eq_map, List.length_map] using hr
      · exact False.elim (hb rfl)
  theorem variance_meaning_args (ws : List Variance) (as : List Ty) (p : Polarity) {P Γ Φ vs θ τ}
      (h : varianceArgsOK P vs p ws as) (he : MeaningEnvRel P Γ Φ vs θ τ) :
      PolarArgs P Γ Φ p ws (rawBindTys θ as) (rawBindTys τ as) := by
    cases ws <;> cases as <;> simp only [varianceArgsOK] at h
    case nil.nil => cases p <;> first | exact MeaningArgs.nil | rfl
    case cons.cons v ws a as =>
      exact PolarArgs.cons (variance_meaning a (p.compose v) h.1 he)
        (variance_meaning_args ws as p h.2 he)
    all_goals contradiction
end

theorem MeaningArgs.length {P Γ Φ vs as bs} (h : MeaningArgs P Γ Φ vs as bs) :
    as.length = vs.length ∧ bs.length = vs.length := by
  match h with
  | .nil => exact ⟨rfl,rfl⟩
  | .covariant_cons _ hs | .contravariant_cons _ hs | .invariant_cons _ hs =>
    exact ⟨congrArg Nat.succ hs.length.1, congrArg Nat.succ hs.length.2⟩

theorem MeaningArgs.get {P Γ Φ vs as bs} (h : MeaningArgs P Γ Φ vs as bs) (i : Nat) (v : Variance)
    (hv : vs[i]? = some v) : ∃ a b, as[i]? = some a ∧ bs[i]? = some b ∧ PolarRel P Γ Φ v.polarity a b := by
  match h with
  | .nil => simp at hv
  | .covariant_cons hh hs | .contravariant_cons hh hs | .invariant_cons hh hs =>
    cases i with
    | zero => cases Option.some.inj hv; exact ⟨_,_,rfl,rfl,hh⟩
    | succ i => exact hs.get i v hv

theorem MeaningArgs.env {P Γ Φ vs as bs} (h : MeaningArgs P Γ Φ vs as bs) :
    MeaningEnvRel P Γ Φ vs (typeEnvAt 0 as []) (typeEnvAt 0 bs []) := by
  refine ⟨?_,rfl,rfl,rfl⟩
  intro i v hv
  obtain ⟨a,b,ha,hb,hr⟩ := h.get i v hv
  have hia := (List.getElem?_eq_some_iff.mp ha).1
  have hib := (List.getElem?_eq_some_iff.mp hb).1
  simpa only [typeEnvAt, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero, hia, hib, ha, hb,
    Option.getD_some, shiftTypes_zero] using hr

theorem field_order {P Γ Φ vs as bs} {a : Ty} (occurs : a.VarianceOK P vs .positive)
    (args : MeaningArgs P Γ Φ vs as bs) :
    MeaningLe P Γ Φ (a.subst as []) (a.subst bs []) :=
  (variance_meaning a .positive occurs args.env).norm

end MeaningTransport
end Benitoite.Release.Refinement
