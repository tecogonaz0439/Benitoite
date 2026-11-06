import Benitoite.Release.Refinement.SurfaceMainExamples
import Benitoite.Release.Refinement.SurfaceDeclarationAgreement
import Benitoite.Release.Refinement.SurfaceStandardSupport

/-! # 完成した標準表と補完した関数宣言を使う実入口の証人 -/
namespace Benitoite.Release.Refinement.Surface.CheckedMainExamples
noncomputable section
open StandardModel

/-- 標準の核の本体を呼び、結果を捨てる表層の計算。 -/
def call : Expr := .call (.funName "Range.checkInteger" [] [] [])
  [some "minimum",some "maximum",some "value"] [0,1,2]
  (.cons (.literal (.integer ⟨0,by decide⟩))
    (.cons (.literal (.integer ⟨1,by decide⟩)) (.cons (.literal (.integer ⟨0,by decide⟩)) .nil)))

def mainDef : Def := {Examples.mainDef with body := .discard call .empty}

def mainProgram : Program := {Examples.mainProgram with defs := fun f => if f = "main" then some mainDef else none}

def source (externals : List (ExternalKey × ExternalDecl)) : Program :=
  {mainProgram with cons := (program externals).cons
                    dataInfo := (program externals).dataInfo
                    externals := externals}

def linked (externals : List (ExternalKey × ExternalDecl)) : Refinement.Program :=
  linkProgram (program externals) (fun _ _ => none) (source externals)

/-- 標準本体の署名を収集した宣言。利用者の表にはこの名前の本体を置かない。 -/
def standardDeclaration : FunDecl where
  tparams := []
  neffs := 0
  names := ["minimum","maximum","value"]
  params := [.base .integer,.base .integer,.base .integer]
  ret := StandardOrdinaryCoreProgram.API.result .checkInteger
  eff := Eff.empty

/-- 利用者の宣言の空欄を、呼び出す標準関数の署名で補う。 -/
def declarations (externals : List (ExternalKey × ExternalDecl)) : Declarations :=
  {(source externals).declarations with
    funs := fun f => if f = "Range.checkInteger" then some standardDeclaration else (source externals).declarations.funs f}

private theorem main_fresh (externals : List (ExternalKey × ExternalDecl)) :
    (program externals).defs "main" = none := rfl

/-- 核の標準本体を同じ値で保持する包含。 -/
theorem includes (externals : List (ExternalKey × ExternalDecl)) : Includes externals (linked externals) where
  extends_ := { Refinement.Program.Extends.refl (program externals) with
    defs := by
      intro f d hd
      have hn : f ≠ "main" := by intro h; subst f; rw [main_fresh] at hd; cases hd
      simpa [linked,linkProgram,desugarProgram,Program.lookupFun,source,mainProgram,Examples.mainProgram,hn] using hd }
  internal := by
    intro f d hn hd
    by_cases hm : f = "main"
    · subst f; simp only [String.startsWith_string_iff]; decide
    · simp [linked,linkProgram,desugarProgram,Program.lookupFun,source,mainProgram,Examples.mainProgram,hm,hn] at hd
  publicCollisions := by
    intro n hn
    have h0 := (Includes.refl externals).publicCollisions n hn
    have hm : n ≠ "main" := by
      intro h; subst n
      simp [FunctionNames.collisionNames] at hn
    simpa [linked,linkProgram,desugarProgram,Program.lookupFun,source,mainProgram,Examples.mainProgram,hm] using h0

/-- 関数の結合は data の宣言を変えない。 -/
def data (externals : List (ExternalKey × ExternalDecl)) : DataTable (linked externals) :=
  { dataTable externals with valid := (variance_valid externals).sameTypes ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩ }

/-- 全ての起点を束縛した具体の環境。 -/
def environment : PathEnv := ⟨[],[],[],some [],some [],some []⟩

private theorem ready (P : Refinement.Program) (B : Builtins) :
    environment.Ready P B (.run mainClosure [] Store.empty) := by
  refine ⟨by simp [PathEnv.Valid,environment,Scope.Domain.PathWordWF], ?_⟩
  intro r _
  cases r with
  | base b => cases b <;> exact ⟨[],rfl⟩
  | secrets => rfl

/-- 表層の整形式を、checker の結論から独立に供給する。 -/
theorem wellFormed (externals : List (ExternalKey × ExternalDecl)) (hw : (program externals).ExternalWF) :
    (source externals).WellFormed where
  types := (MainExamples.wellFormed externals hw).types
  defs := by
    intro f d hd
    change (if f = "main" then some mainDef else none) = some d at hd
    split at hd
    · cases hd
      refine ⟨by simp [mainDef,Examples.mainDef,FunDecl.coreNames,FunDecl.coreParams,FunDecl.dictTys,internalNames,NamesWF],?_,by simp [mainDef,Examples.mainDef,call,Block.Scoped,Expr.Scoped,Exprs.Scoped,scopedTypes,scopedRows]⟩
      change SignatureScopedR _ [] [] 0 (.done (.base .unit) Eff.empty)
      refine ⟨⟨(Examples.mainTel_annotation (source externals).declarations.core).wf,?_,?_⟩,?_,?_,(Examples.mainTel_annotation _).range_empty⟩
      · simp [Ty.RowsIn,Tel.RowsIn,Eff.RowsIn,Eff.empty,Ty.RowsInList]
      · simp [Ty.RangesScoped,Tel.RangesScoped,Eff.RangesScoped,Eff.empty,rangesScopedTypes]
      · simp [Tel.RowsIn,Ty.RowsIn,Eff.RowsIn,Eff.empty,Ty.RowsInList]
      · simp [Ty.HasKind,kindsTel,kindsEff,kindsList,Eff.empty]
    · cases hd
  impls := by intro i id hi; cases hi
  accessors := by intro f c k h; cases h
  testers := by intro f c h; cases h

/-- 同じ完成表を構成元から直接渡す入力。 -/
def input (externals : List (ExternalKey × ExternalDecl)) : Check.Input where
  D := declarations externals
  builtinSource := .custom (complete nameLists (data externals) ApplicationExamples.noAssumptions)
  opPrim := fun _ _ => none
  formation := ⟨StandardSupport.atoms,fun _ => constructorNames,[]⟩
  proofSteps := 4
  defs := ["main"]
  dataNames := []
  ctorNames := constructorNames

private theorem main_lookup (externals : List (ExternalKey × ExternalDecl)) :
    (source externals).defs "main" = some mainDef := rfl

private theorem only_main {externals n d} (h : (source externals).defs n = some d) : n = "main" ∧ d = mainDef := by
  change (if n = "main" then some mainDef else none) = some d at h
  split at h
  · exact ⟨‹n = "main"›,(Option.some.inj h).symm⟩
  · cases h

private theorem constructor_member {externals c cd} (h : (program externals).cons c = some cd) :
    c ∈ constructorNames := by
  have hm := cons_mem h
  exact List.mem_map.mpr ⟨(c,cd),hm,rfl⟩

private theorem public_support (atoms : List Atom) (b : ScopePublic.PublicTy) :
    b.ty.Support (· ∈ atoms) := by
  induction b <;> simp_all [ScopePublic.PublicTy.ty,Ty.Support,Ty.SupportList]

private theorem fields_support (atoms : List Atom) {externals c cd}
    (h : (program externals).cons c = some cd) : Ty.SupportList (· ∈ atoms) cd.args := by
  rcases (constructors_split (cons_mem h)).symm with mem | mem
  · obtain ⟨_,_,as,ha,_⟩ := ScopeDeclarations.public_entry mem
    rw [ha]
    apply Ty.SupportList.iff.mpr
    intro a hm
    obtain ⟨b,_,rfl⟩ := List.mem_map.mp hm
    exact public_support atoms b
  simp only [baseDeclarations,byteOrder,roundingMode,checkError,StandardOrdinaryCoreBodies.declarations,
    ScopeDeclarations.base,ScopeDeclarations.file,ScopeDeclarations.result,ScopeDeclarations.scopeError,
    ScopeDeclarations.pair,ScopeDeclarations.clientRequest,ScopeDeclarations.requestCheckError,
    StandardOrdinaryCoreBodies.Record.owner,StandardOrdinaryCoreBodies.Record.fields,StandardSafe.names] at mem
  simp (config := {decide := true}) [List.filter,StandardKeyTyping.DataDecl.entries] at mem
  repeat' (rcases mem with ⟨rfl,rfl⟩ | mem)
  all_goals try (obtain ⟨rfl,rfl⟩ := mem)
  all_goals subst_vars
  all_goals simp [Ty.SupportList,Ty.Support,atErrorFields,atErrorType,atDetailType]

private theorem declaration_cases {externals f fd} (hf : (declarations externals).funs f = some fd) :
    (f = "main" ∧ fd = mainDef.toFunDecl) ∨ (f = "Range.checkInteger" ∧ fd = standardDeclaration) := by
  simp only [declarations,Program.declarations,Program.declarationsFor,Program.lookupFun,source,mainProgram,Examples.mainProgram] at hf
  by_cases hs : f = "Range.checkInteger"
  · simp only [hs,ite_true,Option.some.injEq] at hf
    exact .inr ⟨hs,hf.symm⟩
  · simp only [hs,ite_false] at hf
    by_cases hm : f = "main"
    · simp only [hm,ite_true,Option.some.injEq] at hf
      exact .inl ⟨hm,hf.symm⟩
    · simp [hm] at hf

/-- 完成表の全署名の支持を含む、checker の実入力の健全性。 -/
theorem input_sound : (input positiveExternals).Sound := by
  refine ⟨⟨?_,?_⟩,⟨⟨?_⟩,?_,?_,?_,?_,?_⟩,?_,?_,?_,?_⟩
  · intro c cd hc
    exact constructor_member (externals := positiveExternals) hc
  · intro c cd hc
    exact fields_support _ (externals := positiveExternals) hc
  · intro i id hi; cases hi
  · intro f fd hf
    rcases declaration_cases hf with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals repeat' constructor
    all_goals intro a ha; cases ha
  · intro b s hs
    exact StandardSupport.complete nameLists (data positiveExternals) hs
  · intro o d ho; cases ho
  · intro c cd m ms hc hm; cases hc
  · intro f d hf
    change (program positiveExternals).externalFunction f = some d at hf
    by_cases hn : f = ⟨0⟩
    · subst f
      change some ExternalModelExamples.positiveSignature = some d at hf
      cases hf
      exact ⟨trivial,Check.empty_effect_support _⟩
    · have hk : (ExternalKey.function f == ExternalKey.function ⟨0⟩) = false := by
        simp_all [BEq.beq]
      simp [Refinement.Program.externalFunction,program,positiveExternals,List.lookup,hk] at hf
  · intro C a p h; cases h
  · intro b sg C ts hb h; cases h
  · intro b rs h; cases h
  · intro o t b ts h; cases h

private theorem declarations_extend (externals : List (ExternalKey × ExternalDecl)) :
    CheckTables.Extends (declarations externals) (source externals).declarations := by
  refine ⟨?_,fun _ _ h => h,rfl,rfl,rfl,rfl,rfl⟩
  intro f fd hf
  have hn : f ≠ "Range.checkInteger" := by
    intro he; subst f
    change none = some fd at hf
    cases hf
  simpa [declarations,hn] using hf

private theorem standard_lookup (externals : List (ExternalKey × ExternalDecl)) :
    (linked externals).defs "Range.checkInteger" = some Body.b016.definition := by
  exact body_lookup externals .b016

private theorem linked_main_lookup (externals : List (ExternalKey × ExternalDecl)) :
    (linked externals).defs "main" = some (desugarDef (fun _ _ => none) mainDef) := rfl

private theorem declaration_support {externals f fd} (hf : (declarations externals).funs f = some fd) :
    (DeclarationAgreement.declarationType fd).Support (· ∈ StandardSupport.atoms) := by
  rcases declaration_cases hf with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals repeat' constructor
  all_goals intro a ha; cases ha

private theorem definition_support {externals f fd d} (hf : (declarations externals).funs f = some fd)
    (hp : (linked externals).defs f = some d) :
    (DeclarationAgreement.functionType d).Support (· ∈ StandardSupport.atoms) := by
  rcases declaration_cases hf with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  · rw [linked_main_lookup] at hp
    cases hp
    repeat' constructor
    all_goals intro a ha; cases ha
  · rw [standard_lookup] at hp
    cases hp
    repeat' constructor
    all_goals intro a ha; cases ha

/-- 二つの有限表の署名の一致。標準関数の本体は利用者側の表に存在しない。 -/
theorem signatures_agree :
    DeclarationAgreement.check StandardSupport.atoms (declarations positiveExternals) (linked positiveExternals)
      ["main","Range.checkInteger"] [] = true := by
  simp only [DeclarationAgreement.check,DeclarationAgreement.functionsCheck,DeclarationAgreement.implementationsCheck,
    List.all_cons,List.all_nil,Bool.and_true]
  rw [linked_main_lookup,standard_lookup]
  rfl

/-- 標準関数の結果型だけを Unit に変えた宣言は、同じ核の表との照合で拒む。 -/
theorem wrong_signature_rejected :
    DeclarationAgreement.check StandardSupport.atoms
      {(declarations positiveExternals) with funs := fun f =>
        if f = "Range.checkInteger" then some {standardDeclaration with ret := .base .unit}
        else (declarations positiveExternals).funs f}
      (linked positiveExternals) ["main","Range.checkInteger"] [] = false := by
  simp only [DeclarationAgreement.check,DeclarationAgreement.functionsCheck,DeclarationAgreement.implementationsCheck,
    List.all_cons,List.all_nil,Bool.and_true]
  rw [linked_main_lookup,standard_lookup]
  rfl

/-- 標準の本体の署名と補完した宣言の照合から、Realizes の全欄を供給する。 -/
theorem realizes : (input positiveExternals).D.Realizes (linked positiveExternals) := by
  apply DeclarationAgreement.realizes_of_check (D := declarations positiveExternals) (P := linked positiveExternals) (functions := ["main","Range.checkInteger"]) (implementations := [])
      (atoms := StandardSupport.atoms) (ht := ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩)
      ((includes positiveExternals).externalWF positive_wf)
  · intro f fd hf
    rcases declaration_cases hf with ⟨rfl,_⟩ | ⟨rfl,_⟩ <;> simp
  · intro i id hi; cases hi
  · exact fun _ _ hf => declaration_support hf
  · exact fun _ _ _ hf hp => definition_support hf hp
  · intro i id hi; cases hi
  · intro i is id hi hp; cases hi
  · exact signatures_agree

private theorem names_complete : CheckTables.NamesComplete (input positiveExternals) (source positiveExternals) where
  defs := by
    intro n d hd
    obtain ⟨rfl,rfl⟩ := only_main hd
    simp [input]
  impls := by intro i id hi; cases hi
  effects := by intro l os hl; cases hl
  operations := by intro o od ho; cases ho
  dataNames := by intro d info hd; cases hd
  ctorNames := by
    intro c cd hc
    exact constructor_member (externals := positiveExternals) hc

private theorem definitions_support : ∀ n d, (source positiveExternals).defs n = some d →
    CheckDeclarations.DefSupport (input positiveExternals) d := by
  intro n d hd
  obtain ⟨rfl,rfl⟩ := only_main hd
  refine ⟨⟨trivial,Check.empty_effect_support _⟩,?_⟩
  change CheckSource.BlockSupport _ _ (.discard call .empty)
  refine ⟨⟨CheckArguments.function_empty_support trivial (by simp),trivial,trivial,trivial,trivial⟩,trivial⟩

private theorem accept_names_complete : CheckAccept.NamesComplete (input positiveExternals) (source positiveExternals) :=
  ⟨names_complete.defs,names_complete.impls,by intro i id hi; cases hi⟩

/-- 必須の判定を同じ入口で実行する。標準関数の呼出しは範囲の判定を要求しない。 -/
def acceptInput : CheckAccept.AcceptInput where
  ok := "Benitoite.Result.Result.Ok"
  rules := fun _ => none
  limits := ⟨⟨100,100⟩,⟨100,100⟩⟩
  methodKey := fun i m => i ++ "." ++ m

private def bodyInput : Check.Input := {input positiveExternals with D := (input positiveExternals).D.withView closedView}

private theorem standardInstantiation : CheckFormation.instTel bodyInput.formation standardDeclaration.tel [] [] = standardDeclaration.tel := by
  rw [CheckFormation.instTel_eq]
  · have hn : typeEnvAt 0 [] [] = renEnv id := by
      change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
      congr 1 <;> funext i <;> simp [typeEnvAt,renEnv]
    rw [instantiatedTel,hn,Tel.bind,Tel.rawBind_id]
    rfl
  · repeat' constructor
    all_goals intro a ha; cases ha
  · trivial
  · simp

private theorem standardHead (path : List Nat) :
    CheckArguments.head bodyInput.formation bodyInput.D bodyInput.B bodyInput.satDec bodyInput.admitsDec bodyInput.admitsRDec
      [] [] [] path (.funName "Range.checkInteger" [] [] []) .plain = some (standardDeclaration.tel, []) := by
  rw [← standardInstantiation]
  rfl

private def standardResult : Ty := .data "Benitoite.Result.Result" [.data "Benitoite.Range.CheckedInteger" [],.data "Benitoite.Range.RangeError" []]
private def resultTel : Tel := .done standardResult Eff.empty
private def valueTel : Tel := .param "value" (.base .integer) resultTel
private def maximumTel : Tel := .param "maximum" (.base .integer) valueTel

private theorem bindResult (v : Val) : CheckFormation.bindValueTel bodyInput.formation v resultTel = resultTel := by
  rw [CheckFormation.bindValueTel_eq]
  · simp [resultTel,standardResult,Tel.bind,Tel.rawBind,Tel.norm,Ty.rawBind,rawBindTys,Ty.norm,Ty.normTys,
      Eff.rawBind,Tel.argumentsEnv,valEnv,instAtoms_nil,substAtoms_nil,rowFails,Eff.norm,Eff.empty]
  · repeat' constructor
    all_goals intro a ha; cases ha

private theorem bindValue (v : Val) : CheckFormation.bindValueTel bodyInput.formation v valueTel = valueTel := by
  rw [CheckFormation.bindValueTel_eq]
  · simp [valueTel,resultTel,standardResult,Tel.bind,Tel.rawBind,Tel.norm,Ty.rawBind,rawBindTys,Ty.norm,Ty.normTys,
      Eff.rawBind,Tel.argumentsEnv,valEnv,SubstEnv.up,instAtoms_nil,substAtoms_nil,rowFails,Eff.norm,Eff.empty]
  · repeat' constructor
    all_goals intro a ha; cases ha

private theorem bindMaximum (v : Val) : CheckFormation.bindValueTel bodyInput.formation v maximumTel = maximumTel := by
  rw [CheckFormation.bindValueTel_eq]
  · simp [maximumTel,valueTel,resultTel,standardResult,Tel.bind,Tel.rawBind,Tel.norm,Ty.rawBind,rawBindTys,Ty.norm,Ty.normTys,
      Eff.rawBind,Tel.argumentsEnv,valEnv,SubstEnv.up,instAtoms_nil,substAtoms_nil,rowFails,Eff.norm,Eff.empty]
  · repeat' constructor
    all_goals intro a ha; cases ha

private theorem arguments_inferred (path : List Nat) : CheckInfer.inferValsTel bodyInput ⟨bodyInput.logicCertificates⟩ [] [] 3
  [some (.base .integer),some (.base .integer),some (.base .integer)] [] path
  [.var 2,.var 1,.var 0] (Tel.shiftV 3 0 standardDeclaration.tel) =
    some (standardResult,Eff.empty,[⟨.base .integer,.var,.refl (.base .integer)⟩,⟨.base .integer,.var,.refl (.base .integer)⟩,⟨.base .integer,.var,.refl (.base .integer)⟩]) := by
  change CheckInfer.inferValsTel _ _ _ _ _ _ _ _ _ (.param "minimum" (.base .integer) maximumTel) = _
  simp only [CheckInfer.inferValsTel,CheckInfer.inferArg,bindMaximum]
  simp only [maximumTel,CheckInfer.inferValsTel,CheckInfer.inferArg,bindValue]
  simp only [valueTel,CheckInfer.inferValsTel,CheckInfer.inferArg,bindResult]
  simp only [resultTel,CheckInfer.inferValsTel]
  with_unfolding_all rfl

private def integerSynth : CheckInfer.Synth :=
  ⟨.base .integer,Eff.empty,.node .E_Literal {} [],none,none⟩

private def integerArgument (e : Expr) (path : List Nat) (ss : CheckInfer.Sequence) : CheckInfer.Sequence :=
  ⟨.base .integer :: ss.types,Check.union bodyInput Eff.empty ss.effect,
    fun ef => .node .Types_cons {} [(CheckInfer.coerceExpr bodyInput ⟨bodyInput.logicCertificates⟩ [] [] (Check.child path 0) e integerSynth (.base .integer) ef).guide,ss.build ef]⟩

private def argumentSequence (path : List Nat) : CheckInfer.Sequence :=
  integerArgument (.literal (.integer ⟨0,by decide⟩)) path
    (integerArgument (.literal (.integer ⟨1,by decide⟩)) (Check.child path 1)
      (integerArgument (.literal (.integer ⟨0,by decide⟩)) (Check.child (Check.child path 1) 1)
        ⟨[],Eff.empty,fun _ => .node .Types_nil {} []⟩))

private theorem arguments_synthesized (fuel : Nat) (path : List Nat) :
    CheckInfer.inferExprsFuel (fuel+4) bodyInput ⟨bodyInput.logicCertificates⟩ [] [] [] [] [] (some (.base .unit)) path
      (.cons (.literal (.integer ⟨0,by decide⟩)) (.cons (.literal (.integer ⟨1,by decide⟩)) (.cons (.literal (.integer ⟨0,by decide⟩)) .nil))) = .ok (argumentSequence path) := by
  simp only [Nat.add_succ,Nat.add_zero,CheckInfer.inferExprsFuel,CheckInfer.inferExprFuel]
  with_unfolding_all rfl

private def callSynth (path : List Nat) : CheckInfer.Synth :=
  {type := standardResult,effect := Eff.empty,
   guide := .node .E_CallDirect
     {types := [standardResult],typeLists := [[.base .integer,.base .integer,.base .integer]],effects := [Eff.empty],
      arguments := [[⟨.base .integer,.var,.refl (.base .integer)⟩,⟨.base .integer,.var,.refl (.base .integer)⟩,⟨.base .integer,.var,.refl (.base .integer)⟩]],
      heads := [.plain],subtypes := [.refl standardResult]} [(argumentSequence (Check.child path 0)).build Eff.empty],
   exprAs := some fun target allowed => .node .E_CallDirect
     {types := [standardResult],typeLists := [[.base .integer,.base .integer,.base .integer]],effects := [Eff.empty],
      arguments := [[⟨.base .integer,.var,.refl (.base .integer)⟩,⟨.base .integer,.var,.refl (.base .integer)⟩,⟨.base .integer,.var,.refl (.base .integer)⟩]],
      heads := [.plain],subtypes := [CheckInfer.inferLe bodyInput ⟨bodyInput.logicCertificates⟩ [some (.base .integer),some (.base .integer),some (.base .integer)] [] path 0 standardResult (target.shiftV 3 0)]}
     [(argumentSequence (Check.child path 0)).build allowed]}

private theorem call_inferred (path : List Nat) :
    CheckInfer.inferExprFuel 47 bodyInput ⟨bodyInput.logicCertificates⟩ [] [] [] [] [] (some (.base .unit)) .other path call = .ok (callSynth path) := by
  simp only [call,CheckInfer.inferExprFuel,directCallee]
  conv =>
    lhs
    arg 1
    arg 1
    change (match CheckArguments.head bodyInput.formation bodyInput.D bodyInput.B bodyInput.satDec bodyInput.admitsDec bodyInput.admitsRDec [] [] [] path (.funName "Range.checkInteger" [] [] []) .plain with
      | some (t,ds) => .ok (t,ds,CheckArguments.HeadGuide.plain)
      | none => .error (.rejected path "call signature is invalid"))
    rw [standardHead]
  simp only [arguments_synthesized 42,Except.bind,Bind.bind]
  -- 値の具体化の小補題を適用するため、この非公開の補助関数だけを展開する。
  run_tac
    let name := Lean.mkPrivateNameCore `Benitoite.Release.Refinement.Surface.CheckInfer
      `Benitoite.Release.Refinement.Surface.CheckInfer.valTelInfo
    Lean.Elab.Tactic.evalTactic (← `(tactic| unfold $(Lean.mkIdent name)))
  have ht : (argumentSequence (Check.child path 0)).types = [.base .integer,.base .integer,.base .integer] := rfl
  simp only [ht,List.length_cons,List.length_nil,Nat.reduceAdd,List.map_nil,List.nil_append]
  have he : bindParams [] [.base .integer,.base .integer,.base .integer] = [some (.base .integer),some (.base .integer),some (.base .integer)] := rfl
  rw [he]
  have hvs : recordFields 3 [0,1,2] (boundVars 3) (.const Const.unit) = [.var 2,.var 1,.var 0] := rfl
  rw [hvs]
  rw [show liftMany 3 [] = [] from rfl]
  rw [arguments_inferred]
  with_unfolding_all rfl

private def bodySynth (path : List Nat) : CheckInfer.Synth :=
  ⟨.base .unit,Eff.empty,.node .B_Discard {types := [standardResult]}
    [(callSynth (Check.child path 0)).guide,.node .B_Empty {} []],none,none⟩

private theorem body_inferred (path : List Nat) :
    CheckInfer.inferBlockExpected bodyInput ⟨bodyInput.logicCertificates⟩ [] [] [] [] [] (some (.base .unit)) .tail path
      (.discard call .empty) (.base .unit) Eff.empty = .ok (bodySynth path) := by
  unfold CheckInfer.inferBlockExpected
  -- この有限の本体の深さと推論の一段を展開し、子の実行結果で書き換える。
  run_tac
    let name := Lean.mkPrivateNameCore `Benitoite.Release.Refinement.Surface.CheckInfer
      `Benitoite.Release.Refinement.Surface.CheckInfer.inferBlockExpectedFuel
    Lean.Elab.Tactic.evalTactic (← `(tactic| unfold $(Lean.mkIdent name)))
  run_tac
    let m := `Benitoite.Release.Refinement.Surface.CheckInfer
    let b := Lean.mkIdent (Lean.mkPrivateNameCore m `Benitoite.Release.Refinement.Surface.CheckInfer.blockNodes)
    let e := Lean.mkIdent (Lean.mkPrivateNameCore m `Benitoite.Release.Refinement.Surface.CheckInfer.exprNodes)
    let es := Lean.mkIdent (Lean.mkPrivateNameCore m `Benitoite.Release.Refinement.Surface.CheckInfer.exprsNodes)
    Lean.Elab.Tactic.evalTactic (← `(tactic| simp only [$b:ident,$e:ident,$es:ident,call,Nat.reduceAdd,Nat.reduceMul]))
  have hc := call_inferred (Check.child path 0)
  simp only [call] at hc
  rw [hc]
  with_unfolding_all rfl

private def elementGuides : List CheckArguments.ElemGuide :=
  [⟨.base .integer,.var,.refl (.base .integer)⟩,⟨.base .integer,.var,.refl (.base .integer)⟩,⟨.base .integer,.var,.refl (.base .integer)⟩]

private def argumentGuide : Check.Guide := .node .Types_cons {} [.node .E_Literal {} [],
  .node .Types_cons {} [.node .E_Literal {} [],.node .Types_cons {} [.node .E_Literal {} [],.node .Types_nil {} []]]]

private def directGuide : Check.Guide := .node .E_CallDirect
  {types := [standardResult],typeLists := [[.base .integer,.base .integer,.base .integer]],effects := [Eff.empty],
   arguments := [elementGuides],heads := [.plain],subtypes := [.refl standardResult]} [argumentGuide]

private def expectedGuide : Check.Guide := .node .B_Discard {types := [standardResult]} [directGuide,.node .B_Empty {} []]

private theorem expected_guide (path : List Nat) : (bodySynth path).guide = expectedGuide := by
  with_unfolding_all rfl

private theorem values_recheck (path : List Nat) :
    CheckArguments.valsTel bodyInput.formation bodyInput.D bodyInput.B bodyInput.satDec [] [] 3
      [some (.base .integer),some (.base .integer),some (.base .integer)] [] bodyInput.proofSteps path
      [.var 2,.var 1,.var 0] (Tel.shiftV 3 0 standardDeclaration.tel) standardResult Eff.empty elementGuides = true := by
  change CheckArguments.valsTel _ _ _ _ _ _ _ _ _ _ _ _ (.param "minimum" (.base .integer) maximumTel) _ _ _ = _
  simp only [elementGuides,CheckArguments.valsTel,bindMaximum]
  simp only [maximumTel,CheckArguments.valsTel,bindValue]
  simp only [valueTel,CheckArguments.valsTel,bindResult]
  simp only [resultTel,CheckArguments.valsTel]
  with_unfolding_all rfl

private theorem call_recheck (path : List Nat) :
    Check.checkExprAt bodyInput [] [] [] [] [] (some (.base .unit)) .other path call standardResult Eff.empty directGuide = true := by
  simp only [Check.checkExprAt,directGuide,call,Check.head,Check.Hints.head,List.getElem?_cons_zero,Option.getD_some]
  rw [standardHead]
  simp only [Check.valsTel,Check.Hints.tys,Check.Hints.ty,Check.Hints.eff,Check.Hints.args,
    List.getElem?_cons_zero,Option.getD_some,List.length_cons,List.length_nil,Nat.reduceAdd,List.map_nil,List.nil_append]
  have he : bindParams [] [.base .integer,.base .integer,.base .integer] = [some (.base .integer),some (.base .integer),some (.base .integer)] := rfl
  rw [he]
  have hvs : recordFields 3 [0,1,2] (boundVars 3) (.const Const.unit) = [.var 2,.var 1,.var 0] := rfl
  rw [hvs,show liftMany 3 [] = [] from rfl,values_recheck]
  with_unfolding_all rfl

private theorem block_recheck (path : List Nat) :
    Check.checkBlockAt bodyInput [] [] [] [] [] (some (.base .unit)) .tail path (.discard call .empty) (.base .unit) Eff.empty expectedGuide = true := by
  simp only [Check.checkBlockAt,expectedGuide,Check.Hints.ty,List.getElem?_cons_zero,Option.getD_some]
  rw [call_recheck]
  with_unfolding_all rfl
private theorem guide_support : expectedGuide.Support StandardSupport.atoms := by
  simp only [expectedGuide,directGuide,argumentGuide,Check.Guide.Support,Check.GuidesSupport]
  repeat' constructor
  all_goals simp [standardResult,Ty.SupportList,Ty.Support,Eff.Support,Eff.empty,
    CheckArguments.ElemGuidesSupport,CheckArguments.ElemGuide.Support,CheckArguments.ArgGuide.Support,elementGuides,
    CheckArguments.HeadGuide.Support,CheckSubtyping.LeCertificate.Supported,
    CheckSubtyping.LeCertificate.source,CheckSubtyping.LeCertificate.target]

private theorem body_result (path : List Nat) :
    CheckDeclarations.bodyResult bodyInput [] [] [] [] path (.discard call .empty) (.base .unit) Eff.empty = .ok () := by
  unfold CheckDeclarations.bodyResult
  rw [body_inferred]
  change (if Check.checkBlockAt bodyInput [] [] [] [] [] (some (.base .unit)) .tail path
    (.discard call .empty) (.base .unit) Eff.empty (CheckFinite.guide bodyInput.formation.atoms (bodySynth path).guide)
    then (Except.ok () : Check.Result Unit) else _) = .ok ()
  rw [expected_guide,show bodyInput.formation.atoms = StandardSupport.atoms from rfl,
    CheckFinite.guide_eq _ _ guide_support,block_recheck]
  rfl

private theorem definition_check (path : List Nat) : CheckDeclarations.checkDef bodyInput path mainDef = .ok () := by
  have hc : CheckDeclarations.checkDefWith CheckDeclarations.bodyChecker (CheckDeclarations.definitionInput bodyInput mainDef) path mainDef = .ok () := by
    unfold CheckDeclarations.checkDefWith
    change Check.require path "function declaration or body is invalid"
      (true && (true && (true && (true && (true && CheckDeclarations.bodyChecker bodyInput [] [] [] [] (path ++ [1]) (.discard call .empty) (.base .unit) Eff.empty))))) = .ok ()
    simp only [CheckDeclarations.bodyChecker,body_result]
    rfl
  unfold CheckDeclarations.checkDef
  rw [hc]
  with_unfolding_all rfl

/-- 標準関数の署名を補った実入力で、checker の成功を各部分の実行結果から構成する。 -/
theorem checker_succeeds : CheckTables.checkProgram (input positiveExternals) (source positiveExternals) = .ok () := by
  unfold CheckTables.checkProgram
  have hv : CheckVariance.check (input positiveExternals).formation (input positiveExternals).D.core
      (input positiveExternals).dataNames (input positiveExternals).ctorNames = true := by rfl
  have he : CheckTables.effectsCheck (input positiveExternals) = true := rfl
  simp only [hv,he,Check.require,ite_true,Except.bind,Bind.bind]
  have hdefs : (input positiveExternals).defs = ["main"] := rfl
  have himpls : (input positiveExternals).impls = [] := rfl
  simp only [hdefs,himpls,CheckTables.checkNamed,main_lookup,Except.bind,Bind.bind]
  change ((CheckDeclarations.checkDef bodyInput [0,0] mainDef >>= fun _ => Except.ok ()) >>= fun _ => Except.ok ()) = .ok ()
  rw [definition_check]
  rfl

/-- 必須の判定の実行も成功する。 -/
theorem acceptance_succeeds : CheckAccept.acceptProgram acceptInput (input positiveExternals) (source positiveExternals) = .ok () := by
  with_unfolding_all rfl

/-- 実入口の成功を、型付けの検査と必須の判定の実行結果から導く。 -/
theorem entry_succeeds : CheckAccept.checkProgramAccepted (input positiveExternals) acceptInput (source positiveExternals) = .ok () := by
  simp only [CheckAccept.checkProgramAccepted,checker_succeeds,acceptance_succeeds]

/-- 完成した標準表の下で実入口の成功・受理・全主定理・main の開始を同時に満たす。 -/
theorem main_guarantees :
    CheckAccept.Accepted acceptInput (input positiveExternals) (source positiveExternals) ∧
    ProgramGuarantees (linked positiveExternals) (input positiveExternals).B environment ∧
    MainGuarantees (linked positiveExternals) (input positiveExternals).B environment Eff.empty := by
  apply checkProgramAccepted_main input_sound names_complete definitions_support
    (by intro i id hi; cases hi) (by intro i id hi; cases hi)
    (declarations_extend positiveExternals) accept_names_complete entry_succeeds
    nameLists_wf (data positiveExternals) rfl (includes positiveExternals) realizes
    (ApplicationExamples.noAssumptions_completion nameLists_wf _) positive_wf (wellFormed _ positive_wf)
  · exact ⟨mainDef,rfl,rfl,rfl,rfl,rfl,rfl,Or.inl rfl,rfl⟩
  · exact ready _ _

end
end Benitoite.Release.Refinement.Surface.CheckedMainExamples
