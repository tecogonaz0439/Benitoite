import Benitoite.Surface.CheckTablesSound

/-! 信頼するシグネチャを補った宣言表のもとで、利用者の本体の型付けを結論する。
対応する検査と保証の範囲は設計書 07-04「証明する性質」に従う。 -/
namespace Benitoite.Surface.CheckTables
open Benitoite.Release Benitoite.Surface Benitoite.Surface.CheckTools

/-- 表の共有部分は同じであり、関数と実装の空欄だけを補う。 -/
def Extends (D base : Declarations) : Prop :=
  (∀ n d, base.funs n = some d → D.funs n = some d) ∧
  (∀ n d, base.impls n = some d → D.impls n = some d) ∧
  D.cons = base.cons ∧ D.conFields = base.conFields ∧
  D.ops = base.ops ∧ D.effects = base.effects ∧ D.classes = base.classes

theorem declarations_extend (m : Materials) : Extends m.declarations m.program.declarations := by
  refine ⟨?_, ?_, rfl, rfl, rfl, rfl, rfl⟩
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

/-- 本体の指定を選ぶ鍵も、検査に成功した値と同じ探索結果から得る。 -/
theorem checkNamed_key_sound {table : String → Option α}
    {check : List Nat → String → α → Check.Result Unit} {path names index}
    (h : checkNamed (fun n => (table n).map (fun x => (n, x)))
      (fun path (n, x) => check path n x) path names index = .ok ()) :
    ∀ n ∈ names, ∀ x, table n = some x → ∃ location, check location n x = .ok () := by
  intro n hn x hx
  exact checkNamed_sound h n hn (n, x) (by simp [hx])

/-- 同じ有限の材料から作った実名付き入力と、本体の射影を対応させる。 -/
theorem program_impl_input {m : Materials} {n id}
    (h : m.program.impls n = some id) :
    ∃ input, lookup (m.impls.map fun (n,i) => (n,i.input)) n = some input ∧ input.decl = id := by
  have map_lookup {α β : Type} (xs : List (String × α)) (f : α → β) (key : String) :
      lookup (xs.map fun (n,x) => (n,f x)) key = (lookup xs key).map f := by
    simp only [lookup, List.find?_map, Function.comp_def, Option.map_map]
  change lookup (m.impls.map fun (n,i) => (n,i.decl)) n = some id at h
  rw [map_lookup] at h
  cases hi : lookup m.impls n with
  | none => simp [hi] at h
  | some i =>
    simp only [hi, Option.map_some, Option.some.injEq] at h
    exact ⟨i.input, by rw [map_lookup, hi]; rfl, h⟩

/-- この結論は、信頼する標準ライブラリの本体を型付けしたとは主張しない。 -/
def CheckedUnder (p : Program) (q : Check.Input) : Prop :=
  (∀ n d, p.defs n = some d → d.WellTyped (q.D.withView (p.functionViews n)) q.B q.opPrim) ∧
  Extends q.D p.declarations ∧
  (∀ l os, p.effects l = some os → q.B.effects l = none) ∧
  (∀ n id, p.impls n = some id → id.WellTyped q.D q.B q.opPrim (p.methodViews n))

theorem checkProgram_under {q : Check.Input} {m : Materials} {names : Names}
    (hq : q.Sound) (hn : NamesComplete m.program names)
    (hd : ∀ n d, m.program.defs n = some d → d.AtomsIn q.atoms)
    (hi : ∀ n id, m.program.impls n = some id → id.AtomsIn q.atoms)
    (him : ∀ n id, lookup (m.impls.map fun (n,i) => (n,i.input)) n = some id → Check.ImplNamesComplete q id names.methods names.supers)
    (hext : Extends q.D m.program.declarations)
    (h : checkProgram q m names = .ok ()) : CheckedUnder m.program q := by
  have steps := bind_ok (Check.guardResult_ok h)
  have more := bind_ok steps.2
  refine ⟨?_, hext, ?_, ?_⟩
  · intro n d hget
    obtain ⟨path, hp⟩ := checkNamed_key_sound (check := fun path n d => Check.checkDef
      { q with D := q.D.withView (m.program.functionViews n) } path d) steps.1 n (hn.1 n d hget) d hget
    exact Check.checkDef_sound (hq.withView _) (hd n d hget) hp
  · intro l os hget
    have hmap : (m.program.effects l).map (fun _ => l) = some l := by simp [hget]
    obtain ⟨path, hp⟩ := checkNamed_sound more.2 l (hn.2.2 l os hget) l hmap
    unfold Check.require at hp
    split at hp
    · simpa using ‹(q.B.effects l).isNone = true›
    · cases hp
  · intro n id hget
    obtain ⟨input, hinput, hdecl⟩ := program_impl_input hget
    obtain ⟨path, hp⟩ := checkNamed_key_sound (check := fun path n id =>
      Check.checkImpl q names.methods names.supers path id (m.program.methodViews n)) more.1 n (hn.2.1 n id hget) input hinput
    rw [← hdecl]
    exact Check.checkImpl_sound hq (by rw [hdecl]; exact hi n id hget) (him n input hinput) hp

/-- 実装の本体へ射影する前の、全プログラムの引数名の保証。 -/
theorem checkProgram_contracts {m : Materials} {B sat admits op atoms}
    (hn : implNamesOk m m.names.methods m.names.supers = true)
    (h : checkProgram (m.input B sat admits op atoms) m m.names = .ok ()) :
    ∀ n id, lookup (m.impls.map fun (n,i) => (n,i.input)) n = some id →
      id.ContractsMatch m.declarations := by
  have steps := bind_ok (Check.guardResult_ok h)
  have more := bind_ok steps.2
  intro n id hget
  have hmem := lookup_mem hget
  obtain ⟨⟨name,i⟩, hi, he⟩ := List.mem_map.mp hmem
  simp only [Prod.mk.injEq] at he
  obtain ⟨rfl, rfl⟩ := he
  have hname : name ∈ m.names.impls := List.mem_map.mpr ⟨(name,i), hi, rfl⟩
  obtain ⟨path, hp⟩ := checkNamed_key_sound (check := fun path n id =>
    Check.checkImpl (m.input B sat admits op atoms) m.names.methods m.names.supers path id
      (m.program.methodViews n)) more.1 name hname i.input hget
  exact Check.checkImpl_contracts (implNames_sound hn hget) hp

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
theorem checkProgram_sound {m : Materials} {S raw b select atoms}
    (hd : m.declarations.AtomsIn atoms)
    (hb : (builtins S (primEntries S raw) b).AtomsIn atoms)
    (hdefs : ∀ n d, m.program.defs n = some d → d.body.AtomsIn atoms)
    (himpls : ∀ n id, m.program.impls n = some id → ImplBodiesAtoms atoms id)
    (hc : constructorsOk m = true)
    (hn : implNamesOk m m.names.methods m.names.supers = true)
    (h : checkProgram
      (m.input (builtins S (primEntries S raw) b) (satB S) (admitsDec S (primEntries S raw))
        (makeOpPrim select) atoms) m m.names = .ok ()) :
    CheckedUnder m.program
      (m.input (builtins S (primEntries S raw) b) (satB S) (admitsDec S (primEntries S raw))
        (makeOpPrim select) atoms) := by
  apply checkProgram_under (input_sound hd hb hc) (names_complete m)
  · intro n d hget; exact def_atoms hd hget (hdefs n d hget)
  · intro n id hget; exact impl_atoms hd hget (himpls n id hget)
  · intro n id hi; exact implNames_sound hn hi
  · exact declarations_extend m
  · exact h

theorem checkProgram_empty {m : Materials} {S raw b select atoms}
    (hf : m.trustedFuns = []) (hi : m.trustedImpls = [])
    (hd : m.declarations.AtomsIn atoms)
    (hb : (builtins S (primEntries S raw) b).AtomsIn atoms)
    (hdefs : ∀ n d, m.program.defs n = some d → d.body.AtomsIn atoms)
    (himpls : ∀ n id, m.program.impls n = some id → ImplBodiesAtoms atoms id)
    (hc : constructorsOk m = true)
    (hn : implNamesOk m m.names.methods m.names.supers = true)
    (h : checkProgram
      (m.input (builtins S (primEntries S raw) b) (satB S) (admitsDec S (primEntries S raw))
        (makeOpPrim select) atoms) m m.names = .ok ()) :
    m.program.WellTyped (builtins S (primEntries S raw) b)
      (makeOpPrim select) := by
  have hD : m.declarations = m.program.declarations := by
    have hor : ∀ {α : Type} (x : Option α), x.or none = x := by
      intro α x; cases x <;> rfl
    simp [Materials.declarations, extend, hf, hi, lookup, hor]
  have checked := checkProgram_sound hd hb hdefs himpls hc hn h
  simp only [CheckedUnder, Materials.input] at checked
  rw [hD] at checked
  exact ⟨checked.1, checked.2.2.1, checked.2.2.2⟩

/-- 型付けと、射影前の実装の実名一致を同じ検査成功から得る。 -/
theorem checkProgram_sound_contracts {m : Materials} {S raw b select atoms}
    (hd : m.declarations.AtomsIn atoms)
    (hb : (builtins S (primEntries S raw) b).AtomsIn atoms)
    (hdefs : ∀ n d, m.program.defs n = some d → d.body.AtomsIn atoms)
    (himpls : ∀ n id, m.program.impls n = some id → ImplBodiesAtoms atoms id)
    (hc : constructorsOk m = true)
    (hn : implNamesOk m m.names.methods m.names.supers = true)
    (h : checkProgram
      (m.input (builtins S (primEntries S raw) b) (satB S) (admitsDec S (primEntries S raw))
        (makeOpPrim select) atoms) m m.names = .ok ()) :
    CheckedUnder m.program
      (m.input (builtins S (primEntries S raw) b) (satB S) (admitsDec S (primEntries S raw))
        (makeOpPrim select) atoms) ∧
    (∀ n id, lookup (m.impls.map fun (n,i) => (n,i.input)) n = some id →
      id.ContractsMatch m.declarations) := by
  exact ⟨checkProgram_sound hd hb hdefs himpls hc hn h, checkProgram_contracts hn h⟩

/-- 信頼する宣言が空の場合も、型付けと実名一致を同時に保証する。 -/
theorem checkProgram_empty_contracts {m : Materials} {S raw b select atoms}
    (hf : m.trustedFuns = []) (hi : m.trustedImpls = [])
    (hd : m.declarations.AtomsIn atoms)
    (hb : (builtins S (primEntries S raw) b).AtomsIn atoms)
    (hdefs : ∀ n d, m.program.defs n = some d → d.body.AtomsIn atoms)
    (himpls : ∀ n id, m.program.impls n = some id → ImplBodiesAtoms atoms id)
    (hc : constructorsOk m = true)
    (hn : implNamesOk m m.names.methods m.names.supers = true)
    (h : checkProgram
      (m.input (builtins S (primEntries S raw) b) (satB S) (admitsDec S (primEntries S raw))
        (makeOpPrim select) atoms) m m.names = .ok ()) :
    m.program.WellTyped (builtins S (primEntries S raw) b)
      (makeOpPrim select) ∧
    (∀ n id, lookup (m.impls.map fun (n,i) => (n,i.input)) n = some id →
      id.ContractsMatch m.declarations) := by
  exact ⟨checkProgram_empty hf hi hd hb hdefs himpls hc hn h, checkProgram_contracts hn h⟩
end Benitoite.Surface.CheckTables
