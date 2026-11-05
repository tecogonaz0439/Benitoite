# L60 群 F1 の実装記録

基準 B_WORK: `d0f7b3051f74dfefb73a6ef6b3edd59ba734dfb1`。指定ブランチ `m014/l60.f1`。git の操作と scripts/check.sh の実行は行わない。共通依頼文と2026-10-30の勧告照合・組み込まない判断を継承する。J60-1=B・J60-2=F06・J60-3=(a)と群Aの台帳を正とする。

## 単位の時刻と判定

依頼文・detail・tables・plan（本体の作業木の最新の確認点を含む）・群A〜Eの記録と本番の該当モジュールの読解は、最初の時刻の取得（2026-11-05T15:16:13+09:00）より前に始め、15:21:00に終えた。開始時の既定ビルドは差分なしの状態で終了0（外側1分45秒。群Dのモジュールの作り直しを含む）。

| 単位 | 開始（JST） | 終了（JST） | 判定 |
|---|---|---|---|
| L60.23 | 2026-11-05T15:21:00+09:00 | 2026-11-05T15:33:17+09:00 | 完了。三署名の行・丸め方式の宣言・群Eの読者の追随・最初の16接続・共有の宣言。照合の台本（三署名とProcess.exit、台帳の差分）は15:37〜15:42 |
| L60.24 | 2026-11-05T15:33:17+09:00 | 2026-11-05T15:35:43+09:00 | 完了。数値の公開モジュールの全166行 |
| L60.25 | 2026-11-05T15:35:43+09:00 | 2026-11-05T15:37:07+09:00 | 完了。演算子の107行と構造の等号の2行 |
| 三単位の非空性（N） | 2026-11-05T15:37:07+09:00 | 2026-11-05T15:52:38+09:00 | 完了。全275行の前提を満たす入力 |
| 写し・監査・照合・記録 | 2026-11-05T15:42:01+09:00 | 2026-11-05T16:00:24+09:00 | 完了 |

時刻は各区切りで取得したコマンドの出力であり、results.md へは作業末にまとめて書いた（計画からのずれ6）。各区間は外側の時間で、能動時間とLeanの待ち（途中の既定ビルド四回、計約7分）を分離していない。群F1の外側の時間の全体は、L60.23の開始から照合の終了まで約39分（読解を含めると約55分）で、見込みの2時間00分〜3時間25分の下端を下回った。主な理由は、群Aが合成表の行・出典の表・lookupの対応を本番で閉じており、各行の接続が既存の任意のP/Bの応答への当てはめに限られたことである。

最初の同種16件の一件当たりの能動時間は、16件の接続と三署名・宣言の作業が同じ区間（12分17秒）にあり分離できないので未取得とし、旧見込みを保つ（plan「本番の実績を使う外挿と相談条件」）。

## 同じ有限P/Bの構成

`StandardModel.program externals` と `StandardModel.builtins P` は群Aの実定義を使い、次の二点だけを加えた。

| 変更 | 内容 | 理由 |
|---|---|---|
| 組込みの台帳の三行 | `Primitive.p374`（Lazy.force）・`p375`（Reference.new）・`p376`（Reference.update）と、署名 `refNewSig`・`refUpdateSig`・`forceSig`。出典の表は取得・設定の行と同じ `signatureBase`。二分探索木へ三つの葉を加え（[store_rows.py](store_rows.py)）、行ごとのlookupを足した | plan の取りまとめの判断（合成表に三つの署名とStoreShapeを加え、台帳の行を合成側へ移す）。三行はδ・IO応答を持たず、実行は `E_RefNew`・`E_RefUpdate`・`E_ForceDone`・`E_Force` が受け持つ |
| 丸め方式の宣言 | `StandardModel.roundingMode`（RoundingModeの五構成子、arity 0）を `declarations` の末尾に加えた | Decimal.round の署名の引数の型。宣言がないと、この行の型付きの入力が存在せず契約が空疎になる |

合成表の形（lookupの双方向の対応、18名の内部名、外部宣言の専用表）は変えていない。`builtins_lookup_iff`・`primitive_lookup`・`signatures_iff` の実署名は同じで、証明は三行を含む全376行の場合分けになった。

共有の宣言は次で供給する（合成表の名前空間に新しいlookupを作らない）。

| 定理 | 内容 |
|---|---|
| `StandardModel.option_declarations`（群A） | Optionの二構成子とarity 1、Optionのデータ名の構成子は二つに限る |
| `StandardModel.http_declarations` | `ScopeDeclarations.HasHttp (program externals)`。Result・ScopeError・Pair・Http.ClientRequest・Http.RequestCheckError の全構成子のlookupとarity。`HasHttp.file` で `HasFile` も得る |
| `StandardModel.rounding_declarations` | `StandardDecimalResponse.Declarations (program externals)`。Optionと丸め方式の五構成子、丸め方式のデータ名の構成子は五つに限る |

## L60.23 最初の16接続と三署名

| 完了条件 | 全場合・全入力の判定 |
|---|---|
| 行の契約の形 | `StandardModel.PureRow P b` は `Builtins.ResponseAssumptions.delta_typed` の欄を名前bへ制限した形（任意のΨ・署名・型/行/範囲の引数・値・結果・効果を量化）。種類の前提を除いた分だけ強い |
| 行から契約へ | `PureRow.of_row` は任意のPと任意の行について、行の出典の表のδが行の署名の全 `BuiltinArgs` で応答を返すなら契約を返す。`PureRow.of_response` は名前・署名・δの一致から既存の応答の補題へつなぐ |
| 最初の16件 | `first_sixteen` は任意のPで、`StandardOperatorResponse.entries.take 16`（`first_sixteen_entries` が並びを固定）の全要素について契約を示す。整数七型のdiv/mod14件とFloatのadd/subtract2件で、証拠は任意のP/Bの `StandardOperatorResponse.response`（`PureRow.operator`）。部分表の `table_response` は使わない |
| 三署名 | [store-signatures.json](store-signatures.json)：三行の署名をRustの登録（名前・state/pure・引数の個数）、標準ソースの型付きの宣言、群Eの記録したStoreShapeの各欄と照合し、全項目一致。合成表の行・出典・δ・IO応答の定義なしも照合した |
| 群Eの読者 | `Primitive.store_rows` は五行（取得・設定・作成・更新・明示遅延の評価）へ、`store_lookup` は取得・設定の種類へ、`reference_rows` は五種類へ広げた。`no_store_transitions`（三種類の行がない）は偽になるので、`store_transitions`（三種類の全lookupは三つの名前と署名）へ置き換えた。`store_shape` の実署名は変えていない。参照と明示遅延の全五行で型引数の種類は `[value]` |
| Process.exit | 同じ扱いに当たらないと判定し、加えていない。理由は下の「取りまとめに判断を求める点」の1 |

三署名の追加は型付けの規則・主な十言明・Core/TargetAgreementの欄を変えない。三行の種類の署名は既存のStoreShapeの形を満たし（`store_shape`）、操作の効果を持たない（`reference_rows`）。

## L60.24 数値の全pure行

`numeric_rows externals row` は、`Primitive.numeric row = true` の全166行（Byte・Character・Float・Float32・Decimal・Integer・Integer8/16/32・UnsignedInteger16/32/64の公開モジュールの組込みの行）について、合成プログラムで契約を示す。分類の関数 `Primitive.numeric` の行の集合が、名前の公開モジュールの基準と一致することを [rows.py](rows.py) が照合する。

| 族（出典の表） | 行数 | 既存の証拠 | 供給した副条件 |
|---|---:|---|---|
| Scalar | 13 | `StandardScalarResponse.response` | Optionの宣言 |
| ByteString | 1 | `StandardByteStringResponse.response` | なし（任意のP） |
| Character | 10 | `StandardCharacterResponse.response` | なし（任意のP） |
| NumericRemaining | 10 | `StandardNumericRemainingResponse.response` | Optionの宣言 |
| IntegerAPI | 67 | `StandardIntegerAPI.response` | 利用可能性（具体の引数でdecide） |
| IntegerText | 21 | `StandardIntegerTextResponse.response` | Optionの宣言 |
| Conversion | 12 | `StandardConversionResponse.response` | 利用可能性、Optionの宣言 |
| Decimal | 6 | `StandardDecimalResponse.response_of` | 丸め方式とOptionの宣言 |
| FloatMath | 12 | `StandardFloatMathResponse.response` | Optionの宣言 |
| MinMax | 14 | `StandardIntegerResponse.minMax_response` | なし（任意のP） |

表のδの読み替えは、整数・Decimalの表は同じδ（定義の等号）、名前の照合で振り分ける表（NumericRemaining・IntegerText・FloatMath）は振り分けの計算、名前の接頭辞で振り分ける表（Scalar）と全行を順に試す表（Character）は族ごとの補題（`scalar_delta`・`character_delta`）で示す。

- Decimal.fromFloat の正常値は、NumericRemaining の表の同じδ（同じbitsから作る）を読み、自由なparsedを入れない。
- 別名の本体（Def）は組込みの行に数えない。166行は全て組込みの行で、群Aの台帳の受け手 `L60.24〜.26` の244行のうち数値のモジュールの行に当たる（残る78行は.26）。
- 証拠のない公開名の意味は足していない。
- `StandardDecimalResponse` の六実名の応答は、群Aまでは固定のPに限っていた。同じ証明を、Optionの二構成子とarityを持ち丸め方式の構成子を既知の五方式に限る条件（`Declarations P`。五方式の各構成子の存在は要求しない）を満たす任意のPへ一般化した（`response_of`）。元の固定のPと合成プログラムは五方式を全て宣言する。既存の `response` の実署名は変えず、`program_declarations` を当てた系とした（計画からのずれ1）。

## L60.25 全107演算子と構造等号

`operator_rows P row` は、`Primitive.operator row = true` の全109行（%で始まる組込みの行から %Map.replaceValues・%eq・%ne を除いた107行と、%eq/%ne の2行）について、任意のPで契約を示す。

| 族 | 行数 | 既存の証拠 |
|---|---:|---|
| 演算子の表 | 34 | `StandardOperatorResponse.response`。最初の16件は `first_sixteen` を読み、数え直さない |
| 算術 | 25 | `StandardArithmeticResponse.response_math` |
| 順序 | 48 | `StandardOrderResponse.response_math`（関係の結論は使わない） |
| 構造等号 | 2 | `StandardStructuralEqualityResponse.response` |

- %eq/%ne は、全型の一つの署名（Equalityの制約を持つ一つの型パラメータ、`StandardEqualityResponse.fullSignature`）の一行ずつに統一してある。旧の型ごとのscalarの証拠は同じlookupへ対応させ、別の署名の行を作らない。
- 不適格な構造の比較は誤り `InternalComparison` を返す。処理系では内部の誤り（Stop::Internal）として扱うことの照合は、R50への申し送りのまま保つ。Leanの関係は変えていない。
- 部分表の `table_response` を使っていない（[verify.py](verify.py) が四つのモジュールの使用を照合する）。

## 非空性と四分類

`PureRow.Satisfiable P b` は、契約の前提（合成表のlookupとその署名の `BuiltinArgs`）を満たす入力があることである。`operator_inputs` は演算子の全109行、`numeric_inputs` は数値の全166行について、正常な定数の引数列（`sample`）で前提を満たす入力を示す。

| 署名の形 | 行数 | 補題 |
|---|---:|---|
| 基本型の一引数→基本型 | 75 | `unary_arguments` |
| 基本型の二引数→基本型 | 172 | `binary_arguments` |
| 基本型の一引数→Option | 25 | `option_arguments`（Optionのarity） |
| Decimal.round | 1 | `round_arguments`（丸め方式の構成子 `mode_typed`） |
| %eq/%ne | 2 | `equality_arguments`（型引数Integer） |

[conditions.json](conditions.json) の判定は、全275行が**実質**、空疎0・自明0・不成立0・保留0である。結論は既存の応答の補題が同じ入力で合成表のδの値を返すことであり、定数の証人ではない。前提は上の入力で満たされる。正常な入力でDecimal.roundと %eq の型付きの応答が得られることを適用例で示した。

この判定は行ごとの契約についてであり、`delta_typed` の欄全体（合成表の全pure行）の判定ではない。%Map.replaceValues・String・Bytes・List・Map・Set・Rangeの純粋な行と、範囲付きの純粋な6行は.26/.28の受け持ちである。

## 台帳の差分

[ledger-diff.json](ledger-diff.json)（[ledger_diff.py](ledger_diff.py)）。群Aの台帳は書き換えていない。

| 差分 | 件数 | 内容 |
|---|---:|---|
| 仮定→合成 | 3 | L494 Reference.new・L495 Reference.update・L496 Lazy.force。合成表の行 p375・p376・p374、証拠 `row_lookup`・`store_transitions`・`store_shape`・`reference_rows` |
| 仮定側の理由の訂正 | 1 | L518 Process.exit。仮定側に残し、理由を「専用の遷移」から、exitの種類がioResponseを読むことへ改めた |
| 合成行の接続 | 275 | 全行が群Aの台帳の合成行の `composition_lookup` と同じ行へ対応。L60.23が16、L60.24が166、L60.25が93 |

台帳の分類は合成486→489、仮定154→151。合成表の子キーは、群Aの504（本体130・組込みの署名373・資源名1）から507（本体130・組込みの署名376・資源名1）になる。丸め方式の構成子は宣言であり、子キーにも応答の行数にも数えない（`ledger-diff.json` の `composition_child_keys`）。Rust参照の分類は合成369→372、仮定154→151（Reference.new・update・Lazy.forceの三参照）。

## 足した宣言

新しいモジュールは四つで、既定 import（`formal/Benitoite.lean`）に加えた。

| モジュール | 宣言 |
|---|---|
| StandardModelPureRows | `PureRow`、`PureRow.of_row`、`PureRow.of_response`、`http_declarations`、`rounding_declarations`、`PureRow.operator`、`first_sixteen_entries`、`first_sixteen` |
| StandardModelNumericRows | `PureRow.scalar`・`byteString`・`character`・`numericRemaining`・`integerAPI`・`integerText`・`conversion`・`decimal`・`floatMath`・`minMax`、`Primitive.numeric`、`numeric_rows`（他に読者のあるprivateの補題5） |
| StandardModelOperatorRows | `PureRow.arithmetic`・`order`・`structural`、`Primitive.operator`、`operator_rows`（privateの補題1） |
| StandardModelPureInputs | `PureRow.Satisfiable`、`sample`、`sample_typed`、`unarySig`・`binarySig`・`optionSig`、`unary_arguments`・`binary_arguments`・`option_arguments`、`rounding_arity`、`mode_typed`、`round_arguments`、`equality_arguments`、`PureRow.Satisfiable.unary`・`binary`・`option`、`operator_inputs`、`numeric_inputs`（privateの補題4） |

既存のモジュールへ足した宣言は、`StandardModel.refNewSig`・`refUpdateSig`・`forceSig`、`Primitive.p374`〜`p376`（StandardModelSignatures）、行ごとのlookup三つ（StandardModelPrimitiveLookup、private）、`StandardModel.roundingMode`（StandardModelDeclarations）、`StandardDecimalResponse.Declarations`・`program_declarations`・`response_of`（StandardDecimalResponse）、`StandardModel.store_transitions`（ResourceReleaseLeaves）である。取り除いた宣言は `StandardModel.no_store_transitions` だけである。

公開した43名は、名前付きの読者38、既定ビルドの適用例7を持つ（[readers.json](readers.json)。重なりを含む）。読者のない名前は0。

## 検査

| 検査 | コマンド | 終了 | 外側の時間 |
|---|---|---|---|
| 既定ビルド（作業末） | `formal/` で lockf の下に `lake build`（[default-build.json](default-build.json)） | 0、1315ジョブ | 10.90秒（変更したモジュールは途中のビルドで作成済み） |
| 公理監査 | `formal/` で lockf の下に `lake env lean -M 12288` [axioms.lean](axioms.lean)（[axioms.json](axioms.json)） | 0 | 38.66秒 |
| 照合 | [verify.py](verify.py) `--tmp <tmp> --baseline <tmp>/baseline.json`（[verification.json](verification.json)） | 0 | 数秒 |

作業の途中の局所検査は `lake env lean -M 12288` を同時に一つずつ使い、`-o` を付けていない。途中の既定ビルドは四回（4分47秒・10秒・11秒・6秒。最初の一回はStandardDecimalResponseの下流の作り直し）。最大常駐量は未取得（計画上の非採取）。

既定ビルドの警告は開始時と同じ162件で、変えた・足したモジュールの警告は0。

公理の監査は既定importの全プロジェクト宣言84,025件（privateと生成宣言を含む閉包、2回で固定点）を対象とし、依存する公理はpropext・Quot.sound・Classical.choiceの部分集合だけである（sorryAx 0、新しい公理 0）。生の出力は `<tmp>` に置き、大きさ17,408,138バイト・SHA-256 `beddb09ab85eba599e59ab5f2920821f5dd657ea36428e5ca224d3e6e662a060`、対象の一覧は5,561,063バイト・SHA-256 `be1b86663c782f92e9173883c6aa9292956f7ba26ba00fccfde70c507898751e`。四つの新しいモジュールとResourceReleaseLeavesの全167宣言の実署名と依存は [declarations-01.json](declarations-01.json)〜[declarations-08.json](declarations-08.json) に、件数・ハッシュは [audit-summary.json](audit-summary.json) にある。生成された照合の補助4件（`Primitive.numeric`・`Primitive.operator` の `match_1`・`_sparseCasesOn_1`）は型の字面が20,000バイトを超えるので、大きさとSHA-256だけを残した。

照合（verify.py）は、変更の範囲（開始時の全28,801ファイルのハッシュとの差が、既定import・二つの写し・五つの既存モジュール・四つの新しいモジュール・本書の記録に限ること、写しは [design_copies.py](design_copies.py) の置換の組を戻すと開始時に一致すること）、既定importの閉包、監査の結果、読者、行の件数（演算子109・数値166・最初の16件・証人の形275）、全場合の定理の場合の集合、`table_response` の不使用、台帳の差分の証拠名の実在、記録の大きさ（最大84,155バイト、群全体約0.91 MB。照合の実行時点の値は verification.json）・手元の絶対パスとdocs/todoへのリンクの不在を確かめる。

## 写し

01-12「篩を含むコア計算の形式化」の合成表の参照と明示遅延の行の文を五行へ改め、純粋な行の契約・三つの全場合の定理・共有の宣言の段落を加え、`StandardDecimalResponse` の段落を一般化した形に改めた。07-04 の同じ三箇所と、対応表に新しいモジュールの行を一つ加えた。置換の組は [design_copies.py](design_copies.py) にある。

## 義務と申し送りの判定

| 行 | F1の受け持ち | 判定 | 残る段 |
|---|---|---|---|
| O062 | 合成対象の同じδの全BuiltinArgsで存在・型・適格性・非exit | 一部。数値166行・演算子109行は完了（全入力を量化、全行実質）。String・Bytes・List・Map・Set・Range・%Map.replaceValuesと範囲付きの純粋な行は未 | .26/.28/.29、R50 |
| O065 | 合成対象のsourceTelRows・operationKinds・arity・StoreShapeと仮定側の台帳 | 一部。参照と明示遅延の五行のStoreShape・種類・効果なし、Option・丸め方式・HTTPの宣言のarity、仮定側の台帳の差分。全行のsourceTelRows・operationKinds・sig_scopedは未 | .29、L70 |
| O022 | 同じout/toTerm?からのfactsと全表への接続 | F1の分なし。数値・演算子の行の応答は型・適格性・非exitまでで、factsの接続は扱っていない | .29、R50/V10 |
| O016・O084・O118 | 共通 | 既定import・公理（上記）、篩・σ・externalの差なし（今回の変更はδの接続と宣言）、本番のコメントに段・単位のIDなし | 段末 |
| H06・S17 | 残る全表のsourceTelRows | F1の分なし（参照と明示遅延の五行のRowsInは `reference_rows`） | .29 |
| H13・S18 | 有限PのResult/Pairのarity2、Request/Errorと全lookup | 完了（`http_declarations`）。Optionと丸め方式も供給 | .27/.29 |
| H25 | 同じ有限宣言 | 一部。丸め方式を加えた同じ有限宣言表で数値・演算子の行を接続 | .26/.27/.29 |
| S06 | Reference四種kind=[value]と処理系の実四署名・Lazy.force | 完了。五行を合成表に置き、Rust・標準ソース・StoreShapeと照合 | .29の全表の照合 |
| S19 | 生lambda/closureの二表現と応答の差 | F1の分なし（数値・演算子の行は関数値を受けない） | .26/.33、R50 |
| S20 | Decimal.fromFloatのparsedとbits | 完了。NumericRemainingの同じbitsのδ | なし |
| S21 | 任意P/Bのresponseを使い、固定Pの証拠の無条件移植0 | F1の分は完了。固定PだったDecimalの証拠は宣言の条件付きの任意のPへ一般化して使った | .26〜.29 |
| S22 | 34演算子と構造等号の実署名、表の合成 | 完了（`operator_rows`） | .29/.30 |

## 計画からのずれ

1. L40のモジュール `StandardDecimalResponse` に、宣言の条件 `Declarations` と一般化した `response_of` を足し、既存の `response` をその適用にした。`response` と他の定理の実署名は変えていない。固定のPの証拠を合成プログラムへ当てられないためで、使わない前提を除く変更ではなく、前提を宣言の条件へ置き換えた一般化である（差の表）。

   | 宣言 | 元 | 今回 |
   |---|---|---|
   | `StandardDecimalResponse.response` | 固定の `program` | 同じ実署名。証明を `response_of program_declarations` に置き換え |
   | `StandardDecimalResponse.response_of` | なし | 任意のPと `Declarations P` |

2. 合成プログラムに丸め方式の宣言を加えた（`declarations` の末尾）。`signatureBase.sat` が読むデータの要約も一つ増える。群A・Eの定理の実署名は変わらず、全て既定ビルドで通った。
3. 群Eの `Primitive.store_rows`・`store_lookup`・`reference_rows` の文を変え、`no_store_transitions` を `store_transitions` へ置き換えた（依頼文が予告した読者の追随）。群Eの記録（resources.json の証拠名 `no_store_transitions`、verify.py の照合）は書き換えていないので、群Eの照合の台本をこの状態で再実行すると、その名前の照合で失敗する。
4. detailの「触るファイル」の StandardModelResponse に書かず、四つの新しいモジュールに置いた。StandardModelResponse を変えると下流の作り直しが増え、群F2以降の読者がこの段の定理を名前で引けるようにするためである。非空性の証人のモジュール（StandardModelPureInputs）はdetailに名前がなく、N（非空性）の判定のために足した。
5. 三署名の照合は群Eの台本を書き換えず、同じ読み方の照合を [store_signatures.py](store_signatures.py) に置いた。
6. 単位の時刻は、区切りごとに取得したコマンドの出力を作業末に本書へ写した。各単位を始めるときと終えるときに本書へ書いていない。

## 取りまとめに判断を求める点

1. **Process.exit は合成表へ加えていない**（[store-signatures.json](store-signatures.json) の `process_exit`）。種類exitの実行は、ハンドラのない呼出しでは `E_Exit`・`E_IOErr` が同じ表の `ioResponse` を読み、ハンドラのある呼出しは `E_OpPrim` で節へ移る。δ・IO応答のない専用の遷移ではないので、署名だけを置くと `io_exists` の欄が閉じず、閉じるには新しいIO応答の意味を定義する必要がある（J60-3=(a)の外）。合成表の既存の `exit`（ModelTargetsのモデル）は全ての整数を終了コードにし、処理系の範囲外の誤り（0〜255の外の `ArgumentOutOfDomain`）を写さないので、Process.exit の証拠に流用しない。Process.exit を使うプログラムは、証拠のない他のIOの名前と同じく合成表では型付かず、07-04の仮定（IO応答は仮定）の側に残る。台帳の理由を訂正した。合成表に入れる判断を求めるなら、IO応答の意味を定義する別の判断が要る。
2. 丸め方式のデータ名は既存のLeanの証拠どおり `RoundingMode` とした。処理系の標準ソースの実際の型名との対応は、L70の収集とR50の照合で確かめる対象である。
3. 群Eの記録が取り除いた名前 `no_store_transitions` を引いている（ずれ3）。前の群の記録は書き換えないので、群末の取り込みのときに扱いを決めてほしい。
4. 不適格な構造の比較の誤り `InternalComparison` と処理系のStop::Internalの照合は、R50への申し送りのままである。
5. 行ごとの契約275行は `delta_typed` の欄全体ではない。合成表の残りの純粋な行（.26/.28）とともに.29で欄を閉じる。

## 後段への申し送り

| 受け手 | 本番の入口 | 渡す条件 |
|---|---|---|
| L60.26〜.28（F2） | `PureRow`、`PureRow.of_row`・`of_response`、`PureRow.Satisfiable` と三つの署名の形の補題、`http_declarations`・`rounding_declarations` | 残る純粋な行も同じ契約の形で接続し、前提を満たす入力を示す |
| L60.29（F2） | `numeric_rows`・`operator_rows`・`numeric_inputs`・`operator_inputs`、`Primitive.numeric`・`Primitive.operator`、`store_transitions`・`reference_rows`・`store_shape` | 全行の場合分けで `delta_typed` を組み立てる。参照と明示遅延の五行は `store_shape`・`ref_get`・`ref_set` の欄へ。台帳の差分（[ledger-diff.json](ledger-diff.json)）を四照合の入力に加える |
| R50 | Process.exit の仮定側の理由、`InternalComparison`、丸め方式の型名 | 処理系の実物との照合 |

## 再開1（RV-L60.f1 の処置）

開始 2026-11-05T16:16:21+09:00、終了 2026-11-05T16:26:09+09:00（外側の時間。既定ビルドの待ち約5分を含む）。[RV-L60.f1](../../reviews/RV-L60.f1.md)（可、軽4・情報3）の所見を、取りまとめの指示した箇所に限って処置した。Leanは docstring だけを変え、宣言の型・値は変えていない。

| 所見 | 処置 |
|---|---|
| 軽1 | 演算子の集合を「%で始まる組込みの行から %Map.replaceValues・%eq・%ne を除いた107行と、%eq/%ne の2行（計109行）」と書き分けた。StandardModelOperatorRows のモジュールの説明と `Primitive.operator` の docstring、StandardModelPureInputs のモジュールの説明、本書の「L60.25」、01-12 の追加文 |
| 軽2 | `StandardDecimalResponse.Declarations` と `response_of` の docstring、01-12・07-04 の文を、Optionの二構成子とarityを持ち丸め方式の構成子を既知の五方式に限る条件（五方式の各構成子の存在は要求しない）へ改め、元の固定のPと合成プログラムが五方式を全て宣言することを別に書いた。本書の「L60.24」の同じ説明も直した |
| 軽3 | 01-12 の追加段落に `PureRow.Satisfiable`・`numeric_inputs`・`operator_inputs` と、Decimal.round・%eq/%ne の入力の文を加えた。07-04 の段落に `StandardModelPureInputs` の一文を加え、対応表の行に同じモジュールと「各行の契約の前提を満たす入力」を加えた |
| 軽4 | 01-12 の追加文と `PureRow.of_row` の docstring の「台帳の行」を「組込みの表の行（`StandardModel.Primitive`）」に改めた |
| 情報1 | 群Eの [resources.json](../e/resources.json) の証拠名 `StandardModel.no_store_transitions`（3箇所）を `StandardModel.store_transitions` に置き換え、[群Eの結果](../e/results.md) の末尾に指示の一行を足した。群Eの [verify.py](../e/verify.py) には消した名前の字面がないので変えていない。群Eのほかの記録（ledger.py を含む）は変えていない |
| 情報3 | [ledger-diff.json](ledger-diff.json) の `composition_child_keys` に、合成表の子キーが群Aの504（本体130・組込みの署名373・資源名1）から507（組込みの署名376）になることを記した（[ledger_diff.py](ledger_diff.py) が二つのLeanのソースと群Aの `composition_keys` から数える）。本書の「台帳の差分」にも書いた |
| 情報2 | 処置の指示なし |

置換の組の表 [design_copies.py](design_copies.py) を写しの変更後の文に合わせた。[verify.py](verify.py) には、群Eの二つの記録の変更が名前の置き換えと末尾の一行だけであることを、開始時のハッシュへ戻して確かめる照合を足した。

| 検査 | 終了 | 外側の時間 | 記録 |
|---|---|---|---|
| 既定ビルド（lockfの下で一度） | 0、1315ジョブ、警告は開始時と同じ162件 | 297.70秒（StandardDecimalResponseの下流の作り直し） | [default-build.json](default-build.json)。生の出力 48,292バイト、SHA-256 `c3bd3bdbe5f9f3a5a7a570042b14646e06aa8dde23c10894485a8c2b98da7dac` |
| 公理監査（lockfの下で一度） | 0。84,025宣言、許可三公理の部分集合だけ、sorryAx 0・新公理0。新しい四モジュールとResourceReleaseLeavesの167宣言（足した125） | 39.79秒 | [axioms.json](axioms.json)・[audit-summary.json](audit-summary.json)。生の出力 17,408,138バイト、SHA-256 `6667ae342d6de5d6c6a0e29f4dcd2baef9b00539ec8b376ed1d6ae82a9d54de3` |
| 群F1の照合 | 0 | 数秒 | [verification.json](verification.json) |
| 群Eの照合（群Eの一時領域の開始時のハッシュと監査の生の出力で一度） | 1 | 約1秒 | 生の出力 9,479バイト、SHA-256 `9cb1c61bbd4241685149a9ea44f4b1f13c8e1a3a716f1f3d2d178bff7f80f5fc`（`<tmp>`） |

群Eの照合は、最初の照合（群Eの開始時の全ファイルのハッシュとの比較で、追加のファイルを群Eのものに限る）で止まった。挙がったファイルは群Dの記録とモジュール、群Fの記録とモジュール、レビューの記録で、群Eの開始の後に群Dを取り込み群F1を加えたことによる。名前の置き換えとは関係なく、群Eの照合の台本を変えない限り、今の作業木では終了0にならない。置き換えた名前の照合（群Eの照合の第5段と同じ入力の読み方）は一時領域で単独に行い、群Eの条件と資源の記録の証拠名23件が今回の監査の対象に全て実在することを確かめた。群Eの監査の対象（群Eの時点）には `store_transitions` がない。

## 群 F1 の作業末の work の検査（取りまとめ）

- 基準: `d0f7b3051f74dfefb73a6ef6b3edd59ba734dfb1`（HEAD と一致）。作業木は再開1の後の未コミットの状態（worktree）。
- 事前に `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消した。
- コマンド: `scripts/check.sh --level work --base d0f7b3051f74dfefb73a6ef6b3edd59ba734dfb1`（`/usr/bin/time -l` で測定）。
- 終了状態 0（selected checks passed）。外側の時間 630.68秒（16:27:08〜16:37:39）、最大常駐量 3,884,613,632 バイト。
- 生の記録は `<tmp>` に置いた（6,624 バイト、SHA-256 `0d57157365a415f51a0db499a42075f26b27fb88c66a3f382a1f85e4be53b7c5`）。
- 計画からのずれ: なし。
