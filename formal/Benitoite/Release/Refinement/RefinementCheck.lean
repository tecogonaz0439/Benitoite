import Benitoite.Release.Refinement.PublicNames
import Benitoite.Release.Refinement.BooleanResult

/-! # 閉じた篩の明示的な検査 -/
namespace Benitoite.Release.Refinement.RefinementCheck
noncomputable section

def errorType : Ty := .data "Refinement.CheckError" []
def result (u : Ty) : Ty := .data "Result" [u,errorType]

def signature : PrimSig :=
  ⟨[TypeCtx.valueParam,TypeCtx.valueParam],0,["value"],[.tvar 0],result (.tvar 1),Eff.empty,
    PublicNames.checkAdmits,.pure,none,[],.untargeted⟩

/-- 自己変数を観測できなければ閉じた述語だけを検査する。評価不能も拒否する。 -/
def accepts (v : Val) : Ty → Bool
  | .refined a p => accepts v a &&
    (match a.sort? with
    | none => p.closedTrue
    | some _ => match v.toTerm? with | none => false | some t => (p.open t).closedTrue)
  | _ => true

/-- 型付きの値から外側の篩だけを除去し、同じ値を基の型へ渡す。 -/
theorem to_core {P B Ψ v a} (ha : Ty.Annotation P [] [] a)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v a) :
    HasTypeVQ P B Ψ Qempty [] [] [] v a.core := by
  cases a with
  | refined a p =>
    have hb : Ty.Annotation P [] [] a := ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩
    exact to_core (a := a) hb (.V_Sub hv .forget hb.wf hb.sorted hb.declared)
  | _ => exact hv
termination_by structural a

/-- 基の型で型付く値は、外側の全篩の閉じた評価が真なら期待型で型付く。 -/
theorem accepted_typed {P B Ψ v a} (ha : Ty.Annotation P [] [] a)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v a.core) (hc : accepts v a = true) :
    HasTypeVQ P B Ψ Qempty [] [] [] v a := by
  cases a with
  | refined a p =>
    have hh := hc
    simp only [accepts, Bool.and_eq_true] at hh
    have hb : Ty.Annotation P [] [] a := ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩
    have typed := accepted_typed (a := a) hb hv hh.1
    cases hsort : a.sort? with
    | none =>
      have he : p.closedTrue = true := by simpa only [hsort] using hh.2
      exact .V_Sub typed (.introduce ha.sorted.2 ((Pred.closedTrue_entails he).2.2.weaken (by simp)))
        ha.wf ha.sorted ha.declared
    | some s =>
      cases ht : v.toTerm? with
      | none => simp [hsort,ht] at hh
      | some t =>
        have he : (p.open t).closedTrue = true := by simpa only [hsort,ht] using hh.2
        exact .V_Refine typed hsort ht ha.sorted.2 ha.wf.2.1
          (Pred.closedTrue_entails he).2.2 ha.declared.1 ha.declared.2
  | _ => exact hv
termination_by structural a

/-- 表示文字列は実行結果の診断用であり、型検査はこの文字列を読まない。 -/
def errorValue (expected : String) : Val :=
  .con "Refinement.CheckError" [] [.const (.string expected)]

def ok (u : Ty) (v : Val) : Val := .con "Result.Ok" [u,errorType] [v]
def rejected (u : Ty) (expected : String) : Val :=
  .con "Result.Error" [u,errorType] [errorValue expected]

/-- 誤りの表示器は応答の型と検査の成否に影響しない。 -/
def run (render : Ty → String) (t u : Ty) (v : Val) : Outcome := by
  classical
  exact if t.core = u.core ∧ accepts v u = true then .val (ok u v)
  else .val (rejected u (render u))

def delta (render : Ty → String) (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
    (ws : List Val) : Option Outcome :=
  if name = PublicNames.checkName ∧ es = [] ∧ rs = [] then
    match ts,ws with
    | [t,u],[v] => some (run render t u v)
    | _,_ => none
  else none

/-- 消去は、基の型の一致と閉じた評価の成功を静的に示した場合に限り同じ Ok を返す。 -/
theorem run_ok {render t u v} (hcore : t.core = u.core) (htrue : accepts v u = true) :
    run render t u v = .val (ok u v) := by simp [run,hcore,htrue]

/-- 偽と評価不能はいずれも誤りである。 -/
theorem run_rejected {render t u v} (h : accepts v u = false) :
    run render t u v = .val (rejected u (render u)) := by simp [run,h]

/-- 観測できる自己変数の一つの篩は、D19 が some true を返す場合に限り成功する。 -/
theorem accepts_refined {v a p sort term}
    (hs : a.sort? = some sort) (ht : v.toTerm? = some term) :
    accepts v (.refined a p) = (accepts v a && (p.open term).closedTrue) := by
  simp only [accepts,hs,ht]

/-- D19 が偽又は評価不能なら、篩の外側の検査は誤りを返す。 -/
theorem run_refined_rejected {render t a p v sort term}
    (hs : a.sort? = some sort) (ht : v.toTerm? = some term)
    (he : (p.open term).evalClosed = some false ∨ (p.open term).evalClosed = none) :
    run render t (.refined a p) v = .val (rejected (.refined a p) (render (.refined a p))) := by
  apply run_rejected
  rw [accepts_refined hs ht]
  rcases he with he | he <;> simp [Pred.closedTrue,he]

end
end Benitoite.Release.Refinement.RefinementCheck
