import Benitoite.Release.Refinement.Typing
import Benitoite.Release.Refinement.TypeSubst
import Benitoite.Release.Refinement.Adequate
import Benitoite.Release.Refinement.SourceScope
import Benitoite.Release.Refinement.VarianceValidation

/-! # At の診断の公開形の値の型付け・閉性・適格性

公開の宣言を持つプログラム（`Program.HasScopePublic`）で、公開の値の木の値が任意の文脈で同じ型を持ち、
閉じた正常値で、どの起点の環境でも適格であることを示す（設計書 07-04「篩を含む形式化の範囲」）。 -/
namespace Benitoite.Release.Refinement.ScopePublic
open Scope.Domain

/-! ## 公開の欄の型 -/

theorem PublicTy.ground (a : PublicTy) : groundTy a.ty = true := by
  induction a with
  | string | integer | bytes => rfl
  | list a ih => simpa [PublicTy.ty, groundTy] using ih
  | option a ih => simpa [PublicTy.ty, groundTy, groundTys] using ih
  | data d => rfl

theorem PublicTy.sorted (Γ : Ctx) (a : PublicTy) : a.ty.Sorted Γ := by
  induction a with
  | string | integer | bytes => trivial
  | list a ih => exact ih
  | option a ih => exact ⟨ih, trivial⟩
  | data d => trivial

theorem PublicTy.norm_ty (a : PublicTy) : a.ty.norm = a.ty := by
  induction a with
  | string | integer | bytes => rfl
  | list a ih => simp [PublicTy.ty, Ty.norm, ih]
  | option a ih => simp [PublicTy.ty, Ty.norm, Ty.normTys, ih]
  | data d => simp [PublicTy.ty, Ty.norm, Ty.normTys]

theorem PublicTy.rawBind_ty (θ : SubstEnv) (a : PublicTy) : a.ty.rawBind θ = a.ty := by
  induction a with
  | string | integer | bytes => rfl
  | list a ih => simp [PublicTy.ty, Ty.rawBind, ih]
  | option a ih => simp [PublicTy.ty, Ty.rawBind, rawBindTys, ih]
  | data d => simp [PublicTy.ty, Ty.rawBind, rawBindTys]

theorem PublicTy.subst_ty (ts : List Ty) (es : List Eff) (a : PublicTy) : a.ty.subst ts es = a.ty := by
  simp [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, PublicTy.rawBind_ty, PublicTy.norm_ty]

theorem PublicTy.ordinary (a : PublicTy) : Ordinary a.ty := by
  intro b t e h
  cases a <;> simp [PublicTy.ty, Ty.core] at h

theorem PublicTy.sourceScoped (nt ne nv : Nat) (a : PublicTy) : a.ty.SourceScoped 0 nt ne nv := by
  refine ⟨groundTy_wf a.ground, ?_, ?_⟩
  · induction a with
    | string | integer | bytes | data _ => simp [PublicTy.ty, Ty.RowsIn, Ty.RowsInList]
    | list a ih => simpa [PublicTy.ty, Ty.RowsIn] using ih
    | option a ih => simpa [PublicTy.ty, Ty.RowsIn, Ty.RowsInList] using ih
  · induction a with
    | string | integer | bytes | data _ => simp [PublicTy.ty, Ty.RangesScoped, rangesScopedTypes]
    | list a ih => simpa [PublicTy.ty, Ty.RangesScoped] using ih
    | option a ih => simpa [PublicTy.ty, Ty.RangesScoped, rangesScopedTypes] using ih

theorem PublicTy.varianceOK (P : Program) (vs : List Variance) :
    ∀ (a : PublicTy) (p : Polarity), a.ty.VarianceOK P vs p
  | .string, _ | .integer, _ | .bytes, _ => trivial
  | .data d, p => by
    show varianceArgsOK P vs p (P.varianceFor d 0) []
    have h := Program.varianceFor_length P d 0
    generalize P.varianceFor d 0 = ws at h
    match ws, h with
    | [], _ => trivial
  | .list a, p => PublicTy.varianceOK P vs a p
  | .option a, p => by
    show varianceArgsOK P vs p (P.varianceFor "Option" 1) [a.ty]
    have h := Program.varianceFor_length P "Option" 1
    generalize P.varianceFor "Option" 1 = ws at h
    match ws, h with
    | [v], _ => exact ⟨PublicTy.varianceOK P vs a _, trivial⟩

private theorem known_data {d : DataName} (h : (PublicTy.data d).Known) : d ∈ all.map PublicData.name :=
  h d (by simp [PublicTy.names])

private theorem data_arity {P : Program} (hp : P.HasScopePublic) {d : DataName}
    (h : d ∈ all.map PublicData.name) : P.DataArity d 0 := by
  obtain ⟨D, hD, rfl⟩ := List.mem_map.mp h
  exact hp.arity D hD

theorem PublicTy.declared {P : Program} (hp : P.HasScopePublic) (C : TypeCtx) (Γ : Ctx) :
    ∀ a : PublicTy, a.Known → a.ty.Declared P C Γ
  | .string, _ | .integer, _ | .bytes, _ => trivial
  | .list a, h => PublicTy.declared hp C Γ a (fun d hd => h d (by simpa [PublicTy.names] using hd))
  | .option a, h => ⟨⟨1, hp.optionArity, rfl⟩,
      PublicTy.declared hp C Γ a (fun d hd => h d (by simpa [PublicTy.names] using hd)), trivial⟩
  | .data d, h => ⟨⟨0, data_arity hp (known_data h), rfl⟩, trivial⟩

theorem PublicTy.kind {P : Program} (hp : P.HasScopePublic) (K : KindCtx) :
    ∀ a : PublicTy, a.Known → a.ty.HasKind P K .value
  | .string, _ | .integer, _ | .bytes, _ => trivial
  | .list a, h => PublicTy.kind hp K a (fun d hd => h d (by simpa [PublicTy.names] using hd))
  | .option a, h => ⟨TyCon.arity_data hp.optionArity,
      PublicTy.kind hp K a (fun d hd => h d (by simpa [PublicTy.names] using hd)), trivial⟩
  | .data d, h => ⟨TyCon.arity_data (data_arity hp (known_data h)), trivial⟩

theorem PublicTy.annotation {P : Program} (hp : P.HasScopePublic) (C : TypeCtx) (Γ : Ctx)
    {a : PublicTy} (h : a.Known) : Ty.Annotation P C Γ a.ty :=
  ⟨groundTy_wf a.ground, a.sorted Γ, a.declared hp C Γ h⟩

/-! ## 宣言の lookup -/

theorem constructor_fields {c : ConName} {d : DataName} {as : List PublicTy}
    (h : (c, d, as) ∈ constructors) : d ∈ all.map PublicData.name ∧ ∀ a ∈ as, a.Known := by
  have shape := fields_declared (c, d, as) h
  simp only [constructors, List.mem_flatMap, List.mem_map] at h
  obtain ⟨D, hD, ⟨c', as'⟩, _, eq⟩ := h
  simp only [Prod.mk.injEq] at eq
  obtain ⟨rfl, rfl, rfl⟩ := eq
  exact ⟨List.mem_map_of_mem hD, fun a ha d hd => shape a ha d hd⟩

/-! ## 型付け -/

section
variable {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred}

mutual
  /-- 型付き木の値は、公開の宣言を持つ任意の文脈で同じ型を持つ。 -/
  theorem PublicTree.Typed.val (hp : P.HasScopePublic) {t : PublicTree} {a : PublicTy}
      (h : t.Typed a) : HasTypeVQ P B Ψ Q C Γ Φ t.toVal a.ty := by
    match h with
    | .text s => exact .V_Const trivial
    | .integer n => exact .V_Const trivial
    | .bytes hb => exact .V_Bytes hb
    | .list ha hs =>
      exact .V_List (PublicTree.TypedEach.vals hp hs) (groundTy_wf (PublicTy.ground _))
        (PublicTy.sorted Γ _) (PublicTy.declared hp C Γ _ ha)
    | .none (a := a) ha =>
      exact .V_Con hp.optionNone rfl (kinded hp ha) (by simp) .nil (option_annotation hp ha)
    | .some (a := a) ha hx =>
      refine .V_Con hp.optionSome rfl (kinded hp ha) ?_ ?_ (option_annotation hp ha)
      · intro t ht; cases List.mem_singleton.mp ht; exact Nat.zero_lt_one
      · simpa [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, PublicTy.norm_ty]
          using HasTypeVsQ.cons (PublicTree.Typed.val hp hx) HasTypeVsQ.nil
    | .con (c := c) (d := d) (as := as) hl hs =>
      have mem := lookup_mem hl
      obtain ⟨hd, _⟩ := constructor_fields mem
      refine .V_Con (ts := []) (hp.cons c d as mem) rfl ⟨rfl, by intro i t k ht; cases i <;> cases ht⟩ ?_ ?_
        ⟨trivial, trivial, ⟨⟨0, data_arity hp hd, rfl⟩, trivial⟩⟩
      · intro t ht
        obtain ⟨a, _, rfl⟩ := List.mem_map.mp ht
        exact groundTy_wf (PublicTy.ground a)
      · simpa [List.map_map, Function.comp_def, PublicTy.subst_ty] using PublicTree.TypedAll.vals hp hs
  theorem PublicTree.TypedAll.vals (hp : P.HasScopePublic) {ts : List PublicTree} {as : List PublicTy}
      (h : PublicTree.TypedAll ts as) : HasTypeVsQ P B Ψ Q C Γ Φ (PublicTree.toVals ts) (as.map PublicTy.ty) := by
    match h with
    | .nil => exact .nil
    | .cons hx hs => exact .cons (PublicTree.Typed.val hp hx) (PublicTree.TypedAll.vals hp hs)
  theorem PublicTree.TypedEach.vals (hp : P.HasScopePublic) {ts : List PublicTree} {a : PublicTy}
      (h : PublicTree.TypedEach ts a) : HasTypeEachQ P B Ψ Q C Γ Φ (PublicTree.toVals ts) a.ty := by
    match h with
    | .nil => exact .nil
    | .cons hx hs => exact .cons (PublicTree.Typed.val hp hx) (PublicTree.TypedEach.vals hp hs)
  private theorem kinded (hp : P.HasScopePublic) {a : PublicTy} (ha : a.Known) :
      TypeArgsKinded P C [a.ty] [.value] := by
    refine ⟨rfl, ?_⟩
    intro i t k ht hk
    cases i with
    | zero =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at ht hk
      subst t; subst k
      exact ⟨PublicTy.kind hp _ a ha, fun _ => PublicTy.ordinary a⟩
    | succ i => simp at ht
  private theorem option_annotation (hp : P.HasScopePublic) {a : PublicTy} (ha : a.Known) :
      Ty.Annotation P C Γ (.data "Option" [a.ty]) :=
    PublicTy.annotation hp C Γ (a := .option a) (fun d hd => ha d (by simpa [PublicTy.names] using hd))
end
end

mutual
  theorem PublicTree.toVal_ground : ∀ t : PublicTree, groundVal t.toVal = true
    | .text _ | .integer _ | .bytes _ => rfl
    | .list _ xs => by simpa [PublicTree.toVal, groundVal] using PublicTree.toVals_ground xs
    | .none a => by simp [PublicTree.toVal, groundVal, groundVals, groundTys, PublicTy.ground]
    | .some a x => by
      simp [PublicTree.toVal, groundVal, groundVals, groundTys, PublicTy.ground,
        PublicTree.toVal_ground x]
    | .con _ xs => by simpa [PublicTree.toVal, groundVal, groundTys] using PublicTree.toVals_ground xs
  theorem PublicTree.toVals_ground : ∀ xs : List PublicTree, groundVals (PublicTree.toVals xs) = true
    | [] => rfl
    | x :: xs => by
      simp [PublicTree.toVals, groundVals, PublicTree.toVal_ground x, PublicTree.toVals_ground xs]
end

mutual
  /-- 公開の値は、どの起点の環境でも適格である。 -/
  theorem PublicTree.toVal_adequate (σ : PathEnv) : ∀ t : PublicTree, t.toVal.Adequate σ
    | .text _ | .integer _ | .bytes _ | .none _ => by simp [PublicTree.toVal, Val.Adequate, adequateVals]
    | .list _ xs => by simpa [PublicTree.toVal, Val.Adequate] using PublicTree.toVals_adequate σ xs
    | .some _ x => by
      simpa [PublicTree.toVal, PublicTree.toVals, Val.Adequate, adequateVals] using PublicTree.toVal_adequate σ x
    | .con _ xs => by simpa [PublicTree.toVal, Val.Adequate] using PublicTree.toVals_adequate σ xs
  theorem PublicTree.toVals_adequate (σ : PathEnv) : ∀ xs : List PublicTree, adequateVals σ (PublicTree.toVals xs)
    | [] => trivial
    | x :: xs => ⟨PublicTree.toVal_adequate σ x, PublicTree.toVals_adequate σ xs⟩
end
end Benitoite.Release.Refinement.ScopePublic
