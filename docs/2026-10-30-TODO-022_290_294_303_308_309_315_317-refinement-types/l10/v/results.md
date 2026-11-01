# L10 群 V の実装結果

2026-11-01。L10.01〜L10.13の実装について、RV-L10.v の中1〜3・軽1〜3を修正し、指定された検証を完了した。修正後の再レビューと受け入れは取りまとめへ渡す。初回報告では欄の形成を未実装のまま L10.07・L10.08 を完了と記録していた。今回、本番の形成の補助と実際の呼出しを追加して訂正した。L10.14には進んでいない。

指定ブランチは `m014/l10.v`、B_WORKは `c668ff024b99287de702c5823c6280f8130a6aa5` である。gitによる照合・状態の変更・コミットは行っていない。開始時に読んだLeanソースの写しと現在のファイルのハッシュで差分を識別した。[source-state.json](source-state.json) に開始時と実装後のSHA-256を記録した。指示されたB_WORKをgitで再確認したという意味ではない。

## 単位ごとの完了の判定

| 単位 | 判定 | 閉じた内容と証拠 |
|---|---|---|
| L10.01 | 完了 | 下の提供表・DET-L全31行の対応で不足と送り先を判定。Byte/七幅のsortを維持し、boundaryの `all_integer_sorts`・`byte_integer8_predicate` で確認 |
| L10.02 | 完了 | `VarianceSyntax`、`Program.dataInfo`、`varianceFor`。arity/列長の不一致とnoneは不変。`embedProgram`の再構成と既定noneの補題。既存全Programの読者はビルド通過 |
| L10.03 | 完了 | Ty/Tel/Effと型列の構造検査、型変数の全子とtapp headの出現、`Program.VarianceValid`。非出現は不変。全欄のAnnotation/kindと、提供metadataの構造的な正負を検査。境界の三正例と三種類の拒否で確認 |
| L10.04 | 完了 | 同じPを渡すTy.LeQ/TelLe/TelClosure/TypeArgsLe。規則数は14+2+2+4=22。`Eff.Covers`・`Eff.Sub`はPなしのまま |
| L10.05 | 完了 | TypeArgsLeの長さ・反射・推移・norm・get・env、双方向のdataCoreの逆転を存在と引数関係へ変更 |
| L10.06 | 完了 | `Ty.VarianceOK.invariant`・`mono`、`variance_field_mono`。正負・不変、fnの引数反転、list/lazy/map値、dataの候補表、refinedを閉じた |
| L10.07 | 完了 | Telの正負の単調性、Eff/Failの不変、upでの像の移送。TypeFormation で、検証済みの総称の欄と型引数の Annotation・個数・Ordinary から具体化後の Annotation を導出。Declared・HasData（widen を含む）の型置換を実装 |
| L10.08 | 完了 | `inv_con`は元の V_Con の kind・data の Annotation・欄の型付けと TypeArgsLe を保持。`constructor_field_inputs` が両側の欄の形成を導出し、`con_field_by_type`・`field_facts_by_type` が使用。dataCore_source・data_observation・宣言照合の等号依存を解消 |
| L10.09 | 完了 | TypeArgsLeを含むrawBindとrawMapRangesの相互証明。既存のbind/context/値移動/型移動/範囲移動/型・値置換の読者が通過。被覆の意味を保った |
| L10.10 | 完了 | 値移動の14判断76場合。証明の全体を作り直さず、同じPと新しい宣言照合を追随 |
| L10.11 | 完了 | 型移動の同じ76場合。TypeShiftContextでHasDataの観測の対応も移送。TypeShiftTypingの主署名と証明本体は変更せず通過 |
| L10.12 | 完了 | 値置換の同じ76場合とsubst_under_none。SubstTypingの主署名と証明本体は変更せず通過 |
| L10.13 | 完了 | narrowingの同じ76場合と、InversionCore・ReferenceCalls・各handler等の既存読者を追随。既定ビルドを通過 |

場合の数は [axioms-summary.md](axioms-summary.md) と [case-matrix.tsv](case-matrix.tsv) にある。予定の22規則、14判断76場合、76×4=304枝はいずれも実際と一致した。Leanの環境から構成子名と数を取り出し、各相互証明全体の型検査を通した。304は新しく作った証明の件数ではない。宣言照合の `Term.HasData` は補助のwidenを加えて4場合となり、値・型の移送の追随を304とは別に行った。

## L10.01の提供表の不足判定

| 提供するもの | 現行ソースで確認した定義 | 不足と後の単位への反映 |
|---|---|---|
| 七幅の整数とByte | Const.type/ConstOK、V_Const/V_Bytes、Ty.sort?、Val.toTerm?。Integerは既存の表現、符号付き8/16/32・符号なし16/32/64は明示の端点、ByteはNatで255以下 | 新しいsortは不要。述語では八つを同じ.integerへ写す。算術のIntKindの区分、正常結果、変換の制限はL40。旧入力の表現可能性は.26〜.30、数値adapterは.54 |
| Decimal | ConstOKは係数±79228162514264337593543950335とscale≤28。Observation.decimalNormalとdecimalRepresentedがある | 正常結果と丸めの葉はL40。丸めを無視した実数の線形式へ拡張しない。定義の追加を群Vへ持ち込む不足はない |
| Character・Float64/32 | Char、UInt64/UInt32のビット列、Sort、Comparison.Allowed、ClosedEvaluationのIEEE分類・比較がある | 全ビットの丸めの実装は内側の証明の対象にしない。標準の葉とRust側の照合はL40/L60以降 |
| String/Bytes/List | stringBytesはutf8ByteSize、stringCharactersはtoList.length、bytesLength/listLengthの観測がある | 開いた非負性と標準の事実はL30/L40。群Xの非空List・値依存長の代表が必要。比較を狭める変更は不要 |
| Map/Set | mapSize/setSize、観測のmapKeys、ClosedKeysによる重複縮約の接続がある | 観測の鍵のコードと、言語の意味上の鍵の等値との一致はL30/L40。Map値だけを共変、鍵とSetは不変に保つ |
| data/record | FieldRef.Declared、Term.HasData、constructorIs、KindとAnnotationはあるが、変性の表・検証・欄の移送がなかった | 不足を本群.02〜.13で実装。dataCoreの等号依存を解消。型引数のAnnotationと欄の形成を区別した |
| Boolean・対象 | Boolean比較・constructorIs、SnapshotMem・対象kind・scope/opaqueの形がある | 同じσの所属と被覆の全接続はL50。群Vのために外部状態や新しい利用者の構文を追加する不足はない |
| 網羅性 | refinedの既存のInhabitsだけでは、falseになる値を除いたD27を満たさない | 群X（.14〜.20）へ、Month/空篩/非空List/値依存長・unknown・捕捉の代表と全移送を残す。本群では定義を変更しない |
| 宣言の予約名 | Def/ImplDecl/Program.WellTypedとProgram.WellFormedは群Wの担当 | 群W（.21〜.23）が定義し、WellTypedにVarianceValidを格納する。進行でも射影できる位置を保つ |
| metadataの収集 | ConDeclには辞書制約の欄がなく、原ソースの公開境界を表す概念もない | requirements/publicBoundaryに提供された型の構造的な正負は検査する。原ソースからの完全な収集はL70/R10b。none/空列を収集の完全性の証拠にしない |

入口の判定を読み取ってから実装を進めたが、本表をresultsへ保存する作業は実装後に行った。detailは変更していない。

### DET-L全31行の対応

「定義」の行は、その入口の制限があることを確認したという判定であり、後段のCLI・Rust・全表層の照合を完了した判定ではない。

| DET-L | 定義又は後段の担当 | 判定・不足 |
|---|---|---|
| 01 | Term/Predの有限構文、L30 | 量化子なしの論理を維持。全ソルバの証明書はL30 |
| 02 | Sort/Comparison.Allowed/Source、L40 | セル現内容・IO・関数実行を観測へ加えない |
| 03 | Ty.sort?/ConstOK/Shared.IntKind、L40 | 暗黙変換の制限と数学上の述語比較を分け、Byte/七幅比較を維持 |
| 04 | floatClass/ClosedEvaluation、L40 | 分類・比較を維持。一般算術の実数線形化を追加しない |
| 05 | decimalRepresented/ConstOK、L40 | 端点・scaleを確認。丸めの正常結果の葉はL40 |
| 06 | Ordered/Annotation、L20/W | 参照の順序を維持。CaptureOkの条件を強めない |
| 07 | Term.Source/Pred.Source | 型内へ一般の実行式を加えない |
| 08 | L20/L70/R10b | 再帰の契約検査と、停止性を保証しない境界の後段照合 |
| 09 | L30/L70/R10b | unknownを暗黙の実行時検査へ替えない |
| 10 | L20/L70/R20 | 有限な合流候補の推論の後段照合 |
| 11 | 本群のVarianceValid/TypeArgsLe、L40/L70/R10b | 構文検証と単調性を実装。実表と収集の一致は後段 |
| 12 | 本群のVarianceOK、L40 | Reference/Map鍵/Set/辞書/Fail/継続/tapp/外部型を両方向で検査 |
| 13 | NamesWF/TelLe.names | 名前・個数を保つ既存補題をP付きで追随 |
| 14 | RangeIx/対象kind、L50 | 種類付き範囲を維持。動的集合の型への埋込みを増やさない |
| 15 | Source/SnapshotMem、L50 | 文字列の長さだけから対象の所属を導かない |
| 16 | L30/L40/R10b | unknownの三つの誤用を後段で照合 |
| 17 | L30/L40/R20/294の改名単位 | stepsと係数表現外の区別は後段。群Vは変更しない |
| 18 | Ty/Predの構文、L30 | 利用者の一般量化を追加しない |
| 19 | norm等号/LeQ.convert | 一般の論理同値を型の構造等号へ加えない |
| 20 | L20/L40/R10b | 読出しクラスと委譲の後段照合 |
| 21 | L50/R50 | 旧RangeのResult.Errorを保つ照合 |
| 22 | L70/R10b | 比較連鎖・区間略記を追加しない表層の照合 |
| 23 | L70/R10b | checkの型の一意性と文脈からの確定の照合 |
| 24 | 群X/L70/R10b | 不可能腕でも名前・型構造・効果を検査 |
| 25 | L70/R50 | 消去の静的な証拠と観測の照合 |
| 26 | L40/R40 | 生成・縮小の範囲の後段照合 |
| 27 | WF/Ordered、L20/W/L70 | 局所の依存名を公開位置へ漏らさない |
| 28 | R10b/R50/V10 | 除外moduleの検査と構成の照合 |
| 29 | L40/R50/V10 | 旧純粋APIと動的APIを一括で狭めない照合 |
| 30 | L50/R50/V10 | IPv4射影の警告を静的な拒否へ替えない照合 |
| 31 | Term.Source/Pred.Source、L70/R10b | measureのソースの形と内部snapshotを区別。新しい制限は加えない |

## 閉じた定義・補題

新しい本番モジュールは `VarianceSyntax`・`VarianceValidation`・`VarianceFormation`・`VarianceTransport`・`ObservationType`・`TypeFormation` の六つである。既定importに全て追加した。

- 宣言: 三値のVariance/Polarity、有限の反転・合成、DataVarianceDecl、ParamOccurs、Programの既定noneとvarianceFor。
- 検証: Ty/Tel/EffのVarianceOK、Program.ParamOccursInFields、Program.VarianceValid。原ソースの収集の完全性をこの述語に含めない。
- 引数列: TypeArgsLe.length/refl/trans/norm/get/env、rawBind/rawMapRanges。四族の全22規則に同じPを渡す。
- 単調性: Ty/Tel/Effの不変の相互証明、Ty/Tel/型列の正負の相互証明、fn/toTelの反変、依存列のparamの推移、variance_field_mono。
- 形成: SortMap、Pred.Sorted.sameSelf、Sorted の正規化からの反映に加え、Ty.Annotation.subst_types_closed・Program.VarianceValid.field_annotation。NoTapp は総称の欄の kind から導出。WF・Sorted・Declared の型置換と、依存する値の文脈の延長を証明。
- 逆転と欄: Ty.LeQ.dataCore/dataCore_source/hasSort_source、HasTypeVQ.inv_con、con_field_by_type、field_facts_by_type。
- 観測: observationType/observationTypes、部分型から射影への移送、値置換・値移動の不変性、型移動との可換性、型置換後の再射影と DataObservationLe.bind_typesOnly、Term.HasData.typesOnly、DataObservationLeとTerm.HasData.widen、既存の宣言照合への接続。
- 旧入力: embedLeは任意の同じPで使用できる。embedProgram_dataInfo/varianceForで旧宣言の既定の不変を示した。

完全な型は [signatures.md](signatures.md) と [signatures-output.txt](signatures-output.txt) にある。主な10定理の前提・結論の照合は [main-contracts.md](main-contracts.md) にある。

## 補助の契約で決めたことと計画との差

1. 欄の不変の比較はnorm等号とした。unusedを加えず、非出現の型引数のmetadataも不変でなければ拒む。
2. 正負と両方向をPolarity.Rel/TelRel/ArgsRelにまとめ、型像の関係とupの補助を追加した。Programのvalidを単調性の公理にしない。
3. レビュー修正で単調性と形成を分けた。単調性には総称の欄の Sorted [] と両端の Ordinary を使い、推移の中間に形成を要求しない。形成は検証済みの総称の欄と型引数の Annotation・個数・Ordinary から証明する。con_field_by_type の利用者に欄ごとの Annotation を要求しない。
4. 観測の補助にはobservationTypeとDataObservationLeを使い、Term.HasDataにwidenを追加した。DataImages/DeclarationImagesの外形は保ち、出力のHasDataの導出が対応を保持する形とした。完全な部分型・欄の型付け・篩の事実と、宣言照合で読む観測の根拠を区別する。詳細と理由はsignaturesにある。
5. 検証・単調性・観測・形成の補題を六モジュールに配置した。LeはSyntaxを読み、VarianceValid/WellTypedをimportしない。既存のHasSort反映はVarianceTransportへ移した。予約語scopedの束縛名はLeanで `«scoped»` と綴った。
6. 群内では部分型の骨格と構造検証、定義と読者の追随を局所ビルドの依存に合わせて往復した。各単位の途中を取り込み済みと数えず、群の末で全読者と既定ビルドをそろえた。最初に完全署名を保存したが、入口の不足判定のresultsへの保存は実装後になった。

いずれも補助の契約と配置の判断である。新しい公理、主な定理の前提の追加、結論の弱化、利用者の書ける形の制限、精密な外部状態の追加はない。依存・ツールチェーンの更新もない。勧告は共通依頼文が引き継いだ2026-10-30の照合の範囲を維持し、今回再照合したとは記録しない。

## レビューの所見ごとの処置

[review-handling.md](review-handling.md) に、中1〜3・軽1〜3の処置、補助の契約の選択、境界で実際に供給する入力を記録した。中1は群 X へ移さず本番で閉じた。中2は `rv-v-t5.lean` の総称の Sorted と通常値の像を使う証明へ替えた。中3の三つの設計書を同じ変更で更新した。軽2の sort の反映を要する観測の準備は、VarianceValid が必要であることを群 X と L30/L40 へ引き継ぐ。

`RV-L10.v.md` と補助入力 t2〜t6 の6ファイルは [immutable-inputs.json](immutable-inputs.json) の開始時ハッシュと一致する。レビュー用の入力は元の署名で残し、現在の呼出しは boundary に移した。plan・detail・レビュー原本・処理系は変更していない。設計書の変更は今回の起動指示で承認された三章だけである。

## 検査と公理依存

再現の入口は根から `python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/v/check.py` である。git と work は実行しない。台本は次の検査を順に行う。全入力60ファイルの SHA-256 は [check-inputs.json](check-inputs.json) にある。

| 検査 | 内容 | 終了 | 外側の時間・証拠 |
|---|---|---:|---|
| 既定ビルド | formal で lake build、743ジョブ | 0 | 51.378秒、[build-result.json](build-result.json) |
| 境界 | lean -M 12288、55定数 | 0 | 0.81秒、[boundary-result.json](boundary-result.json) |
| 完全署名 | lean -M 12288、137宣言 | 0 | 0.682秒、[signatures-result.json](signatures-result.json) |
| 全差分の公理依存 | lean -M 12288、48モジュール5662定数＋8件＝5670回 | 0 | 4.924秒、[axioms-result.json](axioms-result.json) |
| 設計書の例 | 根で cargo test --test spec_examples、7件成功 | 0 | 8.688秒、[spec-examples-result.json](spec-examples-result.json) |

主な10定理の宣言は、初回開始時の写しと引数・前提・結論が空白を除いて一致した。[main-contracts-result.json](main-contracts-result.json) に宣言の識別を保存した。四族の22規則と14判断76場合も環境から数え、76×4＝304枝の既存の相互証明は全て通過した。304は新しい証明の件数ではない。

各 Lean プロセスのメモリ上限は `-M 12288` である。公理依存の和集合は propext・Quot.sound・Classical.choice のみで、sorryAx・独自公理・対象漏れは0。既定ビルドの証明の穴の診断も0である。ビルドには既存の非推奨 API と未使用の simp 引数の警告が残るが、TypeFormation の新規の警告はない。最大常駐量は非採取である。

01-spec の24個の text ブロックは修正前と一致した。今回変えた規則の写しは lean ブロックである。spec_examples は写しの更新に合わせて根で一度実行し、7件成功した。小さい出力の作業領域の絶対パスは `<repo>` に置き換えて保存する。公理依存など100,000 byteを超える生の記録は `<tmp>` に置き、大きさと SHA-256 を [large-records.md](large-records.md) に記録する。

境界は既存の変性の正負例に加え、実際の V_Con → V_Sub から欄の形成と型付けを得る `supplied_sourceField_and_inputs`・`field_widened`、中間の列に形成も Ordinary も要求しない `field_mono_trans`、widen の後の型置換を検査する。退行として捕まえるのは欄の形成の呼出し側への押し戻し、推移の中間への注釈の要求、観測で捨てた子の型を復元する前提の追加である。レビュー入力の既存の構成を使い、本番の形成・単調性・型付けを呼び出す。処理系のテストの追加・変更は0である。

初回開始時の写しとの Lean 差分は追加1962行・削除283行、新規6ファイルと既存40ファイルである。今回のレビュー修正は Lean 6ファイル（うち TypeFormation が新規）と設計書3ファイルである。[source-state.json](source-state.json) と [review-fix-state.json](review-fix-state.json) で区別する。初回の差分との比較の方法は同じであり、git の差分とは照合していない。

## 残りと送り先

| 担当・時期 | 受け渡すもの・残る作業 | 見込み |
|---|---|---|
| 群Vの独立レビュー・取りまとめ | 新六モジュール、形成と単調性の分離、型引数の Ordinary、観測の widen の型置換と、三章の写しを再レビュー | 不明 |
| 群Vの受け入れ・設計者/取りまとめ | 修正後の所見の確認、work、取り込みと次のB_WORKの固定 | 不明 |
| 群X・次の起動 | P付きLeQと存在を返すdataCoreを使う。ValueMeaningのdataの場合は元の欄型とTypeArgsLeを扱い、con_field_by_type は元の型引数の Ordinary を V_Con の TypeArgsKinded から導き、呼出し側は行き先の型引数の Annotation・Ordinary を渡し、欄の Annotation は本番の補題から得る。HasData.widen の引数は実の引数ではない。欄の sort を元へ反映するには VarianceValid が要る。ValueMeaning や主な定理へ形成の前提を追加しない | detailの群Xの枠。今回は着手しない |
| 群W・.21〜.23 | Program.WellTypedのvariance欄へVarianceValidを格納。metadataのAnnotation/scope/kind/arityをWellFormedへ接続 | detailの群Wの枠 |
| L30/L40・観測の準備 | Declared だけでは欄の sort を元へ反映できない。検証済みの表の VarianceValid を観測の準備の証明で用いる。rv-v-t4 の sort_reflect_aux が補助入力である | 不明 |
| L20/L40/L70・予定の各段 | 主定理とValueMeaning/全保存への全合成、利用側の標準dataの葉、各表の充足と旧入力の全埋め込み | 各段の既存の枠 |
| L70/R10b | 辞書制約と公開境界を原ソースから収集したこと、実際の変性の表との一致をLean外で照合 | 不明 |

今回指定された六所見の修正と検証に未完はない。修正後の独立レビュー・受け入れ・Rust/Lean の全比較を完了したとは扱わない。外側の作業時間は末尾の時刻の記録を参照する。

## 外側の時間

開始は2026-11-01 04:38:19 UTC（13:38:19 JST）、最終の記録の照合は05:22:52 UTC（14:22:52 JST）で、外側44分33秒である。入口の読取り・署名の確定・実装・局所検査・既定ビルド・公理依存・記録の作成を含む。能動時間と道具の待ちを分離していないため、能動時間の確定値にはしない。独立レビュー・設計者の受け入れ・取りまとめのworkの待ちは含まない。指定された26時間の停止条件には達していない。

最後に、ソースのハッシュと検証記録、76行の照合表、ファイルの大きさ、相対リンク、新規ファイル一覧、証明の穴の有無を点検し、全て通過した。

初回の44分33秒は、6.5〜13時間の見込みの約6〜11%である。ただし、この時間には中1の欄の形成の補助が含まれていなかった。レビューが数えた既存への差分457行の大半は P の機械的な追随であり、新規の中身877行とは作業の性質が違う。304枝も、多くがそのまま通った既存の相互証明の照合件数であり、304個の証明を新しく作ったという意味ではない。実装担当の開始時の写しとの行数には比較の方法による差がある。初回の実績から、ValueMeaning や全移送を新しく閉じる群 X・W の見込みを比例で縮めない。今回の修正の時間は初回とは別に記録する。

今回の再開は2026-11-01 05:40:41 UTC（14:40:41 JST）、最終照合は2026-11-01 06:06:33 UTCであり、外側25分52秒である。レビューの読取り・修正・用語の一次資料の確認・局所検査・既定ビルド・公理依存・spec_examples・記録と最終照合を含む。修正後の再レビュー・受け入れ・取りまとめの work は含まない。能動時間と待ちを分離していない。今回の上限6時間には達していない。初回の26時間の上限とは別に判定した。

## 作業末の work

取りまとめが実行した。基準は `c668ff024b99287de702c5823c6280f8130a6aa5`、コマンドは `scripts/check.sh --level work --base <基準>`、終了状態は 0、外側の時間は 92.34 秒である。実行の前に Refinement の生成物を消した。

## RV-L10.s2重1による追随

2026-11-01。value kindの型引数のOrdinaryをTypeArgsKindedが検査する規則へ追随した。constructor_field_inputs・con_field_by_type・field_facts_by_typeのsourceOrdの前提を取り除き、inv_conの元の型引数の検査から導く。境界のV_Conでも新しい欄を満たすことを示し、sourceOrdを別に仮定しない。今回の検査の記録はl10/s2/results.mdに集める。
