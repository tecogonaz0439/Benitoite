import Std

/-!
捨てる試作 SB。san_benito の Release を import しない。
写した定義は名前を下に記す。型は一引数の関数、Integer、Boolean、
不透明型、型変数、不変の List/Reference に縮小する。
効果は自然数の有限列の所属だけで模し、Fail と行変数は扱わない。
-/
namespace SB

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

abbrev Eff := List Nat
def Eff.Sub (e f : Eff) : Prop := ∀ n, n ∈ e → n ∈ f
theorem Eff.Sub.refl (e : Eff) : Eff.Sub e e := fun _ h => h
theorem Eff.Sub.trans {e f g} (h : Eff.Sub e f) (h' : Eff.Sub f g) :
    Eff.Sub e g := fun n hn => h' n (h n hn)

-- 元: formal/Benitoite/Release/Types.lean, Ty。
-- fn の契約名と引数は一個に縮小。list/reference の要素は不変のまま。
inductive Ty where
  | integer | boolean
  | opaque (name : String)
  | tvar (i : Nat)
  | list (a : Ty)
  | reference (a : Ty)
  | range (i : Interval)
  | fn (name : String) (param ret : Ty) (eff : Eff)
  deriving DecidableEq, Repr

-- 元: Release/Typing.lean, Ty.Le。関数の反変・共変を加える。
inductive Ty.Le : Ty → Ty → Prop where
  | refl (a) : Le a a
  | range {i j} : Subset i j → Le (.range i) (.range j)
  | forget (i) : Le (.range i) .integer
  | fn {name a a' r r' e e'} : Le a' a → Le r r' → Eff.Sub e e' →
      Le (.fn name a r e) (.fn name a' r' e')
  | trans {a b c} : Le a b → Le b c → Le a c

-- 元: Release の Ty.substAt / Ty.shift の型部分。型変数の全置換へ縮小。
def Ty.substType (s : Nat → Ty) : Ty → Ty
  | .tvar i => s i
  | .list a => .list (a.substType s)
  | .reference a => .reference (a.substType s)
  | .fn n a r e => .fn n (a.substType s) (r.substType s) e
  | t => t

theorem Ty.Le.substType {a b} (h : Ty.Le a b) (s : Nat → Ty) :
    Ty.Le (a.substType s) (b.substType s) := by
  induction h with
  | refl a => exact .refl _
  | range h => exact .range h
  | forget i => exact .forget i
  | fn hin hout he ihin ihout => exact .fn ihin ihout he
  | trans h h' ih ih' => exact .trans ih ih'

theorem interval_type_substitution (s : Nat → Ty) (i : Interval) :
    (Ty.range i).substType s = .range i := rfl

-- fn_left / fn_right / fn_fn' の置き換えの言明。
theorem Ty.Le.fn_left {s t} (h : Ty.Le s t) :
    ∀ n a r e, s = .fn n a r e →
      ∃ a' r' e', t = .fn n a' r' e' ∧ Ty.Le a' a ∧ Ty.Le r r' ∧ Eff.Sub e e' := by
  induction h with
  | refl t =>
      intro n a r e ht; subst t
      exact ⟨a, r, e, rfl, .refl _, .refl _, Eff.Sub.refl _⟩
  | range hi => intro n a r e ht; cases ht
  | forget i => intro n a r e ht; cases ht
  | fn hin hout he ihin ihout =>
      intro n a r e ht; cases ht
      exact ⟨_, _, _, rfl, hin, hout, he⟩
  | trans hab hbc ihab ihbc =>
      intro n a r e hs
      obtain ⟨a', r', e', hb, ha, hr, he⟩ := ihab n a r e hs
      obtain ⟨a'', r'', e'', hc, ha', hr', he'⟩ := ihbc n a' r' e' hb
      exact ⟨a'', r'', e'', hc, .trans ha' ha, .trans hr hr', he.trans he'⟩

theorem Ty.Le.fn_fn {n a r e n' a' r' e'}
    (h : Ty.Le (.fn n a r e) (.fn n' a' r' e')) :
    n = n' ∧ Ty.Le a' a ∧ Ty.Le r r' ∧ Eff.Sub e e' := by
  obtain ⟨a'', r'', e'', heq, ha, hr, he⟩ := h.fn_left n a r e rfl
  cases heq
  exact ⟨rfl, ha, hr, he⟩

theorem Ty.Le.fn_right {s t} (h : Ty.Le s t) :
    ∀ n a r e, t = .fn n a r e →
      ∃ a' r' e', s = .fn n a' r' e' ∧ Ty.Le a a' ∧ Ty.Le r' r ∧ Eff.Sub e' e := by
  induction h with
  | refl s =>
      intro n a r e ht; subst s
      exact ⟨a, r, e, rfl, .refl _, .refl _, Eff.Sub.refl _⟩
  | range hi => intro n a r e ht; cases ht
  | forget i => intro n a r e ht; cases ht
  | fn hin hout he ihin ihout =>
      intro n a r e ht; cases ht
      exact ⟨_, _, _, rfl, hin, hout, he⟩
  | trans hab hbc ihab ihbc =>
      intro n a r e ht
      obtain ⟨a', r', e', hb, ha, hr, he⟩ := ihbc n a r e ht
      obtain ⟨a'', r'', e'', hs, ha', hr', he'⟩ := ihab n a' r' e' hb
      exact ⟨a'', r'', e'', hs, .trans ha ha', .trans hr' hr, he'.trans he⟩

-- 元: Release/TypeRegularity.lean, Ty.Le.wf/wf_rev の前提の限界。
-- この節だけ効果の自然数を Fail 内の型変数の番号として読む縮小モデル。
-- 本番の Eff.WF は行変数を検査しないため、行番号の反例とは解釈しない。
def Ty.WF (count : Nat) : Ty → Prop
  | .tvar i => i < count
  | .list a | .reference a => a.WF count
  | .fn _ a r e => a.WF count ∧ r.WF count ∧ ∀ i ∈ e, i < count
  | _ => True

def Ty.LatentWF (count : Nat) : Ty → Prop
  | .fn _ _ _ e => ∀ i ∈ e, i < count
  | _ => True

def pureFn : Ty := .fn "x" .integer .integer []
def unscopedFn : Ty := .fn "x" .integer .integer [0]

theorem pure_to_unscoped : Ty.Le pureFn unscopedFn := by
  exact .fn (.refl _) (.refl _) (by intro i hi; cases hi)

theorem outer_latent_wf_is_insufficient :
    ∃ a b, Ty.Le a b ∧ a.WF 0 ∧ b.LatentWF 0 ∧ ¬ b.WF 0 := by
  refine ⟨.fn "outer" .integer pureFn [], .fn "outer" .integer unscopedFn [],
    .fn (.refl _) pure_to_unscoped (Eff.Sub.refl _), ?_, ?_, ?_⟩
  all_goals simp [Ty.WF, Ty.LatentWF, pureFn, unscopedFn]

theorem outer_latent_wf_rev_is_insufficient :
    ∃ a b, Ty.Le a b ∧ b.WF 0 ∧ a.LatentWF 0 ∧ ¬ a.WF 0 := by
  refine ⟨.fn "outer" unscopedFn .integer [], .fn "outer" pureFn .integer [],
    .fn pure_to_unscoped (.refl _) (Eff.Sub.refl _), ?_, ?_, ?_⟩
  all_goals simp [Ty.WF, Ty.LatentWF, pureFn, unscopedFn]

-- 非関数だけでは等号に戻せない。Integer/区間も除いた型の言明は保てる。
def Ty.Rigid : Ty → Prop
  | .integer | .range _ | .fn .. => False
  | _ => True

theorem Ty.Le.eq_of_rigid_right {a b} (h : Ty.Le a b) (hb : b.Rigid) : a = b := by
  induction h with
  | refl _ => rfl
  | range _ => exact hb.elim
  | forget _ => exact hb.elim
  | fn _ _ _ _ _ => exact hb.elim
  | trans h h' ih ih' =>
      have he := ih' hb
      cases he
      exact ih hb

theorem Ty.Le.eq_of_rigid_left {a b} (h : Ty.Le a b) (ha : a.Rigid) : a = b := by
  induction h with
  | refl _ => rfl
  | range _ => exact ha.elim
  | forget _ => exact ha.elim
  | fn _ _ _ _ _ => exact ha.elim
  | trans h h' ih ih' =>
      have he := ih ha
      cases he
      exact ih' ha

theorem nonfunction_subtyping_not_equality :
    Ty.Le (.range (interval 1 65535)) .integer ∧
    Ty.range (interval 1 65535) ≠ Ty.integer :=
  ⟨.forget _, by intro h; cases h⟩

theorem function_parts_not_equal :
    Ty.Le (.fn "x" .integer (.range (interval 1 1)) [])
      (.fn "x" (.range (interval 1 65535)) .integer []) ∧
    Ty.integer ≠ Ty.range (interval 1 65535) ∧
    Ty.range (interval 1 1) ≠ Ty.integer := by
  exact ⟨.fn (.forget _) (.forget _) (Eff.Sub.refl _),
    (by intro h; cases h), (by intro h; cases h)⟩

-- 試作 022 Intervals.lean の反例を閉区間で再検査する。
theorem narrowing_is_not_subsumption :
    ¬ (∀ n, Mem n (interval 0 9) → Mem n (interval 0 4)) := by
  intro h
  have h7 := h 7 (by decide)
  have hn : ¬ Mem 7 (interval 0 4) := by decide
  exact hn h7

def partialIdentity (n : Int) : Int := if n ≤ 4 then n else 100
def FunctionContract (i j : Interval) (f : Int → Int) : Prop :=
  ∀ n, Mem n i → Mem (f n) j

theorem covariance_counterexample :
    FunctionContract (interval 0 4) (interval 0 4) partialIdentity ∧
    ¬ FunctionContract (interval 0 9) (interval 0 4) partialIdentity := by
  constructor
  · intro n hn
    change 0 ≤ n ∧ n ≤ 4 at hn
    change 0 ≤ partialIdentity n ∧ partialIdentity n ≤ 4
    simpa [partialIdentity, hn.2] using hn
  · intro h
    have h7 := h 7 (by decide)
    have hn : ¬ Mem (partialIdentity 7) (interval 0 4) := by decide
    exact hn h7

theorem function_subtyping_sound {a a' r r' : Interval} {f : Int → Int}
    (ha : Subset a' a) (hr : Subset r r') (hf : FunctionContract a r f) :
    FunctionContract a' r' f := by
  intro n hn
  exact (subset_iff _ _).mp hr _ (hf n ((subset_iff _ _).mp ha _ hn))

-- 整数値についての意味。狭める規則を追加していないことも確認する。
def IntSatisfies (n : Int) : Ty → Prop
  | .integer => min64 ≤ n ∧ n ≤ max64
  | .range i => Mem n i
  | _ => False

theorem Ty.Le.integer_sound {a b} (h : Ty.Le a b) (n : Int)
    (hn : IntSatisfies n a) : IntSatisfies n b := by
  induction h with
  | refl _ => exact hn
  | range hi => exact (subset_iff _ _).mp hi _ hn
  | forget _ => exact mem_bounds hn
  | fn _ _ _ _ _ => exact hn.elim
  | trans h h' ih ih' => exact ih' (ih hn)

-- 元: Release/Syntax.lean の Val/Comp、Release/Subst.lean の rename/subst。
mutual
  inductive Val where
    | var (i : Nat)
    | int (n : Int)
    | lam (name : String) (param : Ty) (body : Comp)
    deriving Repr
  inductive Comp where
    | ret (v : Val)
    | app (f arg : Val)
    | letIn (value body : Comp)
    deriving Repr
end

def upRen (s : Nat → Nat) : Nat → Nat
  | 0 => 0
  | i + 1 => s i + 1

mutual
  def Val.rename (s : Nat → Nat) : Val → Val
    | .var i => .var (s i)
    | .int n => .int n
    | .lam n a body => .lam n a (body.rename (upRen s))
  def Comp.rename (s : Nat → Nat) : Comp → Comp
    | .ret v => .ret (v.rename s)
    | .app f v => .app (f.rename s) (v.rename s)
    | .letIn m n => .letIn (m.rename s) (n.rename (upRen s))
end

def upSubst (s : Nat → Val) : Nat → Val
  | 0 => .var 0
  | i + 1 => (s i).rename Nat.succ

mutual
  def Val.subst (s : Nat → Val) : Val → Val
    | .var i => s i
    | .int n => .int n
    | .lam n a body => .lam n a (body.subst (upSubst s))
  def Comp.subst (s : Nat → Val) : Comp → Comp
    | .ret v => .ret (v.subst s)
    | .app f v => .app (f.subst s) (v.subst s)
    | .letIn m n => .letIn (m.subst s) (n.subst (upSubst s))
end

-- 元: Release/Typing.lean, V_Var/V_Const/V_Lam/V_Sub,
-- C_Return/C_App/C_Let/C_Sub。区間の導入を intRange に分ける。
mutual
  inductive HasTypeV : List Ty → Val → Ty → Prop
    | var {g i a} : g[i]? = some a → HasTypeV g (.var i) a
    | int {g n} : min64 ≤ n ∧ n ≤ max64 → HasTypeV g (.int n) .integer
    | intRange {g n i} : Mem n i → HasTypeV g (.int n) (.range i)
    | lam {g n a body r e} : HasTypeC (a :: g) body r e →
        HasTypeV g (.lam n a body) (.fn n a r e)
    | sub {g v a b} : HasTypeV g v a → Ty.Le a b → HasTypeV g v b
  inductive HasTypeC : List Ty → Comp → Ty → Eff → Prop
    | ret {g v a} : HasTypeV g v a → HasTypeC g (.ret v) a []
    | app {g f v n a r e} : HasTypeV g f (.fn n a r e) → HasTypeV g v a →
        HasTypeC g (.app f v) r e
    | letIn {g m n a b e} : HasTypeC g m a e → HasTypeC (a :: g) n b e →
        HasTypeC g (.letIn m n) b e
    | sub {g m a b e e'} : HasTypeC g m a e → Ty.Le a b → Eff.Sub e e' →
        HasTypeC g m b e'
end

def RenOk (g d : List Ty) (s : Nat → Nat) : Prop :=
  ∀ i a, g[i]? = some a → d[s i]? = some a

theorem RenOk.up {g d s} (h : RenOk g d s) (a : Ty) :
    RenOk (a :: g) (a :: d) (upRen s) := by
  intro i b hi
  cases i with
  | zero => simpa [upRen] using hi
  | succ i => exact h i b hi

mutual
  theorem HasTypeV.rename {g v a} (h : HasTypeV g v a)
      {d s} (hs : RenOk g d s) : HasTypeV d (v.rename s) a := by
    match h with
    | .var hi => exact .var (hs _ _ hi)
    | .int hn => exact .int hn
    | .intRange hn => exact .intRange hn
    | .lam hb => exact .lam (HasTypeC.rename hb (hs.up _))
    | .sub hv hl => exact .sub (HasTypeV.rename hv hs) hl
  theorem HasTypeC.rename {g m a e} (h : HasTypeC g m a e)
      {d s} (hs : RenOk g d s) : HasTypeC d (m.rename s) a e := by
    match h with
    | .ret hv => exact .ret (HasTypeV.rename hv hs)
    | .app hf hv => exact .app (HasTypeV.rename hf hs) (HasTypeV.rename hv hs)
    | .letIn hm hn => exact .letIn (HasTypeC.rename hm hs) (HasTypeC.rename hn (hs.up _))
    | .sub hm hl he => exact .sub (HasTypeC.rename hm hs) hl he
end

-- 元: Release/Lemmas/SubstTyping.lean, SubstOk, HasTypeVQ.subst, HasTypeCQ.subst。
-- 通常値だけのモデルなので、同じ型を持つ開いた値への置換まで許す。
def SubstOk (g d : List Ty) (s : Nat → Val) : Prop :=
  ∀ i a, g[i]? = some a → HasTypeV d (s i) a

theorem SubstOk.up {g d s} (hs : SubstOk g d s) (a : Ty) :
    SubstOk (a :: g) (a :: d) (upSubst s) := by
  intro i b hi
  cases i with
  | zero =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at hi
      cases hi
      exact .var rfl
  | succ i =>
      exact (hs i b hi).rename (fun j t hj => hj)

mutual
  theorem HasTypeV.subst {g v a} (h : HasTypeV g v a)
      {d s} (hs : SubstOk g d s) : HasTypeV d (v.subst s) a := by
    match h with
    | .var hi => exact hs _ _ hi
    | .int hn => exact .int hn
    | .intRange hn => exact .intRange hn
    | .lam hb => exact .lam (HasTypeC.subst hb (hs.up _))
    | .sub hv hl => exact .sub (HasTypeV.subst hv hs) hl
  theorem HasTypeC.subst {g m a e} (h : HasTypeC g m a e)
      {d s} (hs : SubstOk g d s) : HasTypeC d (m.subst s) a e := by
    match h with
    | .ret hv => exact .ret (HasTypeV.subst hv hs)
    | .app hf hv => exact .app (HasTypeV.subst hf hs) (HasTypeV.subst hv hs)
    | .letIn hm hn => exact .letIn (HasTypeC.subst hm hs) (HasTypeC.subst hn (hs.up _))
    | .sub hm hl he => exact .sub (HasTypeC.subst hm hs) hl he
end

def singleSubst (v : Val) : Nat → Val
  | 0 => v
  | i + 1 => .var i

theorem singleSubst_ok {g a v} (hv : HasTypeV g v a) :
    SubstOk (a :: g) g (singleSubst v) := by
  intro i b hi
  cases i with
  | zero =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at hi
      cases hi; exact hv
  | succ i => exact .var hi

theorem value_substitution {g a v w b}
    (hw : HasTypeV (a :: g) w b) (hv : HasTypeV g v a) :
    HasTypeV g (w.subst (singleSubst v)) b := hw.subst (singleSubst_ok hv)

theorem body_substitution {g a v m b e}
    (hm : HasTypeC (a :: g) m b e) (hv : HasTypeV g v a) :
    HasTypeC g (m.subst (singleSubst v)) b e := hm.subst (singleSubst_ok hv)

theorem call_with_subtype {g f v n a a' r e}
    (hf : HasTypeV g f (.fn n a r e)) (hv : HasTypeV g v a') (ha : Ty.Le a' a) :
    HasTypeC g (.app f v) r e := .app hf (.sub hv ha)

theorem beta_contract {g n a m r e v a'}
    (hm : HasTypeC (a :: g) m r e) (hv : HasTypeV g v a') (ha : Ty.Le a' a) :
    HasTypeC g (.app (.lam n a m) v) r e ∧
    HasTypeC g (m.subst (singleSubst v)) r e :=
  ⟨call_with_subtype (.lam hm) hv ha, body_substitution hm (.sub hv ha)⟩

-- ラムダ値を部分型で広げた場合も、実際の本体の型を取り出せる。
theorem HasTypeV.inv_lam {g v t} (h : HasTypeV g v t) {n a body}
    (hv : v = .lam n a body) :
    ∃ r e, HasTypeC (a :: g) body r e ∧ Ty.Le (.fn n a r e) t := by
  match h with
  | .var _ => cases hv
  | .int _ => cases hv
  | .intRange _ => cases hv
  | .lam hb => cases hv; exact ⟨_, _, hb, .refl _⟩
  | .sub h hl =>
      obtain ⟨r, e, hb, hle⟩ := h.inv_lam hv
      exact ⟨r, e, hb, .trans hle hl⟩

theorem HasTypeC.inv_app {g m t e} (h : HasTypeC g m t e) {f v}
    (hm : m = .app f v) :
    ∃ n a r e', HasTypeV g f (.fn n a r e') ∧ HasTypeV g v a ∧
      Ty.Le r t ∧ Eff.Sub e' e := by
  match h with
  | .ret _ => cases hm
  | .letIn _ _ => cases hm
  | .app hf hv => cases hm; exact ⟨_, _, _, _, hf, hv, .refl _, Eff.Sub.refl _⟩
  | .sub h hl he =>
      obtain ⟨n, a, r, e', hf, hv, hle, hsub⟩ := h.inv_app hm
      exact ⟨n, a, r, e', hf, hv, .trans hle hl, hsub.trans he⟩

-- fn_fn の等号を「引数は反変、結果は共変」に置き換える保存の要所。
theorem beta_preservation {g n a body v r e}
    (h : HasTypeC g (.app (.lam n a body) v) r e) :
    HasTypeC g (body.subst (singleSubst v)) r e := by
  obtain ⟨n', a', r', e', hf, hv, hr, he⟩ := h.inv_app rfl
  obtain ⟨r0, e0, hb, hfn⟩ := hf.inv_lam rfl
  obtain ⟨_, ha, hr0, he0⟩ := hfn.fn_fn
  exact .sub (body_substitution hb (.sub hv ha)) (.trans hr0 hr) (he0.trans he)

theorem HasTypeV.int_sound {g v t} (h : HasTypeV g v t) {n}
    (hv : v = .int n) : IntSatisfies n t := by
  match h with
  | .var _ => cases hv
  | .int hn => cases hv; exact hn
  | .intRange hn => cases hv; exact hn
  | .lam _ => cases hv
  | .sub h hl => exact hl.integer_sound n (h.int_sound hv)

-- 区間から Integer へは無検査で同じ整数値を使える。
theorem range_as_integer {g v i} (h : HasTypeV g v (.range i)) :
    HasTypeV g v .integer := .sub h (.forget i)

-- 元: 試作 022/Contracts.lean の rawMake。成功時も同じ整数を返す。
def rawMake (i : Interval) (n : Int) : Option Int :=
  if Mem n i then some n else none

theorem rawMake_success {i n out} (h : rawMake i n = some out) :
    out = n ∧ Mem out i := by
  unfold rawMake at h
  split at h
  · cases h; exact ⟨rfl, ‹Mem n i›⟩
  · cases h

theorem rawMake_none_iff (i : Interval) (n : Int) :
    rawMake i n = none ↔ ¬ Mem n i := by simp [rawMake]

theorem checked_integer_to_range {g i n out} (h : rawMake i n = some out) :
    HasTypeV g (.int out) (.range i) := .intRange (rawMake_success h).2

theorem integer_to_range_requires_evidence :
    HasTypeV [] (.int 0) .integer ∧ rawMake (interval 1 65535) 0 = none :=
  ⟨.int (by decide), by decide⟩

theorem cannot_assign_outside_integer :
    ¬ HasTypeV [] (.int 0) (.range (interval 1 65535)) := by
  intro h
  have hn := h.int_sound rfl
  have hno : ¬ Mem 0 (interval 1 65535) := by decide
  exact hno hn

theorem no_unchecked_integer_narrowing :
    ¬ Ty.Le .integer (.range (interval 1 65535)) := by
  intro h
  have hn := h.integer_sound 0 (by change min64 ≤ (0 : Int) ∧ 0 ≤ max64; decide)
  have hno : ¬ Mem 0 (interval 1 65535) := by decide
  exact hno hn

-- 閉区間の両端、狭い区間の引数、入れ子のラムダで捕獲しないこと。
#guard Mem 1 (interval 1 65535)
#guard Mem 65535 (interval 1 65535)
#guard !(decide (Mem 65536 (interval 1 65535)))
#guard Subset .bottom (interval 1 65535)
#guard rawMake (interval 1 65535) 65535 == some 65535
#guard rawMake (interval 1 65535) 65536 == none

theorem port_identity_call :
    HasTypeC [] (.app (.lam "port" (.range (interval 1 65535)) (.ret (.var 0)))
      (.int 5432)) (.range (interval 1 65535)) [] := by
  apply call_with_subtype (.lam (.ret (.var rfl)))
    (HasTypeV.intRange (i := interval 5432 5432) (by decide))
  exact .range (by decide)

theorem substitution_under_lambda :
    HasTypeV []
      ((Val.lam "port" (.range (interval 1 65535)) (.ret (.var 1))).subst
        (singleSubst (.int 5432)))
      (.fn "port" (.range (interval 1 65535)) (.range (interval 5432 5432)) []) := by
  apply value_substitution
  · exact .lam (.ret (.var rfl))
  · exact .intRange (by decide)


-- 全定理の公理監査。
#print axioms SB.subset_iff
#print axioms SB.mem_bounds
#print axioms SB.Eff.Sub.refl
#print axioms SB.Eff.Sub.trans
#print axioms SB.Ty.Le.substType
#print axioms SB.interval_type_substitution
#print axioms SB.Ty.Le.fn_left
#print axioms SB.Ty.Le.fn_fn
#print axioms SB.Ty.Le.fn_right
#print axioms SB.pure_to_unscoped
#print axioms SB.outer_latent_wf_is_insufficient
#print axioms SB.outer_latent_wf_rev_is_insufficient
#print axioms SB.Ty.Le.eq_of_rigid_right
#print axioms SB.Ty.Le.eq_of_rigid_left
#print axioms SB.nonfunction_subtyping_not_equality
#print axioms SB.function_parts_not_equal
#print axioms SB.narrowing_is_not_subsumption
#print axioms SB.covariance_counterexample
#print axioms SB.function_subtyping_sound
#print axioms SB.Ty.Le.integer_sound
#print axioms SB.RenOk.up
#print axioms SB.HasTypeV.rename
#print axioms SB.HasTypeC.rename
#print axioms SB.SubstOk.up
#print axioms SB.HasTypeV.subst
#print axioms SB.HasTypeC.subst
#print axioms SB.singleSubst_ok
#print axioms SB.value_substitution
#print axioms SB.body_substitution
#print axioms SB.call_with_subtype
#print axioms SB.beta_contract
#print axioms SB.HasTypeV.inv_lam
#print axioms SB.HasTypeC.inv_app
#print axioms SB.beta_preservation
#print axioms SB.HasTypeV.int_sound
#print axioms SB.range_as_integer
#print axioms SB.rawMake_success
#print axioms SB.rawMake_none_iff
#print axioms SB.checked_integer_to_range
#print axioms SB.integer_to_range_requires_evidence
#print axioms SB.cannot_assign_outside_integer
#print axioms SB.no_unchecked_integer_narrowing
#print axioms SB.port_identity_call
#print axioms SB.substitution_under_lambda

end SB
