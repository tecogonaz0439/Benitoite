import Benitoite.Release.Refinement.Narrowing

/-!
# 型付きの値の宣言照合

変数の型は文脈から供給し、値の注釈は導入規則から取り出す。
-/
namespace Benitoite.Release.Refinement

/-- lookup が返す型を、その番号を読む文脈で照合する。 -/
def Ctx.Declared (P : Program) (C : List TParam) (Γ : Ctx) : Prop :=
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → Ty.Declared P C Γ a

theorem HasTypeVQ.declared {P B store Q C Γ Φ v a}
    (h : HasTypeVQ P B store Q C Γ Φ v a) (hΓ : Ctx.Declared P C Γ) :
    Ty.Declared P C Γ a := by
  match h with
  | .V_Var hi _ => exact hΓ _ _ hi
  | .V_Const (c := c) _ => cases c <;> trivial
  | .V_Lam _ _ _ _ hd => exact hd
  | .V_List _ _ _ hd => exact hd
  | .V_Fun _ _ _ hi | .V_Prim _ _ _ _ hi | .V_Op _ _ _ hi => exact hi.result.declared
  | .V_Map _ _ _ _ ha hb => exact ⟨ha.declared, hb.declared⟩
  | .V_Set _ _ ha => exact ha.declared
  | .V_Dict _ _ _ _ _ _ _ ha => exact ha.declared
  | .V_Con _ _ _ _ _ ha => exact ha.declared
  | .V_Super _ _ _ hd => exact hd
  | .V_Raise ha => exact ha.declared
  | .V_LocRef _ hd | .V_LocLazy _ hd => exact hd
  | .V_Bytes _ => trivial
  | .V_Sub _ _ _ _ hd => exact hd
  | .V_Refine _ _ _ _ _ _ hda hdp => exact ⟨hda, hdp⟩

theorem HasTypeVsQ.declared {P B store Q C Γ Φ vs as}
    (h : HasTypeVsQ P B store Q C Γ Φ vs as) (hΓ : Ctx.Declared P C Γ) :
    declaredTys P C Γ as := by
  match h with
  | .nil => trivial
  | .cons hv hs => exact ⟨hv.declared hΓ, hs.declared hΓ⟩

theorem HasTypeCQ.declared {P B store Q C Γ Φ R m a e L}
    (h : HasTypeCQ P B store Q C Γ Φ R m a e L) (hΓ : Ctx.Declared P C Γ) :
    Ty.Declared P C Γ a := by
  match h with
  | .C_Return hv => exact hv.declared hΓ
  | .C_Let _ _ hd | .C_BuilderLet _ _ _ hd => exact hd
  | .C_App hv _ => exact (hv.declared hΓ).2.1
  | .C_BuilderOp (kind := kind) (op := op) ha _ _ _ =>
    cases op <;> cases kind <;> first | exact ha.declared | trivial
  | .C_If _ hm _ => exact hm.declared hΓ
  | .C_Lazy _ ha | .C_Escape _ ha | .C_Meth _ _ _ _ _ _ _ _ _ ha => exact ha.declared
  | .C_Use _ _ hb _ => exact hb.declared hΓ
  | .C_Sub _ _ _ _ _ hd => exact hd
  | .C_Eff hb _ => exact hb.declared hΓ

/-- narrowing の呼出し元は、元の値の導出から b の宣言照合を供給できる。 -/
theorem Ctx.Narrows.of_value {P B store Q C Γ Φ v a b}
    (hb : HasTypeVQ P B store Q C Γ Φ v b) (hΓ : Ctx.Declared P C Γ)
    (hl : Ty.LeQ Γ Φ a b) (hw : b.WF 0 C.length Γ.length) (hs : b.Sorted Γ) :
    Ctx.Narrows P C (Γ.extend b) (Φ.map Pred.lift) (Γ.extend a) (Φ.map Pred.lift) :=
  .here hl hw hs (hb.declared hΓ)

end Benitoite.Release.Refinement
