import Benitoite.Release.Refinement.Adequate

/-! # Atの成功から取り出す静的添字への所属 -/
namespace Benitoite.Release.Refinement
open Scope.Domain

private theorem snapshot_of_resolved {snapshot : Option PathEnv} {kind : Kind}
    {r : RangeExpr} {t : Target} {rs : List Range}
    (hv : ∀ σ, snapshot = some σ → σ.Valid)
    (hr : resolveSnapshot snapshot r = some rs) (hk : t.kind = kind)
    (hm : ∃ q ∈ rs, q.Mem t) : SnapshotMem snapshot kind r t := by
  cases snapshot with
  | none =>
    cases r with
    | absolute q => simp only [resolveSnapshot, Option.some.injEq] at hr; cases hr; exact ⟨hk, by simpa using hm⟩
    | based _ _ | secrets => cases hr
  | some σ =>
    refine ⟨hv σ rfl, hk, ?_⟩
    have he : resolveSnapshot (some σ) r = r.resolve σ := by cases r <;> rfl
    rw [he] at hr
    simp only [hr] at *
    exact hm

theorem checkAt.sound {snapshot kind pattern input bound target}
    (hv : ∀ σ, snapshot = some σ → σ.Valid)
    (h : checkAt snapshot kind pattern input bound = .ok target) :
    SnapshotMem snapshot kind pattern target ∧ SnapshotMem snapshot kind bound target := by
  unfold checkAt at h
  split at h <;> try cases h
  rename_i ps t bs hp ht hb
  split at h <;> try cases h
  rename_i hvTarget
  split at h <;> try cases h
  split at h <;> try cases h
  rename_i hmPattern
  split at h <;> try cases h
  rename_i hmBound
  have hk : target.kind = kind := Classical.byContradiction (fun hne => hvTarget (Or.inr hne))
  exact ⟨snapshot_of_resolved hv hp hk (Classical.byContradiction hmPattern),
    snapshot_of_resolved hv hb hk (Classical.byContradiction hmBound)⟩

theorem checkAt.absolute {snapshot kind pat t0 bound t}
    (h : checkAt snapshot kind pat (.absolute t0) bound = .ok t) : t = t0 := by
  unfold checkAt at h
  have hr : resolveTargetSnapshot snapshot (.absolute t0) = some t0 := by cases snapshot <;> rfl
  rw [hr] at h
  split at h <;> try cases h
  all_goals (split at h <;> try cases h)
  all_goals (split at h <;> try cases h)
  all_goals (split at h <;> try cases h)
  all_goals (split at h <;> try cases h)
  all_goals (simp_all)
  all_goals (try (cases h; rfl))

end Benitoite.Release.Refinement
