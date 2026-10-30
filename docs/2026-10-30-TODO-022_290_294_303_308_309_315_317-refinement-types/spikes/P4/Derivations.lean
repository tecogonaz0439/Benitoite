import Context

/- P3b-Derivations.lean:145-230,700-934 の相互帰納を、
   Nat の値変数と構文の Φ/Entails に書き直した独立の写し。
   native は閉じた本番 Ty の埋め込み。開いた型/行/範囲/値の像は別の名前空間で持つ。
   data の全変性や正規化後の等号の規則は本番に残す。 -/
namespace P4.Derivation
open Benitoite.Release
open Benitoite.Scope.Domain (Range)
set_option maxHeartbeats 800000
set_option maxRecDepth 4096

inductive Ix where
  | fixed (r : Range)
  | var (i : Nat)

def Ix.bind (σ : Nat → Ix) : Ix → Ix
  | .fixed r => .fixed r
  | .var i => σ i

inductive RangeLe : Ix → Ix → Prop where
  | refl (a) : RangeLe a a
  | fixed {r s} : r.Sub s → (r = .top → s = .top) → RangeLe (.fixed r) (.fixed s)
  | trans {a b c} : RangeLe a b → RangeLe b c → RangeLe a c

theorem RangeLe.bind {a b} (h : RangeLe a b) (σ : Nat → Ix) : RangeLe (a.bind σ) (b.bind σ) := by
  induction h with
  | refl => exact .refl _
  | fixed h ht => exact .fixed h ht
  | trans _ _ i₁ i₂ => exact .trans i₁ i₂

mutual
  inductive TyQ where
    | native (a : Ty)
    | var (i : Nat)
    | list (a : TyQ)
    | reference (a : TyQ)
    | data (name : String) (fields : FieldsQ)
    | «opaque» (name : String) (ix : Ix)
    | refined (a : TyQ) (p : Pred)
    | fn (args : TelQ)
  inductive EffQ where
    | empty
    | atom (name : String) (ix : Ix)
    | row (i : Nat)
    | fail (error : TyQ)
    | union (a b : EffQ)
  inductive TelQ where
    | done (a : TyQ) (eff : EffQ)
    | param (name : String) (a : TyQ) (rest : TelQ)
  inductive FieldsQ where
    | nil
    | cons (name : String) (a : TyQ) (rest : FieldsQ)
end

def upNat (ξ : Nat → Nat) : Nat → Nat
  | 0 => 0
  | i+1 => ξ i + 1

mutual
  def TyQ.mapValue (ξ : Nat → Nat) : TyQ → TyQ
    | .native a => .native a
    | .var i => .var i
    | .list a => .list (a.mapValue ξ)
    | .reference a => .reference (a.mapValue ξ)
    | .data n fs => .data n (fs.mapValue ξ)
    | .opaque n ix => .opaque n ix
    | .refined a p => .refined (a.mapValue ξ) (p.bind (fun i => .var (upNat ξ i)))
    | .fn ts => .fn (ts.mapValue ξ)
  def EffQ.mapValue (ξ : Nat → Nat) : EffQ → EffQ
    | .empty => .empty
    | .atom n ix => .atom n ix
    | .row i => .row i
    | .fail a => .fail (a.mapValue ξ)
    | .union a b => .union (a.mapValue ξ) (b.mapValue ξ)
  def TelQ.mapValue (ξ : Nat → Nat) : TelQ → TelQ
    | .done a e => .done (a.mapValue ξ) (e.mapValue ξ)
    | .param n a rest => .param n (a.mapValue ξ) (rest.mapValue (upNat ξ))
  def FieldsQ.mapValue (ξ : Nat → Nat) : FieldsQ → FieldsQ
    | .nil => .nil
    | .cons n a rest => .cons n (a.mapValue ξ) (rest.mapValue ξ)
end

structure Sub where
  types : Nat → TyQ
  rows : Nat → EffQ
  ranges : Nat → Ix
  values : Nat → Term

def Sub.up (θ : Sub) : Sub :=
  ⟨fun i => (θ.types i).mapValue Nat.succ,
   fun i => (θ.rows i).mapValue Nat.succ, θ.ranges, upSub θ.values⟩

mutual
  def TyQ.bind (θ : Sub) : TyQ → TyQ
    | .native a => .native a
    | .var i => θ.types i
    | .list a => .list (a.bind θ)
    | .reference a => .reference (a.bind θ)
    | .data n fs => .data n (fs.bind θ)
    | .opaque n ix => .opaque n (ix.bind θ.ranges)
    | .refined a p => .refined (a.bind θ) (p.bind (upSub θ.values))
    | .fn ts => .fn (ts.bind θ)
  def EffQ.bind (θ : Sub) : EffQ → EffQ
    | .empty => .empty
    | .atom n ix => .atom n (ix.bind θ.ranges)
    | .row i => θ.rows i
    | .fail a => .fail (a.bind θ)
    | .union a b => .union (a.bind θ) (b.bind θ)
  def TelQ.bind (θ : Sub) : TelQ → TelQ
    | .done a e => .done (a.bind θ) (e.bind θ)
    | .param n a rest => .param n (a.bind θ) (rest.bind θ.up)
  def FieldsQ.bind (θ : Sub) : FieldsQ → FieldsQ
    | .nil => .nil
    | .cons n a rest => .cons n (a.bind θ) (rest.bind θ)
end

-- 自己変数0について篩と形の事実だけを取り出す。関数と Reference の内容は論理へ入れない。
def TyQ.assume : TyQ → List Pred
  | .refined a p => p :: a.assume
  | .list _ => [.isList (.var 0)]
  | _ => []

theorem TyQ.assume_bind (a : TyQ) (θ : Sub) {p : Pred} (hp : p ∈ a.assume) :
    p.bind (upSub θ.values) ∈ (a.bind θ).assume := by
  cases a with
  | refined a q =>
      rcases List.mem_cons.mp hp with rfl | hp
      · exact List.mem_cons_self
      · exact List.mem_cons_of_mem _ (TyQ.assume_bind a θ hp)
  | list a =>
      have he : p = .isList (.var 0) := List.mem_singleton.mp hp
      subst p
      exact List.mem_cons_self
  | native | var | reference | data | «opaque» | fn => cases hp

termination_by sizeOf a

inductive Covers : EffQ → EffQ → Prop where
  | refl (a) : Covers a a
  | trans {a b c} : Covers a b → Covers b c → Covers a c
  | empty (a) : Covers a .empty
  | atom {n a b} : RangeLe a b → Covers (.atom n b) (.atom n a)
  | fail {a b} : a = b → Covers (.fail a) (.fail b)
  | left (a b) : Covers (.union a b) a
  | right (a b) : Covers (.union a b) b
  | union {o a b} : Covers o a → Covers o b → Covers o (.union a b)

theorem Covers.bind {a b} (h : Covers a b) (θ : Sub) : Covers (a.bind θ) (b.bind θ) := by
  induction h with
  | refl => exact .refl _
  | trans _ _ i₁ i₂ => exact .trans i₁ i₂
  | empty => exact .empty _
  | atom h => exact .atom (h.bind θ.ranges)
  | fail he => exact .fail (congrArg (TyQ.bind θ) he)
  | left => exact .left _ _
  | right => exact .right _ _
  | union _ _ i₁ i₂ => exact .union i₁ i₂

mutual
  inductive TyLe : List Pred → TyQ → TyQ → Prop where
    | refl {Φ : List Pred} (a) : TyLe Φ a a
    | trans {Φ : List Pred} {a b c} : TyLe Φ a b → TyLe Φ b c → TyLe Φ a c
    | native {Φ : List Pred} {a b} : Ty.Le a b → TyLe Φ (.native a) (.native b)
    | forget {Φ : List Pred} {a p} : TyLe Φ (.refined a p) a
    | introduce {Φ : List Pred} {a p} : Entails (a.assume ++ Φ.map Pred.lift) p → TyLe Φ a (.refined a p)
    | refine {Φ : List Pred} {a b p q} : TyLe Φ a b → Entails (p :: a.assume ++ Φ.map Pred.lift) q →
        TyLe Φ (.refined a p) (.refined b q)
    | list {Φ : List Pred} {a b} : TyLe Φ a b → TyLe Φ (.list a) (.list b)
    | reference {Φ : List Pred} {a b} : a = b → TyLe Φ (.reference a) (.reference b)
    | data {Φ : List Pred} {name fs gs} : FieldsLe Φ fs gs → TyLe Φ (.data name fs) (.data name gs)
    | «opaque» {Φ : List Pred} {name a b} : RangeLe a b → TyLe Φ (.opaque name a) (.opaque name b)
    | fn {Φ : List Pred} {a b} : TelLe Φ a b → TyLe Φ (.fn a) (.fn b)
  inductive TelLe : List Pred → TelQ → TelQ → Prop where
    | done {Φ : List Pred} {a b e f} : TyLe Φ a b → Covers f e → TelLe Φ (.done a e) (.done b f)
    | param {Φ : List Pred} {name a b as bs} : TyLe Φ b a → TelLe (b.assume ++ Φ.map Pred.lift) as bs →
        TelLe Φ (.param name a as) (.param name b bs)
  inductive FieldsLe : List Pred → FieldsQ → FieldsQ → Prop where
    | nil {Φ : List Pred} : FieldsLe Φ .nil .nil
    | cons {Φ : List Pred} {name a b as bs} : TyLe Φ a b → FieldsLe Φ as bs →
        FieldsLe Φ (.cons name a as) (.cons name b bs)
end

-- Φ の切り替えを、構文の含意で示す。Tel の下で新しい仮定をそのまま残す。
theorem lift_cut {Φ Ψ : List Pred} (hm : ∀ p ∈ Φ, Entails Ψ p) (extra : List Pred) :
    ∀ p ∈ extra ++ Φ.map Pred.lift, Entails (extra ++ Ψ.map Pred.lift) p := by
  intro p hp
  rcases List.mem_append.mp hp with hp | hp
  · exact .hyp (List.mem_append_left _ hp)
  · obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
    apply ((hm q hq).bind (fun i => .var (i+1))).cut
    intro r hr
    exact .hyp (List.mem_append_right _ hr)

theorem TyLe.cut {Φ a b} (h : TyLe Φ a b) :
    ∀ (Ψ : List Pred), (∀ p ∈ Φ, Entails Ψ p) → TyLe Ψ a b := by
  induction h using TyLe.rec
    (motive_2 := fun Φ a b _ => ∀ Ψ, (∀ p ∈ Φ, Entails Ψ p) → TelLe Ψ a b)
    (motive_3 := fun Φ a b _ => ∀ Ψ, (∀ p ∈ Φ, Entails Ψ p) → FieldsLe Ψ a b) with
  | refl => (first | intro Ψ hm | rename_i Ψ hm); exact .refl _
  | trans _ _ i₁ i₂ => (first | intro Ψ hm | rename_i Ψ hm); exact .trans (i₁ Ψ hm) (i₂ Ψ hm)
  | native h => (first | intro Ψ hm | rename_i Ψ hm); exact .native h
  | forget => (first | intro Ψ hm | rename_i Ψ hm); exact .forget
  | introduce h => (first | intro Ψ hm | rename_i Ψ hm); exact .introduce (h.cut (lift_cut hm _))
  | refine _ hp ih => (first | intro Ψ hm | rename_i Ψ hm); exact .refine (ih Ψ hm) (hp.cut (lift_cut hm _))
  | list _ ih => (first | intro Ψ hm | rename_i Ψ hm); exact .list (ih Ψ hm)
  | reference h => (first | intro Ψ hm | rename_i Ψ hm); exact .reference h
  | data _ ih => (first | intro Ψ hm | rename_i Ψ hm); exact .data (ih Ψ hm)
  | «opaque» h => (first | intro Ψ hm | rename_i Ψ hm); exact .opaque h
  | fn _ ih => (first | intro Ψ hm | rename_i Ψ hm); exact .fn (ih Ψ hm)
  | done _ he ih => (first | intro Ψ hm | rename_i Ψ hm); exact .done (ih Ψ hm) he
  | param _ _ ia ir => (first | intro Ψ hm | rename_i Ψ hm); exact .param (ia Ψ hm) (ir _ (lift_cut hm _))
  | nil => (first | intro Ψ hm | rename_i Ψ hm); exact .nil
  | cons _ _ ia ir => (first | intro Ψ hm | rename_i Ψ hm); exact .cons (ia Ψ hm) (ir Ψ hm)

-- TelLe/FieldsLe についても同じ相互帰納を使う。Lean の recursor を共有する。
theorem TelLe.cut {Φ a b} (h : TelLe Φ a b) (Ψ) (hm : ∀ p ∈ Φ, Entails Ψ p) : TelLe Ψ a b := by
  revert Ψ hm
  induction h using TelLe.rec
    (motive_1 := fun Φ a b _ => ∀ Ψ, (∀ p ∈ Φ, Entails Ψ p) → TyLe Ψ a b)
    (motive_3 := fun Φ a b _ => ∀ Ψ, (∀ p ∈ Φ, Entails Ψ p) → FieldsLe Ψ a b) with
  | refl => (first | intro Ψ hm | rename_i Ψ hm); exact .refl _
  | trans _ _ i₁ i₂ => (first | intro Ψ hm | rename_i Ψ hm); exact .trans (i₁ Ψ hm) (i₂ Ψ hm)
  | native h => (first | intro Ψ hm | rename_i Ψ hm); exact .native h
  | forget => (first | intro Ψ hm | rename_i Ψ hm); exact .forget
  | introduce h => (first | intro Ψ hm | rename_i Ψ hm); exact .introduce (h.cut (lift_cut hm _))
  | refine _ hp ih => (first | intro Ψ hm | rename_i Ψ hm); exact .refine (ih Ψ hm) (hp.cut (lift_cut hm _))
  | list _ ih => (first | intro Ψ hm | rename_i Ψ hm); exact .list (ih Ψ hm)
  | reference h => (first | intro Ψ hm | rename_i Ψ hm); exact .reference h
  | data _ ih => (first | intro Ψ hm | rename_i Ψ hm); exact .data (ih Ψ hm)
  | «opaque» h => (first | intro Ψ hm | rename_i Ψ hm); exact .opaque h
  | fn _ ih => (first | intro Ψ hm | rename_i Ψ hm); exact .fn (ih Ψ hm)
  | done _ he ih => (first | intro Ψ hm | rename_i Ψ hm); exact .done (ih Ψ hm) he
  | param _ _ ia ir => (first | intro Ψ hm | rename_i Ψ hm); exact .param (ia Ψ hm) (ir _ (lift_cut hm _))
  | nil => (first | intro Ψ hm | rename_i Ψ hm); exact .nil
  | cons _ _ ia ir => (first | intro Ψ hm | rename_i Ψ hm); exact .cons (ia Ψ hm) (ir Ψ hm)

-- 置換前の篩/形の仮定は置換後にも導出できる。型像が新しい篩を持つときは仮定が増える。
theorem bind_context (θ : Sub) (a : TyQ) (Φ : List Pred) :
    ∀ p ∈ (a.assume ++ Φ.map Pred.lift).map (Pred.bind (upSub θ.values)),
      Entails ((a.bind θ).assume ++ (Φ.map (Pred.bind θ.values)).map Pred.lift) p := by
  intro p hp
  obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
  rcases List.mem_append.mp hq with hq | hq
  · exact .hyp (List.mem_append_left _ (a.assume_bind θ hq))
  · obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hq
    rw [Pred.lift_bind]
    exact .hyp (List.mem_append_right _ (List.mem_map.mpr ⟨_, List.mem_map.mpr ⟨r, hr, rfl⟩, rfl⟩))

theorem TyLe.bind {Φ a b} (h : TyLe Φ a b) : ∀ (θ : Sub),
    TyLe (Φ.map (Pred.bind θ.values)) (a.bind θ) (b.bind θ) := by
  induction h using TyLe.rec
    (motive_2 := fun Φ a b _ => ∀ θ, TelLe (Φ.map (Pred.bind θ.values)) (a.bind θ) (b.bind θ))
    (motive_3 := fun Φ a b _ => ∀ θ, FieldsLe (Φ.map (Pred.bind θ.values)) (a.bind θ) (b.bind θ)) with
  | refl => (first | intro θ | rename_i θ); exact .refl _
  | trans _ _ i₁ i₂ => (first | intro θ | rename_i θ); exact .trans (i₁ θ) (i₂ θ)
  | native h => (first | intro θ | rename_i θ); exact .native h
  | forget => (first | intro θ | rename_i θ); exact .forget
  | introduce hp => (first | intro θ | rename_i θ); exact .introduce ((hp.bind _).cut (bind_context θ _ _))
  | @refine Φ a b p q _ hp ih =>
      first | intro θ | rename_i θ
      apply TyLe.refine (ih θ)
      apply (hp.bind (upSub θ.values)).cut
      intro r hr
      rcases List.mem_cons.mp hr with rfl | hr
      · exact .hyp (by simp)
      · apply (bind_context θ a Φ r hr).cut
        intro s hs
        exact .hyp (List.mem_cons_of_mem _ hs)
  | list _ ih => (first | intro θ | rename_i θ); exact .list (ih θ)
  | reference he => (first | intro θ | rename_i θ); exact .reference (congrArg (TyQ.bind θ) he)
  | data _ ih => (first | intro θ | rename_i θ); exact .data (ih θ)
  | «opaque» h => (first | intro θ | rename_i θ); exact .opaque (h.bind θ.ranges)
  | fn _ ih => (first | intro θ | rename_i θ); exact .fn (ih θ)
  | done _ he ih => (first | intro θ | rename_i θ); exact .done (ih θ) (he.bind θ)
  | @param Φ name a b as bs _ _ ia ir =>
      first | intro θ | rename_i θ
      exact .param (ia θ) ((ir θ.up).cut _ (bind_context θ b Φ))
  | nil => (first | intro θ | rename_i θ); exact .nil
  | cons _ _ ia ir => (first | intro θ | rename_i θ); exact .cons (ia θ) (ir θ)

theorem TelLe.bind {Φ a b} (h : TelLe Φ a b) : ∀ (θ : Sub),
    TelLe (Φ.map (Pred.bind θ.values)) (a.bind θ) (b.bind θ) := by
  induction h using TelLe.rec
    (motive_1 := fun Φ a b _ => ∀ θ, TyLe (Φ.map (Pred.bind θ.values)) (a.bind θ) (b.bind θ))
    (motive_3 := fun Φ a b _ => ∀ θ, FieldsLe (Φ.map (Pred.bind θ.values)) (a.bind θ) (b.bind θ)) with
  | refl => (first | intro θ | rename_i θ); exact .refl _
  | trans _ _ i₁ i₂ => (first | intro θ | rename_i θ); exact .trans (i₁ θ) (i₂ θ)
  | native h => (first | intro θ | rename_i θ); exact .native h
  | forget => (first | intro θ | rename_i θ); exact .forget
  | introduce hp => (first | intro θ | rename_i θ); exact .introduce ((hp.bind _).cut (bind_context θ _ _))
  | @refine Φ a b p q _ hp ih =>
      first | intro θ | rename_i θ
      apply TyLe.refine (ih θ)
      apply (hp.bind (upSub θ.values)).cut
      intro r hr
      rcases List.mem_cons.mp hr with rfl | hr
      · exact .hyp (by simp)
      · apply (bind_context θ a Φ r hr).cut
        intro s hs
        exact .hyp (List.mem_cons_of_mem _ hs)
  | list _ ih => (first | intro θ | rename_i θ); exact .list (ih θ)
  | reference he => (first | intro θ | rename_i θ); exact .reference (congrArg (TyQ.bind θ) he)
  | data _ ih => (first | intro θ | rename_i θ); exact .data (ih θ)
  | «opaque» h => (first | intro θ | rename_i θ); exact .opaque (h.bind θ.ranges)
  | fn _ ih => (first | intro θ | rename_i θ); exact .fn (ih θ)
  | done _ he ih => (first | intro θ | rename_i θ); exact .done (ih θ) (he.bind θ)
  | @param Φ name a b as bs _ _ ia ir =>
      first | intro θ | rename_i θ
      exact .param (ia θ) ((ir θ.up).cut _ (bind_context θ b Φ))
  | nil => (first | intro θ | rename_i θ); exact .nil
  | cons _ _ ia ir => (first | intro θ | rename_i θ); exact .cons (ia θ) (ir θ)


theorem FieldsLe.bind {Φ a b} (h : FieldsLe Φ a b) : ∀ (θ : Sub),
    FieldsLe (Φ.map (Pred.bind θ.values)) (a.bind θ) (b.bind θ) := by
  induction h using FieldsLe.rec
    (motive_1 := fun Φ a b _ => ∀ θ, TyLe (Φ.map (Pred.bind θ.values)) (a.bind θ) (b.bind θ))
    (motive_2 := fun Φ a b _ => ∀ θ, TelLe (Φ.map (Pred.bind θ.values)) (a.bind θ) (b.bind θ)) with
  | refl => (first | intro θ | rename_i θ); exact .refl _
  | trans _ _ i₁ i₂ => (first | intro θ | rename_i θ); exact .trans (i₁ θ) (i₂ θ)
  | native h => (first | intro θ | rename_i θ); exact .native h
  | forget => (first | intro θ | rename_i θ); exact .forget
  | introduce hp => (first | intro θ | rename_i θ); exact .introduce ((hp.bind _).cut (bind_context θ _ _))
  | @refine Φ a b p q _ hp ih =>
      first | intro θ | rename_i θ
      apply TyLe.refine (ih θ)
      apply (hp.bind (upSub θ.values)).cut
      intro r hr
      rcases List.mem_cons.mp hr with rfl | hr
      · exact .hyp (by simp)
      · apply (bind_context θ a Φ r hr).cut
        intro s hs
        exact .hyp (List.mem_cons_of_mem _ hs)
  | list _ ih => (first | intro θ | rename_i θ); exact .list (ih θ)
  | reference he => (first | intro θ | rename_i θ); exact .reference (congrArg (TyQ.bind θ) he)
  | data _ ih => (first | intro θ | rename_i θ); exact .data (ih θ)
  | «opaque» h => (first | intro θ | rename_i θ); exact .opaque (h.bind θ.ranges)
  | fn _ ih => (first | intro θ | rename_i θ); exact .fn (ih θ)
  | done _ he ih => (first | intro θ | rename_i θ); exact .done (ih θ) (he.bind θ)
  | @param Φ name a b as bs _ _ ia ir =>
      first | intro θ | rename_i θ
      exact .param (ia θ) ((ir θ.up).cut _ (bind_context θ b Φ))
  | nil => (first | intro θ | rename_i θ); exact .nil
  | cons _ _ ia ir => (first | intro θ | rename_i θ); exact .cons (ia θ) (ir θ)


-- 最外の本番 Ty アダプタの V_Sub と、この相互帰納の判断を結ぶ。
-- 二つの判断が同じ構文の Entails を使うことを、埋め込みで確認する。
def embedRef (a : RefTy) : TyQ := .refined (.native a.carrier) a.predicate

theorem adapter_le {Φ a b} (h : P4.Le Φ a b) : TyLe Φ (embedRef a) (embedRef b) := by
  induction h with
  | refl => exact .refl _
  | trans _ _ i₁ i₂ => exact .trans i₁ i₂
  | refine hc hp => exact .refine (.native hc) hp

#print axioms TelLe.bind
#print axioms FieldsLe.bind
#print axioms adapter_le
#print axioms TyLe.bind
#print axioms TyLe.cut
#print axioms TelLe.cut
#print axioms Covers.bind
#print axioms TyQ.assume_bind
end P4.Derivation
