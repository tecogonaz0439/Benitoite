import Benitoite.Release.Refinement.Patterns

/-! # 正規形の値の意味と子値の意味 -/
namespace Benitoite.Release.Refinement

/-- 範囲付き型の意味に使う成功値の形。範囲の所属そのものは型付けが保持する。 -/
inductive ScopedValue : RangeIx → Val → Prop where
  | checked {r target} : ScopedValue (.fixed r) (.checked target)
  | checkedRequest {r target req} : ScopedValue (.fixed r) (.checkedRequest target req)
  | checkedAt {ix r snapshot target req} : ScopedValue ix (.checkedAt r snapshot target req)

theorem ScopedValue.covers {outer inner v} (hc : RangeIx.Covers outer inner)
    (h : ScopedValue inner v) : ScopedValue outer v := by
  cases outer <;> cases inner <;> simp only [RangeIx.Covers] at hc
  · cases h <;> first | exact .checked | exact .checkedRequest | exact .checkedAt
  · subst hc; exact h

mutual
  inductive ValueMeaning (P : Program) (η : ObservationEnvModel) : Ty → Val → Prop where
    | mk {a v} : ValueShapeMeaning P η a.norm.core v →
        (∀ p ∈ a.norm.refinementPredicates, p.interpret (selfModel η v) = true) → ValueMeaning P η a v
  inductive ValueShapeMeaning (P : Program) (η : ObservationEnvModel) : Ty → Val → Prop where
    | const {c} : ValueShapeMeaning P η c.type (.const c)
    | con {c ts tys args cd} : P.cons c = some cd → cd.ntys = ts.length →
        (∀ a ∈ cd.args, a.WF 0 cd.ntys 0) →
        ValueMeanings P η (cd.args.map (Ty.subst ts [])) args →
        ValueShapeMeaning P η (.data cd.data ts) (.con c tys args)
    | atError {detail} : ResultShape.StandardError P
        ⟨"Result", "Ok", "Error", atErrorType⟩ →
        ValueShapeMeaning P η atErrorType (.atError detail)
    | list {a elems} : ValueMeaningEach P η a elems → ValueShapeMeaning P η (.list a) (.list elems)
    | fn {ns ps r e v} : ValueShapeMeaning P η (.fn ns ps r e) v
    | dependentFn {t v} : ValueShapeMeaning P η (.dependentFn t) v
    | tvar {i v} : ValueShapeMeaning P η (.tvar i) v
    | reference {a v} : ValueShapeMeaning P η (.reference a) v
    | lazy {a v} : ValueShapeMeaning P η (.lazy a) v
    | cont {b t e v} : ValueShapeMeaning P η (.cont b t e) v
    | map {a b v} : ValueShapeMeaning P η (.map a b) v
    | set {a v} : ValueShapeMeaning P η (.set a) v
    | bytes {v} : ValueShapeMeaning P η .bytes v
    | dict {cl a v} : ValueShapeMeaning P η (.dict cl a) v
    | tapp {i as v} : ValueShapeMeaning P η (.tapp i as) v
    | ctor {c v} : ValueShapeMeaning P η (.ctor c) v
    | external {id ts v} : ValueShapeMeaning P η (.external id ts) v
    | scoped {o k ix v} : ScopedValue ix v → ValueShapeMeaning P η (.scoped o k ix) v
    | pathBases {v} : ValueShapeMeaning P η .pathBases v
    | scopePattern {k v} : ValueShapeMeaning P η (.scopePattern k) v
    | checked {o r t} : ValueShapeMeaning P η (.opaque o (.fixed r)) (.checked t)
    | checkedRequest {o r t req} : ValueShapeMeaning P η (.opaque o (.fixed r)) (.checkedRequest t req)
    | checkedAtOpaque {o ix r snapshot target req} :
        ValueShapeMeaning P η (.opaque o ix) (.checkedAt r snapshot target req)
  inductive ValueMeanings (P : Program) (η : ObservationEnvModel) : List Ty → List Val → Prop where
    | nil : ValueMeanings P η [] []
    | cons {a as v vs} : ValueMeaning P η a v → ValueMeanings P η as vs → ValueMeanings P η (a :: as) (v :: vs)
  inductive ValueMeaningEach (P : Program) (η : ObservationEnvModel) : Ty → List Val → Prop where
    | nil {a} : ValueMeaningEach P η a []
    | cons {a v vs} : ValueMeaning P η a v → ValueMeaningEach P η a vs → ValueMeaningEach P η a (v :: vs)
end

noncomputable section

theorem ValueMeaning.norm_iff (P : Program) (η : ObservationEnvModel) (a : Ty) (v : Val) :
    ValueMeaning P η a.norm v ↔ ValueMeaning P η a v := by
  constructor <;> intro h <;> cases h with
  | mk hs hp =>
    exact .mk (by simpa only [Ty.norm_idem] using hs)
      (by simpa only [Ty.norm_idem] using hp)

theorem ScopedValue.forget {ix v} (P : Program) (η : ObservationEnvModel) (o : OpaqueName)
    (h : ScopedValue ix v) : ValueShapeMeaning P η (.opaque o ix) v := by
  cases h <;> first | exact .checked | exact .checkedRequest | exact .checkedAtOpaque

theorem ValueShapeMeaning.scoped_inv {P η a v} (h : ValueShapeMeaning P η a v) :
    ∀ o k ix, a = .scoped o k ix → ScopedValue ix v := by
  match h with
  | .scoped hs => intro o k ix he; cases he; exact hs
  | .const (c := c) => intro o k ix he; cases c <;> cases he
  | .con .. | .atError .. | .list .. | .fn | .dependentFn | .tvar | .reference | .lazy | .cont |
    .map | .set | .bytes | .dict | .tapp | .ctor | .external | .pathBases | .scopePattern |
    .checked | .checkedRequest | .checkedAtOpaque => intro o k ix he; cases he

theorem ValueMeaning.of_scoped {P η o k ix v} (h : ScopedValue ix v) :
    ValueMeaning P η (.scoped o k ix) v := .mk (.scoped h) (by intro p hp; cases hp)

theorem ValueMeaning.scoped_inv {P η o k ix v} (h : ValueMeaning P η (.scoped o k ix) v) :
    ScopedValue ix v := by
  cases h with
  | mk hs _ => exact hs.scoped_inv o k ix rfl

/-- 範囲を広げる部分型は、成功値の形を保つ。 -/
theorem ValueMeaning.scoped_covers {P η o k inner outer v}
    (hc : RangeIx.Covers outer inner) (h : ValueMeaning P η (.scoped o k inner) v) :
    ValueMeaning P η (.scoped o k outer) v := .of_scoped (h.scoped_inv.covers hc)

/-- scoped から opaque への部分型は、同じ添字の成功値の意味を持つ。 -/
theorem ValueMeaning.scoped_forget {P η o k ix v}
    (h : ValueMeaning P η (.scoped o k ix) v) : ValueMeaning P η (.opaque o ix) v :=
  .mk (h.scoped_inv.forget P η o) (by intro p hp; cases hp)

end
end Benitoite.Release.Refinement
