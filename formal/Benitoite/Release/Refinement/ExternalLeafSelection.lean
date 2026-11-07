import Benitoite.Release.Refinement.ExternalStateLeaves
import Benitoite.Release.Refinement.ExternalModels
import Benitoite.Release.Refinement.LeafInputs

/-!
# 型付きの外部呼出しの開始から応答・選択・一歩へ

元の状態の型付けが与えるストア型・宣言・実引数から外部の三条件へ進み、応答関係の存在、
実行関数が選ぶ応答、実行規則の一歩と行先の型付けを同じσ・継続・ストアで結ぶ。
主定理への合成は含めない（設計書 01-12「篩を含む状態の型付け」、07-04「篩を含む形式化の範囲」）。
-/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem external_declared {P B Ψ Q C Γ Φ R m a e L f ts vs}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) (hm : m = .externalCall f ts vs) :
    ∃ d, P.externalFunction f = some d := by
  match h with
  | .C_External hd _ _ _ => cases hm; exact ⟨_,hd⟩
  | .C_Sub hb _ _ _ _ _ => exact external_declared hb hm
  | .C_Eff hb _ => exact external_declared hb hm
  | .C_Normal hb => exact external_declared hb hm
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_App .. | .C_DependentApp .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm
termination_by structural h

/-- 状態の同じストア型から、外部宣言のlookupと型付きの実引数を取り出す。 -/
theorem StateTyE.external_args {P B σ Eb q f ts ws k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : Builtins.CoreAssumptions P B)
    (state : StateTyE P B σ Eb (.run q k μ)) (view : q.view = .externalCall f ts ws) :
    ∃ Ψ d a e, P.externalFunction f = some d ∧ ExternalArgs P B Ψ d ts ws a e := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,_,_,_,hcl,_,_⟩ := state
  obtain ⟨d,hd⟩ := external_declared
    (hq.external_view_typed hP hPB hB hs.wf hs.sorted hs.declared view) rfl
  obtain ⟨r,ef,ha,_,_⟩ := hq.external_view_inputs hP hPB hB hs.wf hs.sorted hs.declared hcl view hd
  exact ⟨Ψ,d,r,ef,hd,ha⟩

/-- 関係に属する任意の応答は、型付きの開始では受信がnoneにもexitにもならず、IO対象を生じない。 -/
theorem StateTyE.external_receive {P B σ Eb q f ts ws k μ out obs}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : Builtins.CoreAssumptions P B)
    (state : StateTyE P B σ Eb (.run q k μ)) (view : q.view = .externalCall f ts ws)
    (response : B.externalResponse f ts ws out obs) :
    ∃ d c, P.externalFunction f = some d ∧ externalReceive P d ts ws out = some c ∧
      (∀ n : Int, c ≠ .exit n) ∧ obs = [] := by
  obtain ⟨Ψ,d,a,e,hd,ha⟩ := state.external_args hP hPB hB view
  obtain ⟨c,hc,_,hn,ho⟩ := hB.toExternalAssumptions.receive hP.external hd ha response
  exact ⟨d,c,hd,hc,hn,ho⟩

/-- 関係に属する任意の応答から、受信の結果に従う外部の一歩と、同じσ・Ebでの行先の型付けを得る。 -/
theorem StateTyE.external_step_of_response {P B σ Eb q f ts ws k μ out obs}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : Builtins.CoreAssumptions P B)
    (state : StateTyE P B σ Eb (.run q k μ)) (view : q.view = .externalCall f ts ws)
    (response : B.externalResponse f ts ws out obs) :
    ∃ d dest, P.externalFunction f = some d ∧
      ((∃ v, externalReceive P d ts ws out = some (.val v) ∧ dest = .run (Closure.pure (.ret v)) k μ) ∨
        (∃ r, externalReceive P d ts ws out = some (.err r) ∧ dest = .error [r] k μ)) ∧
      Step P B σ (.run q k μ) none dest ∧ StateTyE P B σ Eb dest := by
  obtain ⟨d,c,hd,hc,hn,_⟩ := state.external_receive hP hPB hB view response
  cases c with
  | val v =>
    obtain ⟨step,typed⟩ := state.external_value_all hP hPB hB view hd response hc
    exact ⟨d,_,hd,.inl ⟨v,hc,rfl⟩,step,typed⟩
  | err r =>
    obtain ⟨step,typed⟩ := state.external_error_all view hd response hc
    exact ⟨d,_,hd,.inr ⟨r,hc,rfl⟩,step,typed⟩
  | exit n => exact (hn n rfl).elim

/-- 型付きの外部呼出しの開始には応答が存在し、その応答の一歩と行先の型付けがある。 -/
theorem StateTyE.external_response_step {P B σ Eb q f ts ws k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B)
    (hB : Builtins.CoreAssumptions P B)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .externalCall f ts ws) :
    ∃ out obs dest,
      B.externalResponse f ts ws out obs ∧ obs = [] ∧
      Step P B σ (.run q k μ) none dest ∧ StateTyE P B σ Eb dest := by
  obtain ⟨Ψ,d,a,e,hd,ha⟩ := state.external_args hP hPB hB view
  obtain ⟨out,obs,response⟩ := hB.toExternalAssumptions.external_exists Ψ f d ts ws a e hP.external hd ha
  obtain ⟨_,_,_,_,_,ho⟩ := state.external_receive hP hPB hB view response
  obtain ⟨_,dest,_,_,step,typed⟩ := state.external_step_of_response hP hPB hB view response
  exact ⟨out,obs,dest,response,ho,step,typed⟩

private theorem step_external_receive {P B σ oracle externalOracle rel fresh q f ts ws k μ d out}
    (view : q.view = .externalCall f ts ws) (lookup : P.externalFunction f = some d)
    (selected : externalOracle f ts ws = out) :
    step P B σ oracle externalOracle rel fresh (.run q k μ) =
      match externalReceive P d ts ws out.1 with
      | some (.val v) => some (none, .run (Closure.pure (.ret v)) k μ)
      | some (.err r) => some (none, .error [r] k μ)
      | _ => none := by
  simp only [step,view]
  change (match P.externalFunction f with
    | none => none
    | some d => match externalReceive P d ts ws (externalOracle f ts ws).1 with
      | some (.val v) => some ((none : Option Event), State.run (Closure.pure (.ret v)) k μ)
      | some (.err r) => some (none, State.error [r] k μ)
      | _ => none) = _
  rw [lookup,selected]

/-- 実行関数は型付きの開始で `B.selectExternal` の対を選び、その対は応答関係に属してIO対象を持たない。
計算した一歩は実行規則の一歩と同じ行先を返し、行先は同じσ・Ebで型付く。逆向きの完全性は含めない。 -/
theorem step_external_selected {P B σ Eb oracle rel fresh q f ts ws k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : Builtins.CoreAssumptions P B)
    (state : StateTyE P B σ Eb (.run q k μ)) (view : q.view = .externalCall f ts ws) :
    B.externalResponse f ts ws (B.selectExternal f ts ws).1 (B.selectExternal f ts ws).2 ∧
      (B.selectExternal f ts ws).2 = [] ∧
      ∃ dest, step P B σ oracle B.selectExternal rel fresh (.run q k μ) = some (none,dest) ∧
        Step P B σ (.run q k μ) none dest ∧ StateTyE P B σ Eb dest := by
  obtain ⟨Ψ,d,a,e,hd,ha⟩ := state.external_args hP hPB hB view
  have response := Builtins.selectExternal_response
    (hB.toExternalAssumptions.external_exists Ψ f d ts ws a e hP.external hd ha)
  obtain ⟨_,_,_,_,_,ho⟩ := state.external_receive hP hPB hB view response
  obtain ⟨d',dest,hd',shape,rule,typed⟩ := state.external_step_of_response hP hPB hB view response
  cases Option.some.inj (hd.symm.trans hd')
  have computed := step_external_receive (P := P) (B := B) (σ := σ) (oracle := oracle) (rel := rel)
    (fresh := fresh) (k := k) (μ := μ) view hd (out := B.selectExternal f ts ws) rfl
  refine ⟨response,ho,dest,?_,rule,typed⟩
  rw [computed]
  rcases shape with ⟨v,hv,rfl⟩ | ⟨r,hr,rfl⟩
  · rw [hv]
  · rw [hr]

/-- 外部参照の適用は、どの応答の選択でも同じ外部呼出しへ一歩進み、行先は同じσ・Ebで型付く。 -/
theorem step_external_apply {P B σ Eb oracle externalOracle rel fresh q f ts ws k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : Builtins.CoreAssumptions P B)
    (state : StateTyE P B σ Eb (.run q k μ)) (view : q.view = .app (.externalRef f ts) ws) :
    step P B σ oracle externalOracle rel fresh (.run q k μ) =
        some (none,.run (Closure.pure (.externalCall f ts ws)) k μ) ∧
      Step P B σ (.run q k μ) none (.run (Closure.pure (.externalCall f ts ws)) k μ) ∧
      StateTyE P B σ Eb (.run (Closure.pure (.externalCall f ts ws)) k μ) := by
  obtain ⟨rule,typed⟩ := state.external_apply_all hP hPB hB view
  refine ⟨?_,rule,typed⟩
  simp only [step,view]
  rfl

namespace ExternalLeafExamples
open ExternalModelExamples

/-- 二つの整数を宣言順に受け取り、Stateを持たない外部関数。 -/
def pairSignature : ExternalSignature :=
  ⟨⟨0⟩,"pair",[],[],.param "a" (.base .integer) (.param "b" (.base .integer)
    (.done (.base .integer) Eff.empty)),[]⟩

/-- 値に依存する篩 `0 < self` を結果に持つ外部関数、二引数の外部関数、外部型の宣言を持つ有限表。 -/
def program : Program :=
  ExternalNominal.program [(.function ⟨0⟩,.function ⟨0⟩ positiveSignature),
    (.function ⟨1⟩,.function ⟨1⟩ pairSignature),(.type ⟨0⟩,.type handleDeclaration)]

/-- 応答関係を外部宣言のcarrierで与える、資源のない模型の拡張表。 -/
def builtins : Builtins := ExternalModels.model program

theorem lookup : program.externalFunction ⟨0⟩ = some positiveSignature := rfl

theorem annotation : Ty.Annotation program [] [] positiveType := by
  constructor <;> simp [positiveType,Ty.WF,Ty.Sorted,Ty.Declared,Pred.WF,Pred.VarsIn,
    Pred.Sorted,Pred.Declared,Ty.NotContCore,Term.VarsIn,Term.HasSort,Term.References,
    Term.Shape,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Term.Declared,Ctx.declarationSelf,Ctx.extend,Ty.shiftV,Ty.core]

theorem signature_wf : positiveSignature.WF program := by
  refine ⟨rfl,rfl,?_,⟨by simp [positiveType,Ty.HasKind,Ty.NotContCore],by simp [kindsEff,kindsList,Eff.empty]⟩,?_,
    by simp [positiveSignature],.done (.refined (.scalar trivial)) rfl,?_⟩
  · exact ⟨⟨annotation.wf,trivial,rfl⟩,⟨annotation.sorted,trivial⟩,⟨annotation.declared,trivial⟩⟩
  · intro use
    simp only [positiveSignature,List.not_mem_nil,false_iff]
    intro site
    cases site with | result occurrence => cases occurrence with | refined h => cases h
  · exact ⟨trivial,by simp [Eff.RowsIn,Ty.RowsInList,Eff.empty]⟩

theorem pair_wf : pairSignature.WF program := by
  refine ⟨rfl,rfl,?_,?_,?_,by simp [pairSignature],?_,?_⟩
  · constructor
    all_goals dsimp [pairSignature,Ty.WF,Ty.Sorted,Tel.WF,Tel.Sorted,
      Ty.Declared,Tel.Declared,declaredEff,Ty.WFList,sortedEff,declaredTys,Eff.WF,Eff.empty,Eff.Canonical,
      Eff.norm,Ty.normTys,sortedTys]
    all_goals simp
  · simp [pairSignature,Ty.HasKind,kindsTel,kindsEff,kindsList,Eff.empty]
  · intro use
    simp only [pairSignature,List.not_mem_nil,false_iff]
    intro h
    cases h with
    | argument h => cases h
    | next h =>
      cases h with
      | argument h => cases h
      | next h => cases h with | result h => cases h
  · exact .param (.scalar trivial) (.param (.scalar trivial) (.done (.scalar trivial) rfl))
  · simp [pairSignature,Tel.RowsIn,Ty.RowsIn,Eff.RowsIn,Ty.RowsInList,Eff.empty]

theorem externalWF : program.ExternalWF := by
  refine ⟨by simp [program,ExternalNominal.program],?_⟩
  intro key decl mem
  change (key,decl) ∈ [_,_,_] at mem
  simp only [List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
  rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  · exact ⟨rfl,signature_wf⟩
  · exact ⟨rfl,pair_wf⟩
  · exact ⟨rfl,rfl⟩

theorem wellFormed : program.WellFormed where
  defs := by intro f d h; cases h
  cons := by intro c cd h; cases h
  ops := by intro o od h; cases h
  classes := by intro cl cd h; cases h
  impls := by intro i id h; cases h
  metadata := by intro d info h; cases h
  external := externalWF

theorem wellTyped : program.WellTyped builtins where
  variance := ⟨(by intro d info h; cases h),(by intro c cd h; cases h)⟩
  external := externalWF
  defs := by intro f d h; cases h
  impls := by intro i id h; cases h

theorem core : Builtins.CoreAssumptions program builtins := ExternalModels.model_core program

theorem bind_parameters :
    Tel.bind (typeEnv []) positiveSignature.parameters = .done positiveType Eff.empty := by
  have h := Tel.substAt_nil_of_wf (c := 0) [] positiveSignature.parameters ⟨annotation.wf,trivial,rfl⟩
  change Tel.bind (typeEnv []) positiveSignature.parameters = _ at h
  simpa only [positiveSignature,Tel.norm,show positiveType.norm = positiveType from rfl,
    show Eff.norm Eff.empty = Eff.empty from rfl] using h

theorem end_annotation : Ty.Annotation program [] [] (.dependentFn (.done positiveType Eff.empty)) :=
  ⟨⟨annotation.wf,trivial,rfl⟩,⟨annotation.sorted,trivial⟩,⟨annotation.declared,trivial⟩⟩

theorem admissible (B : Builtins) : ExternalCallAdmissible program B [] positiveSignature [] :=
  ⟨rfl,⟨rfl,by intros i t k hi; cases hi⟩,⟨rfl,by intros i t p hi; cases hi⟩,by simp [TypeAnnotations]⟩

theorem arguments (B : Builtins) (Ψ : StoreTy) :
    ExternalArgs program B Ψ positiveSignature [] [] positiveType Eff.empty := by
  refine ⟨admissible B,?_,by simp,by simp,⟨annotation.wf,rfl⟩,⟨trivial,rfl⟩⟩
  rw [bind_parameters]
  exact .done end_annotation

/-- 外部呼出しだけを持つ閉じた開始状態。 -/
def start : State := .run (Closure.pure (.externalCall ⟨0⟩ [] [])) [] Store.empty

/-- 外部参照の適用だけを持つ閉じた開始状態。 -/
def applyStart : State := .run (Closure.pure (.app (.externalRef ⟨0⟩ []) [])) [] Store.empty

private theorem closed_state {σ m}
    (hb : HasTypeC program builtins StoreTy.empty [] [] [] none m positiveType Eff.empty)
    (hc : m.ClosedAt 0 0) (had : m.Adequate σ) :
    StateTyE program builtins σ Eff.empty (.run (Closure.pure m) [] Store.empty) := by
  have hq := ClosureTy.pure hb end_annotation (by intro r hr; cases hr) rfl (by intro r hr; cases hr)
  exact ⟨StoreTy.empty,none,positiveType,positiveType,Eff.empty,Eff.empty,StoreOk.empty _ _ _,hq,
    ⟨fun _ h => h,fun _ h => h⟩,.K_Empty ⟨fun _ h => h,fun _ h => h⟩
      ⟨end_annotation.wf.1,end_annotation.sorted.1,end_annotation.declared.1⟩,
    ⟨trivial,had⟩,⟨trivial,hc⟩,(by intro f hf; cases hf),(by intro l c hc; cases hc)⟩

/-- 外部呼出しの開始は、同じ表で型付く。 -/
theorem start_typed (σ : PathEnv) : StateTyE program builtins σ Eff.empty start := by
  have args := arguments builtins StoreTy.empty
  exact closed_state (.C_External lookup signature_wf args.admissible args.arguments)
    (by simp [Comp.ClosedAt,Val.ClosedList]) (by trivial)

/-- 外部参照の適用の開始も、同じ宣言の参照の型から型付く。 -/
theorem applyStart_typed (σ : PathEnv) : StateTyE program builtins σ Eff.empty applyStart := by
  have args := arguments builtins StoreTy.empty
  have inst : SignatureInstance program [] [] positiveSignature.parameters positiveSignature.kinds [] [] :=
    ⟨⟨annotation.wf,trivial,rfl⟩,by simp [TypeAnnotations],⟨rfl,by intros i t k hi; cases hi⟩,
      (by intro e he; cases he),(by intro e he; cases he),by
        change Ty.Annotation program [] [] (.dependentFn (Tel.bind (typeEnv []) positiveSignature.parameters))
        rw [bind_parameters]; exact end_annotation⟩
  have ref := HasTypeVQ.V_ExternalRef (Ψ := StoreTy.empty) (Q := Qempty) (Φ := [])
    lookup signature_wf args.admissible inst
  exact closed_state (.C_DependentApp ref args.arguments)
    (by simp [Comp.ClosedAt,Val.ClosedAt,Val.ClosedList]) (by trivial)

theorem start_view :
    (Closure.pure (.externalCall ⟨0⟩ [] [])).view = .externalCall ⟨0⟩ [] [] := rfl
theorem apply_view :
    (Closure.pure (.app (.externalRef ⟨0⟩ []) [])).view = .app (.externalRef ⟨0⟩ []) [] := rfl

/-- 任意の整数を返す生の応答は、同じ拡張表の関係に属する。篩の検査は受信で行う。 -/
theorem integer_response (i : Integer64Value) :
    builtins.externalResponse ⟨0⟩ [] [] (.val (.const (.integer i))) [] :=
  ExternalModel.response_value lookup (arguments Model.builtins StoreTy.empty).instantiate
    (fun _ => .refined (.scalar (.V_Const trivial)) annotation) (by trivial)

theorem accept : externalReceive program positiveSignature [] []
    (.val (.const (.integer ⟨1,by decide⟩))) = some (.val (.const (.integer ⟨1,by decide⟩))) := by
  rw [externalReceive_of_args (arguments builtins StoreTy.empty)]
  simp [externalCheckedOutcome,positiveType,externalCheck,Const.type,Val.toTerm?,Ty.sort?,Pred.open,predBind,
    Pred.closedTrue,Pred.evalClosed,Pred.WF,Pred.VarsIn,Pred.Sorted,Pred.evalWith,
    Pred.atomValue,Pred.atomReady,Term.VarsIn,Term.HasSort,Term.References,Term.Shape,
    termReady,integerAs,Integer64Value.toInt,Term.observe,Observation.sort,observeAs,Term.interpret]

theorem reject : externalReceive program positiveSignature [] []
    (.val (.const (.integer ⟨0,by decide⟩))) = some (.err "ExternalRefinement") := by
  rw [externalReceive_of_args (arguments builtins StoreTy.empty)]
  simp [externalCheckedOutcome,positiveType,externalCheck,Const.type,Val.toTerm?,Ty.sort?,Pred.open,predBind,
    Pred.closedTrue,Pred.evalClosed,Pred.WF,Pred.VarsIn,Pred.Sorted,Pred.evalWith,
    Pred.atomValue,Pred.atomReady,Term.VarsIn,Term.HasSort,Term.References,Term.Shape,
    termReady,integerAs,Integer64Value.toInt,Term.observe,Observation.sort,observeAs,Term.interpret]

/-- 型付きの開始で外部の三葉はすべて到達する。正常値1は受理され、篩に反する0とerrは誤りへ進む。 -/
example (σ : PathEnv) (r : Benitoite.Release.ErrKind) :
    (Step program builtins σ start none (.run (Closure.pure (.ret (.const (.integer ⟨1,by decide⟩)))) [] Store.empty) ∧
      StateTyE program builtins σ Eff.empty
        (.run (Closure.pure (.ret (.const (.integer ⟨1,by decide⟩)))) [] Store.empty)) ∧
    (Step program builtins σ start none (.error ["ExternalRefinement"] [] Store.empty) ∧
      StateTyE program builtins σ Eff.empty (.error ["ExternalRefinement"] [] Store.empty)) ∧
    (Step program builtins σ start none (.error [r] [] Store.empty) ∧
      StateTyE program builtins σ Eff.empty (.error [r] [] Store.empty)) ∧
    (Step program builtins σ applyStart none start ∧ StateTyE program builtins σ Eff.empty start) := by
  have err := ExternalModel.receive_error_no_exit (arguments builtins StoreTy.empty) lookup r
  exact ⟨(start_typed σ).external_value_all wellFormed wellTyped core start_view lookup
      (integer_response _) accept,
    (start_typed σ).external_error_all start_view lookup (integer_response _) reject,
    (start_typed σ).external_error_all start_view lookup err.1 err.2.1,
    (applyStart_typed σ).external_apply_all wellFormed wellTyped core apply_view⟩

/-- 同じ型付きの開始で、応答の存在・選択した対の所属と計算した一歩・行先の型付けがそろう。 -/
example (σ : PathEnv) (oracle : Oracle) (rel : Val → Option Benitoite.Release.ErrKind)
    (fresh : Store → Nat) :
    (∃ out obs dest, builtins.externalResponse ⟨0⟩ [] [] out obs ∧ obs = [] ∧
      Step program builtins σ start none dest ∧ StateTyE program builtins σ Eff.empty dest) ∧
    (builtins.externalResponse ⟨0⟩ [] [] (builtins.selectExternal ⟨0⟩ [] []).1
        (builtins.selectExternal ⟨0⟩ [] []).2 ∧
      ∃ dest, step program builtins σ oracle builtins.selectExternal rel fresh start = some (none,dest) ∧
        Step program builtins σ start none dest ∧ StateTyE program builtins σ Eff.empty dest) ∧
    step program builtins σ oracle builtins.selectExternal rel fresh applyStart = some (none,start) := by
  have selected := step_external_selected (oracle := oracle) (rel := rel) (fresh := fresh)
    wellFormed wellTyped core (start_typed σ) start_view
  exact ⟨(start_typed σ).external_response_step wellFormed wellTyped core start_view,
    ⟨selected.1,selected.2.2⟩,
    (step_external_apply wellFormed wellTyped core (applyStart_typed σ) apply_view).1⟩

theorem pair_lookup : program.externalFunction ⟨1⟩ = some pairSignature := rfl

theorem pair_admissible (B : Builtins) (C : TypeCtx) : ExternalCallAdmissible program B C pairSignature [] :=
  ⟨rfl,⟨rfl,by intros i t k hi; cases hi⟩,⟨rfl,by intros i t p hi; cases hi⟩,by simp [TypeAnnotations]⟩

private theorem integer_annotation (Γ : Ctx) : Ty.Annotation program [] Γ (.base .integer) := by
  constructor <;> simp [Ty.WF,Ty.Sorted,Ty.Declared]

private theorem pair_bind :
    Tel.bind (typeEnv []) pairSignature.parameters = pairSignature.parameters := by
  have h := Tel.substAt_nil_of_wf (c := 0) [] pairSignature.parameters pair_wf.annotation.wf
  change Tel.bind (typeEnv []) pairSignature.parameters = _ at h
  exact h.trans rfl

private theorem rest_bind (v : Val) :
    Tel.bind (Tel.argumentsEnv v) (.param "b" (.base .integer) (.done (.base .integer) Eff.empty)) =
      .param "b" (.base .integer) (.done (.base .integer) Eff.empty) :=
  (Tel.bind_values_of_wf_zero (nr := 0) (nt := 0)
    (by simp [Tel.WF,Ty.WF,Eff.WF,Eff.empty,Eff.Canonical,Ty.WFList] <;> rfl) _).trans rfl

private theorem last_bind (v : Val) :
    Tel.bind (Tel.argumentsEnv v) (.done (.base .integer) Eff.empty) = .done (.base .integer) Eff.empty :=
  (Tel.bind_values_of_wf_zero (nr := 0) (nt := 0)
    (by simp [Tel.WF,Ty.WF,Eff.WF,Eff.empty,Eff.Canonical,Ty.WFList] <;> rfl) _).trans rfl

/-- 宣言順の二つの整数の実引数は、任意の文脈で同じ依存列に型付く。 -/
theorem pair_arguments (B : Builtins) (Ψ : StoreTy) (Γ : Ctx) (x y : Val)
    (first : HasTypeVQ program B Ψ Qempty [] Γ [] x (.base .integer))
    (second : HasTypeVQ program B Ψ Qempty [] Γ [] y (.base .integer)) :
    HasTypeTelArgsQ program B Ψ Qempty [] Γ [] [x,y]
      (Tel.bind (typeEnv []) pairSignature.parameters) (.base .integer) Eff.empty := by
  rw [pair_bind]
  refine .param (integer_annotation Γ) first ?_
  rw [rest_bind]
  refine .param (integer_annotation Γ) second ?_
  rw [last_bind]
  exact .done (by constructor <;> simp [Ty.WF,Tel.WF,Ty.Sorted,Tel.Sorted,Ty.Declared,Tel.Declared,
    Eff.WF,Eff.empty,Eff.Canonical,sortedEff,declaredEff,declaredTys,Ty.WFList,sortedTys] <;> rfl)

private theorem pair_instance (Γ : Ctx) :
    SignatureInstance program [] Γ pairSignature.parameters pairSignature.kinds [] [] :=
  ⟨pair_wf.annotation.wf,by simp [TypeAnnotations],⟨rfl,by intros i t k hi; cases hi⟩,
    (by intro e he; cases he),(by intro e he; cases he),by
      change Ty.Annotation program [] Γ (.dependentFn (Tel.bind (typeEnv []) pairSignature.parameters))
      rw [pair_bind]; exact pair_wf.annotation.closed_context⟩

private def one : Val := .const (.integer ⟨1,by decide⟩)
private def two : Val := .const (.integer ⟨2,by decide⟩)

private theorem one_typed (B : Builtins) (Ψ : StoreTy) (Γ : Ctx) :
    HasTypeVQ program B Ψ Qempty [] Γ [] one (.base .integer) := .V_Const trivial
private theorem two_typed (B : Builtins) (Ψ : StoreTy) (Γ : Ctx) :
    HasTypeVQ program B Ψ Qempty [] Γ [] two (.base .integer) := .V_Const trivial

private theorem swapped :
    Benitoite.Release.Refinement.Surface.recordFields pairSignature.parameters.arity [1,0] [two,one] (.const .unit) = [one,two] := rfl

/-- 型IDの参照: 宣言した型IDだけを受理し、未知のIDと型引数を持つ参照を同じ表で拒否する。 -/
example (C : TypeCtx) (Γ : Ctx) (args : List Ty) (nonempty : args ≠ []) :
    Ty.Declared program C Γ (.external ⟨0⟩ []) ∧
    ¬ Ty.Declared program C Γ (.external ⟨1⟩ []) ∧
    ¬ Ty.Declared program C Γ (.external ⟨0⟩ args) := by
  refine ⟨(ExternalSurface.type_declared_iff externalWF).mpr ⟨rfl,_,rfl⟩,?_,?_⟩
  · intro declared
    obtain ⟨_,td,lookup⟩ := (ExternalSurface.type_declared_iff externalWF).mp declared
    cases lookup
  · intro declared
    exact nonempty ((ExternalSurface.type_declared_iff externalWF).mp declared).1

/-- 外部名の参照: 宣言した名前は宣言の依存列の正規形で型付き、宣言のない名前はどの型でも型付かない。 -/
example (B : Builtins) (Ψ : StoreTy) (T : Ty) :
    HasTypeVQ program B Ψ Qempty [] [] [] (.externalRef ⟨1⟩ []) (.dependentFn (Tel.norm pairSignature.parameters)) ∧
    ExternalSurface.callEffect pairSignature = Eff.empty ∧
    ¬ HasTypeVQ program B Ψ Qempty [] [] [] (.externalRef ⟨2⟩ []) T := by
  obtain ⟨_,_,effect,typed⟩ := ExternalSurface.ref_of_lookup (Ψ := Ψ) (Q := Qempty) (Φ := [])
    externalWF pair_lookup (pair_admissible B []) (pair_instance [])
  refine ⟨typed,rfl,?_⟩
  intro bad
  obtain ⟨d,_,lookup,_⟩ := ExternalSurface.ref_inputs bad
  cases lookup

/-- 直接の飽和呼出しと名前付き引数: `pair(b = 2, a = 1)` は宣言順の `[1, 2]` へ並び、同じ表で型付く。 -/
example (B : Builtins) (Ψ : StoreTy) :
    Benitoite.Release.Refinement.Surface.recordFields pairSignature.parameters.arity [1,0] [two,one] (.const .unit) = [one,two] ∧
    HasTypeCQ program B Ψ Qempty [] [] [] none (.externalCall ⟨1⟩ [] [one,two]) (.base .integer) Eff.empty [] ∧
    Eff.empty = ExternalSurface.callEffect pairSignature ∧
    [one,two].length = pairSignature.parameters.arity := by
  have args := pair_arguments B Ψ [] one two (one_typed B Ψ []) (two_typed B Ψ [])
  have direct := ExternalSurface.call_of_lookup (R := none) (Δ := []) externalWF pair_lookup
    (pair_admissible B []) args
  rw [← swapped] at args
  obtain ⟨_,_,effect,typed⟩ := ExternalSurface.named_call (R := none) (Δ := [])
    (labels := [some "b",some "a"]) (.const .unit) externalWF pair_lookup (pair_admissible B [])
    (by decide) rfl rfl args
  rw [swapped] at typed
  exact ⟨swapped,typed,effect,direct.2.1⟩

/-- 穴を持つ部分適用: `pair(b = 2, a = _)` の生成ラムダの本体では、穴の引数（番号0）と2を宣言順に並べ、
外部参照の適用として型付く。 -/
example (B : Builtins) (Ψ : StoreTy) :
    HasTypeCQ program B Ψ Qempty [] (Ctx.extend [] (.base .integer)) [] none
      (.app (.externalRef ⟨1⟩ []) [.var 0,two]) (.base .integer) Eff.empty [] := by
  let Γ := Ctx.extend [] (.base .integer)
  have hole : HasTypeVQ program B Ψ Qempty [] Γ [] (.var 0) (.base .integer) := .V_Var rfl (by simp [Ordinary])
  have args := pair_arguments B Ψ Γ (.var 0) two hole (two_typed B Ψ Γ)
  have ordered : Benitoite.Release.Refinement.Surface.recordFields pairSignature.parameters.arity [1,0] [two,.var 0] (.const .unit) =
      [.var 0,two] := rfl
  rw [← ordered] at args
  obtain ⟨_,_,typed⟩ := ExternalSurface.partial_call (R := none) (Δ := []) (.const .unit) externalWF pair_lookup
    (pair_admissible B []) (pair_instance Γ) (by decide) rfl args
  rw [ordered] at typed
  exact typed

/-- 参照の型の依存列に沿う実引数は `TelClosure.apply` で宣言の依存列へ戻る。実際の開始状態も、外部参照の
適用の入力（同じ宣言の具体化と依存列に沿う実引数）を供給する。 -/
example (B : Builtins) (Ψ : StoreTy) (σ : PathEnv) :
    (∃ d b g, program.externalFunction ⟨1⟩ = some d ∧
      HasTypeTelArgsQ program B Ψ Qempty [] [] [] [one,two] (Tel.bind (typeEnv []) d.parameters) b g ∧
      Ty.LeQ program [] [] b (.base .integer)) ∧
    (∃ store result effects, HasTypeTelArgsQ program builtins store Qempty [] [] [] []
      (instantiatedTel positiveSignature.parameters [] []) result effects) := by
  obtain ⟨_,_,_,typed⟩ := ExternalSurface.ref_of_lookup (Ψ := Ψ) (Q := Qempty) (Φ := [])
    externalWF pair_lookup (pair_admissible B []) (pair_instance [])
  have args := pair_arguments B Ψ [] one two (one_typed B Ψ []) (two_typed B Ψ [])
  rw [pair_bind] at args
  obtain ⟨d,b,g,found,_,_,original,le,_⟩ :=
    ExternalSurface.ref_arguments (by intro i a h; cases h) typed rfl args
  obtain ⟨store,_,_,_,d',result,effects,_,_,found',_,_,_,inputs,_,_⟩ :=
    StateTyE.externalRef_contract_inputs wellFormed wellTyped core (applyStart_typed σ) apply_view
  cases Option.some.inj (lookup.symm.trans found')
  exact ⟨⟨d,b,g,found,original,le⟩,⟨store,result,effects,inputs⟩⟩

/-- 偽造を断る境界: 同じ表の外部型について、ハンドルの直接構築、表現を読むパターン、構成子値からの変換を拒否する。 -/
example (B : Builtins) (Ψ : StoreTy) (h : ExternalHandle) (c : ConName) (ps : List Pat) (vs : List Val) :
    ¬ (Val.externalHandle h []).Source ∧
    (∀ δ, ¬ PatTy program (.con c ps) (.external ⟨0⟩ []) δ) ∧
    ¬ HasTypeVQ program B Ψ Qempty [] [] [] (.con c [] vs) (.external ⟨0⟩ []) :=
  ⟨(ExternalSignatureLeaves.handle_not_source h [] 0 0 0 0).1,
    ExternalSignatureLeaves.non_binding_pattern_rejected program (.con c ps)
      (by intro e; cases e) (by intro e; cases e) ⟨0⟩ [],
    ExternalSignatureLeaves.constructor_value_rejected program B Ψ Qempty [] [] c [] vs ⟨0⟩ []⟩

end ExternalLeafExamples

end
end Benitoite.Release.Refinement
