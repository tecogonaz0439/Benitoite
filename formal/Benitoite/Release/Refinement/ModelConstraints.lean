import Benitoite.Release.Refinement.StandardKeySummary
import Benitoite.Release.Refinement.SubstitutionContracts

/-! # モデルの制約の骨格と具体化の境界 -/
namespace Benitoite.Release.Refinement.ModelConstraints
open StandardKeyTyping
noncomputable section

def sat (S : Benitoite.Release.SummaryTable) (C : List TParam) (a : Ty) (p : TParam) : Prop :=
  Benitoite.Release.satB S C (carrier a) p = true

/-- 実引数数と、位置ごとの非空制約を同時に検査する。 -/
def admits (S : Benitoite.Release.SummaryTable) (ps C : List TParam) (ts : List Ty) : Prop :=
  ts.length = ps.length ∧ ∀ (i : Nat) (a : Ty) (p : TParam), ts[i]? = some a → ps[i]? = some p → sat S C a p

mutual
  private theorem carrier_rawBind_values (a : Ty) (θ : SubstEnv)
      (ht : ∀ i, θ.types i = .tvar i) : carrier (a.rawBind θ) = carrier a := by
    cases a <;> simp only [Ty.rawBind,carrier,carrier_rawBind_values _ θ ht,carriers_rawBind_values _ θ ht,ht,rawApply]
  private theorem carriers_rawBind_values (as : List Ty) (θ : SubstEnv)
      (ht : ∀ i, θ.types i = .tvar i) : carriers (rawBindTys θ as) = carriers as := by
    cases as <;> simp only [rawBindTys,carriers,carrier_rawBind_values _ θ ht,carriers_rawBind_values _ θ ht]
end

/-- 全ての型と行の像について、値だけの置換は制約の骨格を保つ。 -/
theorem sat_bind_values (S : Benitoite.Release.SummaryTable) (C : List TParam)
    (a : Ty) (p : TParam) (θ : SubstEnv) (ht : ∀ i, θ.types i = .tvar i) :
    sat S C (a.bind θ) p ↔ sat S C a p := by
  simp only [sat,Ty.bind,carrier_norm,carrier_rawBind_values a θ ht]

/-- 実引数列全体の長さと各制約も、同じ置換で保つ。 -/
theorem admits_bind_values (S : Benitoite.Release.SummaryTable) (ps C : List TParam)
    (as : List Ty) (θ : SubstEnv) (ht : ∀ i, θ.types i = .tvar i) :
    admits S ps C (as.map (fun a => a.bind θ)) ↔ admits S ps C as := by
  simp only [admits,List.length_map,List.getElem?_map]
  constructor
  · rintro ⟨count,h⟩
    refine ⟨count,?_⟩
    intro i a p ha hp
    exact (sat_bind_values S C a p θ ht).mp (h i (a.bind θ) p (by simp [ha]) hp)
  · rintro ⟨count,h⟩
    refine ⟨count,?_⟩
    intro i a p ha hp
    obtain ⟨b,hb,rfl⟩ := Option.map_eq_some_iff.mp ha
    exact (sat_bind_values S C b p θ ht).mpr (h i b p hb hp)

example (S : Benitoite.Release.SummaryTable) (C ps : List TParam) (as : List Ty)
    (a : Ty) (p : TParam) (ν : Nat → Val) (ξ : Nat → Nat) :
    (sat S C (substTyValues ν a) p ↔ sat S C a p) ∧
    (sat S C (renameTy ξ a) p ↔ sat S C a p) ∧
    (admits S ps C (as.map (substTyValues ν)) ↔ admits S ps C as) := by
  refine ⟨sat_bind_values S C a p (valEnv ν) (fun _ => rfl),?_,
    admits_bind_values S ps C as (valEnv ν) (fun _ => rfl)⟩
  simp only [renameTy,sat,carrier_rawBind_values a (renEnv ξ) (fun _ => rfl)]

private def eqC : TParam := ⟨true,false⟩
private def keyC : TParam := ⟨false,true⟩

/-- 空制約と、鍵として拒否される関数を同じ判定で区別する。 -/
example (S : Benitoite.Release.SummaryTable) (a : Ty) :
    sat S [] a {} ∧ ¬ sat S [] (.fn [] [] (.base .unit) Eff.empty) keyC := by
  exact ⟨rfl,by simp [sat,keyC,carrier,Benitoite.Release.satB,Benitoite.Release.satisfiesB]⟩

/-- 非空の二制約の変数を同じ位置へ改名できる。行き先は両方を満たす。 -/
example (S : Benitoite.Release.SummaryTable) :
    sat S [keyC,eqC] (.tvar 0) keyC ∧ sat S [keyC,eqC] (.tvar 1) eqC ∧
    sat S [keyC] ((Ty.tvar 0).renameTypes (fun _ => 0)) keyC ∧
    sat S [keyC] ((Ty.tvar 1).renameTypes (fun _ => 0)) eqC := by
  simp [sat,keyC,eqC,carrier,Ty.renameTypes,Ty.rawRenameTypes,Ty.norm,
    Benitoite.Release.satB,Benitoite.Release.satisfiesB]

/-- 型の像の篩は値に依存してよい。鍵の骨格はその述語を読まない。 -/
example (S : Benitoite.Release.SummaryTable) (p : Pred) :
    sat S [] ((Ty.tvar 0).subst [.refined (.base .integer) p] []) keyC ∧
    admits S [keyC] [] [.refined (.base .integer) p] := by
  constructor
  · simp [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,carrier_norm,Ty.rawBind,typeEnvAt,
      sat,carrier,keyC,Benitoite.Release.satB,Benitoite.Release.satisfiesB]
  · refine ⟨rfl,?_⟩
    intro i a q ha hq
    cases i with
    | zero => cases ha; cases hq; rfl
    | succ i => simp at ha

/-- 値・行の像に依存述語と Fail があっても、関数型を鍵にはしない。 -/
example (S : Benitoite.Release.SummaryTable) (p : Pred) (ν : Nat → Val) :
    ¬ sat S [] (substTyValues ν
      (.fn ["x"] [.refined (.base .integer) p] (.base .unit)
        (Eff.singleFail (.refined (.base .integer) p)))) keyC := by
  simp [sat,keyC,substTyValues,Ty.bind,carrier_norm,Ty.rawBind,carrier,
    Benitoite.Release.satB,Benitoite.Release.satisfiesB]

/-- 行の像は値に依存する Fail を持ってよい。 -/
example (S : Benitoite.Release.SummaryTable) (p : Pred) :
    ¬ sat S [] ((Ty.fn [] [] (.base .unit) (.mk (fun a => decide (a = .rho 0)) [])).subst
      [] [Eff.singleFail (.refined (.base .integer) p)]) keyC := by
  simp [sat,keyC,Ty.subst,Ty.substAt,substTypeAt,Ty.bind,carrier_norm,Ty.rawBind,
    carrier,Benitoite.Release.satB,Benitoite.Release.satisfiesB]

/-- 型像の衝突で Fail は縮約する。骨格の関数拒否は列の長さを読まない。 -/
example (S : Benitoite.Release.SummaryTable) (p : Pred) :
    let a : Ty := .refined (.base .integer) p
    let e : Eff := .mk (fun _ => false) [.tvar 0,.tvar 1]
    (Eff.bind (typeEnvAt 0 [a,a] []) e).fails = [a.norm] ∧
    ¬ sat S [] (.fn [] [] (.base .unit) (Eff.bind (typeEnvAt 0 [a,a] []) e)) keyC := by
  dsimp
  constructor
  · have cmp := (tyCompare_eq_iff ((Ty.refined (.base .integer) p).norm) _).mpr rfl
    simp [cmp,Eff.bind,Eff.rawBind,rawBindTys,typeEnvAt,rowFails,Eff.norm,
      Ty.normTys,Ty.rawBind,Eff.fails,Order.sortUnique,Order.insertUnique]
  · simp [sat,keyC,carrier,Benitoite.Release.satB,Benitoite.Release.satisfiesB]
end
end Benitoite.Release.Refinement.ModelConstraints
