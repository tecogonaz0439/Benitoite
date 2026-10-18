import Benitoite.Surface.CheckInduction

/-! 関数値の検査にも必要な辞書と辞書引数の健全性。
対応する検査と保証の範囲は設計書 07-04「証明する性質」に従う。 -/
namespace Benitoite.Surface.Check
open Benitoite.Release Benitoite.Surface.CheckTools

mutual
  theorem dict_sound (q : Input) (d : DictEv) : DictSound q d := by
    intro C Γ path a hq hd hΓ h
    cases d with
    | «local» j =>
        have h := guardResult_ok h
        obtain ⟨t, ht, h⟩ := bind_ok h
        obtain ⟨⟨cl, τ⟩, hv, h⟩ := bind_ok h
        have eqt := dictView_ok hv
        have eqa : t = a := Except.ok.inj h
        subst a; subst t
        exact ⟨.local (lookup_local_ok ht), Env.atoms_get hΓ (lookup_local_ok ht)⟩
    | clause scope i depth =>
        have h := guardResult_ok h
        obtain ⟨u, hu, h⟩ := bind_ok h
        obtain ⟨t, ht, h⟩ := bind_ok h
        obtain ⟨⟨cl, τ⟩, hv, h⟩ := bind_ok h
        have eqt := dictView_ok hv
        have eqa : t = a := Except.ok.inj h
        subst a; subst t
        have hs := Bool.and_eq_true_iff.mp (require_ok hu).1
        exact ⟨.clause (of_decide_eq_true hs.1) (of_decide_eq_true hs.2)
          (lookup_local_ok ht), Env.atoms_get hΓ (lookup_local_ok ht)⟩
    | impl i ts ds =>
        have h := guardResult_ok h
        obtain ⟨id, hi, h⟩ := bind_ok h
        obtain ⟨u, hu, h⟩ := bind_ok h
        obtain ⟨v, hv, h⟩ := bind_ok h
        have eq : Ty.dict id.cls (substTy q.atoms ts [] id.target) = a := Except.ok.inj h
        subst a
        have hi := lookup_ok hi
        have hiAtoms := hq.declarations.2.2.2.2 i id hi
        have hs := substParams_atoms (es := []) hd.1 (by simp) hiAtoms.2
        have hh := dicts_sound q ds C Γ (child path 0) 0 _ hq hd.2 hΓ hs (by cases v; exact hv)
        refine ⟨?_, substTy_atoms hiAtoms.1 hd.1 (by simp)⟩
        simpa only [substTy_eq ts [] id.target (tysAtoms_iff.mp hd.1) (by simp) hiAtoms.1] using
          (DictEv.HasType.impl hi (satAll_sound hq.sat (require_ok hu).1)
            (by simpa only [substParams_eq ts [] id.dictTys (tysAtoms_iff.mp hd.1) (by simp) (tysAtoms_iff.mp hiAtoms.2)] using hh))
    | super d sup =>
        have h := guardResult_ok h
        obtain ⟨t, ht, h⟩ := bind_ok h
        obtain ⟨⟨cl, τ⟩, hv, h⟩ := bind_ok h
        obtain ⟨cd, hc, h⟩ := bind_ok h
        obtain ⟨u, hu, h⟩ := bind_ok h
        have eq : Ty.dict sup τ = a := Except.ok.inj h
        subst a
        have hh := dict_sound q d C Γ (child path 0) t hq hd hΓ ht
        have eqt := dictView_ok hv
        subst t
        exact ⟨.super hh.1 (lookup_ok hc) (List.mem_of_elem_eq_true (require_ok hu).1), hh.2⟩
  termination_by sizeOf d

  theorem dicts_sound (q : Input) (ds : List DictEv) : DictsSound q ds := by
    intro C Γ path index ts hq hd hΓ hts h
    cases ds with
    | nil =>
        cases ts with
        | nil => exact .nil
        | cons a as => contradiction
    | cons d ds =>
        cases ts with
        | nil => contradiction
        | cons a as =>
            obtain ⟨t, ht, h⟩ := bind_ok h
            obtain ⟨u, hu, h⟩ := bind_ok h
            have hh := dict_sound q d C Γ (child path index) t hq hd.1 hΓ ht
            have eq := tyEq_sound hh.2 hts.1 (require_ok hu).1
            rw [eq] at hh
            exact .cons hh.1 (dicts_sound q ds C Γ path (index + 1) as hq hd.2 hΓ hts.2 h)
  termination_by sizeOf ds
end

/-- 式の場合別の証明から独立に使用できる辞書の契約。 -/
theorem dictionarySoundness (q : Input) : DictionarySoundness q :=
  ⟨dict_sound q, dicts_sound q⟩

end Benitoite.Surface.Check
