import Benitoite.Release.Refinement.Surface.CheckEntrypointsSound
import Benitoite.Release.Refinement.Surface.CheckAccept
import Benitoite.Release.Refinement.Surface.CheckMaterials
import Benitoite.Release.Refinement.EffectSoundnessExamples

/-! ソースと証明書だけを与える実入口の適用例。 -/
namespace Benitoite.Release.Refinement.Surface.CheckInferExamples
open Check CheckSubtyping

private def unitFunction : FunDecl where
  tparams := []
  neffs := 0
  names := ["value"]
  params := [.base .unit]
  ret := .base .unit
  eff := Eff.empty

private def unitPrimitive : PrimSig where
  tparams := []
  neffs := 0
  names := ["value"]
  params := [.base .unit]
  ret := .base .unit
  eff := Eff.empty
  admits := fun _ _ => True
  kind := .pure
  opEff := none

private def ping : OpDecl where
  eff := "Example.E"
  tparams := []
  names := []
  params := []
  ret := .base .unit

private def declarations : Declarations where
  funs := fun f => if f = "Example.id" then some unitFunction else none
  cons := fun _ => none
  ops := fun o => if o = "Example.ping" then some ping else
    if o = "Example.other" then some {ping with eff := "Example.F"} else none
  effects := fun e => if e = "Example.E" then some ["Example.ping"] else
    if e = "Example.F" then some ["Example.other"] else none

private def builtins : Builtins where
  sig := fun b => if b = "Example.unit" then some unitPrimitive else none
  delta := fun b _ _ _ vs => if b = "Example.unit" then vs.head?.map Outcome.val else none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  sat := fun _ _ _ => False
  refGet := "get"
  refSet := "set"

/-- 案内や位置ごとの型の欄を持たず、ソースと署名の表を渡す。 -/
private def input : Check.Input where
  D := declarations
  builtinSource := .custom builtins
  opPrim := fun _ _ => none
  formation := { atoms := [.name "Example.E" (.fixed .top), .name "Example.F" (.fixed .top)], ctors := fun _ => [] }
  admitsDec := fun _ _ _ => true
  proofSteps := 10
  effects := ["Example.E", "Example.F"]
  ops := ["Example.ping", "Example.other"]

private def booleanMatch (both : Bool) : Expr :=
  .matchE (.base .unit) (.literal (.boolean true))
    (.cons [⟨.boolean true, []⟩] none (.last .unit)
      (if both then .cons [⟨.boolean false, []⟩] none (.last .unit) .nil else .nil))

private def namedCall (f : Expr) (label : String := "value") : Expr :=
  .call f [some label] [0] (.cons .unit .nil)

private def handled : Expr :=
  .handleE (.last (.call (.opName "Example.ping" []) [] [] .nil))
    (.cons (.user "Example.ping") 0 0 (.last (.resume 0 .unit)) .nil)

private def unitDefinition (body : Expr) : Def where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := Eff.empty
  body := .last body

/-- 候補に操作の原子があっても、単位値と純粋な束縛の効果は空である。 -/
theorem unit_and_let :
    Check.checkExpr input [] [] [] none .other [] .unit = .ok (.base .unit, Eff.empty) ∧
    Check.checkBlock input [] [] [] none .other []
      (.bind .bind (.base .unit) .unit (.last (.local 0))) = .ok (.base .unit, Eff.empty) := by
  constructor <;> with_unfolding_all rfl

/-- 同じ Boolean の値について、両方の腕を持つ照合を受理し、不足する腕を拒否する。 -/
theorem branches_accept_reject :
    (Check.checkExpr input [] [] [] none .other []
      (.ite (.literal (.boolean true)) (.last .unit) (.last .unit))).toBool = true ∧
    (Check.checkExpr input [] [] [] none .other [] (booleanMatch true)).toBool = true ∧
    (Check.checkExpr input [] [] [] none .other [] (booleanMatch false)).toBool = false := by
  with_unfolding_all exact ⟨rfl, rfl, rfl⟩

/-- 関数と組込みの呼出しは、ソースの契約名を実際の署名と照合する。 -/
theorem calls_accept_reject :
    (Check.checkExpr input [] [] [] none .other []
      (namedCall (.funName "Example.id" [] []))).toBool = true ∧
    (Check.checkExpr input [] [] [] none .other []
      (namedCall (.primName "Example.unit" [] [] []))).toBool = true ∧
    (Check.checkExpr input [] [] [] none .other []
      (namedCall (.primName "Example.unit" [] [] []) "other")).toBool = false := by
  cbv

/-- 操作を再開する節のある本体は純粋であり、同じ操作を捕まえない本体は純粋の契約に違反する。 -/
theorem handler_accept_reject :
    CheckDeclarations.checkDef input [] (unitDefinition handled) = .ok () ∧
    (CheckDeclarations.checkDef input [] (unitDefinition
      (.handleE (.last (.call (.opName "Example.ping" []) [] [] .nil)) .nil))).toBool = false := by
  cbv

private def resumeOther : Expr :=
  .handleE (.last (.call (.opName "Example.ping" []) [] [] .nil))
    (.cons (.user "Example.ping") 0 0
      (.last (.resume 0 (.call (.opName "Example.other" []) [] [] .nil))) .nil)

/-- 再開の引数で行う別の操作は、処理した操作を除いた後の効果に残る。 -/
theorem resume_argument_effect :
    (match Check.checkExpr input [] [] [] none .other [] resumeOther with
      | .ok (a, e) => a = .base .unit ∧ e.test (.name "Example.F" (.fixed .top)) = true ∧
          e.test (.name "Example.E" (.fixed .top)) = false
      | .error _ => False) ∧
    (CheckDeclarations.checkDef input [] (unitDefinition resumeOther)).toBool = false := by
  cbv

private def one : Literal := .integer ⟨1, by decide⟩
private def onePredicate : Pred := .eq (.var 0) (.integer 1)
private def oneType : Ty := .refined (.base .integer) onePredicate
private def closedOne : ExchangeCertificate :=
  { certificate := .leaf ⟨.eq (.integer 1) (.integer 1), .closed, [], []⟩
    actions := [.work .checkCertificate .node, .work .checkCertificate .node] }

private def proofInput : Check.Input :=
  { input with
    D := { funs := fun _ => none, cons := fun _ => none }
    builtinSource := .custom { builtins with sig := fun _ => none, delta := fun _ _ _ _ _ => none }
    formation := { atoms := [], ctors := fun _ => [] }
    effects := [], ops := []
    logicCertificates := fun _ _ => some closedOne }

private theorem proofInput_sound : proofInput.Sound := by
  refine ⟨⟨?_, ?_⟩, ⟨⟨?_⟩, ?_, ?_, ?_, ?_, ?_⟩, ?_, ?_, ?_, ?_⟩
  · intro c cd h; cases h
  · intro c cd h; cases h
  · intro i d h; cases h
  · intro f d h; cases h
  · intro b s h; cases h
  · intro o d h; cases h
  · intro c cd m ms h; cases h
  · intro f d h; cases h
  · intro C a p h; cases h
  · intro b s C ts h; cases h
  · intro b rs h; cases h
  · intro o t b ts h; cases h

private def proofDefinition (limit : Nat) : Def where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := Eff.empty
  proofSteps := some limit
  body := .lastBind .bind oneType (.literal one)

/-- 値の篩の導入と、篩を忘れる部分型を、ソースの注釈から検査する。 -/
theorem refinement_accept_reject :
    (Check.checkBlock proofInput [] [] [] none .other []
      (.lastBind .bind oneType (.literal one))).toBool = true ∧
    (Check.checkBlock proofInput [] [some oneType] [] none .other []
      (.lastBind .bind (.base .integer) (.local 0))).toBool = true ∧
    (Check.checkBlock {proofInput with logicCertificates := fun _ _ => some {certificate := .use 99, actions := []}}
      [] [] [] none .other [] (.lastBind .bind oneType (.literal one))).toBool = false := by
  with_unfolding_all exact ⟨rfl, rfl, rfl⟩

/-- 関数の指定が既定の上限を上書きし、打ち切りと0の拒否を実入口に返す。 -/
theorem proof_steps_accept_reject :
    CheckDeclarations.checkDef {proofInput with proofSteps := 1} [] (proofDefinition 10) = .ok () ∧
    (match CheckDeclarations.checkDef proofInput [] (proofDefinition 1) with
      | .error error => error.kind = .unknown | _ => False) ∧
    (match CheckDeclarations.checkDef proofInput [] (proofDefinition 0) with
      | .error error => error.kind = .rejected | _ => False) := by
  with_unfolding_all exact ⟨rfl, rfl, rfl⟩

private def refinedResult (value : Literal) : Def where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := oneType
  eff := Eff.empty
  body := .last (.literal value)

/-- 戻り値の篩は末尾の値で導入し、同じ戻り値の契約に合わない値を拒否する。 -/
theorem refined_result_contract :
    CheckDeclarations.checkDef proofInput [] (refinedResult one) = .ok () ∧
    (CheckDeclarations.checkDef proofInput []
      (refinedResult (.integer ⟨2, by decide⟩))).toBool = false := by
  with_unfolding_all exact ⟨rfl, rfl⟩

/-- 同じ篩付きの戻り値の受理に、入力の全条件を満たして健全性の定理を適用する。 -/
theorem refined_result_typed : (refinedResult one).WellTyped proofInput.D proofInput.B proofInput.opPrim :=
  CheckDeclarations.checkDef_no_ranges_sound proofInput_sound
    ⟨⟨by trivial, Check.empty_effect_support _⟩, by trivial⟩ rfl refined_result_contract.1

private def nestedRefinement : Block :=
  .lastDiscard (.paren (.constE oneType (.literal one)))

private def malformedInput : Check.Input :=
  { proofInput with
    proofSteps := 1
    logicCertificates := fun _ _ => some {certificate := .use 99, actions := []} }

private def malformedGuide : Guide :=
  match CheckInfer.inferBlock malformedInput ⟨malformedInput.logicCertificates⟩
      [] [] [] [] [] none .other [] nestedRefinement with
  | .ok s => (finiteSynth malformedInput s).guide
  | .error _ => .unknown

/-- 打ち切りと不正な証明書の区別は、ブロックと括弧の内側の導入から入口へ伝わる。 -/
theorem nested_proof_errors :
    (match Check.checkBlock {proofInput with proofSteps := 1} [] [] [] none .other [] nestedRefinement with
      | .error error => error.kind = .unknown | _ => False) ∧
    (match Check.checkBlock malformedInput [] [] [] none .other [] nestedRefinement with
      | .error error => error.kind = .rejected | _ => False) ∧
    (match Check.checkBlock { proofInput with
        proofSteps := 1
        logicCertificates := fun path _ => some
          (if path.head? = some 0 then closedOne else {certificate := .use 99, actions := []})}
        [] [] [] none .other []
        (.discard (.constE oneType (.literal one))
          (.lastDiscard (.constE oneType (.literal one)))) with
      | .error error => error.kind = .rejected | _ => False) := by
  with_unfolding_all exact ⟨rfl, rfl, rfl⟩

private def joinLeft : Ty :=
  .fn ["value"] [.refined (.base .integer) (.eq (.integer 1) (.integer 1))]
    (.base .unit) Eff.empty

private def joinRight : Ty :=
  .fn ["value"] [.base .integer] (.base .unit)
    (.mk (fun atom => decide (atom = .name "Example.E" (.fixed .top))) [])

private def joinSource : Expr :=
  .ite (.literal (.boolean true)) (.last (.local 0)) (.last (.local 1))

/-- 結合する型の最初の候補での打ち切りは、逆の候補が効果で失敗しても unknown として残る。 -/
theorem function_join_proof_errors :
    (Check.checkExpr {input with logicCertificates := fun _ _ => some closedOne}
      [] [some joinLeft, some joinRight] [] none .other [] joinSource).toBool = true ∧
    (match Check.checkExpr { input with
        proofSteps := 1
        logicCertificates := fun _ _ => some closedOne }
        [] [some joinLeft, some joinRight] [] none .other [] joinSource with
      | .error error => error.kind = .unknown | _ => False) ∧
    (match Check.checkExpr { input with
        proofSteps := 1
        logicCertificates := fun _ _ => some {certificate := .use 99, actions := []} }
        [] [some joinLeft, some joinRight] [] none .other [] joinSource with
      | .error error => error.kind = .rejected | _ => False) := by
  with_unfolding_all exact ⟨rfl, rfl, rfl⟩

example :
    InferenceStopped {proofInput with proofSteps := 1}
      (CheckInfer.inferBlock {proofInput with proofSteps := 1} ⟨proofInput.logicCertificates⟩
        [] [] [] [] [] none .other [] nestedRefinement) ∧
    InferenceStopped {proofInput with proofSteps := 1}
      (CheckInfer.inferExpr {proofInput with proofSteps := 1} ⟨proofInput.logicCertificates⟩
        [] [] [] [] [] none .other [] (.paren (.constE oneType (.literal one)))) ∧
    (proofFailure [] 1 malformedGuide).kind = .rejected := by
  refine ⟨?_, ?_, ?_⟩
  · cases h : Check.checkBlock {proofInput with proofSteps := 1}
        [] [] [] none .other [] nestedRefinement with
    | ok value => have hn := nested_proof_errors.1; simp only [h] at hn
    | error error =>
      exact Check.checkBlock_unknown h (by simpa only [h] using nested_proof_errors.1)
  · have h : Check.checkExpr {proofInput with proofSteps := 1}
        [] [] [] none .other [] (.paren (.constE oneType (.literal one))) =
        .error ⟨[], "proof accounting stopped", .unknown⟩ := by
      with_unfolding_all rfl
    exact Check.checkExpr_unknown h rfl
  · let c : LogicCertificate :=
      {certificate := .use 99, actions := []
       query := some ⟨[0, 0, 0], [], .eq (.integer 1) (.integer 1)⟩}
    have hc : c ∈ CheckDiagnostics.guideQueries malformedGuide := by
      with_unfolding_all exact List.mem_singleton_self c
    exact proofFailure_malformed hc rfl rfl

private def ordinaryIdentity : Def :=
  { toFunDecl := unitFunction, body := .last (.local 0) }

private def userMaterials : CheckTables.Materials where
  defs := [("Example.id", ordinaryIdentity),
    ("Example.main", unitDefinition (namedCall (.funName "Example.id" [] [])))]

/-- 本体を持つ利用者の関数とその呼出しを、同じ宣言材料から検査する。 -/
theorem user_program_checked :
    CheckTables.checkProgram (userMaterials.input input) userMaterials.program = .ok () := by
  cbv

private def rangedPrimitive : PrimSig :=
  { unitPrimitive with names := [], params := [], rkinds := [.path] }

private def rangedBuiltins : Builtins :=
  { builtins with
    admitsR := fun _ _ => True
    sig := fun b => if b = "Example.required" then some rangedPrimitive else builtins.sig b
    delta := fun b ts es rs vs => if b = "Example.required" then some (.val (.const .unit))
      else builtins.delta b ts es rs vs }

private def rangedDefinition (r : Scope.Domain.Range) : Def where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := Eff.empty
  body := .last (.call (.primName "Example.required" [] [] [.fixed (.absolute r)]) [] [] .nil)

private def rangedMaterials (r : Scope.Domain.Range) : CheckTables.Materials where
  defs := [("Example.main", rangedDefinition r)]

private def rangedInput (r : Scope.Domain.Range) : Check.Input :=
  (rangedMaterials r).input { input with builtinSource := .custom rangedBuiltins, admitsRDec := fun _ _ => true }

private def requiredRule : Benitoite.Scope.Inference.ScopeRule Refinement.Val where
  index := fun _ => [.path (.tree ["data"])]
  run := fun _ _ => some (.const .unit)
  transfer := fun _ _ => none

private def acceptance : CheckAccept.AcceptInput where
  ok := "Ok"
  rules := fun n => if n = "Example.required" then some requiredRule else none
  limits := ⟨⟨100, 100⟩, ⟨100, 100⟩⟩
  methodKey := fun i m => i ++ "." ++ m

/-- 同じ型を推論する二つのプログラムを、必須の範囲の規則まで含む実入口で区別する。 -/
theorem program_accept_reject :
    CheckAccept.checkProgramAccepted (rangedInput (.path (.tree ["data"]))) acceptance
      (rangedMaterials (.path (.tree ["data"]))).program = .ok () ∧
    CheckAccept.checkProgramAccepted (rangedInput (.path (.tree ["other"]))) acceptance
      (rangedMaterials (.path (.tree ["other"]))).program =
        .error (.cover ⟨"Example.main", 0⟩ .notCovered) := by
  with_unfolding_all exact ⟨rfl, rfl⟩

private def stoppedMaterials : CheckTables.Materials where
  defs := [("Example.proof", proofDefinition 1)]

/-- 関数の打ち切りは必須の判定を含む入口でも unknown として残り、実際の本体の停止を持つ。 -/
example :
    (match CheckAccept.checkProgramAccepted (stoppedMaterials.input proofInput) acceptance
        stoppedMaterials.program with
      | .error (.typing error) => error.kind = .unknown | _ => False) ∧
    CheckTables.ClosedProgramStopped (stoppedMaterials.input proofInput) stoppedMaterials.program := by
  have hu : (match CheckAccept.checkProgramAccepted (stoppedMaterials.input proofInput) acceptance
      stoppedMaterials.program with
    | .error (.typing error) => error.kind = .unknown | _ => False) := by
    with_unfolding_all rfl
  refine ⟨hu, ?_⟩
  cases h : CheckAccept.checkProgramAccepted (stoppedMaterials.input proofInput) acceptance
      stoppedMaterials.program with
  | ok value => simp only [h] at hu
  | error error =>
    cases error with
    | cover key reason => simp only [h] at hu
    | typing error =>
      apply CheckTables.programStopped_no_ranges (h := CheckAccept.checkProgramAccepted_unknown h (by simpa only [h] using hu))
      intro n d hd
      change (if "Example.proof" = n then some (proofDefinition 1) else none) = some d at hd
      split at hd
      · cases hd; rfl
      · cases hd

/-- 支持を満たす案内の有限表現は、型・効果も含めて同じ再検査の結果を返す。 -/
example {q : Check.Input} {rows : List Bool} {Δ : BuilderCtx} {C : TypeCtx} {Γ : Ctx}
    {Φ : List Pred} {R : Option Ty} {p : Position} {path : List Nat} {e : Expr} {a : Ty} {ef : Eff}
    {g : Guide} (ha : a.Support (· ∈ q.formation.atoms))
    (he : ef.Support (· ∈ q.formation.atoms)) (hg : g.Support q.formation.atoms) :
    Check.checkExprAt q rows Δ C Γ Φ R p path e
      (CheckFinite.ty q.formation.atoms a) (CheckFinite.eff q.formation.atoms ef)
      (CheckFinite.guide q.formation.atoms g) = Check.checkExprAt q rows Δ C Γ Φ R p path e a ef g := by
  rw [CheckFinite.ty_eq _ _ ha, CheckFinite.eff_eq _ _ he, CheckFinite.guide_eq _ _ hg]

/-- 案内の支持を余分に仮定する呼出しからも、実入口の成功に健全性を適用できる。 -/
example {q : Check.Input} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {R : Option Ty} {p : Position}
    {path : List Nat} {e : Expr} {a : Ty} {ef : Eff} {g : Guide} (hq : q.Sound)
    (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ) (hR : Check.ReturnSupport q.formation.atoms R)
    (hs : Check.ExprSupport q e) (ha : a.Support (· ∈ q.formation.atoms))
    (he : ef.Support (· ∈ q.formation.atoms)) (_hg : g.Support q.formation.atoms)
    (hc : Check.checkExpr q C Γ Φ R p path e = .ok (a, ef)) :
    HasTypeQ q.D q.B q.opPrim Qempty [] C Γ Φ R p e a ef ∧ SingleTy Qempty a ∧ SingleEff Qempty ef :=
  Check.checkExpr_sound hq hΓ hR hs ha he hc

noncomputable section

private def pureSource : Expr :=
  .handleE (.bind .bind (.base .unit) .unit (.last (.local 0))) .nil

private def pureInput : Check.Input where
  D := { funs := fun _ => none, cons := fun _ => none }
  builtinSource := .custom Model.builtins
  opPrim := fun _ _ => none
  formation := { atoms := [], ctors := fun _ => [] }
  proofSteps := 1

private def pureBody : Comp := .letIn (.ret (.const .unit)) (.ret (.var 0))
private def pureStart : Closure := Closure.pure (.handle pureBody [])

private theorem pureTyped :
    ClosureTy EffectSoundnessExamples.program Model.builtins StoreTy.empty [] none
      pureStart (.base .unit) Eff.empty := by
  have ha : Ty.Annotation EffectSoundnessExamples.program [] [] (.base .unit) :=
    ⟨trivial, trivial, trivial⟩
  have body : HasTypeC EffectSoundnessExamples.program Model.builtins StoreTy.empty [] [] [] none
      pureBody (.base .unit) Eff.empty :=
    .C_Let (.C_Return (.V_Const (by trivial)))
      (.C_Return (.V_Var rfl (by intro b t e h; cases h))) (by trivial)
  have inner : HasTypeC EffectSoundnessExamples.program Model.builtins StoreTy.empty [] [] [] none
      (.handle pureBody []) (.base .unit) Eff.empty :=
    .C_Handle body
      ⟨(by intro a h; cases h), (by intro a h; obtain ⟨t, ht, _⟩ := h; cases ht)⟩ .nil
  exact ClosureTy.pure inner ha.done_empty (by intro r hr; cases hr) rfl (by intro r hr; cases hr)

private theorem pureStartCondition :
    StartCondition EffectSoundnessExamples.program Model.builtins EffectSoundnessExamples.σFull pureStart := by
  refine ⟨?_, ?_, ⟨EffectSoundnessExamples.valid, fun r _ => ?_⟩⟩
  · simp [pureStart, pureBody, Closure.pure, Closure.Adequate, Comp.Adequate,
      Capture.Adequate, adequateCaptureSlots, Capture.empty, Val.Adequate, adequateClauses]
  · simp [pureStart, pureBody, Closure.pure, Closure.ClosedAt, Comp.ClosedAt, Clause.ClosedList,
      Val.ClosedAt, Capture.Closed, captureSlotsClosed, Capture.empty]
  · cases r with
    | base b => cases b <;> exact ⟨_, rfl⟩
    | secrets => rfl

/-- 実入口が受理した同じハンドラは、実際に四段進み、全到達状態の健全性を終端にも適用できる。 -/
theorem pure_handler_execution :
    Check.checkExpr pureInput [] [] [] none .other [] pureSource = .ok (.base .unit, Eff.empty) ∧
    desugarExpr pureInput.opPrim .other pureSource = .handle pureBody [] ∧
    ClosureTy EffectSoundnessExamples.program Model.builtins StoreTy.empty [] none
      pureStart (.base .unit) Eff.empty ∧
    StartCondition EffectSoundnessExamples.program Model.builtins EffectSoundnessExamples.σFull pureStart ∧
    ¬ (State.run pureStart [] Store.empty).Final ∧
    ∃ finished,
      Steps EffectSoundnessExamples.program Model.builtins EffectSoundnessExamples.σFull
        (.run pureStart [] Store.empty) [] finished ∧ finished.Final ∧
      (∀ ev next, ¬ Step EffectSoundnessExamples.program Model.builtins EffectSoundnessExamples.σFull
        finished (some ev) next) ∧ ¬ UnhandledOp finished := by
  refine ⟨?_, rfl, pureTyped, pureStartCondition, ?_, ?_⟩
  · with_unfolding_all rfl
  · rintro ⟨v, hv⟩
    cases hv
  · let finished : State := .run (Closure.pure (.ret (.const .unit))) [] Store.empty
    have run : Steps EffectSoundnessExamples.program Model.builtins EffectSoundnessExamples.σFull
        (.run pureStart [] Store.empty) [] finished :=
      .cons (.E_Handle rfl) (.cons (.E_Let rfl) (.cons (.E_Return rfl) (.cons (.E_HRet rfl) .nil)))
    have sound := effect_soundness EffectSoundnessExamples.program Model.builtins EffectSoundnessExamples.σFull
      EffectSoundnessExamples.wellFormed EffectSoundnessExamples.wellTyped EffectSoundnessExamples.effectsOk
      EffectSoundnessExamples.core pureStart (.base .unit) pureTyped pureStartCondition [] finished run
    exact ⟨finished, run, ⟨.const .unit, rfl⟩, sound⟩

end

end Benitoite.Release.Refinement.Surface.CheckInferExamples
