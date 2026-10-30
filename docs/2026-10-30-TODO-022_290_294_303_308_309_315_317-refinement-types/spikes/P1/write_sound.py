from pathlib import Path
p=Path(__file__).with_name('Skeleton.lean')
s=p.read_text();s=s[:s.index('theorem TyLe.sound')]
s+='''def Tel.Implies (w : World) (η : Interp T E R) (Φ : (V → Value) → Prop) (a b : Tel T E R V) : Prop := ∀ ρ, Φ ρ → ∀ vs, b.Pre w η ρ vs → a.Pre w η ρ vs ∧ ∀ result trace, a.Post w η ρ vs result trace → b.Post w η ρ vs result trace
def Fields.Implies (w : World) (η : Interp T E R) (Φ : (V → Value) → Prop) (a b : Fields T E R V) : Prop := ∀ ρ, Φ ρ → ∀ xs, a.Mem w η ρ xs → b.Mem w η ρ xs
'''
handlers='''
    | refl => exact fun _ _ _ hx => hx
    | trans h₁ h₂ ih₁ ih₂ => exact fun ρ hρ x hx => ih₂ ρ hρ x (ih₁ ρ hρ x hx)
    | forget => exact fun _ _ _ hx => hx.1
    | introduce hp => exact fun ρ hρ x hx => ⟨hx, hp ρ hρ x hx⟩
    | refine hab hp ih => exact fun ρ hρ x hx => ⟨ih ρ hρ x hx.1, hp ρ hρ x hx.1 hx.2⟩
    | list h ih =>
      rintro ρ hρ x ⟨xs, rfl, hx⟩
      exact ⟨xs, rfl, fun x hm => ih ρ hρ x (hx x hm)⟩
    | reference he => cases he; exact fun _ _ _ hx => hx
    | record h ih =>
      rintro ρ hρ x ⟨xs, rfl, hx⟩
      exact ⟨xs, rfl, ih ρ hρ xs hx⟩
    | @«opaque» V Φ n ia ib h ht =>
      intro ρ hρ x hx
      cases hk : targetKind n with
      | none =>
        simp only [Ty.Mem, hk] at hx ⊢
        exact ⟨hx.choose, hx.choose_spec.1, ht hx.choose_spec.2⟩
      | some k =>
        simp only [Ty.Mem, hk] at hx ⊢
        exact ⟨hx.choose, hx.choose_spec.1, h _ hx.choose_spec.2⟩
    | fn h ih =>
      rintro ρ hρ x ⟨code, rfl, hc⟩
      refine ⟨code, rfl, ?_⟩
      intro vs result trace hp hcall
      exact (ih ρ hρ vs hp).2 result trace (hc vs result trace (ih ρ hρ vs hp).1 hcall)
    | done ha he ih =>
      intro ρ hρ vs hp
      refine ⟨hp, ?_⟩
      rintro result trace ⟨hn, hr, ht⟩
      exact ⟨hn, ih ρ hρ result hr, fun ev hm => Eff.covers_sound w η ρ he (ht ev hm)⟩
    | @param V Φ b a as bs name hba hs iarg irest =>
      rintro ρ hρ vs ⟨x, xs, rfl, hx, hrest⟩
      have hctx : Φ (extend ρ x ∘ some) ∧ b.Mem w η (extend ρ x ∘ some) (extend ρ x none) := ⟨hρ, hx⟩
      have ih := irest (extend ρ x) hctx xs hrest
      refine ⟨⟨x, xs, rfl, iarg ρ hρ x hx, ih.1⟩, ?_⟩
      rintro result trace ⟨y, ys, heq, hr⟩
      cases heq
      exact ⟨x, xs, rfl, ih.2 result trace hr⟩
    | nil => exact fun _ _ _ _ => trivial
    | cons ha hs ia is =>
      rintro ρ hρ xs ⟨x, hx, ha', hs'⟩
      exact ⟨x, hx, ia ρ hρ x ha', is ρ hρ xs hs'⟩
'''
motives='''
      (motive_1 := fun Φ a b _ => a.Subtype w η Φ b)
      (motive_2 := fun Φ a b _ => a.Implies w η Φ b)
      (motive_3 := fun Φ a b _ => a.Implies w η Φ b) with'''
statements=[
('TyLe','a.Subtype w η Φ b'),
('TelLe','a.Implies w η Φ b'),
('FieldsLe','a.Implies w η Φ b')]
for name,stmt in statements:
 m=motives
 idx={'TyLe':1,'TelLe':2,'FieldsLe':3}[name]
 m='\n'.join(line for line in m.split('\n') if f'(motive_{idx} :=' not in line)
 if not m.rstrip().endswith('with'): m+=' with'
 s+=f'\ntheorem {name}.sound (h : {name} w η Φ a b) : {stmt} := by\n  induction h using {name}.rec'+m+handlers
s+='end P1\n';p.write_text(s)
