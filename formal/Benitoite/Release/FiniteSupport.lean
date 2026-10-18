import Benitoite.Release.Finite

/-! 宣言・注釈から与えた候補の中で、Fail内部までの支持を収集する。 -/
namespace Benitoite.Release

mutual
  def Ty.collectAtoms (s : List Atom) : Ty → List Atom
    | .data _ ts | .tapp _ ts => Ty.collectAtomsList s ts
    | .list t | .reference t | .lazy t | .set t | .dict _ t => t.collectAtoms s
    | .fn _ ps r e => Ty.collectAtomsList s ps ++ r.collectAtoms s ++ Eff.collectAtoms s e
    | .cont a b e => a.collectAtoms s ++ b.collectAtoms s ++ Eff.collectAtoms s e
    | .map a b => a.collectAtoms s ++ b.collectAtoms s
    | _ => []
  def Ty.collectAtomsList (s : List Atom) : List Ty → List Atom
    | [] => []
    | t :: ts => t.collectAtoms s ++ Ty.collectAtomsList s ts
  def Eff.collectAtoms (s : List Atom) : Eff → List Atom
    | .mk f fs => s.filter f ++ Ty.collectAtomsList s fs
end

mutual
  theorem Ty.support_mono {p q : Atom → Prop} (t : Ty) (h : t.Support p)
      (hp : ∀ a, p a → q a) : t.Support q := by
    cases t <;> simp only [Ty.Support] at h ⊢
    all_goals first
      | trivial
      | exact Ty.support_mono _ h hp
      | exact Ty.supportList_mono _ h hp
      | skip
    case fn ns ps r e => exact ⟨Ty.supportList_mono ps h.1 hp,
      Ty.support_mono r h.2.1 hp, Eff.support_mono e h.2.2 hp⟩
    case cont a b e => exact ⟨Ty.support_mono a h.1 hp,
      Ty.support_mono b h.2.1 hp, Eff.support_mono e h.2.2 hp⟩
    case map a b => exact ⟨Ty.support_mono a h.1 hp, Ty.support_mono b h.2 hp⟩
  theorem Ty.supportList_mono {p q : Atom → Prop} (ts : List Ty) (h : Ty.SupportList p ts)
      (hp : ∀ a, p a → q a) : Ty.SupportList q ts := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨Ty.support_mono t h.1 hp, Ty.supportList_mono ts h.2 hp⟩
  theorem Eff.support_mono {p q : Atom → Prop} (e : Eff) (h : Eff.Support p e)
      (hp : ∀ a, p a → q a) : Eff.Support q e := by
    cases e
    exact ⟨fun a ha => hp a (h.1 a ha), Ty.supportList_mono _ h.2 hp⟩
end

mutual
  /-- 候補が入力を覆うとき、収集した集合だけでも型内部を覆う。 -/
  theorem Ty.collectAtoms_complete (s : List Atom) (t : Ty) (h : t.Support (· ∈ s)) :
      t.Support (· ∈ t.collectAtoms s) := by
    cases t <;> simp only [Ty.Support] at h ⊢
    all_goals first
      | trivial
      | exact Ty.collectAtoms_complete s _ h
      | exact Ty.collectAtomsList_complete s _ h
      | skip
    case fn ns ps r e =>
      exact ⟨Ty.supportList_mono ps (Ty.collectAtomsList_complete s ps h.1)
          (fun a ha => List.mem_append_left _ (List.mem_append_left _ ha)),
        Ty.support_mono r (Ty.collectAtoms_complete s r h.2.1)
          (fun a ha => List.mem_append_left _ (List.mem_append_right _ ha)),
        Eff.support_mono e (Eff.collectAtoms_complete s e h.2.2)
          (fun a ha => List.mem_append_right _ ha)⟩
    case cont a b e =>
      exact ⟨Ty.support_mono a (Ty.collectAtoms_complete s a h.1)
          (fun a ha => List.mem_append_left _ (List.mem_append_left _ ha)),
        Ty.support_mono b (Ty.collectAtoms_complete s b h.2.1)
          (fun a ha => List.mem_append_left _ (List.mem_append_right _ ha)),
        Eff.support_mono e (Eff.collectAtoms_complete s e h.2.2)
          (fun a ha => List.mem_append_right _ ha)⟩
    case map a b =>
      exact ⟨Ty.support_mono a (Ty.collectAtoms_complete s a h.1)
          (fun a ha => List.mem_append_left _ ha),
        Ty.support_mono b (Ty.collectAtoms_complete s b h.2)
          (fun a ha => List.mem_append_right _ ha)⟩
  theorem Ty.collectAtomsList_complete (s : List Atom) (ts : List Ty)
      (h : Ty.SupportList (· ∈ s) ts) : Ty.SupportList (· ∈ Ty.collectAtomsList s ts) ts := by
    cases ts with
    | nil => trivial
    | cons t ts =>
      exact ⟨Ty.support_mono t (Ty.collectAtoms_complete s t h.1)
          (fun a ha => List.mem_append_left _ ha),
        Ty.supportList_mono ts (Ty.collectAtomsList_complete s ts h.2)
          (fun a ha => List.mem_append_right _ ha)⟩
  theorem Eff.collectAtoms_complete (s : List Atom) (e : Eff) (h : Eff.Support (· ∈ s) e) :
      Eff.Support (· ∈ Eff.collectAtoms s e) e := by
    cases e with
    | mk f fs =>
      exact ⟨fun a ha => List.mem_append_left _ (List.mem_filter.mpr ⟨h.1 a ha, ha⟩),
        Ty.supportList_mono fs (Ty.collectAtomsList_complete s fs h.2)
          (fun a ha => List.mem_append_right _ ha)⟩
end

mutual
  /-- 収集した原子は、候補の中で実際に現れる原子だけである。 -/
  theorem Ty.collectAtoms_sound {p} (s : List Atom) (t : Ty) (h : t.Support p) :
      ∀ a ∈ t.collectAtoms s, p a := by
    cases t <;> simp only [Ty.collectAtoms, Ty.Support] at h ⊢
    all_goals first
      | exact fun _ h => False.elim (List.not_mem_nil h)
      | exact Ty.collectAtoms_sound s _ h
      | exact Ty.collectAtomsList_sound s _ h
      | skip
    case fn ns ps r e =>
      intro a ha
      rcases List.mem_append.mp ha with ha | ha
      · rcases List.mem_append.mp ha with ha | ha
        · exact Ty.collectAtomsList_sound s ps h.1 a ha
        · exact Ty.collectAtoms_sound s r h.2.1 a ha
      · exact Eff.collectAtoms_sound s e h.2.2 a ha
    case cont a b e =>
      intro x hx
      rcases List.mem_append.mp hx with hx | hx
      · rcases List.mem_append.mp hx with hx | hx
        · exact Ty.collectAtoms_sound s a h.1 x hx
        · exact Ty.collectAtoms_sound s b h.2.1 x hx
      · exact Eff.collectAtoms_sound s e h.2.2 x hx
    case map a b =>
      intro x hx
      rcases List.mem_append.mp hx with hx | hx
      · exact Ty.collectAtoms_sound s a h.1 x hx
      · exact Ty.collectAtoms_sound s b h.2 x hx
  theorem Ty.collectAtomsList_sound {p} (s : List Atom) (ts : List Ty)
      (h : Ty.SupportList p ts) : ∀ a ∈ Ty.collectAtomsList s ts, p a := by
    cases ts with
    | nil => exact fun _ h => False.elim (List.not_mem_nil h)
    | cons t ts =>
      intro a ha
      rcases List.mem_append.mp ha with ha | ha
      · exact Ty.collectAtoms_sound s t h.1 a ha
      · exact Ty.collectAtomsList_sound s ts h.2 a ha
  theorem Eff.collectAtoms_sound {p} (s : List Atom) (e : Eff) (h : Eff.Support p e) :
      ∀ a ∈ Eff.collectAtoms s e, p a := by
    cases e with
    | mk f fs =>
      intro a ha
      rcases List.mem_append.mp ha with ha | ha
      · exact h.1 a (List.mem_filter.mp ha).2
      · exact Ty.collectAtomsList_sound s fs h.2 a ha
end

/-- 候補の完全性が分かる場合、収集結果で任意の支持述語を判定できる。 -/
theorem Ty.collectAtoms_support_iff {s t} (hs : Ty.Support (· ∈ s) t) (p : Atom → Prop) :
    t.Support p ↔ ∀ a ∈ t.collectAtoms s, p a :=
  ⟨Ty.collectAtoms_sound s t, fun h => Ty.support_mono t (Ty.collectAtoms_complete s t hs) h⟩

theorem Eff.collectAtoms_support_iff {s e} (hs : Eff.Support (· ∈ s) e) (p : Atom → Prop) :
    Eff.Support p e ↔ ∀ a ∈ Eff.collectAtoms s e, p a :=
  ⟨Eff.collectAtoms_sound s e, fun h => Eff.support_mono e (Eff.collectAtoms_complete s e hs) h⟩

mutual
  theorem Ty.support_of_norm {p} (t : Ty) (h : t.norm.Support p) : t.Support p := by
    cases t <;> simp only [Ty.norm, Ty.Support] at h ⊢
    all_goals first
      | trivial
      | exact Ty.support_of_norm _ h
      | exact Ty.supportList_of_norm _ h
      | skip
    case fn ns ps r e => exact ⟨Ty.supportList_of_norm ps h.1,
      Ty.support_of_norm r h.2.1, Eff.support_of_norm e h.2.2⟩
    case cont a b e => exact ⟨Ty.support_of_norm a h.1,
      Ty.support_of_norm b h.2.1, Eff.support_of_norm e h.2.2⟩
    case map a b => exact ⟨Ty.support_of_norm a h.1, Ty.support_of_norm b h.2⟩
  theorem Ty.supportList_of_norm {p} (ts : List Ty) (h : Ty.SupportList p (Ty.normTys ts)) :
      Ty.SupportList p ts := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨Ty.support_of_norm t h.1, Ty.supportList_of_norm ts h.2⟩
  theorem Eff.support_of_norm {p} (e : Eff) (h : Eff.Support p (Eff.norm e)) : Eff.Support p e := by
    cases e with
    | mk a fs =>
      refine ⟨h.1, Ty.SupportList.iff.mpr ?_⟩
      intro t ht
      apply Ty.support_of_norm t
      exact Ty.SupportList.iff.mp h.2 t.norm (Order.mem_sortUnique.mpr
        (by rw [Ty.normTys_eq_map]; exact List.mem_map.mpr ⟨t, ht, rfl⟩))
end

/-- 最上位の原子の支持によらず、Fail列の再帰的な支持は正規化で保たれる。 -/
theorem Eff.norm_fails_support {p : Atom → Prop} (e : Eff) (h : Ty.SupportList p e.fails) :
    Ty.SupportList p (Eff.norm e).fails := by
  cases e with
  | mk a fs =>
    apply Ty.SupportList.iff.mpr
    intro t ht
    exact Ty.SupportList.iff.mp (Ty.normTys_support fs h) t (Order.mem_sortUnique.mp ht)

/-- 意味上の包含から、正規化前のFail内部の支持も取り出せる。 -/
theorem Eff.support_of_sub {p : Atom → Prop} {a b : Eff} (hb : Eff.Support p b)
    (h : Eff.Sub a b) : Eff.Support p a := by
  rw [Eff.support_iff] at hb ⊢
  constructor
  · intro x hx
    exact hb.1 x (h.1 x hx)
  · apply Ty.SupportList.iff.mpr
    intro t ht
    obtain ⟨u, hu, he⟩ := h.2 t ⟨t, ht, rfl⟩
    apply Ty.support_of_norm t
    rw [← he]
    exact Ty.norm_support u (Ty.SupportList.iff.mp hb.2 u hu)

end Benitoite.Release
