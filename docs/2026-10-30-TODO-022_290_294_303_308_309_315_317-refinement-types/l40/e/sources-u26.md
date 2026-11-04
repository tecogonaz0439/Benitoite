# 安全な内部19契約と実ソースの対応

2026-11-04。固定の19契約は[元の定義](../a/safe-contracts.lean)と同じ本文であり、StandardSafeContractsへの複写時はrootとの循環を避けるimportだけを替えた。公開名と字面はU02に残す。以下の行番号は固定リスト内の順序である。実ソースの必要部分・SHA-256と照合台本は[source-evidence-u26.json](source-evidence-u26.json)・[verify-u26.py](verify-u26.py)に保存する。

具体NamesはCheckedInteger/CheckedLength/CheckedIndexにそれぞれBenitoite.Rangeの同名束縛を用いる。record構成子も各recordと同じ束縛名である。ResultはBenitoite.Result.Result、EmptyListErrorはBenitoite.NonEmptyList.EmptyListErrorであり、構成子Ok/Errorはarity2、EmptyListはarity0である。同じ有限cons表からDataArityと欄の宣言を構成した。これはRustのBindingIdや整数tagとLeanの文字列名の機械的同一性を証明したものではない。R50の収集は未完である。

| record | 型パラメータ数 | 宣言順の欄と型 |
|---|---:|---|
| CheckedInteger | 0 | minimum:Integer、maximum:Integer、value:Integer |
| CheckedLength | 1 | minimum:Integer、maximum:Integer、length:Integer、values:List[T] |
| CheckedIndex | 1 | values:List[T]、index:Integer、element:T |

StandardSafeAnnotationsのdeclarationRowsは、各行のtparamsとneffs、固定Telそのものを保持する。declarations_annotationは、defsを任意に差し替えた同じcons表のprogramに対し、全19行のWF・Sorted・Declaredを証明する。01/02/03/04/09〜18はC1、05はC2、06〜08はC0、19はC2でneffs1かつE=row0である。型引数T/U内の関数・閉包の潜在効果を制限しない。19をE=emptyの例だけで済ませていない。

| 行 | 固定契約 | 本体・宣言の到達点 | 正常境界への依存 |
|---:|---|---|---|
| 01 | safeHead | Internal.safeHeadの同じ固定Tel・cons match→元head。BodyTypedと同じP.defs lookup、通常のfnRefによる型付け済み参照 | 不要。有限matchと静的規則だけを使う |
| 02 | safeGet | Internal.safeGetは既存%List.getFrontを1回呼ぶ。固定TelのBodyTyped、同じxs/iの有限列の選択と全BuiltinArgs応答 | 不要。pureδの型と有限列を直接示す。u32変換失敗/範囲外Stopは保持 |
| 03 | safeTail | Internal.safeTailは既存%List.slice(xs,1,0)を1回呼ぶ。固定長n−1のBodyTyped、全BuiltinArgs→精密応答と同じdrop/take | 不要。pureδと有限証明書で型付ける |
| 04 | CheckedIndex.get | Internal.CheckedIndex.getはCXの欄2をmatchで束縛して返す。element:Tという元の普通の欄型で固定Telを検査 | 不要。欄選択のみ。実Range.getのgetter呼出しwrapperとはcoreの字面が異なる |
| 05 | sameLengthGet | Internal.sameLengthGetはCXの欄1indexを1回束縛し、ys/indexでgetFrontを1回呼ぶ。固定TelのBodyTypedと、同じ添字でのysのU型要素 | 不要。元xsの保持要素をysの要素と同一視しない |
| 06 | Range.minimum | 全Annotation。actual getterのmatch腕からsingleton等号へ進むV_RefineのEntailsが未接続 | 不要だが静的接続で停止。下の反モデル |
| 07 | Range.maximum | 全Annotation。欄1の束縛と元receiver.field1の等号の静的接続が未証明 | 不要だが静的接続で停止 |
| 08 | Range.value | 全Annotation。欄2の束縛と元receiver.field2の等号の静的接続が未証明 | 不要だが静的接続で停止 |
| 09 | Range.lengthMinimum | 全Annotation。CL欄0のsingleton結果の静的接続が未証明 | 不要だが静的接続で停止 |
| 10 | Range.lengthMaximum | 全Annotation。CL欄1のsingleton結果の静的接続が未証明 | 不要だが静的接続で停止 |
| 11 | Range.checkedLength | 全Annotation。CL欄2とlength(values)、上下限を結果へ渡す静的接続が未証明 | 不要だが静的接続で停止 |
| 12 | Range.lengthValues | 全Annotation。CL欄3の元Listとreceiver.lengthを結ぶ静的接続が未証明 | 不要だが静的接続で停止 |
| 13 | Range.indexValue | 全Annotation。CX欄1のsingleton等号とboundsを結果へ渡す静的接続が未証明 | 不要だが静的接続で停止 |
| 14 | Range.indexValues | 全Annotation。CX欄0の元Listとreceiver.valuesの長さ等号の静的接続が未証明 | 不要だが静的接続で停止 |
| 15 | NonEmptyList.fromList | 別名化後の内部本体は空→同じEmptyListError.EmptyListのError、cons→元xs自体をNEへ狭めたOk。固定TelのBodyTyped | 不要。matchのpathFactsで同じ元xsの非空を得る |
| 16 | NonEmptyList.toList | 別名化後の内部identity本体。非空と同じ長さを持つ固定TelのBodyTyped | 不要。元List自体を返し、長さの反射等号を使う |
| 17 | NonEmptyList.head | 別名化後の内部cons match。01と同じ固定Telと本体のBodyTyped、同じP.defsへ別の内部名で登録 | 不要。01と同じ有限match |
| 18 | NonEmptyList.tail | 別名化後の内部slice本体。03と同じ固定Telと本体のBodyTyped、同じP.defsへ別の内部名で登録 | 不要。03と同じpureδと有限証明書 |
| 19 | NonEmptyList.map | 一般EのAnnotationまで。非空・同長を持つ強いBodyTypedとList.mapの正常関係の接続は境界の決定待ち | 境界の決定待ち。pure E、callback全域性・無失敗を追加しない |

9本のBodyTypedは二つの具体P/Bで検査した。StandardSafeBodiesのP/Bは7本とgetFrontを、StandardSafeSliceのP/Bは2本とsliceを保持する。どちらも同じ6構成子の宣言を用い、それぞれのP.defsに同じRow.definitionを登録してlookupとDef.WellTypedを読む。全19宣言・全328APIを含む一つのProgram.WellTyped、又は全モデルCoreAssumptionsの証明とは数えない。

実ソースのRangeの公開射影は引数名valueを持ち、recordの自動getterを呼ぶ。固定Telのchecked、内部の直接matchとこのwrapperのラベル・呼出し形を同一視しない。9本の精密getterを未証明の強いP.defs lookupで補ったり、意味的なgetterCorrectを入力欄に置いたりしていない。04のelement:Tは普通の欄型なので、06〜14のsingleton結果の問題を持たない。

現行NonEmptyListはfirst/restを持つnominal recordである。現行fromListの引数名はvaluesであり、Okはwrapper構築である。toList/head/tail/mapの引数名はvalueであり、toListはprepend、head/tailはgetter、mapはhead callback→tail List.map→wrapper再構築である。固定Telのxsと、NE[T]別名へ変えた今回の内部本体は、現行公開ソースの型・本体と一致しない。R40の変換とU02の公開入口の確定を残し、fnのラベルを部分型でrenameして一致させない。旧List.head/tail/getのOption API、ResultとRangeErrorの既存APIは変更していない。

getFrontの通常署名は型パラメータ1個・効果0個、xs/index、(List[T],Integer)→Tであり、List.getのxs/i、Option[T]とは別の項目である。sliceの通常署名は同じ型パラメータ数でxs/front/back、(List[T],Integer,Integer)→List[T]である。今回のsliceSignatureは同じ入力と同じδに対する内部の精密結果型を加えた契約であり、現在のRust schemaそのものが既に精密な型を持つとは記録しない。全BuiltinArgsからその精密結果を直接証明し、本体が同じB.sig/B.deltaを読む。Rustのheap表現と有限列の全交換はR50に残る。

getFrontの有限列の補題は、0≤i<len xsとu32変換可能な正常枝で同じxs[i]を選ぶ。変換可能性を固定safeGetの利用者前提へ足していない。範囲内の全数学的添字がu32に収まるとも結論しない。sliceは負値/u32域外とback>n又はfront>n−backをStopに残し、正常枝の同じdrop/takeの長さがn−front−backである。出力の要素型は元ListのEachから得るため、要素の実行や関数の潜在効果に条件を加えない。

## 欄等号の未証明と代案

StandardSafeFieldGapは、同じ具体PのCI minimum getterと同じパターン・Γ・pathFactsを構成する。Γは[Integer,CI]、実ΦはconstructorIs(var1,CI)であり、元CIの篩とInteger64の上下限もΓ.factsに含む。η0=7、η1=CI(0,0,0)は全仮定を満たすが、V_Refineで必要なvar0=field0(var1)は満たさない。元CI篩をΦにも加えた強い仮定に対しても同じEntailsを反証した。述語自身のWF・Sorted・Declaredと、固定結果型をshift/openした式との一致も検査する。

反証したのはこのV_RefineのためのEntailsだけである。実matchでこの観測ηへ到達する、実getterが7を返す、固定契約が偽、又は全HasTypeCQ導出が不可能とは結論しない。既存P_Con/P_List/pathFactsが生成しない開いた束縛の等号を、閉値向けfield_facts_by_typeで代用しない。

未証明の接続は、actual getter腕の戻り値を元receiverの同じFieldRefへ結ぶ導出である。代案は、既存規則の別の導出を調べること、又は構成子束縛の等号を生成する規則の変更案を設計者へ示すことである。後者は型規則とその保存・置換への影響を持ち、今回の許可範囲外なので実装していない。追加所要は不明であり、最初の一導出の調査を15〜25分で区切る案がある。実用上は06〜14の固定精密結果型をまだ通常getterから供給できない。普通のgetterの動作や今回の9本の内部BodyTypedを失敗扱いにはしない。

## 検査の作成時の関門

Leanの既定例は、同じP/Bのlookupと実型付けの適用、全引数の純粋応答、別型の同長参照、精密sliceの長さ、minimumの未生成等号の反モデルを守る。現実的な退行は、宣言の型引数数・構成子位置・後続の値番号のずれ、別Listとの要素の混同、Stop枝の欠落である。既存の閉値の長さの例だけではこの依存列・開いた本体の接続を検査できない。公開する注入フラグや新しい型規則は追加しない。ソースのハッシュ照合は凍結入力の保持を確認する作業記録であり、処理系の実行テストとは区別する。
