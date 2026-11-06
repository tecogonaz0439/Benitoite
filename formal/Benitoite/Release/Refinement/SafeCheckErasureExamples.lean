import Benitoite.Release.Refinement.SafeCheckObservations
import Benitoite.Release.Refinement.SurfaceMainExamples

/-! # 完成した表での消去と、ラムダを保持する具体の入力 -/
namespace Benitoite.Release.Refinement.SafeCheckErasure
noncomputable section
open RefinementCheck CheckErasure StandardModel

/-- 仮定側の行に依らず、同じ完成した表の check の行は消去の条件を満たす。 -/
theorem Agreement.complete {L : NameLists} (hL : L.WF) {P : Program} (T : DataTable P) (A : AssumedTable) :
    Agreement (StandardModel.complete L T A) := by
  have hm := hL.composedAll Primitive.p392.name (by simp [baseBuiltins,StandardModel.signature,primitive_lookup])
  constructor
  · change (StandardModel.complete L T A).sig Primitive.p392.name = _
    rw [(complete_agree L T A).sig _ hm,DataTable.base_sig,primitive_lookup]
    rfl
  · intro t u v
    change (StandardModel.complete L T A).delta Primitive.p392.name [t,u] [] [] [v] = _
    rw [complete_delta hL T A .p392]
    rfl

/-- 正常な正の整数。 -/
def successfulValue : Val := .const (.integer ⟨1,by decide⟩)

/-- 閉じた成功した検査について、全ての静的条件を満たす。 -/
theorem successfulSite : Site (.base .integer) nonnegative successfulValue where
  expectedWF := by simp [nonnegative,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
  normalSource := rfl
  normalExpected := rfl
  core := rfl
  accepts := by decide
  stable := ⟨(by intro cap; exact ⟨rfl,rfl⟩),
    (by intro ν ρ; exact ⟨rfl,rfl⟩),
    (by intro c ts es; exact ⟨rfl,rfl⟩),
    (by intro ρ; exact ⟨rfl,rfl⟩)⟩

/-- 成功した呼出しを let の中に置く。 -/
def checkedBody : Comp := .letIn (call (.base .integer) nonnegative successfulValue) (.ret (.const .unit))

/-- 定義の本体・let の子では、成功した検査を実際に消す。 -/
theorem checkedBody_erased : erase checkedBody = .letIn (.ret (ok nonnegative successfulValue)) (.ret (.const .unit)) := by
  simp [checkedBody,call,erase,successfulSite]

/-- ラムダの本体へは入らず、閉包を組込みへ渡したときのコードを保持する。 -/
theorem lambda_retained : erase (.ret (.lam [] [] checkedBody)) = .ret (.lam [] [] checkedBody) := rfl

/-- 実引数が変数の呼出しは、型と篩が同じでも保持する。 -/
theorem variable_retained (i : Nat) : erase (call (.base .integer) nonnegative (.var i)) = call (.base .integer) nonnegative (.var i) := by
  simp only [call,erase]
  split
  · next h =>
    have hv := (h.2.stable.view Capture.empty).1
    simp [Closure.view,Closure.code,Closure.capture,Capture.empty,closeVal,closeVals,call] at hv
    have hvalue := hv.2
    simp [Capture.env,Capture.values] at hvalue
  · rfl

/-- プログラムと main の計算の同時の消去で、開始の状態が対応する。 -/
theorem initial_relation (main : Comp) :
    StateRel (.run (Closure.pure main) [] Store.empty) (.run (Closure.pure (erase main)) [] Store.empty) :=
  .run (.code (erase_code main)) .nil (.refl _)

/-- プログラム全体と main の消去について、事象列と終端の全 payload が一致する。 -/
theorem program_observations (P : Program) (B : Builtins) (σ : PathEnv) (main : Comp) (ha : Agreement B) :
    ∀ events obs,
      (∃ z, Steps P B σ (.run (Closure.pure main) [] Store.empty) events z ∧ terminal z = some obs) ↔
      (∃ z, Steps (eraseProgram P) B σ (.run (Closure.pure (erase main)) [] Store.empty) events z ∧ terminal z = some obs) :=
  observations_preserved ha (initial_relation main)

/-- 同じプログラム全体と main の消去について、非停止の選択も両方向で保つ。 -/
theorem program_infinite (P : Program) (B : Builtins) (σ : PathEnv) (main : Comp) (ha : Agreement B) :
    (∃ labels, InfiniteExecution P B σ (.run (Closure.pure main) [] Store.empty) labels) ↔
      (∃ labels, InfiniteExecution (eraseProgram P) B σ (.run (Closure.pure (erase main)) [] Store.empty) labels) :=
  infinite_preserved ha (initial_relation main)

/-- 定義の lookup は同じ署名と、消去した同じ本体を返す。 -/
example {P : Program} {f : String} {d : Def} (hd : P.defs f = some d) (hb : d.body = checkedBody) :
    (eraseProgram P).defs f = some {d with body := .letIn (.ret (ok nonnegative successfulValue)) (.ret (.const .unit))} := by
  simp only [eraseProgram,hd,Option.map_some,hb,checkedBody_erased]

/-- 非停止へ至る有限の事象列も、同じ完成した標準表で一致する。 -/
example (externals : List (ExternalKey × ExternalDecl)) (σ : PathEnv) (events : List Event) :
    let P := Surface.MainExamples.linked externals
    let B := (Surface.MainExamples.input externals).B
    (∃ z, Steps P B σ (.run (Closure.pure checkedBody) [] Store.empty) events z ∧ Diverges P B σ z) ↔
      (∃ z, Steps (eraseProgram P) B σ (.run (Closure.pure (erase checkedBody)) [] Store.empty) events z ∧
        Diverges (eraseProgram P) B σ z) :=
  diverging_prefixes_preserved (Agreement.complete nameLists_wf (Surface.MainExamples.data externals) _)
    (initial_relation checkedBody) events

/-- 同じ効果による被覆を付けた終端の観測も、具体の let の消去で保つ。 -/
example (externals : List (ExternalKey × ExternalDecl)) (σ : PathEnv) (Γ : Ctx) (Φ : List Pred)
    (ε : Eff) (events : List Event) (obs : TerminalObservation) :
    let P := Surface.MainExamples.linked externals
    let B := (Surface.MainExamples.input externals).B
    (∃ z, Steps P B σ (.run (Closure.pure checkedBody) [] Store.empty) events z ∧ terminal z = some obs ∧
      ∀ ev ∈ events, Event.Covered B Γ Φ ε ev) ↔
      (∃ z, Steps (eraseProgram P) B σ (.run (Closure.pure (erase checkedBody)) [] Store.empty) events z ∧ terminal z = some obs ∧
        ∀ ev ∈ events, Event.Covered B Γ Φ ε ev) :=
  effects_preserved (Agreement.complete nameLists_wf (Surface.MainExamples.data externals) _)
    (initial_relation checkedBody) Γ Φ ε events obs

/-- let 内の成功した検査が、同じ完成した標準表で事象・終端・非停止を保つ具体の適用。 -/
example (externals : List (ExternalKey × ExternalDecl)) (σ : PathEnv) :
    let P := Surface.MainExamples.linked externals
    let B := (Surface.MainExamples.input externals).B
    (∀ events obs,
      (∃ z, Steps P B σ (.run (Closure.pure checkedBody) [] Store.empty) events z ∧ terminal z = some obs) ↔
      (∃ z, Steps (eraseProgram P) B σ (.run (Closure.pure (erase checkedBody)) [] Store.empty) events z ∧ terminal z = some obs)) ∧
    ((∃ labels, InfiniteExecution P B σ (.run (Closure.pure checkedBody) [] Store.empty) labels) ↔
      (∃ labels, InfiniteExecution (eraseProgram P) B σ (.run (Closure.pure (erase checkedBody)) [] Store.empty) labels)) := by
  exact ⟨program_observations _ _ σ _ (Agreement.complete nameLists_wf (Surface.MainExamples.data externals) _),
    program_infinite _ _ σ _ (Agreement.complete nameLists_wf (Surface.MainExamples.data externals) _)⟩

end
end Benitoite.Release.Refinement.SafeCheckErasure
