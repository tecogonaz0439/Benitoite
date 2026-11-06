import Benitoite.Release.Refinement.Surface.CheckCompare
import Benitoite.Release.Refinement.SourceScope

/-! # 範囲変数の有効範囲の有限な照合

効果の原子は入力の有限支持に沿って検査し、型に直接書かれた範囲の添字も構造的に検査する。
-/
namespace Benitoite.Release.Refinement.Surface.OpenRangeFormationCheck

/-- 固定範囲は変数を束縛せず、範囲変数は宣言した深さより小さい。 -/
def ix (nr : Nat) : RangeIx → Bool
  | .fixed _ => true
  | .rvar i => decide (i < nr)

@[simp] theorem ix_spec (nr : Nat) (r : RangeIx) : ix nr r = true ↔ r.WF nr := by
  cases r <;> simp [ix, RangeIx.WF]

mutual
  def ty (atoms : List Atom) (nr : Nat) : Ty → Bool
    | .base _ | .bytes | .tvar _ | .ctor _ | .pathBases | .scopePattern _ => true
    | .opaque _ r | .scoped _ _ r => ix nr r
    | .data _ as | .tapp _ as | .external _ as => tys atoms nr as
    | .list a | .reference a | .lazy a | .set a | .dict _ a | .refined a _ => ty atoms nr a
    | .map a b => ty atoms nr a && ty atoms nr b
    | .fn _ ps r e => tys atoms nr ps && ty atoms nr r && eff atoms nr e
    | .cont a b e => ty atoms nr a && ty atoms nr b && eff atoms nr e
    | .dependentFn t => tel atoms nr t
  def tys (atoms : List Atom) (nr : Nat) : List Ty → Bool
    | [] => true
    | a :: as => ty atoms nr a && tys atoms nr as
  def eff (atoms : List Atom) (nr : Nat) : Eff → Bool
    | .mk test fails => atoms.all (fun a => match a with
        | .name _ r => !test a || ix nr r
        | .rho _ => true) && tys atoms nr fails
  def tel (atoms : List Atom) (nr : Nat) : Tel → Bool
    | .done r e => ty atoms nr r && eff atoms nr e
    | .param _ a t => ty atoms nr a && tel atoms nr t
end

mutual
  theorem ty_sound {atoms nr a} (ha : a.Support (· ∈ atoms)) (h : ty atoms nr a = true) :
      a.RangesScoped nr := by
    cases a <;> simp only [ty, Bool.and_eq_true, Ty.RangesScoped, Ty.Support] at h ha ⊢
    all_goals first | trivial | exact (ix_spec _ _).mp h | exact ty_sound ha h | exact tys_sound ha h | exact tel_sound ha h | skip
    case fn => exact ⟨tys_sound ha.1 h.1.1, ty_sound ha.2.1 h.1.2, eff_sound ha.2.2 h.2⟩
    case cont => exact ⟨ty_sound ha.1 h.1.1, ty_sound ha.2.1 h.1.2, eff_sound ha.2.2 h.2⟩
    case map => exact ⟨ty_sound ha.1 h.1, ty_sound ha.2 h.2⟩
  theorem tys_sound {atoms nr as} (ha : Ty.SupportList (· ∈ atoms) as) (h : tys atoms nr as = true) :
      rangesScopedTypes nr as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨ty_sound ha.1 (Bool.and_eq_true_iff.mp h).1,
        tys_sound ha.2 (Bool.and_eq_true_iff.mp h).2⟩
  theorem eff_sound {atoms nr e} (he : e.Support (· ∈ atoms)) (h : eff atoms nr e = true) :
      e.RangesScoped nr := by
    cases e with
    | mk test fails =>
      have hh := Bool.and_eq_true_iff.mp h
      refine ⟨?_, tys_sound he.2 hh.2⟩
      intro label r hr
      have hm := List.all_eq_true.mp hh.1 (.name label r) (he.1 _ hr)
      simp only [hr, Bool.not_true, Bool.false_or] at hm
      exact (ix_spec _ _).mp hm
  theorem tel_sound {atoms nr t} (ht : t.Support (· ∈ atoms)) (h : tel atoms nr t = true) :
      t.RangesScoped nr := by
    cases t with
    | done r e => exact ⟨ty_sound ht.1 (Bool.and_eq_true_iff.mp h).1,
        eff_sound ht.2 (Bool.and_eq_true_iff.mp h).2⟩
    | param name a t => exact ⟨ty_sound ht.1 (Bool.and_eq_true_iff.mp h).1,
        tel_sound ht.2 (Bool.and_eq_true_iff.mp h).2⟩
end

end Benitoite.Release.Refinement.Surface.OpenRangeFormationCheck
