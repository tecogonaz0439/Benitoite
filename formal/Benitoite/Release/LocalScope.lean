import Benitoite.Release.Typing
import Benitoite.Release.LocalTyping

/-!
# 局所参照の範囲と通常値の捕捉禁止

型や契約名の条件と分け、局所番号の範囲と専用の場所の出現を調べる。
設計書 01-12「構築器の分類と環境の対応」に対応する。
-/
namespace Benitoite.Release

/-- 束縛番号と実行場所を別の条件で調べる。 -/
def LocalRef.Allowed (depth : Nat) (places : Nat → Prop) : LocalRef → Prop
  | .bound i => i < depth
  | .loc l => places l

theorem LocalRef.HasKind.allowed {Ψ Δ r k depth places} (h : HasKind Ψ Δ r k)
    (hΔ : Δ.Scoped depth) (hΨ : Ψ.BuilderPlaces places) : r.Allowed depth places := by
  cases h with
  | bound hi => exact hΔ _ _ hi
  | loc hl => exact hΨ _ _ hl

mutual
  /-- 通常値の内部のラムダも含めて局所参照を調べる。 -/
  def Val.LocalRefs (depth : Nat) (places : Nat → Prop) : Val → Prop
    | .lam _ ps body => Comp.LocalRefs (depth + ps.length) places body
    | .con _ _ vs | .list vs | .setV vs | .dict _ _ vs => Val.LocalRefsList depth places vs
    | .mapV ks vs => Val.LocalRefsList depth places ks ∧ Val.LocalRefsList depth places vs
    | .super v _ => Val.LocalRefs depth places v
    | .var .. | .const .. | .fnRef .. | .prim .. | .op .. | .raise .. | .loc .. | .bytesV .. => True
  def Val.LocalRefsList (depth : Nat) (places : Nat → Prop) : List Val → Prop
    | [] => True
    | v :: vs => Val.LocalRefs depth places v ∧ Val.LocalRefsList depth places vs
  def Comp.LocalRefs (depth : Nat) (places : Nat → Prop) : Comp → Prop
    | .builderLet _ body => Comp.LocalRefs (depth + 1) places body
    | .builderOp _ _ r vs => r.Allowed depth places ∧ Val.LocalRefsList depth places vs
    | .ret v | .escape v => Val.LocalRefs depth places v
    | .letIn m n => Comp.LocalRefs depth places m ∧ Comp.LocalRefs (depth + 1) places n
    | .app f vs | .meth f _ _ _ vs => Val.LocalRefs depth places f ∧ Val.LocalRefsList depth places vs
    | .ite v m n => Val.LocalRefs depth places v ∧ Comp.LocalRefs depth places m ∧ Comp.LocalRefs depth places n
    | .match v arms => Val.LocalRefs depth places v ∧ Arm.LocalRefsList depth places arms
    | .lazyC m => Comp.LocalRefs depth places m
    | .use v m => Val.LocalRefs depth places v ∧ Comp.LocalRefs depth places m
    | .handle m cs => Comp.LocalRefs depth places m ∧ Clause.LocalRefsList depth places cs
    | .resume k v => Val.LocalRefs depth places k ∧ Val.LocalRefs depth places v
  def Arm.LocalRefsList (depth : Nat) (places : Nat → Prop) : List Arm → Prop
    | [] => True
    | .mk alts none m :: arms => Comp.LocalRefs (depth + Arm.bindersOf alts) places m ∧ Arm.LocalRefsList depth places arms
    | .mk alts (some g) m :: arms => Comp.LocalRefs (depth + Arm.bindersOf alts) places g ∧
        Comp.LocalRefs (depth + Arm.bindersOf alts) places m ∧ Arm.LocalRefsList depth places arms
  def Clause.LocalRefsList (depth : Nat) (places : Nat → Prop) : List Clause → Prop
    | [] => True
    | .mk _ n _ m :: cs => Comp.LocalRefs (depth + n + 1) places m ∧ Clause.LocalRefsList depth places cs
    | .fail _ m :: cs => Comp.LocalRefs (depth + 2) places m ∧ Clause.LocalRefsList depth places cs
end

/-- 実行場所を許し、自由な bound の範囲だけを検査する。 -/
def LocalScoped (depth : Nat) (m : Comp) : Prop := Comp.LocalRefs depth (fun _ => True) m
/-- 内側の専用束縛は許し、自由な bound と専用 loc は許さない。 -/
def NoFreeBuilders (m : Comp) : Prop := Comp.LocalRefs 0 (fun _ => False) m
/-- 通常値についても同じ捕捉禁止を表す。 -/
def Val.NoFreeBuilders (v : Val) : Prop := Val.LocalRefs 0 (fun _ => False) v

variable {P : Program} {B : Builtins} {Q : NoFailCtx}

mutual
  /-- 値の捕捉境界の空Δと隠したΨから、自由な専用参照の不在を導く。 -/
  theorem HasTypeVQ.localRefs {depth : Nat} {places : Nat → Prop} {Ψ C Γ v a} (h : HasTypeVQ P B Ψ Q C Γ v a) :
      Val.LocalRefs depth places v := by
    match h with
    | .V_Var _ _ => trivial
    | .V_Const => trivial
    | .V_Fun .. => trivial
    | .V_Prim .. => trivial
    | .V_Op _ _ _ => trivial
    | .V_Raise _ _ => trivial
    | .V_Lam hn hw hb => exact HasTypeCQ.localRefs (depth := _) (places := places) hb (.nil _) (.hidden _ _)
    | .V_Con _ _ hs => exact HasTypeVsQ.localRefs (depth := _) (places := places) hs
    | .V_List hs _ => exact HasTypeEachQ.localRefs (depth := _) (places := places) hs
    | .V_LocRef _ => trivial
    | .V_LocLazy _ => trivial
    | .V_Map hk hv _ _ _ _ => exact ⟨HasTypeEachQ.localRefs (depth := _) (places := places) hk, HasTypeEachQ.localRefs (depth := _) (places := places) hv⟩
    | .V_Set hs _ _ => exact HasTypeEachQ.localRefs (depth := _) (places := places) hs
    | .V_Bytes => trivial
    | .V_Dict _ _ hs => exact HasTypeVsQ.localRefs (depth := _) (places := places) hs
    | .V_Super hv _ _ =>
        simp only [Val.LocalRefs]; exact HasTypeVQ.localRefs (depth := _) (places := places) hv
    | .V_Sub hv _ hw => exact HasTypeVQ.localRefs (depth := _) (places := places) hv

  theorem HasTypeVsQ.localRefs {depth : Nat} {places : Nat → Prop} {Ψ C Γ vs as} (h : HasTypeVsQ P B Ψ Q C Γ vs as) :
      Val.LocalRefsList depth places vs := by
    match h with
    | .nil => trivial
    | .cons hv hs => exact ⟨HasTypeVQ.localRefs (depth := _) (places := places) hv, HasTypeVsQ.localRefs (depth := _) (places := places) hs⟩

  theorem HasTypeEachQ.localRefs {depth : Nat} {places : Nat → Prop} {Ψ C Γ vs a} (h : HasTypeEachQ P B Ψ Q C Γ vs a) :
      Val.LocalRefsList depth places vs := by
    match h with
    | .nil => trivial
    | .cons hv hs => exact ⟨HasTypeVQ.localRefs (depth := _) (places := places) hv, HasTypeEachQ.localRefs (depth := _) (places := places) hs⟩

  theorem HasTypeCQ.localRefs {depth : Nat} {places : Nat → Prop} {Δl : LocalCtx} {Ψ C Γ R m a ε} (h : HasTypeCQ P B Ψ Q C Γ R m a ε Δl)
      (hΔ : Δl.Scoped depth) (hΨ : Ψ.BuilderPlaces places) :
      Comp.LocalRefs depth places m := by
    match h with
    | .C_BuilderLet hw hb =>
        simp only [Comp.LocalRefs]
        exact HasTypeCQ.localRefs (depth := depth + 1) (places := places) hb (hΔ.builder _) hΨ
    | .C_BuilderOp hw hr ha => exact ⟨hr.allowed hΔ hΨ, HasTypeVsQ.localRefs ha⟩
    | .C_Return hv => exact HasTypeVQ.localRefs (depth := _) (places := places) hv
    | .C_Sub hm _ _ hw => exact HasTypeCQ.localRefs (depth := _) (places := places) hm hΔ hΨ
    | .C_Eff hm _ => exact HasTypeCQ.localRefs (depth := _) (places := places) hm hΔ hΨ
    | .C_Let hm hn => exact ⟨HasTypeCQ.localRefs (depth := _) (places := places) hm hΔ hΨ, HasTypeCQ.localRefs (depth := _) (places := places) hn (hΔ.extend 1) hΨ⟩
    | .C_App hf hs => exact ⟨HasTypeVQ.localRefs (depth := _) (places := places) hf, HasTypeVsQ.localRefs (depth := _) (places := places) hs⟩
    | .C_If hv hm hn => exact ⟨HasTypeVQ.localRefs (depth := _) (places := places) hv, HasTypeCQ.localRefs (depth := _) (places := places) hm hΔ hΨ, HasTypeCQ.localRefs (depth := _) (places := places) hn hΔ hΨ⟩
    | .C_Match hv hs _ => exact ⟨HasTypeVQ.localRefs (depth := _) (places := places) hv, HasTypeArmsQ.localRefs (depth := _) (places := places) hs hΔ hΨ⟩
    | .C_Lazy hm =>
        simp only [Comp.LocalRefs]; exact HasTypeCQ.localRefs (depth := _) (places := places) hm (.nil _) (.hidden _ _)
    | .C_Escape hv _ => exact HasTypeVQ.localRefs (depth := _) (places := places) hv
    | .C_Use hv _ hm _ => exact ⟨HasTypeVQ.localRefs (depth := _) (places := places) hv, HasTypeCQ.localRefs (depth := _) (places := places) hm hΔ hΨ⟩
    | .C_Handle hm _ hs => exact ⟨HasTypeCQ.localRefs (depth := _) (places := places) hm hΔ hΨ, HasTypeClausesQ.localRefs (depth := _) (places := places) hs hΔ hΨ⟩
    | .C_Handle_Fail hm _ _ hc => exact ⟨HasTypeCQ.localRefs (depth := _) (places := places) hm hΔ hΨ, HasFailureClause.localRefs (depth := _) (places := places) hc hΔ hΨ⟩
    | .C_Resume _ hv => exact ⟨trivial, HasTypeVQ.localRefs (depth := _) (places := places) hv⟩
    | .C_ResumeL _ hv => exact ⟨trivial, HasTypeVQ.localRefs (depth := _) (places := places) hv⟩
    | .C_Meth hv _ _ _ _ _ _ hs => exact ⟨HasTypeVQ.localRefs (depth := _) (places := places) hv, HasTypeVsQ.localRefs (depth := _) (places := places) hs⟩

  theorem HasTypeArmsQ.localRefs {depth : Nat} {places : Nat → Prop} {Δl : LocalCtx} {Ψ C Γ R arms a b ε} (h : HasTypeArmsQ P B Ψ Q C Γ R arms a b ε Δl)
      (hΔ : Δl.Scoped depth) (hΨ : Ψ.BuilderPlaces places) :
      Arm.LocalRefsList depth places arms := by
    match h with
    | .nil _ => trivial
    | .plain hp hm hs => exact ⟨HasTypeCQ.localRefs (depth := _) (places := places) hm (by simpa [hp.2.1] using hΔ.extend _) hΨ, HasTypeArmsQ.localRefs (depth := _) (places := places) hs hΔ hΨ⟩
    | .guarded hp hg hm hs => exact ⟨HasTypeCQ.localRefs (depth := _) (places := places) hg (by simpa [hp.2.1] using hΔ.extend _) hΨ, HasTypeCQ.localRefs (depth := _) (places := places) hm (by simpa [hp.2.1] using hΔ.extend _) hΨ, HasTypeArmsQ.localRefs (depth := _) (places := places) hs hΔ hΨ⟩

  theorem HasTypeClausesQ.localRefs {depth : Nat} {places : Nat → Prop} {Δl : LocalCtx} {Ψ C Γ R cs t ε} (h : HasTypeClausesQ P B Ψ Q C Γ R cs t ε Δl)
      (hΔ : Δl.Scoped depth) (hΨ : Ψ.BuilderPlaces places) :
      Clause.LocalRefsList depth places cs := by
    match h with
    | .nil => trivial
    | .cons _ _ _ _ _ hm hs => exact ⟨HasTypeCQ.localRefs (depth := _) (places := places) hm (.nil _) (.hidden _ _), HasTypeClausesQ.localRefs (depth := _) (places := places) hs hΔ hΨ⟩
  theorem HasFailureClause.localRefs {depth : Nat} {places : Nat → Prop} {Δl : LocalCtx} {Ψ C Γ E R h t ε}
      (hc : HasFailureClause P B Ψ Q C Γ E R h t ε Δl)
      (_hΔ : Δl.Scoped depth) (_hΨ : Ψ.BuilderPlaces places) : Clause.LocalRefsList depth places h := by
    match hc with
    | .one _ _ _ hb => exact ⟨HasTypeCQ.localRefs (depth := _) (places := places) hb (.nil _) (.hidden _ _), trivial⟩

end

/-- 通常の型付き値には、ラムダの内部を含め自由な局所参照がない。 -/
theorem builder_value_no_free_local {Ψ C Γ v a} (h : HasTypeVQ P B Ψ Q C Γ v a) :
    v.NoFreeBuilders := h.localRefs

end Benitoite.Release
