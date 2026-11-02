import Benitoite.Release.Refinement.TypeSubstLocalSignature
import Benitoite.Release.Refinement.EffectFacts

/-! # 型置換の局所参照と効果（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement
set_option maxHeartbeats 2000000

@[simp] theorem BuilderKind.contents_substAt (b : BuilderKind) (c : Nat) (ts : List Ty) (es : List Eff) :
    (b.substAt c ts es).contents = b.contents.substAt c ts es := by
  cases b <;> rfl

@[simp] theorem BuilderOp.parameters_substAt (op : BuilderOp) (b : BuilderKind) (c : Nat) (ts : List Ty) (es : List Eff) :
    op.parameters (b.substAt c ts es) = (op.parameters b).map (Ty.substAt c ts es) := by
  cases op <;> cases b <;> rfl

@[simp] theorem BuilderOp.resultType_substAt (op : BuilderOp) (b : BuilderKind) (c : Nat) (ts : List Ty) (es : List Eff) :
    op.resultType (b.substAt c ts es) = (op.resultType b).substAt c ts es := by
  cases op <;> cases b <;> rfl

@[simp] theorem BuilderKind.substAt_norm_source (b : BuilderKind) (c : Nat) (ts : List Ty) (es : List Eff) :
    b.norm.substAt c ts es = b.substAt c ts es := by
  cases b <;> simp only [BuilderKind.norm,BuilderKind.substAt,Ty.substAt_norm_source]

theorem LocalRef.HasKind.typeSubst {Ψ L r b c ts es}
    (h : LocalRef.HasKind Ψ L r b) (hw : Ψ.WF)
    (hc : es = [] ∨ ∃ i, r = .bound i) :
    LocalRef.HasKind Ψ (L.map (Option.map (BuilderKind.substAt c ts es))) r
      (b.substAt c ts es) := by
  induction h with
  | bound hi => exact .bound (by simp only [List.getElem?_map,hi,Option.map_some])
  | @loc l b hi =>
    have he : es = [] := hc.resolve_right (by rintro ⟨i,h⟩; cases h)
    subst es
    have hb : b.substAt c ts [] = b.norm := by
      have hh := hw l _ hi
      cases b with
      | string => rfl
      | bytes => rfl
      | list a =>
        exact congrArg BuilderKind.list (Ty.substAt_nil_of_wf ts a
          (by simpa only [List.length_replicate,List.length_nil] using
            (hh.closed_context (C := List.replicate c TypeCtx.valueParam) (Γ := []))))
    rw [hb]
    exact (LocalRef.HasKind.loc hi).normal
  | normal h ih =>
    rw [BuilderKind.substAt_norm_source]
    exact ih hc

theorem Eff.mem_union_iff (e f : Eff) (a : Atom) :
    (e.union f).mem a ↔ e.mem a ∨ f.mem a := by
  unfold Eff.union
  rw [Eff.mem_norm]
  simp only [Eff.mem,Eff.test,Eff.atoms,Bool.or_eq_true]

theorem Eff.memFail_union_iff (e f : Eff) (t : Ty) :
    (e.union f).memFail t ↔ e.memFail t ∨ f.memFail t := by
  unfold Eff.union
  rw [Eff.norm_memFail]
  simp only [Eff.memFail,Eff.fails,List.mem_append,
    or_and_right,exists_or]

theorem Eff.bind_union (e f : Eff) (θ : SubstEnv) :
    Eff.bind θ (e.union f) = (Eff.bind θ e).union (Eff.bind θ f) := by
  have hr : Eff.bind θ (e.union f) =
      Eff.bind θ (.mk (fun a => e.test a || f.test a) (e.fails ++ f.fails)) :=
    Eff.norm_rawBind θ _
  have ha (a : Atom) : (Eff.bind θ (e.union f)).mem a ↔
      ((Eff.bind θ e).union (Eff.bind θ f)).mem a := by
    rw [hr,Eff.mem_union_iff]
    simp only [Eff.bind]
    simp only [Eff.mem_norm]
    simp only [Eff.mem_rawBind]
    simp only [Eff.mem,Eff.test,Eff.atoms,Bool.or_eq_true]
    grind
  have ht (t : Ty) : (Eff.bind θ (e.union f)).memFail t ↔
      ((Eff.bind θ e).union (Eff.bind θ f)).memFail t := by
    rw [hr,Eff.memFail_union_iff]
    simp only [Eff.bind]
    simp only [Eff.norm_memFail]
    simp only [Eff.memFail_rawBind]
    simp only [Eff.fails,List.mem_append,Eff.mem,Eff.test,Eff.atoms,Bool.or_eq_true]
    grind
  exact Eff.eq_of_sub_of_sub (Eff.norm_idem _) (Eff.norm_idem _)
    ⟨fun a => (ha a).mp,fun t => (ht t).mp⟩ ⟨fun a => (ha a).mpr,fun t => (ht t).mpr⟩

theorem handled_typeSubst (P : Program) (B : Builtins) (cs : List Clause)
    (c : Nat) (ts : List Ty) (es : List Eff) :
    handled P B (Clause.substTyAtList c ts es cs) = handled P B cs := by
  have hop : (Clause.substTyAtList c ts es cs).map Clause.op = cs.map Clause.op := by
    induction cs with
    | nil => rfl
    | cons cl cs ih => cases cl <;> simp [Clause.substTyAtList,Clause.op,ih]
  have hh : handles (Clause.substTyAtList c ts es cs) = handles cs := by
    funext o
    have hh := congrArg (fun xs => xs.any (fun o' => o' == o)) hop
    simpa only [handles,List.any_map,Function.comp_def] using hh
  unfold handled
  rw [hh]

theorem handled_substAt (P : Program) (B : Builtins) (cs : List Clause)
    (c : Nat) (ts : List Ty) (es : List Eff) :
    Eff.substAt c ts es (handled P B cs) = handled P B cs := by
  have hr : (handled P B cs).RowsIn (· < 0) := by
    constructor
    · intro i h; cases h
    · trivial
  have hraw := Eff.rawBind_rows_rowfree (handled P B cs) hr (typeEnvAt c ts [])
    (typeEnvAt c ts es).rows []
  change (Eff.rawBind (typeEnvAt c ts es) (handled P B cs)).norm = _
  have hh : Eff.rawBind (typeEnvAt c ts es) (handled P B cs) =
      Eff.rawBind (typeEnvAt c ts []) (handled P B cs) := hraw
  rw [hh]
  simp only [handled,Eff.rawBind,typeEnvAt,instAtoms_nil,substAtoms_nil,rowFails,
    List.map_nil,List.length_nil,List.range_zero,List.filter_nil,List.flatMap_nil,List.append_nil,
    rawBindTys,Eff.norm,Ty.normTys,Order.sortUnique_nil]

theorem Ty.Annotation.typeSubst_boolean {P B} {Ψ : StoreTy} {C0 C1 Γ p ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ (.refined (.base .boolean) p)) :
    Ty.Annotation P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) (.refined (.base .boolean) p) := by
  refine ⟨?_,⟨trivial,ha.sorted.2.typeSubst hi⟩,⟨trivial,ha.declared.2.typeSubst hf hi⟩⟩
  simpa only [Ty.WF,Ctx.bindTypes,List.length_map] using ha.wf

theorem Eff.substAt_union (e f : Eff) (c : Nat) (ts : List Ty) (es : List Eff) :
    Eff.substAt c ts es (e.union f) = (Eff.substAt c ts es e).union (Eff.substAt c ts es f) := Eff.bind_union e f (typeEnvAt c ts es)

end Benitoite.Release.Refinement
