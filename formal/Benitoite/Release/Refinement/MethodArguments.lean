import Benitoite.Release.Refinement.ValueBinding

namespace Benitoite.Release.Refinement
noncomputable section

def openingEnv (o : Option Term) : ObservationEnv
  | 0 => o
  | i+1 => some (.var i)

theorem termBind_shift_open (o : Option Term) (t : Term) :
    termBind? (openingEnv o) (termBind (fun i => some (.var (i+1))) t) = some t := by
  have hh := termBind?_comp (fun i => some (.var (i+1))) (openingEnv o) t
  rw [termBind?_renaming, Option.bind_some] at hh
  exact hh.trans (termBind?_id t)

theorem opening_comp (ν : ObservationEnv) (o : Option Term) :
    (fun i => (openingEnv o i).bind (termBind? ν)) =
      (fun i => (upValues ν i).bind (termBind? (openingEnv (o.bind (termBind? ν))))) := by
  funext i
  cases i with
  | zero => rfl
  | succ i =>
    simp only [openingEnv, Option.bind_some, termBind?, upValues]
    cases ν i with
    | none => rfl
    | some t => exact (termBind_shift_open _ t).symm

theorem Tel.bind_values_comp (t : Tel) (ν μ : ObservationEnv) :
    Tel.bind (SubstEnv.valuesOnly μ) (Tel.bind (SubstEnv.valuesOnly ν) t) =
      Tel.bind (SubstEnv.valuesOnly (fun i => (ν i).bind (termBind? μ))) t := by
  simp only [Tel.bind, Tel.norm_rawBind]
  simp only [SubstEnv.valuesOnly, ← Tel.rawSubstV_eq_rawBind, Tel.rawSubstV_comp]

theorem Tel.bind_open_exchange (t : Tel) (ν : ObservationEnv) (o : Option Term) :
    Tel.bind (SubstEnv.valuesOnly ν) (Tel.bind (SubstEnv.valuesOnly (openingEnv o)) t) =
      Tel.bind (SubstEnv.valuesOnly (openingEnv (o.bind (termBind? ν))))
        (Tel.bind (SubstEnv.valuesOnly (upValues ν)) t) := by
  rw [Tel.bind_values_comp, Tel.bind_values_comp, opening_comp]

theorem argumentsEnv_eq (v : Val) : Tel.argumentsEnv v = SubstEnv.valuesOnly (openingEnv v.toTerm?) := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1
  funext i
  cases i <;> rfl

theorem Ty.bind_norm (a : Ty) (θ : SubstEnv) : Ty.bind θ a.norm = Ty.bind θ a := by
  exact Ty.norm_rawBind θ a

theorem Eff.bind_norm (e : Eff) (θ : SubstEnv) : Eff.bind θ e.norm = Eff.bind θ e := by
  exact Eff.norm_rawBind θ e

theorem Tel.bind_param (n a t θ) : Tel.bind θ (.param n a t) = .param n (a.bind θ) (Tel.bind θ.up t) := rfl

theorem Tel.bind_done (r e θ) : Tel.bind θ (.done r e) = .done (r.bind θ) (Eff.bind θ e) := rfl

/-- 部分観測のNoneを保ったまま、逐次具体化と外側の値置換を交換する。 -/
theorem Tel.bind_norm (t : Tel) (θ : SubstEnv) : Tel.bind θ t.norm = Tel.bind θ t := Tel.norm_rawBind θ t

theorem Tel.bind_renaming (t : Tel) (k c : Nat) :
    Tel.bind (renEnv (shiftIndex k c)) t = (Tel.shiftV k c t).norm := by
  rw [Tel.shiftV_eq_rawBind]
  rfl

/-- paramの一束縛を除く具体化と、外側の単調な移動の交換。 -/
theorem Tel.open_shift (t : Tel) (v : Val) (k c : Nat) :
    Tel.bind (Tel.argumentsEnv (v.rename (shiftIndex k c))) (Tel.shiftV k (c+1) t) =
      Tel.shiftV k c (Tel.bind (Tel.argumentsEnv v) t) := by
  have hh := Tel.bind_open_exchange t (renEnv (shiftIndex k c)).values v.toTerm?
  have hv : (v.rename (shiftIndex k c)).toTerm? =
      v.toTerm?.bind (termBind? (renEnv (shiftIndex k c)).values) := by
    rw [Val.toTerm_rename]
    cases v.toTerm? <;> simp [renEnv, termBind?_renaming]
  have hup : SubstEnv.valuesOnly (upValues (renEnv (shiftIndex k c)).values) =
      renEnv (shiftIndex k (c+1)) := by
    rw [renEnv_values, upValues_shiftIndex]
    rfl
  rw [hup, Tel.bind_renaming, Tel.bind_norm] at hh
  rw [← argumentsEnv_eq] at hh
  change Tel.bind (renEnv (shiftIndex k c)) (Tel.bind (Tel.argumentsEnv v) t) = _ at hh
  rw [Tel.bind_renaming, Tel.norm_shiftV] at hh
  have hn : (Tel.bind (Tel.argumentsEnv v) t).norm = Tel.bind (Tel.argumentsEnv v) t := Tel.norm_idem _
  rw [hn] at hh
  rw [argumentsEnv_eq, hv]
  exact hh.symm

theorem Tel.open_subst (t : Tel) (v : Val) (ν : Nat → Val) (ρ : Nat → LocalRef) :
    Tel.bind (Tel.argumentsEnv (v.subst ν ρ)) (Tel.bind (valEnv (upSubst 1 ν)) t) =
      Tel.bind (valEnv ν) (Tel.bind (Tel.argumentsEnv v) t) := by
  rw [argumentsEnv_eq, argumentsEnv_eq, Val.toTerm_subst_optional]
  rw [valEnv_upSubst_one]
  exact (Tel.bind_open_exchange t (valEnv ν).values v.toTerm?).symm

theorem Tel.arguments_subst (t : Tel) (vs : List Val) (ν : Nat → Val) (ρ : Nat → LocalRef) :
    Tel.arguments (Tel.bind (valEnv ν) t) (Val.substList ν vs ρ) =
      (Tel.arguments t vs).map (fun (as, r, e) => (as.map (substTyValues ν), substTyValues ν r, substEffValues ν e)) := by
  induction vs generalizing t with
  | nil =>
    cases t <;> simp only [Tel.bind_done, Tel.bind_param, Tel.arguments, Val.substList,
      Option.map_some, Option.map_none, substTyValues, substEffValues, Ty.bind,
      Eff.bind, Ty.norm_idem, Eff.norm_idem, List.map_nil, Ty.norm_rawBind, Eff.norm_rawBind]
  | cons v vs ih =>
    cases t with
    | done r e => simp only [Tel.bind_done, Tel.arguments, Val.substList, Option.map_none]
    | param n a t =>
      simp only [Tel.bind_param, Val.substList, Tel.arguments]
      have he : Tel.bind (Tel.argumentsEnv (v.subst ν ρ)) (Tel.bind (valEnv ν).up t) =
          Tel.bind (valEnv ν) (Tel.bind (Tel.argumentsEnv v) t) := by
        rw [argumentsEnv_eq, argumentsEnv_eq, Val.toTerm_subst_optional]
        exact (Tel.bind_open_exchange t (valEnv ν).values v.toTerm?).symm
      rw [he, ih]
      simp only [Option.map_map]
      congr 1
      funext x
      obtain ⟨as, r, e⟩ := x
      simp only [Function.comp_def, List.map_cons, substTyValues, Ty.bind, Ty.norm_idem, Ty.norm_rawBind]

theorem Tel.arguments_map (t : Tel) (vs : List Val) (ν : ObservationEnv) (g : Val → Val)
    (hg : ∀ v, (g v).toTerm? = v.toTerm?.bind (termBind? ν)) :
    Tel.arguments (Tel.bind (SubstEnv.valuesOnly ν) t) (vs.map g) =
      (Tel.arguments t vs).map (fun (as, r, e) =>
        (as.map (Ty.bind (SubstEnv.valuesOnly ν)), r.bind (SubstEnv.valuesOnly ν), Eff.bind (SubstEnv.valuesOnly ν) e)) := by
  induction vs generalizing t with
  | nil =>
    cases t <;> simp only [Tel.bind_done, Tel.bind_param, Tel.arguments, List.map_nil,
      Option.map_some, Option.map_none, Ty.bind, Eff.bind, Ty.norm_idem, Eff.norm_idem, Ty.norm_rawBind, Eff.norm_rawBind]
  | cons v vs ih =>
    cases t with
    | done r e => simp only [Tel.bind_done, Tel.arguments, List.map_cons, Option.map_none]
    | param n a t =>
      simp only [Tel.bind_param, List.map_cons, Tel.arguments]
      have he : Tel.bind (Tel.argumentsEnv (g v)) (Tel.bind (SubstEnv.valuesOnly ν).up t) =
          Tel.bind (SubstEnv.valuesOnly ν) (Tel.bind (Tel.argumentsEnv v) t) := by
        rw [argumentsEnv_eq, argumentsEnv_eq, hg]
        exact (Tel.bind_open_exchange t ν v.toTerm?).symm
      rw [he, ih]
      simp only [Option.map_map]
      congr 1; funext x; obtain ⟨as, r, e⟩ := x
      simp only [Function.comp_def, List.map_cons, Ty.bind, Ty.norm_idem, Ty.norm_rawBind]

theorem Tel.arguments_norm (t : Tel) (vs : List Val) : Tel.arguments t.norm vs = Tel.arguments t vs := by
  induction vs generalizing t with
  | nil => cases t <;> simp [Tel.arguments, Tel.norm, Ty.norm_idem, Eff.norm_idem]
  | cons v vs ih =>
    cases t <;> simp only [Tel.norm, Tel.arguments, Ty.norm_idem]
    rw [show Tel.bind (Tel.argumentsEnv v) (Tel.norm _) = Tel.bind (Tel.argumentsEnv v) _ from Tel.norm_rawBind _ _]

theorem Tel.arguments_normal {t vs as r e} (h : Tel.arguments t vs = some (as, r, e)) :
    as.map Ty.norm = as ∧ r.norm = r ∧ e.norm = e := by
  induction vs generalizing t as r e with
  | nil =>
    cases t <;> simp only [Tel.arguments, Option.some.injEq, reduceCtorEq] at h
    cases h
    exact ⟨rfl, Ty.norm_idem _, Eff.norm_idem _⟩
  | cons v vs ih =>
    cases t with
    | done r e => simp [Tel.arguments] at h
    | param n a t =>
      simp only [Tel.arguments] at h
      obtain ⟨⟨as', r', e'⟩, hh, he⟩ := Option.map_eq_some_iff.mp h
      cases he
      obtain ⟨has, hr, he⟩ := ih hh
      exact ⟨by simp only [List.map_cons, Ty.norm_idem, has], hr, he⟩

theorem Tel.arguments_shift {t vs as r e} (h : Tel.arguments t vs = some (as, r, e)) (k c : Nat) :
    Tel.arguments (Tel.shiftV k c t) (Val.renameList (shiftIndex k c) vs) =
      some (as.map (Ty.shiftV k c), r.shiftV k c, e.shiftV k c) := by
  have hg : ∀ v : Val, (v.rename (shiftIndex k c)).toTerm? =
      v.toTerm?.bind (termBind? (renEnv (shiftIndex k c)).values) := by
    intro v
    rw [Val.toTerm_rename]
    cases v.toTerm? <;> simp only [Option.map_none, Option.bind_none, Option.map_some,
      Option.bind_some, renEnv_values, termBind?_renaming]
  have hh := Tel.arguments_map t vs (renEnv (shiftIndex k c)).values (Val.rename (shiftIndex k c)) hg
  have hv : vs.map (Val.rename (shiftIndex k c)) = Val.renameList (shiftIndex k c) vs := by
    clear h hh
    induction vs with
    | nil => rfl
    | cons v vs ih => simp only [List.map_cons, Val.renameList, ih]
  have ht : Tel.bind (SubstEnv.valuesOnly (renEnv (shiftIndex k c)).values) t =
      (Tel.shiftV k c t).norm := by
    rw [Tel.shiftV_eq_rawBind]
    rfl
  rw [ht, hv, Tel.arguments_norm, h, Option.map_some] at hh
  obtain ⟨has, hr, he⟩ := Tel.arguments_normal h
  have ha : ∀ a ∈ as, a.norm = a := by
    intro a hm
    have hm' : a ∈ as.map Ty.norm := has.symm ▸ hm
    obtain ⟨a', _, he'⟩ := List.mem_map.mp hm'
    rw [← he', Ty.norm_idem]
  have hb : ∀ a : Ty, Ty.bind (SubstEnv.valuesOnly (renEnv (shiftIndex k c)).values) a = (a.shiftV k c).norm := by
    intro a; rw [Ty.shiftV_eq_renameTy]; rfl
  have he' : ∀ e : Eff, Eff.bind (SubstEnv.valuesOnly (renEnv (shiftIndex k c)).values) e = (e.shiftV k c).norm := by
    intro e; rw [Eff.shiftV_eq_renameEff]; rfl
  simp only [hb, he', Ty.norm_shiftV, Eff.norm_shiftV, hr, he] at hh
  have hl : as.map (Ty.bind (SubstEnv.valuesOnly (renEnv (shiftIndex k c)).values)) = as.map (Ty.shiftV k c) := by
    apply List.map_congr_left
    intro a hm
    rw [hb, Ty.norm_shiftV, ha a hm]
  rw [hl] at hh
  exact hh

theorem Tel.instantiate_eq_arguments (t : Tel) (vs : List Val) :
    Tel.instantiate t vs = (Tel.arguments t vs).map (fun (_, r, e) => (r, e)) := by
  induction vs generalizing t with
  | nil => cases t <;> simp [Tel.instantiate, Tel.arguments]
  | cons v vs ih =>
    cases t with
    | done r e => simp [Tel.instantiate, Tel.arguments]
    | param n a t =>
      simp only [Tel.instantiate, Tel.arguments, Option.map_map, ih]
      rfl

theorem Tel.instantiate_subst (t : Tel) (vs : List Val) (ν : Nat → Val) (ρ : Nat → LocalRef) :
    Tel.instantiate (Tel.bind (valEnv ν) t) (Val.substList ν vs ρ) =
      (Tel.instantiate t vs).map (fun (r, e) => (substTyValues ν r, substEffValues ν e)) := by
  simp only [Tel.instantiate_eq_arguments, Tel.arguments_subst, Option.map_map]
  rfl

theorem Tel.instantiate_shift {t vs r e} (h : Tel.instantiate t vs = some (r, e)) (k c : Nat) :
    Tel.instantiate (Tel.shiftV k c t) (Val.renameList (shiftIndex k c) vs) =
      some (r.shiftV k c, e.shiftV k c) := by
  rw [Tel.instantiate_eq_arguments] at h ⊢
  obtain ⟨⟨as, r', e'⟩, hh, he⟩ := Option.map_eq_some_iff.mp h
  cases he
  rw [Tel.arguments_shift hh k c]
  rfl

end
end Benitoite.Release.Refinement
