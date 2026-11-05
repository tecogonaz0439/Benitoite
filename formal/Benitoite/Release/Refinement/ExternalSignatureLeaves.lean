import Benitoite.Release.Refinement.ExternalNominal
import Benitoite.Release.Refinement.ExternalSurfaceLeaves
import Benitoite.Release.Refinement.ExternalCheck
import Benitoite.Release.Refinement.Patterns
import Benitoite.Release.Refinement.SourceScope
import Benitoite.Release.Refinement.ResourceReleaseModel

/-! # 外部署名の使用位置とStateの宣言照合 -/
namespace Benitoite.Release.Refinement

/-- 引数の出現はborrow、結果の出現はownである。 -/
theorem ExternalUseAt.mode {P n tel use}
    (h : ExternalUseAt P n tel use) :
    (∀ i, use.position = .argument i → use.mode = .borrow) ∧
    (use.position = .result → use.mode = .own) := by
  induction h with
  | argument _ => exact ⟨by intros; rfl, by intro h; cases h⟩
  | next _ ih => exact ih
  | result _ => exact ⟨(by intro i h; cases h), (by intros; rfl)⟩

namespace ExternalSignatureLeaves

/-- 外部Mapの適格な鍵に外部型の出現はない。 -/
theorem key_no_occurrence {P a path id} (key : ExternalMapKey a) :
    ¬ ExternalOccurrence P a path id := by
  cases a with
  | base b => intro h; cases h
  | refined a p => intro h; cases h with | refined h => exact key_no_occurrence (a := a) key h
  | _ => cases key

/-- 全入れ子の出現は、同じcomponentの単相の型宣言へ戻る。 -/
theorem occurrence_declaration {P component unit a path id}
    (value : ExternalValueType P component unit a)
    (occurrence : ExternalOccurrence P a path id) :
    ∃ td, P.externalType id = some td ∧ td.component = component ∧
      td.id = id ∧ td.arity = 0 := by
  induction value generalizing path id with
  | scalar _ => cases occurrence
  | unit => cases occurrence
  | bytes => cases occurrence
  | handle lookup component same arity args =>
    cases occurrence
    exact ⟨_,lookup,component,same,arity⟩
  | list _ ih => cases occurrence with | element h => exact ih h
  | map key _ ih =>
    cases occurrence with
    | key h => exact (key_no_occurrence key h).elim
    | value h => exact ih h
  | flags _ _ _ _ _ _ _ => cases occurrence
  | data cs unique nonempty complete arity fields ih =>
    cases occurrence with
    | field lookup owner count slot h =>
      exact ih _ _ lookup owner _ (List.mem_of_getElem? slot) h
  | refined _ ih => cases occurrence with | refined h => exact ih h

/-- 宣言順の使用位置から、その出現を同じcomponentの型宣言へ戻す。 -/
theorem use_declaration {P component effect tel n use}
    (shape : ExternalTelWF P component effect tel)
    (site : ExternalUseAt P n tel use) :
    ∃ td, P.externalType use.typeId = some td ∧ td.component = component ∧
      td.id = use.typeId ∧ td.arity = 0 := by
  induction site with
  | argument occurrence =>
    cases shape with | param value _ => exact occurrence_declaration value occurrence
  | next _ ih => cases shape with | param _ rest => exact ih rest
  | result occurrence =>
    cases shape with | done value _ => exact occurrence_declaration value occurrence

/-- 八欄を持つ実署名は、使用列の全要素について所有と宣言を供給する。 -/
theorem declared_use {P d use} (wf : ExternalSignature.WF P d) (mem : use ∈ d.uses) :
    (∀ i, use.position = .argument i → use.mode = .borrow) ∧
    (use.position = .result → use.mode = .own) ∧
    ∃ td, P.externalType use.typeId = some td ∧ td.component = d.component ∧
      td.id = use.typeId ∧ td.arity = 0 := by
  have site := (wf.uses_exact use).mp mem
  exact ⟨site.mode.1,site.mode.2,use_declaration wf.shape site⟩

/-- handlesを使う署名の効果。IOの操作は加えない。 -/
def stateEffect : Eff :=
  .mk (fun a => match a with | .name n (.fixed .top) => decide (n = stateEff) | _ => false) []

def pureSignature (component : ComponentId) (name : String) : ExternalSignature :=
  ⟨component,name,[],[],.param "n" (.base .integer) (.done (.base .integer) Eff.empty),[]⟩

def handleSignature (component : ComponentId) (name : String) (id : ExternalId) : ExternalSignature :=
  ⟨component,name,[],[],.param "handle" (.external id []) (.done (.external id []) stateEffect),
    [⟨.argument 0,[],.borrow,id⟩,⟨.result,[],.own,id⟩]⟩

/-- scalarだけの依存列には、usesが要求する外部型の出現がない。 -/
theorem pure_wf (P : Program) (component : ComponentId) (name : String) :
    (pureSignature component name).WF P := by
  refine ⟨rfl,rfl,?_,?_,?_,by simp [pureSignature],?_,?_⟩
  · constructor
    all_goals dsimp [pureSignature,Ty.WF,Ty.Sorted,Tel.WF,Tel.Sorted,
      Ty.Declared,Tel.Declared,declaredEff,Ty.WFList,sortedEff,declaredTys,Eff.WF,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,sortedTys]
    all_goals simp
  · simp [pureSignature,Ty.HasKind,kindsTel,kindsEff,kindsList,Eff.empty]
  · intro use
    simp only [pureSignature,List.not_mem_nil,false_iff]
    intro h
    cases h with
    | argument h => cases h
    | next h => cases h with | result h => cases h
  · exact .param (.scalar trivial) (.done (.scalar trivial) rfl)
  · simp [pureSignature,Tel.RowsIn,Ty.RowsIn,Eff.RowsIn,Ty.RowsInList,Eff.empty]

/-- ハンドルの引数と結果には、それぞれ一つだけ使用位置がある。 -/
theorem handle_uses (P : Program) (n : Nat) (id : ExternalId) (use : ExternalUse) :
    ExternalUseAt P n (.param "handle" (.external id []) (.done (.external id []) stateEffect)) use ↔
      use = ⟨.argument n,[],.borrow,id⟩ ∨ use = ⟨.result,[],.own,id⟩ := by
  constructor
  · intro h
    cases h with
    | argument occurrence => cases occurrence; exact Or.inl rfl
    | next site => cases site with | result occurrence => cases occurrence; exact Or.inr rfl
  · rintro (rfl | rfl)
    · exact .argument .root
    · exact .next (.result .root)

/-- 型宣言の実lookupから、borrow/ownとStateを持つ単相署名を構成する。 -/
theorem handle_wf {P : Program} (td : ExternalTypeDecl)
    (lookup : P.externalType td.id = some td) (arity : td.arity = 0) (name : String) :
    (handleSignature td.component name td.id).WF P := by
  refine ⟨rfl,rfl,?_,?_,?_,?_,?_,?_⟩
  · constructor
    all_goals dsimp [handleSignature,Ty.WF,Ty.Sorted,Tel.WF,Tel.Sorted,
      Ty.Declared,Tel.Declared,declaredEff,Ty.WFList,sortedEff,declaredTys,Eff.WF,stateEffect,Eff.Canonical,Eff.norm,Ty.normTys,sortedTys]
    all_goals simp [lookup,arity]
  · simp [handleSignature,Ty.HasKind,kindsTel,kindsEff,kindsList,stateEffect]
  · intro use
    change (use ∈ [_,_]) ↔ _
    rw [List.mem_cons, List.mem_singleton]
    exact (handle_uses P 0 td.id use).symm
  · simp [handleSignature]
  · exact .param (.handle lookup rfl rfl arity rfl) (.done (.handle lookup rfl rfl arity rfl) rfl)
  · simp [handleSignature,Tel.RowsIn,Ty.RowsIn,Eff.RowsIn,Ty.RowsInList,stateEffect]

/-- 純粋外部とハンドルを使う外部を、同じ有限表へ収集する。 -/
def declarations (td : ExternalTypeDecl) (pure state : ExternalFunctionId) : Program :=
  ExternalNominal.program [(.type td.id,.type td),
    (.function pure,.function pure (pureSignature td.component "pure")),
    (.function state,.function state (handleSignature td.component "state" td.id))]

theorem declarations_wf (td : ExternalTypeDecl) (arity : td.arity = 0)
    (pure state : ExternalFunctionId) (different : pure ≠ state) :
    (declarations td pure state).ExternalWF := by
  have lookup : (declarations td pure state).externalType td.id = some td := by
    simp [declarations,ExternalNominal.program,Program.externalType]
  refine ⟨?_,?_⟩
  · simp [declarations,ExternalNominal.program,different]
  · intro key decl mem
    change (key,decl) ∈ [_,_,_] at mem
    simp only [List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · exact ⟨rfl,arity⟩
    · exact ⟨rfl,pure_wf _ _ _⟩
    · exact ⟨rfl,handle_wf td lookup arity _⟩

/-- 有限表のlookupを通して、八欄と全使用位置の供給を読む。 -/
theorem collected_contract {P f d} (wf : Program.ExternalWF P)
    (lookup : P.externalFunction f = some d) :
    d.tparams = [] ∧ d.kinds = [] ∧
    Ty.Annotation P [] [] (.dependentFn d.parameters) ∧
    Ty.HasKind P [] (.dependentFn d.parameters) .value ∧
    d.uses.Nodup ∧ d.parameters.RowsIn (· < 0) ∧
    (∀ use, use ∈ d.uses ↔ ExternalUseAt P 0 d.parameters use) ∧
    (∀ use ∈ d.uses,
      (∀ i, use.position = .argument i → use.mode = .borrow) ∧
      (use.position = .result → use.mode = .own) ∧
      ∃ td, P.externalType use.typeId = some td ∧ td.component = d.component ∧
        td.id = use.typeId ∧ td.arity = 0) := by
  have signature := wf.function_lookup lookup
  exact ⟨signature.monomorphic,signature.kinds,signature.annotation,signature.kinded,
    signature.uses_unique,signature.sourceTelRows,signature.uses_exact,
    fun _ mem => declared_use signature mem⟩

/-- 宣言順の後続位置と結果の位置を使って、borrow/ownを両方読む。 -/
example {P : Program} (td : ExternalTypeDecl)
    (lookup : P.externalType td.id = some td) (arity : td.arity = 0) :
    (∀ use ∈ (handleSignature td.component "state" td.id).uses,
      (∀ i, use.position = .argument i → use.mode = .borrow) ∧
      (use.position = .result → use.mode = .own) ∧
      ∃ td', P.externalType use.typeId = some td' ∧ td'.component = td.component ∧
        td'.id = use.typeId ∧ td'.arity = 0) ∧
    ExternalTelWF P td.component stateEffect
      (handleSignature td.component "state" td.id).parameters ∧
    ExternalTelWF P td.component Eff.empty
      (pureSignature td.component "pure").parameters := by
  have handle := handle_wf td lookup arity "state"
  exact ⟨fun _ mem => declared_use handle mem,handle.shape,(pure_wf P _ _).shape⟩

example (td : ExternalTypeDecl) (arity : td.arity = 0)
    (pure state : ExternalFunctionId) (different : pure ≠ state) :
    let P := declarations td pure state
    (∀ f d, P.externalFunction f = some d →
      d.uses.Nodup ∧ d.parameters.RowsIn (· < 0) ∧ d.tparams = [] ∧ d.kinds = []) := by
  intro P f d lookup
  obtain ⟨mono,kinds,_,_,unique,rows,_⟩ := collected_contract (declarations_wf td arity pure state different) lookup
  exact ⟨unique,rows,mono,kinds⟩

example (component : ComponentId) (f : ExternalFunctionId) :
    (ExternalNominal.program [(.function f,.function f (pureSignature component "pure"))]).ExternalWF :=
  (ExternalNominal.singleton_function _ _ _).mpr ⟨rfl,pure_wf _ _ _⟩

/-- 外部型を一欄に持つ有限のdata宣言。 -/
def boxProgram (td : ExternalTypeDecl) : Program :=
  { ExternalNominal.program [(.type td.id,.type td)] with
    cons := fun c => if c = "Box" then some ⟨"Box",0,[.external td.id []]⟩ else none }

theorem box_value_type (td : ExternalTypeDecl) (arity : td.arity = 0) (unit : Bool) :
    ExternalValueType (boxProgram td) td.component unit (.data "Box" []) := by
  apply ExternalValueType.data ["Box"]
  · simp
  · simp
  · intro c
    simp only [boxProgram]
    split
    · rename_i equal
      subst c
      simp
    · rename_i different
      simp [different]
  · constructor
    · exact ⟨"Box",⟨"Box",0,[.external td.id []]⟩,by simp [boxProgram],rfl⟩
    · intro c cd lookup owner
      dsimp [boxProgram] at lookup
      split at lookup
      · cases lookup; rfl
      · cases lookup
  · intro c cd lookup owner a mem
    dsimp [boxProgram] at lookup
    split at lookup
    · cases lookup
      simp only [List.mem_singleton] at mem
      subst a
      exact .handle (by simp [boxProgram,ExternalNominal.program,Program.externalType]) rfl rfl arity rfl
    · cases lookup

/-- root・element・value・field・refinedが同じ宣言へ戻る非空の読者。 -/
example (td : ExternalTypeDecl) (arity : td.arity = 0) :
    let P := boxProgram td
    let a := Ty.refined (.map (.base .string) (.list (.data "Box" []))) .truth
    ExternalValueType P td.component true a ∧
    ExternalOccurrence P a [.value,.element,.field "Box" 0] td.id ∧
    ∃ declaration, P.externalType td.id = some declaration ∧
      declaration.component = td.component ∧ declaration.id = td.id ∧ declaration.arity = 0 := by
  intro P a
  have value : ExternalValueType P td.component true a :=
    .refined (.map ⟨trivial,by decide,by decide⟩ (.list (box_value_type td arity false)))
  have occurrence : ExternalOccurrence P a [.value,.element,.field "Box" 0] td.id :=
    .refined (.value (.element (.field (cd := ⟨"Box",0,[.external td.id []]⟩) (by simp [P,boxProgram]) rfl rfl rfl .root)))
  exact ⟨value,occurrence,occurrence_declaration value occurrence⟩

/-- keyは構文上の出現を持つが、適格な外部Mapの鍵にはならない。 -/
example (P : Program) (id : ExternalId) (a : Ty) :
    ExternalOccurrence P (.map (.external id []) a) [.key] id ∧
    ¬ ExternalMapKey (.external id []) :=
  ⟨.key .root,fun key => key_no_occurrence key (.root (P := P))⟩

/-- usesが空の純粋署名にはStateを付けられない。 -/
example (P : Program) (component : ComponentId) (name : String) :
    ¬ ExternalSignature.WF P
      { pureSignature component name with
        parameters := .param "n" (.base .integer) (.done (.base .integer) stateEffect) } := by
  intro wf
  have shape := wf.shape
  cases shape with
  | param _ rest =>
    cases rest with
    | done _ equal =>
      have wrong := congrArg (fun e => e.atoms (.name stateEff (.fixed .top))) equal
      simp [pureSignature,stateEffect,Eff.atoms,Eff.empty] at wrong

/-- borrow/ownを列挙した署名のStateを空にできない。 -/
example (P : Program) (component : ComponentId) (id : ExternalId) (name : String) :
    ¬ ExternalSignature.WF P
      { handleSignature component name id with
        parameters := .param "handle" (.external id []) (.done (.external id []) Eff.empty) } := by
  intro wf
  have shape := wf.shape
  cases shape with
  | param _ rest =>
    cases rest with
    | done _ equal =>
      have wrong := congrArg (fun e => e.atoms (.name stateEff (.fixed .top))) equal
      simp [handleSignature,Eff.atoms,Eff.empty] at wrong

example {P d use i} (wf : ExternalSignature.WF P d) (mem : use ∈ d.uses)
    (position : use.position = .argument i) : use.mode ≠ .own := by
  have mode := (declared_use wf mem).1 i position
  simp [mode]

example {P d use} (wf : ExternalSignature.WF P d) (mem : use ∈ d.uses)
    (position : use.position = .result) : use.mode ≠ .borrow := by
  have mode := (declared_use wf mem).2.1 position
  simp [mode]

/-- 使用列から引数の出現を落とすと、uses_exactの逆向きで拒否される。 -/
example (P : Program) (component : ComponentId) (id : ExternalId) (name : String) :
    ¬ ExternalSignature.WF P { handleSignature component name id with uses := [] } := by
  intro wf
  have mem := (wf.uses_exact ⟨.argument 0,[],.borrow,id⟩).mpr (.argument .root)
  cases mem

example (P : Program) (component : ComponentId) (id : ExternalId) (name : String) :
    ¬ ExternalSignature.WF P { handleSignature component name id with uses :=
      [⟨.argument 0,[],.borrow,id⟩,⟨.argument 0,[],.borrow,id⟩,⟨.result,[],.own,id⟩] } := by
  intro wf
  have unique := wf.uses_unique
  simp at unique

/-- 宣言からの単相性は、呼出しの全型引数列を空にする。 -/
example {P B C f d ts} (wf : Program.ExternalWF P)
    (lookup : P.externalFunction f = some d)
    (admissible : ExternalCallAdmissible P B C d ts) : ts = [] :=
  admissible.types_nil (wf.function_lookup lookup)

/-- 同じ名目型の型付けは、componentとresourceの両方を照合する。 -/
theorem handle_typed_iff {P B Ψ Q C Γ Φ} (h : ExternalHandle) (td : ExternalTypeDecl)
    (lookup : P.externalType h.typeId = some td) (arity : td.arity = 0)
    (annotation : Ty.Annotation P C Γ (.external h.typeId [])) :
    HasTypeVQ P B Ψ Q C Γ Φ (.externalHandle h []) (.external h.typeId []) ↔
      td.component = h.component ∧ td.resource = h.resource := by
  constructor
  · intro typed
    obtain ⟨other,found,component,resource,_⟩ := typed.inv_externalHandle rfl
    have equal := Option.some.inj (found.symm.trans lookup)
    subst other
    exact ⟨component,resource⟩
  · rintro ⟨component,resource⟩
    exact .V_ExternalHandle h td lookup component resource arity.symm annotation

/-- 宣言と同じハンドルを実引数に持ち、ownの結果とStateを保つ入力。 -/
theorem handle_arguments {P : Program} (B : Builtins) (Ψ : StoreTy)
    (td : ExternalTypeDecl) (lookup : P.externalType td.id = some td)
    (arity : td.arity = 0) (identity : Nat) :
    ExternalArgs P B Ψ (handleSignature td.component "state" td.id) []
      [.externalHandle ⟨td.id,td.component,td.resource,identity⟩ []]
      (.external td.id []) stateEffect := by
  have annotation : Ty.Annotation P [] [] (.external td.id []) :=
    ⟨trivial,trivial,⟨⟨td,lookup,rfl,arity.symm⟩,trivial⟩⟩
  have endAnnotation : Ty.Annotation P [] [] (.dependentFn (.done (.external td.id []) stateEffect)) := by
    constructor
    · exact ⟨trivial,trivial,rfl⟩
    · trivial
    · exact ⟨annotation.declared,trivial⟩
  have typed := (handle_typed_iff (B := B) (Ψ := Ψ) (Q := Qempty) (Φ := [])
    ⟨td.id,td.component,td.resource,identity⟩ td lookup arity annotation).mpr ⟨rfl,rfl⟩
  refine ⟨?_,?_,?_,by simp,⟨trivial,rfl⟩,⟨trivial,rfl⟩⟩
  · exact ⟨rfl,⟨rfl,by intros i t k hi; cases hi⟩,⟨rfl,by intros i t p hi; cases hi⟩,by simp [TypeAnnotations]⟩
  · have doneArgs := HasTypeTelArgsQ.done (B := B) (Ψ := Ψ) (Q := Qempty) (Φ := []) endAnnotation
    have tail : HasTypeTelArgsQ P B Ψ Qempty [] [] [] []
        (Tel.bind (Tel.argumentsEnv (.externalHandle ⟨td.id,td.component,td.resource,identity⟩ []))
          (.done (.external td.id []) stateEffect)) (.external td.id []) stateEffect := by
      simpa only [Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Tel.norm,Ty.norm,Ty.normTys,
        stateEffect,Eff.rawBind,Tel.argumentsEnv,valEnv,instAtoms_nil,substAtoms_nil,rowFails,
        List.length_nil,List.range_zero,List.filter_nil,List.flatMap_nil,List.append_nil,
        Eff.norm,Order.sortUnique] using doneArgs
    have args := HasTypeTelArgsQ.param (name := "handle") annotation typed tail
    simpa only [handleSignature,Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Tel.norm,Ty.norm,
      Ty.normTys,stateEffect,Eff.rawBind,typeEnv,typeEnvAt,SubstEnv.up,instAtoms_nil,substAtoms_nil,
      List.map_nil,rowFails,List.length_nil,List.range_zero,List.filter_nil,List.flatMap_nil,
      List.append_nil,Eff.norm,Order.sortUnique] using args
  · intro v mem
    simp only [List.mem_singleton] at mem
    subst v
    simp [Val.Ground,Val.ClosedAt]

/-- 同じ実引数の導出を、表層の外部固有の直接呼出しへ渡す。 -/
theorem handle_call_typed {P : Program} (B : Builtins) (Ψ : StoreTy)
    (td : ExternalTypeDecl) (lookup : P.externalType td.id = some td)
    (arity : td.arity = 0) (identity : Nat) (f : ExternalFunctionId)
    (function : P.externalFunction f = some (handleSignature td.component "state" td.id)) :
    HasTypeCQ P B Ψ Qempty [] [] [] none
      (.externalCall f [] [.externalHandle ⟨td.id,td.component,td.resource,identity⟩ []])
      (.external td.id []) stateEffect [] := by
  have args := handle_arguments B Ψ td lookup arity identity
  exact ExternalSurface.call_typed function (handle_wf td lookup arity _) args.admissible args.arguments

/-- 同じIDでもcomponent/resourceが異なるハンドルは、任意の結果型で拒否する。 -/
theorem mismatched_handle {P B Ψ Q C Γ Φ h ts T td}
    (lookup : P.externalType h.typeId = some td)
    (mismatch : td.component ≠ h.component ∨ td.resource ≠ h.resource) :
    ¬ HasTypeVQ P B Ψ Q C Γ Φ (.externalHandle h ts) T := by
  intro typed
  obtain ⟨other,found,component,resource,_⟩ := typed.inv_externalHandle rfl
  have equal := Option.some.inj (found.symm.trans lookup)
  subst other
  exact mismatch.elim (· component) (· resource)

/-- 表層構文と四名前空間の検査は、外部ハンドルの直接構築を受け入れない。 -/
theorem handle_not_source (h : ExternalHandle) (ts : List Ty) (nr nt ne nv : Nat) :
    ¬ (Val.externalHandle h ts).Source ∧
      ¬ (Val.externalHandle h ts).SourceScoped nr nt ne nv := ⟨id,id⟩

private theorem pattern_observation_not_external {P p a δ}
    (typed : PatTy P p a δ) (wild : p ≠ .wild) (notVar : p ≠ .var) :
    ∀ id args, a.observationType ≠ .external id args := by
  match typed with
  | .P_Convert equal sub =>
    have converted := congrArg Ty.observationType equal
    simp only [Ty.observationType_norm] at converted
    rw [← converted]
    exact pattern_observation_not_external sub wild notVar
  | .P_Refined sub =>
    have ih := pattern_observation_not_external sub wild notVar
    exact ih
  | .P_Wild => exact (wild rfl).elim
  | .P_Var => exact (notVar rfl).elim
  | .P_Const (c := c) _ =>
    cases c <;> simp [embedConst, Const.type, Ty.observationType]
  | .P_RangeInt | .P_RangeChar | .P_List .. | .P_Con .. =>
    intro id args equal
    cases equal

/-- wildcardと変数以外の全パターンは、変換と篩を介しても外部型に型付かない。 -/
theorem non_binding_pattern_rejected (P : Program) (p : Pat)
    (wild : p ≠ .wild) (notVar : p ≠ .var)
    (id : ExternalId) (args : List Ty) (δ : List Ty) :
    ¬ PatTy P p (.external id args) δ := by
  intro typed
  exact pattern_observation_not_external typed wild notVar id [] rfl

/-- 空の値文脈で型付く構成子値は、全構成子・全欄・全型引数で外部型にならない。 -/
theorem constructor_value_rejected (P : Program) (B : Builtins) (Ψ : StoreTy)
    (Q : NoFailCtx) (C : TypeCtx) (Φ : List Pred) (c : ConName) (ts : List Ty)
    (vs : List Val) (id : ExternalId) (args : List Ty) :
    ¬ HasTypeVQ P B Ψ Q C [] Φ (.con c ts vs) (.external id args) := by
  intro typed
  obtain ⟨h,us,equal⟩ := typed.canonical_external rfl
  cases equal

/-- 任意のハンドルと型引数列は、通常資源の解放関係に属さない。 -/
theorem handle_not_release (h : ExternalHandle) (ts : List Ty)
    (isResource : Benitoite.Release.OpaqueName → Bool) (r : Option Benitoite.Release.ErrKind) :
    ¬ ResourceRelease.response isResource (.externalHandle h ts) r := by
  rintro ⟨o,i,equal,_⟩
  cases equal

/-- 同じ宣言の型付けと、通常資源の解放関係への非所属とSourceの拒否を併せて読む。 -/
example (td : ExternalTypeDecl) (arity : td.arity = 0) (identity : Nat)
    (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx) (Φ : List Pred)
    (isResource : Benitoite.Release.OpaqueName → Bool) (r : Option Benitoite.Release.ErrKind) :
    let P := ExternalNominal.program [(.type td.id,.type td)]
    let h : ExternalHandle := ⟨td.id,td.component,td.resource,identity⟩
    HasTypeVQ P B Ψ Q [] [] Φ (.externalHandle h []) (.external td.id []) ∧
    ¬ ResourceRelease.response isResource (.externalHandle h []) r ∧
    ¬ (Val.externalHandle h []).Source := by
  intro P h
  have lookup : P.externalType h.typeId = some td := by
    simp [P,h,ExternalNominal.program,Program.externalType]
  have annotation : Ty.Annotation P [] [] (.external h.typeId []) := by
    constructor
    · trivial
    · trivial
    · exact ⟨⟨td,lookup,rfl,arity.symm⟩,trivial⟩
  exact ⟨(handle_typed_iff h td lookup arity annotation).mpr ⟨rfl,rfl⟩,
    handle_not_release h [] isResource r, (handle_not_source h [] 0 0 0 0).1⟩

/-- 異種のcomponentとresourceは、それぞれ独立に拒否される。 -/
example {P B Ψ Q C Γ Φ h ts T td} (lookup : P.externalType h.typeId = some td)
    (component : td.component ≠ h.component) :
    ¬ HasTypeVQ P B Ψ Q C Γ Φ (.externalHandle h ts) T :=
  mismatched_handle lookup (Or.inl component)

example {P B Ψ Q C Γ Φ h ts T td} (lookup : P.externalType h.typeId = some td)
    (resource : td.resource ≠ h.resource) :
    ¬ HasTypeVQ P B Ψ Q C Γ Φ (.externalHandle h ts) T :=
  mismatched_handle lookup (Or.inr resource)

/-- 型を保つ変数・wildcardと、表現を読む構成子パターンの境界。 -/
example (P : Program) (id : ExternalId) (args : List Ty) (c : ConName) (ps : List Pat) :
    PatTy P .wild (.external id args) [] ∧
    PatTy P .var (.external id args) [.external id args] ∧
    (∀ δ, ¬ PatTy P (.con c ps) (.external id args) δ) :=
  ⟨.P_Wild,.P_Var,non_binding_pattern_rejected P (.con c ps) (by intro h; cases h) (by intro h; cases h) id args⟩

/-- 引数を持たない具体の構成子値も外部型にはならない。 -/
example (P : Program) (B : Builtins) (Ψ : StoreTy) (id : ExternalId) :
    ¬ HasTypeVQ P B Ψ Qempty [] [] [] (.con "Null" [] []) (.external id []) :=
  constructor_value_rejected P B Ψ Qempty [] [] "Null" [] [] id []

example (td : ExternalTypeDecl) (arity : td.arity = 0) (pure state : ExternalFunctionId)
    (different : pure ≠ state) (B : Builtins) (Ψ : StoreTy) (identity : Nat) :
    let P := declarations td pure state
    HasTypeCQ P B Ψ Qempty [] [] [] none
      (.externalCall state [] [.externalHandle ⟨td.id,td.component,td.resource,identity⟩ []])
      (.external td.id []) stateEffect [] := by
  apply handle_call_typed B Ψ td _ arity identity state
  · simp [declarations,ExternalNominal.program,Program.externalFunction,List.lookup,BEq.beq,Ne.symm different]
  · simp [declarations,ExternalNominal.program,Program.externalType]

/-- 外部関数を含む同じ有限表に、borrowの実引数とownの結果を供給する。 -/
example (td : ExternalTypeDecl) (arity : td.arity = 0) (pure state : ExternalFunctionId)
    (different : pure ≠ state) (B : Builtins) (Ψ : StoreTy) (identity : Nat) :
    let P := declarations td pure state
    P.ExternalWF ∧
    ExternalArgs P B Ψ (handleSignature td.component "state" td.id) []
      [.externalHandle ⟨td.id,td.component,td.resource,identity⟩ []] (.external td.id []) stateEffect := by
  intro P
  exact ⟨declarations_wf td arity pure state different,
    handle_arguments B Ψ td (by simp [P,declarations,ExternalNominal.program,Program.externalType]) arity identity⟩

end ExternalSignatureLeaves
end Benitoite.Release.Refinement
