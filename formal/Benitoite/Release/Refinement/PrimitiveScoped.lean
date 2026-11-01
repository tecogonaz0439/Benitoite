import Benitoite.Release.Refinement.SourceScope

/-! # 組み込みの依存列の形成（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement

/-- 範囲変数は操作の対象の最上位にあり、他の注釈は閉じた範囲を持つ。 -/
def Ty.TargetWF (nr nt nv : Nat) : Ty → Prop
  | .opaque _ (.rvar i) | .scoped _ _ (.rvar i) => i < nr
  | a => a.WF 0 nt nv


def BinderTypes.TargetWF (nr nt : Nat) : Nat → List Ty → Prop
  | _, [] => True
  | n, a :: as => a.TargetWF nr nt n ∧ BinderTypes.TargetWF nr nt (n+1) as


def PrimSig.OperationWF (s : PrimSig) : Prop :=
  BinderTypes.TargetWF s.rkinds.length s.tparams.length 0 s.params ∧
    s.ret.WF 0 s.tparams.length s.params.length


/-- 宣言した範囲・型・行の深さと、依存する値束縛の形成を同時に読む。 -/
structure PrimSig.Scoped (P : Program) (s : PrimSig) : Prop where
  names : NamesWF s.names s.params
  source : (Ty.dependentFn s.tel).SourceScoped
    s.rkinds.length s.tparams.length s.neffs 0
  kinds : Ty.HasKind P (TypeCtx.kinds s.tparams) (.dependentFn s.tel) .value
  sorted : Tel.Sorted [] s.tel
  declared : Tel.Declared P s.tparams [] s.tel
  operation : s.opEff ≠ none → s.OperationWF ∧
    (∀ a ∈ s.params, (∃ o ix, a = .opaque o ix) ∨
      (∃ o k ix, a = .scoped o k ix) ∨ a.RangesScoped 0) ∧
    s.ret.RangesScoped 0

end Benitoite.Release.Refinement
