import Benitoite.Surface.CheckTables
import Benitoite.Surface.CheckSound

/-! 有限の表の判定を宣言的な契約に接続する。実行ファイルはこのモジュールを読まない。
対応する検査と保証の範囲は設計書 07-04「証明する性質」に従う。 -/
namespace Benitoite.Surface.CheckTables
open Benitoite.Release Benitoite.Surface Benitoite.Surface.CheckTools

theorem sat_sound (S xs b) : SatDecSound (builtins S xs b) (satB S) := by
  intro C t p h; exact h

theorem admits_sound (S raw b) :
    AdmitsDecSound (builtins S (primEntries S raw) b) (admitsDec S (primEntries S raw)) := by
  intro name C ts sg hsig had
  unfold builtins at hsig
  simp only at hsig
  unfold admitsDec at had
  cases hf : primLookup (primEntries S raw) name with
  | none => simp [hf] at hsig
  | some entry =>
    simp only [hf, Option.map_some, Option.some.injEq] at hsig
    simp only [hf] at had
    have hm := List.mem_of_find?_eq_some hf
    obtain ⟨⟨n,m⟩, _, he⟩ := List.mem_map.mp hm
    subst entry
    subst sg
    exact had

/-- 選択の結果によらず、型引数は演算子の規則に一致する。 -/
theorem opPrim_sound (select) : OpPrimTypeArgs (makeOpPrim select) := by
  intro op ty b ts h
  unfold makeOpPrim at h
  cases hs : select op ty with
  | none => simp [hs] at h
  | some name =>
    simp only [hs, Option.map_some, Option.some.injEq, Prod.mk.injEq] at h
    exact h.2.symm

theorem constructors_sound {m : Materials} (h : constructorsOk m = true) :
    CtorsComplete m.declarations.patternProgram (dataConstructors m.data) := by
  intro c cd hc
  have hall := (Bool.and_eq_true_iff.mp h).2
  change constructorDecl m.data c = some cd at hc
  have hm : (c,cd) ∈ m.data.flatMap (·.ctors) := lookup_mem hc
  exact List.mem_of_elem_eq_true ((List.all_eq_true.mp hall) (c,cd) hm)

/-- 有限の宣言材料で検査した完全性は、本体の view の選択によらない。 -/
theorem constructors_withView_sound {m : Materials} (view : CoverageView)
    (h : constructorsOk m = true) :
    CtorsComplete (m.declarations.withView view).patternProgram (dataConstructors m.data) := by
  simpa only [Declarations.withView_patternProgram] using constructors_sound h

theorem record_sound {atoms ds name cd actual}
    (ha : Tys.AtomsIn atoms actual.args) (hc : Tys.AtomsIn atoms cd.args)
    (hget : constructorDecl ds name = some actual)
    (h : recordOk atoms ds name cd = true) :
    actual = cd := by
  simp only [recordOk, hget] at h
  have ⟨hp, hs⟩ := Bool.and_eq_true_iff.mp h
  have ⟨hd, hn⟩ := Bool.and_eq_true_iff.mp hp
  have hd' := beq_iff_eq.mp hd
  have hn' := beq_iff_eq.mp hn
  have hs' := tysEq_sound ha hc hs
  cases actual; cases cd
  simp_all

theorem implNames_sound {m : Materials} {B sat admits op atoms}
    {methods supers : List String} (h : implNamesOk m methods supers = true)
    {name id} (hi : lookup (m.impls.map fun (n,i) => (n,i.input)) name = some id) :
    Check.ImplNamesComplete (m.input B sat admits op atoms) id methods supers := by
  have ⟨hm, hs⟩ := Bool.and_eq_true_iff.mp h
  have ⟨hc, hi'⟩ := Bool.and_eq_true_iff.mp hm
  have im := lookup_mem hi
  obtain ⟨⟨n,i⟩, him, he⟩ := List.mem_map.mp im
  simp only [Prod.mk.injEq] at he
  obtain ⟨rfl, rfl⟩ := he
  constructor
  · intro cd hcd method hout
    have cm := lookup_mem hcd
    obtain ⟨⟨cn,c⟩, hcm, hec⟩ := List.mem_map.mp cm
    simp only [Prod.mk.injEq] at hec
    obtain ⟨rfl, rfl⟩ := hec
    apply lookup_none
    intro hin
    have hall := List.all_eq_true.mp hc method
      (List.mem_flatMap.mpr ⟨(i.signature.cls,c), hcm, hin⟩)
    exact hout (List.mem_of_elem_eq_true hall)
  · constructor
    · intro method hout
      apply lookup_none
      intro hin
      exact hout (List.mem_of_elem_eq_true (List.all_eq_true.mp hi' method
        (List.mem_flatMap.mpr ⟨(n,i), him, hin⟩)))
    · intro super hout
      apply lookup_none
      intro hin
      exact hout (List.mem_of_elem_eq_true (List.all_eq_true.mp hs super
        (List.mem_flatMap.mpr ⟨(n,i), him, hin⟩)))

/-- 橋は原子集合を証明しない。変換した宣言と注釈の契約を明示して受け取る。 -/
theorem input_sound {m : Materials} {S raw b select atoms}
    (hd : m.declarations.AtomsIn atoms)
    (hb : (builtins S (primEntries S raw) b).AtomsIn atoms)
    (hc : constructorsOk m = true) :
    (m.input (builtins S (primEntries S raw) b) (satB S)
      (admitsDec S (primEntries S raw))
      (makeOpPrim select) atoms).Sound :=
  ⟨hd, hb, sat_sound _ _ _, admits_sound _ _ _, opPrim_sound _, constructors_withView_sound m.declarations.view hc,
    fun _ _ h => by simp [Materials.input] at h⟩
end Benitoite.Surface.CheckTables
