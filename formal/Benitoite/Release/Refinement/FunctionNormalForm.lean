import Benitoite.Release.Refinement.ValueRenamingSyntax

/-! # 非依存の依存列から通常の関数型への写し -/
namespace Benitoite.Release.Refinement

def Tel.names : Tel → List String
  | .done _ _ => []
  | .param n _ t => n :: t.names

theorem Tel.names_toTel {ns ps r e} (h : NamesWF ns ps) : (Ty.toTel ns ps r e).names = ns := by
  induction ns generalizing ps r e with
  | nil => cases ps <;> simp_all [NamesWF, Ty.toTel, Tel.names]
  | cons n ns ih =>
    cases ps with
    | nil => simp [NamesWF] at h
    | cons a ps =>
      simp only [Ty.toTel, Tel.names]
      congr 1
      exact ih ⟨by simpa [NamesWF] using h.1, h.2.of_cons⟩

structure FnView where
  names : List String
  params : List Ty
  result : Ty
  effect : Eff
  names_wf : NamesWF names params

def FnView.toTel (f : FnView) : Tel := Ty.toTel f.names f.params f.result f.effect

private theorem toTel_fields {ns ps qs r s e f}
    (hp : NamesWF ns ps) (hq : NamesWF ns qs)
    (he : Ty.toTel ns ps r e = Ty.toTel ns qs s f) : ps = qs ∧ r = s ∧ e = f := by
  induction ns generalizing ps qs r s e f with
  | nil =>
    cases ps with
    | cons => simp [NamesWF] at hp
    | nil =>
      cases qs with
      | cons => simp [NamesWF] at hq
      | nil => exact ⟨rfl, (Tel.done.inj he).1, (Tel.done.inj he).2⟩
  | cons n ns ih =>
    cases ps with
    | nil => simp [NamesWF] at hp
    | cons a ps =>
      cases qs with
      | nil => simp [NamesWF] at hq
      | cons b qs =>
        obtain ⟨_, hab, ht⟩ := Tel.param.inj he
        have hp' : NamesWF ns (shiftVTys 1 0 ps) :=
          ⟨by simpa [NamesWF] using Nat.succ.inj hp.1, hp.2.of_cons⟩
        have hq' : NamesWF ns (shiftVTys 1 0 qs) :=
          ⟨by simpa [NamesWF] using Nat.succ.inj hq.1, hq.2.of_cons⟩
        obtain ⟨hps, hrs, hef⟩ := ih hp' hq' ht
        have hpq := congrArg (List.map (Ty.renameValues (unshiftValue 1 0))) hps
        have hpq' : ps = qs := by
          simpa [shiftVTys_eq_map, List.map_map, Function.comp_def, Ty.unshift_shift] using hpq
        exact ⟨by rw [hab, hpq'], Ty.shiftV_injective 1 0 hrs,
          Eff.shiftV_injective 1 0 hef⟩

theorem FnView.toTel_injective : Function.Injective FnView.toTel := by
  rintro ⟨ns, ps, r, e, hp⟩ ⟨ms, qs, s, f, hq⟩ he
  have hn : ns = ms := (Tel.names_toTel hp).symm.trans
    ((congrArg Tel.names he).trans (Tel.names_toTel hq))
  cases hn
  obtain ⟨rfl, rfl, rfl⟩ := toTel_fields hp hq he
  rfl

def FnView.renameValues (f : FnView) (ξ : Nat → Nat) : FnView :=
  ⟨f.names, f.params.map (Ty.renameValues ξ), f.result.renameValues ξ,
    Eff.renameValues ξ f.effect, ⟨by simpa using f.names_wf.1, f.names_wf.2⟩⟩

theorem FnView.toTel_renameValues (f : FnView) (ξ : Nat → Nat) :
    (f.renameValues ξ).toTel = f.toTel.renameValues ξ :=
  (Tel.renameValues_toTel _ _ _ _ _).symm

noncomputable def Tel.fnView? (t : Tel) : Option FnView := by
  classical
  exact if h : ∃ f : FnView, f.toTel = t then some (Classical.choose h) else none

theorem Tel.fnView?_eq_some_iff (t : Tel) (f : FnView) :
    t.fnView? = some f ↔ f.toTel = t := by
  classical
  unfold Tel.fnView?
  split
  next h =>
    constructor
    · intro he
      cases Option.some.inj he
      exact Classical.choose_spec h
    · intro he
      exact congrArg some (FnView.toTel_injective ((Classical.choose_spec h).trans he.symm))
  next h => simp only [reduceCtorEq, false_iff]; intro he; exact h ⟨f, he⟩

noncomputable def Ty.foldFn (t : Tel) : Ty :=
  match t.fnView? with
  | some f => .fn f.names f.params f.result f.effect
  | none => .dependentFn t

theorem Ty.foldFn_toTel (f : FnView) :
    Ty.foldFn f.toTel = .fn f.names f.params f.result f.effect := by
  unfold Ty.foldFn
  rw [(Tel.fnView?_eq_some_iff _ _).mpr rfl]

theorem Ty.foldFn_no_view {t : Tel} (h : ¬ ∃ f : FnView, f.toTel = t) :
    Ty.foldFn t = .dependentFn t := by
  classical
  simp only [Ty.foldFn, Tel.fnView?, h, ↓reduceDIte]

theorem Ty.foldFn_shiftV (t : Tel) (k c : Nat) :
    Ty.foldFn (Tel.shiftV k c t) = (Ty.foldFn t).shiftV k c := by
  classical
  by_cases h : ∃ f : FnView, f.toTel = t
  · obtain ⟨f, rfl⟩ := h
    have he : Tel.shiftV k c f.toTel = (f.renameValues (shiftIndex k c)).toTel := by
      rw [FnView.toTel_renameValues, Tel.shiftV_eq_renameValues]
    rw [he, Ty.foldFn_toTel, Ty.foldFn_toTel]
    have hfun : Ty.shiftV k c = Ty.renameValues (shiftIndex k c) :=
      funext (fun a => Ty.shiftV_eq_renameValues a k c)
    simp only [FnView.renameValues, Ty.shiftV, shiftVTys_eq_map, hfun, Eff.shiftV_eq_renameValues]
  · have hs : ¬ ∃ f : FnView, f.toTel = Tel.shiftV k c t := by
      rintro ⟨f, hf⟩
      apply h
      refine ⟨f.renameValues (unshiftValue k c), ?_⟩
      rw [FnView.toTel_renameValues, hf, Tel.unshift_shift]
    rw [Ty.foldFn_no_view h, Ty.foldFn_no_view hs]
    rfl

end Benitoite.Release.Refinement
