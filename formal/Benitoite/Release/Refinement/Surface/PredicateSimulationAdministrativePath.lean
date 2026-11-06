import Benitoite.Release.Refinement.Surface.PredicateSimulationAdministrativeRank

/-! # 六つの管理規則から作る一意な有限経路

実getterの定義は元のsourceから生成した同じものを読む。Builtinの応答や空き位置の
選択は含めず、各段の実Step・一意性・順位の下降を証明する。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

def getterMatch (step : PredicateAccessorTargets.Step) : Comp :=
  .match (.var 0) [mkArm (accessorPattern step.constructor step.declaration.args.length step.position) (.ret (.var 0))]

inductive AdministrativeStep (source : Program) : State → State → Prop
  | letIn (cap : Capture) (first rest : Comp) (k : Cont) (μ : Store) :
      AdministrativeStep source (.run (.mk cap (.letIn first rest)) k μ)
        (.run (.mk cap first) (.letF (.mk cap rest) :: k) μ)
  | returnValue {q next : Closure} {value : Val} {k : Cont} {μ : Store} (view : q.view = .ret value) :
      AdministrativeStep source (.run q (.letF next :: k) μ) (.run (next.apply [value]) k μ)
  | getter (step : PredicateAccessorTargets.Step)
      (missing : source.defs step.function = none)
      (accessor : source.accessors step.function = some (step.constructor,step.position))
      (declaration : source.cons step.constructor = some step.declaration)
      (count : step.types.length = step.declaration.ntys)
      (cap : Capture) (receiver : Val) (next : Closure) (k : Cont) (μ : Store)
      (view : (.mk (cap.extend receiver) (getterCall step) : Closure).view =
        .app (.fnRef step.function (step.types.map cap.closeTy) [] []) [receiver]) :
      AdministrativeStep source (.run (.mk (cap.extend receiver) (getterCall step)) (.letF next :: k) μ)
        (.run (.mk (Capture.empty.extendMany [receiver]) (getterMatch step)) (.mark :: .letF next :: k) μ)
  | matchStart {q : Closure} {value : Val} {arms : List Arm} {k : Cont} {μ : Store}
      (view : q.view = .match value arms) :
      AdministrativeStep source (.run q k μ) (.matchRun value q.capture arms 0 k μ)
  | matchBody {value : Val} {cap : Capture} {arms : List Arm} {index : Nat} {alternatives : List Benitoite.Release.Alt}
      {body : Comp} {arguments : List Val} {k : Cont} {μ : Store}
      (found : arms[index]? = some (.mk alternatives none body)) (matched : firstAlt value alternatives = some arguments)
      (zero : administrativeCodeCost source body = 0) :
      AdministrativeStep source (.matchRun value cap arms index k μ) (.run (.mk (cap.extendMany arguments) body) k μ)
  | mark {q : Closure} {value : Val} {k : Cont} {μ : Store} (view : q.view = .ret value) :
      AdministrativeStep source (.run q (.mark :: k) μ) (.run (.pure (.ret value)) k μ)

private theorem getter_specialized (step : PredicateAccessorTargets.Step) (cap : Capture) :
    ((accessorDef step.constructor step.declaration step.position).body.instR []).substTy (step.types.map cap.closeTy) [] = getterMatch step := by
  rw [Comp.instR_nil]
  rfl

theorem AdministrativeStep.realize {source before after P B σ} (path : AdministrativeStep source before after)
    (environment : GetterEnvironment source P) : Step P B σ before none after := by
  cases path with
  | letIn cap first rest k μ => exact .E_Let rfl
  | returnValue view => exact .E_Return view
  | getter step missing accessor declaration count cap receiver next k μ view =>
    have typeCount : (step.types.map cap.closeTy).length = (accessorDef step.constructor step.declaration step.position).ntys := by
      simpa only [List.length_map,Def.ntys,accessorDef,accessorDecl,List.length_replicate] using count
    simpa only [getter_specialized,markPush] using
      (Step.E_Fun (P := P) (B := B) (σ := σ) (rs := []) view
        (environment.lookup _ _ _ _ missing accessor declaration) (by rfl) typeCount (by rfl))
  | matchStart view => exact .E_Match view
  | matchBody found matched zero => exact .E_MatchBody found matched
  | mark view => exact .E_Mark view

private theorem view_ret_cost {source : Program} {q : Closure} {value : Val} (view : q.view = .ret value) : administrativeCodeCost source q.code = 0 := by
  cases q with
  | mk cap code => cases code <;> simp_all [Closure.view,Closure.code,Closure.capture,administrativeCodeCost]

private theorem view_match_cost {source : Program} {q : Closure} {value : Val} {arms : List Arm} (view : q.view = .match value arms) : administrativeCodeCost source q.code = 2 := by
  cases q with
  | mk cap code => cases code <;> simp_all [Closure.view,Closure.code,Closure.capture,administrativeCodeCost]

theorem AdministrativeStep.decreases {source before after} (path : AdministrativeStep source before after) :
    administrativeRank source after < administrativeRank source before := by
  cases path with
  | letIn cap first rest k μ => exact administrative_let_decreases source cap first rest k μ
  | @returnValue q next value k μ view =>
    change administrativeCodeCost source next.code + administrativeContCost source k <
      administrativeCodeCost source q.code + (1 + administrativeCodeCost source next.code + administrativeContCost source k)
    rw [view_ret_cost view]
    omega
  | getter step missing accessor declaration count cap receiver next k μ view =>
    change 2 + (1 + (1 + administrativeCodeCost source next.code + administrativeContCost source k)) <
      (if (source.accessors step.function).isSome then 4 else 0) +
        (1 + administrativeCodeCost source next.code + administrativeContCost source k)
    rw [accessor]
    simp only [Option.isSome_some,ite_true]
    omega
  | @matchStart q value arms k μ view =>
    change 1 + administrativeContCost source k < administrativeCodeCost source q.code + administrativeContCost source k
    rw [view_match_cost view]
    omega
  | @matchBody value cap arms index alternatives body arguments k μ found matched zero =>
    change administrativeCodeCost source body + administrativeContCost source k < 1 + administrativeContCost source k
    rw [zero]
    omega
  | @mark q value k μ view =>
    change 0 + administrativeContCost source k < administrativeCodeCost source q.code + (1 + administrativeContCost source k)
    rw [view_ret_cost view]
    omega

/-- builtin応答と空き位置の選択を含まない六規則なので、別の実一段も同じ到達先を持つ。 -/
theorem AdministrativeStep.unique {source before after P B σ label destination}
    (path : AdministrativeStep source before after) (environment : GetterEnvironment source P)
    (actual : Step P B σ before label destination) : label = none ∧ destination = after := by
  cases path with
  | letIn cap first rest k μ =>
    cases actual <;> simp_all [Closure.view,Closure.code,Closure.capture]
  | returnValue view =>
    cases actual <;> simp_all
    all_goals subst_vars
    all_goals simp_all [Closure.view]
  | getter step missing accessor declaration count cap receiver next k μ view =>
    have found := environment.lookup _ _ _ _ missing accessor declaration
    have specialized := getter_specialized step cap
    cases actual <;> simp_all [closeVal]
    all_goals subst_vars
    all_goals simp_all [Closure.view,Closure.code,Closure.capture,getterCall,markPush]
  | matchStart view =>
    cases actual <;> simp_all
    all_goals subst_vars
    all_goals simp_all [Closure.view]
  | matchBody found matched zero => cases actual <;> simp_all
  | mark view =>
    cases actual <;> simp_all
    all_goals subst_vars
    all_goals simp_all [Closure.view]

inductive AdministrativePath (source : Program) : State → State → Prop
  | nil (state : State) : AdministrativePath source state state
  | cons {first middle last} : AdministrativeStep source first middle → AdministrativePath source middle last →
      AdministrativePath source first last

theorem AdministrativePath.append {source first middle last} (beginning : AdministrativePath source first middle)
    (rest : AdministrativePath source middle last) : AdministrativePath source first last := by
  induction beginning with
  | nil state => exact rest
  | cons step path ih => exact .cons step (ih rest)

theorem AdministrativePath.realize {source first last P B σ} (path : AdministrativePath source first last)
    (environment : GetterEnvironment source P) : Steps P B σ first [] last := by
  induction path with
  | nil state => exact .nil
  | cons step path ih => exact .cons (step.realize environment) ih

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
