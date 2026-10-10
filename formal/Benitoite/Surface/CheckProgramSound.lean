import Benitoite.Surface.CheckTablesSound

/-! 信頼するシグネチャを補った宣言表のもとで、利用者の本体の型付けを結論する。 -/
namespace Benitoite.Surface.CheckTables
open Benitoite.Release Benitoite.Surface Benitoite.Surface.CheckTools

/-- 表の共有部分は同じであり、関数と実装の空欄だけを補う。 -/
def Extends (D base : Declarations) : Prop :=
  (∀ n d, base.funs n = some d → D.funs n = some d) ∧
  (∀ n d, base.impls n = some d → D.impls n = some d) ∧
  D.cons = base.cons ∧ D.ops = base.ops ∧ D.effects = base.effects ∧ D.classes = base.classes

theorem declarations_extend (m : Materials) : Extends m.declarations m.program.declarations := by
  refine ⟨?_, ?_, rfl, rfl, rfl, rfl⟩
  · intro n d h; change (m.program.declarations.funs n).or _ = some d; simp [h]
  · intro n d h; change (m.program.declarations.impls n).or _ = some d; simp [h]

def NamesComplete (p : Program) (names : Names) : Prop :=
  (∀ n d, p.defs n = some d → n ∈ names.defs) ∧
  (∀ n d, p.impls n = some d → n ∈ names.impls) ∧
  (∀ n os, p.effects n = some os → n ∈ names.effects)

theorem names_complete (m : Materials) : NamesComplete m.program m.names := by
  refine ⟨?_, ?_, ?_⟩
  · intro n d h; exact List.mem_map.mpr ⟨(n,d), lookup_mem h, rfl⟩
  · intro n d h
    have hm := lookup_mem h
    obtain ⟨⟨name,i⟩, hi, he⟩ := List.mem_map.mp hm
    simp only [Prod.mk.injEq] at he
    exact List.mem_map.mpr ⟨(name,i), hi, he.1⟩
  · intro n os h; exact List.mem_map.mpr ⟨(n,os), lookup_mem h, rfl⟩

private theorem bind_ok {r s : Check.Result Unit}
    (h : (r >>= fun _ => s) = .ok ()) : r = .ok () ∧ s = .ok () := by
  cases r with
  | error e => cases h
  | ok u => cases u; exact ⟨rfl, h⟩

theorem checkNamed_sound {table : String → Option α} {check path names index}
    (h : checkNamed table check path names index = .ok ()) :
    ∀ n ∈ names, ∀ x, table n = some x → ∃ location, check location x = .ok () := by
  induction names generalizing index with
  | nil => simp
  | cons name rest ih =>
    cases ht : table name with
    | none =>
      have tail : checkNamed table check path rest (index + 1) = .ok () := by
        simpa only [checkNamed, ht] using h
      intro n hn x hx
      rcases List.mem_cons.mp hn with rfl | hn
      · simp [ht] at hx
      · exact ih tail n hn x hx
    | some value =>
      have hh := bind_ok (show ((check (path ++ [index]) value) >>= fun _ =>
        checkNamed table check path rest (index + 1)) = .ok () from by
          simpa only [checkNamed, ht] using h)
      intro n hn x hx
      rcases List.mem_cons.mp hn with rfl | hn
      · rw [ht] at hx
        cases Option.some.inj hx
        exact ⟨path ++ [index], hh.1⟩
      · exact ih hh.2 n hn x hx

/-- この結論は、信頼する標準ライブラリの本体を型付けしたとは主張しない。 -/
def CheckedUnder (p : Program) (q : Check.Input) : Prop :=
  (∀ n d, p.defs n = some d → d.WellTyped q.D q.B q.opPrim) ∧
  Extends q.D p.declarations ∧
  (∀ l os, p.effects l = some os → q.B.effects l = none) ∧
  (∀ n id, p.impls n = some id → id.WellTyped q.D q.B q.opPrim)

theorem checkProgram_under {q : Check.Input} {p : Program} {names : Names}
    (hq : q.Sound) (hn : NamesComplete p names)
    (hd : ∀ n d, p.defs n = some d → d.AtomsIn q.atoms)
    (hi : ∀ n id, p.impls n = some id → id.AtomsIn q.atoms)
    (him : ∀ n id, p.impls n = some id → Check.ImplNamesComplete q id names.methods names.supers)
    (hext : Extends q.D p.declarations)
    (h : checkProgram q p names = .ok ()) : CheckedUnder p q := by
  have steps := bind_ok h
  have more := bind_ok steps.2
  refine ⟨?_, hext, ?_, ?_⟩
  · intro n d hget
    obtain ⟨path, hp⟩ := checkNamed_sound steps.1 n (hn.1 n d hget) d hget
    exact Check.checkDef_sound hq (hd n d hget) hp
  · intro l os hget
    have hmap : (p.effects l).map (fun _ => l) = some l := by simp [hget]
    obtain ⟨path, hp⟩ := checkNamed_sound more.2 l (hn.2.2 l os hget) l hmap
    unfold Check.require at hp
    split at hp
    · simpa using ‹(q.B.effects l).isNone = true›
    · cases hp
  · intro n id hget
    obtain ⟨path, hp⟩ := checkNamed_sound more.1 n (hn.2.1 n id hget) id hget
    exact Check.checkImpl_sound hq (hi n id hget) (him n id hget) hp

/-- 実装の本体側の注釈。対象の型と辞書の型は宣言表から導く。 -/
def ImplBodiesAtoms (atoms : List Atom) (id : ImplDecl) : Prop :=
  (∀ s d, id.supers s = some d → d.AtomsIn atoms) ∧
  (∀ m b, id.methods m = some b → b.AtomsIn atoms)

private theorem def_atoms {m : Materials} {atoms n d}
    (hd : m.declarations.AtomsIn atoms) (hget : m.program.defs n = some d)
    (hb : d.body.AtomsIn atoms) : d.AtomsIn atoms := by
  have hbase : m.program.declarations.funs n = some d.toFunDecl := by
    simp only [Program.declarations, Program.lookupFun, hget]
  have ha := hd.1 n d.toFunDecl ((declarations_extend m).1 n d.toFunDecl hbase)
  exact ⟨⟨tysAtoms_append ha.2 ha.1.1, ha.1.2⟩, hb⟩

private theorem impl_atoms {m : Materials} {atoms n id}
    (hd : m.declarations.AtomsIn atoms) (hget : m.program.impls n = some id)
    (hb : ImplBodiesAtoms atoms id) : id.AtomsIn atoms := by
  have hbase : m.program.declarations.impls n = some id.toImplSig := by
    simp only [Program.declarations, hget, Option.map_some]
  have ha := hd.2.2.2.2 n id.toImplSig ((declarations_extend m).2.1 n id.toImplSig hbase)
  exact ⟨ha.1, ha.2, hb⟩

/-- Q9 の原子集合だけを信頼し、表の有限性と判定の接続は証明から得る。 -/
theorem checkProgram_sound {m : Materials} {S raw b opAtoms entries atoms}
    (hd : m.declarations.AtomsIn atoms)
    (hb : (builtins S (primEntries S raw) b).AtomsIn atoms)
    (hdefs : ∀ n d, m.program.defs n = some d → d.body.AtomsIn atoms)
    (himpls : ∀ n id, m.program.impls n = some id → ImplBodiesAtoms atoms id)
    (hc : constructorsOk m = true)
    (hn : implNamesOk m m.names.methods m.names.supers = true)
    (h : checkProgram
      (m.input (builtins S (primEntries S raw) b) (satB S) (admitsDec S (primEntries S raw))
        (Benitoite.Exchange.makeOpPrim opAtoms entries) atoms) m.program m.names = .ok ()) :
    CheckedUnder m.program
      (m.input (builtins S (primEntries S raw) b) (satB S) (admitsDec S (primEntries S raw))
        (Benitoite.Exchange.makeOpPrim opAtoms entries) atoms) := by
  apply checkProgram_under (input_sound hd hb hc) (names_complete m)
  · intro n d hget; exact def_atoms hd hget (hdefs n d hget)
  · intro n id hget; exact impl_atoms hd hget (himpls n id hget)
  · intro n id hi; exact implNames_sound hn hi
  · exact declarations_extend m
  · exact h

theorem checkProgram_empty {m : Materials} {S raw b opAtoms entries atoms}
    (hf : m.trustedFuns = []) (hi : m.trustedImpls = [])
    (hd : m.declarations.AtomsIn atoms)
    (hb : (builtins S (primEntries S raw) b).AtomsIn atoms)
    (hdefs : ∀ n d, m.program.defs n = some d → d.body.AtomsIn atoms)
    (himpls : ∀ n id, m.program.impls n = some id → ImplBodiesAtoms atoms id)
    (hc : constructorsOk m = true)
    (hn : implNamesOk m m.names.methods m.names.supers = true)
    (h : checkProgram
      (m.input (builtins S (primEntries S raw) b) (satB S) (admitsDec S (primEntries S raw))
        (Benitoite.Exchange.makeOpPrim opAtoms entries) atoms) m.program m.names = .ok ()) :
    m.program.WellTyped (builtins S (primEntries S raw) b)
      (Benitoite.Exchange.makeOpPrim opAtoms entries) := by
  have hD : m.declarations = m.program.declarations := by
    have hor : ∀ {α : Type} (x : Option α), x.or none = x := by
      intro α x; cases x <;> rfl
    simp [Materials.declarations, extend, hf, hi, lookup, hor]
  have checked := checkProgram_sound hd hb hdefs himpls hc hn h
  exact ⟨by simpa only [Materials.input, hD] using checked.1,
    checked.2.2.1, by simpa only [Materials.input, hD] using checked.2.2.2⟩
end Benitoite.Surface.CheckTables
