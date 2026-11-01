import Benitoite
namespace Benitoite.Release.Refinement

/-- 候補を広げるだけの場合、単一原子の像の条件は行の像から導ける。 -/
theorem typeEnvAt_atom {q : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (he : ∀ e ∈ es, e.Support q) (a : Atom) (ha : q a) :
    (Eff.rawBind (typeEnvAt c ts es) (.mk (fun b => decide (b = a)) [])).Support q := by
  have hrows : ∀ f ∈ (typeEnvAt c ts es).rows, f.Support q := by
    intro f hf
    obtain ⟨g, hg, rfl⟩ := List.mem_map.mp hf
    exact Eff.rawShift_support c 0 g (he g hg)
  rw [Eff.support_iff]
  constructor
  · intro x hx
    rcases (Eff.mem_rawBind _ _ x).mp hx with ⟨b, hb, hi, _⟩ | ⟨i, f, hf, _, hm⟩
    · have hba : b = a := of_decide_eq_true hb
      subst hba
      have : b.instR (typeEnvAt c ts es).ranges = b := by
        rcases b with ⟨l, r | i⟩ | i <;> simp [typeEnvAt, Atom.instR, RangeIx.inst]
      rw [this] at hi
      exact hi ▸ ha
    · exact ((Eff.support_iff f).mp (hrows f (List.mem_of_getElem? hf))).1 x hm
  · apply Ty.SupportList.iff.mpr
    intro t hm
    rcases List.mem_append.mp hm with hm | hm
    · cases hm
    · obtain ⟨i, f, hf, _, hm⟩ := Eff.mem_rowFails.mp hm
      exact Ty.SupportList.iff.mp ((Eff.support_iff f).mp (hrows f (List.mem_of_getElem? hf))).2 t hm

/-- 旧 `Ty.substAt_support` と同じ形（同じ支持）。 -/
theorem Ty.substAt_support_same {p : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff) (a : Ty)
    (h : a.Support p) (ht : ∀ t ∈ ts, t.Support p) (he : ∀ e ∈ es, e.Support p) :
    (a.substAt c ts es).Support p :=
  Ty.substAt_support p p c ts es a h ht he (fun x hx => typeEnvAt_atom c ts es he x hx)
#print axioms Ty.substAt_support_same
end Benitoite.Release.Refinement
