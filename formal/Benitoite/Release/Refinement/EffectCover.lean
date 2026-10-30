import Benitoite.Release.Refinement.Bind
import Benitoite.Release.RangeInst

/-!
# 同時置換による一原子の被覆の保存

各原子に一つの証人を残す。行の像から来る原子と Fail は、像を再置換しない。
-/
namespace Benitoite.Release.Refinement

@[simp] theorem Eff.mem_norm (e : Eff) (a : Atom) : e.norm.mem a ↔ e.mem a := by
  cases e; rfl

theorem Eff.Covers.refl (Γ : Ctx) (Φ : List Pred) (e : Eff) : Covers Γ Φ e e :=
  ⟨fun a ha => ⟨a, ha, Atom.Covers.refl a⟩, fun _ => id⟩

theorem Eff.Covers.trans {Γ Φ e f g} (h : Covers Γ Φ e f) (h' : Covers Γ Φ f g) :
    Covers Γ Φ e g := by
  refine ⟨?_, fun t ht => h.2 t (h'.2 t ht)⟩
  intro a ha
  obtain ⟨b, hb, hba⟩ := h'.1 a ha
  obtain ⟨c, hc, hcb⟩ := h.1 b hb
  exact ⟨c, hc, hcb.trans hba⟩

theorem Eff.Sub.covers {Γ Φ e f} (h : Sub e f) : Covers Γ Φ f e :=
  ⟨fun a ha => ⟨a, h.1 a ha, Atom.Covers.refl a⟩, h.2⟩

theorem Eff.covers_norm_left {Γ Φ e f} : Covers Γ Φ e.norm f ↔ Covers Γ Φ e f := by
  simp only [Covers, mem_norm, norm_memFail]

theorem Eff.covers_norm_right {Γ Φ e f} : Covers Γ Φ e f.norm ↔ Covers Γ Φ e f := by
  simp only [Covers, mem_norm, norm_memFail]

/-- 元の原子の範囲だけを具体化してから、行の像を挿入する。 -/
theorem Eff.mem_rawBind (θ : SubstEnv) (e : Eff) (a : Atom) :
    (Eff.rawBind θ e).mem a ↔
      (∃ b, e.mem b ∧ b.instR θ.ranges = a ∧
        match b with | .name _ _ => True | .rho i => θ.rows.length ≤ i) ∨
      ∃ i f, θ.rows[i]? = some f ∧ e.mem (.rho i) ∧ f.mem a := by
  cases e with
  | mk atoms fs =>
    change substAtoms θ.rows (instAtoms θ.ranges atoms) a = true ↔ _
    have hm := Eff.mem_substAtoms θ.rows (.mk (instAtoms θ.ranges atoms) []) a
    simp only [Eff.atoms] at hm
    rw [hm]
    apply or_congr _ Iff.rfl
    cases a with
    | name l ix =>
      change instAtoms θ.ranges atoms (.name l ix) = true ↔ _
      rw [instAtoms_spec]
      constructor
      · rintro ⟨b, hb, he⟩
        refine ⟨b, hb, he, ?_⟩
        cases b with
        | name _ _ => trivial
        | rho i => cases he
      · rintro ⟨b, hb, he, _⟩; exact ⟨b, hb, he⟩
    | rho i =>
      constructor
      · rintro ⟨hi, ha⟩; exact ⟨.rho i, ha, rfl, hi⟩
      · rintro ⟨b, hb, he, hi⟩
        cases b with
        | name l ix => cases he
        | rho j => cases he; exact ⟨hi, hb⟩

/-- 範囲の具体化で、覆う一原子を覆われる原子と同時に移す。 -/
theorem atomCovers_instR {a b : Atom} (h : a.Covers b) (rs : List RangeExpr) :
    (a.instR rs).Covers (b.instR rs) := by
  rcases a with ⟨l, r | i⟩ | i <;> rcases b with ⟨m, s | j⟩ | j <;>
    simp only [Atom.Covers] at h
  · exact h
  · obtain ⟨rfl, rfl⟩ := h; exact Atom.Covers.refl _
  · cases h; exact Atom.Covers.refl _

/-- 四名前空間の置換は、一原子の証人と Fail の不変性を保つ。 -/
theorem Eff.Covers.bind {Γ Φ Δ Ψ outer inner} (h : Covers Γ Φ outer inner) (θ : SubstEnv) :
    Covers Δ Ψ (Eff.bind θ outer) (Eff.bind θ inner) := by
  rw [Eff.bind, Eff.bind, covers_norm_left, covers_norm_right]
  refine ⟨?_, ?_⟩
  · intro a ha
    rcases (Eff.mem_rawBind θ inner a).mp ha with ⟨b, hb, rfl, hi⟩ | ⟨i, f, hf, hi, ha⟩
    · obtain ⟨c, hc, hcb⟩ := h.1 b hb
      refine ⟨c.instR θ.ranges, (Eff.mem_rawBind θ outer _).mpr (Or.inl ⟨c, hc, rfl, ?_⟩),
        atomCovers_instR hcb _⟩
      cases b with
      | name l ix => obtain ⟨jx, rfl⟩ := hcb.name_right; trivial
      | rho i => rw [Atom.covers_rho_iff.mp hcb]; exact hi
    · have ho : outer.mem (.rho i) := by
        obtain ⟨b, hb, hbi⟩ := h.1 (.rho i) hi
        rwa [Atom.covers_rho_iff.mp hbi] at hb
      exact ⟨a, (Eff.mem_rawBind θ outer a).mpr (Or.inr ⟨i, f, hf, ho, ha⟩), Atom.Covers.refl a⟩
  · intro t ht
    rw [Eff.memFail_rawBind] at ht ⊢
    rcases ht with ⟨x, hx, hxt⟩ | ⟨i, f, x, hf, hi, hx, hxt⟩
    · obtain ⟨y, hy, hyx⟩ := h.2 x ⟨x, hx, rfl⟩
      exact Or.inl ⟨y, hy, (Ty.rawBind_norm_congr θ hyx).trans hxt⟩
    · have ho : outer.mem (.rho i) := by
        obtain ⟨b, hb, hbi⟩ := h.1 (.rho i) hi
        rwa [Atom.covers_rho_iff.mp hbi] at hb
      exact Or.inr ⟨i, f, x, hf, ho, hx, hxt⟩

/-- 対象の集合が二つの範囲に含まれても、一原子を二原子に分割して覆えない。 -/
theorem cannot_split_one_atom (Γ : Ctx) (Φ : List Pred) (l : EffName) (host : Scope.Domain.HostPattern) :
    ¬ Eff.Covers Γ Φ
      (.mk (fun (a : Atom) => by
        classical
        exact decide (a = .name l (.fixed (.endpoint ⟨host, ⟨0, 4⟩⟩)) ∨
          a = .name l (.fixed (.endpoint ⟨host, ⟨5, 9⟩⟩)))) [])
      (.mk (fun (a : Atom) => by
        classical
        exact decide (a = .name l (.fixed (.endpoint ⟨host, ⟨0, 9⟩⟩)))) []) := by
  classical
  intro h
  obtain ⟨b, hb, hc⟩ := h.1 (.name l (.fixed (.endpoint ⟨host, ⟨0, 9⟩⟩))) (by simp [Eff.mem, Eff.test, Eff.atoms])
  have hb : b = .name l (.fixed (.endpoint ⟨host, ⟨0, 4⟩⟩)) ∨
      b = .name l (.fixed (.endpoint ⟨host, ⟨5, 9⟩⟩)) := of_decide_eq_true hb
  obtain ⟨_, hleft, hright⟩ := Scope.Domain.Range.endpoint_union_not_covers host
  rcases hb with rfl | rfl
  · exact hleft ((RangeExpr.covers_absolute _ _).mp hc.2)
  · exact hright ((RangeExpr.covers_absolute _ _).mp hc.2)

/-- 被覆から構造上の包含への逆向きの含意は成り立たない。 -/
theorem covers_not_sub (Γ : Ctx) (Φ : List Pred) (l : EffName) :
    Eff.Covers Γ Φ
      (.mk (fun (a : Atom) => by classical exact decide (a = .nameTop l)) [])
      (.mk (fun (a : Atom) => by classical exact decide (a = .name l (.fixed (.path (.tree []))))) []) ∧
    ¬ Eff.Sub
      (.mk (fun (a : Atom) => by classical exact decide (a = .name l (.fixed (.path (.tree []))))) [])
      (.mk (fun (a : Atom) => by classical exact decide (a = .nameTop l)) []) := by
  classical
  constructor
  · constructor
    · intro a ha
      have he : a = .name l (.fixed (.path (.tree []))) := of_decide_eq_true ha
      subst a
      exact ⟨.nameTop l, by simp [Eff.mem, Eff.test, Eff.atoms],
        Atom.nameTop_covers_iff.mpr ⟨_, rfl⟩⟩
    · intro t ht
      obtain ⟨_, h, _⟩ := ht
      cases h
  · intro hs
    have he := hs.1 (.name l (.fixed (.path (.tree [])))) (by simp [Eff.mem, Eff.test, Eff.atoms])
    have he : Atom.name l (.fixed (.path (.tree []))) = .nameTop l := of_decide_eq_true he
    cases he

end Benitoite.Release.Refinement
