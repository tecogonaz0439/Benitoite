import Benitoite.Release.NoFail
import Benitoite.Release.FiniteSupport

/-!
# 表層の単一 Fail

具体化した型と効果を検査する。Fail を持たない行の和は制限せず、Fail を持つ位置だけ
同じエラー型と署名由来の NoFail 行を要求する（設計書 01-12「型付きの失敗の表層検査」）。
Release の効果包含にはこの制限を課さない。
-/
namespace Benitoite.Surface
open Benitoite.Release

def SingleFail (Q : NoFailCtx) (e : Eff) : Prop :=
  ∀ t ∈ e.fails, (∀ u ∈ e.fails, u = t) ∧ ∀ i, e.test (.rho i) = true → Q i

mutual
  def SingleTy (Q : NoFailCtx) : Ty → Prop
    | .data _ ts | .tapp _ ts => SingleTys Q ts
    | .list t | .reference t | .lazy t | .set t | .dict _ t => SingleTy Q t
    | .fn _ ps r e => SingleTys Q ps ∧ SingleTy Q r ∧ SingleEff Q e
    | .cont a b e => SingleTy Q a ∧ SingleTy Q b ∧ SingleEff Q e
    | .map a b => SingleTy Q a ∧ SingleTy Q b
    | _ => True
  def SingleTys (Q : NoFailCtx) : List Ty → Prop
    | [] => True
    | t :: ts => SingleTy Q t ∧ SingleTys Q ts
  def SingleEff (Q : NoFailCtx) : Eff → Prop
    | .mk a fs => SingleFail Q (.mk a fs) ∧ SingleTys Q fs
end

end Benitoite.Surface
