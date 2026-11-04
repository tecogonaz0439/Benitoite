import Benitoite.Release.Refinement.AtPrepare
namespace L50InternalSave
open Benitoite.Release.Refinement

/-- 生の入力の型に対して正の位置だけを持つ内部保存の形。 -/
structure Detail (Raw : Type) where
  failure : AtFailure
  originalPattern : Raw
  originalTarget : Raw
  parsedPattern : Option RangeExpr
  parsedTarget : Option TargetInput
  resolvedPatterns : Option (List Benitoite.Scope.Domain.Range)
  resolvedTarget : Option Benitoite.Scope.Domain.Target
  patternBase : Option PathBase
  targetBase : Option PathBase

def save {Raw : Type} (rawPattern rawTarget : Raw) (snapshot : Option PathEnv)
    (parsedPattern : Option RangeExpr) (parsedTarget : Option TargetInput)
    (failure : AtFailure) : Detail Raw where
  failure := failure
  originalPattern := rawPattern
  originalTarget := rawTarget
  parsedPattern := parsedPattern
  parsedTarget := parsedTarget
  resolvedPatterns := parsedPattern.bind (resolveSnapshot snapshot)
  resolvedTarget := parsedTarget.bind (resolveTargetSnapshot snapshot)
  patternBase := parsedPattern.bind RangeExpr.base?
  targetBase := parsedTarget.bind TargetInput.base?

/-- 任意入力・全失敗・全原子列について、九欄を切り詰めず保持する。 -/
theorem save_exact {Raw : Type} (p t : Raw) (snapshot : Option PathEnv)
    (pp : Option RangeExpr) (pt : Option TargetInput) (f : AtFailure) :
    let d := save p t snapshot pp pt f
    d.originalPattern = p ∧ d.originalTarget = t ∧ d.failure = f ∧
    d.parsedPattern = pp ∧ d.parsedTarget = pt ∧
    d.resolvedPatterns = pp.bind (resolveSnapshot snapshot) ∧
    d.resolvedTarget = pt.bind (resolveTargetSnapshot snapshot) ∧
    d.patternBase = pp.bind RangeExpr.base? ∧ d.targetBase = pt.bind TargetInput.base? :=
  ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

example (p t : Val) (snapshot : Option PathEnv) :
    (save p t snapshot none none .invalidPattern).originalPattern = p ∧
    (save p t snapshot none none .invalidPattern).originalTarget = t ∧
    (save p t snapshot none none .invalidPattern).parsedPattern = none ∧
    (save p t snapshot none none .invalidPattern).resolvedPatterns = none :=
  ⟨rfl,rfl,rfl,rfl⟩

/-- 生の入力に値を保持する形は、既存の相互構文にも正に埋め込める。 -/
inductive Stored where
  | raw (value : Val)
  | error (detail : Detail Stored)

example (p t : Val) :
    ∃ d : Detail Stored, d.originalPattern = .raw p ∧ d.originalTarget = .raw t :=
  ⟨save (.raw p) (.raw t) none none none .invalidTarget,rfl,rfl⟩
end L50InternalSave
