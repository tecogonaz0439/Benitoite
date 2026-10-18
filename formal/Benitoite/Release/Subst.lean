import Benitoite.Release.Syntax

/-!
# 置き換えとパターンの照合（段階 B）

段階 A（`Benitoite.Core`）の置き換えを、段階 B の構成に広げる。型の変数は de Bruijn の番号で表す
（`Syntax.lean` の冒頭）。型の置き換え `Ty.substAt c ts es` は、`c` 個の型の変数を束縛した内側で、
番号 `c` から `c + ts.length - 1` の型の変数を `ts` の型（`c` だけずらしたもの）に置き換え、
それより大きい番号を `ts` の長さだけ詰める。型構成子を表す型パラメータの適用 `α[Ā]` の α を置き換えるときは、
置き換えた型を Ā に適用する（`Ty.applyTo`）。
-/

noncomputable section

namespace Benitoite.Release

/-- 型を変換しても引数の個数と契約名の一意性は変わらない。 -/
theorem NamesWF.map {names : List String} {ps : List Ty} (h : NamesWF names ps)
    (f : Ty → Ty) : NamesWF names (ps.map f) := by
  simpa only [NamesWF, List.length_map] using h

mutual
  def Pat.binders : Pat → Nat
    | .wild => 0
    | .var => 1
    | .const _ => 0
    | .con _ args => Pat.bindersList args
    | .range _ _ => 0
    | .list before rest after =>
        Pat.bindersList before + (rest.map ListRest.binders).getD 0 + Pat.bindersList after

  def Pat.bindersList : List Pat → Nat
    | [] => 0
    | p :: ps => Pat.binders p + Pat.bindersList ps
end

/-- 分岐の変数の順は、最初の選択肢の左から現れる順である。 -/
def Arm.bindersOf (alts : List Alt) : Nat :=
  match alts with
  | [] => 0
  | alt :: _ => alt.pat.binders

def Arm.binders (arm : Arm) : Nat := Arm.bindersOf arm.alts

/-! ## 型とエフェクトの置き換え -/

/-- 型の置き換え θ = [T̄/ᾱ, Ē/ρ̄]（束縛の外側での置き換え）。 -/
def Ty.subst (ts : List Ty) (es : List Eff) : Ty → Ty := Ty.substAt 0 ts es

mutual
  def Val.substTyAt (c : Nat) (ts : List Ty) (es : List Eff) : Val → Val
    | .var i => .var i
    | .const k => .const k
    | .fnRef f tys effs => .fnRef f (tys.map (Ty.substAt c ts es)) (effs.map (Eff.substAt c ts es))
    | .prim b tys effs => .prim b (tys.map (Ty.substAt c ts es)) (effs.map (Eff.substAt c ts es))
    | .lam names params body => .lam names (params.map (Ty.substAt c ts es)) (Comp.substTyAt c ts es body)
    | .con k tys args => .con k (tys.map (Ty.substAt c ts es)) (Val.substTyAtList c ts es args)
    | .list elems => .list (Val.substTyAtList c ts es elems)
    | .op o tys => .op o (tys.map (Ty.substAt c ts es))
    | .raise t e => .raise (t.substAt c ts es) (e.substAt c ts es)
    | .loc l => .loc l
    | .mapV ks vs => .mapV (Val.substTyAtList c ts es ks) (Val.substTyAtList c ts es vs)
    | .setV elems => .setV (Val.substTyAtList c ts es elems)
    | .bytesV bs => .bytesV bs
    | .dict i tys args => .dict i (tys.map (Ty.substAt c ts es)) (Val.substTyAtList c ts es args)
    | .super v cl => .super (Val.substTyAt c ts es v) cl

  def Val.substTyAtList (c : Nat) (ts : List Ty) (es : List Eff) : List Val → List Val
    | [] => []
    | v :: vs => Val.substTyAt c ts es v :: Val.substTyAtList c ts es vs

  def Comp.substTyAt (c : Nat) (ts : List Ty) (es : List Eff) : Comp → Comp
    | .ret v => .ret (Val.substTyAt c ts es v)
    | .letIn m n => .letIn (Comp.substTyAt c ts es m) (Comp.substTyAt c ts es n)
    | .app f args => .app (Val.substTyAt c ts es f) (Val.substTyAtList c ts es args)
    | .ite v m n => .ite (Val.substTyAt c ts es v) (Comp.substTyAt c ts es m) (Comp.substTyAt c ts es n)
    | .match v arms => .match (Val.substTyAt c ts es v) (Arm.substTyAtList c ts es arms)
    | .lazyC m => .lazyC (Comp.substTyAt c ts es m)
    | .escape v => .escape (Val.substTyAt c ts es v)
    | .use v m => .use (Val.substTyAt c ts es v) (Comp.substTyAt c ts es m)
    | .handle m h => .handle (Comp.substTyAt c ts es m) (Clause.substTyAtList c ts es h)
    | .resume k v => .resume (Val.substTyAt c ts es k) (Val.substTyAt c ts es v)
    | .meth d m tys effs args =>
        .meth (Val.substTyAt c ts es d) m (tys.map (Ty.substAt c ts es)) (effs.map (Eff.substAt c ts es))
          (Val.substTyAtList c ts es args)

  def Arm.substTyAtList (c : Nat) (ts : List Ty) (es : List Eff) : List Arm → List Arm
    | [] => []
    | .mk alts none m :: arms =>
        .mk alts none (Comp.substTyAt c ts es m) :: Arm.substTyAtList c ts es arms
    | .mk alts (some g) m :: arms =>
        .mk alts (some (Comp.substTyAt c ts es g)) (Comp.substTyAt c ts es m) :: Arm.substTyAtList c ts es arms

  /-- 節の本体では、操作の型パラメータの個数だけ、束縛された型の変数が増える。 -/
  def Clause.substTyAtList (c : Nat) (ts : List Ty) (es : List Eff) : List Clause → List Clause
    | [] => []
    | .mk o n k m :: cs => .mk o n k (Comp.substTyAt (c + k) ts es m) :: Clause.substTyAtList c ts es cs
    | .fail e m :: cs => .fail (e.substAt c ts es) (Comp.substTyAt (c + 1) ts es m) :: Clause.substTyAtList c ts es cs
end

/-- 01-12 の `Mθ`。 -/
def Comp.substTy (ts : List Ty) (es : List Eff) (m : Comp) : Comp := Comp.substTyAt 0 ts es m

def Val.substTy (ts : List Ty) (es : List Eff) (v : Val) : Val := Val.substTyAt 0 ts es v

/-! ## 値の置き換え -/

def upRen (k : Nat) (ξ : Nat → Nat) (i : Nat) : Nat :=
  if i < k then i else ξ (i - k) + k

mutual
  def Val.rename (ξ : Nat → Nat) : Val → Val
    | .var i => .var (ξ i)
    | .const c => .const c
    | .fnRef f tys effs => .fnRef f tys effs
    | .prim b tys effs => .prim b tys effs
    | .lam names params body => .lam names params (Comp.rename (upRen params.length ξ) body)
    | .con c tys args => .con c tys (Val.renameList ξ args)
    | .list elems => .list (Val.renameList ξ elems)
    | .op o tys => .op o tys
    | .raise t e => .raise t e
    | .loc l => .loc l
    | .mapV ks vs => .mapV (Val.renameList ξ ks) (Val.renameList ξ vs)
    | .setV elems => .setV (Val.renameList ξ elems)
    | .bytesV bs => .bytesV bs
    | .dict i tys args => .dict i tys (Val.renameList ξ args)
    | .super v cl => .super (Val.rename ξ v) cl

  def Val.renameList (ξ : Nat → Nat) : List Val → List Val
    | [] => []
    | v :: vs => Val.rename ξ v :: Val.renameList ξ vs

  def Comp.rename (ξ : Nat → Nat) : Comp → Comp
    | .ret v => .ret (Val.rename ξ v)
    | .letIn m n => .letIn (Comp.rename ξ m) (Comp.rename (upRen 1 ξ) n)
    | .app f args => .app (Val.rename ξ f) (Val.renameList ξ args)
    | .ite v m n => .ite (Val.rename ξ v) (Comp.rename ξ m) (Comp.rename ξ n)
    | .match v arms => .match (Val.rename ξ v) (Arm.renameList ξ arms)
    | .lazyC m => .lazyC (Comp.rename ξ m)
    | .escape v => .escape (Val.rename ξ v)
    | .use v m => .use (Val.rename ξ v) (Comp.rename ξ m)
    | .handle m h => .handle (Comp.rename ξ m) (Clause.renameList ξ h)
    | .resume k v => .resume (Val.rename ξ k) (Val.rename ξ v)
    | .meth d m tys effs args => .meth (Val.rename ξ d) m tys effs (Val.renameList ξ args)

  def Arm.renameList (ξ : Nat → Nat) : List Arm → List Arm
    | [] => []
    | .mk alts none m :: arms =>
        .mk alts none (Comp.rename (upRen (Arm.bindersOf alts) ξ) m) :: Arm.renameList ξ arms
    | .mk alts (some g) m :: arms =>
        .mk alts (some (Comp.rename (upRen (Arm.bindersOf alts) ξ) g))
          (Comp.rename (upRen (Arm.bindersOf alts) ξ) m) :: Arm.renameList ξ arms

  def Clause.renameList (ξ : Nat → Nat) : List Clause → List Clause
    | [] => []
    | .mk o n k m :: cs => .mk o n k (Comp.rename (upRen (n + 1) ξ) m) :: Clause.renameList ξ cs
    | .fail e m :: cs => .fail e (Comp.rename (upRen 2 ξ) m) :: Clause.renameList ξ cs
end

def upSubst (k : Nat) (σ : Nat → Val) (i : Nat) : Val :=
  if i < k then .var i else (σ (i - k)).rename (· + k)

mutual
  def Val.subst (σ : Nat → Val) : Val → Val
    | .var i => σ i
    | .const c => .const c
    | .fnRef f tys effs => .fnRef f tys effs
    | .prim b tys effs => .prim b tys effs
    | .lam names params body => .lam names params (Comp.subst (upSubst params.length σ) body)
    | .con c tys args => .con c tys (Val.substList σ args)
    | .list elems => .list (Val.substList σ elems)
    | .op o tys => .op o tys
    | .raise t e => .raise t e
    | .loc l => .loc l
    | .mapV ks vs => .mapV (Val.substList σ ks) (Val.substList σ vs)
    | .setV elems => .setV (Val.substList σ elems)
    | .bytesV bs => .bytesV bs
    | .dict i tys args => .dict i tys (Val.substList σ args)
    | .super v cl => .super (Val.subst σ v) cl

  def Val.substList (σ : Nat → Val) : List Val → List Val
    | [] => []
    | v :: vs => Val.subst σ v :: Val.substList σ vs

  def Comp.subst (σ : Nat → Val) : Comp → Comp
    | .ret v => .ret (Val.subst σ v)
    | .letIn m n => .letIn (Comp.subst σ m) (Comp.subst (upSubst 1 σ) n)
    | .app f args => .app (Val.subst σ f) (Val.substList σ args)
    | .ite v m n => .ite (Val.subst σ v) (Comp.subst σ m) (Comp.subst σ n)
    | .match v arms => .match (Val.subst σ v) (Arm.substList σ arms)
    | .lazyC m => .lazyC (Comp.subst σ m)
    | .escape v => .escape (Val.subst σ v)
    | .use v m => .use (Val.subst σ v) (Comp.subst σ m)
    | .handle m h => .handle (Comp.subst σ m) (Clause.substList σ h)
    | .resume k v => .resume (Val.subst σ k) (Val.subst σ v)
    | .meth d m tys effs args => .meth (Val.subst σ d) m tys effs (Val.substList σ args)

  def Arm.substList (σ : Nat → Val) : List Arm → List Arm
    | [] => []
    | .mk alts none m :: arms =>
        .mk alts none (Comp.subst (upSubst (Arm.bindersOf alts) σ) m) :: Arm.substList σ arms
    | .mk alts (some g) m :: arms =>
        .mk alts (some (Comp.subst (upSubst (Arm.bindersOf alts) σ) g))
          (Comp.subst (upSubst (Arm.bindersOf alts) σ) m) :: Arm.substList σ arms

  def Clause.substList (σ : Nat → Val) : List Clause → List Clause
    | [] => []
    | .mk o n k m :: cs => .mk o n k (Comp.subst (upSubst (n + 1) σ) m) :: Clause.substList σ cs
    | .fail e m :: cs => .fail e (Comp.subst (upSubst 2 σ) m) :: Clause.substList σ cs
end

/-- 01-12 の `M[W̄/x̄]`。束縛した順の最後の値が番号 0 に当たる。 -/
def instSubst (ws : List Val) (i : Nat) : Val :=
  if i < ws.length then (ws.reverse[i]?).getD (.var i) else .var (i - ws.length)

def Comp.instantiate (ws : List Val) (m : Comp) : Comp :=
  Comp.subst (instSubst ws) m

def Val.instantiate (ws : List Val) (v : Val) : Val :=
  Val.subst (instSubst ws) v

/-! ## パターンの照合と分岐の選択 -/

/-- 範囲は Integer または Character の両端を含む。ほかの組合せは照合しない。 -/
def Const.inRange : Const → Const → Const → Bool
  | .integer lo, .integer hi, .integer n => decide (lo ≤ n ∧ n ≤ hi)
  | .character lo, .character hi, .character c => decide (lo.toNat ≤ c.toNat ∧ c.toNat ≤ hi.toNat)
  | _, _, _ => false

mutual
  def Pat.matchVal : Pat → Val → Option (List Val)
    | .wild, _ => some []
    | .var, v => some [v]
    | .const c, .const c' => if c.matches c' then some [] else none
    | .con c ps, .con c' _ args =>
        if c = c' then Pat.matchList ps args else none
    | .range lo hi, .const c => if Const.inRange lo hi c then some [] else none
    | .list before rest after, .list elems => do
        let n := before.length + after.length
        if (if rest.isSome then n ≤ elems.length else n = elems.length) then
          let left ← Pat.matchList before (elems.take before.length)
          let right ← Pat.matchList after (elems.drop (elems.length - after.length))
          let middle := elems.drop before.length |>.take (elems.length - n)
          let bound := match rest with
            | some .bind => [Val.list middle]
            | _ => []
          pure (left ++ bound ++ right)
        else none
    | _, _ => none

  def Pat.matchList : List Pat → List Val → Option (List Val)
    | [], [] => some []
    | p :: ps, v :: vs => do
        let a ← Pat.matchVal p v
        let b ← Pat.matchList ps vs
        pure (a ++ b)
    | _, _ => none
end

/-- 選択肢の束縛を分岐の変数の順に並べ替える。範囲外の番号は照合の失敗になる。 -/
def selectSlots {α : Type} (xs : List α) : List Nat → Option (List α)
  | [] => some []
  | i :: is => do
      let x ← xs[i]?
      let ys ← selectSlots xs is
      pure (x :: ys)

theorem selectSlots_map {α β : Type} (f : α → β) (xs : List α) (slots : List Nat) :
    selectSlots (xs.map f) slots = (selectSlots xs slots).map (List.map f) := by
  induction slots with
  | nil => rfl
  | cons i is ih =>
      simp only [selectSlots, List.getElem?_map]
      cases xs[i]? <;> simp [ih]
      cases selectSlots xs is <;> simp

theorem selectSlots_mem {α : Type} {xs ys : List α} {slots : List Nat}
    (h : selectSlots xs slots = some ys) : ∀ x ∈ ys, x ∈ xs := by
  induction slots generalizing ys with
  | nil => simp [selectSlots] at h; subst ys; simp
  | cons i is ih =>
      simp only [selectSlots] at h
      cases hi : xs[i]? with
      | none => simp [hi] at h
      | some x =>
          cases hs : selectSlots xs is with
          | none => simp [hi, hs] at h
          | some zs =>
              simp [hi, hs] at h; subst ys
              intro y hy
              rcases List.mem_cons.mp hy with rfl | hy
              · exact List.mem_of_getElem? hi
              · exact ih hs y hy

/-- 選択肢を左から調べ、一つ照合した時点で分岐を選ぶ。
型の付いた選択肢では、照合すれば並べ替え（`selectSlots`）に失敗しない
（`AltsTy` の順列の条件による）。 -/
def firstAlt (v : Val) : List Alt → Option (List Val)
  | [] => none
  | alt :: alts =>
      match Pat.matchVal alt.pat v with
      | some ws => selectSlots ws alt.slots
      | none => firstAlt v alts

/-- ガードのない分岐の選択肢だけを網羅性に数える。 -/
def unguardedPats : List Arm → List Pat
  | [] => []
  | .mk alts none _ :: arms => alts.map Alt.pat ++ unguardedPats arms
  | .mk _ (some _) _ :: arms => unguardedPats arms

end Benitoite.Release
