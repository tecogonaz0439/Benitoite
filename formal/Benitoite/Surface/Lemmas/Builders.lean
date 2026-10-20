import Benitoite.Surface.Builders
import Benitoite.Surface.Lemmas.CallHead
import Benitoite.Surface.CheckSupport

/-!
# 構築器の環境と共有番号の型付け

表層とコアの分類表を同じ番号で対応させ、通常束縛と空の捕捉境界へ接続する。
対応する規則は設計書 01-12「構築器の分類と環境の対応」である。
-/
namespace Benitoite.Surface
open Benitoite.Release

namespace BuilderCtx

@[simp] theorem toLocal_values (n : Nat) (Δ : BuilderCtx) :
    toLocal (List.replicate n none ++ Δ) = LocalCtx.extend n Δ.toLocal := by
  induction n with
  | zero => simp
  | succ n ih => simp only [List.replicate_succ, List.cons_append, toLocal_value, ih,
      LocalCtx.extend_add, Nat.add_comm 1 n]

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

/-- 束縛の接頭部を保った恒等対応。空Δの境界本体の通常環境を保つ。 -/
theorem RenOk.up_id {Γ Γc} (xs : List (Option Ty)) (h : RenOk Γ Γc id) :
    RenOk (xs ++ Γ) (xs ++ Γc) id := by
  simpa only [upRen_id] using h.up xs

/-- パターンの型列は逆順に束縛するが、分類表へ積む none の個数は同じである。 -/
theorem BuilderCtx.aligned_binds {Γ Δ} (h : BuilderCtx.Aligned Γ Δ) (ts : List Ty) :
    BuilderCtx.Aligned (binds ts ++ Γ) (List.replicate ts.length none ++ Δ) := by
  simpa only [binds_length] using BuilderCtx.aligned_values h (binds ts)

/-- 番号を変えず、空Δの境界の導出の通常環境を対応させる。 -/
theorem HasTypeCQ.renameId {P B Ψ Q C Γ Γc R m a ε}
    (hΓ : RenOk Γ Γc id) (h : HasTypeCQ P B Ψ Q C Γ R m a ε) :
    HasTypeCQ P B Ψ Q C Γc R m a ε := by
  simpa only [Comp.rename_id] using h.rename hΓ

/-- 穴の固定引数の計算列を、穴の束縛の下で恒等対応に沿って移す。 -/
theorem CompTypesQ.renameId {P B Q C Γ Γc R ms as ε Δl}
    (h : CompTypesQ P B Q C Γ R ε ms as Δl) (hΓ : RenOk Γ Γc id) :
    CompTypesQ P B Q C Γc R ε ms as Δl := by
  induction h with
  | nil => exact .nil
  | cons h _ ih => exact .cons (by simpa only [Comp.rename_id] using h.rename hΓ _ (fun _ _ hi => hi)) ih

/-- 通常の環境の恒等対応は、直接値と固定式の両方で保持する。 -/
theorem ArgTypesQ.renameId {P B Q C Γ Γc R plans ts ε Δl}
    (h : ArgTypesQ P B Q C Γ R ε Δl plans ts) (hΓ : RenOk Γ Γc id) :
    ArgTypesQ P B Q C Γc R ε Δl plans ts := by
  induction h with
  | nil => exact .nil
  | direct hv _ ih => exact .direct (by simpa only [Val.rename_id] using hv.rename hΓ) ih
  | evaluate hm _ ih => exact .evaluate (by simpa only [Comp.rename_id] using hm.rename hΓ _ (fun _ _ hi => hi)) ih

end Benitoite.Surface
