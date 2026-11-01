import Benitoite
/-! 効果の許可と、VarsIn の移送、生の二重置換の代替の確認。 -/
open Benitoite.Release.Refinement
namespace RvT3
abbrev Kind := Benitoite.Scope.Domain.Kind

def snapshot : PathEnv := ⟨[], [], [], none, none, none⟩
def other : PathEnv := ⟨[], ["x"], [], none, none, none⟩
def pathKind : Benitoite.Release.EffName → Option Kind := fun _ => some .path
def one (a : Atom) : Eff := .mk (fun b => decide (b = a)) []
def based : Atom := .name "" (.fixed (.based .cwd (.tree [])))

-- boundary の kind_none_denies の対になる正例。Top の効果は κ があれば許す。
theorem top_allows : Eff.Allows snapshot pathKind (one (.nameTop "")) "" (.path []) :=
  ⟨.path, .top, rfl, by decide, by decide⟩
-- 範囲変数の原子からは許可が出ない（boundary の row_variable_denies は行変数であり、これとは別）。
theorem rvar_denies : ¬ Eff.Allows snapshot pathKind (one (.name "" (.rvar 0))) "" (.path []) := by
  rintro ⟨_, r, _, h, _⟩
  have : Atom.name "" (.fixed r) = .name "" (.rvar 0) := of_decide_eq_true h
  cases this
-- σ に secrets がなければ許可は出ない。
theorem secrets_denies : ¬ Eff.Allows snapshot pathKind (one (.name "" (.fixed .secrets))) "" (.path []) := by
  rintro ⟨k, r, hk, h, hm⟩
  have : Atom.name "" (.fixed r) = .name "" (.fixed .secrets) := of_decide_eq_true h
  cases this
  exact hm.2.elim
-- 固定する σ を変えると based の結果が変わる。
theorem sigma_matters : Eff.Allows snapshot pathKind (one based) "" (.path ["y"]) ∧
    ¬ Eff.Allows other pathKind (one based) "" (.path ["y"]) := by
  constructor
  · exact ⟨.path, .based .cwd (.tree []), rfl, by decide, by decide⟩
  · rintro ⟨k, r, hk, h, hm⟩
    have : Atom.name "" (.fixed r) = based := of_decide_eq_true h
    cases this
    cases hk
    revert hm; decide

-- TopAtoms は Fail 内部を読まず、非 Top の名前の原子だけを拒む。
def inner : Ty := .fn [] [] (.base .unit) (one based)
def topWithFail : Eff := .mk (fun a => decide (a = .nameTop "")) [inner]
theorem top_atoms_ignores_fail : topWithFail.TopAtoms := by
  intro a ha
  have : a = .nameTop "" := of_decide_eq_true ha
  subst this; rfl
theorem top_atoms_rejects_based : ¬ (one based).TopAtoms := by
  intro h
  have := h based (by decide)
  simp only [Atom.TopImage, based] at this
  cases this

/-- 型の VarsIn の substAt。支持の入口と bind_wf を組み合わせれば足りる。 -/
theorem substAt_varsIn {nr n nv ne : Nat} (c : Nat) (ts : List Ty) (es : List Eff) (a : Ty)
    (ht : ∀ t ∈ ts, t.VarsIn nr n nv (· < ne)) (he : ∀ e ∈ es, e.VarsIn nr n nv (· < ne))
    (ho : ∀ t ∈ ts, Ordinary t)
    (ha : a.VarsIn nr (c+ts.length) nv (· < ne)) (hne : ne = 0) :
    (a.substAt c ts es).VarsIn nr (n+c) nv (· < ne) := by
  subst hne
  have hw := Ty.substAt_wf c ts es (fun t h => (ht t h).1) (fun e h => (he e h).1) ho a ha.1
  have hs : ∀ (q : Atom → Prop), (∀ t ∈ ts, t.Support q) → (∀ e ∈ es, e.Support q) → a.Support q →
      (a.substAt c ts es).Support q := fun q h1 h2 h3 =>
    Ty.substAt_support_of_imp c ts es a h3 h1 h2 (fun _ h => h)
  refine ⟨hw, ?_, ?_⟩
  · exact (Ty.rowsIn_iff_support _ _).mpr (hs _
      (fun t h => (Ty.rowsIn_iff_support _ _).mp (ht t h).2.1)
      (fun e h => (Eff.rowsIn_iff_support _ _).mp (he e h).2.1)
      ((Ty.rowsIn_iff_support _ _).mp ha.2.1))
  · exact (Ty.rangesScoped_iff_support _ hw).mpr (hs _
      (fun t h => (Ty.rangesScoped_iff_support _ (ht t h).1).mp (ht t h).2.2)
      (fun e h => (Eff.rangesScoped_iff_support _ (he e h).1).mp (he e h).2.2)
      ((Ty.rangesScoped_iff_support _ ha.1).mp ha.2.2))

/-- 旧 RawWF の中間段の代替。二重の生の置換は、正規化の交換で bind の合成へ移す。 -/
theorem raw_twice_wf {nr nt nv mr mt mv kr kt kv : Nat} {θ τ : SubstEnv} (a : Ty)
    (h : a.WF nr nt nv) (hθ : θ.WFImages nr nt nv mr mt mv) (hτ : τ.WFImages mr mt mv kr kt kv) :
    ((a.rawBind θ).rawBind τ).norm.WF kr kt kv := by
  rw [← Ty.norm_rawBind]
  exact Ty.rawBind_norm_wf _ (Ty.rawBind_norm_wf a h hθ) hτ

end RvT3
#print axioms RvT3.substAt_varsIn
#print axioms RvT3.raw_twice_wf
