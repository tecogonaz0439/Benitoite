import Benitoite.Release.Typing

/-!
# 観測と記号付き範囲の有限構文

実行ごとに固定する基準の写しを値として保持する。静的な判断に実行の環境を渡さない。
-/
namespace Benitoite.Release.Refinement

inductive PathBase where
  | root | cwd | home | work | tmp
  deriving DecidableEq, Repr

structure PathEnv where
  root : Scope.Domain.Word
  cwd : Scope.Domain.Word
  home : Scope.Domain.Word
  work : Option Scope.Domain.Word
  tmp : Option Scope.Domain.Word
  secrets : Option (List Scope.Domain.PathPattern)
  deriving DecidableEq, Repr

inductive RangeExpr where
  | absolute (range : Scope.Domain.Range)
  | based (base : PathBase) (pattern : Scope.Domain.PathPattern)
  | secrets
  deriving DecidableEq, Repr

inductive RangeIx where
  | fixed (range : RangeExpr)
  | rvar (index : Nat)
  deriving DecidableEq

@[match_pattern] abbrev RangeExpr.top : RangeExpr := .absolute .top
@[match_pattern] abbrev RangeExpr.path (p : Scope.Domain.PathPattern) : RangeExpr := .absolute (.path p)
@[match_pattern] abbrev RangeExpr.host (p : Scope.Domain.HostPattern) : RangeExpr := .absolute (.host p)
@[match_pattern] abbrev RangeExpr.endpoint (p : Scope.Domain.EndpointPattern) : RangeExpr := .absolute (.endpoint p)
abbrev RangeIx.top : RangeIx := .fixed .top

inductive Atom where
  | name (effect : EffName) (index : RangeIx)
  | rho (index : Nat)
  deriving DecidableEq

abbrev Atom.nameTop (l : EffName) : Atom := .name l .top

def embedAtom : Benitoite.Release.Atom → Atom
  | .name l (.fixed r) => .name l (.fixed (.absolute r))
  | .name l (.rvar i) => .name l (.rvar i)
  | .rho i => .rho i

def Atom.toOld? : Atom → Option Benitoite.Release.Atom
  | .name l (.fixed (.absolute r)) => some (.name l (.fixed r))
  | .name l (.rvar i) => some (.name l (.rvar i))
  | .rho i => some (.rho i)
  | _ => none

@[simp] theorem Atom.toOld?_embed (a : Benitoite.Release.Atom) : (embedAtom a).toOld? = some a := by
  rcases a with ⟨_, _ | _⟩ | _ <;> rfl

theorem Atom.toOld?_sound {a : Atom} {b : Benitoite.Release.Atom} (h : a.toOld? = some b) :
    embedAtom b = a := by
  rcases a with ⟨l, (r | i)⟩ | i
  · cases r <;> cases h <;> rfl
  · cases h; rfl
  · cases h; rfl

def embedAtoms (f : Benitoite.Release.Atom → Bool) (a : Atom) : Bool :=
  (a.toOld?.map f).getD false

@[simp] theorem embedAtoms_embed (f : Benitoite.Release.Atom → Bool) (a : Benitoite.Release.Atom) :
    embedAtoms f (embedAtom a) = f a := by simp [embedAtoms]

theorem embedAtoms_true (f : Benitoite.Release.Atom → Bool) (a : Atom) :
    embedAtoms f a = true ↔ ∃ b, f b = true ∧ embedAtom b = a := by
  constructor
  · intro h
    cases ho : a.toOld? with
    | none => simp [embedAtoms, ho] at h
    | some b => exact ⟨b, by simpa [embedAtoms, ho] using h, Atom.toOld?_sound ho⟩
  · rintro ⟨b, hb, rfl⟩
    simpa only [embedAtoms_embed] using hb

def RangeIx.inst (rs : List RangeExpr) : RangeIx → RangeIx
  | .fixed r => .fixed r
  | .rvar i => match rs[i]? with
    | some r => .fixed r
    | none => .rvar i

def RangeIx.WF (nr : Nat) : RangeIx → Prop
  | .fixed _ => True
  | .rvar i => i < nr

def embedRange : Scope.Domain.Range → RangeExpr := RangeExpr.absolute

def embedIx : Scope.Signature.Ix → RangeIx
  | .fixed r => .fixed (.absolute r)
  | .rvar i => .rvar i

def RangeIx.toOld? : RangeIx → Option Scope.Signature.Ix
  | .fixed (.absolute r) => some (.fixed r)
  | .rvar i => some (.rvar i)
  | _ => none

@[simp] theorem RangeIx.toOld?_embed (ix : Scope.Signature.Ix) : (embedIx ix).toOld? = some ix := by
  cases ix <;> rfl

theorem RangeIx.toOld?_sound {a : RangeIx} {b : Scope.Signature.Ix} (h : a.toOld? = some b) :
    embedIx b = a := by
  cases a with
  | fixed r => cases r <;> cases h <;> rfl
  | rvar i => cases h; rfl

@[simp] theorem RangeIx.inst_nil (ix : RangeIx) : ix.inst [] = ix := by
  cases ix <;> rfl

@[simp] theorem RangeIx.inst_fixed (rs : List RangeExpr) (r : RangeExpr) :
    (RangeIx.fixed r).inst rs = .fixed r := rfl

theorem embedIx_injective : Function.Injective embedIx := by
  intro a b h
  cases a <;> cases b <;> simp_all [embedIx]

theorem embedIx_inst (ix : Scope.Signature.Ix) (rs : List Scope.Domain.Range) :
    embedIx (ix.inst rs) = (embedIx ix).inst (rs.map embedRange) := by
  cases ix with
  | fixed r => rfl
  | rvar i =>
    simp only [Scope.Signature.Ix.inst, embedIx, RangeIx.inst, List.getElem?_map]
    cases rs[i]? <;> rfl

theorem embedIx_wf {nr : Nat} {ix : Scope.Signature.Ix} (h : ix.WF nr) :
    (embedIx ix).WF nr := by
  cases ix <;> exact h

inductive TargetInput where
  | absolute (target : Scope.Domain.Target)
  | relativePath (segments : Scope.Domain.Word)
  | homePath (segments : Scope.Domain.Word)
  deriving DecidableEq, Repr

inductive AtFailure where
  | outsideScope
  | unbound (base : PathBase)
  | secretsUnbound
  | invalidPattern
  | invalidTarget
  | dynamicCondition
  | staticIndex
  deriving DecidableEq, Repr

structure AtError where
  failure : AtFailure
  originalPattern : RangeExpr
  originalTarget : TargetInput
  resolvedPatterns : Option (List Scope.Domain.Range)
  resolvedTarget : Option Scope.Domain.Target
  patternBase : Option PathBase
  targetBase : Option PathBase
  deriving DecidableEq

/-- 診断の全データを切り詰めずに保持する内部の七欄。利用者向けShowとは分ける。 -/
def AtError.textFields (d : AtError) : List String :=
  [reprStr d.failure, reprStr d.originalPattern, reprStr d.originalTarget,
   reprStr d.resolvedPatterns, reprStr d.resolvedTarget, reprStr d.patternBase, reprStr d.targetBase]

inductive ExternalId where
  | mk (declaration : Nat)
  deriving DecidableEq
inductive ComponentId where
  | mk (declaration : Nat)
  deriving DecidableEq
inductive ExternalFunctionId where
  | mk (declaration : Nat)
  deriving DecidableEq

inductive «Sort» where
  | integer | character | float64 | float32 | decimal | boolean | unit | string
  | list | bytes | map | set | data
  | target (kind : Scope.Domain.Kind)
  deriving DecidableEq

structure FieldRef where
  owner : DataName
  constructor : ConName
  position : Nat
  result : «Sort»
  deriving DecidableEq

inductive Measure where
  | stringBytes | stringCharacters | listLength | bytesLength | mapSize | setSize
  | characterCode
  deriving DecidableEq

def Measure.input : Measure → «Sort»
  | .stringBytes | .stringCharacters => .string
  | .listLength => .list
  | .bytesLength => .bytes
  | .mapSize => .map
  | .setSize => .set
  | .characterCode => .character

def Measure.output (_ : Measure) : «Sort» := .integer

inductive Comparison where
  | eq | ne | lt | le | gt | ge
  deriving DecidableEq
inductive FloatClass where
  | finite | nan | positiveInfinity | negativeInfinity | positiveZero | negativeZero
  deriving DecidableEq
inductive FloatWidth where
  | binary32 | binary64
  deriving DecidableEq

end Benitoite.Release.Refinement
