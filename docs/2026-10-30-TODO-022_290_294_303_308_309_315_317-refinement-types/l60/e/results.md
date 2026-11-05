# L60 群 E の実装記録

基準 B_WORK: `787e7139add411caac6a72ed4f072d70d27877b2`。指定ブランチ `m014/l60.e`。git の操作と scripts/check.sh の実行は行わない。共通依頼文と2026-10-30の勧告照合・組み込まない判断を継承する。

## 単位の時刻と判定

準備の読解（依頼文・detail・plan・群A〜Cの記録と本番の該当モジュール）は2026-11-05T14:04:17+09:00から行った。開始時の既定ビルドは差分なしで終了0（外側0.38秒）。

| 単位 | 開始（JST） | 終了（JST） | 判定 |
|---|---|---|---|
| L60.19 | 2026-11-05T14:11:06+09:00 | 2026-11-05T14:16:20+09:00 | 完了。表の条件・全結果の存在・三表の分類と入力。.20の葉と同じファイルで書いたため、この区間に.20のLeanの下書きを含む |
| L60.20 | 2026-11-05T14:16:20+09:00 | 2026-11-05T14:32:23+09:00 | 完了。8遷移・use・選択の葉。Leanは14:16の局所検査で終了0、全件照合は最終のverifyで終了0 |
| L60.21 | 2026-11-05T14:16:20+09:00 | 2026-11-05T14:32:23+09:00 | 完了。合成表の資源と参照の行（14:19の局所検査で終了0）、資源の台帳（14:25）。.20と区間が重なる |
| L60.22 | 2026-11-05T14:19:00+09:00 | 2026-11-05T14:32:23+09:00 | 完了。三モデルの合成の読者（14:21の既定ビルドで終了0）、87欄（14:26）、写し（14:24） |

四単位は同じ二つのファイルを行き来して書いたので、区間が重なる。各区間は外側の時間であり、能動時間とLeanの待ちは分離していない。群Eの外側の時間の全体は、読解の開始14:04:17から記録の作成を終えた14:40頃まで（約36分）である。見込みの2時間10分〜3時間30分の下端を下回った。主な理由は、群Aが解放の関係・Targetsの分類・三モデルのCoreを、群Cが87欄の分類と正常値の入力を本番で閉じており、群Eはその接続と照合に限られたことである。外側の時間を能動時間として見込みの更新に使わない。

## 追加したモジュールと写し

新しいモジュールは二つで、既定 import（`formal/Benitoite.lean`）に加えた。

| モジュール | 内容 |
|---|---|
| ResourceReleaseLeaves | 通常資源の関係を持つ表の条件 `ResourceRelease.Table`、全結果の解放、八つの遷移とuse・選択、外部ハンドルの不在、三モデルと合成表の資源の分類、合成表の参照と明示遅延の行 |
| ExternalModelComposition | 三モデルの同じ拡張表の25+3+1欄とCore・TargetAgreementの読者、Modelの六欄の前提の否定、存在欄の定数の証人、新12欄の前提を満たす入力 |

01-12「篩を含むコア計算の形式化」の `ResourceRelease.response` の段落の後に四段落、07-04 の三モデルの段落の後に一段落と対応表の二行を加えた。既存の文は変えていない（verify が追加箇所を除いた全文のハッシュを開始時と照合する）。

群Aの `ResourceReleaseModel`・`StandardModelSignatures` は変更していない。detailの「触るファイル」はこの二つを挙げるが、変えると後続の全モジュールの再ビルドが要り、群Dの並行作業と衝突しうるので、同じ内容を新しいモジュールに置いた（計画からのずれ1）。

## L60.19 資源値と通常の解放関係

| 完了条件 | 全場合・全入力の判定 |
|---|---|
| 任意のΨ/v/oのrelease_exists | `ResourceRelease.Table.release_all` は任意のP・B・Ψ・v・o と全ての結果r（成功none・任意の失敗some）を量化する。`Table.release_exists` はCoreAssumptionsの欄と同じ量化の形。`Table.release_value` は関係に属する値が資源名のopaque定数に限ることを示す |
| canonicalから型付き資源 | `Table.release_all` は群Aの `ResourceRelease.typed_response`（canonicalと表の分類）を読む。分類は表の条件 `Table.classification` で受け、Coreの新しい前提にしない |
| 三表の分類 | `ModelCase.resource_iff` は全ModelCase・全P・全名前で、資源名がTargetsのFile.Handleだけであることを示す。`ModelCase.resource_table` は三表とも同じ関係と分類を持つことを示す |
| 成功・失敗の対照 | Targetsの型付きFile.Handle（任意のP・Ψ・番号、`targets_resource_input`）でnoneと任意のsomeが関係に属し、整数と外部ハンドルは属さない（適用例） |
| Model/Httpの空疎の分離 | `ModelCase.release_premise_false` は `m ≠ .targets` の全ての名前で資源の前提を否定する |
| 全値noneの関係を使わない | 三表と合成表の解放応答は `ResourceRelease.response` そのもの（`Table.release` の等号）。旧 `ModelTargets.builtins` の `r = none` の関係は使っていない |

## L60.20 八つの解放の遷移と選択

`Step` の構成子のうち `releaseResponse` を前提に持つものは8個であり、verify が Semantics.lean から抽出して照合した。継続破棄で解放の枠を積む E_DropRel・E_EscDropRel・E_ErrDropRel・E_ExitDropRel の4個は解放応答を読まず、既存の継続の葉が積んだ枠の型付けを保つ。積んだ枠は下表の error・exit・ret・escape の開始で読む。

| 開始 | 成功 | 失敗（全てのr） | 群Eの葉 | 読む既存の葉 |
|---|---|---|---|---|
| ret | E_Release | E_RelErr | `StateTyE.release_return_all` | `StateTyE.return_release`・`return_release_failure` |
| escape | E_EscRel | E_EscRelErr | `StateTyE.release_escape_all` | `StateTyE.escape_release`・`escape_release_failure` |
| error | E_ErrRel | E_ErrRelErr | `StateTyE.release_error_all` | `StateTyE.error_release`・`error_release_failure` |
| exit | E_ExitRel | E_ExitRelErr | `StateTyE.release_exit_all` | `StateTyE.exit_release`・`exit_release_failure` |

四定理はいずれも成功の遷移・遷移先の型付けと、全てのrの失敗の遷移・型付けを連言で返す。ret・escapeは既存の葉と同じく `P.WellFormed`・`P.WellTyped B`・`B.CoreAssumptions P` を受け、全て `ResourceRelease.Table B` を受ける。値の関係は解放の枠の型付けから得る（`ContTy.release_resource`・`ContTy.release_all`）。

| 照合 | 判定 |
|---|---|
| 選択への接続 | `release_selected_run`（escapeの真偽を量化してretとescapeの両方）、`release_selected_error`、`release_selected_exit` は、`B.selectRelease v` が同じ関係に属することと、実行関数 `step` の結果・同じ `Step`・遷移先の `StateTyE` を返す。runは既存の `step_release_selected` と `Builtins.selectRelease_response` を読み、選んだ結果のnone・someの両方の場合で上の葉を使う |
| useの入口 | `StateTyE.use_release_all` は既存の `StateTyE.use_all` の遷移と型付けに、積んだ枠の値の全結果の関係を加える。use→release、drop→releases の既存の枠の順は変えていない |
| 外部ハンドルを混ぜない | `ContTy.release_not_external` は、表の条件の下で解放の枠に外部ハンドルが型付かないことを示す。三表と合成表の適用例を置いた |
| 具体の表 | Targetsの表で四つの開始の選択、useの枠の全結果を読む適用例を置いた（Coreは群Aの `targets_core`） |

## L60.21 通常資源の台帳と Reference の形

[resources.json](resources.json) を [ledger.py](ledger.py) で作った。Rustの `runtime::ResourceKind` の列挙と表示名の定数をソースから抽出し、群Aの資源の台帳・全台帳の行と照合する。

| 区分 | 行 | 分類と根拠 |
|---|---:|---|
| Rustの通常資源 | 5 | FileReader（File.Reader）・FileWriter（File.Writer）・HttpListener（Http.Listener）・HttpExchange（Http.Exchange）・TaskGroup（TaskGroup）。全て仮定側。同名のLeanの資源名も、開閉状態・中断・失敗理由の算法の証拠もない。07-04の解放応答の条件として量化する |
| Leanの通常資源 | 1 | File.Handle。合成。`StandardModel.resource_table`・`resource_input`・`release_all` と三表の同じ証拠。Rustの五種のどれの実署名でもない |
| 外部型 | 1 | 通常資源に含めない。`ExternalSignatureLeaves.handle_not_release`・`ContTy.release_not_external` |
| 参照と明示遅延 | 5 | Reference.get・Reference.set は合成（`store_lookup`・`reference_rows`・`store_shape`・`ref_get`/`ref_set`）。Reference.new・Reference.update・Lazy.force は群Aの台帳どおり仮定側（専用の遷移）。合成表がこれらの種類の行を持たないことを `no_store_transitions` が全lookupで示す |

合成表の全373行について、参照と明示遅延の5種類の行がReference.get・Reference.setの二行だけであることを `StandardModel.Primitive.store_rows` が行の構成子の全場合で示す（各行の種類を `decide` で判定。既定ビルドでの所要は約9秒）。ここから、PathBases以外の全署名の `StoreShape`（Coreの `store_shape` の欄と同じ量化）を `StandardModel.store_shape` で示した。依頼の「合成対象の全件照合」は参照の行に限らず全行の種類の判定を要したので、全行へ広げた（計画からのずれ2）。二行の種類[value]・元の依存列の行の上限（sourceTelRows）・操作の効果なし（operationKindsの前提が成り立たない）を `reference_rows` で示す。合成表の `ref_get`・`ref_set` の二欄も示した。全行のoperationKinds（opEffを持つ全署名の種類）とsig_scopedは.29の受け持ちのまま残す。

## L60.22 三モデルのCoreと対象条件

`ExternalModels.ModelCase.composition` は全ModelCase・全Pで、元の宣言条件（ModelはTrue、TargetsはHasFile、HttpはHasHttp）だけを受け、同じ拡張表の `ModelScopeConditions`（25欄）・`ExternalAssumptions`（3欄）・全結果の解放（1欄）・CoreAssumptions・TargetAgreementを返す。Coreは群Aの `model_core`・`targets_core`・`http_core` をそのまま読み、作り直していない。25+3+1から `ModelScopeConditions.core` でCoreを組み立てられることは適用例で示した。

[conditions.json](conditions.json) を [conditions.py](conditions.py) で作った。欄の母集団は本番の五つの構造体と `ExternalAssumptions`・`CoreAssumptions.release_exists` の定義から抽出し、L50の75欄の判定と群Cの87欄の判定に一致することを確かめた。

| 列 | 不成立 | 空疎 | 自明 | 実質 | 保留 |
|---|---:|---:|---:|---:|---:|
| 既存75 | 0 | 6 | 0 | 69 | 0 |
| 新12 | 0 | 2 | 3 | 7 | 0 |
| 合計87 | 0 | 8 | 3 | 76 | 0 |

| 分類 | 欄 | 前提の否定・結論の自明さ・充足できる入力 |
|---|---|---|
| 空疎8 | Modelの delta_typed・io_typed・io_kind・io_exists・io_op・io_target、Model/Httpの release_exists | 拡張表の上で前提からFalseを導く。`model_vacuous_premises` の六成分（各欄の前提の並びそのまま）と `ModelCase.release_premise_false` |
| 自明3 | 三表の external_exists | `ModelCase.external_constant` は宣言・引数・ストアを読まない定数errと空観測で全入力に応答を与える。前提は正常値で満たせる（`new_field_inputs`）が、結論は前提を読まない |
| 実質7 | 三表の external_typed・external_no_targets、Targetsの release_exists | 前提を満たす入力: `new_field_inputs`（群Cの `shape_inputs`）と `targets_resource_input`。結論は生応答の証拠又は型付き値のcanonicalと分類を読み、関係はopaque資源定数以外を断る |
| 実質69 | 既存の25欄（Model19・Targets25・Http25） | 前提の否定はL50の前提検査で閉じない。前提を満たす入力はL50で受け入れた到達枝の証拠を、同じPの七射影とδ・IO・refGet・refSet・effKindの一致（`ExternalModel.scope_conditions`・`ModelScopeConditions.of_responses`・`BuiltinArgs.of_fields`）で拡張表へ移す |

既存の25欄のうち state_effect・ref_get・ref_set の3欄は前提を持たない閉じた命題である（conditions.jsonの `no_premise_fields`）。結論は表の署名・効果の内容を読むので、L50の判定どおり実質に数えた。「自明」の定義（充足可能な前提に依存せず定数の証人で閉じる）に照らした扱いを、取りまとめへの判断の点に挙げる。

## 群Eの完了条件の照合

| 群Eの完了条件 | 全場合・全入力での判定 |
|---|---|
| 8解放葉 | 4開始×2結果の全8構成子を四定理が返す。失敗は全てのrを量化。選択は3定理で4開始と選んだ結果の両場合。抽出した8構成子と既存の8葉、群Eの宣言の依存をverifyが照合 |
| 既存証拠のある通常資源と5種の名前台帳 | File.Handle 1名を合成、Rust 5種を名前・表示名・理由つきで仮定側、外部型を除外。合成表の全373行の参照と明示遅延の種類を全場合で判定 |
| 87欄の実質76/自明3/空疎8 | 既存75と新12を別の列で出力。保留0。各欄に前提の否定・結論の自明さ・入力の三列とLeanの証拠名（監査の全宣言に実在することをverifyが照合） |
| 外部ハンドルを通常資源へ混ぜない | `ContTy.release_not_external` と `handle_not_release`。外部ownの解放は既存の担当（L70/R50）に残す |

## 足した宣言

二つのモジュールの宣言は47（ResourceReleaseLeaves 43、ExternalModelComposition 4。private 3、構造体の生成宣言と `match` の補助を含む）。全実署名・型のSHA-256・直接の依存は [declarations-01.json](declarations-01.json)・[declarations-02.json](declarations-02.json)、読者は [readers.json](readers.json) にある。公開の35名は、全て名前付きの読者か既定ビルドの適用例を持つ（件数の内訳は再開2を正とする）。

- ResourceRelease: `Table`、`Table.release_all`、`Table.release_exists`、`Table.release_value`
- ExternalModels: `ModelCase.resource_iff`、`ModelCase.resource_table`、`ModelCase.release_all`、`ModelCase.release_premise_false`、`targets_resource_input`、`ModelCase.composition`、`model_vacuous_premises`、`ModelCase.external_constant`、`ModelCase.new_field_inputs`
- StandardModel: `resource_table`、`resource_input`、`release_all`、`Primitive.store_rows`、`store_lookup`、`no_store_transitions`、`store_shape`、`row_lookup`、`ref_get`、`ref_set`、`reference_rows`
- ContTy: `release_resource`、`release_all`、`release_not_external`
- StateTyE: `use_release_all`、`release_return_all`、`release_escape_all`、`release_error_all`、`release_exit_all`、`release_selected_run`、`release_selected_error`、`release_selected_exit`

`ContTy.release_resource` は HandlerGeneral の private な `release_tail_all` の前半と同じ内容である。privateのため読めないので、公開の補題として置いた。

## 検査と公理への依存

全て `formal/` から、固定のLean 4.34.1 で実行した。生出力は一時領域に置き、ここには大きさとSHA-256を残す。RSSは未取得（計画上の非採取）。

| 検査 | コマンドの要旨 | 終了 | 外側 | 記録 |
|---|---|---:|---:|---|
| 開始時の既定ビルド | lockfで順番を取り `lake build` | 0 | 0.38秒 | 差分なし |
| 局所Lean | `lake env lean -M 12288` で新しいモジュールを単独検査（途中の数回） | 最終0 | 0.8〜9.2秒 | 途中の誤りは記法・defeqの展開の不足（後述） |
| 最終の既定ビルド | lockfで順番を取り `lake build` | 0 | 28.71秒 | [default-build.json](default-build.json)。生出力45,575バイト。新しい二モジュールの警告0 |
| 全環境の公理監査 | lockfで順番を取り `lake env lean -M 12288` で [axioms.lean](axioms.lean) | 0 | 47.32秒 | [axioms.json](axioms.json)・[audit-summary.json](audit-summary.json) |
| 記録の照合 | [verify.py](verify.py) | 0 | 約1.5秒 | [verify.json](verify.json)・[verification.json](verification.json)・[tools.json](tools.json) |

公理監査は既定 import の閉包1,049モジュールの全プロジェクト宣言83,740件（private・生成宣言を含む）を `#print axioms` した。全体の公理の集合はpropext・Quot.sound・Classical.choiceの部分集合だけで、sorryAx 0、新しい公理0。足した47宣言の内訳は、三公理の全部36・依存なし11である（Classical.choiceは選択の関数 `selectRelease` と既存の三モデルの表に由来する）。監査の対象は [inventory.py](inventory.py) で、必須入口131名（群Cの96名に既存の解放の葉・選択・三モデルの入口35名を加えた）を作り直せる。

verify は次を照合した。開始時に一時領域へ取った全28,745ファイルのハッシュと比べ、変更は `formal/Benitoite.lean`・01-12・07-04の三つだけで、追加箇所を除いた全文が開始時と一致すること。追加は新しい二モジュールと本ディレクトリだけであること。二モジュールが既定 import の閉包と監査に入っていること。公開名の読者、八つの構成子と既存の葉、87欄と台帳の証拠名の実在、`sorry`・`axiom`・`native_decide`・`#eval`・`set_option`・工程のIDが二モジュールにないこと、記録の大きさ（最大83,972バイト）と手元の絶対パス・docs/todoへのリンクの不在。

局所Leanの途中の誤りは、`m ≠ .targets` の `decide` の不可、`Option.some_get` の暗黙引数、文字列の名前とrefGetの欄の `show` によるdefeqの照合の失敗（行の名前を経由する `row_lookup` に替えた）である。証明の方針・言明は変えていない。開始時のファイルのハッシュの台本はキーの先頭2文字を落とす誤りがあり、変更を加える前の同じ全ファイルの走査から直した（キーの対応で全28,745件が一意に一致し、その時点の差分は0件）。

## 担当の義務の一行ずつの判定

| 義務・受け口 | 群Eの受け持ち | 判定 | 残る所有 |
|---|---|---|---|
| O013 | .22 三モデルの12欄と同じP/Bの対象条件 | 群E分は完了。composition が同じ拡張表のTargetAgreementを返す | .29の合成表、L70/R50/V10 |
| O038 | .20/.22 通常解放の同じ状態からの葉と三表 | 群E分は完了。四開始の成功・失敗の遷移と型付け | .29、L70全保存 |
| O057 | .19/.22 任意の新型付き入力からreleaseの応答存在 | 群E分は完了。任意のΨ/v/oと全r | .14（群D）・.29、L70 progress |
| O058 | .20 σ/Eb/μを保つ解放の保存葉 | 群E分は完了。既存の葉の同じσ・Eb・μ | .14・.29、L70 preservation |
| O059 | .20 選んだ解放応答からstep→Step | 群E分は完了。3定理で4開始 | .15（群D）、L70 step_sound |
| O060 | .22 外部obs=[]の読者 | 一部。compositionが同じ表の外部三欄を返す。Stateの追跡と合成表のeffectsは他単位 | .29、L70 |
| O064 | .19〜.22 三モデルと合成資源の全型付き値で新関係の存在、5種の名前と理由 | 群E分は完了 | R30/R50の実装比較 |
| O065 | .21 合成対象の参照の行の形と仮定側の台帳 | 一部。参照・明示遅延の全行のStoreShape、二行の種類・行・効果。全署名のoperationKinds・sourceTelRows・arityは.23/.29 | .23/.29、L70 |
| O088 | .19〜.22 三条件9欄と通常資源の区別 | 群E分は完了。外部ハンドルを解放へ混ぜない | L70/R50 |
| O016 | 担当単位は.35/.36（群Eの単位を含まない） | 群Eは入力を用意した（新モジュールの既定import、全環境の監査の記録）。行の判定は変えない | .35/.36、段末A-L |
| O084 | 担当単位は.01〜.05/.36（群Eの単位を含まない） | 群Eは入力を用意した（停止条件に当たる変更なしの記録）。行の判定は変えない | .36、L70/R/K/V |
| O118 | 担当単位は.34/.36（群Eの単位を含まない） | 群Eは入力を用意した（本番のコメントに作業IDがないことのverifyの記録）。行の判定は変えない | .34/.36、L70/R50/R60/D10/V10 |
| O157 | 担当単位は.09/.18/.29/.33/.34（群Eの単位を含まない） | 群Eは入力を用意した（新しい解放の葉と合成の01-12・07-04の写し）。行の判定は変えない | .29/.33/.34、L70/R50/D10/V10 |
| H06・S01・S16・S17 | .21 sourceTelRows・operationKinds | 一部。合成する参照の二行のみ。全標準行は.23/.29 | .23/.29 |
| H07・S02 | .22 75欄を新Bへ移し12欄と合成 | 群E分は完了。sat=Trueの例で代用していない | .29 |
| H09・H10 | .22 sat/admitsの保存の再利用 | 群E分は完了（三表の既存8欄を移送のまま読む）。合成表は.29 | .29 |
| H16 | .21 valKindの分類 | 一部。資源名のvalKind=noneを合成表で示した。PathIn/RequestInの分類は.28/.29 | .28/.29 |
| H27・S05 | .19〜.22 12行と28+1の新表 | 群E分は完了。三モデルの29欄 | .29の合成表 |
| H29 | .19 borrow/own/Stateと通常資源の区別 | 群E分は完了 | .28、R30 |
| S06 | .21/.29 Reference四種kind=[value]と処理系の実四署名 | 一部。合成する二種は[value]。処理系の四署名とLazy.forceを、Rustの登録・標準ソース・StoreShape、合成表の二行と照合した（再開1）。new・updateは合成表に行がない | .23（L60.23で加える行）と.29の照合 |
| S15 | .21 正規形の継承 | 変更なし（BuiltinArgsの量化を変えていない） | .29 |
| S23・S24・S25 | Modelのrelease空疎、Targetsのnone自明との区別、75欄と12欄 | 完了 | なし |
| S27・S28 | 69/0/6と7/3/2の別集計、Targetsのreleaseが通常資源の関係の接続であること | 群E分は完了 | .32の段末照合 |

閉じた（残る所有がない）行は S23・S24・S25 の3行で、他は群E分の完了か一部であり、段全体の義務の閉鎖ではない。

## 計画からのずれ

1. 置き場所: .19の表の条件と全結果の存在、.21の合成表の定理を、detailが挙げる `ResourceReleaseModel`・`StandardModelSignatures` ではなく新しい `ResourceReleaseLeaves` に置いた。.22は新しい `ExternalModelComposition` に置いた。既存モジュールの変更による再ビルドと、群Dとの衝突を避けるためである。定義・前段の署名は変えていない。
2. 範囲の拡大: .21の「合成対象の全件照合」に、合成表の全373行の種類の判定と全署名の `store_shape` を含めた。参照の二行だけでは他の行に参照の種類がないことを示せないためである。
3. 既存75欄の前提を満たす入力: 新しいLeanの証人は作らず、L50で受け入れた到達枝の証拠と同じPの移送の組で示した。新12欄・空疎8欄・自明3欄はLeanの証拠を新しい表の上で置いた。
4. 所要: 外側約36分で、見込みの下端を下回った。理由は「単位の時刻と判定」に書いた。

停止条件（主な10言明の形・新しい公理・独立の信頼条件・書ける形を狭める変更・提供範囲の削減・精密な外部状態・型付けの規則の変更・U02に依存する公開形）に当たる変更はない。前段の実署名は変えていない。

## 後段へ渡す署名と受け口

| 受け手 | 入口 | 内容 |
|---|---|---|
| F2（.28/.29） | `StandardModel.resource_table`・`release_all` | 合成表のCoreの `release_exists` は `(resource_table P).release_exists` で供給できる |
| F2（.29） | `StandardModel.store_shape`・`ref_get`・`ref_set` | 合成表のCoreの三欄（store_shape・ref_get・ref_set）と同じ量化 |
| F2（.29） | `StandardModel.store_lookup`・`no_store_transitions`・`reference_rows` | 参照・明示遅延の行の全lookupの分類 |
| F1（L60.23） | `StandardModel.Primitive.store_rows`・`store_lookup`・`no_store_transitions`、[reference-signatures.json](reference-signatures.json) | Reference.new・Reference.update・Lazy.forceの署名を合成表へ加えると、`store_rows` の場合分けと `no_store_transitions` の結論が変わる。三つの署名と処理系の宣言の照合は残りの3件として渡す |
| L70 | `StateTyE.release_*_all`・`release_selected_*`・`use_release_all` | 任意の表で `ResourceRelease.Table` と既存の前提から、四開始の全結果の遷移と型付け、実行関数の選択 |
| L70・R30/R50 | `ResourceRelease.Table`・`ContTy.release_not_external`、[resources.json](resources.json) | 抽象の解放の関係とRust 5種の仮定側の理由。実資源の解放・中断・失敗との向きの照合はR30/R50 |
| G（.32） | `ModelCase.composition`、[conditions.json](conditions.json) | 87欄の行ごとの三列と証拠名 |

## 取りまとめに判断を求める点

1. 合成表に Reference.new・Reference.update・Lazy.force の署名がない。群Aの台帳はこれらを「専用の遷移」として仮定側に置いた。これらの遷移はδ・IO応答を持たず、署名と `StoreShape` だけで合成表へ置ける可能性がある。L70で利用者のプログラムを合成表で型付けると、この三つを使うプログラムが型付かない。群Eでは合成表の形を変えていない。F2又はL70の前に、署名を合成表へ加えるかを判断してほしい。（再開1の時点で、取りまとめが群F1のL60.23で合成表へ加えると記録した。申し送りの先はF1のL60.23とする）
2. 既存75欄の state_effect・ref_get・ref_set の3欄は前提を持たず、具体の署名や効果の値で閉じる。L50の判定どおり実質に数えたが、「自明」の定義に照らした扱いを確かめてほしい。自明に移すと、3欄×3表の9欄が移り、87欄は実質67・自明12・空疎8となる。
3. 既存69欄の前提を満たす入力は、L50の到達枝の証拠と移送の組で示した。新しい拡張表の上の個別のLeanの証人を求めるなら、Targets/HttpのBuiltinArgsを要する欄（delta_typed・io_*）の証人の構成が要る。

## 再開1（RV-L60.e の処置）

開始 2026-11-05T14:48:46+09:00、終了 2026-11-05T14:53:03+09:00（外側の時間）。[RV-L60.e](../../reviews/RV-L60.e.md)（可、軽3・情報2）の軽1〜3を所見の箇所に限って処置した。Leanの宣言は変えていないので、既定ビルドと公理監査は再実行していない。情報1・2は処置せず、情報1の申し送りの先だけを取りまとめの記録（群F1のL60.23で三署名を合成表へ加える）に合わせた。

| 所見 | 処置 |
|---|---|
| 軽1 | 「担当の義務の一行ずつの判定」のO016・O084・O118・O157を、detailの担当単位（.35/.36、.01〜.05/.36、.34/.36、.09/.18/.29/.33/.34）を明記し「群Eは入力を用意した。行の判定は変えない」の形へ直した。O084の残る所有に.36を戻した |
| 軽2 | S06の担当を.21/.29とし、R50へ移す記述を消した。.21の範囲で行える照合として [reference_signatures.py](reference_signatures.py) を置き、処理系の四署名とLazy.forceの5件を、Rustの登録（名前・state/pureの区分・引数の個数）、標準ソースの型付きの宣言（名前・型引数・引数の名前と型・結果・uses）、Leanの `PrimSig.StoreShape` の各種類の形と照合した。合成表の二行（Reference.get・Reference.set）は `ScopeSignatures.refGet`・`refSet` の名前・種類・引数・結果・効果とも一致した。5件とも全項目が一致した（[reference-signatures.json](reference-signatures.json)）。合成表に行のないReference.new・Reference.update・Lazy.forceの3件の、合成表の行との照合はL60.23で加える行について.23/.29へ渡す |
| 軽3 | [verify.py](verify.py) の適用例の範囲を、`example` から次のトップレベルの宣言・docstring・名前空間の区切りの前までに直した。公開35名のうち名前付きの読者17、既定ビルドの適用例26（直す前は35と数えていた）。適用例のない9名（`ResourceRelease.Table`・`ModelCase.resource_iff`・`Primitive.store_rows`・`store_lookup`・`ContTy.release_resource`・`StateTyE.release_return_all`・`release_escape_all`・`release_error_all`・`release_exit_all`）は全て名前付きの読者を持つ |

verify は、独立レビューの記録 `reviews/RV-L60.e.md` を取りまとめが加えたファイルとして変更の範囲から除くように直した。最初の実行はこのファイルで終了1、直した後の実行は終了0・1.55秒だった。記録を書き終えた最後の状態で、もう一度実行した（[verify.json](verify.json)）。

## 再開2（RV-L60.e の再レビューの残件の処置）

開始 2026-11-05T14:58:11+09:00、終了 2026-11-05T15:00:02+09:00（外側の時間）。再レビューの再軽1（軽3の残件）だけを処置した。Lean・lakeは実行していない。

[verify.py](verify.py) の読者の照合を、末尾名の検索から完全名の解決へ直した。各適用例の位置で開いている名前空間の列を保存し、適用例の中の名前を次の規則で完全名へ解決する。無修飾・修飾の名前は、開いている名前空間の各接頭辞を付けた名前とする。ドット記法の受け手が変数のときは、同じ適用例の束縛（`(m : ModelCase)`・`∀ m : ModelCase`・`(run : StateTyE …)` など）の型の名前空間で解決し、束縛がなければ止める。受け手が括弧のときは `(… resource_table P)`（`ResourceRelease.Table`）だけを解決し、型を決めない他の括弧は数えない。公開35名のうち、既定ビルドの適用例で直接使うものは24名である（再開1の26名は、`ResourceRelease.Table.release_all` と `ContTy.release_all` を末尾名の `release_all` の衝突で数えていた）。適用例のない11名は、全て名前付きの読者を持つ（[readers.json](readers.json)）。名前付きの読者は17名のまま変わらない。

verify はLeanの版を `lake env lean --version` で取らず、前回の [tools.json](tools.json) の記録を引き継ぐように直した（`formal/lean-toolchain` のハッシュが前回と一致することを照合する）。取りまとめが同じ作業ディレクトリでビルド出力を作り直しているため、lakeを起動しないためである。verify は一度実行した（[verify.json](verify.json)）。

## 群 E の作業末の work の検査（取りまとめ）

- 基準: `787e7139add411caac6a72ed4f072d70d27877b2`（HEAD と一致）。作業木は再開1の後の未コミットの状態（worktree）。
- 事前に `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消した。
- コマンド: `scripts/check.sh --level work --base 787e7139add411caac6a72ed4f072d70d27877b2`（`/usr/bin/time -l` で測定）。
- 終了状態 0（selected checks passed）。外側の時間 620.95秒（14:56:57〜15:07:18）、最大常駐量 3,796,844,544 バイト。
- 生の記録は `<tmp>` に置いた（6,624 バイト、SHA-256 `078ee0f2a85425545ee42e604ffd3f81f07f9e40a10c10c4a860db312edca00a`）。
- 計画からのずれ: 再開2（verify.py の読者の照合と記録だけの修正。Lean・設計書は変えていない）は、この検査の実行中の 14:58〜15:00 に行った。再開2の後の verify.py は終了0である。群 D の作業と同じ機械で並行したので、外側の時間と最大常駐量は単独の実行より大きい。

群 F1 で `no_store_transitions` を `store_transitions` へ置き換えた（参照と明示遅延の三行を合成表へ加えたため）。
