import Benitoite.Release.Refinement.ResourceReleaseLeaves
import Benitoite.Release.Refinement.StandardModelGeneral

/-! # 合成表の純粋な行の応答

名前ごとに、`Builtins.ResponseAssumptions` の `delta_typed` と同じ形の契約（`StandardModel.PureRowOn`）を、行の
lookup と δ が合成表の行と一致する任意の表で置く（`StandardModel.RowLookup`）。合成表の契約は `PureRow` である。
各行の証拠は、既存の任意のP/Bの応答の補題を、同じlookupと同じBuiltinArgsへ当てて得る。部分表の
`table_response` を合成表の証拠に流用しない。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section

/-- 名前 `b` の純粋な応答の契約。`delta_typed` の欄を一つの名前へ制限したもの。 -/
def PureRowOn (P : Program) (B : Builtins) (b : PrimName) : Prop :=
  ∀ Ψ sg ts es rs ws a e, B.sig b = some sg →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    ∃ out, B.delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out

/-- 合成表の名前 `b` の純粋な応答の契約。 -/
abbrev PureRow (P : Program) (b : PrimName) : Prop := PureRowOn P (builtins P) b

/-- 行の出典の表のδが、行の署名の全BuiltinArgsで型付きの応答を返すなら、行の lookup と δ が合成表と一致する表の
同じ名前は純粋な応答の契約を満たす。 -/
theorem PureRow.of_row {P : Program} {B : Builtins} [RowLookup B] (row : Primitive)
    (response : ∀ Ψ ts es rs ws a e,
      BuiltinArgs P B Ψ row.name (row.signatureWith B.sat) ts es rs ws a e →
      ∃ out, row.provider.delta row.name ts es rs ws = some out ∧
        Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ ∀ i, out ≠ .exit i)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name := by
  intro Ψ sg ts es rs ws a e lookup args
  cases Option.some.inj (lookup.symm.trans (RowLookup.sig row))
  obtain ⟨out, delta, typed, adequate, nonexit⟩ := response Ψ ts es rs ws a e args
  refine ⟨out, ?_, nonexit, typed, adequate⟩
  rw [RowLookup.delta row hrow]
  exact delta

/-- 鍵を読む行の出典の δ を宣言表の構成子の並びで作った応答が型付きなら、同じ名前は純粋な応答の契約を満たす。 -/
theorem PureRow.of_keys {P : Program} {B : Builtins} [env : RowEnv P B] (row : Primitive)
    (response : ∀ Ψ ts es rs ws a e,
      BuiltinArgs P B Ψ row.name (row.signatureWith B.sat) ts es rs ws a e →
      ∃ out, row.deltaWith ((env.keys.declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst)
          row.name ts es rs ws = some out ∧
        Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ ∀ i, out ≠ .exit i) :
    PureRowOn P B row.name := by
  intro Ψ sg ts es rs ws a e lookup args
  cases Option.some.inj (lookup.symm.trans (RowLookup.sig row))
  obtain ⟨out, delta, typed, adequate, nonexit⟩ := response Ψ ts es rs ws a e args
  refine ⟨out, ?_, nonexit, typed, adequate⟩
  rw [env.keyDelta row]
  exact delta

/-- 行の名前・署名・出典のδが既存の応答の名前・署名・δと一致すれば、既存の任意のP/Bの応答から
行の契約を得る。 -/
theorem PureRow.of_response {P : Program} {B : Builtins} [RowLookup B] (row : Primitive) {name : PrimName}
    {sg : PrimSig}
    {delta : PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome}
    (hname : row.name = name) (hsig : row.signatureWith B.sat = sg)
    (hdelta : ∀ ts es rs ws, row.provider.delta name ts es rs ws = delta name ts es rs ws)
    (response : ∀ Ψ ts es rs ws a e, BuiltinArgs P B Ψ name sg ts es rs ws a e →
      ∃ out, delta name ts es rs ws = some out ∧
        Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ ∀ i, out ≠ .exit i)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name := by
  refine PureRow.of_row row (fun Ψ ts es rs ws a e args => ?_) hrow
  rw [hname, hsig] at args
  rw [hname, hdelta]
  exact response Ψ ts es rs ws a e args

/-! ## 演算子の表の最初の十六行 -/

/-- 演算子の表（整数のdiv/mod・二幅のFloat・Decimal・Stringの算術）の行は、同じentryの
任意のP/Bの応答から合成表の契約を得る。 -/
theorem PureRow.operator {P : Program} {B : Builtins} [RowLookup B] (row : Primitive)
    (entry : StandardOperatorResponse.Entry)
    (hname : row.name = entry.name) (hsig : row.signatureWith B.sat = entry.signature)
    (hprovider : row.provider.delta = (StandardOperatorResponse.table signatureBase).delta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig
    (fun ts es rs ws => by
      rw [hprovider]
      show ((StandardOperatorResponse.dispatch entry.name).bind fun r => r.delta entry.name ts es rs ws) = _
      rw [StandardOperatorResponse.dispatch_name]
      rfl)
    (fun _ _ _ _ _ _ _ args => StandardOperatorResponse.response entry args)

/-- 演算子の表の並びの最初の十六行（七整数型のdiv/modと、Floatのadd/subtract）の全BuiltinArgsは、
合成表の同じlookupで型付きの非exitの応答を持つ。 -/
theorem first_sixteen_entries : StandardOperatorResponse.entries.take 16 =
    [.integer .integer8 false, .integer .integer8 true, .integer .integer16 false, .integer .integer16 true,
      .integer .integer32 false, .integer .integer32 true, .integer .integer64 false, .integer .integer64 true,
      .integer .unsignedInteger16 false, .integer .unsignedInteger16 true,
      .integer .unsignedInteger32 false, .integer .unsignedInteger32 true,
      .integer .unsignedInteger64 false, .integer .unsignedInteger64 true,
      .floating false .add, .floating false .subtract] := rfl

theorem first_sixteen_of {P : Program} {B : Builtins} [RowLookup B] :
    ∀ entry ∈ StandardOperatorResponse.entries.take 16, PureRowOn P B entry.name := by
  intro entry member
  rw [first_sixteen_entries] at member
  simp only [List.mem_cons, List.not_mem_nil, or_false] at member
  rcases member with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl
  · exact PureRow.operator .p067 (.integer .integer8 false) rfl rfl rfl
  · exact PureRow.operator .p072 (.integer .integer8 true) rfl rfl rfl
  · exact PureRow.operator .p047 (.integer .integer16 false) rfl rfl rfl
  · exact PureRow.operator .p052 (.integer .integer16 true) rfl rfl rfl
  · exact PureRow.operator .p057 (.integer .integer32 false) rfl rfl rfl
  · exact PureRow.operator .p062 (.integer .integer32 true) rfl rfl rfl
  · exact PureRow.operator .p037 (.integer .integer64 false) rfl rfl rfl
  · exact PureRow.operator .p042 (.integer .integer64 true) rfl rfl rfl
  · exact PureRow.operator .p083 (.integer .unsignedInteger16 false) rfl rfl rfl
  · exact PureRow.operator .p088 (.integer .unsignedInteger16 true) rfl rfl rfl
  · exact PureRow.operator .p092 (.integer .unsignedInteger32 false) rfl rfl rfl
  · exact PureRow.operator .p097 (.integer .unsignedInteger32 true) rfl rfl rfl
  · exact PureRow.operator .p101 (.integer .unsignedInteger64 false) rfl rfl rfl
  · exact PureRow.operator .p106 (.integer .unsignedInteger64 true) rfl rfl rfl
  · exact PureRow.operator .p018 (.floating false .add) rfl rfl rfl
  · exact PureRow.operator .p026 (.floating false .subtract) rfl rfl rfl

theorem first_sixteen (P : Program) :
    ∀ entry ∈ StandardOperatorResponse.entries.take 16, PureRow P entry.name :=
  first_sixteen_of

/-- 合成表のlookupで %Integer8.div の型付き引数から、表のδの応答を得る。 -/
example (P : Program) {Ψ sg ts es rs ws a e} (lookup : (builtins P).sig "%Integer8.div" = some sg)
    (args : BuiltinArgs P (builtins P) Ψ "%Integer8.div" sg ts es rs ws a e) :
    ∃ out, (builtins P).delta "%Integer8.div" ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P (builtins P) Ψ out a ∧ AdequateResult ws out :=
  first_sixteen P (.integer .integer8 false)
    (by rw [first_sixteen_entries]; exact List.mem_cons_self) Ψ sg ts es rs ws a e lookup args

end
end Benitoite.Release.Refinement.StandardModel
