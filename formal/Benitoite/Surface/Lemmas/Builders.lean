import Benitoite.Surface.Builders
import Benitoite.Surface.Lemmas.CallHead
import Benitoite.Surface.CheckSupport

/-!
# 構築器の環境と参照先の型付け

定義は表層判断から独立させ、ここで既存の宣言の脱糖と値・呼び出しの規則へ接続する。
対応する規則は設計書 01-12「構築器の分類と環境の対応」である。
-/
namespace Benitoite.Surface
open Benitoite.Release

namespace BuilderCtx

theorem clean_values {n Δ} (h : Clean n Δ) (m : Nat) :
    Clean n (List.replicate m none ++ Δ) := all_values h m
theorem atomsIn_values {atoms Δ} (h : AtomsIn atoms Δ) (m : Nat) :
    AtomsIn atoms (List.replicate m none ++ Δ) := all_values h m
theorem single_values {Q Δ} (h : Single Q Δ) (m : Nat) :
    Single Q (List.replicate m none ++ Δ) := all_values h m

/-- 捕捉の境界では、Γ の none を残したまま Δ だけを空にする。 -/
theorem boundary (Γ : List (Option Ty)) (n : Nat) (atoms : List Atom) (Q : NoFailCtx) :
    Aligned Γ [] ∧ Clean n [] ∧ AtomsIn atoms [] ∧ Single Q [] :=
  ⟨aligned_empty Γ, clean_empty n, atomsIn_empty atoms, single_empty Q⟩

/-- hideConts は分類表とその内部の型を変えない。 -/
theorem hideConts {Γ Δ n atoms Q} (ha : Aligned Γ Δ) (hc : Clean n Δ)
    (ht : AtomsIn atoms Δ) (hs : Single Q Δ) :
    Aligned (Release.hideConts Γ) Δ ∧ Clean n Δ ∧ AtomsIn atoms Δ ∧ Single Q Δ :=
  ⟨aligned_hideConts ha, hc, ht, hs⟩

end BuilderCtx

/-- セルも内容の型と同じ clean・支持・単一 Fail の条件を持つ。 -/
theorem BuilderKind.cell_clean {k : BuilderKind} {n} (h : TyOK n k.contents) :
    TyOK n k.cell := h
theorem BuilderKind.cell_atoms {k : BuilderKind} {atoms} (h : Ty.AtomsIn atoms k.contents) :
    Ty.AtomsIn atoms k.cell := h
theorem BuilderKind.cell_single {k : BuilderKind} {Q} (h : SingleTy Q k.contents) :
    SingleTy Q k.cell := h

namespace fillBuilders

theorem clean {Γ Δ n} (hΓ : EnvClean n Γ) (hΔ : BuilderCtx.Clean n Δ) :
    EnvClean n (fillBuilders Γ Δ) := by
  intro i t hi
  rw [lookup] at hi
  obtain ⟨a, ha, ht⟩ := Option.map_eq_some_iff.mp hi
  cases hk : Δ.kindAt i with
  | none => simp only [hk] at ht; rw [ht] at ha; exact hΓ i t ha
  | some k =>
      simp only [hk, Option.some.injEq] at ht
      subst t
      exact Or.inl (BuilderKind.cell_clean (hΔ i k hk))

theorem atomsIn {Γ Δ atoms} (hΓ : Env.AtomsIn atoms Γ) (hΔ : BuilderCtx.AtomsIn atoms Δ) :
    Env.AtomsIn atoms (fillBuilders Γ Δ) := by
  intro t ht
  obtain ⟨i, hi⟩ := List.mem_iff_getElem?.mp ht
  rw [lookup] at hi
  obtain ⟨a, ha, ht⟩ := Option.map_eq_some_iff.mp hi
  cases hk : Δ.kindAt i with
  | none => simp only [hk] at ht; rw [ht] at ha; exact hΓ t (List.mem_of_getElem? ha)
  | some k =>
      simp only [hk, Option.some.injEq] at ht
      subst t
      exact BuilderKind.cell_atoms (hΔ i k hk)

theorem single {Γ Δ Q} (hΓ : ∀ (i : Nat) t, Γ[i]? = some (some t) → SingleTy Q t)
    (hΔ : BuilderCtx.Single Q Δ) :
    ∀ (i : Nat) t, (fillBuilders Γ Δ)[i]? = some (some t) → SingleTy Q t := by
  intro i t hi
  rw [lookup] at hi
  obtain ⟨a, ha, ht⟩ := Option.map_eq_some_iff.mp hi
  cases hk : Δ.kindAt i with
  | none => simp only [hk] at ht; rw [ht] at ha; exact hΓ i t ha
  | some k =>
      simp only [hk, Option.some.injEq] at ht
      subst t
      exact BuilderKind.cell_single (hΔ i k hk)

theorem cell_typed {P B Ψ Q C Γ Δ i k} (ha : BuilderCtx.Aligned Γ Δ)
    (hi : Δ.kindAt i = some k) :
    HasTypeVQ P B Ψ Q C (fillBuilders Γ Δ) (.var i) k.cell :=
  .V_Var (cell_lookup ha hi) (by intro b t e he; cases he)

end fillBuilders

/-- 束縛の接頭部を保った恒等対応。空Δの境界本体をセル環境へ移す。 -/
theorem RenOk.up_id {Γ Γc} (xs : List (Option Ty)) (h : RenOk Γ Γc id) :
    RenOk (xs ++ Γ) (xs ++ Γc) id := by
  simpa only [upRen_id] using h.up xs

/-- パターンの型列は逆順に束縛するが、分類表へ積む none の個数は同じである。 -/
theorem BuilderCtx.aligned_binds {Γ Δ} (h : BuilderCtx.Aligned Γ Δ) (ts : List Ty) :
    BuilderCtx.Aligned (binds ts ++ Γ) (List.replicate ts.length none ++ Δ) := by
  simpa only [binds_length] using BuilderCtx.aligned_values h (binds ts)

/-- パターン束縛の前後でも、通常値とセルの番号は一致する。 -/
theorem fillBuilders.under_binds (Γ : List (Option Ty)) (Δ : BuilderCtx) (ts : List Ty) :
    fillBuilders (binds ts ++ Γ) (List.replicate ts.length none ++ Δ) = binds ts ++ fillBuilders Γ Δ := by
  simpa only [binds_length] using fillBuilders.under_values Γ Δ (binds ts)

/-- 番号を変えず、空Δの境界の導出や辞書をセル環境へ移す。 -/
theorem HasTypeCQ.renameId {P B Ψ Q C Γ Γc R m a ε}
    (hΓ : RenOk Γ Γc id) (h : HasTypeCQ P B Ψ Q C Γ R m a ε) :
    HasTypeCQ P B Ψ Q C Γc R m a ε := by
  simpa only [Comp.rename_id] using h.rename hΓ

/-- 穴の固定引数の計算列を、穴の束縛の下で恒等対応に沿って移す。 -/
theorem CompTypesQ.renameId {P B Q C Γ Γc R ms as ε}
    (h : CompTypesQ P B Q C Γ R ε ms as) (hΓ : RenOk Γ Γc id) :
    CompTypesQ P B Q C Γc R ε ms as := by
  induction h with
  | nil => exact .nil
  | cons h _ ih => exact .cons (HasTypeCQ.renameId hΓ h) ih

variable {view : CoverageView}
variable {p : Program} {op : OpPrim} {B : Builtins} {C : List TParam} {Q : NoFailCtx}

theorem BuilderPrimRef.Ok.surfaceTyped {Δb : BuilderCtx} {D r kind names ps ret eff Γ R pos}
    (h : BuilderPrimRef.Ok B C Q r kind names ps ret eff) :
    HasTypeQ D B op Q Δb C Γ R pos (.primName r.name r.types [])
      (.fn names ps ret eff) Eff.empty := by
  obtain ⟨s, h⟩ := h
  rw [← h.shape]
  exact .E_Prim h.declared h.namesWF h.typeCount h.noRows.symm h.admits
    (h.admissible Q) h.single

theorem BuilderPureRef.Ok.surfaceTyped {Δb : BuilderCtx} {D r names ps ret Γ R pos}
    (h : BuilderPureRef.Ok D B C Q r names ps ret) :
    HasTypeQ D B op Q Δb C Γ R pos
      (match r with | .prim r => .primName r.name r.types [] | .funRef f ts => .funName f ts [])
      (.fn names ps ret Eff.empty) Eff.empty := by
  cases r with
  | prim r => exact BuilderPrimRef.Ok.surfaceTyped h
  | funRef f ts =>
      obtain ⟨d, h⟩ := h
      have hdict : d.dictTys = [] := by simp [FunDecl.dictTys, h.noDicts]
      have hnames : d.coreNames = d.names := by simp [FunDecl.coreNames, h.noDicts, internalNames]
      rw [← h.shape]
      exact .E_Fun h.declared h.namesWF
        (by simpa only [hdict, hnames, List.nil_append] using h.namesWF)
        h.sat h.noRows.symm h.noDicts
        (by simpa only [hdict, List.nil_append] using h.admissible Q) h.single

theorem BuilderPrimRef.Ok.typed {r kind names ps ret eff Γ Ψ}
    (h : BuilderPrimRef.Ok B C Q r kind names ps ret eff) :
    HasTypeVQ (desugarProgram op p) B Ψ Q C Γ r.toVal (.fn names ps ret eff) := by
  obtain ⟨s, h⟩ := h
  rw [← h.shape]
  exact .V_Prim h.declared h.namesWF (h.admissible Q)

theorem BuilderPureRef.Ok.typed {r names ps ret Γ Ψ}
    (h : BuilderPureRef.Ok (p.declarationsFor view) B C Q r names ps ret) :
    HasTypeVQ (desugarProgram op p) B Ψ Q C Γ r.toVal (.fn names ps ret Eff.empty) := by
  cases r with
  | prim r => exact BuilderPrimRef.Ok.typed h
  | funRef f ts =>
      obtain ⟨d, h⟩ := h
      obtain ⟨dd, hd, ht, he, hn, hp, hr, hε⟩ := funDecl_desugared (op := op) h.declared
      have ha := h.admissible Q
      rw [← h.shape]
      have hdict : d.dictTys = [] := by simp [FunDecl.dictTys, h.noDicts]
      have hnames : d.coreNames = d.names := by simp [FunDecl.coreNames, h.noDicts, internalNames]
      simpa only [BuilderPureRef.toVal, ht, he, hn, hp, hr, hε, hdict, hnames,
        List.nil_append] using HasTypeVQ.V_Fun (Ψ := Ψ) (Γ := Γ) hd
          (by simpa only [hn, hp, hdict, hnames, List.nil_append] using h.namesWF)
          (by simpa only [ht, he, hp, hr, hε, hdict, List.nil_append] using ha)

theorem BuilderPrimRef.Ok.apply {r kind names ps ret eff Γ Ψ R vs}
    (h : BuilderPrimRef.Ok B C Q r kind names ps ret eff)
    (hv : HasTypeVsQ (desugarProgram op p) B Ψ Q C Γ vs ps) :
    HasTypeCQ (desugarProgram op p) B Ψ Q C Γ R (.app r.toVal vs) ret eff :=
  .C_App h.typed hv

theorem BuilderPureRef.Ok.apply {r names ps ret Γ Ψ R vs}
    (h : BuilderPureRef.Ok (p.declarationsFor view) B C Q r names ps ret)
    (hv : HasTypeVsQ (desugarProgram op p) B Ψ Q C Γ vs ps) :
    HasTypeCQ (desugarProgram op p) B Ψ Q C Γ R (.app r.toVal vs) ret Eff.empty :=
  .C_App h.typed hv

/-- 既存のコア規則によるセルの三参照の型付け。 -/
def BuilderCellRefs.Typed (P : Release.Program) (B : Builtins) (C : List TParam)
    (Q : NoFailCtx) (Γ : List (Option Ty)) (Ψ : StoreTy) (k : BuilderKind) (r : BuilderCellRefs) : Prop :=
  HasTypeVQ P B Ψ Q C Γ r.newRef.toVal (.fn ["value"] [k.contents] k.cell (Eff.single stateEff)) ∧
  HasTypeVQ P B Ψ Q C Γ r.getRef.toVal (.fn ["reference"] [k.cell] k.contents (Eff.single stateEff)) ∧
  HasTypeVQ P B Ψ Q C Γ r.setRef.toVal (.fn ["reference", "value"] [k.cell, k.contents] (.base .unit) (Eff.single stateEff))

theorem BuilderCellRefs.Ok.typed {k r Γ Ψ} (h : BuilderCellRefs.Ok B C Q k r) :
    r.Typed (desugarProgram op p) B C Q Γ Ψ k :=
  ⟨h.2.2.2.1.typed, h.2.2.2.2.1.typed, h.2.2.2.2.2.typed⟩

/-- 純粋な参照の各役割を同じ型付け境界へ渡す。 -/
def BuilderRefs.PureTyped (P : Release.Program) (B : Builtins) (C : List TParam)
    (Q : NoFailCtx) (Γ : List (Option Ty)) (Ψ : StoreTy) : BuilderRefs → Prop
  | .string _ add join len =>
      HasTypeVQ P B Ψ Q C Γ add.toVal (.fn ["left", "right"] [.base .string, .base .string] (.base .string) Eff.empty) ∧
      HasTypeVQ P B Ψ Q C Γ join.toVal (.fn ["xs", "separator"] [.list (.base .string), .base .string] (.base .string) Eff.empty) ∧
      HasTypeVQ P B Ψ Q C Γ len.toVal (.fn ["s"] [.base .string] (.base .integer) Eff.empty)
  | .list t _ append cat len =>
      HasTypeVQ P B Ψ Q C Γ append.toVal (.fn ["xs", "x"] [.list t, t] (.list t) Eff.empty) ∧
      HasTypeVQ P B Ψ Q C Γ cat.toVal (.fn ["xs", "ys"] [.list t, .list t] (.list t) Eff.empty) ∧
      HasTypeVQ P B Ψ Q C Γ len.toVal (.fn ["xs"] [.list t] (.base .integer) Eff.empty)
  | .bytes _ empty fromList cat len =>
      HasTypeVQ P B Ψ Q C Γ empty.toVal (.fn [] [] .bytes Eff.empty) ∧
      HasTypeVQ P B Ψ Q C Γ fromList.toVal (.fn ["bs"] [.list (.base .byte)] .bytes Eff.empty) ∧
      HasTypeVQ P B Ψ Q C Γ cat.toVal (.fn ["a", "b"] [.bytes, .bytes] .bytes Eff.empty) ∧
      HasTypeVQ P B Ψ Q C Γ len.toVal (.fn ["b"] [.bytes] (.base .integer) Eff.empty)

theorem BuilderRefs.PureOk.typed {r Γ Ψ} (h : BuilderRefs.PureOk (p.declarationsFor view) B C Q r) :
    r.PureTyped (desugarProgram op p) B C Q Γ Ψ := by
  cases r with
  | string _ _ _ _ => exact ⟨h.1.typed, h.2.1.typed, h.2.2.typed⟩
  | list _ _ _ _ _ => exact ⟨h.1.typed, h.2.1.typed, h.2.2.typed⟩
  | bytes _ _ _ _ _ => exact ⟨h.1.typed, h.2.1.typed, h.2.2.1.typed, h.2.2.2.typed⟩

theorem builderRefs_typed {r Γ Δ i Ψ} (h : BuilderRefs.Ok (p.declarationsFor view) B C Q Δ i r) :
    r.cells.Typed (desugarProgram op p) B C Q Γ Ψ r.kind ∧
      r.PureTyped (desugarProgram op p) B C Q Γ Ψ :=
  ⟨h.2.1.typed, h.2.2.typed⟩

end Benitoite.Surface
