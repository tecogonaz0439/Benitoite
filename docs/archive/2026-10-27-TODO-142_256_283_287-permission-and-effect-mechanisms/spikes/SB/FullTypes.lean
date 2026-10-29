import Std

/-! 試作 SB の型構成子を省かない版。
元: san_benito:formal/Benitoite/Release/Types.lean の全定義。
Ty.range を追加する。Atom と Integer の閉区間だけを手前へ写す。
Release の正規化・型置換・項・主定理は import しない。 -/
namespace SBFull

-- 元: formal/Benitoite/Release/Atom.lean, EffName, Atom。
abbrev EffName := String
inductive Atom where
  | name (l : EffName)
  | rho (i : Nat)
  deriving DecidableEq, Repr

abbrev min64 : Int := -9223372036854775808
abbrev max64 : Int := 9223372036854775807

-- 元: formal/Benitoite/Interval/Domain.lean, Interval, Mem, Subset, normalize。
-- Integer の一種類だけを写す。範囲の端点は項でなく数学上の Int の定数。
inductive Interval where
  | bottom
  | closed (lo hi : Int) (valid : min64 ≤ lo ∧ lo ≤ hi ∧ hi ≤ max64)
  deriving DecidableEq, Repr

def Mem (n : Int) : Interval → Prop
  | .bottom => False
  | .closed lo hi _ => lo ≤ n ∧ n ≤ hi

instance (n : Int) (i : Interval) : Decidable (Mem n i) := by
  cases i <;> unfold Mem <;> infer_instance

def Subset : Interval → Interval → Prop
  | .bottom, _ => True
  | .closed _ _ _, .bottom => False
  | .closed lo hi _, .closed lo' hi' _ => lo' ≤ lo ∧ hi ≤ hi'

instance (i j : Interval) : Decidable (Subset i j) := by
  cases i <;> cases j <;> unfold Subset <;> infer_instance

def interval (lo hi : Int) : Interval :=
  let l := max min64 lo
  let u := min max64 hi
  if h : l ≤ u then .closed l u ⟨Int.le_max_left _ _, h, Int.min_le_left _ _⟩
  else .bottom

theorem subset_iff (i j : Interval) :
    Subset i j ↔ ∀ n, Mem n i → Mem n j := by
  cases i with
  | bottom => simp [Subset, Mem]
  | closed lo hi valid =>
    cases j with
    | bottom =>
      simp only [Subset, Mem]
      constructor
      · intro h; contradiction
      · intro h; exact h lo ⟨Int.le_refl _, valid.2.1⟩
    | closed lo' hi' valid' =>
      simp only [Subset, Mem]
      constructor
      · intro h n hn; omega
      · intro h
        have hl := h lo ⟨Int.le_refl _, valid.2.1⟩
        have hh := h hi ⟨valid.2.1, Int.le_refl _⟩
        omega

theorem mem_bounds {n i} (h : Mem n i) : min64 ≤ n ∧ n ≤ max64 := by
  cases i with
  | bottom => exact h.elim
  | closed lo hi valid => simp only [Mem] at h; omega

/-- 基本型。01-12 の `ι`。既存の Integer・Float・Byte と幅付きの七種を区別する。 -/
inductive BaseTy where
  | integer | float | string | character | boolean | unit | byte | decimal
  | integer8 | integer16 | integer32
  | unsignedInteger16 | unsignedInteger32 | unsignedInteger64 | float32
  deriving DecidableEq, Repr

abbrev DataName := String
abbrev ConName := String
abbrev FunName := String
abbrev PrimName := String
abbrev OpName := String
/-- 中身を見せない型の名前（`IOError`・`NetworkError`・リソースの型など）。01-12 の `O`。 -/
abbrev OpaqueName := String
abbrev ClassName := String
abbrev ImplName := String
abbrev MethName := String

/-- 型構成子 φ（01-12「型クラス」の `τ ::= A | φ`）。型引数を与えずに書いた型構成子であり、高カインドの
型パラメータの型引数と、型構成子を引数にとる型クラスの辞書の型に現れる。高カインドの型パラメータそのものを
型構成子として書く形は、型の変数 `Ty.tvar` で表す。 -/
inductive TyCon where
  | data (d : DataName)
  | list
  | set
  | map
  | reference
  | lazy

mutual
/-- 型。01-12 の型に、初回リリース版の拡張が加える型を加えたもの。
`tvar i` は番号 i の型パラメータ。`cont b t ε` は継続の型 `Cont(B → T ! ε)`。`dict cl τ` は辞書の型
`Dict[Cl, τ]`、`tapp i Ā` は型構成子を表す型パラメータの適用 `α[Ā]`、`ctor φ` は型構成子 φ である。 -/
inductive Ty where
  | base (ι : BaseTy)
  | range (i : Interval)
  | opaque (o : OpaqueName)
  | data (d : DataName) (args : List Ty)
  | list (a : Ty)
  | fn (names : List String) (params : List Ty) (ret : Ty) (eff : EffR)
  | tvar (i : Nat)
  | reference (a : Ty)
  | lazy (a : Ty)
  | cont (b : Ty) (t : Ty) (eff : EffR)
  | map (k : Ty) (v : Ty)
  | set (a : Ty)
  | bytes
  | dict (cl : ClassName) (τ : Ty)
  | tapp (i : Nat) (args : List Ty)
  | ctor (φ : TyCon)


/-- 名前と行の所属、および Fail のエラー型の有限列。 -/
inductive EffR where
  | mk (atoms : Atom → Bool) (fails : List Ty)
end

abbrev Eff := EffR

namespace Eff

/-- 名前と行の所属関数。 -/
def atoms : Eff → Atom → Bool
  | .mk a _ => a

/-- Fail のエラー型の生の列。 -/
def fails : Eff → List Ty
  | .mk _ fs => fs

abbrev test (e : Eff) (a : Atom) : Bool := e.atoms a
abbrev mem (e : Eff) (a : Atom) : Prop := test e a = true
abbrev ofAtoms (a : Atom → Bool) : Eff := .mk a []

/-- 生の列も等しいことを確認して効果の等号を導く。 -/
theorem ext {e f : Eff} (ha : ∀ a, mem e a ↔ mem f a) (hf : e.fails = f.fails) : e = f := by
  cases e with
  | mk a fs =>
    cases f with
    | mk b gs =>
      have hab : a = b := funext (fun x => Bool.eq_iff_iff.mpr (ha x))
      cases hab; cases hf; rfl

theorem ext_test {e f : Eff} (ha : ∀ a, test e a = test f a) (hf : e.fails = f.fails) : e = f :=
  ext (fun a => Bool.eq_iff_iff.mp (ha a)) hf

end Eff

/-- 契約名は引数型と同じ個数であり、重複しない。
名前は宣言順に対応し、de Bruijn の局所変数とは区別する。 -/
def NamesWF (names : List String) (params : List Ty) : Prop :=
  names.length = params.length ∧ names.Nodup

-- Fail は型の構造の一致による所属を保つ。Fail の範囲共変は加えない。
def Eff.Sub (e f : Eff) : Prop :=
  (∀ a, mem e a → mem f a) ∧ (∀ t ∈ e.fails, t ∈ f.fails)

theorem Eff.Sub.refl (e : Eff) : Sub e e := ⟨fun _ h => h, fun _ h => h⟩
theorem Eff.Sub.trans {e f g} (h : Sub e f) (h' : Sub f g) : Sub e g :=
  ⟨fun a ha => h'.1 a (h.1 a ha), fun t ht => h'.2 t (h.2 t ht)⟩

-- 元: Release/Typing.lean, Ty.Le。ほかの構成子の引数は不変のまま。
mutual
  inductive Ty.Le : Ty → Ty → Prop where
    | refl (a) : Le a a
    | range {i j} : Subset i j → Le (.range i) (.range j)
    | forget (i) : Le (.range i) (.base .integer)
    | fn {names ps ps' r r' e e'} : Ty.Les ps' ps → Le r r' → Eff.Sub e e' →
        Le (.fn names ps r e) (.fn names ps' r' e')
    | trans {a b c} : Le a b → Le b c → Le a c
  inductive Ty.Les : List Ty → List Ty → Prop where
    | nil : Les [] []
    | cons {a b as bs} : Ty.Le a b → Les as bs → Les (a :: as) (b :: bs)
end

theorem Ty.Les.refl (as : List Ty) : Ty.Les as as := by
  induction as with
  | nil => exact .nil
  | cons a as ih => exact .cons (.refl _) ih

theorem Ty.Les.trans {as bs cs} (h : Ty.Les as bs) (h' : Ty.Les bs cs) :
    Ty.Les as cs := by
  match h, h' with
  | .nil, .nil => exact .nil
  | .cons ha hs, .cons hb ht => exact .cons (.trans ha hb) (hs.trans ht)

theorem Ty.Les.length_eq {as bs} (h : Ty.Les as bs) : as.length = bs.length := by
  match h with
  | .nil => rfl
  | .cons _ hs => exact congrArg Nat.succ hs.length_eq

-- 元: Release/Lemmas/Basic.lean, fn_left と fn_right。
theorem Ty.Le.fn_left {s t} (h : Ty.Le s t) :
    ∀ names ps r e, s = .fn names ps r e →
      ∃ ps' r' e', t = .fn names ps' r' e' ∧ Ty.Les ps' ps ∧
        Ty.Le r r' ∧ Eff.Sub e e' := by
  match h with
  | .refl _ =>
      intro names ps r e ht; cases ht
      exact ⟨ps, r, e, rfl, .refl _, .refl _, Eff.Sub.refl _⟩
  | .range _ => intro names ps r e ht; cases ht
  | .forget _ => intro names ps r e ht; cases ht
  | .fn hp hr he =>
      intro names ps r e ht; cases ht
      exact ⟨_, _, _, rfl, hp, hr, he⟩
  | .trans hab hbc =>
      intro names ps r e hs
      obtain ⟨ps', r', e', hb, hp, hr, he⟩ := hab.fn_left names ps r e hs
      obtain ⟨ps'', r'', e'', hc, hp', hr', he'⟩ := hbc.fn_left names ps' r' e' hb
      exact ⟨ps'', r'', e'', hc, hp'.trans hp, .trans hr hr', he.trans he'⟩

theorem Ty.Le.fn_right {s t} (h : Ty.Le s t) :
    ∀ names ps r e, t = .fn names ps r e →
      ∃ ps' r' e', s = .fn names ps' r' e' ∧ Ty.Les ps ps' ∧
        Ty.Le r' r ∧ Eff.Sub e' e := by
  match h with
  | .refl _ =>
      intro names ps r e ht; cases ht
      exact ⟨ps, r, e, rfl, .refl _, .refl _, Eff.Sub.refl _⟩
  | .range _ => intro names ps r e ht; cases ht
  | .forget _ => intro names ps r e ht; cases ht
  | .fn hp hr he =>
      intro names ps r e ht; cases ht
      exact ⟨_, _, _, rfl, hp, hr, he⟩
  | .trans hab hbc =>
      intro names ps r e ht
      obtain ⟨ps', r', e', hb, hp, hr, he⟩ := hbc.fn_right names ps r e ht
      obtain ⟨ps'', r'', e'', hs, hp', hr', he'⟩ := hab.fn_right names ps' r' e' hb
      exact ⟨ps'', r'', e'', hs, hp.trans hp', .trans hr' hr, he'.trans he⟩

-- 元: Release/Lemmas/Preservation.lean, Ty.Le.fn_fn'。
theorem Ty.Le.fn_fn {names ps r e names' ps' r' e'}
    (h : Ty.Le (.fn names ps r e) (.fn names' ps' r' e')) :
    names = names' ∧ Ty.Les ps' ps ∧ Ty.Le r r' ∧ Eff.Sub e e' := by
  obtain ⟨ps'', r'', e'', heq, hp, hr, he⟩ := h.fn_left names ps r e rfl
  cases heq
  exact ⟨rfl, hp, hr, he⟩

def Ty.Rigid : Ty → Prop
  | .base .integer | .range _ | .fn .. => False
  | _ => True

theorem Ty.Le.eq_of_rigid_right {a b} (h : Ty.Le a b) (hb : b.Rigid) : a = b := by
  match h with
  | .refl _ => rfl
  | .range _ => exact hb.elim
  | .forget _ => exact hb.elim
  | .fn _ _ _ => exact hb.elim
  | .trans hab hbc =>
      have heq := hbc.eq_of_rigid_right hb
      exact (hab.eq_of_rigid_right (heq.symm ▸ hb)).trans heq

theorem Ty.Le.eq_of_rigid_left {a b} (h : Ty.Le a b) (ha : a.Rigid) : a = b := by
  match h with
  | .refl _ => rfl
  | .range _ => exact ha.elim
  | .forget _ => exact ha.elim
  | .fn _ _ _ => exact ha.elim
  | .trans hab hbc =>
      have heq := hab.eq_of_rigid_left ha
      exact heq.trans (hbc.eq_of_rigid_left (heq ▸ ha))

-- 型が変わる関数でも、実行に要る引数の個数と契約名は保つ。
theorem fn_arity_preserved {names ps r e names' ps' r' e'}
    (h : Ty.Le (.fn names ps r e) (.fn names' ps' r' e')) :
    names = names' ∧ ps.length = ps'.length := by
  obtain ⟨hn, hp, _, _⟩ := h.fn_fn
  exact ⟨hn, hp.length_eq.symm⟩

-- 元: Release/Typing.lean, HasTypeVsQ と C_App。
-- 値自体は自然数の識別子に縮小し、変数環境からの型付けだけを用意する。
inductive HasTypeV (env : Nat → Ty) : Nat → Ty → Prop where
  | var (v) : HasTypeV env v (env v)
  | sub {v a b} : HasTypeV env v a → Ty.Le a b → HasTypeV env v b

inductive HasTypeVs (env : Nat → Ty) : List Nat → List Ty → Prop where
  | nil : HasTypeVs env [] []
  | cons {v vs a as} : HasTypeV env v a → HasTypeVs env vs as →
      HasTypeVs env (v :: vs) (a :: as)

theorem HasTypeVs.sub {env vs as bs} (h : HasTypeVs env vs as) (hl : Ty.Les as bs) :
    HasTypeVs env vs bs := by
  match h, hl with
  | .nil, .nil => exact .nil
  | .cons hv hs, .cons ha ht => exact .cons (.sub hv ha) (hs.sub ht)

inductive HasTypeApp (env : Nat → Ty) : Nat → List Nat → Ty → Eff → Prop where
  | app {f args names ps r e} : HasTypeV env f (.fn names ps r e) →
      HasTypeVs env args ps → HasTypeApp env f args r e

theorem call_with_subtypes {env f args names ps actual r e}
    (hf : HasTypeV env f (.fn names ps r e)) (ha : HasTypeVs env args actual)
    (hl : Ty.Les actual ps) : HasTypeApp env f args r e := .app hf (ha.sub hl)

theorem arguments_for_native_contract {env args names ps r e names' ps' r' e'}
    (h : Ty.Le (.fn names ps r e) (.fn names' ps' r' e'))
    (ha : HasTypeVs env args ps') : HasTypeVs env args ps := ha.sub h.fn_fn.2.1

-- Reference と Fail の型には範囲の共変を足していない。
theorem reference_stays_invariant {a b} (h : Ty.Le (.reference a) (.reference b)) :
    a = b := by
  have heq := h.eq_of_rigid_right (by trivial)
  cases heq
  rfl

theorem function_name_and_arity_example :
    Ty.Le
      (.fn ["port", "value"] [.base .integer, .base .integer]
        (.range (interval 1 1)) (.mk (fun _ => false) []))
      (.fn ["port", "value"] [.range (interval 1 65535), .range (interval 0 9)]
        (.base .integer) (.mk (fun _ => false) [])) :=
  .fn (.cons (.forget _) (.cons (.forget _) .nil)) (.forget _) (Eff.Sub.refl _)

-- 元: Release/Typing.lean, Ty.WF/Ty.WFList/Eff.WF。
-- Eff.Canonical だけを省いたもの。失敗型のスコープの反例を切り分ける。
mutual
  def Ty.ScopeWF (n : Nat) : Ty → Prop
    | .base _ | .range _ | .opaque _ | .bytes | .ctor _ => True
    | .tvar i => i < n
    | .data _ args => Ty.ScopeWFList n args
    | .list a | .reference a | .lazy a | .set a | .dict _ a => a.ScopeWF n
    | .fn names ps r e => NamesWF names ps ∧ Ty.ScopeWFList n ps ∧ r.ScopeWF n ∧ Eff.ScopeWF n e
    | .cont b t e => b.ScopeWF n ∧ t.ScopeWF n ∧ Eff.ScopeWF n e
    | .map a b => a.ScopeWF n ∧ b.ScopeWF n
    | .tapp i args => i < n ∧ Ty.ScopeWFList n args
  def Ty.ScopeWFList (n : Nat) : List Ty → Prop
    | [] => True
    | a :: as => a.ScopeWF n ∧ Ty.ScopeWFList n as
  def Eff.ScopeWF (n : Nat) : Eff → Prop
    | .mk _ fs => Ty.ScopeWFList n fs
end

def Ty.LatentScopeWF (n : Nat) : Ty → Prop
  | .fn _ _ _ e => Eff.ScopeWF n e
  | _ => True

def emptyEff : Eff := .mk (fun _ => false) []
def openFailure : Eff := .mk (fun _ => false) [.tvar 0]
def pureInner : Ty := .fn ["x"] [.base .integer] (.base .integer) emptyEff
def badInner : Ty := .fn ["x"] [.base .integer] (.base .integer) openFailure

theorem nested_failure_widening : Ty.Le pureInner badInner := by
  apply Ty.Le.fn (.refl _) (.refl _)
  simp [Eff.Sub, emptyEff, openFailure, Eff.mem, Eff.test, Eff.atoms, Eff.fails]

theorem outer_latent_scope_is_insufficient :
    ∃ a b, Ty.Le a b ∧ a.ScopeWF 0 ∧ b.LatentScopeWF 0 ∧ ¬ b.ScopeWF 0 := by
  refine ⟨.fn ["outer"] [.base .integer] pureInner emptyEff,
    .fn ["outer"] [.base .integer] badInner emptyEff,
    .fn (.refl _) nested_failure_widening (Eff.Sub.refl _), ?_, ?_, ?_⟩
  all_goals simp [Ty.ScopeWF, Ty.ScopeWFList, Eff.ScopeWF, Ty.LatentScopeWF,
    NamesWF, pureInner, badInner, emptyEff, openFailure]

theorem outer_latent_scope_rev_is_insufficient :
    ∃ a b, Ty.Le a b ∧ b.ScopeWF 0 ∧ a.LatentScopeWF 0 ∧ ¬ a.ScopeWF 0 := by
  refine ⟨.fn ["outer"] [badInner] (.base .integer) emptyEff,
    .fn ["outer"] [pureInner] (.base .integer) emptyEff,
    .fn (.cons nested_failure_widening .nil) (.refl _) (Eff.Sub.refl _), ?_, ?_, ?_⟩
  all_goals simp [Ty.ScopeWF, Ty.ScopeWFList, Eff.ScopeWF, Ty.LatentScopeWF,
    NamesWF, pureInner, badInner, emptyEff, openFailure]


-- 全定理の公理監査。
#print axioms SBFull.subset_iff
#print axioms SBFull.mem_bounds
#print axioms SBFull.Eff.ext
#print axioms SBFull.Eff.ext_test
#print axioms SBFull.Eff.Sub.refl
#print axioms SBFull.Eff.Sub.trans
#print axioms SBFull.Ty.Les.refl
#print axioms SBFull.Ty.Les.trans
#print axioms SBFull.Ty.Les.length_eq
#print axioms SBFull.Ty.Le.fn_left
#print axioms SBFull.Ty.Le.fn_right
#print axioms SBFull.Ty.Le.fn_fn
#print axioms SBFull.Ty.Le.eq_of_rigid_right
#print axioms SBFull.Ty.Le.eq_of_rigid_left
#print axioms SBFull.fn_arity_preserved
#print axioms SBFull.HasTypeVs.sub
#print axioms SBFull.call_with_subtypes
#print axioms SBFull.arguments_for_native_contract
#print axioms SBFull.reference_stays_invariant
#print axioms SBFull.function_name_and_arity_example
#print axioms SBFull.nested_failure_widening
#print axioms SBFull.outer_latent_scope_is_insufficient
#print axioms SBFull.outer_latent_scope_rev_is_insufficient

end SBFull

