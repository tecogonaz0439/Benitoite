import Benitoite.Release.Refinement.Normalize

/-!
# 文脈・事実・整形式と同時置換

None と値の番号を保ち、篩の self を外側の値から区別する。
-/

namespace Benitoite.Release.Refinement

abbrev Ctx := List (Option Ty)

def termBind (σ : Nat → Term) : Term → Term
  | .var i => σ i
  | .integer n => .integer n
  | .add a b => .add (termBind σ a) (termBind σ b)

def predBind (σ : Nat → Term) : Pred → Pred
  | .truth => .truth
  | .falsity => .falsity
  | .eq a b => .eq (termBind σ a) (termBind σ b)
  | .le a b => .le (termBind σ a) (termBind σ b)
  | .lt a b => .lt (termBind σ a) (termBind σ b)
  | .and p q => .and (predBind σ p) (predBind σ q)
  | .or p q => .or (predBind σ p) (predBind σ q)
  | .not p => .not (predBind σ p)

/-- 通常の文脈に self を加える。 -/
def Pred.lift (p : Pred) : Pred := predBind (fun i => .var (i+1)) p

/-- self を開き、外側の番号を一つ下げる。像へ同じ置換を再適用しない。 -/
def Pred.open (p : Pred) (t : Term) : Pred :=
  predBind (fun i => match i with | 0 => t | j+1 => .var j) p

def termWF (nv : Nat) : Term → Prop
  | .var i => i < nv
  | .integer _ => True
  | .add a b => termWF nv a ∧ termWF nv b

def Pred.WF (nv : Nat) : Pred → Prop
  | .truth | .falsity => True
  | .eq a b | .le a b | .lt a b => termWF nv a ∧ termWF nv b
  | .and p q | .or p q => p.WF nv ∧ q.WF nv
  | .not p => p.WF nv

/-- 述語の整数観測が許される carrier。 -/
def Ty.IntegerCarrier : Ty → Prop
  | .base .integer | .base .integer8 | .base .integer16 | .base .integer32
  | .base .unsignedInteger16 | .base .unsignedInteger32 | .base .unsignedInteger64
  | .base .byte => True
  | .refined a _ => a.IntegerCarrier
  | _ => False

/-- 最外の篩をすべて除いた担い手。子の型の篩は除かない。 -/
def Ty.core : Ty → Ty
  | .refined a _ => a.core
  | a => a

/-- 継続の型は篩の担い手にしない。 -/
def Ty.NotContCore (a : Ty) : Prop := ∀ b t e, a.core ≠ .cont b t e

@[simp] theorem Ty.notContCore_norm (a : Ty) : a.norm.NotContCore ↔ a.NotContCore := by
  cases a <;> simp [Ty.NotContCore, Ty.core, Ty.norm]
  case refined a p => exact Ty.notContCore_norm a

theorem Ty.IntegerCarrier.notContCore {a : Ty} (h : a.IntegerCarrier) : a.NotContCore := by
  cases a <;> simp_all [Ty.IntegerCarrier, Ty.NotContCore, Ty.core]
  case refined a p => exact Ty.IntegerCarrier.notContCore h

def termSorted (Γ : Ctx) : Term → Prop
  | .var i => ∃ a, Γ[i]? = some (some a) ∧ a.IntegerCarrier
  | .integer _ => True
  | .add a b => termSorted Γ a ∧ termSorted Γ b

def Pred.Sorted (Γ : Ctx) (self : Option Ty) : Pred → Prop
  | .truth | .falsity => True
  | .eq a b | .le a b | .lt a b =>
      let Δ := match self with | none => Γ | some a => some a :: Γ
      termSorted Δ a ∧ termSorted Δ b
  | .and p q | .or p q => Pred.Sorted Γ self p ∧ Pred.Sorted Γ self q
  | .not p => Pred.Sorted Γ self p

def Ty.assume : Ty → List Pred
  | .refined a p => p :: a.assume
  | _ => []

/-- 文脈の番号を保ち、各変数の最外の篩だけを事実とする。 -/
def Ctx.facts (Γ : Ctx) : List Pred :=
  (Γ.zipIdx).flatMap fun (a, i) =>
    match a with
    | none => []
    | some a => a.assume.map (fun p => p.open (.var i))

mutual
  def Ty.WF (nr nt nv : Nat) : Ty → Prop
    | .base _ | .bytes | .ctor _ => True
    | .opaque _ ix => ix.WF nr
    | .data _ args => Ty.WFList nr nt nv args
    | .list a | .reference a | .lazy a | .set a | .dict _ a => a.WF nr nt nv
    | .fn ns ps r e => NamesWF ns ps ∧ Ty.WFList nr nt nv ps ∧ r.WF nr nt nv ∧
        Eff.WF nr nt nv e ∧ Eff.Canonical e
    | .tvar i => i < nt
    | .cont b t e => b.WF nr nt nv ∧ t.WF nr nt nv ∧ Eff.WF nr nt nv e ∧ Eff.Canonical e
    | .map a b => a.WF nr nt nv ∧ b.WF nr nt nv
    | .tapp i args => i < nt ∧ Ty.WFList nr nt nv args
    | .refined a p => a.WF nr nt nv ∧ p.WF (nv+1) ∧ a.NotContCore
  def Ty.WFList (nr nt nv : Nat) : List Ty → Prop
    | [] => True
    | a :: as => a.WF nr nt nv ∧ Ty.WFList nr nt nv as
  def Eff.WF (nr nt nv : Nat) : Eff → Prop
    | .mk _ fs => Ty.WFList nr nt nv fs
end

mutual
  def Ty.Sorted (Γ : Ctx) : Ty → Prop
    | .base _ | .opaque _ _ | .tvar _ | .bytes | .ctor _ => True
    | .data _ as | .tapp _ as => sortedTys Γ as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => a.Sorted Γ
    | .fn _ ps r e => sortedTys Γ ps ∧ r.Sorted Γ ∧ sortedEff Γ e
    | .cont b t e => b.Sorted Γ ∧ t.Sorted Γ ∧ sortedEff Γ e
    | .map a b => a.Sorted Γ ∧ b.Sorted Γ
    | .refined a p => a.Sorted Γ ∧ p.Sorted Γ (some a)
  def sortedTys (Γ : Ctx) : List Ty → Prop
    | [] => True
    | a :: as => a.Sorted Γ ∧ sortedTys Γ as
  def sortedEff (Γ : Ctx) : Eff → Prop
    | .mk _ fs => sortedTys Γ fs
end

mutual
  /-- 値の名前空間だけを移動する。篩の self は越えない。 -/
  def Ty.shiftV (k c : Nat) : Ty → Ty
    | .base b => .base b
    | .opaque o ix => .opaque o ix
    | .data d as => .data d (shiftVTys k c as)
    | .list a => .list (a.shiftV k c)
    | .fn ns ps r e => .fn ns (shiftVTys k c ps) (r.shiftV k c) (Eff.shiftV k c e)
    | .tvar i => .tvar i
    | .reference a => .reference (a.shiftV k c)
    | .lazy a => .lazy (a.shiftV k c)
    | .cont b t e => .cont (b.shiftV k c) (t.shiftV k c) (Eff.shiftV k c e)
    | .map a b => .map (a.shiftV k c) (b.shiftV k c)
    | .set a => .set (a.shiftV k c)
    | .bytes => .bytes
    | .dict cl a => .dict cl (a.shiftV k c)
    | .tapp i as => .tapp i (shiftVTys k c as)
    | .ctor φ => .ctor φ
    | .refined a p => .refined (a.shiftV k c)
        (predBind (fun i => .var (if i < c+1 then i else i+k)) p)
  def shiftVTys (k c : Nat) : List Ty → List Ty
    | [] => []
    | a :: as => a.shiftV k c :: shiftVTys k c as
  def Eff.shiftV (k c : Nat) : Eff → Eff
    | .mk a fs => .mk a (shiftVTys k c fs)
end

def Ctx.extend (Γ : Ctx) (a : Ty) : Ctx :=
  some (a.shiftV 1 0) :: Γ.map (Option.map (Ty.shiftV 1 0))
def Ctx.extendNone (Γ : Ctx) : Ctx :=
  none :: Γ.map (Option.map (Ty.shiftV 1 0))

@[simp] theorem Ty.notContCore_shiftV (a : Ty) (k c : Nat) :
    (a.shiftV k c).NotContCore ↔ a.NotContCore := by
  cases a <;> simp [Ty.NotContCore, Ty.core, Ty.shiftV]
  case refined a p => exact Ty.notContCore_shiftV a k c


mutual
  theorem embed_wf {nr nt nv : Nat} {a : Benitoite.Release.Ty} (h : a.WF nr nt) :
      (embedTy a).WF nr nt nv := by
    cases a <;> simp only [Benitoite.Release.Ty.WF] at h <;> simp only [embedTy, Ty.WF]
    all_goals first
      | exact h
      | exact embed_wf h
      | exact embed_wfList h
      | skip
    case fn ns ps r e =>
      exact ⟨by simpa only [NamesWF, Benitoite.Release.NamesWF, embedTys_eq_map, List.length_map] using h.1,
        embed_wfList h.2.1, embed_wf h.2.2.1, embed_eff_wf h.2.2.2.1,
        embed_canonical h.2.2.2.2⟩
    case cont b t e => exact ⟨embed_wf h.1, embed_wf h.2.1, embed_eff_wf h.2.2.1, embed_canonical h.2.2.2⟩
    case map a b => exact ⟨embed_wf h.1, embed_wf h.2⟩
    case tapp i as => exact ⟨h.1, embed_wfList h.2⟩
  private theorem embed_wfList {nr nt nv : Nat} {as : List Benitoite.Release.Ty}
      (h : Benitoite.Release.Ty.WFList nr nt as) : Ty.WFList nr nt nv (embedTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨embed_wf h.1, embed_wfList h.2⟩
  private theorem embed_eff_wf {nr nt nv : Nat} {e : Benitoite.Release.Eff} (h : e.WF nr nt) :
      Eff.WF nr nt nv (embedEff e) := by
    cases e
    exact embed_wfList h
end

/-- 型・行・閉じた範囲と、論理の値の同時置換。 -/
structure SubstEnv where
  types : Nat → Ty
  rows : List Eff
  ranges : List Scope.Domain.Range
  values : Nat → Term

def upValues (σ : Nat → Term) : Nat → Term
  | 0 => .var 0
  | i+1 => termBind (fun j => .var (j+1)) (σ i)

def rawApply (t : Ty) (as : List Ty) : Ty :=
  match t with
  | .ctor (.data d) => .data d as
  | .ctor .list => .list (as.headD (.base .unit))
  | .ctor .set => .set (as.headD (.base .unit))
  | .ctor .map => .map (as.headD (.base .unit)) (as.tail.headD (.base .unit))
  | .ctor .reference => .reference (as.headD (.base .unit))
  | .ctor .lazy => .lazy (as.headD (.base .unit))
  | .tvar i => .tapp i as
  | t => t

def substAtoms (es : List Eff) (a : Atom → Bool) : Atom → Bool := fun x =>
  let kept := match x with
    | .name l r => a (.name l r)
    | .rho i => if i < es.length then false else a (.rho i)
  kept || (List.range es.length).any (fun i =>
    a (.rho i) && match es[i]? with | some e => e.test x | none => false)

def rowFails (es : List Eff) (a : Atom → Bool) : List Ty :=
  ((List.range es.length).filter (fun i => a (.rho i))).flatMap (fun i =>
    match es[i]? with | some e => e.fails | none => [])

mutual
  /-- 入力の子だけに再帰し、型・行の像には同じ置換を再適用しない。 -/
  def Ty.rawBind (θ : SubstEnv) : Ty → Ty
    | .base b => .base b
    | .opaque o ix => .opaque o (ix.inst θ.ranges)
    | .data d as => .data d (rawBindTys θ as)
    | .list a => .list (a.rawBind θ)
    | .fn ns ps r e => .fn ns (rawBindTys θ ps) (r.rawBind θ) (Eff.rawBind θ e)
    | .tvar i => θ.types i
    | .reference a => .reference (a.rawBind θ)
    | .lazy a => .lazy (a.rawBind θ)
    | .cont b t e => .cont (b.rawBind θ) (t.rawBind θ) (Eff.rawBind θ e)
    | .map a b => .map (a.rawBind θ) (b.rawBind θ)
    | .set a => .set (a.rawBind θ)
    | .bytes => .bytes
    | .dict cl a => .dict cl (a.rawBind θ)
    | .tapp i as => rawApply (θ.types i) (rawBindTys θ as)
    | .ctor φ => .ctor φ
    | .refined a p => .refined (a.rawBind θ) (predBind (upValues θ.values) p)
  def rawBindTys (θ : SubstEnv) : List Ty → List Ty
    | [] => []
    | a :: as => a.rawBind θ :: rawBindTys θ as
  def Eff.rawBind (θ : SubstEnv) : Eff → Eff
    | .mk a fs => .mk (substAtoms θ.rows (Benitoite.Release.Eff.instAtoms θ.ranges a))
        (rawBindTys θ fs ++ rowFails θ.rows a)
end

noncomputable def Ty.bind (θ : SubstEnv) (t : Ty) : Ty := (t.rawBind θ).norm
noncomputable def Eff.bind (θ : SubstEnv) (e : Eff) : Eff := (Eff.rawBind θ e).norm

end Benitoite.Release.Refinement
