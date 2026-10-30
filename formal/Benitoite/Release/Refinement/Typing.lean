import Benitoite.Release.Refinement.Subst
import Benitoite.Release.Refinement.Le

/-!
# 有限の文脈と経路条件を持つ値・計算の型付け

捕捉時の文脈とパラメータの束縛は、置換の補題と同じ操作で構成する。
-/

namespace Benitoite.Release.Refinement

def hideConts (Γ : Ctx) : Ctx := Γ.map fun a => match a with
  | some (.cont _ _ _) => none
  | a => a

def hideBuilders (Ψ : StoreTy) : StoreTy := fun l => match Ψ l with
  | some (.builder _) => none
  | a => a

def bindParams (Γ : Ctx) (ps : List Ty) : Ctx :=
  (ps.reverse.map (fun a => some (a.shiftV ps.length 0))) ++
    Γ.map (Option.map (Ty.shiftV ps.length 0))

def liftMany (n : Nat) (Φ : List Pred) : List Pred :=
  Nat.rec Φ (fun _ Ξ => Ξ.map Pred.lift) n

def localExtend (n : Nat) : LocalCtx → LocalCtx
  | [] => []
  | x :: xs => List.replicate n none ++ (x :: xs)

mutual
  /-- 値の型付け。経路条件は通常の文脈の番号で読む。 -/
  inductive HasTypeVQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → Ctx → List Pred → Val → Ty → Prop where
    | V_Var {Ψ Q C Γ Φ i a} : Γ[i]? = some (some a) → (∀ b t ε, a ≠ .cont b t ε) →
        HasTypeVQ P B Ψ Q C Γ Φ (.var i) a
    | V_Const {Ψ Q C Γ Φ c} : ConstOK B c →
        HasTypeVQ P B Ψ Q C Γ Φ (.const c) (Const.type c)
    | V_Lam {Ψ Q C Γ Φ ns ps body r ε} : NamesWF ns ps →
        Ty.WF 0 C.length Γ.length (.fn ns ps r ε) → Ty.Sorted Γ (.fn ns ps r ε) →
        HasTypeCQ P B (hideBuilders Ψ) Q C (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
          (some (r.shiftV ps.length 0)) body (r.shiftV ps.length 0) (Eff.shiftV ps.length 0 ε) [] →
        HasTypeVQ P B Ψ Q C Γ Φ (.lam ns ps body) (.fn ns ps r ε)
    | V_List {Ψ Q C Γ Φ vs a} : HasTypeEachQ P B Ψ Q C Γ Φ vs a →
        Ty.WF 0 C.length Γ.length a → Ty.Sorted Γ a →
        HasTypeVQ P B Ψ Q C Γ Φ (.list vs) (.list a)
    | V_Sub {Ψ Q C Γ Φ v a b} : HasTypeVQ P B Ψ Q C Γ Φ v a →
        Ty.LeQ Γ Φ a b → Ty.WF 0 C.length Γ.length b → Ty.Sorted Γ b →
        HasTypeVQ P B Ψ Q C Γ Φ v b
    | V_Refine {Ψ Q C Γ Φ v a t p} : HasTypeVQ P B Ψ Q C Γ Φ v a →
        Ty.IntegerCarrier a → v.toTerm? = some t → Pred.Sorted Γ (some a) p →
        Pred.WF (Γ.length+1) p → Entails (Γ.facts ++ Φ) (p.open t) →
        HasTypeVQ P B Ψ Q C Γ Φ v (.refined a p)

  inductive HasTypeVsQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → Ctx → List Pred → List Val → List Ty → Prop where
    | nil {Ψ Q C Γ Φ} : HasTypeVsQ P B Ψ Q C Γ Φ [] []
    | cons {Ψ Q C Γ Φ v vs a as} : HasTypeVQ P B Ψ Q C Γ Φ v a →
        HasTypeVsQ P B Ψ Q C Γ Φ vs as → HasTypeVsQ P B Ψ Q C Γ Φ (v::vs) (a::as)

  inductive HasTypeEachQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → Ctx → List Pred → List Val → Ty → Prop where
    | nil {Ψ Q C Γ Φ a} : HasTypeEachQ P B Ψ Q C Γ Φ [] a
    | cons {Ψ Q C Γ Φ v vs a} : HasTypeVQ P B Ψ Q C Γ Φ v a →
        HasTypeEachQ P B Ψ Q C Γ Φ vs a → HasTypeEachQ P B Ψ Q C Γ Φ (v::vs) a

  inductive HasTypeCQ (P : Program) (B : Builtins) :
      StoreTy → NoFailCtx → List TParam → Ctx → List Pred → Option Ty →
      Comp → Ty → Eff → (Δ : LocalCtx := []) → Prop where
    | C_Return {Ψ Q C Γ Φ Δ R v a} : HasTypeVQ P B Ψ Q C Γ Φ v a →
        HasTypeCQ P B Ψ Q C Γ Φ R (.ret v) a Eff.empty Δ
    | C_Let {Ψ Q C Γ Φ Δ R m n a b ε} : HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
        HasTypeCQ P B Ψ Q C (Γ.extend a) (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0))
          n (b.shiftV 1 0) (Eff.shiftV 1 0 ε) (localExtend 1 Δ) →
        HasTypeCQ P B Ψ Q C Γ Φ R (.letIn m n) b ε Δ
    | C_App {Ψ Q C Γ Φ Δ R f args ns as b ε} :
        HasTypeVQ P B Ψ Q C Γ Φ f (.fn ns as b ε) → HasTypeVsQ P B Ψ Q C Γ Φ args as →
        HasTypeCQ P B Ψ Q C Γ Φ R (.app f args) b ε Δ
    | C_Sub {Ψ Q C Γ Φ Δ R m a b ε ε'} : HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
        Ty.LeQ Γ Φ a b → Eff.Covers Γ Φ ε' ε → Ty.WF 0 C.length Γ.length b → Ty.Sorted Γ b →
        HasTypeCQ P B Ψ Q C Γ Φ R m b ε' Δ
    | C_Eff {Ψ Q C Γ Φ Δ R m a ε ε'} : HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
        Eff.Covers Γ Φ ε' ε → HasTypeCQ P B Ψ Q C Γ Φ R m a ε' Δ
end

abbrev HasTypeV (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeVQ P B Ψ Qempty
abbrev HasTypeVs (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeVsQ P B Ψ Qempty
abbrev HasTypeEach (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeEachQ P B Ψ Qempty
abbrev HasTypeC (P : Program) (B : Builtins) (Ψ : StoreTy) := HasTypeCQ P B Ψ Qempty
abbrev HasTypeCL (P : Program) (B : Builtins) (Ψ : StoreTy) (C : List TParam)
    (Δ : LocalCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (m : Comp) (a : Ty) (ε : Eff) :=
  HasTypeCQ P B Ψ Qempty C Γ Φ R m a ε Δ

end Benitoite.Release.Refinement
