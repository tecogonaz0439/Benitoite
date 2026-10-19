import Benitoite.Surface.CheckSoundSequence

/-! 対応する検査と保証の範囲は設計書 07-04「証明する性質」に従う。
呼び出し・パイプ・部分適用の検査の健全性。 -/
set_option maxHeartbeats 2000000

namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

theorem conCall_case {q c ts args} : CaseSound q (.expr (.conCall c ts args)) := by
  intro ih
  have iha : ExprsSound q args := ih (.exprs args) (by simp [CheckNode.size] <;> omega)
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨cd, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨u, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨εa, mid, hc, h⟩ := checking_bind_ok h
  have hp := substParams_atoms (es := []) he.1 (by simp) (hq.declarations.2.1 c cd (lookup_ok hd))
  have ht := iha.1 Δ _ _ _ _ _ _ _ _ _ hB hq he.2 hΓ hR hp hc
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨.E_ConCall (lookup_ok hd) (by simpa using (require_ok hlen).1) ?_, he.1, ht.2⟩
  simpa only [substParams_eq ts [] cd.args (tysAtoms_iff.mp he.1) (by simp) (tysAtoms_iff.mp (hq.declarations.2.1 c cd (lookup_ok hd)))] using ht.1

theorem call_case {q f labels positions args} : CaseSound q (.expr (.call f labels positions args)) := by
  intro ih
  have ihf : ExprSound q f := ih (.expr f) (by simp [CheckNode.size] <;> omega)
  have iha : ExprsSound q args := ih (.exprs args) (by simp [CheckNode.size] <;> omega)
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have hSingle := (guardInferred_result h).2
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨⟨ft, εf⟩, mid, hf, h⟩ := checking_bind_ok h
  obtain ⟨⟨names, ps, r, εcall⟩, hv, h⟩ := checking_lift_bind_ok h
  have ftSound := ihf Δ _ _ _ _ _ _ _ _ _ hB hq he.1 hΓ hR hf
  have eqf := fnView_ok hv
  rw [eqf] at ftSound
  obtain ⟨uCall, hCall, h⟩ := checking_lift_bind_ok h
  obtain ⟨εa, mid', ha, h⟩ := checking_bind_ok h
  have atSound := iha.1 Δ _ _ _ _ _ _ _ _ _ hB hq he.2 hΓ hR (sourceTypes_atoms ftSound.2.1.1) ha
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have hSafe := (singleEffCheck_spec _ (union_atoms ftSound.2.2 (union_atoms atSound.2 ftSound.2.1.2.2))).mp hSingle.2
  refine ⟨?_, ftSound.2.1.2.1, union_atoms ftSound.2.2 (union_atoms atSound.2 ftSound.2.1.2.2)⟩
  rw [union_eq ftSound.2.2 (union_atoms atSound.2 ftSound.2.1.2.2), union_eq atSound.2 ftSound.2.1.2.2] at hSafe ⊢
  apply HasTypeQ.E_Call ftSound.1 ((callOk_spec _ _ _ _ _).mp (require_ok hCall).1) atSound.1
  exact hSafe

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

theorem pipe_call_case {q lhs f labels positions args} : CaseSound q (.expr (.pipe lhs (.call f labels positions args))) := by
  intro ih
  have ihl := (pipe_case_ih ih).1
  obtain ⟨ihf, iha⟩ := pipe_call_case_ih ih
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have hSingle := (guardInferred_result h).2
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨⟨ft, εf⟩, mid, hf, h⟩ := checking_bind_ok h
  obtain ⟨⟨names, ps, r, εcall⟩, hv, h⟩ := checking_lift_bind_ok h
  obtain ⟨t, hhead, h⟩ := checking_lift_bind_ok h
  have fs := ihf Δ _ _ _ _ _ _ _ _ _ hB hq he.2.1 hΓ hR hf
  rw [fnView_ok hv] at fs
  have hc := head_lookup_cons hhead
  have psAtoms := fs.2.1.1
  rw [hc] at psAtoms
  obtain ⟨εl, mid', hl, hlAtoms, h, hlAtomsClean⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ihl Δ _ _ _ _ _ _ _ _ _ hB hq he.1 hΓ hR h) psAtoms.1 h
  obtain ⟨uCall, hCall, h⟩ := checking_lift_bind_ok h
  obtain ⟨εa, mid'', ha, h⟩ := checking_bind_ok h
  have as_ := iha.1 Δ _ _ _ _ _ _ _ _ _ hB hq he.2.2 hΓ hR (sourceTypes_atoms fs.2.1.1) ha
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have hSafe := (singleEffCheck_spec _ (union_atoms hlAtoms (union_atoms fs.2.2 (union_atoms as_.2 fs.2.1.2.2)))).mp hSingle.2
  refine ⟨?_, fs.2.1.2.1, union_atoms hlAtoms (union_atoms fs.2.2 (union_atoms as_.2 fs.2.1.2.2))⟩
  rw [union_eq hlAtoms (union_atoms fs.2.2 (union_atoms as_.2 fs.2.1.2.2)), union_eq fs.2.2 (union_atoms as_.2 fs.2.1.2.2),
    union_eq as_.2 fs.2.1.2.2] at hSafe ⊢
  apply HasTypeQ.E_PipeCall hl (by rw [← hc]; exact fs.1)
    (by rw [← hc]; exact (callOk_spec _ _ _ _ _).mp (require_ok hCall).1)
    (by simpa only [← hc] using as_.1)
  exact hSafe

theorem pipe_conCall_case {q lhs c ts args} :
    CaseSound q (.expr (.pipe lhs (.conCall c ts args))) := by
  intro ih
  have ihl := (pipe_case_ih ih).1
  have iha := pipe_conCall_case_ih ih
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨cd, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨u, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨t, hhead, h⟩ := checking_lift_bind_ok h
  have hp := substParams_atoms (es := []) he.2.1 (by simp) (hq.declarations.2.1 c cd (lookup_ok hd))
  have hc := head_lookup_cons hhead
  rw [hc] at hp
  obtain ⟨εl, mid, hl, hlAtoms, h, hlAtomsClean⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ihl Δ _ _ _ _ _ _ _ _ _ hB hq he.1 hΓ hR h) hp.1 h
  obtain ⟨εa, mid', ha, h⟩ := checking_bind_ok h
  have as_ := iha.1 Δ _ _ _ _ _ _ _ _ _ hB hq he.2.2 hΓ hR hp.2 ha
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨?_, he.2.1, union_atoms hlAtoms as_.2⟩
  rw [union_eq hlAtoms as_.2]
  exact .E_PipeConCall (lookup_ok hd) (by simpa using (require_ok hlen).1)
    (by simpa only [substParams_eq ts [] cd.args (tysAtoms_iff.mp he.2.1) (by simp) (tysAtoms_iff.mp (hq.declarations.2.1 c cd (lookup_ok hd)))] using hc) hl as_.1

theorem pipe_conValue_case {q lhs c ts names ps} :
    CaseSound q (.expr (.pipe lhs (.conValue c ts names ps))) := by
  intro ih
  have ihl := (pipe_case_ih ih).1
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨cd, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨uNames, hNames, h⟩ := checking_lift_bind_ok h
  obtain ⟨uWF, hWF, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hps, h⟩ := checking_lift_bind_ok h
  obtain ⟨u3, hunary, h⟩ := checking_lift_bind_ok h
  obtain ⟨t, hhead, h⟩ := checking_lift_bind_ok h
  have hc := unary_of_head (by simpa using (require_ok hunary).1) hhead
  have hp := he.2.2
  rw [hc] at hp
  obtain ⟨εl, mid, hl, hlAtoms, h, hlAtomsClean⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ihl Δ _ _ _ _ _ _ _ _ _ hB hq he.1 hΓ hR h) hp.1 h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have psEq := tysEq_sound he.2.2
    (substParams_atoms (es := []) he.2.1 (by simp) (hq.declarations.2.1 c cd (lookup_ok hd)))
    (require_ok hps).1
  exact ⟨.E_PipeConValue (lookup_ok hd) (by simpa using (require_ok hlen).1)
    (eq_of_beq (require_ok hNames).1) ((namesWF_spec _ _).mp (require_ok hWF).1)
    (by simpa only [substParams_eq ts [] cd.args (tysAtoms_iff.mp he.2.1) (by simp) (tysAtoms_iff.mp (hq.declarations.2.1 c cd (lookup_ok hd)))] using psEq) hc hl, he.2.1, hlAtoms⟩

theorem partialCall_case {q f names args r eff} :
    CaseSound q (.expr (.partialCall f names args r eff)) := by
  intro ih
  have ihf : ExprSound q f := ih (.expr f) (by simp [CheckNode.size] <;> omega)
  have iha : HoleArgsSound q args := ih (.holes args) (by simp [CheckNode.size] <;> omega)
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have hSingle := (guardInferred_result h).2
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨u1, hholes, h⟩ := checking_lift_bind_ok h
  obtain ⟨⟨ft, εf⟩, mid, hf, h⟩ := checking_bind_ok h
  obtain ⟨⟨calleeNames, ps, r0, εcall⟩, hv, h⟩ := checking_lift_bind_ok h
  have fs := ihf [] _ _ _ _ _ _ _ _ _ (BuilderInvariant.empty _ _ _) hq he.1 (Env.atoms_hideConts hΓ)
    (fun t ht => by cases ht; exact he.2.2.1) hf
  rw [fnView_ok hv] at fs
  obtain ⟨uNames, hNames, h⟩ := checking_lift_bind_ok h
  obtain ⟨uCall, hCall, h⟩ := checking_lift_bind_ok h
  obtain ⟨uWF, hWF, h⟩ := checking_lift_bind_ok h
  have hnames : names = calleeNames := eq_of_beq (require_ok hNames).1
  rw [← hnames] at fs
  obtain ⟨εa, mid', ha, h⟩ := checking_bind_ok h
  have as_ := iha [] _ _ _ _ _ _ _ _ _ (BuilderInvariant.empty _ _ _) hq he.2.1 (Env.atoms_hideConts hΓ)
    (fun t ht => by cases ht; exact he.2.2.1) (sourceTypes_atoms fs.2.1.1) ha
  obtain ⟨u2, hr, h⟩ := checking_lift_bind_ok h
  obtain ⟨u3, heff, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  refine ⟨.E_PartialCall ((nonemptyList_spec _).mp (require_ok hholes).1) fs.1
    ((callOk_spec _ _ _ _ _).mp (require_ok hCall).1)
    ((namesWF_spec _ _).mp (require_ok hWF).1) as_.1
    (tyLe_sound fs.2.1.2.1 he.2.2.1 (require_ok hr).1) ?_
    ((singleTyCheck_spec (.fn (args.holeNames names) args.holeTypes r eff) ⟨holeTypes_atoms he.2.1, he.2.2.1, he.2.2.2⟩).mp hSingle.1),
    ⟨?_, he.2.2.1, he.2.2.2⟩, emptyEff_atoms _⟩
  · have hh := acceptEff_sound (union_atoms fs.2.2 (union_atoms as_.2 fs.2.1.2.2)) he.2.2.2 heff
    rwa [union_eq fs.2.2 (union_atoms as_.2 fs.2.1.2.2), union_eq as_.2 fs.2.1.2.2] at hh
  · exact holeTypes_atoms he.2.1

theorem partialCon_case {q c ts args} : CaseSound q (.expr (.partialCon c ts args)) := by
  intro ih
  have iha : HoleArgsSound q args := ih (.holes args) (by simp [CheckNode.size] <;> omega)
  intro Δ C Γ R p path s s' a ε hB hq he hΓ hR h
  have h := guardInferred_ok h
  simp only [Expr.AtomsIn] at he
  obtain ⟨cd, hd, h⟩ := checking_lift_bind_ok h
  obtain ⟨u1, hlen, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hholes, h⟩ := checking_lift_bind_ok h
  obtain ⟨uCtor, hCtor, h⟩ := checking_lift_bind_ok h
  obtain ⟨uRecord, hRecord, h⟩ := checking_lift_bind_ok h
  obtain ⟨uWF, hWF, h⟩ := checking_lift_bind_ok h
  obtain ⟨εa, mid, ha, h⟩ := checking_bind_ok h
  have as_ := iha [] _ _ _ _ _ _ _ _ _ (BuilderInvariant.empty _ _ _) hq he.2 (Env.atoms_hideConts hΓ)
    (fun t ht => by cases ht; exact he.1)
    (substParams_atoms (es := []) he.1 (by simp) (hq.declarations.2.1 c cd (lookup_ok hd))) ha
  obtain ⟨uClean, hClean, h⟩ := checking_lift_bind_ok h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have henorm := Eff.normWith_eq_norm q.atoms εa as_.2
  refine ⟨?_, ⟨holeTypes_atoms he.2, he.1,
    by rw [henorm]; exact Eff.norm_support _ as_.2⟩, emptyEff_atoms _⟩
  have hconstructed := HasTypeQ.E_PartialCon (Δ := Δ) (r := .data cd.data ts) (εargs := εa) (D := q.D) (B := q.B) (opPrim := q.opPrim)
    (C := C) (Γ := Γ) (R := R) (p := p)
    (Option.isNone_iff_eq_none.mp (require_ok hRecord).1) (lookup_ok hd) (by simpa using (require_ok hlen).1)
    ((nonemptyList_spec _).mp (require_ok hholes).1)
    ((constructorHolesOk_spec _ _).mp (require_ok hCtor).1)
    ((namesWF_spec _ _).mp (require_ok hWF).1)
    (by simpa only [substParams_eq ts [] cd.args (tysAtoms_iff.mp he.1) (by simp) (tysAtoms_iff.mp (hq.declarations.2.1 c cd (lookup_ok hd)))] using as_.1)
    (Or.inl rfl) (cleanFails_sound as_.2 (require_ok hClean).1)
  simpa only [henorm, emptyEff] using hconstructed

theorem pipe_apply_of_ok {q Δ C Γ R p path lhs rhs s s' a ε}
    (ihl : ExprSound q lhs) (ihr : ExprSound q rhs)
    (hB : BuilderInvariant q C Γ Δ) (hq : q.Sound) (he : (Expr.pipe lhs rhs).AtomsIn q.atoms)
    (hΓ : Env.AtomsIn q.atoms Γ) (hR : ReturnAtoms q.atoms R)
    (hSingle : singleEffCheck q.atoms q.noFailRows ε = true)
    (h : (do
      require (child path 1) "invalid pipe value" (pipeValue rhs)
      let (ft, εf) ← checkExprR q .strict Δ C Γ R .other (child path 1) rhs
      let (names, ps, r, εcall) ← fnView (child path 1) ft
      require (child path 1) "pipe value must have one parameter and one name"
        ((ps.length == 1) && (names.length == 1))
      let t ← lookup (child path 1) "pipe value has no parameter" ps.head?
      let εl ← accept q C.length (child path 0) t (← checkExprR q .strict Δ C Γ R .other (child path 0) lhs)
      pure (r, union q εl (union q εf εcall)) : Checking Inferred) s = .ok ((a, ε), s')) :
    HasTypeQ q.D q.B q.opPrim (NoFailCtxOf q.noFailRows) Δ C Γ R p (.pipe lhs rhs) a ε ∧
      a.AtomsIn q.atoms ∧ ε.AtomsIn q.atoms := by
  simp only [Expr.AtomsIn] at he
  obtain ⟨u1, hvalue, h⟩ := checking_lift_bind_ok h
  obtain ⟨⟨ft, εf⟩, mid, hf, h⟩ := checking_bind_ok h
  obtain ⟨⟨names, ps, r, εcall⟩, hv, h⟩ := checking_lift_bind_ok h
  obtain ⟨u2, hunary, h⟩ := checking_lift_bind_ok h
  obtain ⟨t, hhead, h⟩ := checking_lift_bind_ok h
  have fs := ihr Δ _ _ _ _ _ _ _ _ _ hB hq he.2 hΓ hR hf
  rw [fnView_ok hv] at fs
  have hc := unary_of_head (by simpa using (Bool.and_eq_true_iff.mp (require_ok hunary).1).1) hhead
  obtain ⟨name, hn⟩ : ∃ name, names = [name] := List.length_eq_one_iff.mp
    (by simpa using (Bool.and_eq_true_iff.mp (require_ok hunary).1).2)
  have hp := fs.2.1.1
  rw [hc] at hp
  obtain ⟨εl, mid', hl, hlAtoms, h, hlAtomsClean⟩ := checking_accept_expr_ok
    (fun _ _ _ _ h => ihl Δ _ _ _ _ _ _ _ _ _ hB hq he.1 hΓ hR h) hp.1 h
  obtain ⟨eq, _⟩ := checking_pure_ok h
  cases eq
  have hSafe := (singleEffCheck_spec _ (union_atoms hlAtoms (union_atoms fs.2.2 fs.2.1.2.2))).mp hSingle
  refine ⟨?_, fs.2.1.2.1, union_atoms hlAtoms (union_atoms fs.2.2 fs.2.1.2.2)⟩
  rw [union_eq hlAtoms (union_atoms fs.2.2 fs.2.1.2.2), union_eq fs.2.2 fs.2.1.2.2] at hSafe ⊢
  apply HasTypeQ.E_PipeApply ((pipeValue_spec _).mp (require_ok hvalue).1) hl
    (by rw [← hc, ← hn]; exact fs.1)
  exact hSafe

theorem pipe_case {q lhs rhs} : CaseSound q (.expr (.pipe lhs rhs)) := by
  cases rhs with
  | call => exact pipe_call_case
  | conCall => exact pipe_conCall_case
  | conValue => exact pipe_conValue_case
  | _ =>
      intro ih Δ C Γ R p path s s' a ε hB hq he hΓ hR h
      exact pipe_apply_of_ok (pipe_case_ih ih).1 (pipe_case_ih ih).2 hB hq he hΓ hR (guardInferred_result h).2.2 (guardInferred_ok h)

end Benitoite.Surface.Check
