import Benitoite.Release.Refinement.TypeBounds
import Benitoite.Release.Refinement.PathResolution

/-! 効果の構造等号、固定した起点での許可、行の置換。
Failの不変な所属と一原子の被覆を区別する（設計書01-12「コア計算と脱糖」）。 -/
namespace Benitoite.Release.Refinement
open Order

def Eff.Allows (σ : PathEnv) (κ : EffName → Option Scope.Domain.Kind) (e : Eff)
    (l : EffName) (t : Scope.Domain.Target) : Prop :=
  ∃ k r, κ l = some k ∧ e.mem (.name l (.fixed r)) ∧ r.Mem σ k t

def Atom.TopImage : Atom → Prop
  | .rho _ => True
  | .name _ ix => ix = .top

def Eff.TopAtoms (e : Eff) : Prop := ∀ a, e.mem a → a.TopImage

noncomputable def Eff.substRho (es : List Eff) (e : Eff) : Eff := Eff.subst [] es e

theorem Eff.memFail_singleFail (a b : Ty) : (Eff.singleFail a).memFail b ↔ a.norm = b.norm := by
  simp only [Eff.memFail, Eff.singleFail, Eff.fails, List.mem_singleton,
    exists_eq_left, Ty.norm_idem]

theorem Eff.eq_of_sub_of_sub {e f : Eff} (he : e.Canonical) (hf : f.Canonical)
    (hef : Eff.Sub e f) (hfe : Eff.Sub f e) : e = f := by
  have ha : e.atoms = f.atoms := by
    funext a
    exact Bool.eq_iff_iff.mpr ⟨hef.1 a, hfe.1 a⟩
  have hfs : e.norm.fails = f.norm.fails := by
    cases e with
    | mk atoms es =>
      cases f with
      | mk atoms' fs =>
        simp only [Eff.norm, Eff.fails]
        apply (sortUnique_eq_iff_mem).mpr
        intro t
        simp only [Ty.normTys_eq_map, List.mem_map]
        constructor
        · rintro ⟨x, hx, rfl⟩
          obtain ⟨y, hy, hyx⟩ := hef.2 x ⟨x, hx, rfl⟩
          exact ⟨y, hy, hyx⟩
        · rintro ⟨x, hx, rfl⟩
          obtain ⟨y, hy, hyx⟩ := hfe.2 x ⟨x, hx, rfl⟩
          exact ⟨y, hy, hyx⟩
  have hn : e.norm = f.norm := by
    cases e with
    | mk atoms es =>
      cases f with
      | mk atoms' fs =>
        change atoms = atoms' at ha
        cases ha
        exact congrArg (EffR.mk atoms) hfs
  exact he.symm.trans (hn.trans hf)

theorem Eff.allows_norm {σ : PathEnv} {κ : EffName → Option Scope.Domain.Kind}
    {e : Eff} {l : EffName} {t : Scope.Domain.Target} :
    Eff.Allows σ κ e.norm l t ↔ Eff.Allows σ κ e l t := by
  simp only [Eff.Allows, Eff.mem_norm]

theorem Eff.TopAtoms.norm {e : Eff} (h : e.TopAtoms) : e.norm.TopAtoms :=
  fun a ha => h a ((Eff.mem_norm e a).mp ha)

theorem substAtoms_false (es : List Eff) : substAtoms es (fun _ => false) = fun _ => false := by
  funext x
  cases x <;> simp [substAtoms]

theorem rowFails_false (es : List Eff) : rowFails es (fun _ => false) = [] := by
  simp [rowFails]

theorem Eff.substRho_empty (es : List Eff) : Eff.substRho es Eff.empty = Eff.empty := by
  simp only [Eff.substRho, Eff.subst, Eff.substAt, substRowAt, Eff.bind, Eff.rawBind,
    Eff.empty, typeEnvAt, instAtoms_nil, substAtoms_false, rawBindTys, rowFails_false,
    List.nil_append, Eff.norm, Ty.normTys, sortUnique_nil]

theorem Eff.substRho_name {es : List Eff} {e : Eff} {l : EffName} {ix : RangeIx}
    (h : e.mem (.name l ix)) : (Eff.substRho es e).mem (.name l ix) := by
  change (Eff.rawBind (typeEnvAt 0 [] es) e).norm.mem (.name l ix)
  rw [Eff.mem_norm, Eff.mem_rawBind]
  exact Or.inl ⟨.name l ix, h, by simp only [typeEnvAt, Atom.instR_nil], trivial⟩

end Benitoite.Release.Refinement
