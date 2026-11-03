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
