import Benitoite.Release.Refinement.Surface.Rules
import Benitoite.Release.Refinement.Surface.OpenSurface
import Benitoite.Release.Refinement.StandardModelCoreRows

/-! # 発行専用の組込みに対する節の拒否

選ばれた組込みの一覧に属する発行の節を拒否し、同じ効果名の利用者の操作の節を受理する。
-/
namespace Benitoite.Release.Refinement.Surface

/-- 利用者の操作は、発行専用の組込みの節を断る条件に適合する。 -/
theorem ClauseAllowed.user (D : Declarations) (B : Builtins) (o : OpName) : ClauseAllowed D B (.user o) := by
  intro b s l bs h
  cases h

/-- 選んだ組込みの表で発行専用の関数を処理する節には、型付けの導出がない。 -/
theorem HasClausesQ.issue_rejected {D B op Q Δ C Γ Φ R εb b s l bs n ntys body cs ndicts a ε}
    (hs : B.sig b = some s) (hk : s.kind = .pathBases) (hd : D.effects l = none)
    (he : B.effects l = some bs) (hm : b ∈ bs) :
    ¬ HasClausesQ D B op Q Δ C Γ Φ R εb (.cons (.prim b) n ntys body cs ndicts) a ε := by
  intro h
  cases h with
  | cons allowed _ _ _ _ _ _ _ => exact (allowed b s l bs rfl hs hd he hm) hk

/-- 開いた範囲文脈の節も、選ばれた発行専用の操作を処理する導出を持たない。 -/
theorem OpenSurface.HasClausesQ.issue_rejected {D B ks op Q Δ C Γ Φ R εb b s l bs n ntys body cs ndicts a ε}
    (hs : B.sig b = some s) (hk : s.kind = .pathBases) (hd : D.effects l = none)
    (he : B.effects l = some bs) (hm : b ∈ bs) :
    ¬ OpenSurface.HasClausesQ D B ks op Q Δ C Γ Φ R εb (.cons (.prim b) n ntys body cs ndicts) a ε := by
  intro h
  cases h with
  | closed _ h => exact Benitoite.Release.Refinement.Surface.HasClausesQ.issue_rejected hs hk hd he hm h
  | cons allowed _ _ _ _ _ _ _ _ => exact (allowed b s l bs rfl hs hd he hm) hk

namespace RangeClauseExamples

def operation : OpDecl where
  eff := processEnvironmentEff
  tparams := []
  names := []
  params := []
  ret := .base .unit
def signature : OpSig := ⟨[], [], [], .base .unit, processEnvironmentEff⟩

def declarations : Declarations where
  funs := fun _ => none
  cons := fun _ => none
  ops := fun o => if o = "recover" then some operation else none

/-- 同じ Process.Environment に属する利用者の操作の節は、発行の節の拒否条件に妨げられない。 -/
theorem user_clause_accepted (B : Builtins) (op : OpPrim) :
    HasClausesQ declarations B op Qempty [] [] [] [] none Eff.empty
      (.cons (.user "recover") 0 0 (.last .unit) .nil) (.base .unit) Eff.empty := by
  refine .cons (ClauseAllowed.user _ _ _) (sg := signature) ?_ (by decide) rfl rfl (by trivial) ?_ .nil
  · exact ClauseSig.of_opSig (by simp [opSig, opSigAt, declarations, Declarations.core, operation, signature, TypeCtx.values])
      (by intro b s h; cases h)
  · exact .B_Last .E_Unit

/-- 合成表が選ぶ発行の組込みに対する節は、本体が同じ単位値でも拒否される。 -/
theorem standard_issue_clause_rejected (op : OpPrim) :
    ¬ HasClausesQ declarations (StandardModel.builtins declarations.core) op Qempty [] [] [] [] none
      (Eff.single processEnvironmentEff)
      (.cons (.prim ScopeSignatures.pathBasesName) 0 0 (.last .unit) .nil) (.base .unit) Eff.empty := by
  have hs : (StandardModel.builtins declarations.core).sig ScopeSignatures.pathBasesName =
      some StandardModel.Primitive.p156.signature := rfl
  have hk : StandardModel.Primitive.p156.signature.kind = .pathBases := rfl
  obtain ⟨bs, he, hm⟩ := StandardModel.effects_member StandardModel.Primitive.p156 rfl (by decide)
  exact HasClausesQ.issue_rejected (l := processEnvironmentEff) (bs := bs) hs hk rfl he hm

/-- 範囲文脈が非空でも、同じ効果の利用者の操作の節を受理する。 -/
theorem open_user_clause_accepted (B : Builtins) (op : OpPrim) (ks : List Scope.Domain.Kind) :
    OpenSurface.HasClausesQ declarations B ks op Qempty [] [] [] [] none Eff.empty
      (.cons (.user "recover") 0 0 (.last .unit) .nil) (.base .unit) Eff.empty := by
  refine .cons (ClauseAllowed.user _ _ _) (sg := signature) ?_ (by decide) rfl rfl (by trivial) ?_ ?_ .nil
  · exact ClauseSig.of_opSig (by simp [opSig, opSigAt, declarations, Declarations.core, operation, signature, TypeCtx.values])
      (by intro b s h; cases h)
  · exact ⟨(by intro a h; cases h), trivial⟩
  · exact .B_Last .E_Unit

/-- 開いた範囲文脈でも、合成表の発行の操作の節を拒否する。 -/
theorem open_standard_issue_clause_rejected (op : OpPrim) (ks : List Scope.Domain.Kind) :
    ¬ OpenSurface.HasClausesQ declarations (StandardModel.builtins declarations.core) ks op Qempty [] [] [] [] none
      (Eff.single processEnvironmentEff)
      (.cons (.prim ScopeSignatures.pathBasesName) 0 0 (.last .unit) .nil) (.base .unit) Eff.empty := by
  have hs : (StandardModel.builtins declarations.core).sig ScopeSignatures.pathBasesName =
      some StandardModel.Primitive.p156.signature := rfl
  have hk : StandardModel.Primitive.p156.signature.kind = .pathBases := rfl
  obtain ⟨bs, he, hm⟩ := StandardModel.effects_member StandardModel.Primitive.p156 rfl (by decide)
  exact OpenSurface.HasClausesQ.issue_rejected (l := processEnvironmentEff) (bs := bs) hs hk rfl he hm

/-- 別名の展開で生じる、正規形でない入れ子の篩。 -/
def nestedArgument : Ty := .refined (.refined (.base .integer) .falsity) .falsity

def nestedOperation : OpDecl := {operation with names := ["value"], params := [nestedArgument]}

def nestedSignature : OpSig := ⟨[], ["value"], [nestedArgument], .base .unit, processEnvironmentEff⟩

def nestedDeclarations : Declarations :=
  {declarations with ops := fun o => if o = "nested" then some nestedOperation else none}

/-- 操作の引数型の正規形を、宣言の成立条件にはしない。 -/
private theorem nested_argument_not_normal : nestedArgument.norm ≠ nestedArgument := by
  intro h
  change Ty.refined (.base .integer) (.and .falsity .falsity) =
    .refined (.refined (.base .integer) .falsity) .falsity at h
  cases h

private theorem nested_signature_wf : nestedSignature.WF := by
  simp [nestedSignature, OpSig.WF, BinderTypes.LocalWF, nestedArgument, Ty.WF, Ty.NotContCore, Pred.WF, Pred.VarsIn]

/-- 範囲なしの規則が受ける入れ子の篩の節を、空の開いた範囲文脈でも受ける。 -/
theorem nested_clause_no_ranges (B : Builtins) (op : OpPrim) :
    HasClausesQ nestedDeclarations B op Qempty [] [] [] [] none Eff.empty
      (.cons (.user "nested") 1 0 (.last .unit) .nil) (.base .unit) Eff.empty ∧
    OpenSurface.HasClausesQ nestedDeclarations B [] op Qempty [] [] [] [] none Eff.empty
      (.cons (.user "nested") 1 0 (.last .unit) .nil) (.base .unit) Eff.empty := by
  have h : HasClausesQ nestedDeclarations B op Qempty [] [] [] [] none Eff.empty
      (.cons (.user "nested") 1 0 (.last .unit) .nil) (.base .unit) Eff.empty := by
    refine .cons (ClauseAllowed.user _ _ _) (sg := nestedSignature) ?_ (by decide) rfl rfl ?_ (.B_Last .E_Unit) .nil
    · exact ClauseSig.of_opSig (by
        simp [opSig, opSigAt, nestedDeclarations, Declarations.core, nestedOperation,
          nestedSignature, operation, TypeCtx.values]) (by intro b s h; cases h)
    · exact nested_signature_wf
  exact ⟨h, .closed rfl h⟩

/-- 範囲文脈が非空でも、同じ入れ子の篩の節を受ける。 -/
theorem nested_clause_open (B : Builtins) (op : OpPrim) (ks : List Scope.Domain.Kind) :
    nestedArgument.norm ≠ nestedArgument ∧
    OpenSurface.HasClausesQ nestedDeclarations B ks op Qempty [] [] [] [] none Eff.empty
      (.cons (.user "nested") 1 0 (.last .unit) .nil) (.base .unit) Eff.empty := by
  refine ⟨nested_argument_not_normal, ?_⟩
  refine .cons (ClauseAllowed.user _ _ _) (sg := nestedSignature) ?_ (by decide) rfl rfl
    nested_signature_wf ?_ (.B_Last .E_Unit) .nil
  · exact ClauseSig.of_opSig (by
      simp [opSig, opSigAt, nestedDeclarations, Declarations.core, nestedOperation,
        nestedSignature, operation, TypeCtx.values]) (by intro b s h; cases h)
  · constructor
    · intro a ha
      simp only [nestedSignature, List.mem_singleton] at ha
      subst a
      trivial
    · trivial

end RangeClauseExamples
end Benitoite.Release.Refinement.Surface
