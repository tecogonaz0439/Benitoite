import Benitoite.Release.Refinement.StandardModelApplication
import Benitoite.Release.Refinement.StandardModelConditionInputs
import Benitoite.Release.Refinement.Surface.PredicateCalls
import Benitoite.Release.Refinement.Surface.CheckPreparation
import Benitoite.Release.Refinement.Surface.CheckPredicateProgramExamples
import Benitoite.Release.Refinement.SafeCheckObservations

/-! 公開判定の実際の名前解決が閉包の構文を変える境界の独立した確認用入力。
完成した表の契約は、閉包の構文を読む仮定側の応答を禁じていない。
この入力は閉包を渡す核の文脈の反例であり、実入口が受理した main 全体の反例ではない。 -/
namespace Benitoite.Release.Refinement.PredicateResolutionBoundary
open StandardModel
open _root_.Benitoite.Release.Refinement.Surface PredicateRows PredicateResponse
noncomputable section

def probeName : PrimName := "IOError.message"

def probeSig : PrimSig where
  tparams := []
  neffs := 0
  names := ["function"]
  params := [.fn ["x"] [.base .float] (.base .unit) Eff.empty]
  ret := .base .unit
  eff := Eff.empty
  admits := fun _ ts => ts.length = 0
  kind := .pure
  opEff := none

def probeReply : List Val → ErrKind
  | [.closure _ (.mk _ (.letIn (.letIn _ _) _))] => "Before"
  | _ => "After"

def assumed : AssumedTable where
  sig := fun b => if b = probeName then some probeSig else none
  delta := fun _ _ _ _ ws => some (.err (probeReply ws))
  ioResponse := fun _ _ _ _ _ _ => False
  isResource := fun _ => false
  releaseResponse := fun _ _ => False
  effKind := fun _ => none

theorem probe_mem : probeName ∈ nameLists.assumed := by
  simp [probeName,NameLists.assumed,nameLists,deltaNames]

theorem probe_not_composed : probeName ∉ nameLists.composed :=
  fun h => nameLists_wf.disjoint _ h probe_mem

theorem probe_lookup {P} (T : DataTable P) :
    (complete nameLists T assumed).sig probeName = some probeSig := by
  simp [complete,completeBase,ExternalModel.builtins,probe_not_composed,probe_mem,assumed]

theorem assumed_lookup {P} (T : DataTable P) {b s}
    (hb : b ∈ nameLists.assumed) (hs : (complete nameLists T assumed).sig b = some s) :
    b = probeName ∧ s = probeSig := by
  have hn : b ∉ nameLists.composed := fun h => nameLists_wf.disjoint _ h hb
  simp only [complete,ExternalModel.builtins,completeBase,ite_eq_right hn,ite_eq_left hb,assumed] at hs
  split at hs
  · next he => exact ⟨he,(Option.some.inj hs).symm⟩
  · cases hs

theorem probe_scoped (P : Program) : probeSig.Scoped P := by
  constructor <;>
    simp [probeSig,PrimSig.tel,signatureTel,NamesWF,
      Ty.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,Ty.RowsInList,Ty.RowsIn,Tel.RowsIn,Eff.RowsIn,
      Ty.RangesScoped,Tel.RangesScoped,Eff.RangesScoped,rangesScopedTypes,
      Ty.HasKind,kindsTel,kindsEff,kindsList,RangeIx.WF,TypeCtx.kinds,
      Ty.Sorted,Tel.Sorted,sortedEff,sortedTys,Ty.Declared,Tel.Declared,declaredEff,declaredTys,
      Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,Ty.normTys]

theorem completion {P} (T : DataTable P) : Completion nameLists T assumed := by
  refine ⟨?_,?_,?_,?_,?_,?_,?_,?_,?_⟩
  · intro b h
    simp only [assumed] at h
    split at h
    · next he => exact he ▸ probe_mem
    · cases h
  · intro b s hs _
    simp only [assumed] at hs
    split at hs
    · cases hs; rfl
    · cases hs
  · intro b s hs hb
    have he : b = probeName := by
      simp only [assumed] at hs
      split at hs
      · assumption
      · cases hs
    subst b
    rcases hb with hb | hb <;> simp [probeName,nameLists,ioNames,stateNames] at hb
  · constructor
    · intro b s C Γ Δ ts ξ hb hs _ _ _ ha
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      simpa [probeSig] using ha
    · intro b s Ψ Q C Γ Δ Ξ ν ts hb hs _ _ ha
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      simpa [probeSig] using ha
    · intro b s C C' Γ Δ ts ρ hb hs _ _ _ ha
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      simpa [probeSig] using ha
    · intro b s C0 C1 ts ts' es' hb hs ha _ _ _
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      simpa [probeSig] using ha
    · intro Ψ b s ts es rs ws a e hb hs _ _
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      exact ⟨.err (probeReply ws),by simp [complete,completeBase,ExternalModel.builtins,
        probe_not_composed,assumed],(by intro n h; cases h),trivial,(by simp [AdequateResult,Outcome.Adequate])⟩
    · intro Ψ b s ts es rs ws a e out obs hb hs _ _ hr
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      simp [complete,completeBase,ExternalModel.builtins,probe_not_composed,assumed] at hr
    · intro Ψ b s ts es rs ws a e out obs hb hs _ hr
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      simp [complete,completeBase,ExternalModel.builtins,probe_not_composed,assumed] at hr
    · intro Ψ b s ts es rs ws a e hb hs hk
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      rcases hk with hk | hk <;> cases hk
    · intro b s hb hs
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      exact probe_scoped P
    · intro b s C ts hb hs ha
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      exact ⟨by simpa [probeSig,Ty.normTys_eq_map] using ha,by intros; trivial⟩
    · intro b s hb hs hk
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      cases hk
    · intro b s hb hs hk
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      rcases hk with hk | hk <;> cases hk
    · intro b s l hb hs he
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      cases he
    · intro b s hb hs _
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      simp [PrimSig.StoreShape,probeSig]
    · intro b s C ts hb hs hp _ _ _ _
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      exact (hp rfl).elim
    · intro Ψ b s ts es rs ws a e out obs hb hs _ _ hr
      obtain ⟨rfl,rfl⟩ := assumed_lookup T hb hs
      simp [complete,completeBase,ExternalModel.builtins,probe_not_composed,assumed] at hr
  · intro Ψ v o ho _ hr
    change (if o ∈ nameLists.resources then false else T.base.isResource o) = true at hr
    simp [ho] at hr
  · intro o h; cases h
  · intros; rfl
  · intro b s hs
    simp only [assumed] at hs
    split at hs
    · cases hs; simp [probeSig]
    · cases hs
  · intro Ψ v o r _ _ h; exact h.elim

def rows : List (PrimName × Entry) := [("%Predicate.0", .floating .binary64 .finite)]
def op : OpPrim := fun _ _ => none

def publicCall : Expr :=
  .call (.primName "Float.isFinite" [] [] []) [none] [0]
    (.cons (.local 0) .nil)

def source : Block := .last (.lam ["x"] [.base .float] (.base .unit) Eff.empty (.lastDiscard publicCall))
def resolved : Block := PredicateCalls.resolveBlock rows source

def before : Comp := desugarBlock op .tail source
def after : Comp := desugarBlock op .tail resolved

def beforeArg : Val := .lam ["x"] [.base .float]
  (.letIn (.letIn (.ret (.var 0))
    (.app (.prim "Float.isFinite" [] [] []) [.var 0])) (.ret (.const .unit)))
def afterArg : Val := .lam ["x"] [.base .float]
  (.letIn (.app (.prim "%Predicate.0" [] [] []) [.var 0])
    (.ret (.const .unit)))

theorem source_desugars : before = .ret beforeArg := by rfl

theorem resolved_desugars : after = .ret afterArg := by rfl

def context (arg : Val) : Comp := .app (.prim probeName [] [] []) [arg]

theorem guarantees (externals : List (ExternalKey × ExternalDecl))
    (hw : (program externals).ExternalWF) (σ : PathEnv) :
    ProgramGuarantees (program externals) (complete nameLists (dataTable externals) assumed) σ :=
  included_guarantees nameLists_wf (dataTable externals) (Includes.refl externals)
    (completion _) hw (additions_refl externals hw _) σ

theorem different_payloads {P} (T : DataTable P) (σ : PathEnv) :
    Step P (complete nameLists T assumed) σ (.run (.pure (context beforeArg)) [] Store.empty) none
      (.error ["Before"] [] Store.empty) ∧
    Step P (complete nameLists T assumed) σ (.run (.pure (context afterArg)) [] Store.empty) none
      (.error ["After"] [] Store.empty) := by
  constructor
  · exact .E_Err (b := probeName) (ts := []) (es := []) (rs := []) (s := probeSig)
      rfl (probe_lookup T) rfl (by simp [complete,completeBase,ExternalModel.builtins,
        probe_not_composed,assumed,context,beforeArg,probeReply,closeVals,closeVal,Closure.pure])
  · exact .E_Err (b := probeName) (ts := []) (es := []) (rs := []) (s := probeSig)
      rfl (probe_lookup T) rfl (by simp [complete,completeBase,ExternalModel.builtins,
        probe_not_composed,assumed,context,afterArg,probeReply,closeVals,closeVal,Closure.pure])

theorem error_step_unique {P B σ q μ ws r label dest}
    (hq : q.view = .app (.prim probeName [] [] []) ws)
    (hs : B.sig probeName = some probeSig)
    (hd : B.delta probeName [] [] [] ws = some (.err r))
    (h : Step P B σ (.run q [] μ) label dest) :
    label = none ∧ dest = .error [r] [] μ := by
  cases h <;> simp_all [probeSig,closeVal]
  all_goals subst_vars
  all_goals simp_all [Closure.view]

theorem error_steps {P B σ rs μ events z}
    (h : Steps P B σ (.error rs [] μ) events z) :
    events = [] ∧ z = .error rs [] μ := by
  cases h with
  | nil => exact ⟨rfl,rfl⟩
  | cons first _ => cases first

theorem after_cannot_return_before {P} (T : DataTable P) (σ : PathEnv) (events : List Event) :
    ¬ Steps P (complete nameLists T assumed) σ (.run (.pure (context afterArg)) [] Store.empty)
      events (.error ["Before"] [] Store.empty) := by
  intro run
  cases run with
  | cons first rest =>
    have hq : (Closure.pure (context afterArg)).view =
        .app (.prim probeName [] [] []) (closeVals Capture.empty [afterArg]) := rfl
    have hd : (complete nameLists T assumed).delta probeName [] [] []
        (closeVals Capture.empty [afterArg]) = some (.err "After") := by
      simp [complete,completeBase,ExternalModel.builtins,probe_not_composed,assumed,
        afterArg,probeReply,closeVals,closeVal]
    obtain ⟨rfl,rfl⟩ := error_step_unique hq (probe_lookup T) hd first
    have h := (error_steps rest).2
    simp at h

/-- 実際のラムダの名前解決で得た値を、同じ完成した表の応答が区別する。 -/
theorem counterexample (externals : List (ExternalKey × ExternalDecl))
    (hw : (program externals).ExternalWF) (σ : PathEnv) :
    let P := program externals
    let T := dataTable externals
    let B := complete nameLists T assumed
    ProgramGuarantees P B σ ∧
    before = .ret beforeArg ∧ after = .ret afterArg ∧
    Steps P B σ (.run (.pure (context beforeArg)) [] Store.empty) [] (.error ["Before"] [] Store.empty) ∧
    Steps P B σ (.run (.pure (context afterArg)) [] Store.empty) [] (.error ["After"] [] Store.empty) ∧
    ¬ Steps P B σ (.run (.pure (context afterArg)) [] Store.empty) [] (.error ["Before"] [] Store.empty) := by
  have hs := different_payloads (dataTable externals) σ
  exact ⟨guarantees externals hw σ,source_desugars,resolved_desugars,
    Steps.cons hs.1 .nil,Steps.cons hs.2 .nil,after_cannot_return_before _ σ []⟩

example (σ : PathEnv) := counterexample positiveExternals positive_wf σ

/-! 以下は仮定側の応答を使わない、正常値の厳密な観測の境界である。
SafeCheckErasure.terminal の .value は Val そのものを持つ。この正常値の部分だけを
ここで抽出し、末尾の補題で同じ terminal の正常観測と対応させる。
型付きmainの受理や、非関数の正常値まで変わることは主張しない。 -/

def returned : State → Option Val
  | .run q [] _ => match q.view with | .ret v => some v | _ => none
  | _ => none

def originalValue : Val := closeVal Capture.empty beforeArg
def resolvedValue : Val := closeVal Capture.empty afterArg

theorem values_differ : originalValue ≠ resolvedValue := by
  intro h
  cases h

theorem return_steps {P B σ q v μ events z}
    (hq : q.view = .ret v)
    (steps : Steps P B σ (.run q [] μ) events z) :
    events = [] ∧ z = .run q [] μ := by
  cases steps with
  | nil => exact ⟨rfl,rfl⟩
  | cons first rest =>
    cases first <;> simp_all
    all_goals simp_all [Closure.view]

/-- 本体を実行しなくても、名前解決の前後で返す閉包の厳密な値は異なる。 -/
theorem normal_values (P : Refinement.Program) (B : Builtins) (σ : PathEnv) :
    let start := State.run (Closure.pure before) [] Store.empty
    let finish := State.run (Closure.pure after) [] Store.empty
    start.Final ∧ finish.Final ∧
    returned start = some originalValue ∧ returned finish = some resolvedValue ∧
    Steps P B σ start [] start ∧ Steps P B σ finish [] finish ∧
    ∀ events z, Steps P B σ finish events z → returned z ≠ some originalValue := by
  dsimp only
  refine ⟨⟨originalValue,?_⟩,⟨resolvedValue,?_⟩,?_,?_,.nil,.nil,?_⟩
  · rw [source_desugars]; rfl
  · rw [resolved_desugars]; rfl
  · rw [show Closure.pure before = Closure.pure (.ret beforeArg) from congrArg Closure.pure source_desugars]
    rfl
  · rw [show Closure.pure after = Closure.pure (.ret afterArg) from congrArg Closure.pure resolved_desugars]
    rfl
  · intro events z hs
    have view : (Closure.pure after).view = .ret resolvedValue := by rw [resolved_desugars]; rfl
    obtain ⟨rfl,rfl⟩ := return_steps view hs
    change some resolvedValue ≠ some originalValue
    intro he
    exact values_differ (Option.some.inj he).symm

/-- 返す値が関数である単一定義。CLI の main の結果の制約は満たさない。 -/
def lambdaDefinition : Surface.Def where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .fn ["x"] [.base .float] (.base .unit) Eff.empty
  eff := Eff.empty
  body := source

def surfaceProgram : Surface.Program where
  defs := fun name => if name = "factory" then some lambdaDefinition else none
  cons := fun _ => none

def checkInput : Check.Input where
  D := surfaceProgram.declarations
  builtinSource := .standard surfaceProgram.declarations.core
  opPrim := op
  formation := { atoms := PredicateStandardSupport.atoms, ctors := fun _ => [] }
  proofSteps := 200
  defs := ["factory"]

/-- 手で渡した行だけでなく、実入口の収集・登録・解決でも同じ閉包になる。 -/
theorem actual_preparation :
    ((CheckPreparation.prepare checkInput surfaceProgram).program.defs "factory").map
      (fun definition => desugarBlock op .tail definition.body) = some after := by cbv

/-- 公開ソースの通常の脱糖は、実入口の準備前には元の閉包を返す。 -/
theorem original_definition :
    (surfaceProgram.defs "factory").map (fun definition => desugarBlock op .tail definition.body) =
      some before := by rfl

theorem input_sound : checkInput.Sound := by
  refine ⟨⟨?_, ?_⟩, ⟨⟨?_⟩, ?_, ?_, ?_, ?_, ?_⟩, ?_, ?_, ?_, ?_⟩
  · intro c cd h; cases h
  · intro c cd h; cases h
  · intro i d h; cases h
  · intro name d found
    by_cases hn : name = "factory"
    · subst name
      have same : d = lambdaDefinition.toFunDecl := by
        simpa only [checkInput, surfaceProgram, Program.declarations, Program.declarationsFor,
          Program.lookupFun, ite_true, Option.some.injEq] using found.symm
      subst d
      simp [CheckArguments.SignatureSupport, lambdaDefinition, FunDecl.coreParams, FunDecl.dictTys,
        FunDecl.tel, FunDecl.coreNames, internalNames, signatureTel, Ty.Support, Ty.SupportList,
        Tel.Support, Eff.Support, Eff.empty]
    · have missing : checkInput.D.funs name = none := by
        simp only [checkInput, surfaceProgram, Program.declarations, Program.declarationsFor,
          Program.lookupFun, hn, ite_false]
      rw [missing] at found
      cases found
  · intro name signature found
    obtain ⟨row, _, _, rfl⟩ := (StandardModel.builtins_lookup_iff _ _ _).mp found
    exact PredicateStandardSupport.signature row
  · intro o d found; cases found
  · intro c cd m ms found; cases found
  · intro f d found; cases found
  · intro C a p accepted; cases accepted
  · intro name signature C types found accepted; cases accepted
  · intro name ranges accepted; cases accepted
  · intro operator type name types found; cases found

def preparedInput : Check.Input := (CheckPreparation.prepare checkInput surfaceProgram).input

theorem prepared_input_sound : preparedInput.Sound := CheckPreparation.prepare_sound input_sound _

def preparedRows : PredicateProjection.Table.Rows :=
  [("%Predicate.0", .scalar (.floating .binary64 .finite))]

theorem actual_prepared : CheckPreparation.prepare checkInput surfaceProgram =
    ⟨CheckPreparation.input checkInput preparedRows,
      CheckPreparation.resolveProgram preparedRows surfaceProgram⟩ := by cbv

def resolvedDefinition : Surface.Def := { lambdaDefinition with body := resolved }

theorem actual_definitions (name : FunName) :
    (CheckPreparation.prepare checkInput surfaceProgram).program.defs name =
      if name = "factory" then some resolvedDefinition else none := by
  rw [actual_prepared]
  by_cases hn : name = "factory"
  · subst name
    cbv
  · simp only [CheckPreparation.resolveProgram, surfaceProgram, hn, ite_false, Option.map_none]

def acceptedInput : CheckAccept.AcceptInput where
  ok := "Ok"
  rules := fun _ => none
  limits := ⟨⟨100,100⟩,⟨100,100⟩⟩
  methodKey := fun i m => i ++ "." ++ m

attribute [local cbv_opaque] StandardModel.builtins

theorem actual_acceptance :
    CheckAccept.checkProgramAccepted checkInput acceptedInput surfaceProgram = .ok () := by
  cbv

theorem source_names : CheckTables.NamesComplete checkInput surfaceProgram := by
  refine ⟨?_,?_,?_,?_,?_,?_⟩
  · intro name d found
    change (if name = "factory" then some lambdaDefinition else none) = some d at found
    split at found
    · simp [checkInput, ‹name = "factory"›]
    · cases found
  · intro name id found; cases found
  · intro name operations found; cases found
  · intro name operation found; cases found
  · intro name info found; cases found
  · intro name constructor found; cases found

theorem resolved_syntax : resolved = .last (.lam ["x"] [.base .float] (.base .unit) Eff.empty
    (.lastDiscard (.partialCall (.primName "%Predicate.0" [] [] []) [] (.expr none 0 (.local 0) .nil)
      ((Entry.floating .binary64 .finite).result (.var 1)) Eff.empty))) := by rfl

theorem prepared_typed : CheckTables.CheckedUnder
    (CheckPreparation.prepare checkInput surfaceProgram).program preparedInput := by
  apply CheckTables.checkProgram_sound (q := checkInput) (p := surfaceProgram)
    prepared_input_sound (CheckTables.prepare_names source_names) ?_ ?_ ?_ ?_
    (CheckAccept.checkProgramAccepted_ok actual_acceptance).1
  · intro name d found
    rw [actual_definitions] at found
    split at found
    · cases found
      constructor
      · simp [resolvedDefinition, lambdaDefinition, FunDecl.tel, FunDecl.coreParams,
          FunDecl.coreNames, FunDecl.dictTys, internalNames, signatureTel,
          Tel.Support, Ty.Support, Ty.SupportList, Eff.Support, Eff.empty]
      · have head := CheckArguments.primitive_empty_support
          (b := "%Predicate.0") (ts := []) prepared_input_sound.tables (by trivial)
        simpa [preparedInput, resolvedDefinition, resolved_syntax, Check.BlockSupport,
          CheckSource.BlockSupport, CheckSource.ExprSupport, CheckSource.HolesSupport,
          Entry.result, Ty.Support, Ty.SupportList, Eff.Support, Eff.empty] using head
    · cases found
  · rw [actual_prepared]
    intro name id found; cases found
  · rw [actual_prepared]
    intro name id found; cases found
  · apply CheckTables.prepare_extension
    exact CheckTables.Extends.refl _

/-- 解決前の通常の公開呼出しの許容を明示する。表の応答は変えない。 -/
def originalInput : Check.Input := { checkInput with
  admitsDec := fun name _ types => decide (name = "Float.isFinite" ∧ types = []) }

theorem finite_lookup (P : Refinement.Program) :
    (StandardModel.builtins P).sig "Float.isFinite" =
      some (API.floating .binary64 .finite).signature := by
  rfl

attribute [local cbv_eval] finite_lookup

theorem original_input_sound : originalInput.Sound := by
  refine ⟨input_sound.formation,input_sound.tables,input_sound.sat,?_,input_sound.ranges,input_sound.operators⟩
  intro name signature C types found accepted
  obtain ⟨rfl,rfl⟩ := of_decide_eq_true accepted
  have lookup : originalInput.B.sig "Float.isFinite" =
      some (API.floating .binary64 .finite).signature := finite_lookup _
  rw [lookup] at found
  cases found
  rfl

theorem source_support : CheckDeclarations.DefSupport originalInput lambdaDefinition := by
  constructor
  · simp [lambdaDefinition, FunDecl.tel, FunDecl.coreParams, FunDecl.coreNames,
      FunDecl.dictTys, internalNames, signatureTel, Tel.Support, Ty.Support,
      Ty.SupportList, Eff.Support, Eff.empty]
  · have head := CheckArguments.primitive_empty_support
        (b := "Float.isFinite") (ts := []) original_input_sound.tables (by trivial)
    simpa [lambdaDefinition, source, publicCall, Check.BlockSupport,
      CheckSource.BlockSupport, CheckSource.ExprSupport, CheckSource.ExprsSupport,
      Entry.result, Ty.Support, Ty.SupportList, Eff.Support, Eff.empty] using head

/-- 元の本体も固定標準表で型付きである。解決後の受理とは別に検査する。 -/
theorem source_typed : lambdaDefinition.WellTyped originalInput.D originalInput.B op := by
  apply CheckDeclarations.checkDef_no_ranges_sound (path := []) original_input_sound source_support rfl
  cbv

/-- 健全な入力で受理した factory でも、関数を返す正常値の厳密等号は保たない。
開始点は factory 本体の脱糖であり、CLI の main の実行ではない。 -/
theorem accepted_normal_boundary (σ : PathEnv) :
    checkInput.Sound ∧
    CheckAccept.checkProgramAccepted checkInput acceptedInput surfaceProgram = .ok () ∧
    lambdaDefinition.WellTyped originalInput.D originalInput.B op ∧
    CheckTables.CheckedUnder (CheckPreparation.prepare checkInput surfaceProgram).program preparedInput ∧
    ((CheckPreparation.prepare checkInput surfaceProgram).program.defs "factory").map
      (fun definition => desugarBlock op .tail definition.body) = some after ∧
    originalValue ≠ resolvedValue ∧
    returned (.run (.pure before) [] Store.empty) = some originalValue ∧
    returned (.run (.pure after) [] Store.empty) = some resolvedValue ∧
    ∀ events z, Steps (desugarProgram op (CheckPreparation.prepare checkInput surfaceProgram).program) preparedInput.B σ
      (.run (.pure after) [] Store.empty) events z → returned z ≠ some originalValue := by
  have hn := normal_values (desugarProgram op (CheckPreparation.prepare checkInput surfaceProgram).program) preparedInput.B σ
  exact ⟨input_sound,actual_acceptance,source_typed,prepared_typed,actual_preparation,
    values_differ,hn.2.2.1,hn.2.2.2.1,hn.2.2.2.2.2.2⟩

/-- 抽出した正常値は、消去の観測定理が使う正常観測の厳密等号と同値である。 -/
theorem returned_iff_terminal (s : State) (v : Val) :
    returned s = some v ↔ SafeCheckErasure.terminal s = some (.value v) := by
  cases s with
  | run q k μ =>
    cases k with
    | nil => cases view : q.view <;> simp [returned, SafeCheckErasure.terminal, view]
    | cons frame rest => simp [returned, SafeCheckErasure.terminal]
  | matchRun => simp [returned, SafeCheckErasure.terminal]
  | error errors k μ => cases k <;> simp [returned, SafeCheckErasure.terminal]
  | exit code errors k μ => cases k <;> simp [returned, SafeCheckErasure.terminal]

/-- 実入口で受理した factory の本体について、元の正常観測は解決後に現れない。
元と解決後の実プログラムと表を使う。main 起点の実行の反例ではない。 -/
theorem actual_exact_observation_boundary (σ : PathEnv) :
    checkInput.Sound ∧
    CheckAccept.checkProgramAccepted checkInput acceptedInput surfaceProgram = .ok () ∧
    lambdaDefinition.WellTyped originalInput.D originalInput.B op ∧
    CheckTables.CheckedUnder (CheckPreparation.prepare checkInput surfaceProgram).program preparedInput ∧
    (∃ z, Steps (desugarProgram op surfaceProgram) originalInput.B σ
      (.run (.pure before) [] Store.empty) [] z ∧
        SafeCheckErasure.terminal z = some (.value originalValue)) ∧
    ∀ events, ¬ ∃ z, Steps (desugarProgram op (CheckPreparation.prepare checkInput surfaceProgram).program)
      preparedInput.B σ (.run (.pure after) [] Store.empty) events z ∧
        SafeCheckErasure.terminal z = some (.value originalValue) := by
  have initial := normal_values (desugarProgram op surfaceProgram) originalInput.B σ
  have ready := normal_values (desugarProgram op (CheckPreparation.prepare checkInput surfaceProgram).program)
    preparedInput.B σ
  refine ⟨input_sound,actual_acceptance,source_typed,prepared_typed,
    ⟨_,.nil,(returned_iff_terminal _ _).mp initial.2.2.1⟩,?_⟩
  intro events ⟨z,steps,observation⟩
  exact ready.2.2.2.2.2.2 events z steps ((returned_iff_terminal _ _).mpr observation)

example (σ : PathEnv) := actual_exact_observation_boundary σ

#print axioms returned_iff_terminal
#print axioms actual_exact_observation_boundary

#print axioms accepted_normal_boundary

#print axioms source_typed

#print axioms prepared_typed

#print axioms actual_preparation
#print axioms actual_acceptance

#print axioms counterexample
#print axioms normal_values
end
end Benitoite.Release.Refinement.PredicateResolutionBoundary
