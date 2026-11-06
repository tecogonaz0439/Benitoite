import Benitoite.Release.Refinement.IntervalFlowLeaves
import Benitoite.Release.Refinement.FirstFailure
import Benitoite.Release.Refinement.LeafInputs

/-! # 型付きの正常値・return・制御の所属 -/
namespace Benitoite.Release.Refinement.IntervalControlLeaves
open Benitoite.Interval Shared IntervalConnection IntervalFlowLeaves
noncomputable section

/-- 同じ実開始の ClosureTy から ret の値型を取り出し、所属を同じ値へ移す。 -/
theorem normal_state_member {P B σ Eb q k μ c v} {f : FlowApprox}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (source : StateTyE P B σ Eb (.run q k μ)) (view : q.view = .ret v)
    (related : ValueRel c v) (mem : f.NormalMem c.toApprox) :
    (∃ Ψ R a e, StoreOk P B σ Ψ μ ∧ ClosureTy P B Ψ [] R q a e ∧
      HasTypeVQ P B Ψ Qempty [] [] [] v a) ∧ f.NormalMem v.toApprox := by
  obtain ⟨Ψ,R,a,b,e,ec,store,typed,_⟩ := source
  exact ⟨⟨Ψ,R,a,ec,store,typed,
    typed.ret_view_typed hP hPB hB store.wf store.sorted store.declared view⟩,
    normal_mem_of_related related mem⟩

private theorem typed_control {P B σ Eb s ev dest}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (source : StateTyE P B σ Eb s) (input : ControlLeafInputs P B σ s ev dest) :
    Step P B σ s ev dest ∧ StateTyE P B σ Eb dest ∧ dest.Inputs P B σ Eb := by
  obtain ⟨step,typed,_⟩ := source.control_leaf hP hPB hB input
  exact ⟨step,typed,typed.inputs⟩

/-- let を飛ばす return は、同じ値の returned 所属を保つ。 -/
theorem escape_let_member {P B σ Eb q n k μ c v} {f : FlowApprox}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (source : StateTyE P B σ Eb (.run q (.letF n :: k) μ)) (view : q.view = .escape v)
    (related : ValueRel c v) (mem : f.ReturnedMem c.toApprox) :
    Step P B σ (.run q (.letF n :: k) μ) none (.run (Closure.pure (.escape v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.escape v)) k μ) ∧
    EndState (fun _ _ => False) (.returned c) k (.run (Closure.pure (.escape v)) k μ) ∧
    f.ReturnedMem (closeVal Capture.empty v).toApprox := by
  obtain ⟨step,typed,_⟩ := typed_control hP hPB hB source (.E_EscLet view)
  exact ⟨step,typed,⟨Closure.pure (.escape v),μ,closeVal Capture.empty v,rfl,rfl,
    related.close _⟩,returned_mem_of_related (related.close _) mem⟩

theorem escape_handler_member {P B σ Eb q cap handler k μ c v} {f : FlowApprox}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (source : StateTyE P B σ Eb (.run q (.handleF cap handler :: k) μ)) (view : q.view = .escape v)
    (related : ValueRel c v) (mem : f.ReturnedMem c.toApprox) :
    Step P B σ (.run q (.handleF cap handler :: k) μ) none (.run (Closure.pure (.escape v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.escape v)) k μ) ∧
    EndState (fun _ _ => False) (.returned c) k (.run (Closure.pure (.escape v)) k μ) ∧
    f.ReturnedMem (closeVal Capture.empty v).toApprox := by
  obtain ⟨step,typed,_⟩ := typed_control hP hPB hB source (.E_EscHandle view)
  exact ⟨step,typed,⟨Closure.pure (.escape v),μ,closeVal Capture.empty v,rfl,rfl,
    related.close _⟩,returned_mem_of_related (related.close _) mem⟩

/-- mark は同じ returned 値を通常値へ移し、その値型を元の状態から読む。 -/
theorem escape_mark_member {P B σ Eb q k μ c v} {f : FlowApprox}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (source : StateTyE P B σ Eb (.run q (.mark :: k) μ)) (view : q.view = .escape v)
    (related : ValueRel c v) (mem : f.ReturnedMem c.toApprox) :
    Step P B σ (.run q (.mark :: k) μ) none (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) ∧
    EndState (fun _ _ => False) (.normal c) k (.run (Closure.pure (.ret v)) k μ) ∧
    (normalF f.returned).NormalMem (closeVal Capture.empty v).toApprox ∧
    (∃ Ψ R a e, StoreOk P B σ Ψ μ ∧
      ClosureTy P B Ψ [] R (Closure.pure (.ret v)) a e ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (closeVal Capture.empty v) a) := by
  obtain ⟨typed,ending⟩ := typed_returned_mark hP hPB hB source view related
  obtain ⟨step,_,_⟩ := typed_control hP hPB hB source (.E_EscMark view)
  obtain ⟨value,inside⟩ := normal_state_member hP hPB hB typed rfl (related.close _)
    (show (normalF f.returned).NormalMem c.toApprox from mem)
  exact ⟨step,typed,ending,inside,value⟩

/-- error の同じ理由列での遷移と型付けは、元の状態の型付けだけから得る。 -/
theorem error_let_typed {P B σ Eb errors n k μ}
    (source : StateTyE P B σ Eb (.error errors (.letF n :: k) μ)) :
    Step P B σ (.error errors (.letF n :: k) μ) none (.error errors k μ) ∧
    StateTyE P B σ Eb (.error errors k μ) := by
  obtain ⟨step,typed⟩ := source.error_let
  exact ⟨step,typed⟩

/-- mark を外しても、error の同じ理由列と型付けを保つ。 -/
theorem error_mark_typed {P B σ Eb errors k μ}
    (source : StateTyE P B σ Eb (.error errors (.mark :: k) μ)) :
    Step P B σ (.error errors (.mark :: k) μ) none (.error errors k μ) ∧
    StateTyE P B σ Eb (.error errors k μ) := by
  obtain ⟨step,typed⟩ := source.error_mark
  exact ⟨step,typed⟩

/-- exit の理由列と終了値はそのまま保ち、正常値の所属を作らない。 -/
theorem exit_let_typed {P B σ Eb code errors n k μ}
    (source : StateTyE P B σ Eb (.exit code errors (.letF n :: k) μ)) :
    Step P B σ (.exit code errors (.letF n :: k) μ) none (.exit code errors k μ) ∧
    StateTyE P B σ Eb (.exit code errors k μ) ∧ (State.exit code errors k μ).Inputs P B σ Eb := by
  obtain ⟨step,typed⟩ := source.exit_let
  exact ⟨step,typed,typed.inputs⟩

theorem exit_mark_typed {P B σ Eb code errors k μ}
    (source : StateTyE P B σ Eb (.exit code errors (.mark :: k) μ)) :
    Step P B σ (.exit code errors (.mark :: k) μ) none (.exit code errors k μ) ∧
    StateTyE P B σ Eb (.exit code errors k μ) ∧ (State.exit code errors k μ).Inputs P B σ Eb := by
  obtain ⟨step,typed⟩ := source.exit_mark
  exact ⟨step,typed,typed.inputs⟩

example {P B σ Eb q n k μ c v} {f : FlowApprox}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (source : StateTyE P B σ Eb (.run q (.letF n :: k) μ)) (view : q.view = .escape v)
    (related : ValueRel c v) (mem : f.ReturnedMem c.toApprox) :=
  escape_let_member hP hPB hB source view related mem

example {P B σ Eb q cap handler k μ c v} {f : FlowApprox}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (source : StateTyE P B σ Eb (.run q (.handleF cap handler :: k) μ)) (view : q.view = .escape v)
    (related : ValueRel c v) (mem : f.ReturnedMem c.toApprox) :=
  escape_handler_member hP hPB hB source view related mem

example {P B σ Eb q k μ c v} {f : FlowApprox}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (source : StateTyE P B σ Eb (.run q (.mark :: k) μ)) (view : q.view = .escape v)
    (related : ValueRel c v) (mem : f.ReturnedMem c.toApprox) :=
  escape_mark_member hP hPB hB source view related mem

example {P B σ Eb errors n k μ}
    (source : StateTyE P B σ Eb (.error errors (.letF n :: k) μ)) :=
  error_let_typed source

example {P B σ Eb errors k μ}
    (source : StateTyE P B σ Eb (.error errors (.mark :: k) μ)) :=
  error_mark_typed source

example {P B σ Eb code errors n k μ}
    (source : StateTyE P B σ Eb (.exit code errors (.letF n :: k) μ)) :=
  exit_let_typed source

example {P B σ Eb code errors k μ}
    (source : StateTyE P B σ Eb (.exit code errors (.mark :: k) μ)) :=
  exit_mark_typed source

/-- 同じ Boolean の実 return の所属を、型付き mark の通常値へ渡す。 -/
theorem boolean_mark {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B)
    (hB : B.CoreAssumptions P) (env : ConcreteEnv) (key : OperationKey) :
    EvalPartial env ⟨.returnE (.base .boolean) (.literal (.boolean true)),.base .boolean,key⟩
      (.returned (.boolean true)) [] ∧
    Step P B σ (.run (Closure.pure (.escape (.const (.boolean true)))) [.mark] Store.empty) none
      (.run (Closure.pure (.ret (.const (.boolean true)))) [] Store.empty) ∧
    StateTyE P B σ Eff.empty (.run (Closure.pure (.ret (.const (.boolean true)))) [] Store.empty) ∧
    (normalF (returnF (normalF (.boolean false true))).returned).NormalMem (.boolean true) := by
  have annotation : Ty.Annotation P [] [] (.base .boolean) := ⟨trivial,trivial,trivial⟩
  have closure := ClosureTy.pure (B := B) (Ψ := StoreTy.empty)
    (.C_Escape (ε := Eff.empty) (.V_Const (c := .boolean true) (by trivial)) annotation)
    annotation.done_empty (by intro r hr; cases hr; exact ⟨trivial,trivial⟩) rfl
    (by intro r hr; cases hr; rfl)
  have cont := ContTy.K_Mark (ContTy.K_Empty (R := none) (P := P) (B := B) (σ := σ)
    (Ψ := StoreTy.empty) (show Eff.Sub Eff.empty Eff.empty from ⟨fun _ h => h,fun _ h => h⟩)
    annotation) annotation
  have source : StateTyE P B σ Eff.empty
      (.run (Closure.pure (.escape (.const (.boolean true)))) [.mark] Store.empty) :=
    ⟨StoreTy.empty,some (.base .boolean),.base .boolean,.base .boolean,Eff.empty,Eff.empty,
      StoreOk.empty _ _ σ,closure,⟨fun _ h => h,fun _ h => h⟩,cont,by trivial,by trivial,
      (by intro f hf; cases List.mem_singleton.mp hf; trivial),(by intro l c h; cases h)⟩
  obtain ⟨evaluated,mem,_⟩ := boolean_return env key true
  obtain ⟨step,typed,_,inside,_⟩ := escape_mark_member hP hPB hB source rfl (.boolean true) mem
  exact ⟨evaluated,step,typed,inside⟩

example (env : ConcreteEnv) (key : OperationKey) :
    ∃ P B σ, P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ σ.Valid ∧
      EvalPartial env ⟨.returnE (.base .boolean) (.literal (.boolean true)),.base .boolean,key⟩
        (.returned (.boolean true)) [] ∧
      Step P B σ (.run (Closure.pure (.escape (.const (.boolean true)))) [.mark] Store.empty) none
        (.run (Closure.pure (.ret (.const (.boolean true)))) [] Store.empty) ∧
      StateTyE P B σ Eff.empty (.run (Closure.pure (.ret (.const (.boolean true)))) [] Store.empty) ∧
      (normalF (returnF (normalF (.boolean false true))).returned).NormalMem (.boolean true) := by
  obtain ⟨σ,hσ,hP,hPB,hB,_⟩ := NormalReplyExamples.concrete_normal_replies
  exact ⟨_,_,σ,hP,hPB,hB,hσ,boolean_mark hP hPB hB env key⟩

/-- 型付きの同じ開始と有限実行を、最初の失敗の受渡しへ接続する。 -/
theorem typed_first_failure {P B σ Eb q k μ events errors lastK lastStore}
    (source : StateTyE P B σ Eb (.run q k μ))
    (run : Steps P B σ (.run q k μ) events (.error errors lastK lastStore)) :
    (State.run q k μ).Inputs P B σ Eb ∧
    ∃ (preEvents : List Event) (before : State) (event : Option Event)
      (firstErrors : List ErrKind) (firstK : Cont) (firstStore : Store) (suffix : List Event),
      H04.BeforeErrorSteps P B σ (.run q k μ) preEvents before ∧
      Step P B σ before event (.error firstErrors firstK firstStore) ∧
      Steps P B σ (.error firstErrors firstK firstStore) suffix (.error errors lastK lastStore) ∧
      events = preEvents ++ event.toList ++ suffix ∧
      ∀ (focus : Closure) (atK : Cont) (atStore : Store) (b : PrimName)
        (ts : List Ty) (es : List Eff) (ranges : List RangeExpr) (ws : List Val) (sg : PrimSig),
        before = .run focus atK atStore → focus.view = .app (.prim b ts es (List.map RangeIx.fixed ranges)) ws →
        B.sig b = some sg → sg.kind = .pure →
        event = none ∧ ∃ r, firstErrors = [r] ∧
          B.delta b (Ty.normTys ts) (es.map Eff.norm) ranges ws = some (.err r) :=
  ⟨source.inputs,H04.first_failure_handoff P B σ q k μ events errors lastK lastStore run⟩

example {P B σ Eb q k μ events errors lastK lastStore}
    (source : StateTyE P B σ Eb (.run q k μ))
    (run : Steps P B σ (.run q k μ) events (.error errors lastK lastStore)) :=
  typed_first_failure source run

end
end Benitoite.Release.Refinement.IntervalControlLeaves
