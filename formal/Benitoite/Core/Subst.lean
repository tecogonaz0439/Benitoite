import Benitoite.Core.Syntax

/-!
# 置き換えとパターンの照合（段階 A）

設計書 01-12 の `Mθ`（型とエフェクトの置き換え）、`M[V/x]`（値の置き換え）、
`match(p, V)`（パターンの照合）を定める。

項の変数は de Bruijn の番号で表す（`Syntax.lean` の冒頭）。値の置き換えは、番号から値への関数
（並列の置き換え）で定める。01-12 の `M[W̄/x̄]` は `Comp.instantiate` に当たる。
-/

namespace Benitoite.Core

/-! ## 型とエフェクトの置き換え `θ = [T̄/ᾱ, Ē/ρ̄]` -/

/-- 型の置き換え。番号が `ts` の長さより小さい `tvar i` を `ts[i]` に置き換え、
関数の型のエフェクトに `Eff.substRho es` を適用する。 -/
def Ty.subst (ts : List Ty) (es : List Eff) : Ty → Ty
  | .base ι => .base ι
  | .opaque o => .opaque o
  | .data d args => .data d (args.map (Ty.subst ts es))
  | .list a => .list (Ty.subst ts es a)
  | .fn params ret eff => .fn (params.map (Ty.subst ts es)) (Ty.subst ts es ret) (Eff.substRho es eff)
  | .tvar i => (ts[i]?).getD (.tvar i)

mutual
  /-- 値の中の型とエフェクトに θ を適用する。 -/
  def Val.substTy (ts : List Ty) (es : List Eff) : Val → Val
    | .var i => .var i
    | .const c => .const c
    | .fnRef f tys effs => .fnRef f (tys.map (Ty.subst ts es)) (effs.map (Eff.substRho es))
    | .prim b tys effs => .prim b (tys.map (Ty.subst ts es)) (effs.map (Eff.substRho es))
    | .lam params body => .lam (params.map (Ty.subst ts es)) (Comp.substTy ts es body)
    | .con c tys args => .con c (tys.map (Ty.subst ts es)) (Val.substTyList ts es args)
    | .list elems => .list (Val.substTyList ts es elems)

  def Val.substTyList (ts : List Ty) (es : List Eff) : List Val → List Val
    | [] => []
    | v :: vs => Val.substTy ts es v :: Val.substTyList ts es vs

  /-- 計算の中の型とエフェクトに θ を適用する（01-12 の `Mθ`）。 -/
  def Comp.substTy (ts : List Ty) (es : List Eff) : Comp → Comp
    | .ret v => .ret (Val.substTy ts es v)
    | .letIn m n => .letIn (Comp.substTy ts es m) (Comp.substTy ts es n)
    | .app f args => .app (Val.substTy ts es f) (Val.substTyList ts es args)
    | .ite v m n => .ite (Val.substTy ts es v) (Comp.substTy ts es m) (Comp.substTy ts es n)
    | .match v arms => .match (Val.substTy ts es v) (Comp.substTyArms ts es arms)

  def Comp.substTyArms (ts : List Ty) (es : List Eff) : List (Pat × Comp) → List (Pat × Comp)
    | [] => []
    | (p, m) :: arms => (p, Comp.substTy ts es m) :: Comp.substTyArms ts es arms
end

/-! ## 値の置き換え -/

mutual
  /-- パターンが束縛する変数の個数。 -/
  def Pat.binders : Pat → Nat
    | .wild => 0
    | .var => 1
    | .const _ => 0
    | .con _ args => Pat.bindersList args

  def Pat.bindersList : List Pat → Nat
    | [] => 0
    | p :: ps => Pat.binders p + Pat.bindersList ps
end

/-- k 個の変数を束縛する位置の内側へ、番号の付け替えを持ち上げる。 -/
def upRen (k : Nat) (ξ : Nat → Nat) (i : Nat) : Nat :=
  if i < k then i else ξ (i - k) + k

mutual
  /-- 値の自由な変数の番号を付け替える。 -/
  def Val.rename (ξ : Nat → Nat) : Val → Val
    | .var i => .var (ξ i)
    | .const c => .const c
    | .fnRef f tys effs => .fnRef f tys effs
    | .prim b tys effs => .prim b tys effs
    | .lam params body => .lam params (Comp.rename (upRen params.length ξ) body)
    | .con c tys args => .con c tys (Val.renameList ξ args)
    | .list elems => .list (Val.renameList ξ elems)

  def Val.renameList (ξ : Nat → Nat) : List Val → List Val
    | [] => []
    | v :: vs => Val.rename ξ v :: Val.renameList ξ vs

  def Comp.rename (ξ : Nat → Nat) : Comp → Comp
    | .ret v => .ret (Val.rename ξ v)
    | .letIn m n => .letIn (Comp.rename ξ m) (Comp.rename (upRen 1 ξ) n)
    | .app f args => .app (Val.rename ξ f) (Val.renameList ξ args)
    | .ite v m n => .ite (Val.rename ξ v) (Comp.rename ξ m) (Comp.rename ξ n)
    | .match v arms => .match (Val.rename ξ v) (Comp.renameArms ξ arms)

  def Comp.renameArms (ξ : Nat → Nat) : List (Pat × Comp) → List (Pat × Comp)
    | [] => []
    | (p, m) :: arms => (p, Comp.rename (upRen p.binders ξ) m) :: Comp.renameArms ξ arms
end

/-- k 個の変数を束縛する位置の内側へ、置き換えを持ち上げる。 -/
def upSubst (k : Nat) (σ : Nat → Val) (i : Nat) : Val :=
  if i < k then .var i else (σ (i - k)).rename (· + k)

mutual
  /-- 値の自由な変数を、番号ごとに値へ置き換える（並列の置き換え）。 -/
  def Val.subst (σ : Nat → Val) : Val → Val
    | .var i => σ i
    | .const c => .const c
    | .fnRef f tys effs => .fnRef f tys effs
    | .prim b tys effs => .prim b tys effs
    | .lam params body => .lam params (Comp.subst (upSubst params.length σ) body)
    | .con c tys args => .con c tys (Val.substList σ args)
    | .list elems => .list (Val.substList σ elems)

  def Val.substList (σ : Nat → Val) : List Val → List Val
    | [] => []
    | v :: vs => Val.subst σ v :: Val.substList σ vs

  def Comp.subst (σ : Nat → Val) : Comp → Comp
    | .ret v => .ret (Val.subst σ v)
    | .letIn m n => .letIn (Comp.subst σ m) (Comp.subst (upSubst 1 σ) n)
    | .app f args => .app (Val.subst σ f) (Val.substList σ args)
    | .ite v m n => .ite (Val.subst σ v) (Comp.subst σ m) (Comp.subst σ n)
    | .match v arms => .match (Val.subst σ v) (Comp.substArms σ arms)

  def Comp.substArms (σ : Nat → Val) : List (Pat × Comp) → List (Pat × Comp)
    | [] => []
    | (p, m) :: arms => (p, Comp.subst (upSubst p.binders σ) m) :: Comp.substArms σ arms
end

/-- 最も内側の n 個の変数を値の並び `ws`（束縛した順）で置き換え、残りの番号を n だけ詰める。
01-12 の `M[W̄/x̄]` に当たる。束縛した順の最後の値が番号 0 に当たる。 -/
def instSubst (ws : List Val) (i : Nat) : Val :=
  if i < ws.length then (ws.reverse[i]?).getD (.var i) else .var (i - ws.length)

def Comp.instantiate (ws : List Val) (m : Comp) : Comp :=
  Comp.subst (instSubst ws) m

/-! ## パターンの照合 `match(p, V)` -/

mutual
  /-- `match(p, V)`。照合したら、束縛する変数の値を左から順に並べて返す。 -/
  def Pat.matchVal : Pat → Val → Option (List Val)
    | .wild, _ => some []
    | .var, v => some [v]
    | .const c, .const c' => if c.matches c' then some [] else none
    | .con c ps, .con c' _ args =>
        if c = c' then Pat.matchList ps args else none
    | _, _ => none

  def Pat.matchList : List Pat → List Val → Option (List Val)
    | [], [] => some []
    | p :: ps, v :: vs => do
        let a ← Pat.matchVal p v
        let b ← Pat.matchList ps vs
        pure (a ++ b)
    | _, _ => none
end

/-- E-Match が選ぶ分岐。照合する最初の分岐の本体と、束縛する値の並びを返す。 -/
def firstMatch (v : Val) : List (Pat × Comp) → Option (Comp × List Val)
  | [] => none
  | (p, m) :: arms =>
      match Pat.matchVal p v with
      | some ws => some (m, ws)
      | none => firstMatch v arms

end Benitoite.Core
