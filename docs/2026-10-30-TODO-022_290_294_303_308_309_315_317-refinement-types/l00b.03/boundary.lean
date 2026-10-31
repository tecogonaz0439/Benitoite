import Lean
import Benitoite.Release.Refinement.Context.Capture
import Benitoite.Release.Refinement.Semantics
import Benitoite.Shared.Approximation

namespace Benitoite.Release.Refinement.ContextBoundary
noncomputable section

def scalar : Ty := .base .integer8
def seven : Val := .const (.integer8 7)
def equalSeven : Ty := .refined scalar (.eq (.var 0) (.integer 7))
def same (i : Nat) : Ty := .refined scalar (.eq (.var 0) (.var (i+1)))
def initial : Ctx := Ctx.extend [] equalSeven
def cap0 : Capture := Capture.empty.extend seven
def pathFact : Pred := .eq (.var 0) (.integer 7)
def tel : Tel := .param "x" (same 0) (.param "y" (same 0) (.done (same 1) Eff.empty))
def body : Comp := .ret (.var 0)

theorem scalar_ann (P : Program) (C : List TParam) (Γ : Ctx) : Ty.Annotation P C Γ scalar :=
  ⟨trivial, trivial, trivial⟩

theorem var_sort {Γ : Ctx} {i : Nat} {a : Ty} (hi : Γ[i]? = some (some a))
    (ha : a.HasSort .integer) : (Term.var i).HasSort Γ .integer :=
  ⟨⟨a, hi, ha.ordinary⟩, a, hi, ha⟩

theorem literal_sort (Γ : Ctx) : (Term.integer 7).HasSort Γ .integer := ⟨trivial, rfl⟩

theorem equalSeven_ann (P : Program) (C : List TParam) (Γ : Ctx) :
    Ty.Annotation P C Γ equalSeven := by
  refine ⟨?_, ⟨trivial, var_sort rfl rfl, literal_sort _⟩, ?_⟩
  · simp [equalSeven, scalar, Ty.WF, Pred.WF, Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core]
  · exact ⟨trivial, ⟨scalar.shiftV 1 0, rfl, by simp [scalar, Ty.shiftV, Ordinary]⟩, trivial⟩

theorem same_ann (P : Program) (C : List TParam) {Γ : Ctx} {i : Nat} {a : Ty}
    (hi : Γ[i]? = some (some a)) (ha : a.HasSort .integer) : Ty.Annotation P C Γ (same i) := by
  have hn := (List.getElem?_eq_some_iff.mp hi).1
  refine ⟨?_, ⟨trivial, var_sort rfl rfl, var_sort hi ha⟩, ?_⟩
  · simp [same, scalar, Ty.WF, Pred.WF, Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core]
    omega
  · refine ⟨trivial, ⟨scalar.shiftV 1 0, rfl, by simp [scalar, Ty.shiftV, Ordinary]⟩, ?_⟩
    exact ⟨a.shiftV 1 0, by simp [Ctx.declarationSelf, Ctx.extend, List.getElem?_map, hi], (Ty.ordinary_shiftV _ _ _).mpr ha.ordinary⟩

theorem seven_scalar (P : Program) (B : Builtins) (Ψ : StoreTy) (C : List TParam) (Γ : Ctx) (Φ : List Pred) :
    HasTypeVQ P B Ψ Qempty C Γ Φ seven scalar :=
  .V_Const (by change (-128 : Int) ≤ 7 ∧ 7 ≤ 127; decide)

theorem seven_equalSeven (P : Program) (B : Builtins) (Ψ : StoreTy) (C : List TParam) (Γ : Ctx) (Φ : List Pred) :
    HasTypeVQ P B Ψ Qempty C Γ Φ seven equalSeven := by
  have ha := equalSeven_ann P C Γ
  exact .V_Refine (seven_scalar P B Ψ C Γ Φ) rfl rfl ha.sorted.2 ha.wf.2.1 .eq_refl trivial ha.declared.2

theorem initial_regular (P : Program) : Ctx.Regular P [] initial :=
  (Ctx.Regular.empty P []).extend (equalSeven_ann P [] [])

theorem initial_capture (P : Program) (B : Builtins) (Ψ : StoreTy) :
    CaptureOk P B Ψ none initial [] cap0 := by
  have hv : HasTypeVQ P B Ψ Qempty [] [] [] seven (Capture.empty.closeTy equalSeven) := by
    simpa [Capture.closeTy, Capture.env, Capture.empty, Capture.values, substTyValues, valEnv,
      Ty.bind, Ty.rawBind, Ty.norm, equalSeven, scalar, predBind, upValues, termBind, termBind?] using
      seven_equalSeven P B Ψ [] [] []
  exact (CaptureOk.empty P B Ψ none).extend (equalSeven_ann P [] []) hv trivial

theorem initial_fact : pathFact ∈ initial.facts := by
  apply Ctx.mem_facts_extend.mpr
  exact Or.inl List.mem_cons_self

theorem initial_phi (P : Program) (B : Builtins) : FactsWF P [] initial [pathFact] := by
  intro p hp
  have he := List.mem_singleton.mp hp
  subst p
  exact (initial_regular P).facts B pathFact initial_fact

theorem capture_with_phi (P : Program) (B : Builtins) (Ψ : StoreTy) :
    CaptureOk P B Ψ none initial [pathFact] cap0 := by
  have hc := initial_capture P B Ψ
  have hfact := hc.conditions pathFact (List.mem_append_left _ initial_fact)
  cases hc with
  | mk hw hn hh hs _ hg hi hf =>
    refine .mk hw hn hh hs ?_ hg hi ?_
    · intro p hp
      have hv := initial_phi P B p hp
      exact ⟨hv.wf, hv.sorted, hv.declared⟩
    · intro p hp
      rcases List.mem_append.mp hp with hp | hp
      · exact hf p (List.mem_append_left _ hp)
      · have he := List.mem_singleton.mp hp
        subst p
        exact hfact

theorem tel_annotation (P : Program) : Ty.Annotation P [] initial (.dependentFn tel) := by
  have hx := same_ann P [] (Γ := initial) (i := 0) (a := equalSeven.shiftV 1 0) rfl
    ((Ty.hasSort_shiftV _ _ _ _).mpr rfl)
  have hy := same_ann P [] (Γ := initial.extend (same 0)) (i := 0) (a := (same 0).shiftV 1 0) rfl
    ((Ty.hasSort_shiftV _ _ _ _).mpr rfl)
  have hr := same_ann P [] (Γ := (initial.extend (same 0)).extend (same 0))
    (i := 1) (a := ((same 0).shiftV 1 0).shiftV 1 0) rfl
    ((Ty.hasSort_shiftV _ _ _ _).mpr ((Ty.hasSort_shiftV _ _ _ _).mpr rfl))
  exact ⟨⟨hx.wf, hy.wf, hr.wf, trivial, rfl⟩,
    ⟨hx.sorted, hy.sorted, hr.sorted, trivial⟩, ⟨hx.declared, hy.declared, hr.declared, trivial⟩⟩

theorem extended_regular (P : Program) : Ctx.Regular P [] (tel.context initial) :=
  Tel.regular_context (initial_regular P) (tel_annotation P)

theorem extended_phi (P : Program) (B : Builtins) :
    FactsWF P [] (tel.context initial) (liftMany 2 [pathFact]) := by
  exact (initial_phi P B).extendMany tel.inputs

theorem extended_facts (P : Program) (B : Builtins) :
    FactsWF P [] (tel.context initial) (tel.context initial).facts :=
  (extended_regular P).facts B

theorem body_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    TelBodyTy P B Ψ Qempty [] initial [pathFact] tel body := by
  apply TelBodyTy.param
  apply TelBodyTy.param
  apply TelBodyTy.done
  apply HasTypeCQ.C_Return
  exact .V_Var rfl (by simp [same])

theorem close_same_initial : cap0.closeTy (same 0) = equalSeven := by
  simp [Capture.closeTy, substTyValues, Ty.bind, Ty.rawBind, Ty.norm, same, equalSeven, scalar,
    predBind, upValues, termBind, termBind?, valEnv, cap0, Capture.extend, Capture.env,
    Capture.empty, Capture.values, seven, Val.toTerm?]

theorem open_contract_annotation (P : Program) (B : Builtins) (Ψ : StoreTy) :
    Ty.Annotation P [] initial (.dependentFn
      (Tel.bind (Tel.argumentsEnv (.var 0)) (.param "y" (same 0) (.done (same 1) Eff.empty)))) := by
  have ha : HasTypeVQ P B Ψ Qempty [] initial [pathFact] (.var 0) (same 0) := by
    have hx := (tel_annotation P)
    have hs : HasTypeVQ P B Ψ Qempty [] initial [pathFact] (.var 0) scalar :=
      .V_Sub (.V_Var rfl (by simp [equalSeven, Ty.shiftV])) .forget trivial trivial trivial
    exact .V_Refine hs rfl rfl hx.sorted.1.2 hx.wf.1.2.1 .eq_refl trivial hx.declared.1.2
  exact Tel.annotation_open (initial_regular P).wf (tel_annotation P) ha

def closedTel : Tel := cap0.closeTel tel

theorem closed_annotation (P : Program) (B : Builtins) (Ψ : StoreTy) :
    Ty.Annotation P [] [] (.dependentFn closedTel) := by
  have h := (initial_capture P B Ψ).substOk.annotation (tel_annotation P)
  exact h

theorem arguments_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeTelArgsQ P B Ψ Qempty [] [] [] [seven, seven] closedTel equalSeven Eff.empty := by
  have he : Tel.arguments closedTel [seven, seven] = some ([equalSeven, equalSeven], equalSeven, Eff.empty) := by
    simp [closedTel, Capture.closeTel, tel, Tel.arguments, Tel.bind, Tel.norm, Tel.rawBind, Tel.argumentsEnv,
      same, equalSeven, scalar, predBind, upValues, termBind, termBind?, valEnv, SubstEnv.up,
      Eff.rawBind, rawBindTys, Eff.norm, Eff.empty, substAtoms_nil, instAtoms_nil,
      rowFails, Ty.rawBind, Ty.norm, Ty.normTys, cap0, Capture.env, Capture.extend, Capture.empty,
      Capture.values, seven, Val.toTerm?]
  exact HasTypeTelArgsQ.of_arguments he
    (.cons (seven_equalSeven P B Ψ [] [] []) (.cons (seven_equalSeven P B Ψ [] [] []) .nil))
    (closed_annotation P B Ψ) (by simp [Ctx.WF])

theorem beta_capture (P : Program) (B : Builtins) (Ψ : StoreTy) :
    CaptureOk P B Ψ none (tel.context initial) (liftMany 2 [pathFact])
      (cap0.extendMany [seven, seven]) :=
  (capture_with_phi P B Ψ).extendTel (tel_annotation P) (arguments_typed P B Ψ)
    (by intro v hv; simp only [List.mem_cons, List.not_mem_nil, or_false] at hv; rcases hv with rfl | rfl <;> trivial)

theorem none_capture (P : Program) (B : Builtins) (Ψ : StoreTy) :
    CaptureOk P B Ψ none (tel.context initial).extendNone
      ((liftMany 2 [pathFact]).map Pred.lift) ((cap0.extendMany [seven, seven]).extend (.loc 0)) :=
  (beta_capture P B Ψ).extendHidden (.loc 0) trivial

theorem none_keeps_number : (tel.context initial).extendNone[0]? = some none ∧
    (tel.context initial).extendNone[1]? = some (some ((same 0).shiftV 2 0)) := by
  constructor
  · rfl
  · change some (some (((same 0).shiftV 1 0).shiftV 1 0)) = _
    rw [Ty.shiftV_add]

theorem none_not_readable : ¬ (tel.context initial).extendNone.Readable 0 :=
  Ctx.not_readable_none rfl

theorem beta_closure_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    DependentClosureTy P B Ψ (.mk cap0 body) closedTel := by
  apply DependentClosureTy.mk (Γ := initial) (Φ := [pathFact]) (t := tel)
  · exact capture_with_phi P B (hideBuilders Ψ)
  · exact body_typed P B (hideBuilders Ψ)
  · exact tel_annotation P
  · exact closed_annotation P B (hideBuilders Ψ)

def call : Closure := Closure.pure (.app (.closure closedTel (.mk cap0 body)) [seven, seven])

theorem beta_call_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeCQ P B Ψ Qempty [] [] [] none call.code equalSeven Eff.empty [] := by
  apply HasTypeCQ.C_DependentApp (t := closedTel)
  · apply HasTypeVQ.V_Closure (closed_annotation P B Ψ)
      ⟨(closed_annotation P B Ψ).wf, (closed_annotation P B Ψ).wf, Tel.SameInputs.refl _⟩
    exact beta_closure_typed P B Ψ
  · exact arguments_typed P B Ψ

theorem beta_step (P : Program) (B : Builtins) (σ : PathEnv) :
    Step P B σ (.run call [] Store.empty) none
      (.run (.mk (cap0.extendMany [seven, seven]) body) (markPush []) Store.empty) := by
  apply Step.E_Lam (signature := closedTel) (body := .mk cap0 body) rfl
  exact (arguments_typed P B StoreTy.empty).length

-- source の長さの上限だけなら通るが、自分を参照する注釈は Ordered が拒む。
def selfCycle : Ctx := [some (same 0)]
def backward : Ctx := [some scalar, some (same 0)]
def twoCycle : Ctx := [some (same 1), some (same 0)]

theorem self_cycle_bounded : Ctx.WF 0 0 selfCycle := by
  intro i a hi
  cases i with
  | zero => cases hi; simp [same, scalar, Ty.WF, Pred.WF, Pred.VarsIn, Term.VarsIn, selfCycle, Ty.NotContCore, Ty.core]
  | succ i => simp [selfCycle] at hi

theorem self_cycle_rejected : ¬ selfCycle.Ordered := by
  intro h
  have hp := h.refined_outer (i := 0) (a := scalar) (p := .eq (.var 0) (.var 1)) rfl
  simp [Pred.VarsIn, Term.VarsIn] at hp

theorem backward_rejected : ¬ backward.Ordered := by
  intro h
  have hp := h.refined_outer (i := 1) (a := scalar) (p := .eq (.var 0) (.var 1)) rfl
  simp [Pred.VarsIn, Term.VarsIn] at hp

theorem two_cycle_rejected : ¬ twoCycle.Ordered := by
  intro h
  have hp := h.refined_outer (i := 1) (a := scalar) (p := .eq (.var 0) (.var 1)) rfl
  simp [Pred.VarsIn, Term.VarsIn] at hp

-- None に置いた値を整数として読む型は、番号が内側にあっても Sorted ではない。
theorem none_annotation_rejected (P : Program) : ¬ Ty.Annotation P [] initial.extendNone (same 0) := by
  intro h
  obtain ⟨a, ha, _⟩ := h.sorted.2.2.1
  cases ha

-- 関数は sort がなくても snapshot の参照になり、外側の参照順序を保つ。
def functionType : Ty := .fn [] [] scalar Eff.empty
def snapshotType : Ty := .refined (.list functionType)
  (.compare .list .eq (.var 0) (.listValue [some (.var 1)]))

theorem function_snapshot_reference : snapshotType.References (Ctx.extend [] functionType) := by
  simp [snapshotType, functionType, scalar, Ty.References, referencesTys, Eff.References, Eff.empty,
    Pred.References, Pred.VarsIn, Term.VarsIn, varsInSlots, varsInSlot, Ctx.Readable,
    Ctx.extend, Ty.shiftV, Ordinary]

-- 開いた型変数の kind を同じ宣言に固定する。
def constructorD : List TParamDecl := [⟨{}, .constructor 1⟩]

theorem constructor_kind_fixed (P : Program) : TypeArgsKindedAt P constructorD [.tvar 0] [.constructor 1] := by
  refine ⟨rfl, ?_⟩
  intro i a k ha hk
  cases i with
  | zero => cases ha; cases hk; rfl
  | succ i => simp at ha

theorem value_kind_conflict (P : Program) : ¬ TypeArgsKindedAt P constructorD [.tvar 0] [.value] := by
  intro h
  have hk := h.2 0 (.tvar 0) .value rfl rfl
  cases hk

-- CaptureWF は重複Failを持つソース継続を許し、Ctx.WF は許さない。
def duplicate : Eff := .mk (fun _ => false) [scalar, scalar]
def loose : Ctx := [some (.cont scalar scalar duplicate)]

theorem capture_wf_loose : Ctx.CaptureWF 0 0 loose := by
  intro i a hi
  cases i with
  | zero => cases hi; exact ⟨trivial, trivial⟩
  | succ i => simp [loose] at hi

theorem source_wf_rejects_duplicate : ¬ Ctx.WF 0 0 loose := by
  intro h
  have hc := (h 0 (.cont scalar scalar duplicate) rfl).2.2.2
  have he := congrArg Eff.fails hc
  have hn := congrArg List.length he
  have ht := (tyCompare_eq_iff (Ty.base .integer8) (Ty.base .integer8)).mpr rfl
  simp [duplicate, Eff.norm, Ty.normTys, scalar, Ty.norm, Eff.fails, Order.sortUnique, Order.insertUnique, ht] at hn


def normalRow : Eff := .mk (fun _ => false) [scalar]
def looseStore : StoreTy := fun l => if l = 0 then some (.cont scalar scalar normalRow none) else none
def looseCap : Capture := .mk [some (.loc 0)]

theorem close_duplicate : looseCap.closeTy (.cont scalar scalar duplicate) = .cont scalar scalar normalRow := by
  have ht := (tyCompare_eq_iff (Ty.base .integer8) (Ty.base .integer8)).mpr rfl
  simp [Capture.closeTy, substTyValues, Ty.bind, Ty.rawBind, Eff.rawBind, rawBindTys, valEnv, rowFails,
    instAtoms_nil, substAtoms_nil, Ty.norm, Ty.normTys, Eff.norm, duplicate, normalRow, scalar,
    Order.sortUnique, Order.insertUnique, ht]

theorem loose_capture (P : Program) (B : Builtins) :
    CaptureOk P B looseStore none loose [] looseCap := by
  refine .mk capture_wf_loose rfl ?_ ?_ ?_ ?_ ?_ ?_
  · intro i a hi
    cases i with
    | zero => exact ⟨.loc 0, rfl⟩
    | succ i => simp [loose] at hi
  · intro i a hi
    cases i with
    | zero => cases hi; exact ⟨⟨trivial, trivial⟩, ⟨trivial, trivial⟩⟩
    | succ i => simp [loose] at hi
  · intro p hp; cases hp
  · intro ov ho v hv
    simp only [looseCap, Capture.values, List.mem_cons, List.not_mem_nil, or_false] at ho
    have he : v = .loc 0 := Option.some.inj (hv.symm.trans ho)
    subst v
    trivial
  · intro i a hi
    cases i with
    | zero =>
      cases hi
      apply ImageOk.contLoc (b := scalar) (t := scalar) (e := duplicate) (l := 0) rfl close_duplicate
      · exact ⟨trivial, trivial, ⟨trivial, trivial⟩, rfl⟩
      · rfl
      · simp [looseStore]
      · intro r hr; cases hr
    | succ i => simp [loose] at hi
  · intro p hp
    simp [loose, Ctx.facts, Ty.assume] at hp

theorem loose_capture_extended (P : Program) (B : Builtins) :
    CaptureOk P B looseStore none (loose.extend scalar).extendNone []
      ((looseCap.extend seven).extend (.loc 0)) := by
  have hv : HasTypeVQ P B looseStore Qempty [] [] [] seven (looseCap.closeTy scalar) :=
    seven_scalar P B looseStore [] [] []
  exact ((loose_capture P B).extend (scalar_ann P [] loose) hv trivial).extendHidden (.loc 0) trivial

def operation : OpDecl := ⟨"Choice", [], ["x", "y"], [scalar, same 0], same 1, []⟩
def userProgram : Program := {
  defs := fun _ => none, cons := fun _ => none,
  ops := fun o => if o = "pick" then some operation else none,
  effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }

theorem operation_regular : operation.SignatureWF := by
  simp [OpDecl.SignatureWF, operation, BinderTypes.LocalWF, same, scalar, Ty.WF, Pred.WF,
    Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core]

theorem user_table_regular : userProgram.OpSignaturesWF := by
  intro o d hd
  simp only [userProgram] at hd
  split at hd
  · cases hd; exact operation_regular
  · cases hd

theorem user_clause_signature (B : Builtins) :
    (OpSig.mk [] ["x", "y"] [scalar, same 0] (same 1) "Choice").WF :=
  user_table_regular.user (B := B) (S := .absolute .top) (o := "pick") (by simp [opSigAt, userProgram, operation])

def targetSig : PrimSig := {
  tparams := [⟨{}, .value⟩], neffs := 0, names := ["target", "x", "y"],
  params := [.scoped "Path" .path (.rvar 0), scalar, same 0], ret := same 1,
  eff := Eff.single "Read", admits := fun _ _ => True,
  kind := .io, opEff := some "Read", rkinds := [.path] }

def targetBuiltins (B : Builtins) : Builtins := { B with sig := fun b => if b = "read" then some targetSig else none }

theorem target_declaration_regular : targetSig.OperationWF := by
  simp [PrimSig.OperationWF, BinderTypes.TargetWF, Ty.TargetWF, targetSig, same, scalar,
    Ty.WF, Pred.WF, Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core]

theorem builtin_table_regular (B : Builtins) : (targetBuiltins B).OpSignaturesWF := by
  intro b s hb _
  simp only [targetBuiltins] at hb
  split at hb
  · cases hb; exact target_declaration_regular
  · cases hb

theorem target_clause_signature (P : Program) (B : Builtins) (S : RangeExpr) :
    (OpSig.mk [{}] ["target", "x", "y"]
      [.scoped "Path" .path (.fixed S), scalar, same 0] (same 1) "Read").WF :=
  (builtin_table_regular B).prim (P := P) (S := S) (b := "read")
    (by simp [opSigAt, targetBuiltins, targetSig, Ty.instTarget, RangeIx.inst, scalar, same])

-- 宣言したconstructor kindから、SignatureInstanceを経て実際のV_Funへ接続する。
def polymorphicDef : Def := ⟨constructorD, 0, [], [], scalar, Eff.empty, .ret seven⟩
def functionProgram : Program := { userProgram with defs := fun f => if f = "f" then some polymorphicDef else none }

theorem fixed_signature : SignatureInstanceAt functionProgram constructorD [] polymorphicDef.tel
    [.constructor 1] [.tvar 0] [] := by
  refine ⟨?_, ?_, constructor_kind_fixed functionProgram, ?_, ?_⟩
  · exact ⟨trivial, trivial, rfl⟩
  · intro a ha
    have he := List.mem_singleton.mp ha
    subst a
    exact ⟨by simp [Ty.WF, constructorD], trivial, trivial⟩
  · intro e he; cases he
  · exact ⟨⟨trivial, trivial, rfl⟩, ⟨trivial, trivial⟩, ⟨trivial, trivial⟩⟩

theorem fixed_function_typed (B : Builtins) (Ψ : StoreTy)
    (hsat : B.sat (constructorD.map TParamDecl.constraints) (.tvar 0) {}) :
    HasTypeVQ functionProgram B Ψ Qempty (constructorD.map TParamDecl.constraints) [] []
      (.fnRef "f" [.tvar 0] [])
      (.dependentFn (instantiatedTel polymorphicDef.tel [.tvar 0] [])) := by
  apply HasTypeVQ.V_Fun (d := polymorphicDef)
  · simp [functionProgram]
  · exact ⟨rfl, by decide⟩
  · refine ⟨⟨rfl, ?_⟩, ?_, ?_, ?_, ?_, ?_, ?_⟩
    · intro i a p ha hp
      cases i with
      | zero => cases ha; cases hp; exact hsat
      | succ i => simp at ha
    · intro a ha
      have he := List.mem_singleton.mp ha
      subst a
      exact ⟨by simp [Ty.WF, constructorD], by simp [Ordinary]⟩
    · rfl
    · intro e he; cases he
    · constructor
      · intro i hi; cases hi
      · trivial
    · intro i hi
      simp [Qsig, QTys, QTy, QEff, polymorphicDef, scalar, Qempty, Eff.empty] at hi
    · intro i hi
      simp [Qsig, QTys, QTy, QEff, polymorphicDef, scalar, Qempty, Eff.empty] at hi
  · exact fixed_signature.forget


theorem out_of_scope_input_rejected (P : Program) :
    ¬ Ty.Annotation P [] [] (.dependentFn (.param "x" (same 0)
      (.param "y" scalar (.done scalar Eff.empty)))) := by
  intro h
  have hw := h.wf.1.2.1
  simp [Pred.WF, Pred.VarsIn, Term.VarsIn] at hw

theorem none_regular (P : Program) : Ctx.Regular P [] (tel.context initial).extendNone :=
  (extended_regular P).extendNone

theorem none_phi (P : Program) (B : Builtins) :
    FactsWF P [] (tel.context initial).extendNone ((liftMany 2 [pathFact]).map Pred.lift) :=
  (extended_phi P B).extendNone

theorem function_snapshot_ordered : (Ctx.extend [] functionType |>.extend snapshotType).Ordered := by
  have hf : functionType.References [] := ⟨trivial, trivial, trivial⟩
  exact (Ctx.Ordered.nil.extend hf).extend function_snapshot_reference

def textContext : Ctx := Ctx.extend [] (.base .string)
def textFact : Pred := .compare .string .eq (.var 0) (.string "x")

theorem text_phi_after_none (P : Program) :
    FactsWF P [] textContext.extendNone [textFact.lift] := by
  have hv : Pred.WellFormed P [] textContext textFact := by
    have hs : textFact.Sorted textContext none :=
      ⟨trivial, ⟨⟨.base .string, rfl, by simp [Ordinary]⟩, .base .string, rfl, rfl⟩,
        ⟨trivial, rfl⟩⟩
    exact ⟨hs.wf_none, hs, ⟨⟨.base .string, rfl, by simp [Ordinary]⟩, trivial⟩⟩
  have hf : FactsWF P [] textContext [textFact] := by
    intro p hp
    have he := List.mem_singleton.mp hp
    subst p
    exact hv
  exact hf.extendNone


-- Dependsは自然数の大小を定義に含まず、注釈が必要とする参照を読む。
theorem self_cycle_dependency : selfCycle.Depends 0 0 := by
  refine ⟨same 0, rfl, ?_⟩
  simp [selfCycle, Ctx.without, same, scalar, Ty.References, Pred.References,
    Pred.VarsIn, Term.VarsIn, Ctx.Readable]

theorem cycle_forbidden_from_ordered {Γ : Ctx} (h : Γ.Ordered) (i : Nat) :
    ¬ Relation.TransGen Γ.Depends i i := fun hc => Ctx.no_dependency_cycle h i hc

theorem ordered_dependency_points_outward :
    (initial.extend (same 0)).Depends 0 1 ∧
      ¬ Relation.TransGen (initial.extend (same 0)).Depends 0 0 := by
  have ha := (tel_annotation userProgram)
  constructor
  · refine ⟨(same 0).shiftV 1 0, rfl, ?_⟩
    simp [initial, equalSeven, Ctx.without, Ctx.extend, same, scalar, Ty.shiftV, Ty.References, Pred.References,
      Pred.VarsIn, Term.VarsIn, predBind, Ctx.Readable]
  · exact cycle_forbidden_from_ordered ((initial_regular userProgram).extend
      ⟨ha.wf.1, ha.sorted.1, ha.declared.1⟩).ordered 0

theorem hidden_cont_regular (P : Program) :
    Ctx.Regular P [] (hideConts (initial.extend (.cont scalar scalar Eff.empty))) :=
  ((initial_regular P).extend (a := .cont scalar scalar Eff.empty)
    ⟨⟨trivial, trivial, trivial, rfl⟩, ⟨trivial, trivial, trivial⟩, ⟨trivial, trivial, trivial⟩⟩).hideConts

theorem nondependent_params_regular (P : Program) :
    Ctx.Regular P [] (bindParams initial [same 0, scalar]) := by
  apply Ctx.Regular.bindParams 2 rfl (initial_regular P)
  intro a ha
  simp only [List.mem_cons, List.not_mem_nil, or_false] at ha
  rcases ha with rfl | rfl
  · exact ⟨(tel_annotation P).wf.1, (tel_annotation P).sorted.1, (tel_annotation P).declared.1⟩
  · exact scalar_ann P [] initial

-- E_OpFailの値と継続場所の順を保ち、Noneの位置にも実行値が残る。
def failureBody : Comp := .ret (.var 1)
def failureHandler : List Clause := [.fail scalar failureBody]
def failureCall : Closure := Closure.pure (.app (.raise scalar scalar) [seven])

theorem opfail_target_capture (P : Program) (B : Builtins) (Ψ : StoreTy) :
    CaptureOk P B Ψ none (failureContext initial scalar) (liftMany 2 [pathFact])
      (cap0.extendMany [seven, .loc 0]) := by
  have h := (capture_with_phi P B Ψ).extend (scalar_ann P [] initial)
    (show HasTypeVQ P B Ψ Qempty [] [] [] seven (cap0.closeTy scalar) from seven_scalar P B Ψ [] [] [])
    (show seven.Ground from trivial)
  exact h.extendHidden (.loc 0) trivial

theorem opfail_hidden_location :
    (cap0.extendMany [seven, .loc 0]).env 0 = .loc 0 ∧
      ¬ (failureContext initial scalar).Readable 0 :=
  ⟨rfl, Ctx.not_readable_none rfl⟩

theorem opfail_step (P : Program) (B : Builtins) (σ : PathEnv) :
    Step P B σ (.run failureCall [.handleF cap0 failureHandler] Store.empty) none
      (.run (.mk (cap0.extendMany [seven, .loc 0]) (failureBody.substTy [scalar] []))
        [.drop 0] (Store.empty.set 0 (.cont [.handleF cap0 failureHandler]))) := by
  apply Step.E_OpFail (k1 := []) (k2 := []) (E := scalar) rfl
  · refine ⟨rfl, rfl, ?_⟩
    intro cap h hh
    cases hh
  · rfl

theorem cont_location_capture (P : Program) (B : Builtins) :
    CaptureOk P B looseStore none (initial.extend (.cont scalar scalar duplicate))
      ([pathFact].map Pred.lift) (cap0.extend (.loc 0)) := by
  have he : cap0.closeTy (.cont scalar scalar duplicate) = .cont scalar scalar normalRow := by
    have ht := (tyCompare_eq_iff (Ty.base .integer8) (Ty.base .integer8)).mpr rfl
    simp [Capture.closeTy, substTyValues, Ty.bind, Ty.rawBind, Eff.rawBind, rawBindTys, valEnv, rowFails,
      instAtoms_nil, substAtoms_nil, Ty.norm, Ty.normTys, Eff.norm, duplicate, normalRow, scalar,
      Order.sortUnique, Order.insertUnique, ht]
  apply (capture_with_phi P B looseStore).extendCont (b := scalar) (t := scalar) (e := duplicate)
    (b' := scalar) (t' := scalar) (e' := normalRow) (l := 0)
    ⟨trivial, trivial⟩ ⟨trivial, trivial⟩ ⟨trivial, trivial⟩ he
  · rw [he]
    exact ⟨trivial, trivial, ⟨trivial, trivial⟩, rfl⟩
  · simp [looseStore]
  · intro r hr; cases hr

end
end Benitoite.Release.Refinement.ContextBoundary


open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := env.constants.toList.filterMap fun (name, _) =>
    if "Benitoite.Release.Refinement.ContextBoundary.".isPrefixOf name.toString then some name else none
  let names := names.mergeSort (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
