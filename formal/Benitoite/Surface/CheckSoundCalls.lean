import Benitoite.Surface.CheckSoundCollections

/-! 呼び出し・パイプ・部分適用の検査の健全性。 -/
set_option maxHeartbeats 2000000

namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

theorem holeTypes_atoms {atoms args} (h : HoleArgs.AtomsIn atoms args) :
    Tys.AtomsIn atoms args.holeTypes := by
  induction args using (measure (fun a : HoleArgs => sizeOf a)).wf.induction with
  | h args ih =>
    cases args with
    | nil => trivial
    | expr e args =>
      simp only [HoleArgs.AtomsIn, HoleArgs.holeTypes] at *
      exact ih args (by change sizeOf args < _; dsimp only; simp only [HoleArgs.expr.sizeOf_spec]; omega) h.2
    | hole t args =>
      simp only [HoleArgs.AtomsIn, HoleArgs.holeTypes] at *
      exact ⟨h.1, ih args (by change sizeOf args < _; dsimp only; simp only [HoleArgs.hole.sizeOf_spec]; omega) h.2⟩

theorem conCall_case {q c ts args} : CaseSound q (.expr (.conCall c ts args)) := by
  intro ih
  have iha : ExprsSound q args := ih (.exprs args) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨cd, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨u, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨εa, mid, hc, h⟩ := checking_bind_ok h
  have hp := substParams_atoms (es := []) he.1 (by simp) (hq.declarations.2.1 c cd (lookup_ok hd))
  have ht := iha.1 _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR hp hc
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨.E_ConCall (lookup_ok hd) (by simpa using (require_ok hlen).1) ?_, he.1, ht.2⟩
  simpa only [substParams_eq] using ht.1

theorem call_case {q f args} : CaseSound q (.expr (.call f args)) := by
  intro ih
  have ihf : ExprSound q f := ih (.expr f) (by simp [CheckNode.size] <;> omega)
  have iha : ExprsSound q args := ih (.exprs args) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨⟨ft, εf⟩, mid, hf, h⟩ := checking_bind_ok h
  obtain ⟨⟨ps, r, εcall⟩, hv, h⟩ := checking_lift_bind_ok h
  have ftSound := ihf _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR hf
  have eqf := fnView_ok hv
  rw [eqf] at ftSound
  obtain ⟨εa, mid', ha, h⟩ := checking_bind_ok h
  have atSound := iha.1 _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR ftSound.2.1.1 ha
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨?_, ftSound.2.1.2.1, union_atoms _ _ _⟩
  rw [union_eq ftSound.2.2 (union_atoms _ _ _), union_eq atSound.2 ftSound.2.1.2.2]
  exact .E_Call ftSound.1 atSound.1

/-- 成功した先頭の参照から、引数の非空の形を得る。 -/
theorem head_lookup_cons {α : Type} {xs : List α} {path reason t}
    (h : lookup path reason xs.head? = .ok t) : xs = t :: xs.tail := by
  have hh := lookup_ok h
  cases xs with
  | nil => simp at hh
  | cons a as => simp only [List.head?_cons, Option.some.injEq] at hh; subst a; rfl

theorem unary_of_head {α : Type} {xs : List α} {path reason t}
    (hl : xs.length = 1) (h : lookup path reason xs.head? = .ok t) : xs = [t] := by
  have hc := head_lookup_cons h
  rw [hc] at hl
  have ht : xs.tail = [] := List.length_eq_zero_iff.mp (by simpa using hl)
  simpa [ht] using hc

theorem pipe_call_case {q lhs f args} : CaseSound q (.expr (.pipe lhs (.call f args))) := by
  intro ih
  have ihl := (pipe_case_ih ih).1
  obtain ⟨ihf, iha⟩ := pipe_call_case_ih ih
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨⟨ft, εf⟩, mid, hf, h⟩ := checking_bind_ok h
  obtain ⟨⟨ps, r, εcall⟩, hv, h⟩ := checking_lift_bind_ok h
  obtain ⟨t, hhead, h⟩ := checking_lift_bind_ok h
  have fs := ihf _ _ _ _ _ _ _ _ _ hq he.2.1 hΓ hR hf
  rw [fnView_ok hv] at fs
  have hc := head_lookup_cons hhead
  have psAtoms := fs.2.1.1
  rw [hc] at psAtoms
  obtain ⟨εl, mid', hl, hlAtoms, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ihl _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR h) psAtoms.1 h
  obtain ⟨εa, mid'', ha, h⟩ := checking_bind_ok h
  have as_ := iha.1 _ _ _ _ _ _ _ _ _ hq he.2.2 hΓ hR psAtoms.2 ha
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨?_, fs.2.1.2.1, union_atoms _ _ _⟩
  rw [union_eq hlAtoms (union_atoms _ _ _), union_eq fs.2.2 (union_atoms _ _ _),
    union_eq as_.2 fs.2.1.2.2]
  exact .E_PipeCall hl (by rw [← hc]; exact fs.1) as_.1

theorem pipe_conCall_case {q lhs c ts args} :
    CaseSound q (.expr (.pipe lhs (.conCall c ts args))) := by
  intro ih
  have ihl := (pipe_case_ih ih).1
  have iha := pipe_conCall_case_ih ih
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨cd, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨u, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨t, hhead, h⟩ := checking_lift_bind_ok h
  have hp := substParams_atoms (es := []) he.2.1 (by simp) (hq.declarations.2.1 c cd (lookup_ok hd))
  have hc := head_lookup_cons hhead
  rw [hc] at hp
  obtain ⟨εl, mid, hl, hlAtoms, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ihl _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR h) hp.1 h
  obtain ⟨εa, mid', ha, h⟩ := checking_bind_ok h
  have as_ := iha.1 _ _ _ _ _ _ _ _ _ hq he.2.2 hΓ hR hp.2 ha
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨?_, he.2.1, union_atoms _ _ _⟩
  rw [union_eq hlAtoms as_.2]
  exact .E_PipeConCall (lookup_ok hd) (by simpa using (require_ok hlen).1)
    (by simpa only [substParams_eq] using hc) hl as_.1

theorem pipe_conValue_case {q lhs c ts ps} :
    CaseSound q (.expr (.pipe lhs (.conValue c ts ps))) := by
  intro ih
  have ihl := (pipe_case_ih ih).1
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨cd, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hps, h⟩ := checking_lift_bind_ok h
  obtain ⟨u3, hunary, h⟩ := checking_lift_bind_ok h
  obtain ⟨t, hhead, h⟩ := checking_lift_bind_ok h
  have hc := unary_of_head (by simpa using (require_ok hunary).1) hhead
  have hp := he.2.2
  rw [hc] at hp
  obtain ⟨εl, mid, hl, hlAtoms, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ihl _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR h) hp.1 h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have psEq := tysEq_sound he.2.2
    (substParams_atoms (es := []) he.2.1 (by simp) (hq.declarations.2.1 c cd (lookup_ok hd)))
    (require_ok hps).1
  exact ⟨.E_PipeConValue (lookup_ok hd) (by simpa using (require_ok hlen).1)
    (by simpa only [substParams_eq] using psEq) hc hl, he.2.1, hlAtoms⟩

theorem partialCall_case {q f args r eff} :
    CaseSound q (.expr (.partialCall f args r eff)) := by
  intro ih
  have ihf : ExprSound q f := ih (.expr f) (by simp [CheckNode.size] <;> omega)
  have iha : HoleArgsSound q args := ih (.holes args) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨u1, hholes, h⟩ := checking_lift_bind_ok h
  obtain ⟨⟨ft, εf⟩, mid, hf, h⟩ := checking_bind_ok h
  obtain ⟨⟨ps, r0, εcall⟩, hv, h⟩ := checking_lift_bind_ok h
  have fs := ihf _ _ _ _ _ _ _ _ _ hq he.1 (Env.atoms_hideConts hΓ)
    (fun t ht => by cases ht; exact he.2.2.1) hf
  rw [fnView_ok hv] at fs
  obtain ⟨εa, mid', ha, h⟩ := checking_bind_ok h
  have as_ := iha _ _ _ _ _ _ _ _ _ hq he.2.1 (Env.atoms_hideConts hΓ)
    (fun t ht => by cases ht; exact he.2.2.1) fs.2.1.1 ha
  obtain ⟨u2, hr, h⟩ := checking_lift_bind_ok h
  obtain ⟨u3, heff, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨.E_PartialCall ((nonemptyList_spec _).mp (require_ok hholes).1) fs.1 as_.1
    (tyLe_sound fs.2.1.2.1 he.2.2.1 (require_ok hr).1) ?_,
    ⟨?_, he.2.2.1, he.2.2.2⟩, emptyEff_atoms _⟩
  · have hh := acceptEff_sound (union_atoms _ _ _) heff
    rwa [union_eq fs.2.2 (union_atoms _ _ _), union_eq as_.2 fs.2.1.2.2] at hh
  · exact holeTypes_atoms he.2.1

theorem partialCon_case {q c ts args} : CaseSound q (.expr (.partialCon c ts args)) := by
  intro ih
  have iha : HoleArgsSound q args := ih (.holes args) (by simp [CheckNode.size] <;> omega)
  intro C Γ R p path s s' a ε hq he hΓ hR h
  simp only [Expr.AtomsIn] at he
  obtain ⟨cd, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hholes, h⟩ := checking_lift_bind_ok h
  obtain ⟨εa, mid, ha, h⟩ := checking_bind_ok h
  have as_ := iha _ _ _ _ _ _ _ _ _ hq he.2 (Env.atoms_hideConts hΓ)
    (fun t ht => by cases ht; exact he.1)
    (substParams_atoms (es := []) he.1 (by simp) (hq.declarations.2.1 c cd (lookup_ok hd))) ha
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨.E_PartialCon (lookup_ok hd) (by simpa using (require_ok hlen).1)
    ((nonemptyList_spec _).mp (require_ok hholes).1) ?_ (Or.inl rfl),
    ⟨holeTypes_atoms he.2, he.1, as_.2⟩, emptyEff_atoms _⟩
  simpa only [substParams_eq] using as_.1

/-- 通常の値を右辺とするパイプの成功経路。 -/
theorem pipe_apply_of_ok {q C Γ R p path lhs rhs s s' a ε}
    (ihl : ExprSound q lhs) (ihr : ExprSound q rhs)
    (hq : q.Sound) (he : (Expr.pipe lhs rhs).AtomsIn q.atoms)
    (hΓ : Env.AtomsIn q.atoms Γ) (hR : ReturnAtoms q.atoms R)
    (h : (do
      require (child path 1) "invalid pipe value" (pipeValue rhs)
      let (ft, εf) ← checkExprR q .strict C Γ R .other (child path 1) rhs
      let (ps, r, εcall) ← fnView (child path 1) ft
      require (child path 1) "pipe value must be unary" (ps.length == 1)
      let t ← lookup (child path 1) "pipe value has no parameter" ps.head?
      let εl ← accept q (child path 0) t (← checkExprR q .strict C Γ R .other (child path 0) lhs)
      pure (r, union q εl (union q εf εcall)) : Checking Inferred) s = .ok ((a, ε), s')) :
    HasType q.D q.B q.opPrim C Γ R p (.pipe lhs rhs) a ε ∧
      a.AtomsIn q.atoms ∧ ε.AtomsIn q.atoms := by
  simp only [Expr.AtomsIn] at he
  obtain ⟨u1, hvalue, h⟩ := checking_lift_bind_ok h
  obtain ⟨⟨ft, εf⟩, mid, hf, h⟩ := checking_bind_ok h
  obtain ⟨⟨ps, r, εcall⟩, hv, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hunary, h⟩ := checking_lift_bind_ok h
  obtain ⟨t, hhead, h⟩ := checking_lift_bind_ok h
  have fs := ihr _ _ _ _ _ _ _ _ _ hq he.2 hΓ hR hf
  rw [fnView_ok hv] at fs
  have hc := unary_of_head (by simpa using (require_ok hunary).1) hhead
  have hp := fs.2.1.1
  rw [hc] at hp
  obtain ⟨εl, mid', hl, hlAtoms, h⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ihl _ _ _ _ _ _ _ _ _ hq he.1 hΓ hR h) hp.1 h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨?_, fs.2.1.2.1, union_atoms _ _ _⟩
  rw [union_eq hlAtoms (union_atoms _ _ _), union_eq fs.2.2 fs.2.1.2.2]
  exact .E_PipeApply ((pipeValue_spec _).mp (require_ok hvalue).1) hl
    (by rw [← hc]; exact fs.1)

theorem pipe_case {q lhs rhs} : CaseSound q (.expr (.pipe lhs rhs)) := by
  cases rhs <;> first
    | exact pipe_call_case
    | exact pipe_conCall_case
    | exact pipe_conValue_case
    | intro ih C Γ R p path s s' a ε hq he hΓ hR h
      exact pipe_apply_of_ok (pipe_case_ih ih).1 (pipe_case_ih ih).2 hq he hΓ hR h

end Benitoite.Surface.Check
