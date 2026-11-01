import Benitoite.Release.Refinement.FiniteCompare

/-! 非依存の関数列の有限な逆移動と再構築。 -/
namespace Benitoite.Release.Refinement
open Order

/-- 深さごとの注釈を外側へ戻す候補。再構築の検査までは依存の有無を断定しない。 -/
private def Tel.fnParts : Tel → List Ty × Ty × Eff
  | .done r e => ([], r, e)
  | .param _ a t =>
    let f := t.fnParts
    (a :: f.1.map (Ty.renameValues (unshiftValue 1 0)),
      f.2.1.renameValues (unshiftValue 1 0), Eff.renameValues (unshiftValue 1 0) f.2.2)

private theorem Tel.fnParts_support (p : Atom → Prop) (t : Tel) (h : t.Support p) :
    Ty.SupportList p t.fnParts.1 ∧ t.fnParts.2.1.Support p ∧ t.fnParts.2.2.Support p := by
  cases t with
  | done r e => exact ⟨trivial, h.1, h.2⟩
  | param n a t =>
    obtain ⟨hps, hr, he⟩ := Tel.fnParts_support p t h.2
    exact ⟨⟨h.1, by simpa only [←renameValueTys_eq_map] using
      (Ty.supportList_renameValues_iff p _ (unshiftValue 1 0)).mpr hps⟩,
      (Ty.support_renameValues_iff p _ _).mpr hr, (Eff.support_renameValues_iff p _ _).mpr he⟩

private theorem Tel.fnParts_toTel (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    (hn : NamesWF ns ps) : (Ty.toTel ns ps r e).fnParts = (ps, r, e) := by
  induction ns generalizing ps r e with
  | nil =>
    cases ps with
    | nil => rfl
    | cons => simp [NamesWF] at hn
  | cons n ns ih =>
    cases ps with
    | nil => simp [NamesWF] at hn
    | cons a ps =>
      have hn' : NamesWF ns (shiftVTys 1 0 ps) :=
        ⟨by simpa [NamesWF] using Nat.succ.inj hn.1, hn.2.of_cons⟩
      change (a :: ((Ty.toTel ns (shiftVTys 1 0 ps) (r.shiftV 1 0) (Eff.shiftV 1 0 e)).fnParts.1.map
        (Ty.renameValues (unshiftValue 1 0))), _, _) = _
      rw [ih _ _ _ hn']
      simp only [Ty.unshift_shift, Eff.unshift_shift, shiftVTys_eq_map, List.map_map,
        Function.comp_def]
      exact congrArg (fun xs => (a :: xs, r, e)) (List.map_id ps)

instance (ns : List String) (ps : List Ty) : Decidable (NamesWF ns ps) := by
  unfold NamesWF; infer_instance

def Tel.fnViewWith? (s : List Atom) (t : Tel) : Option FnView :=
  let ps := t.fnParts
  if hn : NamesWF t.names ps.1 then
    let f : FnView := ⟨t.names, ps.1, ps.2.1, ps.2.2, hn⟩
    if telCompareWith s f.toTel t = .eq then some f else none
  else none

def Ty.foldFnWith (s : List Atom) (t : Tel) : Ty :=
  match t.fnViewWith? s with
  | some f => .fn f.names f.params f.result f.effect
  | none => .dependentFn t

theorem telCompareWith_eq_iff (s : List Atom) (t u : Tel)
    (ht : t.Support (· ∈ s)) (hu : u.Support (· ∈ s)) :
    telCompareWith s t u = .eq ↔ t = u := by
  have h := compareWith_eq_compare s (.dependentFn t) (.dependentFn u) ht hu
  simp only [tyCompareWith] at h
  rw [h, tyCompare_eq_iff, Ty.dependentFn.injEq]

private theorem Tel.fnViewWith?_sound (s : List Atom) (t : Tel) (f : FnView)
    (ht : t.Support (· ∈ s)) (h : t.fnViewWith? s = some f) : f.toTel = t := by
  unfold Tel.fnViewWith? at h
  dsimp only at h
  split at h
  next hn =>
    let g : FnView := ⟨t.names, t.fnParts.1, t.fnParts.2.1, t.fnParts.2.2, hn⟩
    have hg : g.toTel.Support (· ∈ s) :=
      (Ty.support_toTel_iff _ _ _ _ _ hn).mpr (Tel.fnParts_support _ t ht)
    split at h
    next he =>
      have hgf : g = f := Option.some.inj h
      exact hgf ▸ (telCompareWith_eq_iff _ _ _ hg ht).mp he
    next => cases h
  next => cases h

private theorem Tel.fnViewWith?_toTel (s : List Atom) (f : FnView)
    (ht : f.toTel.Support (· ∈ s)) : f.toTel.fnViewWith? s = some f := by
  unfold Tel.fnViewWith?
  simp only [FnView.toTel, Tel.names_toTel f.names_wf, Tel.fnParts_toTel _ _ _ _ f.names_wf]
  rw [dite_eq_left f.names_wf]
  have he : (⟨f.names, f.params, f.result, f.effect, f.names_wf⟩ : FnView) = f := by cases f; rfl
  simp only [he]
  change (if telCompareWith s f.toTel f.toTel = .eq then some f else none) = some f
  exact ite_eq_left ((telCompareWith_eq_iff _ _ _ ht ht).mpr rfl)

theorem Tel.fnViewWith?_eq_some_iff (s : List Atom) (t : Tel) (f : FnView)
    (ht : t.Support (· ∈ s)) : t.fnViewWith? s = some f ↔ f.toTel = t := by
  refine ⟨Tel.fnViewWith?_sound s t f ht, ?_⟩
  intro he
  subst t
  exact Tel.fnViewWith?_toTel s f ht

theorem Tel.fnViewWith?_eq_fnView? (s : List Atom) (t : Tel)
    (ht : t.Support (· ∈ s)) : t.fnViewWith? s = t.fnView? := by
  cases hw : t.fnViewWith? s with
  | some f => exact ((Tel.fnView?_eq_some_iff t f).mpr
      ((Tel.fnViewWith?_eq_some_iff s t f ht).mp hw)).symm
  | none =>
    cases hr : t.fnView? with
    | none => rfl
    | some f =>
      have h := (Tel.fnViewWith?_eq_some_iff s t f ht).mpr ((Tel.fnView?_eq_some_iff t f).mp hr)
      rw [hw] at h
      cases h

theorem Ty.foldFnWith_eq_foldFn (s : List Atom) (t : Tel)
    (ht : t.Support (· ∈ s)) : Ty.foldFnWith s t = Ty.foldFn t := by
  simp only [Ty.foldFnWith, Ty.foldFn, Tel.fnViewWith?_eq_fnView? s t ht]
  rfl

end Benitoite.Release.Refinement
