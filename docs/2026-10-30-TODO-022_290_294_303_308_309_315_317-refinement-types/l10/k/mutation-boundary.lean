import Lean
import Benitoite.Release.Refinement.LegacyTables

namespace Benitoite.Release.Refinement.L10KBoundary
noncomputable section

def kinds : DeclarationKinds := ⟨fun _ => .value, fun _ => [], fun _ _ => []⟩
def program : Benitoite.Release.Program := {
  defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
  effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def oldBuiltins : Benitoite.Release.Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def builtins : Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def store : Benitoite.Release.StoreTy := fun _ => none
def unit : Benitoite.Release.Ty := .base .unit

def constNode : LegacyJudgment := .value [] store Benitoite.Release.Qempty [] [] (.const .unit) unit
def leftNode : LegacyJudgment := .comp [] store Benitoite.Release.Qempty [] [] none (.ret (.const .unit)) unit Benitoite.Release.Eff.empty []
def variableNode : LegacyJudgment := .value [] store Benitoite.Release.Qempty [] [some unit] (.var 0) unit
def rightNode : LegacyJudgment := .comp [] store Benitoite.Release.Qempty [] [some unit] none (.ret (.var 0)) unit Benitoite.Release.Eff.empty []
def letNode : LegacyJudgment := .comp [] store Benitoite.Release.Qempty [] [] none
  (.letIn (.ret (.const .unit)) (.ret (.var 0))) unit Benitoite.Release.Eff.empty []

def badType : Benitoite.Release.Ty := .list (.ctor .list)
def badLeft : LegacyJudgment := .comp [] store Benitoite.Release.Qempty [] [] none (.ret (.list [])) badType Benitoite.Release.Eff.empty []
def badRight : LegacyJudgment := .comp [] store Benitoite.Release.Qempty [] [some badType] none (.ret (.const .unit)) unit Benitoite.Release.Eff.empty []
def badLet : LegacyJudgment := .comp [] store Benitoite.Release.Qempty [] [] none
  (.letIn (.ret (.list [])) (.ret (.const .unit))) unit Benitoite.Release.Eff.empty []

theorem reject_intermediate : ¬ LegacyOutputInput kinds program oldBuiltins builtins badLeft := by
  intro h
  have typed := h.regular.2.2.1 badType (by simp)
  exact typed.1

def badConstructor : Benitoite.Release.ConDecl := ⟨"Bad", 0, [.ctor .list]⟩
def badProgram : Benitoite.Release.Program := { program with cons := fun _ => some badConstructor }
theorem reject_constructor_table : ¬ LegacyTables kinds badProgram oldBuiltins builtins := by
  intro h
  have field := (h.constructorFields "Bad.C" badConstructor rfl (.ctor .list) (by simp [badConstructor])).2
  exact field

-- 型変数の範囲が壊れた欄は Annotation で拒む。
def unscopedConstructor : Benitoite.Release.ConDecl := ⟨"Bad", 0, [.tvar 0]⟩
def unscopedProgram : Benitoite.Release.Program := { program with cons := fun _ => some unscopedConstructor }
def arityProgram : Benitoite.Release.Program := { program with cons := fun c =>
  if c = "Zero" then (some { data := "Same", ntys := 0, args := [] }) else (some { data := "Same", ntys := 1, args := [] }) }

theorem reject_constructor_arity : ¬ LegacyTables kinds arityProgram oldBuiltins builtins := by
  intro h
  have same := h.constructorArity "Zero" ⟨"Same", 0, []⟩ "One" ⟨"Same", 1, []⟩
    (by simp [arityProgram]) (by simp [arityProgram]) rfl
  exact Nat.zero_ne_one same

end
end Benitoite.Release.Refinement.L10KBoundary

namespace Benitoite.Release.Refinement.L10KHigherKinds
open L10KBoundary
noncomputable section

def optionDecl : Benitoite.Release.ConDecl := ⟨"Option", 1, []⟩
def functionDecl : Benitoite.Release.Def :=
  ⟨[{}], 0, ["d"], [.dict "Functor" (.tvar 0)], .base .unit, Benitoite.Release.Eff.empty, .ret (.const .unit)⟩
def methodDecl : Benitoite.Release.MethSig := ⟨[], 0, [], [], .base .unit, Benitoite.Release.Eff.empty⟩
def classDecl : Benitoite.Release.ClassDecl := ⟨[], fun m => if m = "ping" then some methodDecl else none⟩
def hkKinds : DeclarationKinds := ⟨fun _ => .constructor 1, fun _ => [.constructor 1], fun _ _ => []⟩
def hkProgram : Benitoite.Release.Program := { program with
  cons := fun _ => some optionDecl
  defs := fun _ => some functionDecl
  classes := fun _ => some classDecl }

def badSource : Benitoite.Release.Def :=
  ⟨[{}], 0, ["x"], [.tvar 1], .base .unit, Benitoite.Release.Eff.empty, .ret (.const .unit)⟩
def badSourceProgram : Benitoite.Release.Program := { program with defs := fun _ => some badSource }
def valueKinds : DeclarationKinds := ⟨fun _ => .value, fun _ => [.value], fun _ _ => []⟩

end
end Benitoite.Release.Refinement.L10KHigherKinds

namespace Benitoite.Release.Refinement.L10KHeld
open L10KBoundary
noncomputable section

def requestDecl : Benitoite.Release.ConDecl := ⟨"Http.ClientRequest", 0,
  [.base .unit, .base .string, .base .unit, .base .unit, .base .unit]⟩
def requestProgram : Benitoite.Release.Program := { program with cons := fun _ => some requestDecl }
def request : Benitoite.Release.Val := .con "Http.ClientRequest" []
  [.const .unit, .const (.string "http://a"), .const .unit, .const .unit, .const .unit]
def requestType : Benitoite.Release.Ty := .data "Http.ClientRequest" []
def target : Scope.Domain.Target := .endpoint ⟨.name ["a"], 80⟩
def requestBuiltins : Builtins := { builtins with
  valKind := fun _ => some .endpoint, valContent := fun _ => some (embedTy requestType) }
def requestOldBuiltins : Benitoite.Release.Builtins := { oldBuiltins with
  valKind := fun _ => some .endpoint, valContent := fun _ => some requestType }

end
end Benitoite.Release.Refinement.L10KHeld

/-! 高 kind の `.tapp` を持つ元の署名と、旧 V_Fun の導出全体の入力を確認する。 -/
namespace Benitoite.Release.Refinement.L10KApplied
open Benitoite.Release.Refinement
noncomputable section

def optionDecl : Benitoite.Release.ConDecl := ⟨"Option", 1, []⟩
def eE : Benitoite.Release.Eff := Benitoite.Release.Eff.empty
def unit : Benitoite.Release.Ty := .base .unit
def fd : Benitoite.Release.Def :=
  ⟨[{}], 0, ["x"], [.tapp 0 [unit]], unit, eE, .ret (.const .unit)⟩
def K : DeclarationKinds := ⟨fun _ => .value, fun _ => [.constructor 1], fun _ _ => []⟩
def P0 : Benitoite.Release.Program := {
  defs := fun _ => some fd, cons := fun _ => some optionDecl, ops := fun _ => none,
  effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def B0 : Benitoite.Release.Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def B : Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def opt : Benitoite.Release.Ty := .ctor (.data "Option")
def result : Benitoite.Release.Ty := Benitoite.Release.fnTy fd.names fd.params fd.ret fd.eff [opt] []


def store : Benitoite.Release.StoreTy := fun _ => none
def node : LegacyJudgment := .value [] store Benitoite.Release.Qempty [] [] (.fnRef "f" [opt] []) result

end
end Benitoite.Release.Refinement.L10KApplied

/-! 欄を持つ構成子の表の正例と、保持値の node の正例・負例。 -/
namespace Benitoite.Release.Refinement.L10KFieldsHeld

noncomputable section

def someDecl : Benitoite.Release.ConDecl := ⟨"Option", 1, [.tvar 0]⟩
def K : DeclarationKinds := ⟨fun _ => .value, fun _ => [], fun _ _ => []⟩
def P0 : Benitoite.Release.Program := {
  defs := fun _ => none, cons := fun _ => some someDecl, ops := fun _ => none,
  effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def target : Scope.Domain.Target := .endpoint ⟨.name ["a"], 80⟩
def B0 (c : Option Benitoite.Release.Ty) : Benitoite.Release.Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set",
  valKind := fun _ => some .endpoint, valContent := fun _ => c }
def B (c : Option Ty) : Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set",
  valKind := fun _ => some .endpoint, valContent := fun _ => c }

def store : Benitoite.Release.StoreTy := fun _ => none
def held : Benitoite.Release.Ty := .opaque "O" (.fixed .top)

theorem reject_content (T0 T) : ¬ LegacyOutputInput K P0 (B0 (some T0)) (B (some T))
    (.value [] store Benitoite.Release.Qempty [] [] (.checked target) held) := by
  intro h
  obtain ⟨o, r, _, _, _, hc, _⟩ := h.regular.2.2.1
  cases hc

end
end Benitoite.Release.Refinement.L10KFieldsHeld

namespace Benitoite.Release.Refinement.L10KClauseSource
open Benitoite.Release.Refinement
noncomputable section

def oldSig : Benitoite.Release.PrimSig := {
  tparams := [], neffs := 0, names := ["x"], params := [.tvar 0], ret := .base .unit,
  eff := Benitoite.Release.Eff.single "E", admits := fun _ _ => True, kind := .pure, opEff := some "E" }
def newSig : PrimSig := {
  tparams := [], neffs := 0, names := ["x"], params := embedParameters [.tvar 0],
  ret := (embedTy (.base .unit)).shiftV 1 0,
  eff := (embedEff (Benitoite.Release.Eff.single "E")).shiftV 1 0,
  admits := fun _ _ => True, kind := .pure, opEff := some "E" }
def B0 : Benitoite.Release.Builtins := {
  sig := fun _ => some oldSig, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => some ["op"],
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def B : Builtins := {
  sig := fun _ => some newSig, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => some ["op"],
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def K : DeclarationKinds := ⟨fun _ => .value, fun _ => [], fun _ _ => []⟩
def P0 : Benitoite.Release.Program := {
  defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
  effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }


def store : Benitoite.Release.StoreTy := fun _ => none
def unit : Benitoite.Release.Ty := .base .unit
def C0 : List Benitoite.Release.TParam := [{}]
def eE : Benitoite.Release.Eff := Benitoite.Release.Eff.empty
def body : Benitoite.Release.Comp := .ret (.const .unit)
def clause : Benitoite.Release.Clause := .mk (.prim "b") 1 0 body
def sg0 : Benitoite.Release.OpSig := ⟨[], ["x"], [.tvar 0], .base .unit, "E"⟩

def Γc : List (Option Benitoite.Release.Ty) := [some (.cont unit unit eE), some (.tvar 0)]

abbrev Q0 := Benitoite.Release.Qempty
/- 外側の制約があっても、元の操作署名の範囲外の型変数を許さない。 -/
theorem reject_clause_source : ¬ LegacyClausesInput K P0 B0 B ⟨[.value], C0, 0, 0⟩ [clause] := by
  rintro ⟨⟨sg, hs, _, _, source, _⟩, _⟩
  change some sg0 = some sg at hs
  cases hs
  have impossible : 0 < 0 := source.2.1.2.1.1
  omega

def scopedOldSig : Benitoite.Release.PrimSig := { oldSig with
  params := [.opaque "O" (.rvar 0)], rkinds := [.endpoint] }
def scopedBuiltins : Benitoite.Release.Builtins := { B0 with sig := fun _ => some scopedOldSig }
def scopedTop : Benitoite.Release.OpSig :=
  ⟨[], ["x"], [.opaque "O" (.fixed .top)], .base .unit, "E"⟩

/- 有効な元の署名は、Top 以外を含む任意の節の範囲へ WF を渡せる。 -/
end
end Benitoite.Release.Refinement.L10KClauseSource

namespace Benitoite.Release.Refinement.L10KOneWay
open L10KBoundary
noncomputable section

def restrictive : Benitoite.Release.Builtins := { oldBuiltins with sat := fun _ _ _ => False }
def permissive : Builtins := { builtins with admitsR := fun _ _ => True }

/- 新しい受理が増えても、旧から新への表の条件を満たす。 -/
def oldSig : Benitoite.Release.PrimSig := {
  tparams := [], neffs := 0, names := [], params := [], ret := .base .unit,
  eff := Benitoite.Release.Eff.empty, admits := fun _ _ => False, kind := .pure, opEff := none }
def newSig : PrimSig := {
  tparams := [], neffs := 0, names := [], params := [], ret := .base .unit,
  eff := (embedEff Benitoite.Release.Eff.empty).shiftV 0 0,
  admits := fun _ _ => True, kind := .pure, opEff := none }

end
end Benitoite.Release.Refinement.L10KOneWay

