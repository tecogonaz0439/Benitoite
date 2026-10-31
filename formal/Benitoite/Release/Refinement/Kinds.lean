import Benitoite.Release.Refinement.Telescope

/-!
# 型構成子位置の kind と引数数

値型の篩と型構成子の像を区別する。全域の rawApply の既定の枝を
適格な適用の証明には使わない。
-/
namespace Benitoite.Release.Refinement

/-- 同じ名目型の宣言が arity について一致し、少なくとも一つ存在する。 -/
def Program.DataArity (P : Program) (d : DataName) (n : Nat) : Prop :=
  (∃ c cd, P.cons c = some cd ∧ cd.data = d) ∧
    ∀ c cd, P.cons c = some cd → cd.data = d → cd.ntys = n

theorem Program.DataArity.unique {P d n m} (h : Program.DataArity P d n)
    (g : Program.DataArity P d m) : n = m := by
  obtain ⟨c, cd, hc, hd⟩ := h.1
  exact (h.2 c cd hc hd).symm.trans (g.2 c cd hc hd)

noncomputable def TyCon.arity (P : Program) : Benitoite.Release.TyCon → Option Nat := by
  classical
  exact fun
  | .list | .set | .reference | .lazy => some 1
  | .map => some 2
  | .data d => if h : ∃ n, P.DataArity d n then some (Classical.choose h) else none

theorem TyCon.arity_data {P d n} (h : P.DataArity d n) : TyCon.arity P (.data d) = some n := by
  classical
  simp only [TyCon.arity, dite_eq_left (show ∃ n, P.DataArity d n from ⟨n, h⟩)]
  congr 1
  exact Program.DataArity.unique (Classical.choose_spec (show ∃ n, P.DataArity d n from ⟨n, h⟩)) h

mutual
  def Ty.HasKind (P : Program) (K : KindCtx) : Ty → TyKind → Prop
    | a, .constructor n => match a with
      | .ctor c => TyCon.arity P c = some n
      | .tvar i => K[i]? = some (.constructor n)
      | _ => False
    | .base _, .value | .bytes, .value | .opaque _ _, .value | .scoped _ _ _, .value
    | .pathBases, .value | .scopePattern _, .value => True
    | .data d as, .value => TyCon.arity P (.data d) = some as.length ∧ kindsList P K as
    | .external _ as, .value => kindsList P K as
    | .list a, .value | .reference a, .value | .lazy a, .value | .set a, .value => a.HasKind P K .value
    | .dict cl a, .value => ∃ cd, P.classes cl = some cd ∧ a.HasKind P K cd.argumentKind
    | .fn ns ps r e, .value => NamesWF ns ps ∧ kindsList P K ps ∧ r.HasKind P K .value ∧ kindsEff P K e
    | .dependentFn t, .value => kindsTel P K t
    | .tvar i, .value => K[i]? = some .value
    | .cont b t e, .value => b.HasKind P K .value ∧ t.HasKind P K .value ∧ kindsEff P K e
    | .map a b, .value => a.HasKind P K .value ∧ b.HasKind P K .value
    | .tapp i as, .value => K[i]? = some (.constructor as.length) ∧ kindsList P K as
    | .ctor _, .value => False
    | .refined a _, .value => a.HasKind P K .value ∧ a.NotContCore
  def kindsTel (P : Program) (K : KindCtx) : Tel → Prop
    | .done r e => r.HasKind P K .value ∧ kindsEff P K e
    | .param _ a t => a.HasKind P K .value ∧ kindsTel P K t
  def kindsList (P : Program) (K : KindCtx) : List Ty → Prop
    | [] => True
    | a :: as => a.HasKind P K .value ∧ kindsList P K as
  def kindsEff (P : Program) (K : KindCtx) : Eff → Prop
    | .mk _ fs => kindsList P K fs
end

abbrev Ty.ValueKind (P : Program) (K : KindCtx) (a : Ty) : Prop := a.HasKind P K .value

theorem Ty.valueKind_dict_iff (P : Program) (K : KindCtx) (cl : ClassName) (a : Ty) :
    Ty.ValueKind P K (.dict cl a) ↔ ∃ cd, P.classes cl = some cd ∧ a.HasKind P K cd.argumentKind := Iff.rfl


theorem Ty.valueKind_dict_iff_class {P K cl a cd} (hc : P.classes cl = some cd) :
    Ty.ValueKind P K (.dict cl a) ↔ a.HasKind P K cd.argumentKind := by
  simp only [Ty.valueKind_dict_iff, hc, Option.some.injEq]
  constructor
  · rintro ⟨other, he, hk⟩; cases he; exact hk
  · intro hk; exact ⟨cd, rfl, hk⟩

/-- 実装の対象を、その型クラスが宣言したkindで検査する。 -/
def ImplDecl.TargetKinded (P : Program) (K : KindCtx) (d : ImplDecl) : Prop :=
  ∃ cd, P.classes d.cls = some cd ∧ d.target.HasKind P K cd.argumentKind

theorem ImplDecl.targetKinded_iff {P K d cd} (hc : P.classes d.cls = some cd) :
    ImplDecl.TargetKinded P K d ↔ d.target.HasKind P K cd.argumentKind := by
  simp only [ImplDecl.TargetKinded, hc, Option.some.injEq]
  constructor
  · rintro ⟨other, he, hk⟩; cases he; exact hk
  · intro hk; exact ⟨cd, rfl, hk⟩


def TypeImagesKinded (P : Program) (K L : KindCtx) (θ : Nat → Ty) : Prop :=
  ∀ i k, K[i]? = some k → (θ i).HasKind P L k ∧
    (k = .value → Ordinary (θ i))

theorem Ty.HasKind.constructor_shape {P : Program} {K : KindCtx} {a : Ty} {n : Nat} (h : a.HasKind P K (.constructor n)) :
    (∃ c, a = .ctor c ∧ TyCon.arity P c = some n) ∨
      (∃ i, a = .tvar i ∧ K[i]? = some (.constructor n)) := by
  cases a <;> simp only [Ty.HasKind] at h
  all_goals first | contradiction | exact Or.inl ⟨_, rfl, h⟩ | exact Or.inr ⟨_, rfl, h⟩

theorem rawApply_proper {P : Program} {K : KindCtx} {a : Ty} {n : Nat} {as : List Ty} (h : a.HasKind P K (.constructor n))
    (hn : as.length = n) : ProperApply a as (rawApply a as) := by
  rcases h.constructor_shape with ⟨c, rfl, hc⟩ | ⟨i, rfl, _⟩
  · cases c with
    | data d => exact .data d as
    | list | set | reference | lazy =>
      simp only [TyCon.arity, Option.some.injEq] at hc
      have hl := hn.trans hc.symm
      cases as with
      | nil => cases hl
      | cons a as =>
        cases as with
        | nil => first | exact .list a | exact .set a | exact .reference a | exact .lazy a
        | cons b bs => simp at hl
    | map =>
      simp only [TyCon.arity, Option.some.injEq] at hc
      have hl := hn.trans hc.symm
      cases as with
      | nil => cases hl
      | cons a as => cases as with
        | nil => cases hl
        | cons b bs => cases bs with
          | nil => exact .map a b
          | cons c cs => simp at hl
  · exact .variable i as

/-- 型引数位置の条件だけで、誤った rawApply の枝へ入らない。 -/
theorem TypeImagesKinded.apply {P K L θ i n as} (h : TypeImagesKinded P K L θ)
    (hi : K[i]? = some (.constructor n)) (hn : as.length = n) :
    ProperApply (θ i) as (rawApply (θ i) as) := rawApply_proper (h i _ hi).1 hn

theorem rawApply_valueKind {P : Program} {K : KindCtx} {a : Ty} {n : Nat} {as : List Ty}
    (h : a.HasKind P K (.constructor n)) (hn : as.length = n) (hs : kindsList P K as) :
    (rawApply a as).HasKind P K .value := by
  have hp := rawApply_proper h hn
  cases hp with
  | «variable» i as => exact ⟨by simpa only [Ty.HasKind, ← hn] using h, hs⟩
  | list a | set a | reference a | lazy a => exact hs.1
  | map a b => exact ⟨hs.1, hs.2.1⟩
  | data d as => exact ⟨by simpa only [Ty.HasKind, ← hn] using h, hs⟩

end Benitoite.Release.Refinement
