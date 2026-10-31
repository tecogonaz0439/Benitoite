import Benitoite.Release.Refinement.Typing
import Benitoite.Release.Refinement.ExternalResponse

/-!
# 依存する実引数列の逐次具体化

各paramの後続に実引数をbindし、最終契約と型付き列を同じ結果から取り出す。
-/
namespace Benitoite.Release.Refinement
noncomputable section

theorem HasTypeTelArgsQ.normal {P B store Q C Γ Φ vs t a e}
    (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e) (hn : t.Normal) : a.norm = a ∧ e.norm = e := by
  match h with
  | .done ha => exact Tel.done.inj hn
  | .param _ _ ht => exact ht.normal (Tel.norm_idem _)

theorem HasTypeTelArgsQ.instantiate {P B store Q C Γ Φ vs t a e}
    (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e) (hn : t.Normal) : Tel.instantiate t vs = some (a, e) := by
  match h with
  | .done _ =>
    simp only [Tel.instantiate]
    change some (a.norm, e.norm) = some (a, e)
    rw [(Tel.done.inj hn).1, (Tel.done.inj hn).2]
  | .param _ _ ht =>
    simpa only [Tel.instantiate] using ht.instantiate (Tel.norm_idem _)

theorem HasTypeTelArgsQ.length {P B store Q C Γ Φ vs t a e}
    (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e) : vs.length = t.arity :=
  by
    match h with
    | .done _ => rfl
    | .param _ _ ht =>
      simpa only [Tel.arity, Tel.names, Tel.bind, List.length_cons,
        Tel.names_norm, Tel.names_rawBind] using congrArg Nat.succ ht.length

theorem HasTypeTelArgsQ.arguments {P B store Q C Γ Φ vs t a e}
    (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e) (hn : t.Normal) :
    ∃ as, Tel.arguments t vs = some (as, a, e) ∧ HasTypeVsQ P B store Q C Γ Φ vs as := by
  match h with
  | .done _ =>
    refine ⟨[], ?_, .nil⟩
    simp only [Tel.arguments]
    change some ([], a.norm, e.norm) = some ([], a, e)
    rw [(Tel.done.inj hn).1, (Tel.done.inj hn).2]
  | .param (a := x) ha hv ht =>
    obtain ⟨as, he, hs⟩ := ht.arguments (Tel.norm_idem _)
    refine ⟨x :: as, ?_, .cons hv hs⟩
    simp only [Tel.arguments, he, Option.map_some]
    rw [(Tel.param.inj hn).2.1]

theorem ExternalArgs.instantiate {P B store d ts vs a e}
    (h : ExternalArgs P B store d ts vs a e) : d.instantiate ts vs = some (a, e) := by
  simp only [ExternalSignature.instantiate, h.admissible.count, ↓reduceIte]
  exact h.arguments.instantiate (Tel.norm_idem _)

end
end Benitoite.Release.Refinement
