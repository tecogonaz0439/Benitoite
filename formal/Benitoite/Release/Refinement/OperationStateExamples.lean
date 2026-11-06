import Benitoite.Release.Refinement.HandlerGeneral
import Benitoite.Release.Refinement.PathBasesLeaves

/-! # 操作・失敗・再開の全状態の具体例 -/
namespace Benitoite.Release.Refinement
noncomputable section
namespace OperationStateExamples

private def unit : Val := .const .unit
private def rowType : Ty := .fn [] [] (.base .unit) (Eff.row 9)
private def argument : Val := .lam [] [] (.ret unit)
private def actualArgument : Val := closeVal Capture.empty argument
private def declaration : OpDecl := ⟨"Example.effect",[{}],["value"],[.tvar 0],.tvar 0,[]⟩
private def opEffect : Eff := .mk (fun a => match a with | .name n (.fixed .top) => decide (n = "Example.effect") | _ => false) []
private def outputEffect : Eff := Eff.union opEffect (Eff.single stateEff)
private def clauses : List Clause := [.mk (.user "Example.identity") 1 1 (.resume (.var 0) (.var 1))]
private def call : Comp := .app (.op "Example.identity" [rowType]) [argument]
private def source : Comp := .handle call clauses
private def opState : State := .run
  (.mk (Capture.empty.extendMany [actualArgument,.loc 0]) (.resume (.var 0) (.var 1)))
  [.drop 0] (Store.empty.set 0 (.cont [.handleF Capture.empty clauses]))
private def resumeState : State := .run (Closure.pure (.ret actualArgument))
  [.handleF Capture.empty clauses,.drop 0]
  ((Store.empty.set 0 (.cont [.handleF Capture.empty clauses])).set 0 .used)

private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e := by
  constructor
  · intro a ha; cases ha
  · intro t ht; obtain ⟨u,hu,_⟩ := ht; cases hu

private theorem row_annotation {P C Γ} : Ty.Annotation P C Γ rowType :=
  ⟨by simp [rowType,Ty.WF,Ty.WFList,NamesWF,Eff.WF,Eff.Canonical,Eff.norm,Eff.row],by trivial,by trivial⟩

private theorem argument_typed {P B Ψ Q C Γ Φ} : HasTypeVQ P B Ψ Q C Γ Φ argument rowType := by
  refine .V_Lam (by trivial) (row_annotation (P := P)).wf (row_annotation (P := P) (C := C)).sorted ?_ row_annotation.declared
  exact .C_Eff (.C_Return (.V_Const (by trivial))) (empty_sub _).covers

private theorem call_signature {P} : SignatureInstance P [] [] declaration.tel [.value] [rowType] [] := by
  refine ⟨?_,?_,?_,?_,?_,?_⟩
  · simp [declaration,OpDecl.tel,signatureTel,Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.Canonical,Eff.norm]
  · intro a ha; cases List.mem_singleton.mp ha; exact row_annotation
  · refine ⟨rfl,?_⟩
    intro i a k ha hk
    cases i with
    | zero => cases ha; cases hk; exact ⟨by trivial,by trivial⟩
    | succ i => simp at ha
  · intro e he; cases he
  · intro e he; cases he
  · exact ⟨by simp [declaration,OpDecl.tel,signatureTel,instantiatedTel,Tel.bind,Tel.rawBind,
        typeEnvAt,Ty.rawBind,Ty.norm,Tel.norm,SubstEnv.up,Eff.rawBind,rowType,
        Ty.WF,Tel.WF,Ty.WFList,NamesWF,Eff.WF,Eff.Canonical,Eff.norm,Eff.row,Ty.normTys,rowFails,Ty.shiftV,Eff.shiftV],
      by trivial,by trivial⟩

private theorem source_code {P B} (hB : B.CoreAssumptions P)
    (hop : P.ops "Example.identity" = some declaration) :
    HasTypeCQ P B StoreTy.empty Qempty [] [] [] none source rowType outputEffect [] := by
  have hv : HasTypeVQ P B StoreTy.empty Qempty [] [] [] (.op "Example.identity" [rowType])
      (.dependentFn (instantiatedTel declaration.tel [rowType] [])) :=
    .V_Op hop (by simp [declaration,NamesWF]) ⟨rfl,by
      intro i t p ht hp
      cases i with
      | zero => cases ht; cases hp; exact hB.sat_unconstrained _ (row_annotation (P := P) (C := []) (Γ := [])).wf
      | succ i => simp [declaration] at hp⟩ call_signature
  have hargs : HasTypeTelArgsQ P B StoreTy.empty Qempty [] [] [] [argument]
      (instantiatedTel declaration.tel [rowType] []) rowType opEffect := by
    have heq : instantiatedTel declaration.tel [rowType] [] = .param "value" rowType (.done rowType opEffect) := by
      simp [declaration,OpDecl.tel,signatureTel,instantiatedTel,Tel.bind,Tel.rawBind,typeEnvAt,Ty.rawBind,Ty.norm,Tel.norm,SubstEnv.up,Eff.rawBind,rowType,opEffect,Eff.row,Eff.norm,rowFails,instAtoms_nil,substAtoms_nil,Ty.normTys,Ty.shiftV,Eff.shiftV]
      rfl
    rw [heq]
    refine .param (rest := .done rowType opEffect) row_annotation argument_typed ?_
    have heq' : Tel.bind (Tel.argumentsEnv argument) (.done rowType opEffect) = .done rowType opEffect := by
      simp [Tel.bind,Tel.rawBind,Tel.argumentsEnv,valEnv,Ty.rawBind,Ty.norm,Tel.norm,rowType,opEffect,
        Eff.rawBind,Eff.norm,Eff.row,Ty.normTys,rowFails,instAtoms_nil,substAtoms_nil]
    rw [heq']
    exact .done ⟨by simp [rowType,opEffect,Ty.WF,Tel.WF,Ty.WFList,NamesWF,Eff.WF,Eff.Canonical,Eff.norm,Eff.row],by trivial,by trivial⟩
  refine .C_Handle (.C_DependentApp hv hargs) ?_ ?_
  · constructor
    · intro a ha
      apply (Eff.mem_union_iff _ _ _).mpr
      exact Or.inl ((Eff.mem_union_iff _ _ _).mpr (Or.inl ha))
    · intro t ht; obtain ⟨u,hu,_⟩ := ht; cases hu
  · let sg : OpSig := ⟨TypeCtx.values [{}],["value"],[.tvar 0],.tvar 0,"Example.effect"⟩
    refine .cons (sg := sg) (ClauseSig.of_opSig ?_ (by intro b s hh; cases hh)) (by simp [sg,NamesWF]) rfl rfl
      (by simp [sg,OpSig.WF,BinderTypes.LocalWF,Ty.WF]) ?_ .nil
    · simp only [opSig,opSigAt,hop,Option.map_some]
      rfl
    · change HasTypeCQ P B _ _ _ _ _ _ (.resume (.var 0) (.var 1)) _ _ []
      refine .C_Resume (by rfl) (.V_Var (by rfl) (by trivial)) ?_
      exact row_annotation.declared

private theorem initial {P B σ m a e}
    (h : HasTypeCQ P B StoreTy.empty Qempty [] [] [] none m a e [])
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a e)))
    (hn : a.Normal) (hc : m.ClosedAt 0 0) (had : m.Adequate σ) :
    StateTyE P B σ e (.run (Closure.pure m) [] Store.empty) := by
  have hq := ClosureTy.pure h ha (by intro r hr; cases hr) hn (by intro r hr; cases hr)
  exact ⟨StoreTy.empty,none,a,a,e,e,StoreOk.empty P B σ,hq,
    ⟨fun _ h => h,fun _ h => h⟩,.K_Empty ⟨fun _ h => h,fun _ h => h⟩
    ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩,⟨trivial,had⟩,⟨trivial,hc⟩,
    (by intro f hf; cases hf),(by intro l c hc; cases hc)⟩

private theorem row_initial {P B σ} (hB : B.CoreAssumptions P)
    (hop : P.ops "Example.identity" = some declaration) :
    StateTyE P B σ outputEffect (.run (Closure.pure source) [] Store.empty) := by
  refine initial (source_code hB hop) ?_ ?_ ?_ ?_
  · exact ⟨by simp [rowType,outputEffect,opEffect,Ty.WF,Tel.WF,Ty.WFList,NamesWF,
        Eff.WF,Eff.Canonical,Eff.norm,Eff.row,Eff.single,Eff.union,Ty.normTys,Eff.fails],by trivial,by trivial⟩
  · rfl
  · simp [source,call,clauses,argument,unit,rowType,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,
      Clause.ClosedList,Ty.WF,Ty.WFList,NamesWF,Eff.WF,Eff.Canonical,Eff.norm,Eff.row]
  · simp [source,call,clauses,argument,unit,Comp.Adequate,Val.Adequate,adequateVals,adequateClauses]

theorem row_handle_operation_resume {P B σ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hop : P.ops "Example.identity" = some declaration) :
    StateTyE P B σ outputEffect opState ∧ StateTyE P B σ outputEffect resumeState := by
  have hh := (row_initial (σ := σ) hB hop).handle_step hB rfl
  have ho : StateTyE P B σ outputEffect opState := by
    apply hh.operation_all hP hPB hB (o := "Example.identity") (ts := [rowType]) (ws := [actualArgument]) (l := 0) ?_
      (k1 := []) (k2 := []) ⟨rfl,rfl,by intro cap cs hm; cases hm⟩ rfl rfl
    change Comp.app (.op "Example.identity" [Capture.empty.closeTy rowType]) [actualArgument] = _
    have ht : Capture.empty.closeTy rowType = rowType :=
      (Ty.subst_values_of_wf_zero (row_annotation (P := P) (C := []) (Γ := [])).wf _).trans rfl
    rw [ht]
  refine ⟨ho,?_⟩
  exact ho.resume_all hP hPB hB rfl rfl

theorem noFail_cutoff_accept :
    NoFail (fun i => i = 9) (Eff.substAt 2 [rowType] [] (Eff.row 9)) := by
  have h : NoFail (fun i => i = 9) (Eff.row 9) := by
    refine ⟨rfl,?_⟩
    intro i hi
    simpa [Eff.row,Eff.mem,Eff.test,Eff.atoms] using hi
  exact h.substAt 2 _ [] (by
    intro i hi
    cases hi
    exact ⟨rfl,by intro j hj; simpa [Eff.row,Eff.mem,Eff.test,Eff.atoms] using hj⟩)

theorem noFail_cutoff_reject :
    ¬ NoFail Qempty (Eff.substAt 2 [rowType] [] (Eff.row 9)) := by
  intro h
  apply h.2 9
  simp [Eff.substAt,substRowAt,Eff.bind,Eff.rawBind,typeEnvAt,Eff.row,Eff.test,Eff.atoms,
    Eff.norm,instAtoms_nil,substAtoms_nil]


private theorem unit_annotation {P C Γ} : Ty.Annotation P C Γ (.base .unit) := ⟨trivial,trivial,trivial⟩

private theorem left_sub (e f : Eff) : Eff.Sub e (Eff.union e f) :=
  ⟨fun _ ha => (Eff.mem_union_iff _ _ _).mpr (Or.inl ha),
   fun _ ha => (Eff.memFail_union_iff _ _ _).mpr (Or.inl ha)⟩

theorem failure_state {P B σ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    StateTyE P B σ (Eff.union Eff.empty (Eff.single stateEff))
      (.run (.mk (Capture.empty.extendMany [unit,.loc 0]) (.ret unit)) [.drop 0]
        (Store.empty.set 0 (.cont [.handleF Capture.empty [.fail (.base .unit) (.ret unit)]]))) := by
  have ha : Ty.Annotation P [] [] (.fn ["error"] [.base .unit] (.base .unit) (Eff.singleFail (.base .unit))) :=
    ⟨by simp [Ty.WF,Ty.WFList,NamesWF,Ty.norm,Eff.WF,Eff.singleFail,Eff.Canonical,Eff.norm,Ty.normTys],by trivial,by trivial⟩
  have hcode : HasTypeCQ P B StoreTy.empty Qempty [] [] [] none
      (.handle (.app (.raise (.base .unit) (.base .unit)) [unit]) [.fail (.base .unit) (.ret unit)])
      (.base .unit) (Eff.union Eff.empty (Eff.single stateEff)) [] := by
    refine .C_Handle_Fail (.C_App (.V_Raise ha (by trivial) (by trivial) (by trivial))
      (.cons (.V_Const (by trivial)) .nil)) (left_sub _ _) ⟨rfl,by intro i hi; cases hi⟩
      (.one unit_annotation unit_annotation ?_ ?_)
    · intro e he; cases List.mem_singleton.mp he
      exact ⟨by simp [Ty.WF,Ty.WFList,NamesWF,Eff.WF,Eff.single,Eff.Canonical,Eff.norm,Ty.normTys],by trivial,by trivial⟩
    · exact .C_Eff (.C_Return (.V_Const (by trivial))) (empty_sub _).covers
  have hh := (initial (σ := σ) hcode
    ⟨by simp [Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.union,Eff.empty,Eff.single,Eff.norm,Eff.fails,Eff.Canonical,Ty.normTys],by trivial,by trivial⟩
    rfl (by trivial) (by trivial)).handle_step hB rfl
  exact hh.operation_failure hP hPB hB (l := 0) rfl
    (k1 := []) (k2 := []) ⟨rfl,rfl,by intro cap cs hm; cases hm⟩ rfl

private def primitiveSig : PrimSig :=
  ⟨[],0,[],[],.pathBases,Eff.single processEnvironmentEff,(fun _ ts => ts = []),.pathBases,
    some processEnvironmentEff,[],.untargeted⟩
private def primitiveEffect : Eff := Eff.union (Eff.single processEnvironmentEff) (Eff.single stateEff)
private def primitiveClauses (σ : PathEnv) : List Clause :=
  [.mk (.prim "Example.pathBases") 0 0 (.ret (.pathBases σ))]

theorem primitive_pathBases {P B σ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hsig : B.sig "Example.pathBases" = some primitiveSig) (hσ : σ.Valid) :
    StateTyE P B σ primitiveEffect
      (.run (.mk Capture.empty (.app (.prim "Example.pathBases" [] [] []) []))
        [.handleF Capture.empty (primitiveClauses σ)] Store.empty) ∧
    Step P B σ
      (.run (.mk Capture.empty (.app (.prim "Example.pathBases" [] [] []) []))
        [.handleF Capture.empty (primitiveClauses σ)] Store.empty) none
      (.run (.mk Capture.empty (.issuePathBases "Example.pathBases"))
        [.handleF Capture.empty (primitiveClauses σ)] Store.empty) ∧
    StateTyE P B σ primitiveEffect
      (.run (.mk Capture.empty (.issuePathBases "Example.pathBases"))
        [.handleF Capture.empty (primitiveClauses σ)] Store.empty) ∧
    Step P B σ
      (.run (.mk Capture.empty (.issuePathBases "Example.pathBases"))
        [.handleF Capture.empty (primitiveClauses σ)] Store.empty)
      (some (.pathBases "Example.pathBases" σ))
      (.run (Closure.pure (.ret (.pathBases σ)))
        [.handleF Capture.empty (primitiveClauses σ)] Store.empty) ∧
    StateTyE P B σ primitiveEffect
      (.run (Closure.pure (.ret (.pathBases σ)))
        [.handleF Capture.empty (primitiveClauses σ)] Store.empty) := by
  have ha {C Γ} : Ty.Annotation P C Γ (.dependentFn (.done .pathBases (Eff.single processEnvironmentEff))) :=
    ⟨by simp [Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.single,Eff.Canonical,Eff.norm,Ty.normTys],by trivial,by trivial⟩
  have heq : instantiatedTel (Tel.instR [] primitiveSig.tel) [] [] = .done .pathBases (Eff.single processEnvironmentEff) := by
    rw [Tel.instR_eq_bind]
    simp [instantiatedTel,Tel.bind,Tel.rawBind,SubstEnv.rangesOnly,
      primitiveSig,PrimSig.tel,signatureTel,Ty.rawBind,Ty.norm,Tel.norm,typeEnvAt,
      Eff.rawBind,Eff.norm,Eff.single,Ty.normTys,rowFails,instAtoms_nil,substAtoms_nil]
  have hi : SignatureInstance P [] [] (Tel.instR [] primitiveSig.tel) [] [] [] := by
    refine ⟨?_,(by intro a ha; cases ha),⟨rfl,(by intro i a k ha; cases ha)⟩,
      (by intro e he; cases he),(by intro e he; cases he),?_⟩
    · exact ((hB.sig_scoped _ _ hsig).inst (rs := []) rfl).2.2.2.wf
    · rw [heq]; exact ha
  have hv : HasTypeVQ P B StoreTy.empty Qempty [] [] [] (.prim "Example.pathBases" [] [] [])
      (.dependentFn (instantiatedTel (Tel.instR [] primitiveSig.tel) [] [])) := by
    refine .V_Prim hsig ⟨rfl,(by intro i r k h; cases h),(by intro r h; cases h),Or.inl (by intro r h; cases h)⟩
      (by trivial) ?_ hi
    refine ⟨rfl,rfl,?_,rfl,?_,?_,?_,?_,?_⟩
    · intro t ht; cases ht
    · intro e he; cases he
    · simp [primitiveSig,Eff.RowsIn,Ty.RowsInList,Eff.single]
    · simp [primitiveSig,Qsig,QTys,QTy,QEff,Qempty,Eff.single]
    · simp [primitiveSig,RowTransport,Qsig,QTys,QTy,QEff,Qempty,Eff.single]
    · simp [primitiveSig,PrimSig.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,Eff.RowsIn,Ty.RowsInList,Eff.single]
  have ht : HasTypeTelArgsQ P B StoreTy.empty Qempty [] [] [] []
      (instantiatedTel (Tel.instR [] primitiveSig.tel) [] []) .pathBases (Eff.single processEnvironmentEff) := by
    rw [heq]; exact .done ha
  have hcode : HasTypeCQ P B StoreTy.empty Qempty [] [] [] none
      (.handle (.app (.prim "Example.pathBases" [] [] []) []) (primitiveClauses σ)) .pathBases primitiveEffect [] := by
    refine .C_Handle (.C_DependentApp hv ht) ⟨(fun a ha => (left_sub _ _).1 a ((left_sub _ _).1 a ha)),
        (fun t ht => (left_sub _ _).2 t ((left_sub _ _).2 t ht))⟩ ?_
    let sg : OpSig := ⟨[],[],[],.pathBases,processEnvironmentEff⟩
    refine .cons (sg := sg) (ClauseSig.of_opSig ?_ ?_) (by trivial) rfl rfl (by trivial) ?_ .nil
    · simp [opSig,opSigAt,hsig,primitiveSig,sg]
    · intro b s ho hs
      cases ho
      have hh := Option.some.inj (hs.symm.trans hsig)
      subst s
      simp [primitiveSig,PrimSig.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,Eff.RowsIn,Ty.RowsInList,Eff.single]
    · exact .C_Eff (.C_Return (.V_PathBases hσ)) (empty_sub _).covers
  have hh := (initial (σ := σ) hcode
    ⟨by simp [Ty.WF,Tel.WF,Ty.WFList,Eff.WF,primitiveEffect,Eff.union,Eff.single,Eff.norm,Eff.fails,Eff.Canonical,Ty.normTys],by trivial,by trivial⟩
    rfl (by simp [primitiveClauses,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Clause.ClosedList]) (by trivial)).handle_step hB rfl
  obtain ⟨hst,hi⟩ := hh.path_bases_apply_all hP hPB hB rfl hsig rfl
  exact ⟨hh,hst,hi,hi.issue_path_bases_all rfl hsig rfl rfl hσ⟩


/-! ## 表の条件を同時に満たす操作の例 -/

private def modelProgram : Program where
  defs := fun _ => none
  cons := fun _ => none
  ops := fun o => if o = "Example.identity" then some declaration else none
  effects := fun l => if l = "Example.effect" then some ["Example.identity"] else none
  classes := fun _ => none
  impls := fun _ => none

private def modelGet : PrimSig where
  tparams := [{}]
  neffs := 0
  names := ["reference"]
  params := [.reference (.tvar 0)]
  ret := .tvar 0
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refGet
  opEff := none

private def modelSet : PrimSig where
  tparams := [{}]
  neffs := 0
  names := ["reference", "value"]
  params := [.reference (.tvar 0), .tvar 0]
  ret := .base .unit
  eff := Eff.single stateEff
  admits := fun _ ts => ts.length = 1
  kind := .refSet
  opEff := none

private def modelBuiltins : Builtins where
  sig := fun b => if b = "Reference.get" then some modelGet
    else if b = "Reference.set" then some modelSet else none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ r => r = none
  isResource := fun _ => false
  effects := fun l => if l = stateEff then some [] else none
  sat := fun _ _ _ => True
  refGet := "Reference.get"
  refSet := "Reference.set"

private theorem model_sig_cases {b s} (h : modelBuiltins.sig b = some s) :
    s = modelGet ∨ s = modelSet := by
  simp only [modelBuiltins] at h
  split at h
  · cases h; exact Or.inl rfl
  · split at h
    · cases h; exact Or.inr rfl
    · cases h

private theorem model_external : modelProgram.ExternalWF := by
  constructor
  · simp [modelProgram]
  · intro key decl h; cases h

private theorem model_wellFormed : modelProgram.WellFormed where
  defs := by intro f d h; cases h
  cons := by intro c cd h; cases h
  ops := by
    intro o od h
    simp only [modelProgram] at h
    split at h
    · cases h
      refine ⟨by simp [declaration,NamesWF],(by intro p hp; cases hp),rfl,?_,?_,?_,?_⟩
      · simp [declaration,OpDecl.tel,signatureTel,Ty.SourceScoped,Ty.WF,Tel.WF,
          Ty.WFList,Ty.RowsIn,Tel.RowsIn,Eff.RowsIn,Ty.RowsInList,
          Ty.RangesScoped,Tel.RangesScoped,Eff.RangesScoped,rangesScopedTypes,
          RangeIx.WF,Eff.WF,Eff.Canonical,Eff.norm,Ty.normTys,TypeCtx.values]
        intro name ix hx
        cases ix with
        | fixed r => trivial
        | rvar i => cases hx
      · simp [declaration,OpDecl.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,Eff.RowsIn,Ty.RowsInList]
      · simp [declaration,OpDecl.tel,signatureTel,Ty.HasKind,kindsTel,kindsEff,kindsList,TypeCtx.kinds,TypeCtx.values]
      · constructor
        · simp [declaration,OpDecl.tel,signatureTel,Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.Canonical,Eff.norm,Ty.normTys,TypeCtx.values]
        · simp [declaration,OpDecl.tel,signatureTel,Ty.Sorted,Tel.Sorted,sortedEff,sortedTys]
        · simp [declaration,OpDecl.tel,signatureTel,Ty.Declared,Tel.Declared,declaredEff,declaredTys,TypeCtx.values]

    · cases h
  classes := by intro cl cd h; cases h
  impls := by intro i id h; cases h
  metadata := by intro d info h; cases h
  external := model_external

private theorem model_wellTyped : modelProgram.WellTyped modelBuiltins where
  variance := ⟨(by intro d info h; cases h),(by intro c cd h; cases h)⟩
  external := model_external
  defs := by intro f d h; cases h
  impls := by intro i id h; cases h

private theorem model_core : modelBuiltins.CoreAssumptions modelProgram where
  sat_rename := by intros; trivial
  sat_values := by intros; trivial
  sat_renameTypes := by intros; trivial
  sat_subst := by intros; trivial
  admits_rename := by
    intro b s C Γ Δ ts ξ hl _ _ _ ha
    rcases model_sig_cases hl with rfl | rfl <;> simpa [modelGet,modelSet] using ha
  admits_values := by
    intro b s Ψ Q C Γ Δ Ξ ν ts hl _ _ ha
    rcases model_sig_cases hl with rfl | rfl <;> simpa [modelGet,modelSet] using ha
  admits_renameTypes := by
    intro b s C C' Γ Δ ts ρ hl _ _ _ ha
    rcases model_sig_cases hl with rfl | rfl <;> simpa [modelGet,modelSet] using ha
  admits_subst := by
    intro b s C0 C1 ts ts' es' hl ha _ _ _
    rcases model_sig_cases hl with rfl | rfl <;> simpa [modelGet,modelSet] using ha
  external_typed := by intro Ψ f d ts vs a e out obs hw hd; cases hd
  external_exists := by intro Ψ f d ts vs a e hw hd; cases hd
  external_no_targets := by intro Ψ f d ts vs a e out obs hw hd; cases hd
  delta_typed := by
    intro Ψ b s ts es rs ws a e hl hk
    rcases model_sig_cases hl with rfl | rfl <;> cases hk
  io_typed := by intro Ψ b s ts es rs ws a e out obs hl hk ha hr; cases hr
  io_kind := by intro Ψ b s ts es rs ws a e out obs hl ha hr; cases hr
  io_exists := by
    intro Ψ b s ts es rs ws a e hl hk
    rcases model_sig_cases hl with rfl | rfl <;> rcases hk with hk | hk <;> cases hk
  sig_scoped := by
    intro b s hl
    rcases model_sig_cases hl with rfl | rfl <;>
      constructor <;>
      simp [modelGet,modelSet,PrimSig.tel,signatureTel,NamesWF,
        Ty.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,Ty.RowsInList,Ty.RowsIn,Tel.RowsIn,Eff.RowsIn,
        Ty.RangesScoped,Tel.RangesScoped,Eff.RangesScoped,rangesScopedTypes,
        Ty.HasKind,kindsTel,kindsEff,kindsList,RangeIx.WF,TypeCtx.kinds,
        Ty.Sorted,Tel.Sorted,sortedEff,sortedTys,Ty.Declared,Tel.Declared,declaredEff,declaredTys,
        Eff.WF,Eff.Canonical,Eff.norm,Eff.single,Ty.normTys]
  sat_unconstrained := by intros; trivial
  admits_sat := by
    intro b s C ts hl ha
    rcases model_sig_cases hl with rfl | rfl <;>
      exact ⟨by simpa [modelGet,modelSet,Ty.normTys_eq_map] using ha,by intros; trivial⟩
  release_exists := by intro Ψ v o hv hr; exact ⟨none,rfl⟩
  pathBases_shape := by
    intro b s hl hk
    rcases model_sig_cases hl with rfl | rfl <;> cases hk
  io_op := by
    intro b s hl hk
    rcases model_sig_cases hl with rfl | rfl <;> rcases hk with hk | hk <;> cases hk
  opEff_io := by
    intro b s l hl he
    rcases model_sig_cases hl with rfl | rfl <;> cases he
  effect_ops := by
    intro l bs b hl hb
    simp only [modelBuiltins] at hl
    split at hl
    · cases hl; cases hb
    · cases hl
  state_effect := by simp [modelBuiltins]
  ref_get := ⟨modelGet,by simp [modelBuiltins],rfl⟩
  ref_set := ⟨modelSet,by simp [modelBuiltins],rfl⟩
  store_shape := by
    intro b s hl hk
    rcases model_sig_cases hl with rfl | rfl <;>
      simp [PrimSig.StoreShape,modelGet,modelSet]
  store_admits := by
    intro b s C ts hl hp hi he hb ha
    rcases model_sig_cases hl with rfl | rfl <;> exact ha

/-- 表の条件を外部の仮定とせず、操作の三段階へ同じ具体の表を適用する。 -/
theorem row_concrete_model (σ : PathEnv) :
    StateTyE modelProgram modelBuiltins σ outputEffect opState ∧
    StateTyE modelProgram modelBuiltins σ outputEffect resumeState :=
  row_handle_operation_resume model_wellFormed model_wellTyped model_core (by simp [modelProgram])


end OperationStateExamples
end
end Benitoite.Release.Refinement
