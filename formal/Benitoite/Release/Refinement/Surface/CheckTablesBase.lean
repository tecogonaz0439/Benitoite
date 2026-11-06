import Benitoite.Release.Refinement.Surface.CheckInput
import Benitoite.Release.Refinement.Surface.CheckVariance
import Benitoite.Release.Refinement.Surface.Theorems

/-! 宣言の有限な一覧と、同じ表の下で検査するプログラムの契約。 -/
namespace Benitoite.Release.Refinement.Surface.Check

theorem Input.Sound.withView {q : Input} (h : q.Sound) (v : CoverageView) :
    ({q with D := q.D.withView v} : Input).Sound := by
  refine ⟨h.formation, ?_, h.sat, h.admits, h.ranges, h.operators⟩
  exact ⟨⟨h.tables.dictionaries.impls⟩, h.tables.funs, h.tables.prims,
    h.tables.ops, h.tables.methods, h.tables.externals⟩

theorem Input.Sound.withProofSteps {q : Input} (h : q.Sound) (n : Nat) :
    ({q with proofSteps := n} : Input).Sound := by
  exact ⟨h.formation, h.tables, h.sat, h.admits, h.ranges, h.operators⟩

end Benitoite.Release.Refinement.Surface.Check

namespace Benitoite.Release.Refinement.Surface.CheckTables

/-- 利用者の宣言は同じ値を持ち、型の宣言は一致する。関数と実装の空欄は外部の署名で補える。 -/
def Extends (D base : Declarations) : Prop :=
  (∀ n d, base.funs n = some d → D.funs n = some d) ∧
  (∀ n d, base.impls n = some d → D.impls n = some d) ∧
  D.core = base.core ∧ D.conFields = base.conFields ∧
  D.aliases = base.aliases ∧ D.records = base.records ∧ D.testers = base.testers

theorem Extends.refl (D : Declarations) : Extends D D :=
  ⟨fun _ _ h => h, fun _ _ h => h, rfl, rfl, rfl, rfl, rfl⟩

/-- 各部分関数の実際の全 lookup が有限の名前の一覧に入っている。 -/
structure NamesComplete (q : Check.Input) (p : Program) : Prop where
  defs : ∀ n d, p.defs n = some d → n ∈ q.defs
  impls : ∀ n id, p.impls n = some id → n ∈ q.impls
  effects : ∀ n os, p.effects n = some os → n ∈ q.effects
  operations : ∀ n od, q.D.ops n = some od → n ∈ q.ops
  dataNames : CheckVariance.DataComplete q.D.core q.dataNames
  ctorNames : CheckVariance.CtorsComplete q.D.core q.ctorNames

/-- 表の名前と同じ鍵で検査する。一覧の重複は検査を省かない。 -/
def checkNamed (table : String → Option α) (check : List Nat → String → α → Check.Result Unit)
    (path : List Nat) : List String → Nat → Check.Result Unit
  | [], _ => .ok ()
  | n :: ns, i => do
      match table n with
      | none => pure ()
      | some a => check (path ++ [i]) n a
      checkNamed table check path ns (i + 1)

private theorem bind_ok {r s : Check.Result Unit} (h : (r >>= fun _ => s) = .ok ()) :
    r = .ok () ∧ s = .ok () := by
  cases r with
  | error e => cases h
  | ok u => cases u; exact ⟨rfl, h⟩

theorem checkNamed_sound {table : String → Option α} {check path names index}
    (h : checkNamed table check path names index = .ok ()) :
    ∀ n ∈ names, ∀ a, table n = some a → ∃ location, check location n a = .ok () := by
  induction names generalizing index with
  | nil => simp
  | cons name rest ih =>
    cases ht : table name with
    | none =>
      have tail : checkNamed table check path rest (index + 1) = .ok () := by
        simpa only [checkNamed, ht] using h
      intro n hn a ha
      rcases List.mem_cons.mp hn with rfl | hn
      · simp [ht] at ha
      · exact ih tail n hn a ha
    | some value =>
      have hh := bind_ok (show (check (path ++ [index]) name value >>= fun _ =>
        checkNamed table check path rest (index + 1)) = .ok () from by
          simpa only [checkNamed, ht] using h)
      intro n hn a ha
      rcases List.mem_cons.mp hn with rfl | hn
      · rw [ht] at ha
        cases Option.some.inj ha
        exact ⟨path ++ [index], hh.1⟩
      · exact ih hh.2 n hn a ha

/-- 同じ宣言表で利用者の本体を型付けし、宣言した変性と効果名の分離も検査したことを表す。 -/
structure CheckedUnder (p : Program) (q : Check.Input) : Prop where
  variance : q.D.core.VarianceValid
  defs : ∀ n d, p.defs n = some d → d.WellTyped (q.D.withView (p.functionViews n)) q.B q.opPrim
  extension : Extends q.D p.declarations
  effects : q.D.core.EffectsOk q.B
  impls : ∀ n id, p.impls n = some id → id.WellTyped q.D q.B q.opPrim (p.methodViews n)

/-- 外部の署名による補完が不要な場合の、プログラム自身の表の下での型付け。 -/
theorem CheckedUnder.wellTyped {p q} (h : CheckedUnder p q) (hD : q.D = p.declarations) :
    p.WellTyped q.B q.opPrim := by
  refine ⟨hD ▸ h.variance, ?_, ?_, ?_⟩
  · intro n d hd
    have hh := h.defs n d hd
    simpa only [hD, Program.declarations, Declarations.withView, Program.declarationsFor] using hh
  · intro i id hi
    have hh := h.impls i id hi
    rw [hD] at hh
    exact hh
  · have hh := h.effects
    rw [hD] at hh
    exact hh

end Benitoite.Release.Refinement.Surface.CheckTables
