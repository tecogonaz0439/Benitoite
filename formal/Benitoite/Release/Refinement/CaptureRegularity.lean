import Benitoite.Release.Refinement.Context.Capture
import Benitoite.Release.Refinement.StateTyping
import Benitoite.Release.Refinement.TypingDeclared
import Benitoite.Release.Refinement.MatchPaths
import Benitoite.Release.Refinement.HandlerFailure

/-!
# 開いた結果型の形成

捕捉元の継続では入力と結果だけを読む。Φ の真や実際の捕捉を、
開いたコードの帰納の前提にしない（設計書 01-12「閉じた述語の評価と捕捉」）。
-/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 結果形成の帰納で使う、捕捉元の三条件。 -/
def CaptureContextRegular (P : Program) (C : TypeCtx) (Γ : Ctx) : Prop :=
  Ctx.CaptureWF 0 C.length Γ ∧
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) →
    a.CaptureSorted Γ ∧ a.CaptureDeclared P C Γ

theorem CaptureContextRegular.extend {P C Γ a}
    (h : CaptureContextRegular P C Γ) (ha : Ty.Annotation P C Γ a) :
    CaptureContextRegular P C (Γ.extend a) := by
  have hm := ShiftMap.outerValue Γ (some (a.shiftV 1 0))
  constructor
  · intro i b hi
    cases i with
    | zero =>
      cases Option.some.inj hi
      simpa [Ctx.extend] using ha.wf.capture.shift 1 0
    | succ i =>
      rw [Ctx.lookup_extend] at hi
      obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
      cases x with
      | none => cases hb
      | some x => cases hb; simpa [Ctx.extend] using (h.1 i x hx).shift 1 0
  · intro i b hi
    cases i with
    | zero =>
      cases Option.some.inj hi
      exact ⟨(hm.annotation ha).sorted.capture, (hm.annotation ha).declared.capture⟩
    | succ i =>
      rw [Ctx.lookup_extend] at hi
      obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
      cases x with
      | none => cases hb
      | some x =>
        cases hb
        exact ⟨hm.captureSorted (h.2 i x hx).1, hm.captureDeclared (h.2 i x hx).2⟩

theorem CaptureContextRegular.extendNone {P C Γ} (h : CaptureContextRegular P C Γ) :
    CaptureContextRegular P C Γ.extendNone := by
  have hm := ShiftMap.outerValue Γ none
  constructor
  · intro i b hi
    cases i with
    | zero => cases hi
    | succ i =>
      rw [Ctx.lookup_extendNone] at hi
      obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
      cases x with
      | none => cases hb
      | some x => cases hb; simpa [Ctx.extendNone] using (h.1 i x hx).shift 1 0
  · intro i b hi
    cases i with
    | zero => cases hi
    | succ i =>
      rw [Ctx.lookup_extendNone] at hi
      obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
      cases x with
      | none => cases hb
      | some x =>
        cases hb
        exact ⟨hm.captureSorted (h.2 i x hx).1, hm.captureDeclared (h.2 i x hx).2⟩

theorem CaptureContextRegular.variable {P C Γ a} {i : Nat}
    (h : CaptureContextRegular P C Γ) (hi : Γ[i]? = some (some a)) (ho : Ordinary a) :
    Ty.Annotation P C Γ a := by
  refine ⟨(h.1 i a hi).ordinary ho, ?_, ?_⟩
  · have hs := (h.2 i a hi).1
    cases a <;> first | exact hs | exact False.elim (ho _ _ _ rfl)
  · have hd := (h.2 i a hi).2
    cases a <;> first | exact hd | exact False.elim (ho _ _ _ rfl)

theorem CaptureOk.contextRegular {P B Ψ R Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) :
    CaptureContextRegular P [] Γ := by
  cases h with | mk hw _ _ hs _ _ _ _ => exact ⟨hw, hs⟩

/-- let の後半の結果を、束縛の外の型へ戻す。 -/
theorem let_annotation {P C Γ a b} (hn : Ty.Annotation P C (Γ.extend a) (b.shiftV 1 0))
    (ha : Ty.Annotation P C Γ a) : Ty.Annotation P C Γ b :=
  ⟨Ty.wf_shiftV_rev (nv := Γ.length) (k := 1) (c := 0) (Nat.zero_le _)
      (by simpa [Ctx.extend] using hn.wf),
    Ty.sorted_shiftV_rev hn.sorted, hn.declared.shiftV_rev ha.declared⟩

private theorem none_typeMap (Γ : Ctx) :
    Ctx.TypeMap Γ.extendNone (Γ.extend (.base .unit)) := by
  constructor
  intro i b hi
  cases i with
  | zero => cases hi
  | succ i =>
    simp only [Ctx.extendNone, List.getElem?_cons_succ, List.getElem?_map] at hi
    exact ⟨b, by simpa only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] using hi,
      fun _ h => h, fun h => h, fun _ h => h⟩

/-- None の束縛の下から WF を戻す。 -/
theorem Ty.wf_shiftV_rev_extendNone {a : Ty} {nr nt : Nat} {Γ : Ctx}
    (h : (a.shiftV 1 0).WF nr nt Γ.extendNone.length) : a.WF nr nt Γ.length :=
  Ty.wf_shiftV_rev (Nat.zero_le _) (by simpa [Ctx.extendNone] using h)

/-- None の束縛の下から Sorted を戻す。 -/
theorem Ty.sorted_shiftV_rev_extendNone {a : Ty} {Γ : Ctx}
    (h : (a.shiftV 1 0).Sorted Γ.extendNone) : a.Sorted Γ :=
  Ty.sorted_shiftV_rev (h.context (none_typeMap Γ))

/-- None の束縛は宣言参照を追加せず、逆 shift ができる。 -/
theorem Ty.Declared.shiftV_rev_extendNone {P C Γ} {a : Ty}
    (h : (a.shiftV 1 0).Declared P C Γ.extendNone) : a.Declared P C Γ :=
by
  have hr : DeclarationRenaming Γ.extendNone (Γ.extend (.base .unit)) id := by
    constructor
    intro i b hi _
    cases i with
    | zero => cases hi
    | succ i =>
      simpa only [id_eq, renameTy_id, Ctx.extend, Ctx.extendNone,
        List.getElem?_cons_succ, List.getElem?_map] using hi
  exact (h.context hr.images).shiftV_rev (by trivial)

theorem builder_annotation {P C Γ a} (hn : Ty.Annotation P C Γ.extendNone (a.shiftV 1 0))
    (hd : a.Declared P C Γ) : Ty.Annotation P C Γ a :=
  ⟨Ty.wf_shiftV_rev_extendNone hn.wf, Ty.sorted_shiftV_rev_extendNone hn.sorted, hd⟩

theorem used_annotation {P Ψ l b t e R C Γ}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.cont b t e R)) : Ty.Annotation P C Γ t :=
  StoreTy.cont_result_annotation hw hs hd hl

theorem locref_annotation {P Ψ l a C Γ}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hl : Ψ l = some (.ref a)) : Ty.Annotation P C Γ (.reference a) := by
  have ha := StoreTy.reference_annotation (C := C) (Γ := Γ) hw hs hd hl
  exact ⟨ha.wf, ha.sorted, ha.declared⟩

theorem checked_annotation (P : Program) (C : TypeCtx) (Γ : Ctx)
    (o : OpaqueName) (k : Scope.Domain.Kind) (r : Scope.Domain.Range) :
    Ty.Annotation P C Γ (.scoped o k (.fixed (.absolute r))) :=
  ⟨by trivial, by trivial, by trivial⟩

private theorem arms_annotation {P B Ψ Q C Γ Φ R obs arms a b e L}
    (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L) : Ty.Annotation P C Γ b := by
  match h with
  | .nil ha => exact ha
  | .plain _ _ _ hs | .guarded _ _ _ _ _ hs => exact arms_annotation hs

mutual
  private theorem value_annotation {P B Ψ Q C Γ Φ v a}
      (h : HasTypeVQ P B Ψ Q C Γ Φ v a)
      (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
      (hΓ : CaptureContextRegular P C Γ) : Ty.Annotation P C Γ a := by
    match h with
    | .V_Var hi ho => exact hΓ.variable hi ho
    | .V_Const (c := c) _ => cases c <;> exact ⟨by trivial, by trivial, by trivial⟩
    | .V_Lam _ hw hs _ hd => exact ⟨hw, hs, hd⟩
    | .V_DependentLam ha _ | .V_Closure ha _ _ => exact ha
    | .V_Fun _ _ _ hi | .V_Prim _ _ _ _ hi | .V_Op _ _ _ hi |
        .V_ExternalRef _ _ _ hi => exact hi.result
    | .V_ExternalHandle _ _ _ _ _ _ ha | .V_Dict _ _ _ _ _ _ _ ha |
        .V_Con _ _ _ _ _ ha | .V_Raise ha _ _ _ => exact ha
    | .V_PathBases _ | .V_ScopePattern _ _ _ |
        .V_CheckedRequest _ _ _ _ _ _ | .V_CheckedAt _ | .V_Bytes _ =>
      exact ⟨by trivial, by trivial, by trivial⟩
    | .V_Checked (o := o) (k := k) (range := r) _ _ _ => exact checked_annotation P C Γ o k r
    | .V_AtError he =>
      rw [he.errorType_eq]
      exact ⟨by trivial, by trivial, by simpa only [he.errorType_eq] using he.errorType_declared (C := C) (Γ := Γ)⟩
    | .V_Map _ _ _ _ ha hb => exact ⟨⟨ha.wf, hb.wf⟩, ⟨ha.sorted, hb.sorted⟩, ⟨ha.declared, hb.declared⟩⟩
    | .V_Set _ _ ha => exact ⟨ha.wf, ha.sorted, ha.declared⟩
    | .V_List _ hwa hsa hda => exact ⟨hwa, hsa, hda⟩
    | .V_LocRef hl _ => exact locref_annotation hw hs hd hl
    | .V_LocLazy hl _ =>
      have ha := StoreTy.lazy_annotation (C := C) (Γ := Γ) hw hs hd hl
      exact ⟨ha.wf, ha.sorted, ha.declared⟩
    | .V_Super hv _ _ hda =>
      have ha := value_annotation hv hw hs hd hΓ
      exact ⟨ha.wf, ha.sorted, hda⟩
    | .V_Sub _ _ hwb hsb hdb => exact ⟨hwb, hsb, hdb⟩
    | .V_Normal hv => exact (value_annotation hv hw hs hd hΓ).norm
    | .V_Refine hv hsort _ hsp hwp _ hda hdp =>
      have ha := value_annotation hv hw hs hd hΓ
      exact ⟨⟨ha.wf, hwp, hsort.ordinary⟩, ⟨ha.sorted, hsp⟩, ⟨hda, hdp⟩⟩

  private theorem comp_annotation {P B Ψ Q C Γ Φ R m a e L}
      (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L)
      (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
      (hΓ : CaptureContextRegular P C Γ) : Ty.Annotation P C Γ a := by
    match h with
    | .C_BuilderLet _ _ hb hda =>
      exact builder_annotation (comp_annotation hb hw hs hd hΓ.extendNone) hda
    | .C_BuilderOp (kind := kind) (op := op) ha _ _ _ =>
      cases op <;> cases kind <;> first | exact ha | exact ⟨by trivial, by trivial, by trivial⟩
    | .C_Return hv => exact value_annotation hv hw hs hd hΓ
    | .C_Let hm hn _ =>
      have ha := comp_annotation hm hw hs hd hΓ
      exact let_annotation (comp_annotation hn hw hs hd (hΓ.extend ha)) ha
    | .C_App hv _ =>
      have ha := value_annotation hv hw hs hd hΓ
      exact ⟨ha.wf.2.2.1, ha.sorted.2.1, ha.declared.2.1⟩
    | .C_DependentApp _ ht | .C_External _ _ _ ht => exact ht.result_annotation
    | .C_If _ _ hm _ | .C_Use _ _ hm _ | .C_Handle hm _ _ |
        .C_Handle_Fail hm _ _ _ | .C_Eff hm _ => exact comp_annotation hm hw hs hd hΓ
    | .C_Match _ _ ha _ => exact arms_annotation ha
    | .C_Lazy _ ha => exact ⟨ha.wf, ha.sorted, ha.declared⟩
    | .C_Escape _ ha | .C_Meth _ _ _ _ _ _ _ _ _ ha => exact ha
    | .C_Resume hi _ hdt =>
      exact ⟨(hΓ.1 _ _ hi).2, (hΓ.2 _ _ hi).1.2, hdt⟩
    | .C_ResumeL hl _ _ => exact used_annotation hw hs hd hl
    | .C_ResumeNorm hi _ hdt =>
      exact ⟨Ty.wf_norm (hΓ.1 _ _ hi).2, Ty.sorted_norm (hΓ.2 _ _ hi).1.2, hdt⟩
    | .C_ResumeLNorm hl _ _ _ => exact (used_annotation hw hs hd hl).norm
    | .C_Normal hm => exact (comp_annotation hm hw hs hd hΓ).norm
    | .C_IssuePathBases _ _ _ _ _ _ _ _ => exact ⟨by trivial, by trivial, by trivial⟩
    | .C_CheckAt ha =>
      cases ha with
      | mk hshape _ _ _ _ _ hindex _ =>
        refine ⟨?_, ?_, ⟨⟨2, hshape.arity, rfl⟩, trivial, hshape.errorType_declared, trivial⟩⟩
        · rw [hshape.errorType_eq]; exact ⟨hindex, trivial, trivial⟩
        · rw [hshape.errorType_eq]; trivial
    | .C_Sub _ _ _ hwb hsb hdb => exact ⟨hwb, hsb, hdb⟩
end

/-- Φ を任意に保った、値の結果形成。 -/
theorem open_value_annotation {P : Program} {B : Builtins} {Ψ : StoreTy}
    {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {v : Val} {a : Ty}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hΓ : CaptureContextRegular P C Γ) (h : HasTypeVQ P B Ψ Q C Γ Φ v a) :
    Ty.Annotation P C Γ a := value_annotation h hw hs hd hΓ

/-- let・builder・分岐の子でも、実際の捕捉を要求しない。 -/
theorem open_comp_annotation {P : Program} {B : Builtins} {Ψ : StoreTy}
    {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred}
    {R : Option Ty} {m : Comp} {a : Ty} {e : Eff} {L : LocalCtx}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hΓ : CaptureContextRegular P C Γ) (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) :
    Ty.Annotation P C Γ a := comp_annotation h hw hs hd hΓ

theorem open_values_annotation {P B Ψ Q C Γ Φ vs as}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hΓ : CaptureContextRegular P C Γ) (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) :
    TypeAnnotations P C Γ as := by
  match h with
  | .nil => intro a ha; cases ha
  | .cons hv hvs =>
    intro a ha
    rcases List.mem_cons.mp ha with rfl | ha
    · exact open_value_annotation hw hs hd hΓ hv
    · exact open_values_annotation hw hs hd hΓ hvs _ ha

theorem open_each_annotation {P B Ψ Q C Γ Φ vs a}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hΓ : CaptureContextRegular P C Γ) (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a)
    (hne : vs ≠ []) : Ty.Annotation P C Γ a := by
  cases h with
  | nil => exact False.elim (hne rfl)
  | cons hv _ => exact open_value_annotation hw hs hd hΓ hv

theorem open_arms_annotation {P B Ψ Q C Γ Φ R obs arms a b e L}
    (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L) : Ty.Annotation P C Γ b :=
  arms_annotation h

theorem open_telArgs_annotation {P B Ψ Q C Γ Φ vs t a e}
    (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e) :
    Ty.Annotation P C Γ (.dependentFn (.done a e)) := by
  match h with
  | .done ha => exact ha
  | .param _ _ hs => exact open_telArgs_annotation hs

theorem capture_value_annotation {P B Ψ R Γ Φ cap v a}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hv : HasTypeVQ P B Ψ Qempty [] Γ Φ v a) :
    Ty.Annotation P [] [] (cap.closeTy a) :=
  hc.substOk.annotation (open_value_annotation hw hs hd hc.contextRegular hv)

theorem capture_comp_annotation {P B Ψ R Γ Φ cap Rs m a e L}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hm : HasTypeCQ P B Ψ Qempty [] Γ Φ Rs m a e L) :
    Ty.Annotation P [] [] (cap.closeTy a) :=
  hc.substOk.annotation (open_comp_annotation hw hs hd hc.contextRegular hm)

private theorem done_union_annotation {P C Γ a} {e f : Eff}
    (he : Ty.Annotation P C Γ (.dependentFn (.done a e)))
    (hf : Ty.Annotation P C Γ (.dependentFn (.done a f))) :
    Ty.Annotation P C Γ (.dependentFn (.done a (Eff.union e f))) := by
  cases e with
  | mk ep es => cases f with
    | mk fp fs =>
      have hw : Eff.WF 0 C.length Γ.length (.mk (fun x => ep x || fp x) (es ++ fs)) := by
        apply wfList_mem.mpr
        intro x hx
        rcases List.mem_append.mp hx with hx | hx
        · exact wfList_mem.mp he.wf.2.1 x hx
        · exact wfList_mem.mp hf.wf.2.1 x hx
      have hs : sortedEff Γ (.mk (fun x => ep x || fp x) (es ++ fs)) := by
        apply sortedTys_mem.mpr
        intro x hx
        rcases List.mem_append.mp hx with hx | hx
        · exact sortedTys_mem.mp he.sorted.2 x hx
        · exact sortedTys_mem.mp hf.sorted.2 x hx
      have hd : declaredEff P C Γ (.mk (fun x => ep x || fp x) (es ++ fs)) := by
        apply declaredTys_mem.mpr
        intro x hx
        rcases List.mem_append.mp hx with hx | hx
        · exact declaredTys_mem.mp he.declared.2 x hx
        · exact declaredTys_mem.mp hf.declared.2 x hx
      exact ⟨⟨he.wf.1, Eff.wf_norm hw, Eff.norm_idem _⟩,
        ⟨he.sorted.1, sortedEff_norm hs⟩, ⟨he.declared.1, declaredEff_norm hd⟩⟩

private theorem noFail_done_annotation {P C Γ Q a e}
    (ha : Ty.Annotation P C Γ a) (hn : NoFail Q e) :
    Ty.Annotation P C Γ (.dependentFn (.done a e)) := by
  cases e with
  | mk ats fs =>
    have hf : fs = [] := hn.1
    subst fs
    exact ⟨⟨ha.wf, trivial, rfl⟩, ⟨ha.sorted, trivial⟩, ⟨ha.declared, trivial⟩⟩

private theorem fail_done_annotation {P C Γ a E}
    (ha : Ty.Annotation P C Γ a) (hE : Ty.Annotation P C Γ E) :
    Ty.Annotation P C Γ (.dependentFn (.done a (Eff.singleFail E))) := by
  have hE := hE.norm
  refine ⟨⟨ha.wf, ⟨hE.wf, trivial⟩, ?_⟩,
    ⟨ha.sorted, hE.sorted, trivial⟩, ⟨ha.declared, hE.declared, trivial⟩⟩
  simp [Eff.Canonical, Eff.singleFail, Eff.norm, Ty.normTys, Ty.norm_idem]

/-- 原子の差は形成を妨げない。閉じた正規行の Fail は形成済み上限から取る。 -/
private theorem done_annotation_of_fail_sub {P a} {outer inner : Eff}
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a outer)))
    (hsub : ∀ x, inner.memFail x → outer.memFail x) (hn : inner.Canonical) :
    Ty.Annotation P [] [] (.dependentFn (.done a inner)) := by
  have hu := done_annotation_with_atoms ha inner.atoms
  exact done_annotation_of_covers hu ⟨fun x hx => ⟨x, hx, Atom.Covers.refl x⟩, hsub⟩ hn

/-- handler の生の行が不適格でも、捕捉で閉じた正規行には上限の形成が移る。 -/
theorem capture_handle_body_annotation {P B t eb ec h} {cap : Capture}
    (ha : Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff ec))))
    (hb : Eff.Sub eb (Eff.union ec (handled P B h))) :
    Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff eb))) := by
  have hb' : Eff.Sub (cap.closeEff eb) (Eff.union (cap.closeEff ec) (handled P B h)) := by
    simpa only [Capture.closeEff, ← substEffValues_eq_bind, substEffValues_union, handled_subst_values]
      using hb.bind (valEnv cap.env)
  apply done_annotation_of_fail_sub ha (fun x hx => ?_)
    (Eff.norm_idem _)
  have hh := (Eff.norm_memFail _ _).mp (hb'.2 x hx)
  obtain ⟨y, hy, he⟩ := hh
  rcases List.mem_append.mp hy with hy | hy
  · exact ⟨y, hy, he⟩
  · cases hy

/-- NoFail の rest は Fail の型を持たない。E と結果の注釈だけで上限を形成できる。 -/
theorem failure_effect_upper_annotation {P C Γ Q t E rest}
    (ha : Ty.Annotation P C Γ t) (hE : Ty.Annotation P C Γ E) (hn : NoFail Q rest) :
    Ty.Annotation P C Γ (.dependentFn (.done t (Eff.union (Eff.singleFail E) rest))) :=
  done_union_annotation (fail_done_annotation ha hE) (noFail_done_annotation ha hn)

/-- Fail の本体の形成は、failure.one の既存注釈と NoFail から得る。 -/
theorem capture_failure_body_annotation {P B Ψ cap Γ Φ R Rs t E eb rest ec h L}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hf : HasFailureClause P B Ψ Qempty [] Γ Φ E Rs h t ec L)
    (hn : NoFail Qempty rest) (hb : Eff.Sub eb (Eff.union (Eff.singleFail E) rest)) :
    Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff eb))) := by
  cases hf with
  | one hE ht _ _ =>
    have hu := hc.substOk.telAnnotation (failure_effect_upper_annotation ht hE hn)
    have hs := hb.bind (valEnv cap.env)
    exact done_annotation_of_covers hu hs.covers (Eff.norm_idem _)

/-- 捕捉先が空のため contVar はなく、contLoc の実際の場所が三条件を供給する。 -/
theorem CaptureOk.continuation_annotation {P B Ψ R Γ Φ cap} {i : Nat} {b t e}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hw : Ψ.WF) (hs : Ψ.Sorted)
    (hd : StoreTy.Declared P Ψ) (hi : Γ[i]? = some (some (.cont b t e))) :
    Ty.Annotation P [] [] (cap.closeTy (.cont b t e)) := by
  have himg := hc.substOk i _ hi
  cases himg with
  | ordinary ho _ => exact False.elim (ho b t e rfl)
  | hidden _ hn => exact False.elim (hn b t e rfl)
  | contVar _ _ hj => obtain ⟨_, _, _, hj, _⟩ := hj; cases hj
  | contLoc _ he _ _ hl _ =>
    change Ty.Annotation P [] [] (substTyValues cap.env (.cont b t e))
    rw [he]
    exact StoreTy.cont_type_annotation hw hs hd hl

theorem CaptureOk.continuation_result_effect {P B Ψ R Γ Φ cap} {i : Nat} {b t e}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hw : Ψ.WF) (hs : Ψ.Sorted)
    (hd : StoreTy.Declared P Ψ) (hi : Γ[i]? = some (some (.cont b t e))) :
    Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff e))) := by
  have ha := hc.continuation_annotation hw hs hd hi
  change Ty.Annotation P [] [] (.cont (cap.closeTy b) (cap.closeTy t) (cap.closeEff e)) at ha
  exact ⟨⟨ha.wf.2.1, ha.wf.2.2⟩, ha.sorted.2, ha.declared.2⟩

/-- let の前半と、後半を保持する一束縛の閉包に、元の全体効果を供給する。 -/
theorem capture_let_effect_annotations {P B Ψ R Rs Γ Φ cap m a b e L}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hm : HasTypeCQ P B Ψ Qempty [] Γ Φ Rs m a e L)
    (ha : Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy b) (cap.closeEff e)))) :
    Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy a) (cap.closeEff e))) ∧
    Ty.Annotation P [] (bindParams [] [cap.closeTy a])
      (.dependentFn (.done (cap.closeTyAt 1 (b.shiftV 1 0)) (cap.closeEffAt 1 (e.shiftV 1 0)))) := by
  have hm := capture_comp_annotation hw hs hd hc hm
  constructor
  · exact ⟨⟨hm.wf, ha.wf.2⟩, ⟨hm.sorted, ha.sorted.2⟩, ⟨hm.declared, ha.declared.2⟩⟩
  · have hh := (ShiftMap.outerValue [] (some ((cap.closeTy a).shiftV 1 0))).annotation ha
    simpa only [Capture.closeTyAt, Capture.closeEffAt, Capture.closeTy, Capture.closeEff,
      Ty.bind_shiftV_values, Eff.bind_shiftV_values, Ty.shiftV, Tel.shiftV,
      bindParams, List.reverse_cons, List.reverse_nil, List.nil_append, List.map_cons,
      List.map_nil, List.append_nil, List.length_cons, List.length_nil] using hh

theorem capture_tel_annotation {P B Ψ R Γ Φ cap t}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (ha : Ty.Annotation P [] Γ (.dependentFn t)) :
    Ty.Annotation P [] [] (.dependentFn (cap.closeTel t)) :=
  hc.substOk.telAnnotation ha

theorem capture_function_result_effect {P B Ψ R Γ Φ cap ns ps r e}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (ha : Ty.Annotation P [] Γ (.fn ns ps r e)) :
    Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy r) (cap.closeEff e))) := by
  have hh := hc.substOk.annotation ha
  exact ⟨⟨hh.wf.2.2.1, hh.wf.2.2.2⟩, hh.sorted.2, hh.declared.2⟩

/-- 保存する継続の潜在効果は、失敗節の既存の行注釈から供給する。 -/
theorem HasFailureClause.capture_result_effect {P B Ψ cap Γ Φ R Rs E t ec h L}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hf : HasFailureClause P B Ψ Qempty [] Γ Φ E Rs h t ec L) :
    Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff ec))) := by
  cases hf with
  | one _ ht he _ =>
    have hrow := he ec List.mem_cons_self
    exact hc.substOk.telAnnotation (t := .done _ _)
      ⟨⟨ht.wf, hrow.wf.2.2.2⟩, ⟨ht.sorted, hrow.sorted.2.2⟩,
        ⟨ht.declared, hrow.declared.2.2⟩⟩

private theorem cover_close {Γ Φ outer inner} (cap : Capture) (h : Eff.Covers Γ Φ outer inner) :
    Eff.Covers [] [] (cap.closeEff outer) (cap.closeEff inner) := h.bind (valEnv cap.env)

/-- 外側の注釈・被覆・内側の結果の注釈から、内側の閉じた done の注釈を得る。 -/
theorem done_inner {P cap Γ Φ a b outer inner}
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a (Capture.closeEff cap outer))))
    (hb : Ty.Annotation P [] [] b) (hc : Eff.Covers Γ Φ outer inner) :
    Ty.Annotation P [] [] (.dependentFn (.done b (Capture.closeEff cap inner))) := by
  have h1 : Ty.Annotation P [] [] (.dependentFn (.done b (Capture.closeEff cap outer))) :=
    ⟨⟨hb.wf, ha.wf.2⟩, ⟨hb.sorted, ha.sorted.2⟩, ⟨hb.declared, ha.declared.2⟩⟩
  exact done_annotation_of_covers h1 (cover_close cap hc) (Eff.norm_idem _)

/-- C_Sub/C_Eff/C_Normal を通す .handle の逆転。 -/
theorem handle_inv {P B Ψ Q C Γ Φ Rs code m h a e L}
    (hm : HasTypeCQ P B Ψ Q C Γ Φ Rs code a e L) (hcode : code = .handle m h) :
    (∃ t εm ε, HasTypeCQ P B Ψ Q C Γ Φ Rs m t εm L ∧
      Eff.Sub εm (Eff.union ε (handled P B h)) ∧
      HasTypeClausesQ P B Ψ Q C Γ Φ Rs εm h t ε L ∧
      Eff.Covers Γ Φ e ε ∧ Ty.LeQ P Γ Φ t a) ∨
    (∃ t E eb rest ec, HasTypeCQ P B Ψ Q C Γ Φ Rs m t eb L ∧
      Eff.Sub eb (Eff.union (Eff.singleFail E) rest) ∧ NoFail Q rest ∧
      HasFailureClause P B Ψ Q C Γ Φ E Rs h t ec L ∧
      Eff.Covers Γ Φ e (Eff.union rest ec) ∧ Ty.LeQ P Γ Φ t a) := by
  match hm with
  | .C_Handle hb hsub hcl =>
    cases hcode
    exact .inl ⟨_, _, _, hb, hsub, hcl, Eff.Covers.refl _ _ _, .refl⟩
  | .C_Handle_Fail hb hsub hn hf =>
    cases hcode
    exact .inr ⟨_, _, _, _, _, hb, hsub, hn, hf, Eff.Covers.refl _ _ _, .refl⟩
  | .C_Normal hh =>
    rcases handle_inv hh hcode with ⟨t, εm, ε, h1, h2, h3, h4, h5⟩ | ⟨t, E, eb, rest, ec, h1, h2, h3, h4, h5, h6⟩
    · exact .inl ⟨t, εm, ε, h1, h2, h3, h4, .trans h5 (.convert (Ty.norm_idem _).symm)⟩
    · exact .inr ⟨t, E, eb, rest, ec, h1, h2, h3, h4, h5, .trans h6 (.convert (Ty.norm_idem _).symm)⟩
  | .C_Sub hh hle hcov _ _ _ =>
    rcases handle_inv hh hcode with ⟨t, εm, ε, h1, h2, h3, h4, h5⟩ | ⟨t, E, eb, rest, ec, h1, h2, h3, h4, h5, h6⟩
    · exact .inl ⟨t, εm, ε, h1, h2, h3, hcov.trans h4, .trans h5 hle⟩
    · exact .inr ⟨t, E, eb, rest, ec, h1, h2, h3, h4, hcov.trans h5, .trans h6 hle⟩
  | .C_Eff hh hcov =>
    rcases handle_inv hh hcode with ⟨t, εm, ε, h1, h2, h3, h4, h5⟩ | ⟨t, E, eb, rest, ec, h1, h2, h3, h4, h5, h6⟩
    · exact .inl ⟨t, εm, ε, h1, h2, h3, hcov.trans h4, h5⟩
    · exact .inr ⟨t, E, eb, rest, ec, h1, h2, h3, h4, hcov.trans h5, h6⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hcode
termination_by structural hm

/-- 実際の E_Handle の前の状態: run q k μ を型付けし q.view = .handle のとき、
ClosureTy の全体効果の注釈だけから、本体の結果と行の閉じた注釈と節の行の注釈を得る。 -/
theorem e_handle_supply {P B Ψ R q m h a e1}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e1) (hv : q.view = .handle m h) :
    ∃ cap Γ Φ Rs m0 h0 L ρ, q = .mk cap (Comp.handle m0 h0 |>.resolveLocals ρ) ∧
      CaptureOk P B Ψ R Γ Φ cap ∧ CaptureLocals Ψ cap.env L ρ ∧
      ((∃ t εm ε, HasTypeCQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs m0 t εm L ∧
          Eff.Sub εm (Eff.union ε (handled P B h0)) ∧
          HasTypeClausesQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs εm h0 t ε L ∧
          Eff.Covers [] [] e1 (cap.closeEff ε) ∧
          Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff ε))) ∧
          Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff εm)))) ∨
       (∃ t E eb rest ec, HasTypeCQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs m0 t eb L ∧
          Eff.Sub eb (Eff.union (Eff.singleFail E) rest) ∧ NoFail Benitoite.Release.Qempty rest ∧
          HasFailureClause P B Ψ Benitoite.Release.Qempty [] Γ Φ E Rs h0 t ec L ∧
          Eff.Covers [] [] e1 (cap.closeEff (Eff.union rest ec)) ∧
          Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff ec))) ∧
          Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy t) (cap.closeEff eb))))) := by
  have hann := hq.annotation
  simp only [bindParams, List.reverse_nil, List.map_nil, List.nil_append] at hann
  obtain ⟨cap, Γ, Φ, Rs, code0, as, es, L, ρ, rfl, hc, hb, hL, hR, rfl, rfl, hrs⟩ := hq.open_zero
  have hform : ∃ m0 h0, code0 = .handle m0 h0 := by
    cases code0
    case handle => exact ⟨_, _, rfl⟩
    case checkAt _ _ _ bs _ _ _ =>
      exfalso; cases bs <;> (simp only [Comp.resolveLocals] at hv; injection hv)
    all_goals (exfalso; simp only [Comp.resolveLocals] at hv; injection hv)
  obtain ⟨m0, h0, rfl⟩ := hform
  refine ⟨cap, Γ, Φ, Rs, m0, h0, L, ρ, rfl, hc, hL, ?_⟩
  rcases handle_inv hb rfl with ⟨t, εm, ε, h1, h2, h3, h4, _⟩ | ⟨t, E, eb, rest, ec, h1, h2, h3, h4, h5, _⟩
  · have ha := capture_comp_annotation hw hs hd hc h1
    have hε := done_inner hann ha h4
    exact .inl ⟨t, εm, ε, h1, h2, h3, cover_close cap h4, hε, capture_handle_body_annotation hε h2⟩
  · have hec := h4.capture_result_effect hc
    exact .inr ⟨t, E, eb, rest, ec, h1, h2, h3, h4, cover_close cap h5, hec,
      capture_failure_body_annotation hc h4 h3 h2⟩


private theorem let_inv {P B Ψ Q C Γ Φ Rs code m n a e L}
    (hm : HasTypeCQ P B Ψ Q C Γ Φ Rs code a e L) (hcode : code = .letIn m n) :
    ∃ a0 b ε, HasTypeCQ P B Ψ Q C Γ Φ Rs m a0 ε L ∧
      HasTypeCQ P B Ψ Q C (Γ.extend a0) (Φ.map Pred.lift) (Rs.map (Ty.shiftV 1 0))
        n (b.shiftV 1 0) (Eff.shiftV 1 0 ε) (localExtend 1 L) ∧
      Ty.Declared P C Γ b ∧ HasTypeCQ P B Ψ Q C Γ Φ Rs (.letIn m n) b ε L ∧
      Eff.Covers Γ Φ e ε ∧ Ty.LeQ P Γ Φ b a := by
  match hm with
  | hh@(.C_Let h1 h2 h3) =>
    cases hcode
    exact ⟨_, _, _, h1, h2, h3, hh, Eff.Covers.refl _ _ _, .refl⟩
  | .C_Normal hh =>
    obtain ⟨a0, b, ε, h1, h2, h3, h4, h5, h6⟩ := let_inv hh hcode
    exact ⟨a0, b, ε, h1, h2, h3, h4, h5, .trans h6 (.convert (Ty.norm_idem _).symm)⟩
  | .C_Sub hh hle hcov _ _ _ =>
    obtain ⟨a0, b, ε, h1, h2, h3, h4, h5, h6⟩ := let_inv hh hcode
    exact ⟨a0, b, ε, h1, h2, h3, h4, hcov.trans h5, .trans h6 hle⟩
  | .C_Eff hh hcov =>
    obtain ⟨a0, b, ε, h1, h2, h3, h4, h5, h6⟩ := let_inv hh hcode
    exact ⟨a0, b, ε, h1, h2, h3, h4, hcov.trans h5, h6⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. |
    .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hcode
termination_by structural hm

theorem ContTy.return_wf {P B σ Ψ R ε k a b Eb Re} (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (hRe : Re = none) : ∀ r, R = some r → r.WF 0 0 0 := by
  induction h with
  | K_Empty => subst hRe; intro r hr; cases hr
  | K_Mark _ ha _ => intro r hr; cases hr; exact ha.wf
  | K_Update | K_Guard => intro r hr; cases hr
  | K_Let _ _ _ _ _ ih | K_Release _ _ _ _ _ ih | K_Drop _ _ _ ih | K_Sub _ _ ih => exact ih hRe
  | K_Handle _ _ _ _ _ _ _ _ _ _ _ _ _ ih => exact ih hRe
  | K_Handle_Fail _ _ _ _ _ _ _ _ _ _ _ _ _ ih => exact ih hRe

/-- 実際の E_Let の一歩。前半は広げた全体効果で、後半は一束縛の閉包で型付ける。 -/
theorem e_let_post {P B σ Ψ R q m n a e1 e k b Eb}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e1) (hsub : Eff.Sub e1 e)
    (hk : ContTy P B σ Ψ R e k a b Eb none)
    (hv : q.view = .letIn m n) (had : (Closure.mk q.capture n).Adequate σ) :
    ∃ a' e1', ClosureTy P B Ψ [] R (.mk q.capture m) a' e1' ∧ Eff.Sub e1' e ∧
      ContTy P B σ Ψ R e (.letF (.mk q.capture n) :: k) a' b Eb none := by
  have hann := hq.annotation
  simp only [bindParams, List.reverse_nil, List.map_nil, List.nil_append] at hann
  obtain ⟨cap, Γ, Φ, Rs, code0, as, es, L, ρ, rfl, hc, hb, hL, hR, rfl, rfl, hrs⟩ := hq.open_zero
  have hform : ∃ m0 n0, code0 = .letIn m0 n0 := by
    cases code0
    case letIn => exact ⟨_, _, rfl⟩
    case checkAt _ _ _ bs _ _ _ =>
      exfalso; cases bs <;> (simp only [Comp.resolveLocals] at hv; injection hv)
    all_goals (exfalso; simp only [Comp.resolveLocals] at hv; injection hv)
  obtain ⟨m0, n0, rfl⟩ := hform
  simp only [Comp.resolveLocals] at hv
  injection hv with hv1 hv2
  subst hv1; subst hv2
  obtain ⟨a0, c, ε, h1, h2, hdc, hlet, hcov, hle⟩ := let_inv hb rfl
  have hle' : Ty.LeQ P [] [] (cap.closeTy c) (cap.closeTy as) := hle.bind (valEnv cap.env) hc.transport
  have hcc := capture_comp_annotation hw hs hd hc hlet
  have hup : Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy c) (cap.closeEff es))) :=
    ⟨⟨hcc.wf, hann.wf.2⟩, ⟨hcc.sorted, hann.sorted.2⟩, ⟨hcc.declared, hann.declared.2⟩⟩
  -- 前半を全体効果へ広げる
  have h1' : HasTypeCQ P B Ψ Benitoite.Release.Qempty [] Γ Φ Rs m0 a0 es L := .C_Eff h1 hcov
  have h2' := HasTypeCQ.C_Eff h2 (hcov.shiftV 1 0 (Δ := Γ.extend a0) (Ψ := Φ.map Pred.lift))
  obtain ⟨hfront, hback⟩ := capture_let_effect_annotations hw hs hd hc h1' hup
  have hq1 := ClosureTy.capture_resolved_closed hc h1' hL hfront hR hrs
  have hopen := open_comp_annotation hw hs hd hc.contextRegular h1
  have hclosea := capture_comp_annotation hw hs hd hc h1
  have hRw := hk.return_wf rfl
  have hRid : R.map (Ty.shiftV 1 0) = R := by
    cases R with
    | none => rfl
    | some r => simp only [Option.map_some]; rw [Ty.shiftV_of_wf_zero (hRw r rfl)]
  have hrc : cap.closeRAt 1 (Rs.map (Ty.shiftV 1 0)) = R := by
    rw [←hRid]
    subst hR
    cases Rs with
    | none => rfl
    | some r0 =>
      simp only [Capture.closeRAt, Capture.closeR, Option.map_some, Capture.closeTyAt, Capture.closeTy]
      congr 1
      exact Ty.bind_shiftV_values r0 1 cap.env
  have hbody := ClosureTy.mk (ss := [a0]) (Rs := Rs.map (Ty.shiftV 1 0)) (a := c.shiftV 1 0)
    (e := Eff.shiftV 1 0 es) (L := localExtend 1 L) hc
    (by simpa only [bindParams_single, List.length_cons, List.length_nil, Nat.zero_add, liftMany_one] using h2')
    (by simpa only [List.length_cons, List.length_nil, Nat.zero_add] using hL.localExtend hw) rfl
    (by intro t ht; cases List.mem_singleton.mp ht; exact hopen)
    (by intro t ht; cases List.mem_singleton.mp (by simpa using ht); exact hclosea)
    hrc
    (by simpa only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add] using
      (show Ty.Annotation P [] (bindParams [] [cap.closeTy a0]) (cap.closeTyAt 1 (c.shiftV 1 0)) from
        ⟨hback.wf.1, hback.sorted.1, hback.declared.1⟩))
    (by simpa only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add] using hback)
    (by
      intro r hr
      obtain ⟨r0, h0, rfl⟩ := Option.map_eq_some_iff.mp hr
      exact (ShiftMap.outerValue Γ (some (a0.shiftV 1 0))).declared (hrs r0 h0))
    (by
      intro r hr
      have hd0 : r.Declared P [] [] := by
        cases hx : Rs with
        | none => simp [Capture.closeR, hx] at hR; rw [←hR] at hr; cases hr
        | some rs =>
          have he : cap.closeTy rs = r := by simpa [Capture.closeR, hx, hr] using hR
          rw [←he]; exact (hrs rs hx).bind_values hc.substOk.declaration
      have := (ShiftMap.outerValue [] (some ((cap.closeTy a0).shiftV 1 0))).declared hd0
      rw [Ty.shiftV_of_wf_zero (hRw r hr)] at this
      simpa [Ctx.extend, bindParams] using this)
  have h3 := Ty.bind_shiftV_values c 1 cap.env
  have h4 := Eff.bind_shiftV_values es 1 cap.env
  have hbody' := hbody
  simp only [List.map_cons, List.map_nil, List.length_cons, List.length_nil, Nat.zero_add,
    Capture.closeTyAt, Capture.closeEffAt, h3, h4] at hbody'
  conv at hbody' => arg 5; rw [←hRid]
  exact ⟨_, _, hq1, hsub, ContTy.K_Let hbody' had ⟨hclosea.wf, hclosea.sorted, hclosea.declared⟩ hsub (.K_Sub hk hle')⟩
theorem split_fail_annotated {P B σ Ψ R ε k a b Eb Re cap E0 body k1 k2}
    (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (he : k = k1 ++ .handleF cap [.fail E0 body] :: k2) :
    ∃ t ec et Rh, ContTy P B σ Ψ R ε (k1 ++ [.handleF cap [.fail E0 body]]) a t (.mk et.atoms ec.fails) Rh ∧
      ContTy P B σ Ψ Rh et k2 t b Eb Re ∧ Eff.Covers [] [] et ec ∧ Eff.Sub (.mk et.atoms ec.fails) et ∧
        Ty.Annotation P [] [] (.dependentFn (.done t ec)) := by
  induction h generalizing k1 with
  | K_Empty _ _ => cases k1 <;> simp at he
  | K_Sub _ hl ih =>
    obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
    exact ⟨t,ec,et,Rh,.K_Sub h1 hl,h2,h3,h4,h5⟩
  | K_Let hq had ha hs _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Let hq had ha hs h1,h2,h3,h4,h5⟩
  | K_Mark _ ha ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Mark h1 ha,h2,h3,h4,h5⟩
  | K_Update hl ha _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Update hl ha h1,h2,h3,h4,h5⟩
  | K_Release hv had hr hs _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Release hv had hr hs h1,h2,h3,h4,h5⟩
  | K_Drop hl hs _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Drop hl hs h1,h2,h3,h4,h5⟩
  | K_Guard hc hv ho hs hL har hr hx heq hR ht hef hb hsub hp _ had ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Guard hc hv ho hs hL har hr hx heq hR ht hef hb hsub hp h1 had,h2,h3,h4,h5⟩
  | K_Handle ht hc hb hcap hcs hR hty hec heb ha has hr had ih =>
    cases k1 with
    | nil => cases he; cases hcs
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Handle h1 hc hb hcap hcs hR hty hec heb ha has hr had,h2,h3,h4,h5⟩
  | @K_Handle_Fail R0 ε0 ec0 rest E cap0 cs0 tail t0 b0 E0' Re0 Γ Φ Rs ts ecs Es
      ht hc hnf hcap hcs hR hty hec hE hr hcov ha had ih =>
    cases k1 with
    | nil =>
      cases he
      have hsub : Eff.Sub (.mk ε0.atoms ec0.fails) (.mk ε0.atoms ec0.fails) := ⟨fun _ h => h,fun _ h => h⟩
      have hcsa := hcs
      refine ⟨_,ec0,ε0,_,?_,ht,hcov,hcov.widen_atoms.2,?_⟩
      refine .K_Handle_Fail (ε := .mk ε0.atoms ec0.fails) (rest := rest) (ec := ec0) (.K_Empty hsub ha) ?_ hnf hcap hcs hR hty hec hE hr ?_ ha had
      · exact ⟨fun a ha => hc.1 a ha,fun t ht => by obtain ⟨_,hx,_⟩ := ht; rw [hnf.1] at hx; cases hx⟩
      · exact ⟨fun a ha => hcov.1 a ha,fun _ h => h⟩
      · rw [←hty,←hec]; exact hcsa.capture_result_effect hcap
    | cons f k1 =>
      simp only [List.cons_append, List.cons.injEq] at he
      obtain ⟨rfl,he⟩ := he
      obtain ⟨t,ec,et,Rh,h1,h2,h3,h4,h5⟩ := ih he
      exact ⟨t,ec,et,Rh,.K_Handle_Fail h1 hc hnf hcap hcs hR hty hec hE hr hcov ha had,h2,h3,h4,h5⟩


end
end Benitoite.Release.Refinement
