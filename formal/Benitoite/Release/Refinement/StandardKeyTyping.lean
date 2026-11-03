import Benitoite.Release.BuiltinTable
import Benitoite.Release.Refinement.KeyContracts
import Benitoite.Release.Refinement.Typing
import Benitoite.Release.Refinement.PreparedLeaf

/-! # 同じ構成子宣言から作る鍵の有限表 -/
namespace Benitoite.Release.Refinement
noncomputable section

namespace StandardKeyTyping
mutual
  /-- 鍵の判定に使う骨格。対象外の型は等値・鍵とも拒否する関数の骨格へ写す。 -/
  def carrier : Ty → Benitoite.Release.Ty
    | .base b => .base b
    | .bytes => .bytes
    | .tvar i => .tvar i
    | .data d ts => .data d (carriers ts)
    | .list a => .list (carrier a)
    | .map a b => .map (carrier a) (carrier b)
    | .set a => .set (carrier a)
    | .refined a _ => carrier a
    | _ => .fn [] [] (.base .unit) Benitoite.Release.Eff.empty
  def carriers : List Ty → List Benitoite.Release.Ty
    | [] => []
    | a :: as => carrier a :: carriers as
end

/-- データ名・型引数数・名前付き構成子と元の欄を一つの有限入力に保つ。 -/
structure DataDecl where
  name : DataName
  ntys : Nat
  constructors : List (ConName × List Ty)

def DataDecl.summaryInput (d : DataDecl) : Benitoite.Release.BuiltinDataDecl :=
  ⟨d.name, d.ntys, d.constructors.map (fun c => carriers c.2)⟩

def DataDecl.entries (d : DataDecl) : List (ConName × ConDecl) :=
  d.constructors.map (fun c => (c.1, ⟨d.name, d.ntys, c.2⟩))

/-- 宣言の等号と計算した判定の等号だけを入力にする。値の鍵化を仮定しない。 -/
structure Table (P : Program) (B : Builtins) where
  declarations : List DataDecl
  constructorNames : ((declarations.flatMap DataDecl.entries).map Prod.fst).Nodup
  dataNames : (declarations.map DataDecl.name).Nodup
  cons_eq : P.cons = fun c => (declarations.flatMap DataDecl.entries).lookup c
  converged : Benitoite.Release.summariesConverged
    (declarations.map DataDecl.summaryInput)
    (Benitoite.Release.dataSummaries (declarations.map DataDecl.summaryInput)) = true
  sat_eq : ∀ C a p, B.sat C a p ↔
    Benitoite.Release.satB (Benitoite.Release.dataSummaries
      (declarations.map DataDecl.summaryInput)) C (carrier a) p = true

/-- 型付きの閉じた値の観測から鍵の有限構造を返す目標。 -/
def KeyObservation (P : Program) (B : Builtins) (a : Ty) : Prop :=
  ∀ {Ψ Q v}, HasTypeVQ P B Ψ Q [] [] [] v a →
    ∀ η : ObservationEnvModel, ∃ t o,
      v.toTerm? = some t ∧ t.Closed ∧ t.observe η = some o ∧ o.KeyShape

/-- 観測から得た構造を、言語上の閉じた鍵の符号へ渡す。 -/
theorem KeyObservation.code {P B a Ψ Q v}
    (shape : KeyObservation P B a) (typed : HasTypeVQ P B Ψ Q [] [] [] v a)
    (η : ObservationEnvModel) :
    ∃ t c, v.toTerm? = some t ∧ Key.code? t = some c := by
  obtain ⟨t,o,ht,hc,ho,hs⟩ := shape typed η
  obtain ⟨c,code,_⟩ := Key.code_of_shape hc η ho hs
  exact ⟨t,c,ht,code⟩

private theorem unit_observation (P : Program) (B : Builtins) :
    KeyObservation P B (.base .unit) := by
  intro Ψ Q v typed η
  obtain ⟨t,ht,hs,hc⟩ := typed.represented (s := .unit) rfl
  obtain ⟨o,ho,sort⟩ := Val.toTerm_observed ht hs η
  refine ⟨t,o,ht,hc,ho,?_⟩
  cases o <;> cases sort
  exact .unit

example {P B Ψ Q v} (typed : HasTypeVQ P B Ψ Q [] [] [] v (.base .unit))
    (η : ObservationEnvModel) :
    ∃ t c, v.toTerm? = some t ∧ Key.code? t = some c :=
  KeyObservation.code (unit_observation P B) typed η

namespace Representatives
def declarations : List DataDecl := [
  ⟨"A", 1, [("A.End", []), ("A.Next", [.data "B" [.tvar 0]])]⟩,
  ⟨"B", 1, [("B.End", [.tvar 0]), ("B.Next", [.data "A" [.tvar 0]])]⟩,
  ⟨"FunctionField", 0, [("FunctionField.Make", [.fn ["x"] [.base .unit] (.base .unit) Eff.empty])]⟩,
  ⟨"Phantom", 1, [("Phantom.Make", [.base .unit])]⟩]
def summaries := Benitoite.Release.dataSummaries (declarations.map DataDecl.summaryInput)
def types : List Ty := [
  .list (.base .decimal),
  .map (.base .integer8) (.list (.base .decimal)),
  .data "A" [.base .decimal],
  .data "FunctionField" [],
  .data "Phantom" [.fn ["x"] [.base .unit] (.base .unit) Eff.empty]]

/-- 相互再帰の依存は伝わり、未使用の関数型引数は依存へ入らない。 -/
theorem computed :
    Benitoite.Release.summariesConverged (declarations.map DataDecl.summaryInput) summaries = true ∧
    summaries = [
      ⟨"A", 1, ⟨false,[0]⟩, ⟨false,[0]⟩⟩,
      ⟨"B", 1, ⟨false,[0]⟩, ⟨false,[0]⟩⟩,
      ⟨"FunctionField", 0, ⟨true,[]⟩, ⟨false,[]⟩⟩,
      ⟨"Phantom", 1, ⟨false,[]⟩, ⟨false,[]⟩⟩] ∧
    types.map (fun a => Benitoite.Release.satB summaries [] (carrier a) TParam.keyC) =
      [true,true,true,false,true] := by decide

private def program : Program where
  defs := fun _ => none
  cons := fun c => (declarations.flatMap DataDecl.entries).lookup c
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

private def builtins : Builtins where
  sig := fun _ => none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  sat := fun C a p => Benitoite.Release.satB summaries C (carrier a) p = true
  refGet := "Reference.get"
  refSet := "Reference.set"

private def table : Table program builtins :=
  ⟨declarations, by decide, by decide, rfl, computed.1, fun _ _ _ => Iff.rfl⟩

/-- 同じ宣言の具体表で五代表の受理と拒否を読む。 -/
example :
    builtins.sat [] (.list (.base .decimal)) TParam.keyC ∧
    builtins.sat [] (.map (.base .integer8) (.list (.base .decimal))) TParam.keyC ∧
    builtins.sat [] (.data "A" [.base .decimal]) TParam.keyC ∧
    ¬ builtins.sat [] (.data "FunctionField" []) TParam.keyC ∧
    builtins.sat [] (.data "Phantom" [.fn ["x"] [.base .unit] (.base .unit) Eff.empty]) TParam.keyC := by
  simp only [table.sat_eq]
  decide

/-- 値側の鍵構造を持つListとMapのKeyShapeを構成する。 -/
theorem decimal_collections (c : Int) (s : Nat) :
    (Observation.listValue [some (.decimal c s)]).KeyShape ∧
    (Observation.mapValue [some (.integer 1)]
      [some (.listValue [some (.decimal c s)])]).KeyShape := by
  have list := Observation.KeyShape.list (.cons (.decimal c s) .nil)
  exact ⟨list, .map (.cons (.integer 1) list .nil)⟩

end Representatives
end StandardKeyTyping
end
end Benitoite.Release.Refinement
