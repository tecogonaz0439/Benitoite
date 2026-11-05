import Benitoite.Release.Refinement.StandardModelPureRows

/-! # 合成表の演算子の行と構造の等号

演算子の母集団は、%で始まる組込みの行から %Map.replaceValues・%eq・%ne を除いた107行（算術25・
順序48・演算子の表34）と、全構造値の %eq/%ne の2行の、計109行である。各行の証拠は、既存の任意のP/Bの応答の補題を
合成表の同じlookupと同じBuiltinArgsへ当てて得る。%eq/%neは全型の一つの署名（Equalityの制約を持つ
一つの型パラメータ）に統一した行であり、不適格な構造の比較は誤り `InternalComparison` を返す。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section
open Benitoite.Interval StandardScalar

/-- 整数の各幅の加減乗算と符号反転の行。 -/
theorem PureRow.arithmetic {P : Program} (row : Primitive) (k : IntKind) (api : StandardArithmeticResponse.API)
    (available : StandardArithmeticResponse.API.available k api)
    (hname : row.name = StandardArithmeticResponse.API.name k api)
    (hsig : row.signature = StandardArithmeticResponse.API.signature k api)
    (hprovider : row.provider.delta = integerDelta) :
    PureRow P row.name :=
  PureRow.of_response row hname hsig (fun ts es rs ws => by rw [hprovider])
    (fun _ _ _ _ _ _ _ args => by
      obtain ⟨_, _, _, out, delta, typed, adequate, nonexit, _⟩ :=
        StandardArithmeticResponse.response_math k api available args
      exact ⟨out, delta, typed, adequate, nonexit⟩)

private theorem order_delta (kind : StandardOrderResponse.Kind) (op : Comparison)
    (ordered : StandardOrderResponse.Ordered op) (ts es rs ws) :
    (StandardOrderResponse.table signatureBase).delta (StandardOrderResponse.name kind op) ts es rs ws =
      kind.delta (StandardOrderResponse.name kind op) ts es rs ws := by
  cases kind <;> rcases ordered with rfl | rfl | rfl | rfl
  all_goals simp [StandardOrderResponse.table, StandardOrderResponse.name, StandardOrderResponse.Kind.module,
    StandardOrderResponse.Kind.delta]

/-- 十二の型の四つの順序の比較の行。 -/
theorem PureRow.order {P : Program} (row : Primitive) (kind : StandardOrderResponse.Kind) (op : Comparison)
    (ordered : StandardOrderResponse.Ordered op)
    (hname : row.name = StandardOrderResponse.name kind op)
    (hsig : row.signature = StandardOrderResponse.signature kind)
    (hprovider : row.provider.delta = (StandardOrderResponse.table signatureBase).delta) :
    PureRow P row.name :=
  PureRow.of_response row hname hsig (delta := kind.delta)
    (fun ts es rs ws => by rw [hprovider]; exact order_delta kind op ordered ts es rs ws)
    (fun _ _ _ _ _ _ _ args => by
      obtain ⟨out, delta, typed, adequate, nonexit, _⟩ :=
        StandardOrderResponse.response_math kind op ordered (fun _ => none) args
      exact ⟨out, delta, typed, adequate, nonexit⟩)

/-- 全構造値の等号と不等号の行。署名は全型の一つで、型引数にEqualityの制約を持つ。 -/
theorem PureRow.structural {P : Program} (row : Primitive) (equal : Bool)
    (hname : row.name = if equal then "%eq" else "%ne")
    (hsig : row.signature = StandardEqualityResponse.fullSignature signatureBase.sat)
    (hprovider : row.provider.delta = StandardStructuralEqualityResponse.delta) :
    PureRow P row.name :=
  PureRow.of_response row hname hsig (fun ts es rs ws => by rw [hprovider])
    (fun _ _ _ _ _ _ _ args => by
      obtain ⟨_, _, _, _, _, out, delta, typed, adequate, nonexit⟩ :=
        StandardStructuralEqualityResponse.response equal args
      exact ⟨out, delta, typed, adequate, nonexit⟩)

/-- 演算子の行：%で始まる組込みの行のうち、%Map.replaceValues以外の109行（107演算子と %eq/%ne）。 -/
def Primitive.operator : Primitive → Bool
  | .p001 | .p002 | .p003 | .p004 | .p005 | .p006 | .p007 | .p008 | .p009 | .p010 | .p011 | .p012 | .p013 | .p014 | .p015 | .p016 | .p017 | .p018 | .p019 | .p020 | .p021 | .p022 | .p023 | .p024 | .p025 | .p026 | .p027 | .p028 | .p029 | .p030 | .p031 | .p032 | .p033 | .p034 | .p035 | .p036 | .p037 | .p038 | .p039 | .p040 | .p041 | .p042 | .p043 | .p044 | .p045 | .p046 | .p047 | .p048 | .p049 | .p050 | .p051 | .p052 | .p053 | .p054 | .p055 | .p056 | .p057 | .p058 | .p059 | .p060 | .p061 | .p062 | .p063 | .p064 | .p065 | .p066 | .p067 | .p068 | .p069 | .p070 | .p071 | .p072 | .p073 | .p074 | .p075 | .p077 | .p078 | .p079 | .p080 | .p081 | .p082 | .p083 | .p084 | .p085 | .p086 | .p087 | .p088 | .p089 | .p090 | .p091 | .p092 | .p093 | .p094 | .p095 | .p096 | .p097 | .p098 | .p099 | .p100 | .p101 | .p102 | .p103 | .p104 | .p105 | .p106 | .p107 | .p108 | .p109 | .p110 => true
  | _ => false

/-- 演算子の107行と構造の等号の2行の全BuiltinArgsは、合成表の同じlookupで型付きの非exitの応答を
持つ。演算子の表の最初の十六行は `first_sixteen` の接続を読む。 -/
theorem operator_rows (P : Program) (row : Primitive) (operator : row.operator = true) :
    PureRow P row.name := by
  cases row
  case p001 => exact PureRow.order .p001 .byte .gt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p002 => exact PureRow.order .p002 .byte .ge (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p003 => exact PureRow.order .p003 .byte .lt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p004 => exact PureRow.order .p004 .byte .le (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p005 => exact PureRow.order .p005 .character .gt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p006 => exact PureRow.order .p006 .character .ge (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p007 => exact PureRow.order .p007 .character .lt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p008 => exact PureRow.order .p008 .character .le (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p009 => exact PureRow.operator .p009 (.decimal .add) rfl rfl rfl
  case p010 => exact PureRow.operator .p010 (.decimal .divide) rfl rfl rfl
  case p011 => exact PureRow.order .p011 .decimal .gt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p012 => exact PureRow.order .p012 .decimal .ge (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p013 => exact PureRow.order .p013 .decimal .lt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p014 => exact PureRow.order .p014 .decimal .le (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p015 => exact PureRow.operator .p015 (.decimal .multiply) rfl rfl rfl
  case p016 => exact PureRow.operator .p016 (.decimal .negate) rfl rfl rfl
  case p017 => exact PureRow.operator .p017 (.decimal .subtract) rfl rfl rfl
  case p018 => exact first_sixteen P (.floating false .add) (by rw [first_sixteen_entries]; simp)
  case p019 => exact PureRow.operator .p019 (.floating false .divide) rfl rfl rfl
  case p020 => exact PureRow.order .p020 .float64 .gt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p021 => exact PureRow.order .p021 .float64 .ge (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p022 => exact PureRow.order .p022 .float64 .lt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p023 => exact PureRow.order .p023 .float64 .le (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p024 => exact PureRow.operator .p024 (.floating false .multiply) rfl rfl rfl
  case p025 => exact PureRow.operator .p025 (.floating false .negate) rfl rfl rfl
  case p026 => exact first_sixteen P (.floating false .subtract) (by rw [first_sixteen_entries]; simp)
  case p027 => exact PureRow.operator .p027 (.floating true .add) rfl rfl rfl
  case p028 => exact PureRow.operator .p028 (.floating true .divide) rfl rfl rfl
  case p029 => exact PureRow.order .p029 .float32 .gt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p030 => exact PureRow.order .p030 .float32 .ge (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p031 => exact PureRow.order .p031 .float32 .lt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p032 => exact PureRow.order .p032 .float32 .le (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p033 => exact PureRow.operator .p033 (.floating true .multiply) rfl rfl rfl
  case p034 => exact PureRow.operator .p034 (.floating true .negate) rfl rfl rfl
  case p035 => exact PureRow.operator .p035 (.floating true .subtract) rfl rfl rfl
  case p036 => exact PureRow.arithmetic .p036 .integer64 .add (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p037 => exact first_sixteen P (.integer .integer64 false) (by rw [first_sixteen_entries]; simp)
  case p038 => exact PureRow.order .p038 .integer64 .gt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p039 => exact PureRow.order .p039 .integer64 .ge (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p040 => exact PureRow.order .p040 .integer64 .lt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p041 => exact PureRow.order .p041 .integer64 .le (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p042 => exact first_sixteen P (.integer .integer64 true) (by rw [first_sixteen_entries]; simp)
  case p043 => exact PureRow.arithmetic .p043 .integer64 .multiply (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p044 => exact PureRow.arithmetic .p044 .integer64 .negate (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p045 => exact PureRow.arithmetic .p045 .integer64 .subtract (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p046 => exact PureRow.arithmetic .p046 .integer16 .add (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p047 => exact first_sixteen P (.integer .integer16 false) (by rw [first_sixteen_entries]; simp)
  case p048 => exact PureRow.order .p048 .integer16 .gt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p049 => exact PureRow.order .p049 .integer16 .ge (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p050 => exact PureRow.order .p050 .integer16 .lt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p051 => exact PureRow.order .p051 .integer16 .le (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p052 => exact first_sixteen P (.integer .integer16 true) (by rw [first_sixteen_entries]; simp)
  case p053 => exact PureRow.arithmetic .p053 .integer16 .multiply (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p054 => exact PureRow.arithmetic .p054 .integer16 .negate (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p055 => exact PureRow.arithmetic .p055 .integer16 .subtract (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p056 => exact PureRow.arithmetic .p056 .integer32 .add (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p057 => exact first_sixteen P (.integer .integer32 false) (by rw [first_sixteen_entries]; simp)
  case p058 => exact PureRow.order .p058 .integer32 .gt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p059 => exact PureRow.order .p059 .integer32 .ge (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p060 => exact PureRow.order .p060 .integer32 .lt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p061 => exact PureRow.order .p061 .integer32 .le (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p062 => exact first_sixteen P (.integer .integer32 true) (by rw [first_sixteen_entries]; simp)
  case p063 => exact PureRow.arithmetic .p063 .integer32 .multiply (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p064 => exact PureRow.arithmetic .p064 .integer32 .negate (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p065 => exact PureRow.arithmetic .p065 .integer32 .subtract (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p066 => exact PureRow.arithmetic .p066 .integer8 .add (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p067 => exact first_sixteen P (.integer .integer8 false) (by rw [first_sixteen_entries]; simp)
  case p068 => exact PureRow.order .p068 .integer8 .gt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p069 => exact PureRow.order .p069 .integer8 .ge (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p070 => exact PureRow.order .p070 .integer8 .lt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p071 => exact PureRow.order .p071 .integer8 .le (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p072 => exact first_sixteen P (.integer .integer8 true) (by rw [first_sixteen_entries]; simp)
  case p073 => exact PureRow.arithmetic .p073 .integer8 .multiply (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p074 => exact PureRow.arithmetic .p074 .integer8 .negate (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p075 => exact PureRow.arithmetic .p075 .integer8 .subtract (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p077 => exact PureRow.operator .p077 (.string .add) rfl rfl rfl
  case p078 => exact PureRow.operator .p078 (.string .greater) rfl rfl rfl
  case p079 => exact PureRow.operator .p079 (.string .greaterOrEqual) rfl rfl rfl
  case p080 => exact PureRow.operator .p080 (.string .less) rfl rfl rfl
  case p081 => exact PureRow.operator .p081 (.string .lessOrEqual) rfl rfl rfl
  case p082 => exact PureRow.arithmetic .p082 .unsignedInteger16 .add (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p083 => exact first_sixteen P (.integer .unsignedInteger16 false) (by rw [first_sixteen_entries]; simp)
  case p084 => exact PureRow.order .p084 .unsignedInteger16 .gt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p085 => exact PureRow.order .p085 .unsignedInteger16 .ge (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p086 => exact PureRow.order .p086 .unsignedInteger16 .lt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p087 => exact PureRow.order .p087 .unsignedInteger16 .le (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p088 => exact first_sixteen P (.integer .unsignedInteger16 true) (by rw [first_sixteen_entries]; simp)
  case p089 => exact PureRow.arithmetic .p089 .unsignedInteger16 .multiply (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p090 => exact PureRow.arithmetic .p090 .unsignedInteger16 .subtract (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p091 => exact PureRow.arithmetic .p091 .unsignedInteger32 .add (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p092 => exact first_sixteen P (.integer .unsignedInteger32 false) (by rw [first_sixteen_entries]; simp)
  case p093 => exact PureRow.order .p093 .unsignedInteger32 .gt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p094 => exact PureRow.order .p094 .unsignedInteger32 .ge (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p095 => exact PureRow.order .p095 .unsignedInteger32 .lt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p096 => exact PureRow.order .p096 .unsignedInteger32 .le (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p097 => exact first_sixteen P (.integer .unsignedInteger32 true) (by rw [first_sixteen_entries]; simp)
  case p098 => exact PureRow.arithmetic .p098 .unsignedInteger32 .multiply (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p099 => exact PureRow.arithmetic .p099 .unsignedInteger32 .subtract (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p100 => exact PureRow.arithmetic .p100 .unsignedInteger64 .add (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p101 => exact first_sixteen P (.integer .unsignedInteger64 false) (by rw [first_sixteen_entries]; simp)
  case p102 => exact PureRow.order .p102 .unsignedInteger64 .gt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p103 => exact PureRow.order .p103 .unsignedInteger64 .ge (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p104 => exact PureRow.order .p104 .unsignedInteger64 .lt (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p105 => exact PureRow.order .p105 .unsignedInteger64 .le (by unfold StandardOrderResponse.Ordered; decide) rfl rfl rfl
  case p106 => exact first_sixteen P (.integer .unsignedInteger64 true) (by rw [first_sixteen_entries]; simp)
  case p107 => exact PureRow.arithmetic .p107 .unsignedInteger64 .multiply (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p108 => exact PureRow.arithmetic .p108 .unsignedInteger64 .subtract (by unfold StandardArithmeticResponse.API.available; decide) rfl rfl rfl
  case p109 => exact PureRow.structural .p109 true rfl rfl rfl
  case p110 => exact PureRow.structural .p110 false rfl rfl rfl
  all_goals cases operator

/-- 全構造値の %eq と、Integerの順序の比較 %Integer.less の行。 -/
example (P : Program) : PureRow P "%eq" ∧ PureRow P "%Integer.less" :=
  ⟨operator_rows P .p109 rfl, operator_rows P .p040 rfl⟩

end
end Benitoite.Release.Refinement.StandardModel
