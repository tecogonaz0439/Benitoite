import Lean
import Benitoite.Release.Refinement.ModelHttp
import Benitoite.Release.Refinement.AtSound
namespace Benitoite.Release.Refinement
open Scope.Domain

theorem checkAt_absolute {snapshot kind pat t0 bound t}
    (h : checkAt snapshot kind pat (.absolute t0) bound = .ok t) : t = t0 := by
  unfold checkAt at h
  have hr : resolveTargetSnapshot snapshot (.absolute t0) = some t0 := by cases snapshot <;> rfl
  rw [hr] at h
  split at h <;> try cases h
  all_goals (split at h <;> try cases h)
  all_goals (split at h <;> try cases h)
  all_goals (split at h <;> try cases h)
  all_goals (split at h <;> try cases h)
  all_goals (simp_all)
  all_goals (try (cases h; rfl))

/-- 実際の E_AtOk の結果に、葉の証拠を組み立てられること（準備の結果の取り出しは入力）。 -/
theorem at_ok_witness {P B Ψ name kind T v t0 snapshot pat bound t}
    (hk : B.valKind name = some kind) (hc : B.valContent name = some T)
    (hi : HasTypeV P B Ψ [] [] [] v T.norm) (hg : groundVal v = true)
    (hr : v.reqTarget = some t0)
    (hend : t0.kind = .endpoint)
    (hv : ∀ σ, snapshot = some σ → σ.Valid)
    (ha : checkAt snapshot kind pat (.absolute t0) bound = .ok t) :
    CheckedWitness P B Ψ name kind bound snapshot t (AtRequest B name v) := by
  have he := checkAt_absolute ha; subst he
  have hs := (checkAt.sound hv ha).2
  have hkk : t.kind = kind := hs.kind
  have : kind = .endpoint := hkk.symm.trans hend
  subst this
  simp only [AtRequest, hc]
  exact .request hk hc hi hg hr hs

-- List の要素の空でない事実（ValueFacts の部品の合成）
theorem list_element_facts {P B Ψ Q C Γ Φ T vs b v t}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.list vs) T) (hb : T.listCore = some b) (hv : v ∈ vs)
    (ht : v.toTerm? = some t) : ∀ p ∈ b.assume, Entails (Γ.facts ++ Φ) (p.open t) := by
  obtain ⟨⟨a,b',hs,hb',hl⟩,_⟩ := h.list_facts rfl
  have : b' = b := Option.some.inj (hb'.symm.trans hb)
  subst this
  exact (hs.member hv).subtype_facts hl ht

-- data の欄を型の側の引数で読む
theorem field_facts_by_type {P B Ψ Q C Γ Φ T c ts vs cd us} {i : Nat} {a : Ty} {t : Term}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.con c ts vs) T) (hc : P.cons c = some cd)
    (hT : T.norm.core = .data cd.data us) (ha : cd.args[i]? = some a)
    (hs : (Val.toTermSlots vs)[i]? = some (some t)) :
    ∀ p ∈ (a.subst us []).assume, Entails (Γ.facts ++ Φ) (p.open t) := by
  obtain ⟨cd',hc',_,_,ht⟩ := h.inv_con rfl
  have : cd' = cd := Option.some.inj (hc'.symm.trans hc); subst this
  have : us = Ty.normTys ts := by rw [hT] at ht; cases ht; rfl
  subst this
  rw [Ty.subst_norm_images]
  exact h.field_facts hc ha hs

-- 値の所属が最終の添字へ届くこと（Covers から）

end Benitoite.Release.Refinement
