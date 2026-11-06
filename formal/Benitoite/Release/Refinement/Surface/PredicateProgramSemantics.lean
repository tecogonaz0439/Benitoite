import Benitoite.Release.Refinement.Surface.CheckAccept
import Benitoite.Release.Refinement.CheckErasure

/-! # 公開ソースの解決とプログラムの意味

公開の判定の名前解決は型付けより前に行う。公開ソースの意味は、実入口と同じ全本体の収集・登録・解決を
経たプログラムの脱糖で定める。解決済みの内部表現には通常の表層の脱糖を適用する。
直接の公開呼出しへ精密な型を付けてから、異なる表で実行することはしない。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateProgramSemantics
open PredicateRows PredicateResponse PredicateProjection MatchFacts
noncomputable section

/-- 解決済みのプログラムと同じ入力表が持つ、核のプログラム。 -/
def core (ready : CheckPreparation.Prepared) : Refinement.Program :=
  desugarProgram ready.input.opPrim ready.program

/-- 公開ソースのプログラムの意味。収集・名前解決を通常の脱糖に先行させる。 -/
def meaning (q : Check.Input) (p : Program) : Refinement.Program :=
  core (CheckPreparation.prepare q p)

/-- 公開ソースの事象列と終端は、実入口が用意した同じ核の遷移関係で観測する。 -/
def execution (q : Check.Input) (p : Program) (σ : PathEnv)
    (start : State) (events : List Event) (finish : State) : Prop :=
  Steps (meaning q p) (CheckPreparation.prepare q p).input.B σ start events finish

/-- 無限の実行も、同じ全プログラムと同じ入力表の各段で観測する。 -/
def infinite (q : Check.Input) (p : Program) (σ : PathEnv)
    (start : State) (labels : Nat → Option Event) : Prop :=
  CheckErasure.InfiniteExecution (meaning q p) (CheckPreparation.prepare q p).input.B σ start labels

/-- 条件を固定した公開行と内部行は、同じ入力で同じδを持つ。 -/
structure PublicDeltaAgreement : Prop where
  path : ∀ pattern path, parseAtPattern .path (.const (.string pattern)) = some (.path path) → ∀ value,
    (Entry.path path).delta [] [] [] [.const (.string value)] =
      API.path.delta API.path.name [] [] [] [.const (.string pattern), .const (.string value)]
  host : ∀ pattern host, parseAtPattern .host (.const (.string pattern)) = some (.host host) → ∀ value,
    (Entry.host host).delta [] [] [] [.const (.string value)] =
      API.host.delta API.host.name [] [] [] [.const (.string pattern), .const (.string value)]
  characters : ∀ lo hi value, (Entry.characters lo hi).delta [] [] [] [.const (.string value)] =
    API.characters.delta API.characters.name [] [] [] [.const (.string value), .const (.character lo), .const (.character hi)]
  floating : ∀ width test values, (Entry.floating width test).delta [] [] [] values =
    (API.floating width test).delta (API.floating width test).name [] [] [] values
  projected : ∀ (projection : Projection) types root leaf,
    types.length = projection.ntys → readPath root projection.route = some leaf →
    projection.delta types [] [] [root] = projection.entry.delta [] [] [] [leaf]

theorem public_deltas : PublicDeltaAgreement := by
  refine ⟨fun _ _ h => PredicateCalls.path_delta h, fun _ _ h => PredicateCalls.host_delta h,
    PredicateCalls.characters_delta, PredicateCalls.floating_delta, ?_⟩
  intro projection types root leaf count read
  simp [Projection.delta, Projection.run, count, read, Entry.delta]

/-- 公開ソースと、その実入口が返す解決済み表現のプログラムの意味は一致する。
事象列と最終状態を等号で保つので、失敗のpayload・終了値・ストアも同じである。
無限の実行の各段のラベルも保つ。公開行と内部行のδの対応を同じ言明に保持する。 -/
theorem observations_preserved (q : Check.Input) (p : Program) :
    PublicDeltaAgreement ∧
    (∀ σ start events finish, execution q p σ start events finish ↔
      Steps (core (CheckPreparation.prepare q p)) (CheckPreparation.prepare q p).input.B σ start events finish) ∧
    (∀ σ start events finish, finish.Final →
      (execution q p σ start events finish ↔
        Steps (core (CheckPreparation.prepare q p)) (CheckPreparation.prepare q p).input.B σ start events finish)) ∧
    (∀ σ start labels, infinite q p σ start labels ↔
      CheckErasure.InfiniteExecution (core (CheckPreparation.prepare q p))
        (CheckPreparation.prepare q p).input.B σ start labels) :=
  ⟨public_deltas, fun _ _ _ _ => Iff.rfl, fun _ _ _ _ _ => Iff.rfl, fun _ _ _ => Iff.rfl⟩

/-- 実入口の受理は、解決後の型付けと通常の性質1へ接続する。
入力の健全性は元の表から構成する。全件性・有限支持とプログラムの整形式・値の束縛の仮定は区別する。 -/
theorem accepted_property1 {q : Check.Input} {p : Program} {A : CheckAccept.AcceptInput}
    (hq : q.Sound)
    (hn : CheckTables.NamesComplete q p)
    (hd : ∀ n d, (CheckPreparation.prepare q p).program.defs n = some d →
      CheckDeclarations.DefSupport (CheckPreparation.prepare q p).input d)
    (hi : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id →
      CheckDeclarations.ImplSupport (CheckPreparation.prepare q p).input id)
    (him : ∀ n id, p.impls n = some id → CheckDeclarations.ImplNamesComplete q id)
    (hD : (CheckPreparation.prepare q p).input.D = (CheckPreparation.prepare q p).program.declarations)
    (ha : CheckAccept.NamesComplete q p)
    (hw : (CheckPreparation.prepare q p).program.WellFormed)
    (hvalues : Builtins.ValueAssumptions (meaning q p) (CheckPreparation.prepare q p).input.B)
    (accepted : CheckAccept.checkProgramAccepted q A p = .ok ()) :
    (CheckPreparation.prepare q p).program.WellTyped
      (CheckPreparation.prepare q p).input.B (CheckPreparation.prepare q p).input.opPrim ∧
    CheckAccept.Accepted A q p ∧
    (meaning q p).WellFormed ∧ (meaning q p).WellTyped (CheckPreparation.prepare q p).input.B ∧
      (meaning q p).EffectsOk (CheckPreparation.prepare q p).input.B := by
  obtain ⟨typed, ranges⟩ := CheckAccept.checkProgramAccepted_empty (q := q) (p := p) (A := A)
    (CheckPreparation.prepare_sound hq p) (CheckTables.prepare_names hn) hd hi
    (CheckTables.prepare_impl_names him) hD ha accepted
  exact ⟨typed, ranges, desugar_typed hw typed hvalues⟩

end
end Benitoite.Release.Refinement.Surface.PredicateProgramSemantics
