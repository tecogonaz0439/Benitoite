import Benitoite.Release.Refinement.StandardModelNumericRows
import Benitoite.Release.Refinement.StandardModelOperatorRows

/-! # 合成表の純粋な行の契約の前提を満たす入力

`StandardModel.PureRow` の前提（合成表のlookupと、その署名の `BuiltinArgs`）を、基本型の定数の
引数列で満たす。型パラメータ・行・範囲・効果を持たず、引数と結果が基本型である署名に限って
一般の補題を置き、演算子の107行と、数値の公開モジュールの同じ形の行に当てる。基本型のOptionを返す行、
Decimal.round、%eq/%ne は、それぞれの署名の補題で満たす。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section

/-- 合成表の名前 `b` の純粋な応答の契約の前提を満たす入力がある。 -/
def PureRow.Satisfiable (P : Program) (b : PrimName) : Prop :=
  ∃ Ψ sg ts es rs ws a e, (builtins P).sig b = some sg ∧
    BuiltinArgs P (builtins P) Ψ b sg ts es rs ws a e

/-- 基本型ごとに一つの定数。 -/
def sample : BaseTy → Const
  | .integer => .integer ⟨1, by decide⟩
  | .float => .float64 0
  | .string => .string ""
  | .character => .character 'a'
  | .boolean => .boolean true
  | .unit => .unit
  | .byte => .byte 1
  | .decimal => .decimal 1 0
  | .integer8 => .integer8 1
  | .integer16 => .integer16 1
  | .integer32 => .integer32 1
  | .unsignedInteger16 => .unsignedInteger16 1
  | .unsignedInteger32 => .unsignedInteger32 1
  | .unsignedInteger64 => .unsignedInteger64 1
  | .float32 => .float32 0

theorem sample_typed {P B Ψ} (base : BaseTy) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (sample base)) (.base base) := by
  cases base <;> exact .V_Const (by simp [ConstOK, sample])

/-- 一つの基本型の引数と基本型の結果を持つ純粋な署名。 -/
def unarySig (n : String) (i o : BaseTy) : PrimSig :=
  ⟨[],0,[n],[.base i],.base o,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩

/-- 名前の異なる二つの基本型の引数と基本型の結果を持つ純粋な署名。 -/
def binarySig (n m : String) (i j o : BaseTy) : PrimSig :=
  ⟨[],0,[n,m],[.base i,.base j],.base o,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩

/-- 一つの基本型の引数と、基本型のOptionの結果を持つ純粋な署名。 -/
def optionSig (n : String) (i o : BaseTy) : PrimSig :=
  ⟨[],0,[n],[.base i],.data "Option" [.base o],Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩

private theorem empty_range : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
  funext x; cases x <;> simp [mapRangeAtoms]

private theorem unary_instantiated (n : String) (i o : BaseTy) :
    instantiatedTel (Tel.instR [] (unarySig n i o).tel) [] [] = Ty.toTel [n] [.base i] (.base o) Eff.empty := by
  simp [unarySig,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
    Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
    Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
    empty_range,Ty.toTel,Ty.shiftV,Eff.shiftV]

private theorem binary_instantiated (n m : String) (i j o : BaseTy) :
    instantiatedTel (Tel.instR [] (binarySig n m i j o).tel) [] [] =
      Ty.toTel [n,m] [.base i,.base j] (.base o) Eff.empty := by
  simp [binarySig,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
    Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
    Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
    empty_range,Ty.toTel,Ty.shiftV,Eff.shiftV,shiftVTys]

private theorem option_instantiated (n : String) (i o : BaseTy) :
    instantiatedTel (Tel.instR [] (optionSig n i o).tel) [] [] =
      Ty.toTel [n] [.base i] (.data "Option" [.base o]) Eff.empty := by
  simp [optionSig,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
    Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
    Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
    empty_range,Ty.toTel,Ty.shiftV,Eff.shiftV,shiftVTys,mapRangesTys]

/-- 基本型の一引数の署名の全欄を、型付きの定数で満たす。 -/
theorem unary_arguments {P B Ψ b} (n : String) (i o : BaseTy) :
    BuiltinArgs P B Ψ b (unarySig n i o) [] [] [] [.const (sample i)] (.base o) Eff.empty := by
  have annotation : Ty.Annotation P [] [] (.fn [n] [.base i] (.base o) Eff.empty) :=
    ⟨by simp [Ty.WF, Ty.WFList, Eff.WF, Eff.empty, NamesWF, Eff.Canonical, Eff.norm], by trivial, by trivial⟩
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · constructor <;> simp [unarySig,RowTransport,PrimSig.tel,signatureTel,Eff.empty,
      Ty.normTys,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,Eff.RowsIn,Qsig,Qempty,QTy,QTys,QEff,Eff.row]
  · simp [Builtins.RangeAdmissible, unarySig]
  · constructor
    · simp [unarySig,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
        Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,empty_range,Ty.WF,Tel.WF,Eff.WF,Eff.empty,
        Tel.norm,Ty.norm,Eff.norm,Ty.normTys,Ty.WFList,Eff.Canonical]
    · intro a ha; cases ha
    · exact ⟨rfl, by intro i a k ha hk; cases ha⟩
    · intro e he; cases he
    · intro e he; cases he
    · rw [unary_instantiated]
      exact ⟨by simp [Ty.WF, Tel.WF, Ty.WFList, Ty.toTel, Ty.shiftV, Eff.shiftV, Eff.WF, Eff.empty,
        Eff.Canonical, Eff.norm, shiftVTys], by trivial, by trivial⟩
  · rw [unary_instantiated]
    simpa [Ty.normTys, Ty.norm, Eff.norm, Eff.empty] using
      HasTypeVsQ.toTel_normal annotation (.cons (sample_typed i) .nil)
  · intro w hw; simp at hw; subst hw; trivial
  · intro t ht; cases ht
  · intro e he; cases he
  · exact ⟨by simp [Ty.WF], rfl⟩
  · exact ⟨by simp [Eff.WF, Eff.empty, Ty.WFList], rfl⟩

/-- 名前の異なる二つの基本型の引数の署名の全欄を、型付きの定数で満たす。 -/
theorem binary_arguments {P B Ψ b} (n m : String) (i j o : BaseTy) (distinct : n ≠ m) :
    BuiltinArgs P B Ψ b (binarySig n m i j o) [] [] [] [.const (sample i), .const (sample j)]
      (.base o) Eff.empty := by
  have annotation : Ty.Annotation P [] [] (.fn [n,m] [.base i,.base j] (.base o) Eff.empty) :=
    ⟨by simp [Ty.WF, Ty.WFList, Eff.WF, Eff.empty, NamesWF, Eff.Canonical, Eff.norm, distinct],
      by trivial, by trivial⟩
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · constructor <;> simp [binarySig,RowTransport,PrimSig.tel,signatureTel,Eff.empty,
      Ty.normTys,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,Eff.RowsIn,Qsig,Qempty,QTy,QTys,QEff,Eff.row]
  · simp [Builtins.RangeAdmissible, binarySig]
  · constructor
    · simp [binarySig,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
        Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,empty_range,Ty.WF,Tel.WF,Eff.WF,Eff.empty,
        Tel.norm,Ty.norm,Eff.norm,Ty.normTys,Ty.WFList,Eff.Canonical]
    · intro a ha; cases ha
    · exact ⟨rfl, by intro i a k ha hk; cases ha⟩
    · intro e he; cases he
    · intro e he; cases he
    · rw [binary_instantiated]
      exact ⟨by simp [Ty.WF, Tel.WF, Ty.WFList, Ty.toTel, Ty.shiftV, Eff.shiftV, Eff.WF, Eff.empty,
        Eff.Canonical, Eff.norm, shiftVTys], by trivial, by trivial⟩
  · rw [binary_instantiated]
    simpa [Ty.normTys, Ty.norm, Eff.norm, Eff.empty] using
      HasTypeVsQ.toTel_normal annotation (.cons (sample_typed i) (.cons (sample_typed j) .nil))
  · intro w hw; simp at hw; rcases hw with rfl | rfl <;> trivial
  · intro t ht; cases ht
  · intro e he; cases he
  · exact ⟨by simp [Ty.WF], rfl⟩
  · exact ⟨by simp [Eff.WF, Eff.empty, Ty.WFList], rfl⟩

/-- 基本型のOptionを返す署名の全欄を、Optionのarityの下で型付きの定数で満たす。 -/
theorem option_arguments {P B Ψ b} (n : String) (i o : BaseTy) (arity : P.DataArity "Option" 1) :
    BuiltinArgs P B Ψ b (optionSig n i o) [] [] [] [.const (sample i)] (.data "Option" [.base o]) Eff.empty := by
  have annotation : Ty.Annotation P [] [] (.fn [n] [.base i] (.data "Option" [.base o]) Eff.empty) :=
    ⟨by simp [Ty.WF, Ty.WFList, Eff.WF, Eff.empty, NamesWF, Eff.Canonical, Eff.norm], by trivial,
      by simp [Ty.Declared, declaredTys, declaredEff, Eff.empty]; exact arity⟩
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · constructor <;> simp [optionSig,RowTransport,PrimSig.tel,signatureTel,Eff.empty,
      Ty.normTys,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,Eff.RowsIn,Qsig,Qempty,QTy,QTys,QEff,Eff.row]
  · simp [Builtins.RangeAdmissible, optionSig]
  · constructor
    · simp [optionSig,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
        Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,empty_range,Ty.WF,Tel.WF,Eff.WF,Eff.empty,
        Tel.norm,Ty.norm,Eff.norm,Ty.normTys,Ty.WFList,Eff.Canonical,mapRangesTys]
    · intro a ha; cases ha
    · exact ⟨rfl, by intro i a k ha hk; cases ha⟩
    · intro e he; cases he
    · intro e he; cases he
    · rw [option_instantiated]
      exact ⟨by simp [Ty.WF, Tel.WF, Ty.WFList, Ty.toTel, Ty.shiftV, Eff.shiftV, Eff.WF, Eff.empty,
        Eff.Canonical, Eff.norm, shiftVTys], by trivial,
        by simp [Tel.Declared, Ty.Declared, declaredTys, declaredEff, Eff.empty, Ty.toTel, Ty.shiftV,
          shiftVTys, Eff.shiftV]; exact arity⟩
  · rw [option_instantiated]
    simpa [Ty.normTys, Ty.norm, Eff.norm, Eff.empty] using
      HasTypeVsQ.toTel_normal annotation (.cons (sample_typed i) .nil)
  · intro w hw; simp at hw; subst hw; trivial
  · intro t ht; cases ht
  · intro e he; cases he
  · exact ⟨by simp [Ty.WF, Ty.WFList], rfl⟩
  · exact ⟨by simp [Eff.WF, Eff.empty, Ty.WFList], rfl⟩

/-- 合成プログラムの丸め方式のarityは0である。 -/
theorem rounding_arity (externals : List (ExternalKey × ExternalDecl)) :
    (program externals).DataArity "RoundingMode" 0 :=
  ⟨⟨"RoundingMode.HalfToEven", _, rfl, rfl⟩, fun c cd lookup owner => by
    obtain ⟨rfl, _⟩ := (rounding_declarations externals).modes c cd lookup owner; rfl⟩

/-- 丸め方式の一つの構成子は、合成プログラムで丸め方式の型に型付く。 -/
theorem mode_typed {externals B Ψ} : HasTypeVQ (program externals) B Ψ Qempty [] [] []
    (.con "RoundingMode.HalfToEven" [] []) (.data "RoundingMode" []) :=
  .V_Con (c := "RoundingMode.HalfToEven") (cd := ⟨"RoundingMode", 0, []⟩) (ts := []) (vs := []) rfl rfl
    ⟨rfl, by intro i a k ha; simp at ha⟩ (by intro t ht; cases ht) .nil
    ⟨by simp [Ty.WF, Ty.WFList], by trivial, ⟨⟨0, rounding_arity externals, rfl⟩, trivial⟩⟩

/-- Decimal.roundの署名の全欄を、Decimal・Integerの定数と丸め方式の構成子で満たす。 -/
theorem round_arguments {externals B Ψ b} :
    BuiltinArgs (program externals) B Ψ b StandardDecimalResponse.API.round.signature [] [] []
      [.const (sample .decimal), .const (sample .integer), .con "RoundingMode.HalfToEven" [] []]
      (.base .decimal) Eff.empty := by
  have arity := rounding_arity externals
  have annotation : Ty.Annotation (program externals) [] []
      (.fn ["x","places","mode"] [.base .decimal,.base .integer,.data "RoundingMode" []] (.base .decimal) Eff.empty) :=
    ⟨by simp [Ty.WF, Ty.WFList, Eff.WF, Eff.empty, NamesWF, Eff.Canonical, Eff.norm], by trivial,
      by simp [Ty.Declared, declaredTys, declaredEff, Eff.empty]; exact arity⟩
  have instantiated : instantiatedTel (Tel.instR [] StandardDecimalResponse.API.round.signature.tel) [] [] =
      Ty.toTel ["x","places","mode"] [.base .decimal,.base .integer,.data "RoundingMode" []] (.base .decimal) Eff.empty := by
    simp [StandardDecimalResponse.API.signature,StandardDecimalResponse.API.names,StandardDecimalResponse.API.inputs,
      StandardDecimalResponse.API.result,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
      Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
      Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
      Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
      empty_range,Ty.toTel,Ty.shiftV,Eff.shiftV,shiftVTys,mapRangesTys]
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · constructor <;> simp [StandardDecimalResponse.API.signature,StandardDecimalResponse.API.names,
      StandardDecimalResponse.API.inputs,StandardDecimalResponse.API.result,RowTransport,PrimSig.tel,signatureTel,Eff.empty,
      Ty.normTys,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,Eff.RowsIn,Qsig,Qempty,QTy,QTys,QEff,Eff.row]
  · simp [Builtins.RangeAdmissible, StandardDecimalResponse.API.signature]
  · constructor
    · simp [StandardDecimalResponse.API.signature,StandardDecimalResponse.API.names,
        StandardDecimalResponse.API.inputs,StandardDecimalResponse.API.result,PrimSig.tel,signatureTel,Tel.instR,
        Tel.substRAt,Tel.mapRanges,
        Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,empty_range,Ty.WF,Tel.WF,Eff.WF,Eff.empty,
        Tel.norm,Ty.norm,Eff.norm,Ty.normTys,Ty.WFList,Eff.Canonical,mapRangesTys]
    · intro a ha; cases ha
    · exact ⟨rfl, by intro i a k ha hk; cases ha⟩
    · intro e he; cases he
    · intro e he; cases he
    · rw [instantiated]
      exact ⟨by simp [Ty.WF, Tel.WF, Ty.WFList, Ty.toTel, Ty.shiftV, Eff.shiftV, Eff.WF, Eff.empty,
        Eff.Canonical, Eff.norm, shiftVTys], by trivial,
        by simp [Tel.Declared, Ty.Declared, declaredTys, declaredEff, Eff.empty, Ty.toTel, Ty.shiftV,
          shiftVTys, Eff.shiftV]; exact arity⟩
  · rw [instantiated]
    simpa [Ty.normTys, Ty.norm, Eff.norm, Eff.empty] using
      HasTypeVsQ.toTel_normal annotation (.cons (sample_typed .decimal) (.cons (sample_typed .integer)
        (.cons mode_typed .nil)))
  · intro w hw; simp at hw; rcases hw with rfl | rfl | rfl
    all_goals simp [Val.Ground, Val.ClosedAt, Val.ClosedList]
  · intro t ht; cases ht
  · intro e he; cases he
  · exact ⟨by simp [Ty.WF], rfl⟩
  · exact ⟨by simp [Eff.WF, Eff.empty, Ty.WFList], rfl⟩

/-- 全構造値の等号の署名の全欄を、型引数Integerと二つのInteger定数で満たす。 -/
theorem equality_arguments {P : Program} {Ψ b} :
    BuiltinArgs P (builtins P) Ψ b (StandardEqualityResponse.fullSignature signatureBase.sat) [.base .integer] [] []
      [.const (sample .integer), .const (sample .integer)] (.base .boolean) Eff.empty := by
  have sat : signatureBase.sat [] (.base .integer) {equality := true} := by
    change Benitoite.Release.satB _ [] _ _ = true
    decide
  have annotation : Ty.Annotation P [] [] (.fn ["left","right"] [.base .integer,.base .integer] (.base .boolean) Eff.empty) :=
    ⟨by simp [Ty.WF, Ty.WFList, Eff.WF, Eff.empty, NamesWF, Eff.Canonical, Eff.norm], by trivial, by trivial⟩
  have instantiated : instantiatedTel (Tel.instR [] (StandardEqualityResponse.fullSignature signatureBase.sat).tel)
      [.base .integer] [] =
      Ty.toTel ["left","right"] [.base .integer,.base .integer] (.base .boolean) Eff.empty := by
    simp [StandardEqualityResponse.fullSignature,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
      Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
      Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
      Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
      empty_range,Ty.toTel,Ty.shiftV,Eff.shiftV,shiftVTys,mapRangesTys]
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
  · constructor <;> simp [StandardEqualityResponse.fullSignature,RowTransport,PrimSig.tel,signatureTel,Eff.empty,
      Ty.normTys,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,Eff.RowsIn,Qsig,Qempty,QTy,QTys,QEff,Eff.row,Ty.norm,
      Ty.WF, Ordinary]
    intro i t p ht hp
    cases i with
    | zero => simp at ht hp; subst ht; subst hp; exact sat
    | succ i => simp at ht
  · simp [Builtins.RangeAdmissible, StandardEqualityResponse.fullSignature]
  · constructor
    · simp [StandardEqualityResponse.fullSignature,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
        Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,empty_range,Ty.WF,Tel.WF,Eff.WF,Eff.empty,
        Tel.norm,Ty.norm,Eff.norm,Ty.normTys,Ty.WFList,Eff.Canonical,mapRangesTys]
    · intro a ha; simp at ha; subst ha; exact ⟨by simp [Ty.WF], by trivial, by trivial⟩
    · refine ⟨rfl, ?_⟩
      intro i a k ha hk
      cases i with
      | zero =>
        simp at ha hk; subst ha
        obtain ⟨d, hd, rfl⟩ := hk
        simp [StandardEqualityResponse.fullSignature] at hd; subst hd
        exact ⟨by constructor, by simp [Ordinary]⟩
      | succ i => simp at ha
    · intro e he; cases he
    · intro e he; cases he
    · rw [instantiated]
      exact ⟨by simp [Ty.WF, Tel.WF, Ty.WFList, Ty.toTel, Ty.shiftV, Eff.shiftV, Eff.WF, Eff.empty,
        Eff.Canonical, Eff.norm, shiftVTys], by trivial, by trivial⟩
  · rw [instantiated]
    simpa [Ty.normTys, Ty.norm, Eff.norm, Eff.empty] using
      HasTypeVsQ.toTel_normal annotation (.cons (sample_typed .integer) (.cons (sample_typed .integer) .nil))
  · intro w hw; simp at hw; subst hw; trivial
  · intro t ht; simp at ht; subst ht; exact ⟨by simp [Ty.WF], rfl⟩
  · intro e he; cases he
  · exact ⟨by simp [Ty.WF], rfl⟩
  · exact ⟨by simp [Eff.WF, Eff.empty, Ty.WFList], rfl⟩
/-- 行の署名が基本型の一引数の形なら、契約の前提を満たす入力がある。 -/
theorem PureRow.Satisfiable.unary {P : Program} (row : Primitive) (n : String) (i o : BaseTy)
    (hsig : row.signature = unarySig n i o) : PureRow.Satisfiable P row.name :=
  ⟨StoreTy.empty, _, [], [], [], _, _, _, row_lookup P row, hsig ▸ unary_arguments n i o⟩

/-- 行の署名が基本型の二引数の形なら、契約の前提を満たす入力がある。 -/
theorem PureRow.Satisfiable.binary {P : Program} (row : Primitive) (n m : String) (i j o : BaseTy)
    (distinct : n ≠ m) (hsig : row.signature = binarySig n m i j o) : PureRow.Satisfiable P row.name :=
  ⟨StoreTy.empty, _, [], [], [], _, _, _, row_lookup P row, hsig ▸ binary_arguments n m i j o distinct⟩

/-- 行の署名が基本型のOptionを返す一引数の形なら、Optionのarityの下で契約の前提を満たす入力がある。 -/
theorem PureRow.Satisfiable.option {P : Program} (row : Primitive) (n : String) (i o : BaseTy)
    (arity : P.DataArity "Option" 1) (hsig : row.signature = optionSig n i o) :
    PureRow.Satisfiable P row.name :=
  ⟨StoreTy.empty, _, [], [], [], _, _, _, row_lookup P row, hsig ▸ option_arguments n i o arity⟩

/-- 演算子の107行と構造の等号の2行は、いずれも契約の前提を満たす入力を持つ。 -/
theorem operator_inputs (P : Program) (row : Primitive) (operator : row.operator = true) :
    PureRow.Satisfiable P row.name := by
  cases row
  case p001 => exact PureRow.Satisfiable.binary .p001 "left" "right" .byte .byte .boolean (by decide) rfl
  case p002 => exact PureRow.Satisfiable.binary .p002 "left" "right" .byte .byte .boolean (by decide) rfl
  case p003 => exact PureRow.Satisfiable.binary .p003 "left" "right" .byte .byte .boolean (by decide) rfl
  case p004 => exact PureRow.Satisfiable.binary .p004 "left" "right" .byte .byte .boolean (by decide) rfl
  case p005 => exact PureRow.Satisfiable.binary .p005 "left" "right" .character .character .boolean (by decide) rfl
  case p006 => exact PureRow.Satisfiable.binary .p006 "left" "right" .character .character .boolean (by decide) rfl
  case p007 => exact PureRow.Satisfiable.binary .p007 "left" "right" .character .character .boolean (by decide) rfl
  case p008 => exact PureRow.Satisfiable.binary .p008 "left" "right" .character .character .boolean (by decide) rfl
  case p009 => exact PureRow.Satisfiable.binary .p009 "left" "right" .decimal .decimal .decimal (by decide) rfl
  case p010 => exact PureRow.Satisfiable.binary .p010 "left" "right" .decimal .decimal .decimal (by decide) rfl
  case p011 => exact PureRow.Satisfiable.binary .p011 "left" "right" .decimal .decimal .boolean (by decide) rfl
  case p012 => exact PureRow.Satisfiable.binary .p012 "left" "right" .decimal .decimal .boolean (by decide) rfl
  case p013 => exact PureRow.Satisfiable.binary .p013 "left" "right" .decimal .decimal .boolean (by decide) rfl
  case p014 => exact PureRow.Satisfiable.binary .p014 "left" "right" .decimal .decimal .boolean (by decide) rfl
  case p015 => exact PureRow.Satisfiable.binary .p015 "left" "right" .decimal .decimal .decimal (by decide) rfl
  case p016 => exact PureRow.Satisfiable.unary .p016 "value" .decimal .decimal rfl
  case p017 => exact PureRow.Satisfiable.binary .p017 "left" "right" .decimal .decimal .decimal (by decide) rfl
  case p018 => exact PureRow.Satisfiable.binary .p018 "left" "right" .float .float .float (by decide) rfl
  case p019 => exact PureRow.Satisfiable.binary .p019 "left" "right" .float .float .float (by decide) rfl
  case p020 => exact PureRow.Satisfiable.binary .p020 "left" "right" .float .float .boolean (by decide) rfl
  case p021 => exact PureRow.Satisfiable.binary .p021 "left" "right" .float .float .boolean (by decide) rfl
  case p022 => exact PureRow.Satisfiable.binary .p022 "left" "right" .float .float .boolean (by decide) rfl
  case p023 => exact PureRow.Satisfiable.binary .p023 "left" "right" .float .float .boolean (by decide) rfl
  case p024 => exact PureRow.Satisfiable.binary .p024 "left" "right" .float .float .float (by decide) rfl
  case p025 => exact PureRow.Satisfiable.unary .p025 "value" .float .float rfl
  case p026 => exact PureRow.Satisfiable.binary .p026 "left" "right" .float .float .float (by decide) rfl
  case p027 => exact PureRow.Satisfiable.binary .p027 "left" "right" .float32 .float32 .float32 (by decide) rfl
  case p028 => exact PureRow.Satisfiable.binary .p028 "left" "right" .float32 .float32 .float32 (by decide) rfl
  case p029 => exact PureRow.Satisfiable.binary .p029 "left" "right" .float32 .float32 .boolean (by decide) rfl
  case p030 => exact PureRow.Satisfiable.binary .p030 "left" "right" .float32 .float32 .boolean (by decide) rfl
  case p031 => exact PureRow.Satisfiable.binary .p031 "left" "right" .float32 .float32 .boolean (by decide) rfl
  case p032 => exact PureRow.Satisfiable.binary .p032 "left" "right" .float32 .float32 .boolean (by decide) rfl
  case p033 => exact PureRow.Satisfiable.binary .p033 "left" "right" .float32 .float32 .float32 (by decide) rfl
  case p034 => exact PureRow.Satisfiable.unary .p034 "value" .float32 .float32 rfl
  case p035 => exact PureRow.Satisfiable.binary .p035 "left" "right" .float32 .float32 .float32 (by decide) rfl
  case p036 => exact PureRow.Satisfiable.binary .p036 "left" "right" .integer .integer .integer (by decide) rfl
  case p037 => exact PureRow.Satisfiable.binary .p037 "left" "right" .integer .integer .integer (by decide) rfl
  case p038 => exact PureRow.Satisfiable.binary .p038 "left" "right" .integer .integer .boolean (by decide) rfl
  case p039 => exact PureRow.Satisfiable.binary .p039 "left" "right" .integer .integer .boolean (by decide) rfl
  case p040 => exact PureRow.Satisfiable.binary .p040 "left" "right" .integer .integer .boolean (by decide) rfl
  case p041 => exact PureRow.Satisfiable.binary .p041 "left" "right" .integer .integer .boolean (by decide) rfl
  case p042 => exact PureRow.Satisfiable.binary .p042 "left" "right" .integer .integer .integer (by decide) rfl
  case p043 => exact PureRow.Satisfiable.binary .p043 "left" "right" .integer .integer .integer (by decide) rfl
  case p044 => exact PureRow.Satisfiable.unary .p044 "value" .integer .integer rfl
  case p045 => exact PureRow.Satisfiable.binary .p045 "left" "right" .integer .integer .integer (by decide) rfl
  case p046 => exact PureRow.Satisfiable.binary .p046 "left" "right" .integer16 .integer16 .integer16 (by decide) rfl
  case p047 => exact PureRow.Satisfiable.binary .p047 "left" "right" .integer16 .integer16 .integer16 (by decide) rfl
  case p048 => exact PureRow.Satisfiable.binary .p048 "left" "right" .integer16 .integer16 .boolean (by decide) rfl
  case p049 => exact PureRow.Satisfiable.binary .p049 "left" "right" .integer16 .integer16 .boolean (by decide) rfl
  case p050 => exact PureRow.Satisfiable.binary .p050 "left" "right" .integer16 .integer16 .boolean (by decide) rfl
  case p051 => exact PureRow.Satisfiable.binary .p051 "left" "right" .integer16 .integer16 .boolean (by decide) rfl
  case p052 => exact PureRow.Satisfiable.binary .p052 "left" "right" .integer16 .integer16 .integer16 (by decide) rfl
  case p053 => exact PureRow.Satisfiable.binary .p053 "left" "right" .integer16 .integer16 .integer16 (by decide) rfl
  case p054 => exact PureRow.Satisfiable.unary .p054 "value" .integer16 .integer16 rfl
  case p055 => exact PureRow.Satisfiable.binary .p055 "left" "right" .integer16 .integer16 .integer16 (by decide) rfl
  case p056 => exact PureRow.Satisfiable.binary .p056 "left" "right" .integer32 .integer32 .integer32 (by decide) rfl
  case p057 => exact PureRow.Satisfiable.binary .p057 "left" "right" .integer32 .integer32 .integer32 (by decide) rfl
  case p058 => exact PureRow.Satisfiable.binary .p058 "left" "right" .integer32 .integer32 .boolean (by decide) rfl
  case p059 => exact PureRow.Satisfiable.binary .p059 "left" "right" .integer32 .integer32 .boolean (by decide) rfl
  case p060 => exact PureRow.Satisfiable.binary .p060 "left" "right" .integer32 .integer32 .boolean (by decide) rfl
  case p061 => exact PureRow.Satisfiable.binary .p061 "left" "right" .integer32 .integer32 .boolean (by decide) rfl
  case p062 => exact PureRow.Satisfiable.binary .p062 "left" "right" .integer32 .integer32 .integer32 (by decide) rfl
  case p063 => exact PureRow.Satisfiable.binary .p063 "left" "right" .integer32 .integer32 .integer32 (by decide) rfl
  case p064 => exact PureRow.Satisfiable.unary .p064 "value" .integer32 .integer32 rfl
  case p065 => exact PureRow.Satisfiable.binary .p065 "left" "right" .integer32 .integer32 .integer32 (by decide) rfl
  case p066 => exact PureRow.Satisfiable.binary .p066 "left" "right" .integer8 .integer8 .integer8 (by decide) rfl
  case p067 => exact PureRow.Satisfiable.binary .p067 "left" "right" .integer8 .integer8 .integer8 (by decide) rfl
  case p068 => exact PureRow.Satisfiable.binary .p068 "left" "right" .integer8 .integer8 .boolean (by decide) rfl
  case p069 => exact PureRow.Satisfiable.binary .p069 "left" "right" .integer8 .integer8 .boolean (by decide) rfl
  case p070 => exact PureRow.Satisfiable.binary .p070 "left" "right" .integer8 .integer8 .boolean (by decide) rfl
  case p071 => exact PureRow.Satisfiable.binary .p071 "left" "right" .integer8 .integer8 .boolean (by decide) rfl
  case p072 => exact PureRow.Satisfiable.binary .p072 "left" "right" .integer8 .integer8 .integer8 (by decide) rfl
  case p073 => exact PureRow.Satisfiable.binary .p073 "left" "right" .integer8 .integer8 .integer8 (by decide) rfl
  case p074 => exact PureRow.Satisfiable.unary .p074 "value" .integer8 .integer8 rfl
  case p075 => exact PureRow.Satisfiable.binary .p075 "left" "right" .integer8 .integer8 .integer8 (by decide) rfl
  case p077 => exact PureRow.Satisfiable.binary .p077 "left" "right" .string .string .string (by decide) rfl
  case p078 => exact PureRow.Satisfiable.binary .p078 "left" "right" .string .string .boolean (by decide) rfl
  case p079 => exact PureRow.Satisfiable.binary .p079 "left" "right" .string .string .boolean (by decide) rfl
  case p080 => exact PureRow.Satisfiable.binary .p080 "left" "right" .string .string .boolean (by decide) rfl
  case p081 => exact PureRow.Satisfiable.binary .p081 "left" "right" .string .string .boolean (by decide) rfl
  case p082 => exact PureRow.Satisfiable.binary .p082 "left" "right" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide) rfl
  case p083 => exact PureRow.Satisfiable.binary .p083 "left" "right" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide) rfl
  case p084 => exact PureRow.Satisfiable.binary .p084 "left" "right" .unsignedInteger16 .unsignedInteger16 .boolean (by decide) rfl
  case p085 => exact PureRow.Satisfiable.binary .p085 "left" "right" .unsignedInteger16 .unsignedInteger16 .boolean (by decide) rfl
  case p086 => exact PureRow.Satisfiable.binary .p086 "left" "right" .unsignedInteger16 .unsignedInteger16 .boolean (by decide) rfl
  case p087 => exact PureRow.Satisfiable.binary .p087 "left" "right" .unsignedInteger16 .unsignedInteger16 .boolean (by decide) rfl
  case p088 => exact PureRow.Satisfiable.binary .p088 "left" "right" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide) rfl
  case p089 => exact PureRow.Satisfiable.binary .p089 "left" "right" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide) rfl
  case p090 => exact PureRow.Satisfiable.binary .p090 "left" "right" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide) rfl
  case p091 => exact PureRow.Satisfiable.binary .p091 "left" "right" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide) rfl
  case p092 => exact PureRow.Satisfiable.binary .p092 "left" "right" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide) rfl
  case p093 => exact PureRow.Satisfiable.binary .p093 "left" "right" .unsignedInteger32 .unsignedInteger32 .boolean (by decide) rfl
  case p094 => exact PureRow.Satisfiable.binary .p094 "left" "right" .unsignedInteger32 .unsignedInteger32 .boolean (by decide) rfl
  case p095 => exact PureRow.Satisfiable.binary .p095 "left" "right" .unsignedInteger32 .unsignedInteger32 .boolean (by decide) rfl
  case p096 => exact PureRow.Satisfiable.binary .p096 "left" "right" .unsignedInteger32 .unsignedInteger32 .boolean (by decide) rfl
  case p097 => exact PureRow.Satisfiable.binary .p097 "left" "right" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide) rfl
  case p098 => exact PureRow.Satisfiable.binary .p098 "left" "right" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide) rfl
  case p099 => exact PureRow.Satisfiable.binary .p099 "left" "right" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide) rfl
  case p100 => exact PureRow.Satisfiable.binary .p100 "left" "right" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide) rfl
  case p101 => exact PureRow.Satisfiable.binary .p101 "left" "right" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide) rfl
  case p102 => exact PureRow.Satisfiable.binary .p102 "left" "right" .unsignedInteger64 .unsignedInteger64 .boolean (by decide) rfl
  case p103 => exact PureRow.Satisfiable.binary .p103 "left" "right" .unsignedInteger64 .unsignedInteger64 .boolean (by decide) rfl
  case p104 => exact PureRow.Satisfiable.binary .p104 "left" "right" .unsignedInteger64 .unsignedInteger64 .boolean (by decide) rfl
  case p105 => exact PureRow.Satisfiable.binary .p105 "left" "right" .unsignedInteger64 .unsignedInteger64 .boolean (by decide) rfl
  case p106 => exact PureRow.Satisfiable.binary .p106 "left" "right" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide) rfl
  case p107 => exact PureRow.Satisfiable.binary .p107 "left" "right" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide) rfl
  case p108 => exact PureRow.Satisfiable.binary .p108 "left" "right" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide) rfl
  case p109 => exact ⟨StoreTy.empty, _, [.base .integer], [], [], _, _, _, row_lookup P .p109, equality_arguments⟩
  case p110 => exact ⟨StoreTy.empty, _, [.base .integer], [], [], _, _, _, row_lookup P .p110, equality_arguments⟩
  all_goals cases operator

/-- 数値の公開モジュールの全166行は、合成プログラムで契約の前提を満たす入力を持つ。 -/
theorem numeric_inputs (externals : List (ExternalKey × ExternalDecl)) (row : Primitive)
    (numeric : row.numeric = true) : PureRow.Satisfiable (program externals) row.name := by
  cases row
  case p111 => exact PureRow.Satisfiable.binary .p111 "a" "b" .byte .byte .byte (by decide) rfl
  case p112 => exact PureRow.Satisfiable.binary .p112 "a" "b" .byte .byte .byte (by decide) rfl
  case p113 => exact PureRow.Satisfiable.unary .p113 "a" .byte .byte rfl
  case p114 => exact PureRow.Satisfiable.binary .p114 "a" "b" .byte .byte .byte (by decide) rfl
  case p115 => exact PureRow.Satisfiable.option .p115 "n" .integer .byte (option_declarations externals).arity rfl
  case p116 => exact PureRow.Satisfiable.binary .p116 "a" "n" .byte .integer .byte (by decide) rfl
  case p117 => exact PureRow.Satisfiable.binary .p117 "a" "n" .byte .integer .byte (by decide) rfl
  case p118 => exact PureRow.Satisfiable.unary .p118 "b" .byte .integer rfl
  case p119 => exact PureRow.Satisfiable.unary .p119 "b" .byte .string rfl
  case p136 => exact PureRow.Satisfiable.option .p136 "n" .integer .character (option_declarations externals).arity rfl
  case p137 => exact PureRow.Satisfiable.unary .p137 "c" .character .boolean rfl
  case p138 => exact PureRow.Satisfiable.unary .p138 "c" .character .boolean rfl
  case p139 => exact PureRow.Satisfiable.unary .p139 "c" .character .boolean rfl
  case p140 => exact PureRow.Satisfiable.unary .p140 "c" .character .boolean rfl
  case p141 => exact PureRow.Satisfiable.unary .p141 "c" .character .boolean rfl
  case p142 => exact PureRow.Satisfiable.unary .p142 "c" .character .boolean rfl
  case p143 => exact PureRow.Satisfiable.unary .p143 "c" .character .boolean rfl
  case p144 => exact PureRow.Satisfiable.unary .p144 "c" .character .integer rfl
  case p145 => exact PureRow.Satisfiable.unary .p145 "c" .character .string rfl
  case p146 => exact PureRow.Satisfiable.unary .p146 "c" .character .string rfl
  case p147 => exact PureRow.Satisfiable.unary .p147 "c" .character .string rfl
  case p148 => exact PureRow.Satisfiable.unary .p148 "x" .decimal .decimal rfl
  case p149 => exact PureRow.Satisfiable.option .p149 "x" .float .decimal (option_declarations externals).arity rfl
  case p150 => exact PureRow.Satisfiable.unary .p150 "n" .integer .decimal rfl
  case p151 => exact PureRow.Satisfiable.option .p151 "s" .string .decimal (option_declarations externals).arity rfl
  case p152 => exact ⟨StoreTy.empty, _, [], [], [], _, _, _, row_lookup _ .p152, round_arguments⟩
  case p153 => exact PureRow.Satisfiable.unary .p153 "x" .decimal .float rfl
  case p154 => exact PureRow.Satisfiable.unary .p154 "x" .decimal .string rfl
  case p155 => exact PureRow.Satisfiable.option .p155 "x" .decimal .integer (option_declarations externals).arity rfl
  case p164 => exact PureRow.Satisfiable.unary .p164 "x" .float .float rfl
  case p165 => exact PureRow.Satisfiable.unary .p165 "x" .float .float rfl
  case p166 => exact PureRow.Satisfiable.unary .p166 "x" .float .float rfl
  case p167 => exact PureRow.Satisfiable.unary .p167 "x" .float .boolean rfl
  case p168 => exact PureRow.Satisfiable.option .p168 "s" .string .float (option_declarations externals).arity rfl
  case p169 => exact PureRow.Satisfiable.unary .p169 "x" .float .float rfl
  case p170 => exact PureRow.Satisfiable.unary .p170 "x" .float .float rfl
  case p171 => exact PureRow.Satisfiable.unary .p171 "x" .float .string rfl
  case p172 => exact PureRow.Satisfiable.option .p172 "x" .float .integer (option_declarations externals).arity rfl
  case p173 => exact PureRow.Satisfiable.unary .p173 "n" .float32 .float32 rfl
  case p174 => exact PureRow.Satisfiable.unary .p174 "n" .float32 .float32 rfl
  case p175 => exact PureRow.Satisfiable.unary .p175 "n" .float32 .float32 rfl
  case p176 => exact PureRow.Satisfiable.option .p176 "n" .float .float32 (option_declarations externals).arity rfl
  case p177 => exact PureRow.Satisfiable.unary .p177 "n" .float32 .boolean rfl
  case p178 => exact PureRow.Satisfiable.unary .p178 "n" .float32 .boolean rfl
  case p179 => exact PureRow.Satisfiable.option .p179 "s" .string .float32 (option_declarations externals).arity rfl
  case p180 => exact PureRow.Satisfiable.unary .p180 "n" .float32 .float32 rfl
  case p181 => exact PureRow.Satisfiable.unary .p181 "n" .float32 .float32 rfl
  case p182 => exact PureRow.Satisfiable.unary .p182 "n" .float32 .float rfl
  case p183 => exact PureRow.Satisfiable.unary .p183 "n" .float32 .string rfl
  case p184 => exact PureRow.Satisfiable.option .p184 "n" .float32 .integer (option_declarations externals).arity rfl
  case p189 => exact PureRow.Satisfiable.unary .p189 "n" .integer .integer rfl
  case p190 => exact PureRow.Satisfiable.binary .p190 "a" "b" .integer .integer .integer (by decide) rfl
  case p191 => exact PureRow.Satisfiable.binary .p191 "a" "b" .integer .integer .integer (by decide) rfl
  case p192 => exact PureRow.Satisfiable.unary .p192 "a" .integer .integer rfl
  case p193 => exact PureRow.Satisfiable.binary .p193 "a" "b" .integer .integer .integer (by decide) rfl
  case p194 => exact PureRow.Satisfiable.binary .p194 "a" "b" .integer .integer .integer (by decide) rfl
  case p195 => exact PureRow.Satisfiable.binary .p195 "a" "b" .integer .integer .integer (by decide) rfl
  case p196 => exact PureRow.Satisfiable.binary .p196 "a" "b" .integer .integer .integer (by decide) rfl
  case p197 => exact PureRow.Satisfiable.binary .p197 "a" "b" .integer .integer .integer (by decide) rfl
  case p198 => exact PureRow.Satisfiable.option .p198 "s" .string .integer (option_declarations externals).arity rfl
  case p199 => exact PureRow.Satisfiable.binary .p199 "a" "n" .integer .integer .integer (by decide) rfl
  case p200 => exact PureRow.Satisfiable.binary .p200 "a" "n" .integer .integer .integer (by decide) rfl
  case p201 => exact PureRow.Satisfiable.binary .p201 "a" "n" .integer .integer .integer (by decide) rfl
  case p202 => exact PureRow.Satisfiable.unary .p202 "n" .integer .float rfl
  case p203 => exact PureRow.Satisfiable.unary .p203 "n" .integer .string rfl
  case p204 => exact PureRow.Satisfiable.unary .p204 "n" .integer16 .integer16 rfl
  case p205 => exact PureRow.Satisfiable.binary .p205 "a" "b" .integer16 .integer16 .integer16 (by decide) rfl
  case p206 => exact PureRow.Satisfiable.binary .p206 "a" "b" .integer16 .integer16 .integer16 (by decide) rfl
  case p207 => exact PureRow.Satisfiable.unary .p207 "a" .integer16 .integer16 rfl
  case p208 => exact PureRow.Satisfiable.binary .p208 "a" "b" .integer16 .integer16 .integer16 (by decide) rfl
  case p209 => exact PureRow.Satisfiable.binary .p209 "a" "b" .integer16 .integer16 .integer16 (by decide) rfl
  case p210 => exact PureRow.Satisfiable.binary .p210 "a" "b" .integer16 .integer16 .integer16 (by decide) rfl
  case p211 => exact PureRow.Satisfiable.option .p211 "n" .integer .integer16 (option_declarations externals).arity rfl
  case p212 => exact PureRow.Satisfiable.binary .p212 "a" "b" .integer16 .integer16 .integer16 (by decide) rfl
  case p213 => exact PureRow.Satisfiable.binary .p213 "a" "b" .integer16 .integer16 .integer16 (by decide) rfl
  case p214 => exact PureRow.Satisfiable.option .p214 "s" .string .integer16 (option_declarations externals).arity rfl
  case p215 => exact PureRow.Satisfiable.binary .p215 "a" "n" .integer16 .integer .integer16 (by decide) rfl
  case p216 => exact PureRow.Satisfiable.binary .p216 "a" "n" .integer16 .integer .integer16 (by decide) rfl
  case p217 => exact PureRow.Satisfiable.binary .p217 "a" "n" .integer16 .integer .integer16 (by decide) rfl
  case p218 => exact PureRow.Satisfiable.unary .p218 "n" .integer16 .float rfl
  case p219 => exact PureRow.Satisfiable.unary .p219 "n" .integer16 .integer rfl
  case p220 => exact PureRow.Satisfiable.unary .p220 "n" .integer16 .string rfl
  case p221 => exact PureRow.Satisfiable.unary .p221 "n" .integer32 .integer32 rfl
  case p222 => exact PureRow.Satisfiable.binary .p222 "a" "b" .integer32 .integer32 .integer32 (by decide) rfl
  case p223 => exact PureRow.Satisfiable.binary .p223 "a" "b" .integer32 .integer32 .integer32 (by decide) rfl
  case p224 => exact PureRow.Satisfiable.unary .p224 "a" .integer32 .integer32 rfl
  case p225 => exact PureRow.Satisfiable.binary .p225 "a" "b" .integer32 .integer32 .integer32 (by decide) rfl
  case p226 => exact PureRow.Satisfiable.binary .p226 "a" "b" .integer32 .integer32 .integer32 (by decide) rfl
  case p227 => exact PureRow.Satisfiable.binary .p227 "a" "b" .integer32 .integer32 .integer32 (by decide) rfl
  case p228 => exact PureRow.Satisfiable.option .p228 "n" .integer .integer32 (option_declarations externals).arity rfl
  case p229 => exact PureRow.Satisfiable.binary .p229 "a" "b" .integer32 .integer32 .integer32 (by decide) rfl
  case p230 => exact PureRow.Satisfiable.binary .p230 "a" "b" .integer32 .integer32 .integer32 (by decide) rfl
  case p231 => exact PureRow.Satisfiable.option .p231 "s" .string .integer32 (option_declarations externals).arity rfl
  case p232 => exact PureRow.Satisfiable.binary .p232 "a" "n" .integer32 .integer .integer32 (by decide) rfl
  case p233 => exact PureRow.Satisfiable.binary .p233 "a" "n" .integer32 .integer .integer32 (by decide) rfl
  case p234 => exact PureRow.Satisfiable.binary .p234 "a" "n" .integer32 .integer .integer32 (by decide) rfl
  case p235 => exact PureRow.Satisfiable.unary .p235 "n" .integer32 .float rfl
  case p236 => exact PureRow.Satisfiable.unary .p236 "n" .integer32 .integer rfl
  case p237 => exact PureRow.Satisfiable.unary .p237 "n" .integer32 .string rfl
  case p238 => exact PureRow.Satisfiable.unary .p238 "n" .integer8 .integer8 rfl
  case p239 => exact PureRow.Satisfiable.binary .p239 "a" "b" .integer8 .integer8 .integer8 (by decide) rfl
  case p240 => exact PureRow.Satisfiable.binary .p240 "a" "b" .integer8 .integer8 .integer8 (by decide) rfl
  case p241 => exact PureRow.Satisfiable.unary .p241 "a" .integer8 .integer8 rfl
  case p242 => exact PureRow.Satisfiable.binary .p242 "a" "b" .integer8 .integer8 .integer8 (by decide) rfl
  case p243 => exact PureRow.Satisfiable.binary .p243 "a" "b" .integer8 .integer8 .integer8 (by decide) rfl
  case p244 => exact PureRow.Satisfiable.binary .p244 "a" "b" .integer8 .integer8 .integer8 (by decide) rfl
  case p245 => exact PureRow.Satisfiable.option .p245 "n" .integer .integer8 (option_declarations externals).arity rfl
  case p246 => exact PureRow.Satisfiable.binary .p246 "a" "b" .integer8 .integer8 .integer8 (by decide) rfl
  case p247 => exact PureRow.Satisfiable.binary .p247 "a" "b" .integer8 .integer8 .integer8 (by decide) rfl
  case p248 => exact PureRow.Satisfiable.option .p248 "s" .string .integer8 (option_declarations externals).arity rfl
  case p249 => exact PureRow.Satisfiable.binary .p249 "a" "n" .integer8 .integer .integer8 (by decide) rfl
  case p250 => exact PureRow.Satisfiable.binary .p250 "a" "n" .integer8 .integer .integer8 (by decide) rfl
  case p251 => exact PureRow.Satisfiable.binary .p251 "a" "n" .integer8 .integer .integer8 (by decide) rfl
  case p252 => exact PureRow.Satisfiable.unary .p252 "n" .integer8 .float rfl
  case p253 => exact PureRow.Satisfiable.unary .p253 "n" .integer8 .integer rfl
  case p254 => exact PureRow.Satisfiable.unary .p254 "n" .integer8 .string rfl
  case p322 => exact PureRow.Satisfiable.unary .p322 "n" .unsignedInteger16 .unsignedInteger16 rfl
  case p323 => exact PureRow.Satisfiable.binary .p323 "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide) rfl
  case p324 => exact PureRow.Satisfiable.binary .p324 "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide) rfl
  case p325 => exact PureRow.Satisfiable.unary .p325 "a" .unsignedInteger16 .unsignedInteger16 rfl
  case p326 => exact PureRow.Satisfiable.binary .p326 "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide) rfl
  case p327 => exact PureRow.Satisfiable.binary .p327 "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide) rfl
  case p328 => exact PureRow.Satisfiable.binary .p328 "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide) rfl
  case p329 => exact PureRow.Satisfiable.option .p329 "n" .integer .unsignedInteger16 (option_declarations externals).arity rfl
  case p330 => exact PureRow.Satisfiable.binary .p330 "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide) rfl
  case p331 => exact PureRow.Satisfiable.binary .p331 "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide) rfl
  case p332 => exact PureRow.Satisfiable.option .p332 "s" .string .unsignedInteger16 (option_declarations externals).arity rfl
  case p333 => exact PureRow.Satisfiable.binary .p333 "a" "n" .unsignedInteger16 .integer .unsignedInteger16 (by decide) rfl
  case p334 => exact PureRow.Satisfiable.binary .p334 "a" "n" .unsignedInteger16 .integer .unsignedInteger16 (by decide) rfl
  case p335 => exact PureRow.Satisfiable.unary .p335 "n" .unsignedInteger16 .float rfl
  case p336 => exact PureRow.Satisfiable.unary .p336 "n" .unsignedInteger16 .integer rfl
  case p337 => exact PureRow.Satisfiable.unary .p337 "n" .unsignedInteger16 .string rfl
  case p338 => exact PureRow.Satisfiable.unary .p338 "n" .unsignedInteger32 .unsignedInteger32 rfl
  case p339 => exact PureRow.Satisfiable.binary .p339 "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide) rfl
  case p340 => exact PureRow.Satisfiable.binary .p340 "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide) rfl
  case p341 => exact PureRow.Satisfiable.unary .p341 "a" .unsignedInteger32 .unsignedInteger32 rfl
  case p342 => exact PureRow.Satisfiable.binary .p342 "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide) rfl
  case p343 => exact PureRow.Satisfiable.binary .p343 "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide) rfl
  case p344 => exact PureRow.Satisfiable.binary .p344 "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide) rfl
  case p345 => exact PureRow.Satisfiable.option .p345 "n" .integer .unsignedInteger32 (option_declarations externals).arity rfl
  case p346 => exact PureRow.Satisfiable.binary .p346 "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide) rfl
  case p347 => exact PureRow.Satisfiable.binary .p347 "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide) rfl
  case p348 => exact PureRow.Satisfiable.option .p348 "s" .string .unsignedInteger32 (option_declarations externals).arity rfl
  case p349 => exact PureRow.Satisfiable.binary .p349 "a" "n" .unsignedInteger32 .integer .unsignedInteger32 (by decide) rfl
  case p350 => exact PureRow.Satisfiable.binary .p350 "a" "n" .unsignedInteger32 .integer .unsignedInteger32 (by decide) rfl
  case p351 => exact PureRow.Satisfiable.unary .p351 "n" .unsignedInteger32 .float rfl
  case p352 => exact PureRow.Satisfiable.unary .p352 "n" .unsignedInteger32 .integer rfl
  case p353 => exact PureRow.Satisfiable.unary .p353 "n" .unsignedInteger32 .string rfl
  case p354 => exact PureRow.Satisfiable.unary .p354 "n" .unsignedInteger64 .unsignedInteger64 rfl
  case p355 => exact PureRow.Satisfiable.binary .p355 "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide) rfl
  case p356 => exact PureRow.Satisfiable.binary .p356 "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide) rfl
  case p357 => exact PureRow.Satisfiable.unary .p357 "a" .unsignedInteger64 .unsignedInteger64 rfl
  case p358 => exact PureRow.Satisfiable.binary .p358 "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide) rfl
  case p359 => exact PureRow.Satisfiable.binary .p359 "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide) rfl
  case p360 => exact PureRow.Satisfiable.binary .p360 "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide) rfl
  case p361 => exact PureRow.Satisfiable.option .p361 "x" .decimal .unsignedInteger64 (option_declarations externals).arity rfl
  case p362 => exact PureRow.Satisfiable.option .p362 "n" .integer .unsignedInteger64 (option_declarations externals).arity rfl
  case p363 => exact PureRow.Satisfiable.binary .p363 "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide) rfl
  case p364 => exact PureRow.Satisfiable.binary .p364 "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide) rfl
  case p365 => exact PureRow.Satisfiable.option .p365 "s" .string .unsignedInteger64 (option_declarations externals).arity rfl
  case p366 => exact PureRow.Satisfiable.binary .p366 "a" "n" .unsignedInteger64 .integer .unsignedInteger64 (by decide) rfl
  case p367 => exact PureRow.Satisfiable.binary .p367 "a" "n" .unsignedInteger64 .integer .unsignedInteger64 (by decide) rfl
  case p368 => exact PureRow.Satisfiable.unary .p368 "n" .unsignedInteger64 .decimal rfl
  case p369 => exact PureRow.Satisfiable.unary .p369 "n" .unsignedInteger64 .float rfl
  case p370 => exact PureRow.Satisfiable.option .p370 "n" .unsignedInteger64 .integer (option_declarations externals).arity rfl
  case p371 => exact PureRow.Satisfiable.unary .p371 "n" .unsignedInteger64 .string rfl
  all_goals cases numeric

/-- 前提を満たす入力で、Decimal.roundと %eq の契約は合成表のδの型付きの応答を返す。 -/
example (externals : List (ExternalKey × ExternalDecl)) :
    (∃ Ψ sg ts es rs ws a e, (builtins (program externals)).sig "Decimal.round" = some sg ∧
      BuiltinArgs (program externals) (builtins (program externals)) Ψ "Decimal.round" sg ts es rs ws a e ∧
      ∃ out, (builtins (program externals)).delta "Decimal.round" ts es rs ws = some out ∧
        Outcome.Typed (program externals) (builtins (program externals)) Ψ out a) ∧
    (∃ Ψ sg ts es rs ws a e, (builtins (program externals)).sig "%eq" = some sg ∧
      BuiltinArgs (program externals) (builtins (program externals)) Ψ "%eq" sg ts es rs ws a e ∧
      ∃ out, (builtins (program externals)).delta "%eq" ts es rs ws = some out ∧
        Outcome.Typed (program externals) (builtins (program externals)) Ψ out a) := by
  constructor
  · obtain ⟨Ψ, sg, ts, es, rs, ws, a, e, lookup, args⟩ := numeric_inputs externals .p152 rfl
    obtain ⟨out, delta, _, typed, _⟩ := numeric_rows externals .p152 rfl Ψ sg ts es rs ws a e lookup args
    exact ⟨Ψ, sg, ts, es, rs, ws, a, e, lookup, args, out, delta, typed⟩
  · obtain ⟨Ψ, sg, ts, es, rs, ws, a, e, lookup, args⟩ := operator_inputs (program externals) .p109 rfl
    obtain ⟨out, delta, _, typed, _⟩ := operator_rows (program externals) .p109 rfl Ψ sg ts es rs ws a e lookup args
    exact ⟨Ψ, sg, ts, es, rs, ws, a, e, lookup, args, out, delta, typed⟩

end
end Benitoite.Release.Refinement.StandardModel
