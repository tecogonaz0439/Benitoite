import Benitoite.Release.Refinement.Surface.PredicateSimulationStructure
import Benitoite.Release.Refinement.Surface.CheckPreparation

/-! # 参照・継続・実装本体の実行の対応

同じ操作種別の署名と、継続・ストア・本体の対応から実際の両側の一段を構成する。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

variable {source : Program} {rows : PredicateProjection.Table.Rows}
variable {P Q : Refinement.Program} {B C : Builtins} {σ : PathEnv}

theorem enabled_reference_names {config : Check.BuiltinSource}
    (active : CheckPreparation.enabled config = true) :
    config.builtins.refGet = "Reference.get" ∧ config.builtins.refSet = "Reference.set" := by
  induction config with
  | custom _ | unrestrictedRanges _ => cases active
  | standard _ | predicates _ _ => exact ⟨rfl,rfl⟩
  | resolved base entries ih => exact ih (CheckPreparation.enabled_resolved_base active)

theorem enabled_references_avoid {config : Check.BuiltinSource} {keys : List PrimName}
    (active : CheckPreparation.enabled config = true)
    (prefixed : ∀ key ∈ keys, key.startsWith "%Predicate." = true) :
    config.builtins.refGet ∉ keys ∧ config.builtins.refSet ∉ keys := by
  obtain ⟨getName,setName⟩ := enabled_reference_names active
  rw [getName,setName]
  constructor
  · intro member
    have impossible := prefixed "Reference.get" member
    have absent : "Reference.get".startsWith "%Predicate." = false := by cbv
    rw [absent] at impossible
    cases impossible
  · intro member
    have impossible := prefixed "Reference.set" member
    have absent : "Reference.set".startsWith "%Predicate." = false := by cbv
    rw [absent] at impossible
    cases impossible

theorem StoreRel.fresh_right {μ ν location} (h : StoreRel source rows μ ν)
    (fresh : ν location = none) : μ location = none := by
  have related := h location
  rw [fresh] at related
  cases original : μ location with
  | none => rfl
  | some cell => rw [original] at related; cases related

theorem StoreRel.lookup_right {μ ν location cell} (h : StoreRel source rows μ ν)
    (found : ν location = some cell) :
    ∃ original, μ location = some original ∧ CellRel source rows original cell := by
  have related := h location
  rw [found] at related
  cases original : μ location with
  | none => rw [original] at related; cases related
  | some cell =>
    rw [original] at related
    cases related with
    | some cells => exact ⟨_,rfl,cells⟩

theorem structural_issue_path_bases {cap' name signature k l μ ν}
    (rightSig : C.sig name = some signature)
    (kind : signature.kind = .pathBases) (effect : signature.opEff = some processEnvironmentEff)
    (valid : σ.Valid) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    ∃ next, Step Q C σ (.run (.mk cap' (.issuePathBases name)) l ν) (some (.pathBases name σ)) next ∧
      StateRel source rows (.run (Closure.pure (.ret (.pathBases σ))) k μ) next :=
  ⟨_,.E_IssuePathBases rfl rightSig kind effect valid,
    .run (.pure (.ret (.pathBases σ))) hk hμ⟩

theorem structural_fail_operation {q r input target ty raised errorTy k l μ ν beforeFrames hcap body rest location}
    (first : q.view = .app (.raise ty raised) [input])
    (second : r.view = .app (.raise ty raised) [target])
    (value : Value source rows input target) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (split : SplitAt .fail k beforeFrames hcap [.fail errorTy body] rest) (fresh : μ location = none) :
    SynchronizedAt source rows P Q B C σ (.run q k μ) (.run r l ν) (.E_OpFail first split fresh) := by
  obtain ⟨before,targetCap,targetClauses,after,targetSplit,hbefore,hcapRel,clausesRel,hafter⟩ := hk.splitAt split
  cases clausesRel with
  | fail code tail =>
    cases tail
    exact ⟨_,.E_OpFail second targetSplit (hμ.fresh fresh),
      .run (.mk (hcapRel.extendMany (.cons value (.cons (.location location) .nil))) (code.substTy 0 [ty] []))
        (.cons (.drop location) hafter)
        (hμ.set (.cont (hbefore.append (.cons (.handleF hcapRel (.fail code .nil)) .nil))))⟩

theorem structural_reference_new {q r name ts es rs v w k l μ ν signature location}
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) [v])
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) [w])
    (leftSig : B.sig name = some signature) (rightSig : C.sig name = some signature) (kind : signature.kind = .refNew)
    (hv : Value source rows v w) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) (fresh : μ location = none) :
    SynchronizedAt source rows P Q B C σ (.run q k μ) (.run r l ν) (.E_RefNew first leftSig kind fresh) :=
  ⟨_,.E_RefNew second rightSig kind (hμ.fresh fresh),
    .run (.pure (.ret (.location location))) hk (hμ.set (.value hv))⟩

theorem structural_reference_get {q r name ts es rs k l μ ν signature location value}
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) [.loc location])
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) [.loc location])
    (leftSig : B.sig name = some signature) (rightSig : C.sig name = some signature) (kind : signature.kind = .refGet)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) (found : μ location = some (.val value)) :
    SynchronizedAt source rows P Q B C σ (.run q k μ) (.run r l ν) (.E_RefGet first leftSig kind found) := by
  obtain ⟨target,targetFound,hvalue⟩ := hμ.value found
  exact ⟨_,.E_RefGet second rightSig kind targetFound,
    .run (.pure (.ret hvalue)) hk hμ⟩

theorem structural_reference_set {q r name ts es rs v w k l μ ν signature location}
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) [.loc location,v])
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) [.loc location,w])
    (leftSig : B.sig name = some signature) (rightSig : C.sig name = some signature) (kind : signature.kind = .refSet)
    (hv : Value source rows v w) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.run q k μ) (.run r l ν) (.E_RefSet first leftSig kind) :=
  ⟨_,.E_RefSet second rightSig kind,
    .run (.pure (.ret (.constant .unit))) hk (hμ.set (.value hv))⟩

theorem structural_reference_update {q r name ts es rs f g k l μ ν signature location}
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) [.loc location,f])
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) [.loc location,g])
    (leftSig : B.sig name = some signature) (rightSig : C.sig name = some signature) (kind : signature.kind = .refUpdate)
    (getSame : B.refGet = C.refGet) (setSame : B.refSet = C.refSet)
    (hf : Value source rows f g) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.run q k μ) (.run r l ν) (.E_RefUpdate first leftSig kind) := by
  refine ⟨_,.E_RefUpdate second rightSig kind,.run (.pure ?_) hk hμ⟩
  rw [getSame,setSame]
  exact .letIn (.app (.primitive _ _ _ _) (.cons (.location _) .nil))
    (.letIn (.app (hf.rename (· + 1)) (.cons (.var 0) .nil))
      (.app (.primitive _ _ _ _) (.cons (.location _) (.cons (.var 0) .nil))))

theorem structural_force_done {q r name ts es rs k l μ ν signature location value}
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) [.loc location])
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) [.loc location])
    (leftSig : B.sig name = some signature) (rightSig : C.sig name = some signature) (kind : signature.kind = .force)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) (found : μ location = some (.done value)) :
    SynchronizedAt source rows P Q B C σ (.run q k μ) (.run r l ν) (.E_ForceDone first leftSig kind found) := by
  obtain ⟨cell,targetFound,related⟩ := hμ.lookup found
  cases related with
  | done hv => exact ⟨_,.E_ForceDone second rightSig kind targetFound,
      .run (.pure (.ret hv)) hk hμ⟩

theorem structural_force_thunk {q r name ts es rs k l μ ν signature location body}
    (first : q.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) [.loc location])
    (second : r.view = .app (.prim name ts es (List.map RangeIx.fixed rs)) [.loc location])
    (leftSig : B.sig name = some signature) (rightSig : C.sig name = some signature) (kind : signature.kind = .force)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) (found : μ location = some (.thunk body)) :
    SynchronizedAt source rows P Q B C σ (.run q k μ) (.run r l ν) (.E_Force first leftSig kind found) := by
  obtain ⟨cell,targetFound,related⟩ := hμ.lookup found
  cases related with
  | thunk hb => exact ⟨_,.E_Force second rightSig kind targetFound,
      .run hb (.cons (.update location) hk) hμ⟩

theorem structural_guard_true {q r v w cap cap' arms targets next body targetBody k l μ ν}
    (first : q.view = .ret (.const (.boolean true))) (second : r.view = .ret (.const (.boolean true)))
    (bodyRel : ClosedCode source rows body targetBody) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.run q (.guardF v cap arms next body :: k) μ)
      (.run r (.guardF w cap' targets next targetBody :: l) ν) (.E_GuardT first) :=
  ⟨_,.E_GuardT second,.run bodyRel hk hμ⟩

theorem structural_guard_false {q r v w cap cap' arms targets next body targetBody k l μ ν}
    (first : q.view = .ret (.const (.boolean false))) (second : r.view = .ret (.const (.boolean false)))
    (hv : Value source rows v w) (hc : Captures source rows cap cap') (ha : Arms source rows arms targets)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.run q (.guardF v cap arms next body :: k) μ)
      (.run r (.guardF w cap' targets next targetBody :: l) ν) (.E_GuardF first) :=
  ⟨_,.E_GuardF second,.matchRun hv hc ha hk hμ⟩

theorem structural_escape_let {q r v w body targetBody k l μ ν}
    (first : q.view = .escape v) (second : r.view = .escape w)
    (hv : Value source rows v w) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.run q (.letF body :: k) μ) (.run r (.letF targetBody :: l) ν) (.E_EscLet first) :=
  ⟨_,.E_EscLet second,.run (.pure (.escape hv)) hk hμ⟩

theorem structural_escape_handle {q r v w cap cap' clauses targets k l μ ν}
    (first : q.view = .escape v) (second : r.view = .escape w)
    (hv : Value source rows v w) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.run q (.handleF cap clauses :: k) μ) (.run r (.handleF cap' targets :: l) ν) (.E_EscHandle first) :=
  ⟨_,.E_EscHandle second,.run (.pure (.escape hv)) hk hμ⟩

theorem structural_escape_mark {q r v w k l μ ν}
    (first : q.view = .escape v) (second : r.view = .escape w)
    (hv : Value source rows v w) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.run q (.mark :: k) μ) (.run r (.mark :: l) ν) (.E_EscMark first) :=
  ⟨_,.E_EscMark second,.run (.pure (.ret hv)) hk hμ⟩

theorem structural_escape_drop_used {q r v w location k l μ ν}
    (first : q.view = .escape v) (second : r.view = .escape w) (found : μ location = some .used)
    (hv : Value source rows v w) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.run q (.drop location :: k) μ) (.run r (.drop location :: l) ν) (.E_EscDrop first found) := by
  obtain ⟨cell,targetFound,related⟩ := hμ.lookup found
  cases related with
  | used => exact ⟨_,.E_EscDrop second targetFound,.run (.pure (.escape hv)) hk hμ⟩

theorem structural_escape_drop_continuation {q r v w location saved k l μ ν}
    (first : q.view = .escape v) (second : r.view = .escape w) (found : μ location = some (.cont saved))
    (hv : Value source rows v w) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.run q (.drop location :: k) μ) (.run r (.drop location :: l) ν) (.E_EscDropRel first found) := by
  obtain ⟨cell,targetFound,related⟩ := hμ.lookup found
  cases related with
  | cont hsaved => exact ⟨_,.E_EscDropRel second targetFound,
      .run (.pure (.escape hv)) (hsaved.releases.append hk) (hμ.set .used)⟩

theorem structural_error_drop_used {errors location k l μ ν} (found : μ location = some .used)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.error errors (.drop location :: k) μ) (.error errors (.drop location :: l) ν) (.E_ErrDrop found) := by
  obtain ⟨cell,targetFound,related⟩ := hμ.lookup found
  cases related with
  | used => exact ⟨_,.E_ErrDrop targetFound,.error hk hμ⟩

theorem structural_error_drop_continuation {errors location saved k l μ ν} (found : μ location = some (.cont saved))
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.error errors (.drop location :: k) μ) (.error errors (.drop location :: l) ν) (.E_ErrDropRel found) := by
  obtain ⟨cell,targetFound,related⟩ := hμ.lookup found
  cases related with
  | cont hsaved => exact ⟨_,.E_ErrDropRel targetFound,
      .error (hsaved.releases.append hk) (hμ.set .used)⟩

theorem structural_exit_drop_used {code errors location k l μ ν} (found : μ location = some .used)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.exit code errors (.drop location :: k) μ) (.exit code errors (.drop location :: l) ν) (.E_ExitDrop found) := by
  obtain ⟨cell,targetFound,related⟩ := hμ.lookup found
  cases related with
  | used => exact ⟨_,.E_ExitDrop targetFound,.exit hk hμ⟩

theorem structural_exit_drop_continuation {code errors location saved k l μ ν} (found : μ location = some (.cont saved))
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.exit code errors (.drop location :: k) μ) (.exit code errors (.drop location :: l) ν) (.E_ExitDropRel found) := by
  obtain ⟨cell,targetFound,related⟩ := hμ.lookup found
  cases related with
  | cont hsaved => exact ⟨_,.E_ExitDropRel targetFound,
      .exit (hsaved.releases.append hk) (hμ.set .used)⟩

private theorem related_some {α β} {R : α → β → Prop} {a : α} {result : Option β}
    (h : Option.Rel R (some a) result) : ∃ b, result = some b ∧ R a b := by
  cases h with
  | some related => exact ⟨_,rfl,related⟩

private theorem related_none {α β} {R : α → β → Prop} {result : Option β}
    (h : Option.Rel R none result) : result = none := by cases h; rfl

private theorem option_values_map {a b f g} (related : Option.Rel (Value source rows) a b)
    (maps : ∀ v w, Value source rows v w → Value source rows (f v) (g w)) :
    Option.Rel (Value source rows) (a.map f) (b.map g) := by
  cases related with
  | none => exact .none
  | some value => exact .some (maps _ _ value)

/-- 上位辞書の取り出しも、実装の対応する本体と捕捉する辞書引数を読む。 -/
theorem ProgramRel.superStep {v w} (program : ProgramRel source rows P Q) (related : Value source rows v w) :
    Option.Rel (Value source rows) (v.superStep P) (w.superStep Q) := by
  cases related with
  | super inner => cases inner with
    | @dictionary name types values targets arguments =>
      have declarations := program.implementations name
      cases found : P.impls name with
      | none =>
        rw [found] at declarations
        have targetFound := related_none declarations
        simp only [Val.superStep,found,targetFound]
        exact .none
      | some implementation =>
        rw [found] at declarations
        obtain ⟨targetImplementation,targetFound,implRel⟩ := related_some declarations
        simp only [Val.superStep,found,targetFound]
        apply option_values_map (implRel.supers _)
        intro v w hv
        exact (hv.substTy 0 types []).close ((Captures.mk Slots.nil).extendMany arguments)
    | super inner =>
      exact option_values_map (program.superStep (Value.super inner)) (fun _ _ hv => Value.super hv)
    | _ => exact .none
  | _ => exact .none
termination_by sizeOf v

theorem structural_super {q r v w method types effects values targets result k l μ ν}
    (program : ProgramRel source rows P Q)
    (first : q.view = .meth v method types effects values) (second : r.view = .meth w method types effects targets)
    (receiver : Value source rows v w) (arguments : Values source rows values targets)
    (found : v.superStep P = some result) (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.run q k μ) (.run r l ν) (.E_Super first found) := by
  have outputs := program.superStep receiver
  rw [found] at outputs
  obtain ⟨target,targetFound,value⟩ := related_some outputs
  exact ⟨_,.E_Super second targetFound,.run (.pure (.method value arguments)) hk hμ⟩

theorem structural_method {q r name types dictionaries targetDictionaries method methodTypes effects arguments targetArguments
    implementation body classDecl methodDecl k l μ ν}
    (program : ProgramRel source rows P Q)
    (first : q.view = .meth (.dict name types dictionaries) method methodTypes effects arguments)
    (second : r.view = .meth (.dict name types targetDictionaries) method methodTypes effects targetArguments)
    (found : P.impls name = some implementation) (methodFound : implementation.methods method = some body)
    (classFound : P.classes implementation.cls = some classDecl) (methodSignature : classDecl.methods method = some methodDecl)
    (argumentsCount : arguments.length = methodDecl.params.length) (dictionariesCount : dictionaries.length = implementation.dictTys.length)
    (typesCount : types.length = implementation.tparams.length) (methodTypesCount : methodTypes.length = methodDecl.tparams.length)
    (effectsCount : effects.length = methodDecl.neffs)
    (dictionariesRel : Values source rows dictionaries targetDictionaries) (argumentsRel : Values source rows arguments targetArguments)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    SynchronizedAt source rows P Q B C σ (.run q k μ) (.run r l ν)
      (.E_Meth first found methodFound classFound methodSignature argumentsCount dictionariesCount typesCount methodTypesCount effectsCount) := by
  have declarations := program.implementations name
  rw [found] at declarations
  obtain ⟨targetImplementation,targetFound,implRel⟩ := related_some declarations
  have methods := implRel.methods method
  rw [methodFound] at methods
  obtain ⟨targetBody,targetMethod,methodRel⟩ := related_some methods
  have targetClass : Q.classes targetImplementation.cls = some classDecl := by
    rw [← implRel.className,← program.types.classes]
    exact classFound
  have dictionaryTypes : implementation.dictTys = targetImplementation.dictTys := by
    simp only [ImplDecl.dictTys,implRel.dictionaries]
  refine ⟨_,.E_Meth second targetFound targetMethod targetClass methodSignature ?_ ?_ ?_ methodTypesCount effectsCount,?_⟩
  · exact argumentsRel.length ▸ argumentsCount
  · exact dictionariesRel.length ▸ dictionaryTypes ▸ dictionariesCount
  · exact implRel.tparams ▸ typesCount
  · exact .run (.mk ((Captures.mk Slots.nil).extendMany (dictionariesRel.append argumentsRel))
      (methodRel.substTy 0 (methodTypes ++ types) effects)) hk.markPush hμ

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
