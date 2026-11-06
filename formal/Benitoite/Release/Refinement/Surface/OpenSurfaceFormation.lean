import Benitoite.Release.Refinement.Surface.OpenSurface
import Benitoite.Release.Refinement.Surface.Property1Base
import Benitoite.Release.Refinement.ContextNormEq

/-! # 開いた表層の注釈・文脈と具体化

型と文脈の対応は、元の構文から計算する。全具体化の型付けを前提にはしない。
-/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

theorem rangeCtx_length (rs : List RangeExpr) (Γ : Ctx) : (rangeCtx rs Γ).length = Γ.length := by
  cases rs <;> simp [rangeCtx, Ctx.mapRanges]

@[simp] theorem rangeLocal_nil (rs : List RangeExpr) : rangeLocal rs [] = [] := by
  cases rs <;> rfl

theorem rangeTy_ordinary {a : Ty} (h : Ordinary a) (rs : List RangeExpr) : Ordinary (rangeTy rs a) := by
  cases rs with
  | nil => exact h
  | cons r rs =>
    exact (Ty.ordinary_norm _).mpr ((Ty.ordinary_rawMapRanges _ _).mpr h)

theorem rangeTy_shiftV (rs : List RangeExpr) (a : Ty) (k c : Nat) :
    rangeTy rs (a.shiftV k c) = (rangeTy rs a).shiftV k c := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    exact (congrArg Ty.norm (Ty.rawMapRanges_shiftV a (rangeAt 0 (r :: rs)) k c)).trans
      (Ty.norm_shiftV _ k c)

theorem rangeEff_shiftV (rs : List RangeExpr) (e : Eff) (k c : Nat) :
    rangeEff rs (Eff.shiftV k c e) = Eff.shiftV k c (rangeEff rs e) := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    exact (congrArg Eff.norm (Eff.rawMapRanges_shiftV e (rangeAt 0 (r :: rs)) k c)).trans
      (Eff.norm_shiftV _ k c)

theorem rangeCtx_extend (rs : List RangeExpr) (Γ : Ctx) (a : Ty) :
    rangeCtx rs (Γ.extend a) = (rangeCtx rs Γ).extend (rangeTy rs a) := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    simp only [rangeCtx, rangeTy, Ctx.mapRanges, Ctx.extend, List.map_cons, Option.map_some,
      List.map_map, Option.map_map, Function.comp_def]
    congr 2
    · exact rangeTy_shiftV (r :: rs) a 1 0
    · funext a
      cases a with
      | none => rfl
      | some a => exact congrArg some (rangeTy_shiftV (r :: rs) a 1 0)

theorem rangeCtx_lookup {Γ : Ctx} {i : Nat} {a : Ty} (h : Γ[i]? = some (some a))
    (rs : List RangeExpr) : (rangeCtx rs Γ)[i]? = some (some (rangeTy rs a)) := by
  cases rs with
  | nil => exact h
  | cons r rs => simp only [rangeCtx, Ctx.mapRanges, List.getElem?_map, h, Option.map_some, rangeTy]; rfl

theorem rangeCtx_facts (rs : List RangeExpr) (Γ : Ctx) : (rangeCtx rs Γ).facts = Γ.facts := by
  cases rs <;> simp [rangeCtx]

theorem rangeTel_done (rs : List RangeExpr) (a : Ty) (e : Eff) :
    rangeTel rs (.done a e) = .done (rangeTy rs a) (rangeEff rs e) := by
  cases rs <;> rfl

theorem rangeTel_param (rs : List RangeExpr) (n : String) (a : Ty) (t : Tel) :
    rangeTel rs (.param n a t) = .param n (rangeTy rs a) (rangeTel rs t) := by
  cases rs <;> rfl

theorem rangeTel_shiftV (rs : List RangeExpr) (t : Tel) (k c : Nat) :
    rangeTel rs (Tel.shiftV k c t) = Tel.shiftV k c (rangeTel rs t) := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    exact (congrArg Tel.norm (Tel.rawMapRanges_shiftV t (rangeAt 0 (r :: rs)) k c)).trans
      (Tel.norm_shiftV _ k c)

theorem annotation {P ks C Γ a} {B : Builtins} (h : Ty.AnnotationR P ks C Γ a) (σ : Instance ks) :
    Ty.Annotation P C (rangeCtx σ.val Γ) (rangeTy σ.val a) := by
  cases hr : σ.val with
  | nil =>
    have hl := σ.property.1
    rw [hr] at hl
    have hk : ks = [] := List.eq_nil_of_length_eq_zero hl.symm
    subst ks
    exact ⟨h.wf, h.sorted, h.declared⟩
  | cons r rs =>
    have ha := Surface.instR_annotation h.wf h.sorted h.declared (hr ▸ σ.property.1)
    have hc : (Γ.rawMapRanges (rangeAt 0 (r :: rs))).NormEq (Γ.mapRanges (rangeAt 0 (r :: rs))) := by
      simp only [Ctx.NormEq, Ctx.rawMapRanges, Ctx.mapRanges, List.map_map, Option.map_map,
        Function.comp_def, Ty.mapRanges, Ty.norm_idem]
    exact hc.annotation (B := B) ha

theorem annotation_sameTypes {P P' ks C Γ a} (h : Ty.AnnotationR P ks C Γ a) (ht : P.SameTypes P') :
    Ty.AnnotationR P' ks C Γ a := ⟨h.wf, h.sorted, h.declared.sameTypes ht⟩

theorem annotation_under {P ks C Γ a} (h : Ty.AnnotationR P ks C Γ a) (as : List Ty) :
    Ty.AnnotationR P ks C (bindParams Γ as) (a.shiftV as.length 0) := by
  refine ⟨?_, (FullShiftMap.outer Γ as).values.sorted h.sorted,
    (FullShiftMap.outer Γ as).values.declared h.declared⟩
  simpa only [bindParams, List.length_append, List.length_map, List.length_reverse, Nat.add_comm] using
    Ty.wf_shiftV h.wf as.length 0

theorem annotation_shift {P ks C Γ Δ a k c} (h : Ty.AnnotationR P ks C Γ a)
    (hm : ShiftMap k c Γ Δ) : Ty.AnnotationR P ks C Δ (a.shiftV k c) := by
  exact ⟨by simpa only [hm.length] using Ty.wf_shiftV h.wf k c,
    hm.sorted h.sorted, hm.declared h.declared⟩

theorem annotation_fn_result {P ks C Γ ns ps r e} (h : Ty.AnnotationR P ks C Γ (.fn ns ps r e)) :
    Ty.AnnotationR P ks C Γ r := ⟨h.wf.2.2.1, h.sorted.2.1, h.declared.2.1⟩

theorem rangeEff_empty (rs : List RangeExpr) : rangeEff rs Eff.empty = Eff.empty := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    simp only [rangeEff, Eff.instR, Eff.substRAt, Eff.mapRanges, Eff.rawMapRanges, Eff.empty,
      mapRangesTys, Eff.norm]
    congr 1
    funext a
    simp [mapRangeAtoms]

theorem rangeTy_const (rs : List RangeExpr) (c : Const) : rangeTy rs c.type = c.type := by
  cases rs <;> cases c <;> rfl

/-- 相互帰納で用いる、一つの具体化における式の型の保存の結論。 -/
abbrev ExprCore (P : Refinement.Program) (B : Builtins) (op : OpPrim) (Q : NoFailCtx)
    (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (p : Position)
    (e : Expr) (a : Ty) (ε : Eff) (rs : List RangeExpr) : Prop :=
  HasTypeCQ P B StoreTy.empty Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs))
    ((desugarExpr op p e).instR rs) (rangeTy rs a) (rangeEff rs ε) (rangeLocal rs Δ)

/-- 同じ具体化における文列の保存の結論。 -/
abbrev BlockCore (P : Refinement.Program) (B : Builtins) (op : OpPrim) (Q : NoFailCtx)
    (Δ : BuilderCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (p : Position)
    (body : Block) (a : Ty) (ε : Eff) (rs : List RangeExpr) : Prop :=
  HasTypeCQ P B StoreTy.empty Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs))
    ((desugarBlock op p body).instR rs) (rangeTy rs a) (rangeEff rs ε) (rangeLocal rs Δ)

theorem return_const_core {P B op Q Δ C Γ Φ R p e c} (hc : ConstOK B c)
    (he : desugarExpr op p e = .ret (.const c)) (rs : List RangeExpr) :
    ExprCore P B op Q Δ C Γ Φ R p e c.type Eff.empty rs := by
  have hm : (Comp.ret (.const c)).instR rs = .ret (.const c) := by cases rs <;> rfl
  unfold ExprCore
  rw [he, hm, rangeTy_const, rangeEff_empty]
  exact .C_Return (.V_Const hc)

theorem local_core {P B op Q Δ C Γ Φ R p i a} (hi : Γ[i]? = some (some a))
    (ho : Ordinary a) (rs : List RangeExpr) :
    ExprCore P B op Q Δ C Γ Φ R p (.local i) a Eff.empty rs := by
  have hm : (Comp.ret (.var i)).instR rs = .ret (.var i) := by cases rs <;> rfl
  unfold ExprCore
  rw [desugarExpr, hm, rangeEff_empty]
  exact .C_Return (.V_Var (rangeCtx_lookup hi rs) (rangeTy_ordinary ho rs))

end
end Benitoite.Release.Refinement.Surface.OpenSurface
