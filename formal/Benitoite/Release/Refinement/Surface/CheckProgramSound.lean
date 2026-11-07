import Benitoite.Release.Refinement.Surface.CheckTables
import Benitoite.Release.Refinement.Surface.CheckDeclarationsSound

/-! 全入力の有限検査の成功を、プログラム全体の表層の型付けへ接続する。 -/
namespace Benitoite.Release.Refinement.Surface.CheckTables
open CheckDeclarations

private theorem bind_ok {r s : Check.Result Unit} (h : (r >>= fun _ => s) = .ok ()) :
    r = .ok () ∧ s = .ok () := by
  cases r with
  | error e => cases h
  | ok u => cases u; exact ⟨rfl, h⟩

private theorem require_ok {path reason ok} (h : Check.require path reason ok = .ok ()) : ok = true := by
  unfold Check.require at h
  split at h
  · assumption
  · cases h

private theorem program_parts {q p} (h : checkPreparedProgram q p = .ok ()) :
    CheckVariance.check q.formation q.D.core q.dataNames q.ctorNames = true ∧ effectsCheck q = true ∧
    checkNamed p.defs (fun path n d => checkDef {q with D := q.D.withView (p.functionViews n), proofSteps := q.functionSteps n} path d) [0] q.defs 0 = .ok () ∧
    checkNamed p.impls (fun path n id => checkImpl q n path id (p.methodViews n)) [1] q.impls 0 = .ok () := by
  unfold checkPreparedProgram at h
  obtain ⟨hv, hr⟩ := bind_ok h
  obtain ⟨he, hr⟩ := bind_ok hr
  obtain ⟨hd, hi⟩ := bind_ok hr
  exact ⟨require_ok hv, require_ok he, hd, hi⟩

/-- 一覧の完全性と入力の有限支持の下で、全定義と全実装を同じ宣言表で型付ける。 -/
theorem checkPreparedProgram_sound {q : Check.Input} {p : Program}
    (hq : q.Sound) (hn : NamesComplete q p)
    (hd : ∀ n d, p.defs n = some d → DefSupport q d)
    (hi : ∀ n id, p.impls n = some id → ImplSupport q id)
    (him : ∀ n id, p.impls n = some id → ImplNamesComplete q id)
    (hext : Extends q.D p.declarations) (h : checkPreparedProgram q p = .ok ()) : CheckedUnder p q := by
  obtain ⟨hv, he, hdefs, himpls⟩ := program_parts h
  refine ⟨CheckVariance.check_sound hq.formation hn.dataNames hn.ctorNames hv, ?_, hext, ?_, ?_⟩
  · intro n d hget
    obtain ⟨path, hp⟩ := checkNamed_sound hdefs n (hn.defs n d hget) d hget
    exact checkDef_sound ((hq.withView _).withProofSteps _)
      ⟨(hd n d hget).signature, (hd n d hget).body⟩ (fun _ => hn.ctorNames) hp
  · apply effectsCheck_sound (ho := hn.operations) (h := he)
    intro l os hget
    have heffects : q.D.effects = p.effects := congrArg Refinement.Program.effects hext.2.2.1
    rw [heffects] at hget
    exact hn.effects l os hget
  · intro n id hget
    obtain ⟨path, hp⟩ := checkNamed_sound himpls n (hn.impls n id hget) id hget
    exact checkImpl_sound hq (hi n id hget) (him n id hget) hp

/-- 宣言の補完が無いとき、成功したプログラムは自身の宣言表で型付く。 -/
theorem checkPreparedProgram_empty {q : Check.Input} {p : Program}
    (hq : q.Sound) (hn : NamesComplete q p)
    (hd : ∀ n d, p.defs n = some d → DefSupport q d)
    (hi : ∀ n id, p.impls n = some id → ImplSupport q id)
    (him : ∀ n id, p.impls n = some id → ImplNamesComplete q id)
    (hD : q.D = p.declarations)
    (h : checkPreparedProgram q p = .ok ()) : p.WellTyped q.B q.opPrim :=
  (checkPreparedProgram_sound hq hn hd hi him (by rw [hD]; exact Extends.refl _) h).wellTyped hD

/-- 全実装の実際のメソッド名は、クラスの同じメソッドの契約名と一致する。 -/
theorem checkPreparedProgram_contracts {q : Check.Input} {p : Program}
    (hn : NamesComplete q p) (him : ∀ n id, p.impls n = some id → ImplNamesComplete q id)
    (h : checkPreparedProgram q p = .ok ()) :
    ∀ i id, p.impls i = some id → ContractsMatch q i id := by
  have hi := (program_parts h).2.2.2
  intro i id hget
  obtain ⟨path, hp⟩ := checkNamed_sound hi i (hn.impls i id hget) id hget
  exact checkImpl_contracts (him i id hget) hp

/-- 型付けと、射影前のメソッドの実名の一致を同じ成功結果から得る。 -/
theorem checkPreparedProgram_sound_contracts {q : Check.Input} {p : Program}
    (hq : q.Sound) (hn : NamesComplete q p)
    (hd : ∀ n d, p.defs n = some d → DefSupport q d)
    (hi : ∀ n id, p.impls n = some id → ImplSupport q id)
    (him : ∀ n id, p.impls n = some id → ImplNamesComplete q id)
    (hext : Extends q.D p.declarations) (h : checkPreparedProgram q p = .ok ()) :
    CheckedUnder p q ∧ ∀ i id, p.impls i = some id → ContractsMatch q i id :=
  ⟨checkPreparedProgram_sound hq hn hd hi him hext h, checkPreparedProgram_contracts hn him h⟩

/-- 自身の宣言表での型付けと、実際のメソッド名の一致を同時に得る。 -/
theorem checkPreparedProgram_empty_contracts {q : Check.Input} {p : Program}
    (hq : q.Sound) (hn : NamesComplete q p)
    (hd : ∀ n d, p.defs n = some d → DefSupport q d)
    (hi : ∀ n id, p.impls n = some id → ImplSupport q id)
    (him : ∀ n id, p.impls n = some id → ImplNamesComplete q id)
    (hD : q.D = p.declarations)
    (h : checkPreparedProgram q p = .ok ()) :
    p.WellTyped q.B q.opPrim ∧ ∀ i id, p.impls i = some id → ContractsMatch q i id :=
  ⟨checkPreparedProgram_empty hq hn hd hi him hD h, checkPreparedProgram_contracts hn him h⟩

/-- 本体の解決は、検査する定義と実装の名前、効果と構成子の一覧を保つ。 -/
theorem prepare_names {q : Check.Input} {p : Program} (hn : NamesComplete q p) :
    NamesComplete (CheckPreparation.prepare q p).input (CheckPreparation.prepare q p).program := by
  rcases CheckPreparation.prepare_cases q p with h | ⟨rows,h⟩
  · rw [h]; exact hn
  · rw [h]
    refine ⟨?_, ?_, hn.effects, hn.operations, hn.dataNames, hn.ctorNames⟩
    · intro name d found
      obtain ⟨original,ho,_⟩ := Option.map_eq_some_iff.mp found
      exact hn.defs name original ho
    · intro name id found
      obtain ⟨original,ho,_⟩ := Option.map_eq_some_iff.mp found
      exact hn.impls name original ho

/-- 実装の本体を解決しても、同じ実在するメソッドと上位辞書を列挙する。 -/
theorem prepare_impl_names {q : Check.Input} {p : Program}
    (hn : ∀ n id, p.impls n = some id → ImplNamesComplete q id) :
    ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id →
      ImplNamesComplete (CheckPreparation.prepare q p).input id := by
  rcases CheckPreparation.prepare_cases q p with h | ⟨rows,h⟩
  · rw [h]; exact hn
  · rw [h]
    intro name id found
    obtain ⟨original,ho,rfl⟩ := Option.map_eq_some_iff.mp found
    have hc := hn name original ho
    refine ⟨?_, hc.supers⟩
    intro cd hd method hm
    apply hc.methods cd hd method
    simpa only [Option.isSome_map] using hm

/-- 入力の準備は宣言表を保つ。外部の署名を補った入力にも適用できる。 -/
theorem prepare_extension {q : Check.Input} {p : Program} (h : Extends q.D p.declarations) :
    Extends (CheckPreparation.prepare q p).input.D (CheckPreparation.prepare q p).program.declarations := by
  rw [CheckPreparation.prepare_declarations]
  rcases CheckPreparation.prepare_cases q p with ready | ⟨rows,ready⟩
  · rw [ready]; exact h
  · rw [ready]; exact h

/-- 収集・解決した全プログラムを、実入口と同じ表で型付ける。 -/
theorem checkProgram_sound {q : Check.Input} {p : Program}
    (hq : (CheckPreparation.prepare q p).input.Sound) (hn : NamesComplete (CheckPreparation.prepare q p).input (CheckPreparation.prepare q p).program)
    (hd : ∀ n d, (CheckPreparation.prepare q p).program.defs n = some d → DefSupport (CheckPreparation.prepare q p).input d)
    (hi : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id → ImplSupport (CheckPreparation.prepare q p).input id)
    (him : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id → ImplNamesComplete (CheckPreparation.prepare q p).input id)
    (hext : Extends (CheckPreparation.prepare q p).input.D (CheckPreparation.prepare q p).program.declarations) (h : checkProgram q p = .ok ()) : CheckedUnder (CheckPreparation.prepare q p).program (CheckPreparation.prepare q p).input :=
  checkPreparedProgram_sound hq hn hd hi him hext h

/-- 収集・解決した全プログラムを、実入口と同じ表で型付ける。 -/
theorem checkProgram_empty {q : Check.Input} {p : Program}
    (hq : (CheckPreparation.prepare q p).input.Sound) (hn : NamesComplete (CheckPreparation.prepare q p).input (CheckPreparation.prepare q p).program)
    (hd : ∀ n d, (CheckPreparation.prepare q p).program.defs n = some d → DefSupport (CheckPreparation.prepare q p).input d)
    (hi : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id → ImplSupport (CheckPreparation.prepare q p).input id)
    (him : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id → ImplNamesComplete (CheckPreparation.prepare q p).input id)
    (hD : (CheckPreparation.prepare q p).input.D = (CheckPreparation.prepare q p).program.declarations)
    (h : checkProgram q p = .ok ()) : (CheckPreparation.prepare q p).program.WellTyped (CheckPreparation.prepare q p).input.B (CheckPreparation.prepare q p).input.opPrim :=
  checkPreparedProgram_empty hq hn hd hi him hD h

/-- 収集・解決した全プログラムを、実入口と同じ表で型付ける。 -/
theorem checkProgram_contracts {q : Check.Input} {p : Program}
    (hn : NamesComplete (CheckPreparation.prepare q p).input (CheckPreparation.prepare q p).program) (him : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id → ImplNamesComplete (CheckPreparation.prepare q p).input id)
    (h : checkProgram q p = .ok ()) :
    ∀ i id, (CheckPreparation.prepare q p).program.impls i = some id → ContractsMatch (CheckPreparation.prepare q p).input i id :=
  checkPreparedProgram_contracts hn him h

/-- 収集・解決した全プログラムを、実入口と同じ表で型付ける。 -/
theorem checkProgram_sound_contracts {q : Check.Input} {p : Program}
    (hq : (CheckPreparation.prepare q p).input.Sound) (hn : NamesComplete (CheckPreparation.prepare q p).input (CheckPreparation.prepare q p).program)
    (hd : ∀ n d, (CheckPreparation.prepare q p).program.defs n = some d → DefSupport (CheckPreparation.prepare q p).input d)
    (hi : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id → ImplSupport (CheckPreparation.prepare q p).input id)
    (him : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id → ImplNamesComplete (CheckPreparation.prepare q p).input id)
    (hext : Extends (CheckPreparation.prepare q p).input.D (CheckPreparation.prepare q p).program.declarations) (h : checkProgram q p = .ok ()) :
    CheckedUnder (CheckPreparation.prepare q p).program (CheckPreparation.prepare q p).input ∧ ∀ i id, (CheckPreparation.prepare q p).program.impls i = some id → ContractsMatch (CheckPreparation.prepare q p).input i id :=
  checkPreparedProgram_sound_contracts hq hn hd hi him hext h

/-- 収集・解決した全プログラムを、実入口と同じ表で型付ける。 -/
theorem checkProgram_empty_contracts {q : Check.Input} {p : Program}
    (hq : (CheckPreparation.prepare q p).input.Sound) (hn : NamesComplete (CheckPreparation.prepare q p).input (CheckPreparation.prepare q p).program)
    (hd : ∀ n d, (CheckPreparation.prepare q p).program.defs n = some d → DefSupport (CheckPreparation.prepare q p).input d)
    (hi : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id → ImplSupport (CheckPreparation.prepare q p).input id)
    (him : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id → ImplNamesComplete (CheckPreparation.prepare q p).input id)
    (hD : (CheckPreparation.prepare q p).input.D = (CheckPreparation.prepare q p).program.declarations)
    (h : checkProgram q p = .ok ()) :
    (CheckPreparation.prepare q p).program.WellTyped (CheckPreparation.prepare q p).input.B (CheckPreparation.prepare q p).input.opPrim ∧ ∀ i id, (CheckPreparation.prepare q p).program.impls i = some id → ContractsMatch (CheckPreparation.prepare q p).input i id :=
  checkPreparedProgram_empty_contracts hq hn hd hi him hD h

end Benitoite.Release.Refinement.Surface.CheckTables
