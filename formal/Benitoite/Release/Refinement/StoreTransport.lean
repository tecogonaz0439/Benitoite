import Benitoite.Release.Refinement.Admissible

/-!
# ストア型の移送

捕捉では builder だけを隠し、通常の場所を保つ。
-/
namespace Benitoite.Release.Refinement

def LocTy.WF : LocTy → Prop
  | .builder .string | .builder .bytes => True
  | .builder (.list a) | .ref a | .lazy a => a.WF 0 0 0
  | .cont b t e r => b.WF 0 0 0 ∧ t.WF 0 0 0 ∧ Eff.WF 0 0 0 e ∧ e.Canonical ∧
      ∀ a, r = some a → a.WF 0 0 0

def StoreTy.WF (Ψ : StoreTy) : Prop := ∀ l t, Ψ l = some t → t.WF

def LocTy.Normal : LocTy → Prop
  | .builder _ => False
  | _ => True

def StoreTy.PreservesNormals (Ψ Ψ' : StoreTy) : Prop :=
  ∀ l t, Ψ l = some t → t.Normal → Ψ' l = some t

def StoreTy.Extends (Ψ Ψ' : StoreTy) : Prop :=
  ∀ l t, Ψ l = some t → Ψ' l = some t

theorem StoreTy.PreservesNormals.refl (Ψ : StoreTy) : Ψ.PreservesNormals Ψ :=
  fun _ _ h _ => h

theorem StoreTy.Extends.refl (Ψ : StoreTy) : Ψ.Extends Ψ := fun _ _ h => h

theorem StoreTy.Extends.preservesNormals {Ψ Ψ' : StoreTy} (h : Ψ.Extends Ψ') : Ψ.PreservesNormals Ψ' :=
  fun l t ht _ => h l t ht

theorem StoreTy.PreservesNormals.trans {Ψ Ψ' Ψ'' : StoreTy} (h : Ψ.PreservesNormals Ψ')
    (g : Ψ'.PreservesNormals Ψ'') : Ψ.PreservesNormals Ψ'' :=
  fun l t ht hn => g l t (h l t ht hn) hn

def StoreTy.empty : StoreTy := fun _ => none

theorem StoreTy.WF.empty : StoreTy.WF StoreTy.empty := by
  intro l t h; cases h

theorem StoreTy.Extends.empty (Ψ : StoreTy) : StoreTy.Extends StoreTy.empty Ψ := by
  intro l t h; cases h

end Benitoite.Release.Refinement
