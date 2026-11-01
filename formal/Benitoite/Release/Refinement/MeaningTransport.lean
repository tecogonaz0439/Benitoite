import Benitoite.Release.Refinement.CoverageRefinement
import Benitoite.Release.Refinement.VarianceTransport
import Benitoite.Release.Refinement.MeaningOrder

/-! 値の大きさと部分型の導出を分けた意味移送の帰納命題。
設計書 01-12「篩を読む網羅性と値の意味」に対応する。 -/
namespace Benitoite.Release.Refinement

namespace MeaningTransport

def MOrder {P : Program} {Γ : Ctx} {Φ : List Pred} {a b : Ty}
    (v : Val) (_h : MeaningLe P Γ Φ a b) : Prop :=
  ∀ (η : ObservationEnvModel),
    (∀ p ∈ Γ.facts ++ Φ, p.interpret η = true) →
    ValueMeaning P η a v → ValueMeaning P η b v

def Outer (n : Nat) : Prop :=
  ∀ (v : Val), sizeOf v = n →
    ∀ (P : Program), P.VarianceValid →
      ∀ (Γ : Ctx) (Φ : List Pred) (a b : Ty) (h : MeaningLe P Γ Φ a b),
        MOrder v h

def Below (n : Nat) : Prop :=
  ∀ (w : Val), sizeOf w < n → Outer (sizeOf w)

noncomputable section

theorem fields_meaning {n P Γ Φ η vs as bs} (ih : Below n) (valid : P.VarianceValid)
    (facts : ∀ p ∈ Γ.facts ++ Φ, p.interpret η = true)
    (args : MeaningArgs P Γ Φ vs as bs) (fields : List Ty)
    (occurs : ∀ a ∈ fields, a.VarianceOK P vs .positive)
    {xs : List Val} (small : ∀ w ∈ xs, sizeOf w < n)
    (source : ValueMeanings P η (fields.map (Ty.subst as [])) xs) :
    ValueMeanings P η (fields.map (Ty.subst bs [])) xs := by
  induction fields generalizing xs with
  | nil => cases source; exact .nil
  | cons a fields tail =>
    cases source with
    | cons h hs =>
      refine .cons (ih _ (small _ (by simp)) _ rfl P valid Γ Φ _ _
        (field_order (occurs a (by simp)) args) η facts h) ?_
      exact tail (fun a ha => occurs a (by simp [ha]))
        (fun w hw => small w (by simp [hw])) hs

theorem data_shape_meaning {n P Γ Φ η d as bs v} (ih : Below n) (valid : P.VarianceValid)
    (facts : ∀ p ∈ Γ.facts ++ Φ, p.interpret η = true)
    (args : MeaningArgs P Γ Φ (P.varianceFor d as.length) as bs)
    (small : sizeOf v = n) (source : ValueShapeMeaning P η (.data d as) v) :
    ValueShapeMeaning P η (.data d bs) v := by
  generalize he : Ty.data d as = t at source
  match source with
  | .con (c := c) (tys := tys) (args := xs) (cd := cd) lookup arity wf fields =>
    cases he
    have hl : bs.length = as.length := args.length.2.trans args.length.1.symm
    refine .con lookup (arity.trans hl.symm) wf ?_
    apply fields_meaning ih valid facts args cd.args
    · intro a ha
      simpa only [←arity] using (valid.2 c cd lookup).2 a ha |>.2.2
    · intro w hw
      have hlt := List.sizeOf_lt_of_mem hw
      simp only [Val.con.sizeOf_spec] at small
      omega
    · exact fields
  | .atError hs =>
    cases he
    have hl : bs.length = 0 := args.length.2.trans args.length.1.symm
    have hb : bs = [] := List.eq_nil_of_length_eq_zero hl
    subst bs
    exact .atError hs
  | .const (c := c) => cases c <;> cases he
  | .list .. | .fn | .dependentFn | .tvar | .reference | .lazy | .cont | .map | .set |
    .bytes | .dict | .tapp | .ctor | .external | .scoped .. | .pathBases | .scopePattern |
    .checked | .checkedRequest | .checkedAtOpaque => cases he

theorem each_meaning {n P Γ Φ η a b xs} (ih : Below n) (valid : P.VarianceValid)
    (facts : ∀ p ∈ Γ.facts ++ Φ, p.interpret η = true)
    (order : MeaningLe P Γ Φ a b) (small : ∀ w ∈ xs, sizeOf w < n)
    (source : ValueMeaningEach P η a xs) : ValueMeaningEach P η b xs := by
  match source with
  | .nil => exact .nil
  | .cons h hs =>
    exact .cons (ih _ (small _ (by simp)) _ rfl P valid Γ Φ a b order η facts h)
      (each_meaning ih valid facts order (fun w hw => small w (by simp [hw])) hs)

theorem list_shape_meaning {n P Γ Φ η a b v} (ih : Below n) (valid : P.VarianceValid)
    (facts : ∀ p ∈ Γ.facts ++ Φ, p.interpret η = true)
    (order : MeaningLe P Γ Φ a b) (small : sizeOf v = n)
    (source : ValueShapeMeaning P η (.list a) v) : ValueShapeMeaning P η (.list b) v := by
  generalize he : Ty.list a = t at source
  match source with
  | .list (elems := xs) hs =>
    cases he
    refine .list ?_
    have lt : ∀ w ∈ xs, sizeOf w < n := by
      intro w hw
      have hlt := List.sizeOf_lt_of_mem hw
      simp only [Val.list.sizeOf_spec] at small
      omega
    exact each_meaning ih valid facts order lt hs
  | .const (c := c) => cases c <;> cases he
  | .con .. | .atError .. | .fn | .dependentFn | .tvar | .reference | .lazy | .cont | .map | .set |
    .bytes | .dict | .tapp | .ctor | .external | .scoped .. | .pathBases | .scopePattern |
    .checked | .checkedRequest | .checkedAtOpaque => cases he

theorem dependentFn_meaning {P η t v} : ValueMeaning P η (.dependentFn t) v := by
  refine .mk ?_ ?_
  · simp only [Ty.norm, Ty.core_foldFn]
    unfold Ty.foldFn
    split
    · exact .fn
    · exact .dependentFn
  · simp only [Ty.predicates_norm, Ty.refinementPredicates, List.not_mem_nil, false_implies, implies_true]

theorem assumptions_meaning {P Γ Φ η a v} (source : ValueMeaning P η a v)
    (facts : ∀ p ∈ Γ.facts ++ Φ, p.interpret η = true) :
    ∀ p ∈ assumptions Γ Φ a, p.interpret (selfModel η v) = true := by
  intro p hp
  rcases List.mem_append.mp hp with hp | hp
  · cases source with
    | mk _ hs =>
      apply hs p
      rw [Ty.predicates_norm]
      by_cases ho : a.Ordinary
      · simpa only [Ty.assume_eq_predicates ho] using hp
      · simp [Ty.assume_eq_nil ho] at hp
  · obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
    rw [Pred.interpret_lift_self]
    exact facts q hq

/-- 同じ値では二つの厳密な部分導出の帰納仮定を合成する。 -/
theorem order_trans {P Γ Φ a b c v} {left : MeaningLe P Γ Φ a b} {right : MeaningLe P Γ Φ b c}
    (hl : MOrder v left) (hr : MOrder v right) : MOrder v (.trans left right) := by
  intro η facts source
  exact hr η facts (hl η facts source)

/-- 基底の内側 IH と自己を加えたモデルでの含意から篩の意味を移送する。 -/
theorem order_refine {P Γ Φ a b p q v} {base : MeaningLe P Γ Φ a b}
    (ih : MOrder v base) (entails : Entails (p :: assumptions Γ Φ a) q) :
    MOrder v (.refine base entails) := by
  intro η facts source
  exact valueMeaning_refine source (ih η facts (ValueMeaning.refined_iff.mp source).1) facts entails

/-- 新しく作った欄の比較には子値の外側 IH を適用する。 -/
theorem order_data {n v P Γ Φ d as bs} (ih : Below n) (small : sizeOf v = n)
    (valid : P.VarianceValid) (args : MeaningArgs P Γ Φ (P.varianceFor d as.length) as bs) :
    MOrder v (.data args) := by
  intro η facts source
  cases source with
  | mk hs _ =>
    refine .mk (data_shape_meaning ih valid facts ?_ small hs) (by intro p hp; cases hp)
    simpa only [Ty.normTys_eq_map, List.length_map] using args.norm

theorem order_step {n v P Γ Φ a b} (ih : Below n) (small : sizeOf v = n)
    (valid : P.VarianceValid) (order : MeaningLe P Γ Φ a b) : MOrder v order := by
  unfold MOrder
  induction order using MeaningLe.rec (motive_2 := fun _ _ _ _ => True) with
  | convert he =>
    intro η facts source
    exact (ValueMeaning.norm_iff P η _ v).mp
      (he ▸ (ValueMeaning.norm_iff P η _ v).mpr source)
  | trans hab hbc left right => exact order_trans (left := hab) (right := hbc) left right
  | list h _ =>
    intro η facts source
    cases source with
    | mk hs _ =>
      exact .mk (list_shape_meaning ih valid facts h.norm small hs) (by intro p hp; cases hp)
  | lazy => intro η facts source; exact .mk .lazy (by intro p hp; cases hp)
  | map => intro η facts source; exact .mk .map (by intro p hp; cases hp)
  | fn => intro η facts source; exact .mk .fn (by intro p hp; cases hp)
  | dependentFn => intro η facts source; exact dependentFn_meaning
  | forget => intro η facts source; exact (ValueMeaning.refined_iff.mp source).1
  | introduce he =>
    intro η facts source
    exact ValueMeaning.refined_iff.mpr ⟨source, he.sound _ (assumptions_meaning source facts)⟩
  | refine h he base => exact order_refine (base := h) base he
  | «scoped» hc => intro η facts source; exact source.scoped_covers hc
  | scoped_forget => intro η facts source; exact source.scoped_forget
  | data args _ => exact order_data ih small valid args
  | nil => trivial
  | covariant_cons _ _ _ _ => trivial
  | contravariant_cons _ _ _ _ => trivial
  | invariant_cons _ _ _ => trivial

theorem outer_complete : ∀ n, Outer n := by
  intro n
  induction n using Nat.strongRecOn with
  | ind n ih =>
    intro v small P valid Γ Φ a b order
    exact order_step (fun w hw => ih (sizeOf w) hw) small valid order

theorem meaning_order_sound {P Γ Φ a b v η} (valid : P.VarianceValid)
    (order : MeaningLe P Γ Φ a b)
    (facts : ∀ p ∈ Γ.facts ++ Φ, p.interpret η = true)
    (source : ValueMeaning P η a v) : ValueMeaning P η b v :=
  outer_complete (sizeOf v) v rfl P valid Γ Φ a b order η facts source

/-- 宣言の欄の型の意味は、型像の Ordinary や新しい形成の前提なしで移送できる。 -/
theorem valueMeaning_field_mono {P Γ Φ vs as bs a v η} (valid : P.VarianceValid)
    (occurs : Ty.VarianceOK P vs .positive a) (args : TypeArgsLe P Γ Φ vs as bs)
    (facts : ∀ p ∈ Γ.facts ++ Φ, p.interpret η = true)
    (source : ValueMeaning P η (a.subst as []) v) : ValueMeaning P η (a.subst bs []) v :=
  meaning_order_sound valid (field_order occurs (of_args args)) facts source

end
end MeaningTransport

/-- 型像の非継続を独立に要求せず、型の構造と値の子への下降から意味を移送する。 -/
theorem valueMeaning_sub {P Γ Φ a b v η} (valid : P.VarianceValid)
    (sub : Ty.LeQ P Γ Φ a b)
    (facts : ∀ p ∈ Γ.facts ++ Φ, p.interpret η = true)
    (source : ValueMeaning P η a v) : ValueMeaning P η b v :=
  MeaningTransport.meaning_order_sound valid (MeaningTransport.of_le sub) facts source

end Benitoite.Release.Refinement
