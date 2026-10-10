import Benitoite.Surface.Typing
import Benitoite.Release.Lemmas.Rename

/-! 値として使う関数とメソッドが捕える辞書の、環境と型の置換。 -/
namespace Benitoite.Surface
open Benitoite.Release

mutual
  /-- 継続を隠しても、局所の辞書は同じ番号に残る。 -/
  theorem DictEv.HasType.hide {D B C Γ d a} (h : DictEv.HasType D B C Γ d a) :
      DictEv.HasType D B C (hideConts Γ) d a := by
    match h with
    | .impl hd ht hs => exact .impl hd ht (DictEv.HasTypes.hide hs)
    | .local hi => exact .local (hideConts_get.mpr ⟨hi, by intro b t ε he; cases he⟩)
    | .super hd hc hs => exact .super (DictEv.HasType.hide hd) hc hs

  theorem DictEv.HasTypes.hide {D B C Γ ds as} (h : DictEv.HasTypes D B C Γ ds as) :
      DictEv.HasTypes D B C (hideConts Γ) ds as := by
    match h with
    | .nil => exact .nil
    | .cons h hs => exact .cons (DictEv.HasType.hide h) (DictEv.HasTypes.hide hs)
end

/-- 宣言の辞書型 Dict[Cl, α] の置換は、エフェクト引数に依存しない。 -/
theorem FunDecl.dictTys_substEff (d : FunDecl) (ts : List Ty) (es : List Eff) :
    d.dictTys.map (Ty.subst ts []) = d.dictTys.map (Ty.subst ts es) := by
  simp only [FunDecl.dictTys, List.map_map]
  apply List.map_congr_left
  intro q _
  simp only [Function.comp_apply, Ty.subst, Ty.substAt]

end Benitoite.Surface
