import Benitoite.Release.Refinement.Surface.PredicateSimulationScalarInputs
import Benitoite.Release.Refinement.Surface.PredicateSimulationSimpleValues
import Benitoite.Release.Refinement.Context.Capture
import Benitoite.Release.Refinement.Semantics

/-! # 公開判定の引数を束縛する有限の実行

元の解析が返す値の構文だけを使う。閉包の本体を評価せず、元の捕捉環境の下の値を
ソース順に捕捉する。継続とストアは任意とする。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateRows PredicateResponse
noncomputable section

theorem Capture.extendMany_append (cap : Capture) (values others : List Val) :
    cap.extendMany (values ++ others) = (cap.extendMany values).extendMany others := by
  exact List.foldl_append

theorem Capture.extendMany_env_old (cap : Capture) (values : List Val) (index : Nat) :
    (cap.extendMany values).env (index + values.length) = cap.env index := by
  induction values generalizing cap index with
  | nil => rfl
  | cons value values ih =>
    change ((cap.extend value).extendMany values).env (index + (values.length + 1)) = _
    rw [show index + (values.length + 1) = (index+1) + values.length by omega,ih]
    rfl

theorem Capture.closeTy_shiftMany (cap : Capture) (values : List Val) (a : Ty) :
    (cap.extendMany values).closeTy (a.shiftV values.length 0) = cap.closeTy a := by
  induction values generalizing cap a with
  | nil => change cap.closeTy (a.shiftV 0 0) = _; rw [Ty.shiftV_zero]
  | cons value values ih =>
    change ((cap.extend value).extendMany values).closeTy (a.shiftV (values.length+1) 0) = _
    have shift : a.shiftV (values.length+1) 0 = (a.shiftV 1 0).shiftV values.length 0 := by
      rw [Ty.shiftV_add]
      congr 1
      omega
    rw [shift,ih,Capture.closeTy_shift]

/-- 追加した管理用の捕捉を越えても、元の値の解析が返す構文は同じ値へ閉じる。 -/
theorem SimpleValue.close_shiftMany {value} (simple : SimpleValue value) (cap : Capture) (values : List Val) :
    closeVal (cap.extendMany values) (value.rename (· + values.length)) = closeVal cap value := by
  cases simple with
  | var index => exact Capture.extendMany_env_old cap values index
  | constant value => rfl
  | con name types =>
    simp only [Val.rename,closeVal,Val.renameList,closeVals,List.map_map]
    congr 1
    apply List.map_congr_left
    intro a member
    have renamed : renameTy (· + values.length) a = a.shiftV values.length 0 := by
      rw [Ty.shiftV_eq_renameTy]
      congr 1
    change (cap.extendMany values).closeTy (renameTy (· + values.length) a) = _
    rw [renamed,Capture.closeTy_shiftMany]

theorem boundVars_succ (count : Nat) : boundVars (count+1) = .var count :: boundVars count := by
  simp [boundVars,List.range_succ,List.reverse_append]

/-- 逆順の局所番号を読むと、ソース順に捕捉した値の列をそのまま得る。 -/
theorem closeVals_boundVars (cap : Capture) (values : List Val) :
    closeVals (cap.extendMany values) (boundVars values.length) = values := by
  induction values generalizing cap with
  | nil => rfl
  | cons value values ih =>
    change closeVals ((cap.extend value).extendMany values) (boundVars (values.length+1)) = value :: values
    rw [boundVars_succ]
    have head : ((cap.extend value).extendMany values).env values.length = value := by
      simpa only [Nat.zero_add,Capture.extend_env_zero] using Capture.extendMany_env_old (cap.extend value) values 0
    change ((cap.extend value).extendMany values).env values.length ::
      closeVals ((cap.extend value).extendMany values) (boundVars values.length) = _
    rw [head,ih]

theorem closeVals_append (cap : Capture) (values others : List Val) :
    closeVals cap (values ++ others) = closeVals cap values ++ closeVals cap others := by
  induction values with
  | nil => rfl
  | cons value values ih => exact congrArg (List.cons (closeVal cap value)) ih

private theorem closeVals_map (cap : Capture) (values : List Val) : closeVals cap values = values.map (closeVal cap) := by
  induction values with
  | nil => rfl
  | cons value values ih => exact congrArg (List.cons (closeVal cap value)) ih

def scalarBody (api : API) (positions : List Nat) (values : List Val) : Comp :=
  .app (.prim api.name [] [] [])
    (recordFields api.inputs.length positions (boundVars values.length) (.const .unit))

/-- 管理用の束縛を全て終えると、元の環境の値を宣言順に並べた公開呼出しを読む。 -/
theorem scalarBody_view (api : API) (positions : List Nat) (values : List Val) (cap : Capture) :
    (.mk (cap.extendMany (closeVals cap values)) (scalarBody api positions values) : Closure).view =
      .app (.prim api.name [] [] []) (recordFields api.inputs.length positions (closeVals cap values) (.const .unit)) := by
  let capture := cap.extendMany (closeVals cap values)
  have bound : closeVals capture (boundVars values.length) = closeVals cap values := by
    simpa only [closeVals_length] using closeVals_boundVars cap (closeVals cap values)
  have fields := recordFields_map (closeVal capture) api.inputs.length positions (boundVars values.length) (.const .unit)
  have fieldsClosed : closeVals capture (recordFields api.inputs.length positions (boundVars values.length) (.const .unit)) =
      recordFields api.inputs.length positions (closeVals cap values) (.const .unit) := by
    simpa only [← closeVals_map,closeVal,bound] using fields
  change Comp.app (.prim api.name [] [] [])
    (closeVals capture (recordFields api.inputs.length positions (boundVars values.length) (.const .unit))) = _
  rw [fieldsClosed]

theorem ScalarInputs.close {api entry positions values value}
    (inputs : ScalarInputs api entry (recordFields api.inputs.length positions values (.const .unit)) value) (cap : Capture) :
    ScalarInputs api entry (recordFields api.inputs.length positions (closeVals cap values) (.const .unit)) (closeVal cap value) := by
  have mapped := inputs.map (closeVal cap) (fun _ => rfl)
  rw [recordFields_map] at mapped
  simpa only [← closeVals_map,closeVal] using mapped

/-- 終了相も公開appであり、正常終端ではない。各引数はletとreturnの二段だけを使う。 -/
inductive ScalarPhase (api : API) (positions : List Nat) (values : List Val) (cap : Capture)
    (continuation : Cont) (store : Store) : State → Nat → Prop
  | chain (before remaining : List Val) (split : values = before ++ remaining) :
      ScalarPhase api positions values cap continuation store
        (.run (.mk (cap.extendMany (closeVals cap before))
          (letChain before.length (remaining.map Comp.ret) (scalarBody api positions values))) continuation store)
        (2 * remaining.length)
  | argument (before : List Val) (value : Val) (remaining : List Val) (split : values = before ++ value :: remaining) :
      ScalarPhase api positions values cap continuation store
        (.run (.mk (cap.extendMany (closeVals cap before)) (.ret (value.rename (· + before.length))))
          (.letF (.mk (cap.extendMany (closeVals cap before))
            (letChain (before.length+1) (remaining.map Comp.ret) (scalarBody api positions values))) :: continuation) store)
        (2 * remaining.length + 1)

theorem ScalarPhase.initial (api positions values cap continuation store) :
    ScalarPhase api positions values cap continuation store
      (.run (.mk cap (scalarCall api positions values)) continuation store) (2 * values.length) := by
  exact .chain [] values rfl

/-- 先頭から連続する管理用let/returnの残りの段数。 -/
def pendingReturns : Comp → Nat
  | .letIn (.ret _) body => 2 + pendingReturns body
  | _ => 0

def scalarRank : State → Nat
  | .run (.mk _ (.ret _)) (.letF (.mk _ body) :: _) _ => 1 + pendingReturns body
  | .run (.mk _ body) _ _ => pendingReturns body
  | _ => 0

theorem pendingReturns_scalarChain (api : API) (positions : List Nat) (values : List Val) (depth : Nat) (remaining : List Val) :
    pendingReturns (letChain depth (remaining.map Comp.ret) (scalarBody api positions values)) = 2 * remaining.length := by
  induction remaining generalizing depth with
  | nil => rfl
  | cons value remaining ih =>
    change 2 + pendingReturns (letChain (depth+1) (remaining.map Comp.ret) (scalarBody api positions values)) = _
    rw [ih]
    simp only [List.length_cons]
    omega

theorem ScalarPhase.rank {api positions values cap continuation store state rank}
    (phase : ScalarPhase api positions values cap continuation store state rank) : scalarRank state = rank := by
  cases phase with
  | chain before remaining split =>
    cases remaining with
    | nil => rfl
    | cons value remaining =>
      change 2 + pendingReturns (letChain (before.length+1) (remaining.map Comp.ret) (scalarBody api positions values)) = _
      rw [pendingReturns_scalarChain]
      simp only [List.length_cons]
      omega
  | argument before value remaining split =>
    change 1 + pendingReturns (letChain (before.length+1) (remaining.map Comp.ret) (scalarBody api positions values)) = _
    rw [pendingReturns_scalarChain]
    omega

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
