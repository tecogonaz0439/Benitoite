# 群B以降の署名

2026-11-03。F01〜F07、S01〜S36、全328 APIの元署名と内部の安全な入口を固定する。証明済みの範囲は results.md で区別する。P/B/Ψ/Q/C/Γ/Φ は現行 Refinement の判断と同じ引数である。

## F01：元規則の直接前提

入力は `HasTypeVQ P B Ψ Q C Γ Φ v T` と、同じ v の当該構文への等号である。以下の直接規則の変数のうち、値構文に現れる変数と P/B/Ψ/Q/C/Γ/Φ/T を全称量化し、残る変数を出力で存在量化する。各規則の矢印の左辺を、直接前提の連言として返す。元の型付けを record へ包んで返さない。

その連言に次の到達関係を加える。この規約と末尾の直接規則の写しで、各変数・型・前提を指定する。

| 入口 | 到達関係 |
|---|---|
| inv_fnRef/prim/op/dependentLam/closure/externalRef | 元の `.dependentFn t` に対し `∃ u, T.fnCore=some u ∧ TelClosure P Γ Φ t u` |
| inv_lam/raise | 元の `.fn ns ps r e` に対し `∃ u, T.fnCore=some u ∧ TelClosure P Γ Φ (Ty.toTel ns ps r e) u` |
| inv_lam_wf | inv_lam の直接前提のうち NamesWF/WF/Sorted/Declared を射影する |
| inv_var | 元のlookup型aと芯bに対し `T.norm.core=b ∧ Ty.LeQ P Γ Φ a.norm.core b`。最外の篩はfactsで読む |
| inv_const | ConstOKと`T.norm.core=c.type.norm.core`。既存ValueFacts.inv_const |
| inv_list_core | 元要素aのEach/Annotation、`T.norm.core=.list b`と要素の`LeQ a b`。本番ValueInversionで証明済み |
| inv_con | 同じ構成子・型引数・欄導出、`T.norm.core=.data cd.data us`とTypeArgsLe。既存ValueFacts.inv_con |
| inv_atError | 同じResultShape.Declaredと`T.norm.core=shape.errorType.norm.core`。一般の逆転証明は後続 |
| inv_checked | 同じvalKind/valContent/保持対象、Holdsによる芯のscoped/opaqueの等号と範囲被覆。既存HeldValues.inv_checked |
| inv_checkedRequest | 同じ要求の型付け/groundVal/reqTarget/保持対象と、Holdsの芯と範囲被覆。既存HeldValues.inv_checkedRequest |
| inv_checkedAt | 同じCheckedWitnessと、Holdsの芯と範囲被覆。既存HeldValues.inv_checkedAt |
| inv_mapV | 元の鍵k・値aに対し `∃ k' b, T.norm.core=.map k' b ∧ k.norm=k'.norm ∧ Ty.LeQ P Γ Φ a b` |
| inv_setV | 元の要素aに対し `∃ b, T.norm.core=.set b ∧ a.norm=b.norm` |
| inv_bytesV | `T.norm.core=.bytes` |
| inv_dict/super | 元の`.dict cl a`に対し `T.norm.core=(Ty.dict cl a).norm.core` |

V_Sub/V_Normal/V_Refine は逆転で取り除き、元規則の代わりに返さない。constは既存inv_constの芯の等号、listはinv_list_coreの要素導出・Annotation・Listの芯・要素LeQ、conは既存inv_conのdataの芯とTypeArgsLe、checked/checkedRequest/checkedAtは既存のHolds（芯のscoped/opaqueの選言）と範囲の被覆を引用する。atErrorは同じ宣言のerrorTypeの芯を返す。これら8枝の最外の篩は同じ値のHasTypeVQ.factsで読む。ret_value/ite_branchは既存の署名を引用する。

## F02：反変の入力、同じ実引数による結果と効果の具体化

```lean
theorem TelClosure.apply {P B Ψ Q C Γ Φ t u ws a e}
    (hP : P.WellFormed) (hB : B.CoreAssumptions P) (hw : Ψ.WF)
    (hΓ : Ctx.WF 0 C.length Γ)
    (ht : Ty.Annotation P C Γ (.dependentFn t))
    (hu : Ty.Annotation P C Γ (.dependentFn u))
    (h : TelClosure P Γ Φ t u)
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws u a e) :
    ∃ b f, HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t b f ∧
      Ty.LeQ P Γ Φ b a ∧ Eff.Covers Γ Φ e f
```

内部の代表は TelBodyTy.narrow_input・TelLe.open_done・TelClosure.two_steps・TelClosure.from_function_norm。open_done/open_tail/open_twoは元文脈のWFを使って、最初の実値を二番目の型まで開く。Ctx.WFを他の公開前提から供給する証明を得られなかったため、F02の公開署名にもhΓを追加した。主な十言明を変更するものではない。閉Γでは自明、開Γでは呼出し側がCtx.Regularを持つ場合にそのwf欄から供給する。全開始入力への供給は一般の適用の担当が照合する。一般の全列の証明はL40.11でこの署名を使う。

## F03：canonical forms と全開始入力

閉Γのscalarは `HasTypeVQ P B Ψ Q C [] Φ v T` と `T.norm.core=.base tag` から `∃ c, v=.const c ∧ ConstOK B c ∧ c.type.norm.core=.base tag` を返す。Booleanは `∃ b, v=.const (.boolean b)`。Listは同じ入力のlist芯から `∃ vs, v=.list vs` と既存inv_listの要素導出を返す。dataはcon/atErrorを分ける。関数はF01の八構文の選言を返す。Map/Set/Bytes/Dict/保持値/外部/対象は、対応する直接規則の前提を保持する。

計算は `HasTypeCQ P B Ψ Q C Γ Φ R m T E L` を入力に、末尾の直接規則の選言を返す。mに現れない変数を存在量化し、直接前提の連言、元結果aからの `Ty.LeQ P Γ Φ a T`、元効果eからの `Eff.Covers Γ Φ E e` を返す。appの二規則はF02で共通の依存列へ統一する。R/Lと、matchのobs・sort・HasTypeArmsQ・Exhaustiveは保持する。

セルの入口は既存のStoreOkの全引数と固定σを保つ。Ψ l=some(ref a)ならval vとHasTypeV v a.norm/Adequate、lazyならthunkのClosureTy又はdoneのHasTypeV/Adequate、contならcontのContTy/EndsWithHandle又はused、builderなら同じBuilderCellOkを返す。全76葉への行き先は l40/results.md の表を維持する。全状態の進行はL70である。

## F04：同じ正常応答の事実

```lean
theorem normal_reply_facts {P B Ψ b sg ts es rs ws a e out v t}
    (hB : B.CoreAssumptions P)
    (hs : B.sig b = some sg) (hk : sg.kind = .pure)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (hd : B.delta b ts es rs ws = some out)
    (hv : out = .val v) (ht : v.toTerm? = some t) :
    ∀ r ∈ a.assume, Entails [] (r.open t)
```

normal_reply_facts_at は ν を追加し、結論を `Entails [] (predBind ν (r.open t))` へ写す。具体のδと算術の等号は実定義から証明する。

## F05：具体表と型付き鍵

Table/KeyObservation/carrier の完全な定義は本番 StandardKeyTyping に置く。Table の入力は有限宣言、data名/構成子名の重複なし、P.consとの等号、計算したdataSummariesの収束、B.satとsatBの全C/a/pでの等号である。値の鍵化の結論を欄にしない。

```lean
theorem key_table_sound {P B} (table : StandardKeyTyping.Table P B)
    (valid : P.VarianceValid) {a : Ty}
    (sat : B.sat [] a.norm TParam.keyC) :
    StandardKeyTyping.KeyObservation P B a

theorem key_values_sound {P B Ψ Q vs as}
    (table : StandardKeyTyping.Table P B) (valid : P.VarianceValid)
    (typed : HasTypeVsQ P B Ψ Q [] [] [] vs as)
    (sat : ∀ a ∈ as, B.sat [] a.norm TParam.keyC) :
    ∀ η : ObservationEnvModel,
      Observation.KeySlots ((Val.toTermSlots vs).map (fun t => t.bind (Term.observe η)))

theorem key_each_sound {P B Ψ Q vs a}
    (table : StandardKeyTyping.Table P B) (valid : P.VarianceValid)
    (typed : HasTypeEachQ P B Ψ Q [] [] [] vs a)
    (sat : B.sat [] a.norm TParam.keyC) :
    ∀ η : ObservationEnvModel,
      Observation.KeySlots ((Val.toTermSlots vs).map (fun t => t.bind (Term.observe η)))
```

mapのsizeは鍵側のKeySlotsを既存mapKeysへ渡す。map自体の鍵化は鍵と値のKeyPairsを要求する。

## F06：標準行と本体

本番 StandardContracts.Row は name/tparams/neffs/tel/body/implementation/relations。Relation の36構成子はS01〜S36へ順に対応する。任意Propの登録欄は持たない。row.definition は同じtelの名前/入力/結果/効果をDefへ戻し、definition_telがその等号を証明する。coreの行は `row.BodyTyped P B`、すなわち `∃ d, row.definition=some d ∧ d.WellTyped P B` を証明する。

pureの各行の完全な量化は、現行の応答の判断をそのまま使う。

```lean
∀ Ψ b sg ts es rs ws a e,
  B.sig b = some sg → sg.kind = .pure →
  BuiltinArgs P B Ψ b sg ts es rs ws a e →
  ∃ out, B.delta b ts es rs ws = some out ∧
    (∀ n, out ≠ .exit n) ∧ Outcome.Typed P B Ψ out a ∧ AdequateResult ws out
```

関係は同じ本体の有限なSteps又はRunsの正常返却から結論する。返却の存在を要求しない。List.mapFromはi+remaining.length=xs.length・acc.length=i・accのU型・同じxsのsuffixと順序を不変条件にする。filterFromはacc.length≤iとT型を使う。callbackを全域関数に置き換えない。Map/Setのmap/filterは実ソースのtoList→List.map/filter→fromListへ対応させる。Set.mapは縮約があるため長さの等式にしない。

## 安全な入口の内部の契約（J40-3）

公開名と字面はU02で決める。以下は通常の依存列として固定した内部契約である。`A{p}`は引数自身の篩、`NE[T]`は`nonemptyType T`の別名、`CI/CL/CX`は同じ元値と欄を保持するCheckedInteger/CheckedLength/CheckedIndexの型を表す。CIはminimum≤value≤maximum、CLはlength=List.length(values)かつminimum≤length≤maximum、CXは0≤index<List.length(values)を篩として持つ。これらは証拠を別の値引数にせず、受ける値の型の篩として要求する。

| 内部の入口 | 受ける値と篩・返す型 | Leanの依存列 | 型に加えてLeanの実行の補題で保つ関係 |
|---|---|---|---|
| safeHead | xs:NE[T] → T | safeHead T | 同じxsの先頭。NEの条件は0<length xs。有限列の補題のxs≠[]への橋は群C/E |
| safeGet | xs:List[T], i:Integer{0≤self ∧ self<length xs} → T | safeGet T | 同じxsのi番目。Natへの写しとgetElem?の等号は群C/E |
| safeTail | xs:NE[T] → List[T]{length self=length xs−1} | safeTail T | 同じxsの残りの列 |
| CheckedIndex.get | checked:CX[T] → T | checkedGet n T | 同じchecked.element。元Listとindexを保持 |
| 同長の別Listへの参照 | checked:CX[T], ys:List[U]{length self=length checked.values} → U | sameLengthGet n T U | ysのchecked.index番目。ysも引数の型で型付けし、保持elementと同一視しない |
| Range.minimum | checked:CI → Integer{self=checked.minimum} | checkedIntegerProjection n 0 | 同じminimum欄 |
| Range.maximum | checked:CI → Integer{self=checked.maximum} | checkedIntegerProjection n 1 | 同じmaximum欄 |
| Range.value | checked:CI → Integer{self=checked.value} | checkedIntegerProjection n 2 | 同じvalue欄。入力CIが上下限の関係を保持 |
| Range.lengthMinimum | checked:CL[T] → Integer{self=checked.minimum} | checkedLengthProjection n T 0 | 同じminimum欄 |
| Range.lengthMaximum | checked:CL[T] → Integer{self=checked.maximum} | checkedLengthProjection n T 1 | 同じmaximum欄 |
| Range.checkedLength | checked:CL[T] → Integer{self=checked.length ∧ self=length checked.values ∧ checked.minimum≤self≤checked.maximum} | checkedLength n T | 同じlength欄と元Listの長さ、両端の関係を結果にも明記 |
| Range.lengthValues | checked:CL[T] → List[T]{length self=checked.length ∧ checked.minimum≤length self≤checked.maximum} | checkedLengthValues n T | 同じ元List。列全体の同一性は型の整数述語に符号化しない |
| Range.indexValue | checked:CX[T] → Integer{self=checked.index ∧ 0≤self<length checked.values} | checkedIndexProjection n T | 同じindex欄 |
| Range.indexValues | checked:CX[T] → List[T]{length self=length checked.values} | checkedIndexValues n T | 同じ元List |
| NonEmptyList.fromList | xs:List[T] → Result[NE[T], EmptyListError] | nonemptyFromList n T | Okは同じxs、Error(EmptyListError.EmptyList)は正常値。成功する返却の存在は要求しない |
| NonEmptyList.toList | xs:NE[T] → List[T]{0<length self ∧ length self=length xs} | nonemptyToList T | 同じxs |
| NonEmptyList.head | xs:NE[T] → T | safeHead T | safeHeadと同じ先頭 |
| NonEmptyList.tail | xs:NE[T] → List[T]{length self=length xs−1} | safeTail T | safeTailと同じ残りの列 |
| NonEmptyList.map | xs:NE[T], f:(value:T)→U ! E → List[U]{0<length self ∧ length self=length xs} ! E | nonemptyMap T U E | 同じ型付きcallbackの正常な有限実行。順序・失敗・効果を保持 |

上表のLeanの完全な定義はsafe-contracts.leanにある。型パラメータT/UはTy、潜在効果EはEff、nは実際のdata名とrecord構成子名を保持するNamesである。各後続の値参照の番号とTy/Effの移動を定義に明示した。名前やFieldRefが同じ宣言を指すこと、Annotation・型付け・本体と実行の関係の証明は群D/Eとソース収集の担当が行う。今回通したのはTelとしての型検査であり、これらの意味の証明ではない。safeHead/get/同長の参照について既存StandardBodiesの有限列の補題が支える部分と、この依存列への接続を区別する。既存のOption・Result APIは保つ。

## F07：失敗の第一候補と二成分

```lean
theorem tracked_failure_sound
    (abstract : Benitoite.Interval.AbstractEnv)
    (concrete : Benitoite.Interval.ConcreteEnv)
    (input : Benitoite.Interval.EvalInput)
    (parameters : Benitoite.Interval.BudgetAnalysis.Parameters)
    (reason : Benitoite.Interval.Failure) (trace : Benitoite.Interval.EvalTrace)
    (hm : Benitoite.Interval.Models abstract concrete)
    (he : Benitoite.Interval.EvalPartial concrete input (.failed reason) trace)
    (ht : IntervalConnection.TrackedFailure reason trace) :
    (Benitoite.Interval.BudgetAnalysis.analyze abstract input parameters).mayFail = true
```

Success/SuccessAtは定義を変えない。内部のFailureCoveredは `∀ r, outcome=.failed r → r≠.unknown → approx.mayFail=true`。停止/未対応はbaseUnknownへ退く。旧NormalSoundness/WarningSoundnessを保持する。

正常/returnの局所規則はsignature-extra.leanに定義したjoinV/normalF/returnF/seqF/joinFを用い、同じ子のResultMemから親のResultMemを構成する。return/順次/枝/腕/Block14に一対一で対応させる。ValueRelからの二系だけで実解析のreturnedを供給したとはしない。第二候補はl20/n/h04-handoff.leanのBeforeError/BeforeErrorSteps/FirstFailureHandoffの完全定義を保って本番化する。実returnedと全表層の接続はL70である。

## 元の直接規則と全API署名

以下は本番からの完全な写しであり、F01/F03の量化と到達関係の規約とともに使う。APIは追加関係と通常結果を分けるが、どちらも宣言結果の型付けを照合する。S01〜S36の関係はdetail第3節の36行を変更しない。丸めの五モードの表と係数の演算はStandardScalarに置く。

直接規則の全命題は末尾の生成した枝を正とする。APIの元の完全な署名は以下のとおりである。

### Byte

追加の関係：S04：fromInteger、toInteger、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight。通常結果：toString。

```text
Byte.fromInteger(n: Integer) -> Option[Byte]  [@builtin("Byte.fromInteger")]
Byte.toInteger(b: Byte) -> Integer  [@builtin("Byte.toInteger")]
Byte.toString(b: Byte) -> String  [@builtin("Byte.toString")]
Byte.bitwiseAnd(a: Byte, b: Byte) -> Byte  [@builtin("Byte.bitwiseAnd")]
Byte.bitwiseOr(a: Byte, b: Byte) -> Byte  [@builtin("Byte.bitwiseOr")]
Byte.bitwiseExclusiveOr(a: Byte, b: Byte) -> Byte  [@builtin("Byte.bitwiseExclusiveOr")]
Byte.bitwiseNot(a: Byte) -> Byte  [@builtin("Byte.bitwiseNot")]
Byte.shiftLeft(a: Byte, n: Integer) -> Byte  [@builtin("Byte.shiftLeft")]
Byte.shiftRight(a: Byte, n: Integer) -> Byte  [@builtin("Byte.shiftRight")]
```

### Character

追加の関係：S05：toInteger、fromInteger。通常結果：toString、isASCIIDigit、isASCIIWhitespace、isAlphabetic、isNumeric、isWhitespace、isUppercase、isLowercase、toUppercase、toLowercase。

```text
Character.toInteger(c: Character) -> Integer  [@builtin("Character.toInteger")]
Character.fromInteger(n: Integer) -> Option[Character]  [@builtin("Character.fromInteger")]
Character.toString(c: Character) -> String  [@builtin("Character.toString")]
Character.isASCIIDigit(c: Character) -> Boolean  [@builtin("Character.isASCIIDigit")]
Character.isASCIIWhitespace(c: Character) -> Boolean  [@builtin("Character.isASCIIWhitespace")]
Character.isAlphabetic(c: Character) -> Boolean  [@builtin("Character.isAlphabetic")]
Character.isNumeric(c: Character) -> Boolean  [@builtin("Character.isNumeric")]
Character.isWhitespace(c: Character) -> Boolean  [@builtin("Character.isWhitespace")]
Character.isUppercase(c: Character) -> Boolean  [@builtin("Character.isUppercase")]
Character.isLowercase(c: Character) -> Boolean  [@builtin("Character.isLowercase")]
Character.toUppercase(c: Character) -> String  [@builtin("Character.toUppercase")]
Character.toLowercase(c: Character) -> String  [@builtin("Character.toLowercase")]
```

### Float

追加の関係：S06：isNaN。通常結果：toString、parse、truncate、absolute、floor、ceiling、round、squareRoot。

```text
Float.toString(x: Float) -> String  [@builtin("Float.toString")]
Float.parse(s: String) -> Option[Float]  [@builtin("Float.parse")]
Float.truncate(x: Float) -> Option[Integer]  [@builtin("Float.truncate")]
Float.isNaN(x: Float) -> Boolean  [@builtin("Float.isNaN")]
Float.absolute(x: Float) -> Float  [@builtin("Float.absolute")]
Float.floor(x: Float) -> Float  [@builtin("Float.floor")]
Float.ceiling(x: Float) -> Float  [@builtin("Float.ceiling")]
Float.round(x: Float) -> Float  [@builtin("Float.round")]
Float.squareRoot(x: Float) -> Float  [@builtin("Float.squareRoot")]
```

### Float32

追加の関係：S06：isNaN、isInfinite。通常結果：fromFloat、toFloat、parse、toString、truncate、absolute、floor、ceiling、round、squareRoot。

```text
Float32.fromFloat(n: Float) -> Option[Float32]  [@builtin("Float32.fromFloat")]
Float32.toFloat(n: Float32) -> Float  [@builtin("Float32.toFloat")]
Float32.parse(s: String) -> Option[Float32]  [@builtin("Float32.parse")]
Float32.toString(n: Float32) -> String  [@builtin("Float32.toString")]
Float32.truncate(n: Float32) -> Option[Integer]  [@builtin("Float32.truncate")]
Float32.isNaN(n: Float32) -> Boolean  [@builtin("Float32.isNaN")]
Float32.isInfinite(n: Float32) -> Boolean  [@builtin("Float32.isInfinite")]
Float32.absolute(n: Float32) -> Float32  [@builtin("Float32.absolute")]
Float32.floor(n: Float32) -> Float32  [@builtin("Float32.floor")]
Float32.ceiling(n: Float32) -> Float32  [@builtin("Float32.ceiling")]
Float32.round(n: Float32) -> Float32  [@builtin("Float32.round")]
Float32.squareRoot(n: Float32) -> Float32  [@builtin("Float32.squareRoot")]
```

### Decimal

追加の関係：S07：round、absolute、fromInteger、truncate、fromFloat。通常結果：toFloat、toString、parse。

```text
Decimal.round(x: Decimal, places: Integer, mode: RoundingMode) -> Decimal  [@builtin("Decimal.round")]
Decimal.absolute(x: Decimal) -> Decimal  [@builtin("Decimal.absolute")]
Decimal.fromInteger(n: Integer) -> Decimal  [@builtin("Decimal.fromInteger")]
Decimal.truncate(x: Decimal) -> Option[Integer]  [@builtin("Decimal.truncate")]
Decimal.toFloat(x: Decimal) -> Float  [@builtin("Decimal.toFloat")]
Decimal.fromFloat(x: Float) -> Option[Decimal]  [@builtin("Decimal.fromFloat")]
Decimal.toString(x: Decimal) -> String  [@builtin("Decimal.toString")]
Decimal.parse(s: String) -> Option[Decimal]  [@builtin("Decimal.parse")]
```

### String

追加の関係：S05/S08：byteLength、characterCount。通常結果：byteSlice、characterAt、characterSlice、isEmpty、contains、startsWith、endsWith、byteIndexOf、split、lines、join、trim、replace、repeat、characters、fromCharacters、toUppercase、toLowercase、toUTF8、fromUTF8、displayWidth、displayWidthCJK、displayWidthPadStart、displayWidthPadEnd、displayWidthPadStartCJK、displayWidthPadEndCJK。

```text
String.byteLength(s: String) -> Integer  [@builtin("String.byteLength")]
String.byteSlice(s: String, start: Integer, stop: Integer) -> Option[String]  [@builtin("String.byteSlice")]
String.characterCount(s: String) -> Integer  [@builtin("String.characterCount")]
String.characterAt(s: String, i: Integer) -> Option[Character]  [@builtin("String.characterAt")]
String.characterSlice(s: String, start: Integer, stop: Integer) -> Option[String]  [@builtin("String.characterSlice")]
String.isEmpty(s: String) -> Boolean  [@builtin("String.isEmpty")]
String.contains(s: String, part: String) -> Boolean  [@builtin("String.contains")]
String.startsWith(s: String, prefix: String) -> Boolean  [@builtin("String.startsWith")]
String.endsWith(s: String, suffix: String) -> Boolean  [@builtin("String.endsWith")]
String.byteIndexOf(s: String, part: String) -> Option[Integer]  [@builtin("String.byteIndexOf")]
String.split(s: String, separator: String) -> List[String]  [@builtin("String.split")]
String.lines(s: String) -> List[String]  [@builtin("String.lines")]
String.join(xs: List[String], separator: String) -> String  [@builtin("String.join")]
String.trim(s: String) -> String  [@builtin("String.trim")]
String.replace(s: String, old: String, new: String) -> String  [@builtin("String.replace")]
String.repeat(s: String, n: Integer) -> String  [@builtin("String.repeat")]
String.characters(s: String) -> List[Character]  [@builtin("String.characters")]
String.fromCharacters(cs: List[Character]) -> String  [@builtin("String.fromCharacters")]
String.toUppercase(s: String) -> String  [@builtin("String.toUppercase")]
String.toLowercase(s: String) -> String  [@builtin("String.toLowercase")]
String.toUTF8(s: String) -> Bytes  [@builtin("String.toUTF8")]
String.fromUTF8(b: Bytes) -> Option[String]  [@builtin("String.fromUTF8")]
String.displayWidth(s: String) -> Integer  [@builtin("String.displayWidth")]
String.displayWidthCJK(s: String) -> Integer  [@builtin("String.displayWidthCJK")]
String.displayWidthPadStart(s: String, width: Integer) -> String  [@builtin("String.displayWidthPadStart")]
String.displayWidthPadEnd(s: String, width: Integer) -> String  [@builtin("String.displayWidthPadEnd")]
String.displayWidthPadStartCJK(s: String, width: Integer) -> String  [@builtin("String.displayWidthPadStartCJK")]
String.displayWidthPadEndCJK(s: String, width: Integer) -> String  [@builtin("String.displayWidthPadEndCJK")]
```

### Bytes

追加の関係：S09：fromList、toList、length、concatenate。通常結果：empty、fromIntegers、fromHex、fromBinary、toHex、toBinary、get、slice、readUnsigned、readSigned、fromUnsigned、fromSigned。

```text
Bytes.empty() -> Bytes  [@builtin("Bytes.empty")]
Bytes.fromList(bs: List[Byte]) -> Bytes  [@builtin("Bytes.fromList")]
Bytes.fromIntegers(ns: List[Integer]) -> Option[Bytes]  [@builtin("Bytes.fromIntegers")]
Bytes.fromHex(s: String) -> Option[Bytes]  [@builtin("Bytes.fromHex")]
Bytes.fromBinary(s: String) -> Option[Bytes]  [@builtin("Bytes.fromBinary")]
Bytes.toList(b: Bytes) -> List[Byte]  [@builtin("Bytes.toList")]
Bytes.toHex(b: Bytes) -> String  [@builtin("Bytes.toHex")]
Bytes.toBinary(b: Bytes) -> String  [@builtin("Bytes.toBinary")]
Bytes.length(b: Bytes) -> Integer  [@builtin("Bytes.length")]
Bytes.get(b: Bytes, i: Integer) -> Option[Byte]  [@builtin("Bytes.get")]
Bytes.slice(b: Bytes, start: Integer, stop: Integer) -> Option[Bytes]  [@builtin("Bytes.slice")]
Bytes.concatenate(a: Bytes, b: Bytes) -> Bytes  [@builtin("Bytes.concatenate")]
Bytes.readUnsigned(b: Bytes, offset: Integer, count: Integer, order: ByteOrder) -> Option[Integer]  [@builtin("Bytes.readUnsigned")]
Bytes.readSigned(b: Bytes, offset: Integer, count: Integer, order: ByteOrder) -> Option[Integer]  [@builtin("Bytes.readSigned")]
Bytes.fromUnsigned(n: Integer, count: Integer, order: ByteOrder) -> Option[Bytes]  [@builtin("Bytes.fromUnsigned")]
Bytes.fromSigned(n: Integer, count: Integer, order: ByteOrder) -> Option[Bytes]  [@builtin("Bytes.fromSigned")]
```

### List

追加の関係：S10〜S16：length、isEmpty、head、tail、get、prepend、append、concatenate、reverse、map、filter。通常結果：take、drop、range、contains、sort、fold、forEach、any、all、find。

```text
List.length[T](xs: List[T]) -> Integer  [@builtin("List.length")]
List.isEmpty[T](xs: List[T]) -> Boolean  [@builtin("List.isEmpty")]
List.head[T](xs: List[T]) -> Option[T]  [@builtin("List.head")]
List.tail[T](xs: List[T]) -> Option[List[T]]  [@builtin("List.tail")]
List.get[T](xs: List[T], i: Integer) -> Option[T]  [@builtin("List.get")]
List.prepend[T](xs: List[T], x: T) -> List[T]  [@builtin("List.prepend")]
List.append[T](xs: List[T], x: T) -> List[T]  [@builtin("List.append")]
List.concatenate[T](xs: List[T], ys: List[T]) -> List[T]  [@builtin("List.concatenate")]
List.reverse[T](xs: List[T]) -> List[T]  [@builtin("List.reverse")]
List.take[T](xs: List[T], n: Integer) -> List[T]  [@builtin("List.take")]
List.drop[T](xs: List[T], n: Integer) -> List[T]  [@builtin("List.drop")]
List.range(start: Integer, stop: Integer) -> List[Integer]  [@builtin("List.range")]
List.contains[T: equality](xs: List[T], x: T) -> Boolean  [@builtin("List.contains")]
List.sort[T: ordered](xs: List[T]) -> List[T]  [@builtin("List.sort")]
List.map[T, U, effect E](xs: List[T], f: function(value: T) -> U uses E) -> List[U] uses E  [core]
List.filter[T, effect E](xs: List[T], p: function(value: T) -> Boolean uses E) -> List[T] uses E  [core]
List.fold[T, A, effect E](xs: List[T], initial: A, f: function(acc: A, value: T) -> A uses E) -> A uses E  [core]
List.forEach[T, effect E](xs: List[T], f: function(value: T) -> Unit uses E) -> Unit uses E  [core]
List.any[T, effect E](xs: List[T], p: function(value: T) -> Boolean uses E) -> Boolean uses E  [core]
List.all[T, effect E](xs: List[T], p: function(value: T) -> Boolean uses E) -> Boolean uses E  [core]
List.find[T, effect E](xs: List[T], p: function(value: T) -> Boolean uses E) -> Option[T] uses E  [core]
```

### Map

追加の関係：S17〜S20：empty、fromList、toList、get、set、remove、contains、size、keys、values、map、filter。通常結果：fold、forEach。

```text
Map.empty[K: key, V]() -> Map[K, V]  [@builtin("Map.empty")]
Map.fromList[K: key, V](pairs: List[Pair[K, V]]) -> Map[K, V]  [@builtin("Map.fromList")]
Map.toList[K: key, V](m: Map[K, V]) -> List[Pair[K, V]]  [@builtin("Map.toList")]
Map.get[K: key, V](m: Map[K, V], k: K) -> Option[V]  [@builtin("Map.get")]
Map.set[K: key, V](m: Map[K, V], k: K, value: V) -> Map[K, V]  [@builtin("Map.set")]
Map.remove[K: key, V](m: Map[K, V], k: K) -> Map[K, V]  [@builtin("Map.remove")]
Map.contains[K: key, V](m: Map[K, V], k: K) -> Boolean  [@builtin("Map.contains")]
Map.size[K: key, V](m: Map[K, V]) -> Integer  [@builtin("Map.size")]
Map.keys[K: key, V](m: Map[K, V]) -> List[K]  [@builtin("Map.keys")]
Map.values[K: key, V](m: Map[K, V]) -> List[V]  [@builtin("Map.values")]
Map.map[K: key, V, U, effect E](m: Map[K, V], f: function(key: K, value: V) -> U uses E) -> Map[K, U] uses E  [core]
Map.filter[K: key, V, effect E](m: Map[K, V], p: function(key: K, value: V) -> Boolean uses E) -> Map[K, V] uses E  [core]
Map.fold[K: key, V, A, effect E](m: Map[K, V], initial: A, f: function(acc: A, key: K, value: V) -> A uses E) -> A uses E  [core]
Map.forEach[K: key, V, effect E](m: Map[K, V], f: function(key: K, value: V) -> Unit uses E) -> Unit uses E  [core]
```

### Set

追加の関係：S21〜S23：empty、fromList、toList、add、remove、size、union、intersection、difference、map、filter。通常結果：contains、fold、forEach。

```text
Set.empty[T: key]() -> Set[T]  [@builtin("Set.empty")]
Set.fromList[T: key](xs: List[T]) -> Set[T]  [@builtin("Set.fromList")]
Set.toList[T: key](s: Set[T]) -> List[T]  [@builtin("Set.toList")]
Set.contains[T: key](s: Set[T], x: T) -> Boolean  [@builtin("Set.contains")]
Set.add[T: key](s: Set[T], x: T) -> Set[T]  [@builtin("Set.add")]
Set.remove[T: key](s: Set[T], x: T) -> Set[T]  [@builtin("Set.remove")]
Set.size[T: key](s: Set[T]) -> Integer  [@builtin("Set.size")]
Set.union[T: key](a: Set[T], b: Set[T]) -> Set[T]  [@builtin("Set.union")]
Set.intersection[T: key](a: Set[T], b: Set[T]) -> Set[T]  [@builtin("Set.intersection")]
Set.difference[T: key](a: Set[T], b: Set[T]) -> Set[T]  [@builtin("Set.difference")]
Set.map[T: key, U: key, effect E](s: Set[T], f: function(value: T) -> U uses E) -> Set[U] uses E  [core]
Set.filter[T: key, effect E](s: Set[T], p: function(value: T) -> Boolean uses E) -> Set[T] uses E  [core]
Set.fold[T: key, A, effect E](s: Set[T], initial: A, f: function(acc: A, value: T) -> A uses E) -> A uses E  [core]
Set.forEach[T: key, effect E](s: Set[T], f: function(value: T) -> Unit uses E) -> Unit uses E  [core]
```

### Range

追加の関係：S26〜S29：checkInteger、minimum、maximum、value、checkLength、lengthMinimum、lengthMaximum、checkedLength、lengthValues、checkIndex、indexValue、indexValues、get。通常結果：なし。

```text
Range.checkInteger(minimum: Integer, maximum: Integer, value: Integer) -> Result[CheckedInteger, RangeError]  [core]
Range.minimum(value: CheckedInteger) -> Integer  [core]
Range.maximum(value: CheckedInteger) -> Integer  [core]
Range.value(value: CheckedInteger) -> Integer  [core]
Range.checkLength[T](minimum: Integer, maximum: Integer, values: List[T]) -> Result[CheckedLength[T], LengthError]  [core]
Range.lengthMinimum[T](value: CheckedLength[T]) -> Integer  [core]
Range.lengthMaximum[T](value: CheckedLength[T]) -> Integer  [core]
Range.checkedLength[T](value: CheckedLength[T]) -> Integer  [core]
Range.lengthValues[T](value: CheckedLength[T]) -> List[T]  [core]
Range.checkIndex[T](index: Integer, values: List[T]) -> Result[CheckedIndex[T], IndexError]  [core]
Range.indexValue[T](value: CheckedIndex[T]) -> Integer  [core]
Range.indexValues[T](value: CheckedIndex[T]) -> List[T]  [core]
Range.get[T](value: CheckedIndex[T]) -> T  [core]
```

### NonEmptyList

追加の関係：S30：fromList、toList、head、tail、map。通常結果：なし。

```text
NonEmptyList.fromList[T](values: List[T]) -> Result[NonEmptyList[T], EmptyListError]  [core]
NonEmptyList.toList[T](value: NonEmptyList[T]) -> List[T]  [core]
NonEmptyList.head[T](value: NonEmptyList[T]) -> T  [core]
NonEmptyList.tail[T](value: NonEmptyList[T]) -> List[T]  [core]
NonEmptyList.map[T, U, effect E](value: NonEmptyList[T], f: function(value: T) -> U uses E) -> NonEmptyList[U] uses E  [core]
```

### Integer

追加の関係：S34〜S36：floorDivide、floorModulo、absolute、minimum、maximum、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight、shiftRightUnsigned。通常結果：toString、parse、toFloat。

```text
Integer.toString(n: Integer) -> String  [@builtin("Integer.toString")]
Integer.parse(s: String) -> Option[Integer]  [@builtin("Integer.parse")]
Integer.toFloat(n: Integer) -> Float  [@builtin("Integer.toFloat")]
Integer.floorDivide(a: Integer, b: Integer) -> Integer  [@builtin("Integer.floorDivide")]
Integer.floorModulo(a: Integer, b: Integer) -> Integer  [@builtin("Integer.floorModulo")]
Integer.absolute(n: Integer) -> Integer  [@builtin("Integer.absolute")]
Integer.minimum(a: Integer, b: Integer) -> Integer  [@builtin("Integer.minimum")]
Integer.maximum(a: Integer, b: Integer) -> Integer  [@builtin("Integer.maximum")]
Integer.bitwiseAnd(a: Integer, b: Integer) -> Integer  [@builtin("Integer.bitwiseAnd")]
Integer.bitwiseOr(a: Integer, b: Integer) -> Integer  [@builtin("Integer.bitwiseOr")]
Integer.bitwiseExclusiveOr(a: Integer, b: Integer) -> Integer  [@builtin("Integer.bitwiseExclusiveOr")]
Integer.bitwiseNot(a: Integer) -> Integer  [@builtin("Integer.bitwiseNot")]
Integer.shiftLeft(a: Integer, n: Integer) -> Integer  [@builtin("Integer.shiftLeft")]
Integer.shiftRight(a: Integer, n: Integer) -> Integer  [@builtin("Integer.shiftRight")]
Integer.shiftRightUnsigned(a: Integer, n: Integer) -> Integer  [@builtin("Integer.shiftRightUnsigned")]
```

### Integer8

追加の関係：S34〜S36：fromInteger、toInteger、absolute、minimum、maximum、floorDivide、floorModulo、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight、shiftRightUnsigned。通常結果：parse、toString、toFloat。

```text
Integer8.fromInteger(n: Integer) -> Option[Integer8]  [@builtin("Integer8.fromInteger")]
Integer8.toInteger(n: Integer8) -> Integer  [@builtin("Integer8.toInteger")]
Integer8.parse(s: String) -> Option[Integer8]  [@builtin("Integer8.parse")]
Integer8.toString(n: Integer8) -> String  [@builtin("Integer8.toString")]
Integer8.toFloat(n: Integer8) -> Float  [@builtin("Integer8.toFloat")]
Integer8.absolute(n: Integer8) -> Integer8  [@builtin("Integer8.absolute")]
Integer8.minimum(a: Integer8, b: Integer8) -> Integer8  [@builtin("Integer8.minimum")]
Integer8.maximum(a: Integer8, b: Integer8) -> Integer8  [@builtin("Integer8.maximum")]
Integer8.floorDivide(a: Integer8, b: Integer8) -> Integer8  [@builtin("Integer8.floorDivide")]
Integer8.floorModulo(a: Integer8, b: Integer8) -> Integer8  [@builtin("Integer8.floorModulo")]
Integer8.bitwiseAnd(a: Integer8, b: Integer8) -> Integer8  [@builtin("Integer8.bitwiseAnd")]
Integer8.bitwiseOr(a: Integer8, b: Integer8) -> Integer8  [@builtin("Integer8.bitwiseOr")]
Integer8.bitwiseExclusiveOr(a: Integer8, b: Integer8) -> Integer8  [@builtin("Integer8.bitwiseExclusiveOr")]
Integer8.bitwiseNot(a: Integer8) -> Integer8  [@builtin("Integer8.bitwiseNot")]
Integer8.shiftLeft(a: Integer8, n: Integer) -> Integer8  [@builtin("Integer8.shiftLeft")]
Integer8.shiftRight(a: Integer8, n: Integer) -> Integer8  [@builtin("Integer8.shiftRight")]
Integer8.shiftRightUnsigned(a: Integer8, n: Integer) -> Integer8  [@builtin("Integer8.shiftRightUnsigned")]
```

### Integer16

追加の関係：S34〜S36：fromInteger、toInteger、absolute、minimum、maximum、floorDivide、floorModulo、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight、shiftRightUnsigned。通常結果：parse、toString、toFloat。

```text
Integer16.fromInteger(n: Integer) -> Option[Integer16]  [@builtin("Integer16.fromInteger")]
Integer16.toInteger(n: Integer16) -> Integer  [@builtin("Integer16.toInteger")]
Integer16.parse(s: String) -> Option[Integer16]  [@builtin("Integer16.parse")]
Integer16.toString(n: Integer16) -> String  [@builtin("Integer16.toString")]
Integer16.toFloat(n: Integer16) -> Float  [@builtin("Integer16.toFloat")]
Integer16.absolute(n: Integer16) -> Integer16  [@builtin("Integer16.absolute")]
Integer16.minimum(a: Integer16, b: Integer16) -> Integer16  [@builtin("Integer16.minimum")]
Integer16.maximum(a: Integer16, b: Integer16) -> Integer16  [@builtin("Integer16.maximum")]
Integer16.floorDivide(a: Integer16, b: Integer16) -> Integer16  [@builtin("Integer16.floorDivide")]
Integer16.floorModulo(a: Integer16, b: Integer16) -> Integer16  [@builtin("Integer16.floorModulo")]
Integer16.bitwiseAnd(a: Integer16, b: Integer16) -> Integer16  [@builtin("Integer16.bitwiseAnd")]
Integer16.bitwiseOr(a: Integer16, b: Integer16) -> Integer16  [@builtin("Integer16.bitwiseOr")]
Integer16.bitwiseExclusiveOr(a: Integer16, b: Integer16) -> Integer16  [@builtin("Integer16.bitwiseExclusiveOr")]
Integer16.bitwiseNot(a: Integer16) -> Integer16  [@builtin("Integer16.bitwiseNot")]
Integer16.shiftLeft(a: Integer16, n: Integer) -> Integer16  [@builtin("Integer16.shiftLeft")]
Integer16.shiftRight(a: Integer16, n: Integer) -> Integer16  [@builtin("Integer16.shiftRight")]
Integer16.shiftRightUnsigned(a: Integer16, n: Integer) -> Integer16  [@builtin("Integer16.shiftRightUnsigned")]
```

### Integer32

追加の関係：S34〜S36：fromInteger、toInteger、absolute、minimum、maximum、floorDivide、floorModulo、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight、shiftRightUnsigned。通常結果：parse、toString、toFloat。

```text
Integer32.fromInteger(n: Integer) -> Option[Integer32]  [@builtin("Integer32.fromInteger")]
Integer32.toInteger(n: Integer32) -> Integer  [@builtin("Integer32.toInteger")]
Integer32.parse(s: String) -> Option[Integer32]  [@builtin("Integer32.parse")]
Integer32.toString(n: Integer32) -> String  [@builtin("Integer32.toString")]
Integer32.toFloat(n: Integer32) -> Float  [@builtin("Integer32.toFloat")]
Integer32.absolute(n: Integer32) -> Integer32  [@builtin("Integer32.absolute")]
Integer32.minimum(a: Integer32, b: Integer32) -> Integer32  [@builtin("Integer32.minimum")]
Integer32.maximum(a: Integer32, b: Integer32) -> Integer32  [@builtin("Integer32.maximum")]
Integer32.floorDivide(a: Integer32, b: Integer32) -> Integer32  [@builtin("Integer32.floorDivide")]
Integer32.floorModulo(a: Integer32, b: Integer32) -> Integer32  [@builtin("Integer32.floorModulo")]
Integer32.bitwiseAnd(a: Integer32, b: Integer32) -> Integer32  [@builtin("Integer32.bitwiseAnd")]
Integer32.bitwiseOr(a: Integer32, b: Integer32) -> Integer32  [@builtin("Integer32.bitwiseOr")]
Integer32.bitwiseExclusiveOr(a: Integer32, b: Integer32) -> Integer32  [@builtin("Integer32.bitwiseExclusiveOr")]
Integer32.bitwiseNot(a: Integer32) -> Integer32  [@builtin("Integer32.bitwiseNot")]
Integer32.shiftLeft(a: Integer32, n: Integer) -> Integer32  [@builtin("Integer32.shiftLeft")]
Integer32.shiftRight(a: Integer32, n: Integer) -> Integer32  [@builtin("Integer32.shiftRight")]
Integer32.shiftRightUnsigned(a: Integer32, n: Integer) -> Integer32  [@builtin("Integer32.shiftRightUnsigned")]
```

### Integer64

追加の関係：S34〜S36：floorDivide、floorModulo、absolute、minimum、maximum、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight、shiftRightUnsigned。通常結果：toString、parse、toFloat。

```text
Integer64.toString(n: Integer64) -> String  [core]
Integer64.parse(s: String) -> Option[Integer64]  [core]
Integer64.toFloat(n: Integer64) -> Float  [core]
Integer64.floorDivide(a: Integer64, b: Integer64) -> Integer64  [core]
Integer64.floorModulo(a: Integer64, b: Integer64) -> Integer64  [core]
Integer64.absolute(n: Integer64) -> Integer64  [core]
Integer64.minimum(a: Integer64, b: Integer64) -> Integer64  [core]
Integer64.maximum(a: Integer64, b: Integer64) -> Integer64  [core]
Integer64.bitwiseAnd(a: Integer64, b: Integer64) -> Integer64  [core]
Integer64.bitwiseOr(a: Integer64, b: Integer64) -> Integer64  [core]
Integer64.bitwiseExclusiveOr(a: Integer64, b: Integer64) -> Integer64  [core]
Integer64.bitwiseNot(a: Integer64) -> Integer64  [core]
Integer64.shiftLeft(a: Integer64, n: Integer) -> Integer64  [core]
Integer64.shiftRight(a: Integer64, n: Integer) -> Integer64  [core]
Integer64.shiftRightUnsigned(a: Integer64, n: Integer) -> Integer64  [core]
```

### UnsignedInteger

追加の関係：S34〜S36：fromInteger、toInteger、toDecimal、fromDecimal、absolute、minimum、maximum、floorDivide、floorModulo、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight。通常結果：parse、toString、toFloat。

```text
UnsignedInteger.fromInteger(n: Integer) -> Option[UnsignedInteger]  [core]
UnsignedInteger.toInteger(n: UnsignedInteger) -> Option[Integer]  [core]
UnsignedInteger.parse(s: String) -> Option[UnsignedInteger]  [core]
UnsignedInteger.toString(n: UnsignedInteger) -> String  [core]
UnsignedInteger.toFloat(n: UnsignedInteger) -> Float  [core]
UnsignedInteger.toDecimal(n: UnsignedInteger) -> Decimal  [core]
UnsignedInteger.fromDecimal(x: Decimal) -> Option[UnsignedInteger]  [core]
UnsignedInteger.absolute(n: UnsignedInteger) -> UnsignedInteger  [core]
UnsignedInteger.minimum(a: UnsignedInteger, b: UnsignedInteger) -> UnsignedInteger  [core]
UnsignedInteger.maximum(a: UnsignedInteger, b: UnsignedInteger) -> UnsignedInteger  [core]
UnsignedInteger.floorDivide(a: UnsignedInteger, b: UnsignedInteger) -> UnsignedInteger  [core]
UnsignedInteger.floorModulo(a: UnsignedInteger, b: UnsignedInteger) -> UnsignedInteger  [core]
UnsignedInteger.bitwiseAnd(a: UnsignedInteger, b: UnsignedInteger) -> UnsignedInteger  [core]
UnsignedInteger.bitwiseOr(a: UnsignedInteger, b: UnsignedInteger) -> UnsignedInteger  [core]
UnsignedInteger.bitwiseExclusiveOr(a: UnsignedInteger, b: UnsignedInteger) -> UnsignedInteger  [core]
UnsignedInteger.bitwiseNot(a: UnsignedInteger) -> UnsignedInteger  [core]
UnsignedInteger.shiftLeft(a: UnsignedInteger, n: Integer) -> UnsignedInteger  [core]
UnsignedInteger.shiftRight(a: UnsignedInteger, n: Integer) -> UnsignedInteger  [core]
```

### UnsignedInteger8

追加の関係：S04/S34/S36：fromInteger、toInteger、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight。通常結果：toString。

```text
UnsignedInteger8.fromInteger(n: Integer) -> Option[UnsignedInteger8]  [core]
UnsignedInteger8.toInteger(b: UnsignedInteger8) -> Integer  [core]
UnsignedInteger8.toString(b: UnsignedInteger8) -> String  [core]
UnsignedInteger8.bitwiseAnd(a: UnsignedInteger8, b: UnsignedInteger8) -> UnsignedInteger8  [core]
UnsignedInteger8.bitwiseOr(a: UnsignedInteger8, b: UnsignedInteger8) -> UnsignedInteger8  [core]
UnsignedInteger8.bitwiseExclusiveOr(a: UnsignedInteger8, b: UnsignedInteger8) -> UnsignedInteger8  [core]
UnsignedInteger8.bitwiseNot(a: UnsignedInteger8) -> UnsignedInteger8  [core]
UnsignedInteger8.shiftLeft(a: UnsignedInteger8, n: Integer) -> UnsignedInteger8  [core]
UnsignedInteger8.shiftRight(a: UnsignedInteger8, n: Integer) -> UnsignedInteger8  [core]
```

### UnsignedInteger16

追加の関係：S34〜S36：fromInteger、toInteger、absolute、minimum、maximum、floorDivide、floorModulo、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight。通常結果：parse、toString、toFloat。

```text
UnsignedInteger16.fromInteger(n: Integer) -> Option[UnsignedInteger16]  [@builtin("UnsignedInteger16.fromInteger")]
UnsignedInteger16.toInteger(n: UnsignedInteger16) -> Integer  [@builtin("UnsignedInteger16.toInteger")]
UnsignedInteger16.parse(s: String) -> Option[UnsignedInteger16]  [@builtin("UnsignedInteger16.parse")]
UnsignedInteger16.toString(n: UnsignedInteger16) -> String  [@builtin("UnsignedInteger16.toString")]
UnsignedInteger16.toFloat(n: UnsignedInteger16) -> Float  [@builtin("UnsignedInteger16.toFloat")]
UnsignedInteger16.absolute(n: UnsignedInteger16) -> UnsignedInteger16  [@builtin("UnsignedInteger16.absolute")]
UnsignedInteger16.minimum(a: UnsignedInteger16, b: UnsignedInteger16) -> UnsignedInteger16  [@builtin("UnsignedInteger16.minimum")]
UnsignedInteger16.maximum(a: UnsignedInteger16, b: UnsignedInteger16) -> UnsignedInteger16  [@builtin("UnsignedInteger16.maximum")]
UnsignedInteger16.floorDivide(a: UnsignedInteger16, b: UnsignedInteger16) -> UnsignedInteger16  [@builtin("UnsignedInteger16.floorDivide")]
UnsignedInteger16.floorModulo(a: UnsignedInteger16, b: UnsignedInteger16) -> UnsignedInteger16  [@builtin("UnsignedInteger16.floorModulo")]
UnsignedInteger16.bitwiseAnd(a: UnsignedInteger16, b: UnsignedInteger16) -> UnsignedInteger16  [@builtin("UnsignedInteger16.bitwiseAnd")]
UnsignedInteger16.bitwiseOr(a: UnsignedInteger16, b: UnsignedInteger16) -> UnsignedInteger16  [@builtin("UnsignedInteger16.bitwiseOr")]
UnsignedInteger16.bitwiseExclusiveOr(a: UnsignedInteger16, b: UnsignedInteger16) -> UnsignedInteger16  [@builtin("UnsignedInteger16.bitwiseExclusiveOr")]
UnsignedInteger16.bitwiseNot(a: UnsignedInteger16) -> UnsignedInteger16  [@builtin("UnsignedInteger16.bitwiseNot")]
UnsignedInteger16.shiftLeft(a: UnsignedInteger16, n: Integer) -> UnsignedInteger16  [@builtin("UnsignedInteger16.shiftLeft")]
UnsignedInteger16.shiftRight(a: UnsignedInteger16, n: Integer) -> UnsignedInteger16  [@builtin("UnsignedInteger16.shiftRight")]
```

### UnsignedInteger32

追加の関係：S34〜S36：fromInteger、toInteger、absolute、minimum、maximum、floorDivide、floorModulo、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight。通常結果：parse、toString、toFloat。

```text
UnsignedInteger32.fromInteger(n: Integer) -> Option[UnsignedInteger32]  [@builtin("UnsignedInteger32.fromInteger")]
UnsignedInteger32.toInteger(n: UnsignedInteger32) -> Integer  [@builtin("UnsignedInteger32.toInteger")]
UnsignedInteger32.parse(s: String) -> Option[UnsignedInteger32]  [@builtin("UnsignedInteger32.parse")]
UnsignedInteger32.toString(n: UnsignedInteger32) -> String  [@builtin("UnsignedInteger32.toString")]
UnsignedInteger32.toFloat(n: UnsignedInteger32) -> Float  [@builtin("UnsignedInteger32.toFloat")]
UnsignedInteger32.absolute(n: UnsignedInteger32) -> UnsignedInteger32  [@builtin("UnsignedInteger32.absolute")]
UnsignedInteger32.minimum(a: UnsignedInteger32, b: UnsignedInteger32) -> UnsignedInteger32  [@builtin("UnsignedInteger32.minimum")]
UnsignedInteger32.maximum(a: UnsignedInteger32, b: UnsignedInteger32) -> UnsignedInteger32  [@builtin("UnsignedInteger32.maximum")]
UnsignedInteger32.floorDivide(a: UnsignedInteger32, b: UnsignedInteger32) -> UnsignedInteger32  [@builtin("UnsignedInteger32.floorDivide")]
UnsignedInteger32.floorModulo(a: UnsignedInteger32, b: UnsignedInteger32) -> UnsignedInteger32  [@builtin("UnsignedInteger32.floorModulo")]
UnsignedInteger32.bitwiseAnd(a: UnsignedInteger32, b: UnsignedInteger32) -> UnsignedInteger32  [@builtin("UnsignedInteger32.bitwiseAnd")]
UnsignedInteger32.bitwiseOr(a: UnsignedInteger32, b: UnsignedInteger32) -> UnsignedInteger32  [@builtin("UnsignedInteger32.bitwiseOr")]
UnsignedInteger32.bitwiseExclusiveOr(a: UnsignedInteger32, b: UnsignedInteger32) -> UnsignedInteger32  [@builtin("UnsignedInteger32.bitwiseExclusiveOr")]
UnsignedInteger32.bitwiseNot(a: UnsignedInteger32) -> UnsignedInteger32  [@builtin("UnsignedInteger32.bitwiseNot")]
UnsignedInteger32.shiftLeft(a: UnsignedInteger32, n: Integer) -> UnsignedInteger32  [@builtin("UnsignedInteger32.shiftLeft")]
UnsignedInteger32.shiftRight(a: UnsignedInteger32, n: Integer) -> UnsignedInteger32  [@builtin("UnsignedInteger32.shiftRight")]
```

### UnsignedInteger64

追加の関係：S34〜S36：fromInteger、toInteger、toDecimal、fromDecimal、absolute、minimum、maximum、floorDivide、floorModulo、bitwiseAnd、bitwiseOr、bitwiseExclusiveOr、bitwiseNot、shiftLeft、shiftRight。通常結果：parse、toString、toFloat。

```text
UnsignedInteger64.fromInteger(n: Integer) -> Option[UnsignedInteger64]  [@builtin("UnsignedInteger64.fromInteger")]
UnsignedInteger64.toInteger(n: UnsignedInteger64) -> Option[Integer]  [@builtin("UnsignedInteger64.toInteger")]
UnsignedInteger64.parse(s: String) -> Option[UnsignedInteger64]  [@builtin("UnsignedInteger64.parse")]
UnsignedInteger64.toString(n: UnsignedInteger64) -> String  [@builtin("UnsignedInteger64.toString")]
UnsignedInteger64.toFloat(n: UnsignedInteger64) -> Float  [@builtin("UnsignedInteger64.toFloat")]
UnsignedInteger64.toDecimal(n: UnsignedInteger64) -> Decimal  [@builtin("UnsignedInteger64.toDecimal")]
UnsignedInteger64.fromDecimal(x: Decimal) -> Option[UnsignedInteger64]  [@builtin("UnsignedInteger64.fromDecimal")]
UnsignedInteger64.absolute(n: UnsignedInteger64) -> UnsignedInteger64  [@builtin("UnsignedInteger64.absolute")]
UnsignedInteger64.minimum(a: UnsignedInteger64, b: UnsignedInteger64) -> UnsignedInteger64  [@builtin("UnsignedInteger64.minimum")]
UnsignedInteger64.maximum(a: UnsignedInteger64, b: UnsignedInteger64) -> UnsignedInteger64  [@builtin("UnsignedInteger64.maximum")]
UnsignedInteger64.floorDivide(a: UnsignedInteger64, b: UnsignedInteger64) -> UnsignedInteger64  [@builtin("UnsignedInteger64.floorDivide")]
UnsignedInteger64.floorModulo(a: UnsignedInteger64, b: UnsignedInteger64) -> UnsignedInteger64  [@builtin("UnsignedInteger64.floorModulo")]
UnsignedInteger64.bitwiseAnd(a: UnsignedInteger64, b: UnsignedInteger64) -> UnsignedInteger64  [@builtin("UnsignedInteger64.bitwiseAnd")]
UnsignedInteger64.bitwiseOr(a: UnsignedInteger64, b: UnsignedInteger64) -> UnsignedInteger64  [@builtin("UnsignedInteger64.bitwiseOr")]
UnsignedInteger64.bitwiseExclusiveOr(a: UnsignedInteger64, b: UnsignedInteger64) -> UnsignedInteger64  [@builtin("UnsignedInteger64.bitwiseExclusiveOr")]
UnsignedInteger64.bitwiseNot(a: UnsignedInteger64) -> UnsignedInteger64  [@builtin("UnsignedInteger64.bitwiseNot")]
UnsignedInteger64.shiftLeft(a: UnsignedInteger64, n: Integer) -> UnsignedInteger64  [@builtin("UnsignedInteger64.shiftLeft")]
UnsignedInteger64.shiftRight(a: UnsignedInteger64, n: Integer) -> UnsignedInteger64  [@builtin("UnsignedInteger64.shiftRight")]
```

### Float64

追加の関係：S06：isNaN。通常結果：toString、parse、truncate、absolute、floor、ceiling、round、squareRoot。

```text
Float64.toString(x: Float64) -> String  [core]
Float64.parse(s: String) -> Option[Float64]  [core]
Float64.truncate(x: Float64) -> Option[Integer]  [core]
Float64.isNaN(x: Float64) -> Boolean  [core]
Float64.absolute(x: Float64) -> Float64  [core]
Float64.floor(x: Float64) -> Float64  [core]
Float64.ceiling(x: Float64) -> Float64  [core]
Float64.round(x: Float64) -> Float64  [core]
Float64.squareRoot(x: Float64) -> Float64  [core]
```

## 補足の完全署名

セルはref_cell/lazy_cell/cont_cell/builder_cellの順である。二成分の関数の型はjoinV、normalF、returnF、seqF/joinFの順である。五つの定義はsignature-extra.leanに具体化した。局所規則の型検査は、その保存則を証明したことを意味しない。

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace Benitoite.Release.Refinement.Signatures

-- F03: 閉じた scalar と Boolean
#check (∀ {P B Ψ Q C Φ v T tag},
  HasTypeVQ P B Ψ Q C [] Φ v T → T.norm.core = .base tag →
  ∃ c, v = .const c ∧ ConstOK B c ∧ c.type.norm.core = .base tag : Prop)
#check (∀ {P B Ψ Q C Φ v T},
  HasTypeVQ P B Ψ Q C [] Φ v T → T.norm.core = .base .boolean →
  ∃ b, v = .const (.boolean b) : Prop)

-- F03: 同じストアと固定したσの四つの入口
#check (∀ {P B σ Ψ μ l a}, StoreOk P B σ Ψ μ → Ψ l = some (.ref a) →
  ∃ v, μ l = some (.val v) ∧ HasTypeV P B Ψ [] [] [] v a.norm ∧ v.Adequate σ : Prop)
#check (∀ {P B σ Ψ μ l a}, StoreOk P B σ Ψ μ → Ψ l = some (.lazy a) →
  (∃ q, μ l = some (.thunk q) ∧
    ClosureTy P B (hideBuilders Ψ) [] none q a Eff.empty ∧ q.Adequate σ) ∨
  (∃ v, μ l = some (.done v) ∧ HasTypeV P B Ψ [] [] [] v a ∧ v.Adequate σ) : Prop)
#check (∀ {P B σ Ψ μ l b t e r}, StoreOk P B σ Ψ μ → Ψ l = some (.cont b t e r) →
  (∃ k, μ l = some (.cont k) ∧ EndsWithHandle k ∧
    ∃ R' e', ContTy P B σ Ψ R' e' k b t e r) ∨ μ l = some .used : Prop)
#check (∀ {P B σ Ψ μ l kind}, StoreOk P B σ Ψ μ → Ψ l = some (.builder kind) →
  ∃ c, μ l = some (.builder c) ∧ BuilderCellOk P B Ψ kind c ∧
    Cell.Adequate σ (.builder c) : Prop)

-- F02: 文脈の形成を明示した全列の入口。
#check (∀ {P B Ψ Q C Γ Φ t u ws a e},
    P.WellFormed → B.CoreAssumptions P → Ψ.WF → Ctx.WF 0 C.length Γ →
    Ty.Annotation P C Γ (.dependentFn t) → Ty.Annotation P C Γ (.dependentFn u) →
    TelClosure P Γ Φ t u → HasTypeTelArgsQ P B Ψ Q C Γ Φ ws u a e →
    ∃ b f, HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t b f ∧
      Ty.LeQ P Γ Φ b a ∧ Eff.Covers Γ Φ e f : Prop)

-- F07: 五つの定義を固定し、その定義について局所規則の型を検査する。
def joinV : Shared.ValueApprox → Shared.ValueApprox → Shared.ValueApprox
  | .bottom, b => b
  | a, .bottom => a
  | .integer k a, .integer l b =>
      if same : l = k then .integer k (Benitoite.Interval.join a (same ▸ b)) else .unknown
  | .boolean f t, .boolean g u => .boolean (f || g) (t || u)
  | _, _ => .unknown

def normalF (a : Shared.ValueApprox) : Shared.FlowApprox := ⟨a,.bottom,false⟩
def returnF (f : Shared.FlowApprox) : Shared.FlowApprox :=
  ⟨.bottom,joinV f.normal f.returned,f.mayFail⟩
def joinF (f g : Shared.FlowApprox) : Shared.FlowApprox :=
  ⟨joinV f.normal g.normal,joinV f.returned g.returned,f.mayFail || g.mayFail⟩
def seqF (f g : Shared.FlowApprox) : Shared.FlowApprox :=
  ⟨g.normal,joinV f.returned g.returned,f.mayFail || g.mayFail⟩

#check (∀ a b v, a.Mem v → (joinV a b).Mem v : Prop)
#check (∀ a b v, b.Mem v → (joinV a b).Mem v : Prop)
#check (∀ a v, a.Mem v → (normalF a).NormalMem v : Prop)
#check (∀ f (outcome : Benitoite.Interval.EvalOutcome),
  f.ResultMem outcome.toApprox →
    (returnF f).ResultMem (Benitoite.Interval.returnOutcome outcome).toApprox : Prop)
#check (∀ f g (outcome : Benitoite.Interval.EvalOutcome),
  f.ResultMem outcome.toApprox → (joinF f g).ResultMem outcome.toApprox : Prop)
#check (∀ f g (outcome : Benitoite.Interval.EvalOutcome),
  g.ResultMem outcome.toApprox → (joinF f g).ResultMem outcome.toApprox : Prop)
#check (∀ f g (outcome : Benitoite.Interval.EvalOutcome),
  g.ResultMem outcome.toApprox → (seqF f g).ResultMem outcome.toApprox : Prop)
#check (∀ f g (outcome : Benitoite.Interval.EvalOutcome),
  outcome.Abrupt → f.ResultMem outcome.toApprox →
    (seqF f g).ResultMem outcome.toApprox : Prop)

end Benitoite.Release.Refinement.Signatures
```

## 内部の安全な契約の依存列

公開名・字面を定めない内部の型である。証明は群D/E。

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace Benitoite.Release.Refinement.InternalContracts

-- 公開名と字面は定めず、通常の依存列の注釈の形を固定する。
structure Names where
  checkedInteger : DataName
  checkedLength : DataName
  checkedIndex : DataName
  result : DataName
  emptyListError : DataName
  checkedIntegerCtor : ConName
  checkedLengthCtor : ConName
  checkedIndexCtor : ConName

def length (xs : Term) : Term := .measure .listLength xs
def getField (owner constructor : String) (position : Nat) (sort : «Sort») (v : Term) : Term :=
  .field ⟨owner,constructor,position,sort⟩ v

def integerField (n : Names) (i : Nat) := getField n.checkedInteger n.checkedIntegerCtor i .integer
def lengthField (n : Names) (i : Nat) := getField n.checkedLength n.checkedLengthCtor i .integer
def lengthValues (n : Names) := getField n.checkedLength n.checkedLengthCtor 3 .list
def indexValue (n : Names) := getField n.checkedIndex n.checkedIndexCtor 1 .integer
def indexValues (n : Names) := getField n.checkedIndex n.checkedIndexCtor 0 .list

def nonnegativeIndex (xs : Term) : Ty := .refined (.base .integer)
  (.and (.le (.integer 0) (.var 0)) (.lt (.var 0) (length xs)))
def nonempty (a : Ty) : Ty := nonemptyType a

def checkedIntegerType (n : Names) : Ty := .refined (.data n.checkedInteger [])
  (.and (.le (integerField n 0 (.var 0)) (integerField n 2 (.var 0)))
        (.le (integerField n 2 (.var 0)) (integerField n 1 (.var 0))))
def checkedLengthType (n : Names) (a : Ty) : Ty := .refined (.data n.checkedLength [a])
  (.and (.eq (lengthField n 2 (.var 0)) (length (lengthValues n (.var 0))))
    (.and (.le (lengthField n 0 (.var 0)) (lengthField n 2 (.var 0)))
          (.le (lengthField n 2 (.var 0)) (lengthField n 1 (.var 0)))))
def checkedIndexType (n : Names) (a : Ty) : Ty := .refined (.data n.checkedIndex [a])
  (.and (.le (.integer 0) (indexValue n (.var 0)))
        (.lt (indexValue n (.var 0)) (length (indexValues n (.var 0)))))

def safeHead (a : Ty) : Tel := .param "xs" (nonempty a) (.done (a.shiftV 1 0) Eff.empty)
def safeGet (a : Ty) : Tel := .param "xs" (.list a)
  (.param "i" (nonnegativeIndex (.var 1)) (.done (a.shiftV 2 0) Eff.empty))
def safeTail (a : Ty) : Tel := .param "xs" (nonempty a)
  (.done (.refined (.list (a.shiftV 1 0))
    (.eq (length (.var 0)) (.add (length (.var 1)) (.integer (-1))))) Eff.empty)
def checkedGet (n : Names) (a : Ty) : Tel :=
  .param "checked" (checkedIndexType n a) (.done (a.shiftV 1 0) Eff.empty)
def sameLengthGet (n : Names) (a b : Ty) : Tel :=
  .param "checked" (checkedIndexType n a)
    (.param "ys" (.refined (.list (b.shiftV 1 0))
      (.eq (length (.var 0)) (length (indexValues n (.var 1)))))
      (.done (b.shiftV 2 0) Eff.empty))

def checkedIntegerProjection (n : Names) (position : Nat) : Tel :=
  .param "checked" (checkedIntegerType n)
    (.done (.refined (.base .integer) (.eq (.var 0) (integerField n position (.var 1)))) Eff.empty)
def checkedLengthProjection (n : Names) (a : Ty) (position : Nat) : Tel :=
  .param "checked" (checkedLengthType n a)
    (.done (.refined (.base .integer) (.eq (.var 0) (lengthField n position (.var 1)))) Eff.empty)
def checkedLength (n : Names) (a : Ty) : Tel :=
  .param "checked" (checkedLengthType n a)
    (.done (.refined (.base .integer)
      (.and (.eq (.var 0) (lengthField n 2 (.var 1)))
        (.and (.eq (.var 0) (length (lengthValues n (.var 1))))
          (.and (.le (lengthField n 0 (.var 1)) (.var 0))
                (.le (.var 0) (lengthField n 1 (.var 1))))))) Eff.empty)
def checkedLengthValues (n : Names) (a : Ty) : Tel :=
  .param "checked" (checkedLengthType n a)
    (.done (.refined (.list (a.shiftV 1 0))
      (.and (.eq (length (.var 0)) (lengthField n 2 (.var 1)))
        (.and (.le (lengthField n 0 (.var 1)) (length (.var 0)))
              (.le (length (.var 0)) (lengthField n 1 (.var 1)))))) Eff.empty)
def checkedIndexProjection (n : Names) (a : Ty) : Tel :=
  .param "checked" (checkedIndexType n a)
    (.done (.refined (.base .integer)
      (.and (.eq (.var 0) (indexValue n (.var 1)))
        (.and (.le (.integer 0) (.var 0))
              (.lt (.var 0) (length (indexValues n (.var 1))))))) Eff.empty)
def checkedIndexValues (n : Names) (a : Ty) : Tel :=
  .param "checked" (checkedIndexType n a)
    (.done (.refined (.list (a.shiftV 1 0))
      (.eq (length (.var 0)) (length (indexValues n (.var 1))))) Eff.empty)

def nonemptyFromList (n : Names) (a : Ty) : Tel :=
  .param "xs" (.list a) (.done (.data n.result
    [nonempty (a.shiftV 1 0), .data n.emptyListError []]) Eff.empty)
def nonemptyToList (a : Ty) : Tel := .param "xs" (nonempty a)
  (.done (.refined (.list (a.shiftV 1 0))
    (.and (.lt (.integer 0) (length (.var 0))) (.eq (length (.var 0)) (length (.var 1))))) Eff.empty)
def nonemptyMap (a b : Ty) (e : Eff) : Tel :=
  .param "xs" (nonempty a)
    (.param "f" (.fn ["value"] [a.shiftV 1 0] (b.shiftV 1 0) (e.shiftV 1 0))
      (.done (.refined (.list (b.shiftV 2 0))
        (.and (.lt (.integer 0) (length (.var 0)))
              (.eq (length (.var 0)) (length (.var 2))))) (e.shiftV 2 0)))

-- 射影は実際に存在する欄だけに具体化する。
def all (n : Names) (a b : Ty) (e : Eff) : List (String × Tel) :=
  [("safeHead",safeHead a),("safeGet",safeGet a),("safeTail",safeTail a),
   ("CheckedIndex.get",checkedGet n a),("sameLengthGet",sameLengthGet n a b),
   ("Range.minimum",checkedIntegerProjection n 0),("Range.maximum",checkedIntegerProjection n 1),
   ("Range.value",checkedIntegerProjection n 2),
   ("Range.lengthMinimum",checkedLengthProjection n a 0),
   ("Range.lengthMaximum",checkedLengthProjection n a 1),("Range.checkedLength",checkedLength n a),
   ("Range.lengthValues",checkedLengthValues n a),("Range.indexValue",checkedIndexProjection n a),
   ("Range.indexValues",checkedIndexValues n a),
   ("NonEmptyList.fromList",nonemptyFromList n a),("NonEmptyList.toList",nonemptyToList a),
   ("NonEmptyList.head",safeHead a),("NonEmptyList.tail",safeTail a),
   ("NonEmptyList.map",nonemptyMap a b e)]

#check all
#check (fun n => all n (.tvar 0) (.tvar 1) Eff.empty)
end Benitoite.Release.Refinement.InternalContracts
```

### 最初の実行失敗の完全な定義

```lean
namespace Benitoite.Release.Refinement.IntervalConnection.H04

/-- 選んだ同じ実行経路について、まだ error に入っていないことを示す。 -/
def BeforeError : State → Prop
  | .error .. => False
  | _ => True

inductive BeforeErrorSteps (P : Program) (B : Builtins) (σ : PathEnv) :
    State → List Event → State → Prop where
  | nil {s} : BeforeError s → BeforeErrorSteps P B σ s [] s
  | cons {s t u event events} : BeforeError s → Step P B σ s event t →
      BeforeErrorSteps P B σ t events u →
      BeforeErrorSteps P B σ s (event.toList ++ events) u

/-- 最初の失敗の位置と、その位置で実際に拒否した pure の δ だけを観測する。 -/
def FirstFailureHandoff : Prop :=
  ∀ (P : Program) (B : Builtins) (σ : PathEnv) (q : Closure) (k : Cont) (μ : Store)
    (events : List Event) (errors : List ErrKind) (lastK : Cont) (lastStore : Store),
    Steps P B σ (.run q k μ) events (.error errors lastK lastStore) →
    ∃ (preEvents : List Event) (before : State) (event : Option Event)
      (firstErrors : List ErrKind) (firstK : Cont) (firstStore : Store) (suffix : List Event),
      BeforeErrorSteps P B σ (.run q k μ) preEvents before ∧
      Step P B σ before event (.error firstErrors firstK firstStore) ∧
      Steps P B σ (.error firstErrors firstK firstStore) suffix (.error errors lastK lastStore) ∧
      events = preEvents ++ event.toList ++ suffix ∧
      ∀ (focus : Closure) (atK : Cont) (atStore : Store) (b : PrimName)
        (ts : List Ty) (es : List Eff) (ranges : List RangeExpr) (ws : List Val) (sg : PrimSig),
        before = .run focus atK atStore → focus.view = .app (.prim b ts es ranges) ws →
        B.sig b = some sg → sg.kind = .pure →
        event = none ∧ ∃ r, firstErrors = [r] ∧ B.delta b (Ty.normTys ts) (es.map Eff.norm) ranges ws = some (.err r)

end Benitoite.Release.Refinement.IntervalConnection.H04

```

## 逆転の各枝の完全な命題

同じ構文の複数規則の出力は、該当する枝の出力の選言である。appはその後F02で共通の列へ移す。入力のvは当該構文に書き換えた形であり、一般のvとその等号を取る入口と同じ命題である。台本signatures.pyで本番の直接規則から再生成し、signature-check.leanで全命題の型を検査する。以下の型検査を証明の完成とは数えない。

```lean
import Benitoite
open Benitoite.Release.Refinement
namespace Benitoite.Release.Refinement.Signatures

-- V_Var の芯と事実の枝
#check (∀ {P B Ψ Q C Γ Φ v T i}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .var i) ,
    (∃ a b, Γ[i]? = some (some a) ∧ a.Ordinary ∧
      T.norm.core = b ∧ Ty.LeQ P Γ Φ a.norm.core b) ∧
    (∀ t, v.toTerm? = some t → ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open t)) : Prop)

-- V_Const の芯と事実の枝
#check (∀ {P B Ψ Q C Γ Φ v T c}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .const c) ,
    (ConstOK B c ∧ T.norm.core = c.type.norm.core) ∧
    (∀ t, v.toTerm? = some t → ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open t)) : Prop)

-- V_Lam の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {ns} {ps} {body},
    HasTypeVQ P B Ψ Q C Γ Φ (.lam ns ps body) T →
    ∃ r ε u,
      (NamesWF ns ps) ∧
      (Ty.WF 0 C.length Γ.length (.fn ns ps r ε)) ∧
      (Ty.Sorted Γ (.fn ns ps r ε)) ∧
      (HasTypeCQ P B (hideBuilders Ψ) Q C (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
          (some (r.shiftV ps.length 0)) body (r.shiftV ps.length 0) (Eff.shiftV ps.length 0 ε) []) ∧
      (Ty.Declared P C Γ (.fn ns ps r ε)) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (Ty.toTel ns ps r ε) u : Prop)

-- V_DependentLam の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {t} {body},
    HasTypeVQ P B Ψ Q C Γ Φ (.dependentLam t body) T →
    ∃ u,
      (Ty.Annotation P C Γ (.dependentFn t)) ∧
      (TelBodyTy P B (hideBuilders Ψ) Q C (hideConts Γ) Φ t body) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ t u : Prop)

-- V_Closure の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {runtime} {body},
    HasTypeVQ P B Ψ Q C Γ Φ (.closure runtime body) T →
    ∃ t u,
      (Ty.Annotation P C Γ (.dependentFn t)) ∧
      (Tel.RuntimeShape runtime t) ∧
      (DependentClosureTy P B Ψ body t) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ t u : Prop)

-- V_Fun の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {f} {ts} {es},
    HasTypeVQ P B Ψ Q C Γ Φ (.fnRef f ts es) T →
    ∃ d u,
      (P.defs f = some d) ∧
      (NamesWF d.names d.params) ∧
      (Admissible B C Γ.length (TypeCtx.constraints d.tparams) d.neffs
          (Qsig d.params d.ret d.eff) Q ts es d.eff) ∧
      (SignatureInstance P C Γ d.tel (TypeCtx.kinds d.tparams) ts es) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel d.tel ts es) u : Prop)

-- V_Prim の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {b} {ts} {es} {rs},
    HasTypeVQ P B Ψ Q C Γ Φ (.prim b ts es rs) T →
    ∃ s u,
      (B.sig b = some s) ∧
      (B.RangeAdmissible b s rs) ∧
      (NamesWF s.names s.params) ∧
      (PrimitiveAdmissible C Γ.length s Q ts es) ∧
      (SignatureInstance P C Γ (Tel.instR rs s.tel) (TypeCtx.kinds s.tparams) ts es) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel (Tel.instR rs s.tel) ts es) u : Prop)

-- V_Op の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {o} {ts},
    HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) T →
    ∃ od u,
      (P.ops o = some od) ∧
      (NamesWF od.names od.params) ∧
      (SatAll B C ts od.tparams) ∧
      (SignatureInstance P C Γ od.tel (List.replicate od.tparams.length .value) ts []) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel od.tel ts []) u : Prop)

-- V_ExternalRef の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {f} {ts},
    HasTypeVQ P B Ψ Q C Γ Φ (.externalRef f ts) T →
    ∃ d u,
      (P.externalFunction f = some d) ∧
      (d.WF P) ∧
      (ExternalCallAdmissible P B C d ts) ∧
      (SignatureInstance P C Γ d.parameters d.kinds ts []) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel d.parameters ts []) u : Prop)

-- V_ExternalHandle の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {ts} {h : ExternalHandle},
    HasTypeVQ P B Ψ Q C Γ Φ (.externalHandle h ts) T →
    ∃ (td : ExternalTypeDecl),
      (P.externalType h.typeId = some td) ∧
      (td.component = h.component) ∧
      (td.resource = h.resource) ∧
      (ts.length = td.arity) ∧
      (Ty.Annotation P C Γ (.external h.typeId ts)) ∧
      Ty.LeQ P Γ Φ (.external h.typeId ts) T : Prop)

-- V_PathBases の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {snapshot},
    HasTypeVQ P B Ψ Q C Γ Φ (.pathBases snapshot) T →
    (snapshot.Valid) ∧
      Ty.LeQ P Γ Φ .pathBases T : Prop)

-- V_ScopePattern の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {range},
    HasTypeVQ P B Ψ Q C Γ Φ (.scopePattern range) T →
    ∃ kind,
      (range.WF) ∧
      (range.Canonical) ∧
      (range.FitsKind kind) ∧
      Ty.LeQ P Γ Φ (.scopePattern kind) T : Prop)

-- V_Checked の芯と事実の枝
#check (∀ {P B Ψ Q C Γ Φ v T target}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .checked target) ,
    (∃ o k range ix, B.valKind o = some k ∧ B.valContent o = none ∧
      Scope.Domain.Range.MemK k range target ∧ T.Holds o k ix ∧
      ix.Covers (.fixed (.absolute range))) ∧
    (∀ t, v.toTerm? = some t → ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open t)) : Prop)

-- V_CheckedRequest の芯と事実の枝
#check (∀ {P B Ψ Q C Γ Φ v T target req}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .checkedRequest target req) ,
    (∃ o range A ix, B.valKind o = some .endpoint ∧ B.valContent o = some A ∧
      HasTypeV P B Ψ [] [] [] req A.norm ∧ groundVal req = true ∧
      req.reqTarget = some target ∧ Scope.Domain.Range.MemK .endpoint range target ∧
      T.Holds o .endpoint ix ∧ ix.Covers (.fixed (.absolute range))) ∧
    (∀ t, v.toTerm? = some t → ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open t)) : Prop)

-- V_CheckedAt の芯と事実の枝
#check (∀ {P B Ψ Q C Γ Φ v T r snapshot target req}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .checkedAt r snapshot target req) ,
    (∃ o k ix, CheckedWitness P B Ψ o k r snapshot target req ∧
      T.Holds o k ix ∧ ix.Covers (.fixed r)) ∧
    (∀ t, v.toTerm? = some t → ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open t)) : Prop)

-- V_AtErrorの芯と事実の枝
#check (∀ {P B Ψ Q C Γ Φ T} (detail : AtError),
  HasTypeVQ P B Ψ Q C Γ Φ (.atError detail) T →
  (∃ shape : ResultShape, shape.Declared P ∧ T.norm.core = shape.errorType.norm.core) ∧
  (∀ t, (Val.atError detail).toTerm? = some t → ∀ p ∈ T.assume,
    Entails (Γ.facts ++ Φ) (p.open t)) : Prop)

-- V_Map の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {ks} {vs},
    HasTypeVQ P B Ψ Q C Γ Φ (.mapV ks vs) T →
    ∃ a b k w,
      (HasTypeEachQ P B Ψ Q C Γ Φ ks a) ∧
      (HasTypeEachQ P B Ψ Q C Γ Φ vs b) ∧
      (ks.length = vs.length) ∧
      (B.sat (TypeCtx.constraints C) a.norm TParam.keyC) ∧
      (Ty.Annotation P C Γ a) ∧
      (Ty.Annotation P C Γ b) ∧
      T.norm.core = .map k w ∧ a.norm = k.norm ∧ Ty.LeQ P Γ Φ b w : Prop)

-- V_Set の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {vs},
    HasTypeVQ P B Ψ Q C Γ Φ (.setV vs) T →
    ∃ a w,
      (HasTypeEachQ P B Ψ Q C Γ Φ vs a) ∧
      (B.sat (TypeCtx.constraints C) a.norm TParam.keyC) ∧
      (Ty.Annotation P C Γ a) ∧
      T.norm.core = .set w ∧ a.norm = w.norm : Prop)

-- V_Dict の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {i} {ts} {vs},
    HasTypeVQ P B Ψ Q C Γ Φ (.dict i ts vs) T →
    ∃ id,
      (P.impls i = some id) ∧
      (SatAll B C ts id.tparams) ∧
      (TypeAnnotations P C Γ ts) ∧
      (TypeArgsKinded P C ts (List.replicate id.tparams.length .value)) ∧
      ((∀ a ∈ id.dictTys, a.WF 0 id.tparams.length 0)) ∧
      (id.target.WF 0 id.tparams.length 0) ∧
      (HasTypeVsQ P B Ψ Q C Γ Φ vs (id.dictTys.map (Ty.subst ts []))) ∧
      (Ty.Annotation P C Γ (.dict id.cls (id.target.subst ts []))) ∧
      T.norm.core = (Ty.dict id.cls (id.target.subst ts [])).norm.core : Prop)

-- V_Raise の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {t} {e},
    HasTypeVQ P B Ψ Q C Γ Φ (.raise t e) T →
    ∃ u,
      (Ty.Annotation P C Γ (.fn ["error"] [e] t (Eff.singleFail e))) ∧
      (Ordinary t) ∧
      (Ordinary e) ∧
      (t.HasKind P (TypeCtx.kinds C) .value) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (Ty.toTel ["error"] [e] t (Eff.singleFail e)) u : Prop)

-- V_LocRef の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {l},
    HasTypeVQ P B Ψ Q C Γ Φ (.loc l) T →
    ∃ a,
      (Ψ l = some (.ref a)) ∧
      (Ty.Declared P C Γ a) ∧
      Ty.LeQ P Γ Φ (.reference a) T : Prop)

-- V_LocLazy の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {l},
    HasTypeVQ P B Ψ Q C Γ Φ (.loc l) T →
    ∃ a,
      (Ψ l = some (.lazy a)) ∧
      (Ty.Declared P C Γ a) ∧
      Ty.LeQ P Γ Φ (.lazy a) T : Prop)

-- V_Bytes の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {bs},
    HasTypeVQ P B Ψ Q C Γ Φ (.bytesV bs) T →
    ((∀ b ∈ bs, b ≤ 255)) ∧
      T.norm.core = .bytes : Prop)

-- V_Con の芯と事実の枝
#check (∀ {P B Ψ Q C Γ Φ v T c ts vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .con c ts vs) ,
    (∃ cd, P.cons c = some cd ∧ ts.length = cd.ntys ∧
      TypeArgsKinded P C ts (List.replicate cd.ntys .value) ∧
      Ty.Annotation P C Γ (.data cd.data ts) ∧
      HasTypeVsQ P B Ψ Q C Γ Φ vs (cd.args.map (Ty.subst ts [])) ∧
      ∃ us, T.norm.core = .data cd.data us ∧
        TypeArgsLe P Γ Φ (P.varianceFor cd.data ts.length) (Ty.normTys ts) us) ∧
    (∀ t, v.toTerm? = some t → ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open t)) : Prop)

-- V_Super の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {v} {super},
    HasTypeVQ P B Ψ Q C Γ Φ (.super v super) T →
    ∃ cl a cd,
      (HasTypeVQ P B Ψ Q C Γ Φ v (.dict cl a)) ∧
      (P.classes cl = some cd) ∧
      (super ∈ cd.supers) ∧
      (Ty.Declared P C Γ a) ∧
      T.norm.core = (Ty.dict super a).norm.core : Prop)

-- V_List の芯と事実の枝
#check (∀ {P B Ψ Q C Γ Φ v T vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .list vs) ,
    (∃ a b, HasTypeEachQ P B Ψ Q C Γ Φ vs a ∧ Ty.Annotation P C Γ a ∧
      T.norm.core = .list b ∧ Ty.LeQ P Γ Φ a b) ∧
    (∀ t, v.toTerm? = some t → ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open t)) : Prop)

-- C_BuilderLet の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {kind} {body},
    HasTypeCQ P B Ψ Q C Γ Φ R (.builderLet kind body) T outEff Δ →
    ∃ a ε,
      (Ty.Annotation P C Γ kind.contents) ∧
      (TypeArgsKinded P C [kind.contents] [.value]) ∧
      (HasTypeCQ P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0))
          body (a.shiftV 1 0) (ε.shiftV 1 0)
          (LocalCtx.extend (some (renameKind (shiftIndex 1 0) kind)) Δ)) ∧
      (Ty.Declared P C Γ a) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_BuilderOp の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {kind} {op} {ref} {args},
    HasTypeCQ P B Ψ Q C Γ Φ R (.builderOp kind op ref args) T outEff Δ →
    (Ty.Annotation P C Γ kind.contents) ∧
      (TypeArgsKinded P C [kind.contents] [.value]) ∧
      (LocalRef.HasKind Ψ Δ ref kind) ∧
      (HasTypeVsQ P B Ψ Q C Γ Φ args (op.parameters kind)) ∧
      Ty.LeQ P Γ Φ (op.resultType kind) T ∧ Eff.Covers Γ Φ outEff Eff.empty : Prop)

-- C_Return の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v},
    HasTypeCQ P B Ψ Q C Γ Φ R (.ret v) T outEff Δ →
    ∃ a,
      (HasTypeVQ P B Ψ Q C Γ Φ v a) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff Eff.empty : Prop)

-- C_Let の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {m} {n},
    HasTypeCQ P B Ψ Q C Γ Φ R (.letIn m n) T outEff Δ →
    ∃ a b ε,
      (HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ) ∧
      (HasTypeCQ P B Ψ Q C (Γ.extend a) (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0))
          n (b.shiftV 1 0) (Eff.shiftV 1 0 ε) (localExtend 1 Δ)) ∧
      (Ty.Declared P C Γ b) ∧
      Ty.LeQ P Γ Φ b T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_App の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {f} {args},
    HasTypeCQ P B Ψ Q C Γ Φ R (.app f args) T outEff Δ →
    ∃ ns as b ε,
      (HasTypeVQ P B Ψ Q C Γ Φ f (.fn ns as b ε)) ∧
      (HasTypeVsQ P B Ψ Q C Γ Φ args as) ∧
      Ty.LeQ P Γ Φ b T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_DependentApp の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {f} {args},
    HasTypeCQ P B Ψ Q C Γ Φ R (.app f args) T outEff Δ →
    ∃ t a e,
      (HasTypeVQ P B Ψ Q C Γ Φ f (.dependentFn t)) ∧
      (HasTypeTelArgsQ P B Ψ Q C Γ Φ args t a e) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff e : Prop)

-- C_If の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v} {m} {n},
    HasTypeCQ P B Ψ Q C Γ Φ R (.ite v m n) T outEff Δ →
    ∃ t a ε,
      (HasTypeVQ P B Ψ Q C Γ Φ v (.base .boolean)) ∧
      (v.toTerm? = some t) ∧
      (HasTypeCQ P B Ψ Q C Γ (boolCond t true :: Φ) R m a ε Δ) ∧
      (HasTypeCQ P B Ψ Q C Γ (boolCond t false :: Φ) R n a ε Δ) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_Match の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v} {arms},
    HasTypeCQ P B Ψ Q C Γ Φ R (.match v arms) T outEff Δ →
    ∃ obs a b ε,
      (HasTypeVQ P B Ψ Q C Γ Φ v a) ∧
      ((∀ t, obs = some t → v.toTerm? = some t ∧ ∃ s, t.HasSort Γ s)) ∧
      (HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε Δ) ∧
      (Exhaustive P a (unguardedPats arms)) ∧
      Ty.LeQ P Γ Φ b T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_Lazy の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {m},
    HasTypeCQ P B Ψ Q C Γ Φ R (.lazyC m) T outEff Δ →
    ∃ a,
      (HasTypeCQ P B (hideBuilders Ψ) Q C (hideConts Γ) Φ none m a Eff.empty []) ∧
      (Ty.Annotation P C Γ a) ∧
      Ty.LeQ P Γ Φ (.lazy a) T ∧ Eff.Covers Γ Φ outEff Eff.empty : Prop)

-- C_Escape の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v},
    HasTypeCQ P B Ψ Q C Γ Φ R (.escape v) T outEff Δ →
    ∃ r a ε,
      (R = (some r)) ∧
      (HasTypeVQ P B Ψ Q C Γ Φ v r) ∧
      (Ty.Annotation P C Γ a) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_Use の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v} {m},
    HasTypeCQ P B Ψ Q C Γ Φ R (.use v m) T outEff Δ →
    ∃ o a ε,
      (HasTypeVQ P B Ψ Q C Γ Φ v (.opaque o (.fixed .top))) ∧
      (B.isResource o = true) ∧
      (HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ) ∧
      (ε.test (.name stateEff (.fixed .top)) = true) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_Handle の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {m} {h},
    HasTypeCQ P B Ψ Q C Γ Φ R (.handle m h) T outEff Δ →
    ∃ t εm ε,
      (HasTypeCQ P B Ψ Q C Γ Φ R m t εm Δ) ∧
      (Eff.Sub εm (Eff.union ε (handled P B h))) ∧
      (HasTypeClausesQ P B Ψ Q C Γ Φ R εm h t ε Δ) ∧
      Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_Handle_Fail の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {m} {h},
    HasTypeCQ P B Ψ Q C Γ Φ R (.handle m h) T outEff Δ →
    ∃ t E eb rest ec,
      (HasTypeCQ P B Ψ Q C Γ Φ R m t eb Δ) ∧
      (Eff.Sub eb (Eff.union (Eff.singleFail E) rest)) ∧
      (NoFail Q rest) ∧
      (HasFailureClause P B Ψ Q C Γ Φ E R h t ec Δ) ∧
      Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff (Eff.union rest ec) : Prop)

-- C_Resume の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {i} {v},
    HasTypeCQ P B Ψ Q C Γ Φ R (.resume (.var i) v) T outEff Δ →
    ∃ b t ε,
      (Γ[i]? = some (some (.cont b t ε))) ∧
      (HasTypeVQ P B Ψ Q C Γ Φ v b) ∧
      (Ty.Declared P C Γ t) ∧
      Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_ResumeL の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {l} {v},
    HasTypeCQ P B Ψ Q C Γ Φ R (.resume (.loc l) v) T outEff Δ →
    ∃ b t ε,
      (Ψ l = some (.cont b t ε R)) ∧
      (HasTypeVQ P B Ψ Q C Γ Φ v b) ∧
      (Ty.Declared P C Γ t) ∧
      Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_ResumeNorm の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {i} {v},
    HasTypeCQ P B Ψ Q C Γ Φ R (.resume (.var i) v) T outEff Δ →
    ∃ b t ε,
      (Γ[i]? = some (some (.cont b t ε))) ∧
      (HasTypeVQ P B Ψ Q C Γ Φ v b.norm) ∧
      (Ty.Declared P C Γ t.norm) ∧
      Ty.LeQ P Γ Φ t.norm T ∧ Eff.Covers Γ Φ outEff (Eff.norm ε) : Prop)

-- C_ResumeLNorm の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {l} {v},
    HasTypeCQ P B Ψ Q C Γ Φ R (.resume (.loc l) v) T outEff Δ →
    ∃ R' b t ε,
      (Ψ l = some (.cont b t ε R')) ∧
      (R'.map Ty.norm = R.map Ty.norm) ∧
      (HasTypeVQ P B Ψ Q C Γ Φ v b.norm) ∧
      (Ty.Declared P C Γ t.norm) ∧
      Ty.LeQ P Γ Φ t.norm T ∧ Eff.Covers Γ Φ outEff (Eff.norm ε) : Prop)

-- C_Meth の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v} {m} {ss} {es} {ws},
    HasTypeCQ P B Ψ Q C Γ Φ R (.meth v m ss es ws) T outEff Δ →
    ∃ cl τ cd ms as a ε,
      (HasTypeVQ P B Ψ Q C Γ Φ v (.dict cl τ)) ∧
      (P.classes cl = some cd) ∧
      (cd.methods m = some ms) ∧
      (NamesWF ms.names ms.params) ∧
      (SatAll B C ss (TypeCtx.constraints ms.tparams)) ∧
      (SignatureInstance P C Γ ms.tel (TypeCtx.kinds ms.tparams ++ [cd.argumentKind]) (ss ++ [τ]) es) ∧
      (MethodRowsAdmissible C Γ.length Q ms es) ∧
      (Tel.arguments (instantiatedTel ms.tel (ss ++ [τ]) es) ws = some (as, a, ε)) ∧
      (HasTypeVsQ P B Ψ Q C Γ Φ ws as) ∧
      (Ty.Annotation P C Γ a) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_External の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {f} {ts} {vs},
    HasTypeCQ P B Ψ Q C Γ Φ R (.externalCall f ts vs) T outEff Δ →
    ∃ d a e,
      (P.externalFunction f = some d) ∧
      (d.WF P) ∧
      (ExternalCallAdmissible P B C d ts) ∧
      (HasTypeTelArgsQ P B Ψ Q C Γ Φ vs (Tel.bind (typeEnv ts) d.parameters) a e) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff e : Prop)

-- C_IssuePathBases の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {b : PrimName},
    HasTypeCQ P B Ψ Q C Γ Φ R (.issuePathBases b) T outEff Δ →
    ∃ (sg : PrimSig),
      (B.sig b = some sg) ∧
      (sg.kind = .pathBases) ∧
      (sg.opEff = some processEnvironmentEff) ∧
      (sg.params = []) ∧
      (sg.ret = .pathBases) ∧
      (sg.eff = Eff.single processEnvironmentEff) ∧
      Ty.LeQ P Γ Φ .pathBases T ∧ Eff.Covers Γ Φ outEff (Eff.single processEnvironmentEff) : Prop)

-- C_CheckAt の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {kind} {name} {shape} {bases} {pattern} {input} {index},
    HasTypeCQ P B Ψ Q C Γ Φ R (.checkAt kind name shape bases pattern input index) T outEff Δ →
    (AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) ∧
      Ty.LeQ P Γ Φ (.data shape.owner [.scoped name kind index, shape.errorType]) T ∧ Eff.Covers Γ Φ outEff Eff.empty : Prop)

end Benitoite.Release.Refinement.Signatures
```
