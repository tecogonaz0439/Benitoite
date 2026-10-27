import Benitoite.Interval.Range

/-!
# 局所解析で使う標準宣言と出現表の保存

局所位置と補助記録を変えても、元の標準宣言の同定を変えない。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis.CallReach
open Benitoite.Surface Benitoite.Release

@[simp] theorem tables_update (env : AbstractEnv) (locals : List AbstractSlot) (ranges : RangeState) :
    rangeTables { env with locals := locals, ranges := ranges } = rangeTables env := rfl

@[simp] theorem tables_locals (env : AbstractEnv) (locals : List AbstractSlot) :
    rangeTables { env with locals := locals } = rangeTables env := rfl

@[simp] theorem tables_ranges (env : AbstractEnv) (ranges : RangeState) :
    rangeTables { env with ranges := ranges } = rangeTables env := rfl

@[simp] theorem tables_clear (env : AbstractEnv) : rangeTables (clearLocals env) = rangeTables env := rfl
@[simp] theorem tables_reset (env : AbstractEnv) : rangeTables (resetRanges env) = rangeTables env := rfl
@[simp] theorem tables_forget (env : AbstractEnv) : rangeTables (forget env) = rangeTables env := rfl
@[simp] theorem tables_extend (env : AbstractEnv) (slot : AbstractSlot) :
    rangeTables (extend env slot) = rangeTables env := rfl

@[simp] theorem tables_pattern (env pattern type) :
    rangeTables (extendPattern env pattern type) = rangeTables env := by
  cases pattern <;> rfl

@[simp] theorem tables_resultArm (env input alts) :
    rangeTables (baseResultArmEnv env input alts) = rangeTables env := by
  unfold baseResultArmEnv
  split <;> first | rfl | (split <;> rfl)

def SameOptionTables (env : AbstractEnv) (result : Option AbstractEnv) : Prop :=
  ∀ inner, result = some inner → rangeTables inner = rangeTables env

theorem tables_join (base : AbstractEnv) (left right : Option AbstractEnv)
    (hl : SameOptionTables base left) (hr : SameOptionTables base right) :
    SameOptionTables base (joinConditionEnvs base left right) := by
  intro inner found
  cases left <;> cases right <;> simp only [joinConditionEnvs] at found
  · contradiction
  · exact hr inner found
  · exact hl inner found
  · cases found; rfl

theorem tables_option_bind {env : AbstractEnv} {first : Option AbstractEnv}
    {next : AbstractEnv → Option AbstractEnv} (hf : SameOptionTables env first)
    (hn : ∀ middle, SameOptionTables middle (next middle)) :
    SameOptionTables env (first.bind next) := by
  intro inner found
  obtain ⟨middle, atMiddle, atInner⟩ := Option.bind_eq_some_iff.mp found
  exact (hn middle inner atInner).trans (hf middle atMiddle)

theorem tables_atomic (env source truth) : SameOptionTables env (atomicConditionEnv env source truth) := by
  intro inner found
  unfold atomicConditionEnv at found
  split at found
  · unfold kindAtomicConditionEnv at found
    split at found
    · cases found; rfl
    · split at found
      · contradiction
      · cases found; rfl
  · split at found
    · contradiction
    · cases found; rfl

theorem tables_condition (env : AbstractEnv) (source : Expr) (truth : Bool) :
    SameOptionTables env (conditionEnv env source truth) := by
  cases source <;> try exact tables_atomic env _ truth
  case literal value =>
    cases value <;> try exact tables_atomic env _ truth
    intro inner found
    simp only [conditionEnv] at found
    split at found
    · cases found; rfl
    · contradiction
  case paren child => exact tables_condition env child truth
  case not child => exact tables_condition env child (!truth)
  case and left right =>
    cases truth
    · exact tables_join env _ _ (tables_condition env left false)
        (tables_option_bind (tables_condition env left true) (fun inner => tables_condition inner right false))
    · exact tables_option_bind (tables_condition env left true) (fun inner => tables_condition inner right true)
  case or left right =>
    cases truth
    · exact tables_option_bind (tables_condition env left false) (fun inner => tables_condition inner right false)
    · exact tables_join env _ _ (tables_condition env left true)
        (tables_option_bind (tables_condition env left false) (fun inner => tables_condition inner right true))
termination_by surfaceSize source

theorem tables_branch (env source normal truth) : SameOptionTables env (branchEnv env source normal truth) := by
  unfold branchEnv
  split <;> split
  all_goals first | exact tables_condition env source truth | (intro inner found; contradiction)

theorem tables_extendMatch (env slots positions) : SameOptionTables env (extendMatchSlots env slots positions) := by
  intro inner found
  unfold extendMatchSlots at found
  cases selected : selectSlots slots positions <;> simp [selected] at found
  cases found; rfl

theorem tables_alternative (env source type normal alt) :
    SameOptionTables env (matchAlternativeEnv env source type normal alt) := by
  intro inner found
  unfold matchAlternativeEnv at found
  split at found
  all_goals dsimp only at found
  all_goals first
    | (split at found; contradiction; exact (tables_extendMatch _ _ _ inner found).trans (by
        unfold matchScrutineeEnv; split <;> first | rfl | (split <;> rfl)))
    | exact (tables_extendMatch _ _ _ inner found).trans (by
        unfold matchScrutineeEnv; split <;> first | rfl | (split <;> rfl))

theorem tables_kindAlternative (env source kind normal alt) :
    SameOptionTables env (matchKindAlternativeEnv env source kind normal alt) := by
  intro inner found
  unfold matchKindAlternativeEnv at found
  dsimp only at found
  split at found
  · contradiction
  ·
    exact (tables_extendMatch _ _ _ inner found).trans (by
      unfold matchKindScrutineeEnv
      split <;> rfl)

theorem tables_alternatives (template env source type normal alts)
    (same : rangeTables template = rangeTables env) :
    SameOptionTables env (matchAlternativesEnv template env source type normal alts) := by
  induction alts with
  | nil => intro inner found; contradiction
  | cons alt rest ih =>
    intro inner found
    exact (tables_join template _ _
      (fun value ok => (tables_alternative env source type normal alt value ok).trans same.symm)
      (fun value ok => (ih value ok).trans same.symm) inner found).trans same

theorem tables_kindAlternatives (template env source kind normal alts)
    (same : rangeTables template = rangeTables env) :
    SameOptionTables env (matchKindAlternativesEnv template env source kind normal alts) := by
  induction alts with
  | nil => intro inner found; contradiction
  | cons alt rest ih =>
    intro inner found
    exact (tables_join template _ _
      (fun value ok => (tables_kindAlternative env source kind normal alt value ok).trans same.symm)
      (fun value ok => (ih value ok).trans same.symm) inner found).trans same

theorem tables_arm (env source kind normal alts) :
    SameOptionTables env (matchKindArmEnv env source kind normal alts) := by
  cases kind with
  | integer64 => exact tables_alternatives _ _ _ _ _ _ rfl
  | integer8 | integer16 | integer32 | unsignedInteger16 | unsignedInteger32 | unsignedInteger64 =>
    exact tables_kindAlternatives _ _ _ _ _ _ rfl

end Benitoite.Interval.BudgetAnalysis.CallReach
