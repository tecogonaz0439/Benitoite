# L60 群 F2 の実装記録

基準 B_WORK: `25ea27a0f15bd9010e302bde340c7f1cd767319b`。指定ブランチ `m014/l60.f2`。git の操作（コミット・切り替え・取り込み）と scripts/check.sh の実行は行わない。開始版との比較は読み取りだけのgitの照会（ls-tree・show・check-ignore）で行う。共通依頼文と2026-10-30の勧告照合・組み込まない判断を継承する。J60-1=B・J60-2=F06・J60-3=(a)と群A・F1の台帳を正とする。

## 単位の時刻

依頼文・detail・tables・plan・群A〜F1の記録と本番の該当モジュールの読解は2026-11-05T16:38:58+09:00に始めた。開始時の既定ビルドは差分なしで終了0（16:42:45、外側0.38秒、1315ジョブ）。

| 単位 | 開始（JST） | 終了（JST） | 所要 | 判定 |
|---|---|---|---:|---|
| L60.26 | 2026-11-05T16:49:19+09:00 | 2026-11-05T16:56:10+09:00 | 6分51秒 | String・Bytes・List・Map・Setの純粋な79行の契約を本番で閉じた |
| L60.27 | 2026-11-05T16:56:10+09:00 | 2026-11-05T18:05:46+09:00 | 1時間9分36秒 | 全130本体の再証明と `program_typed` を本番で閉じ、既定ビルド終了0 |
| L60.28 | 2026-11-05T18:05:46+09:00 | 2026-11-05T18:21:00+09:00 | 15分14秒 | IOと終了の10行・範囲付きの純粋な6行と %List.getFront の契約を本番で閉じた。参照・明示遅延の5行と発行の行は群E・F1の補題を同じ表で読む |
| L60.29 | 2026-11-05T18:21:00+09:00 | 2026-11-05T19:38:00+09:00 | 1時間17分 | 28+1欄・WellTyped・WellFormed・四照合・写し・記録・最後の既定ビルドと監査と照合 |

L60.27の終了の時点で既定ビルドは終了0だった（18:05、build7）。依頼の「.27の完了で途中の結果と残りの見込みを書く」は、その時点で本書へ書かず、L60.29の作業中に書いた（計画からのずれの表の6）。当時の残りの見込みは.28と.29で1時間30分〜2時間30分であり、実績は1時間32分である（記録の作成を含む）。読解の開始からの全体は約3時間で、見込み3時間50分〜6時間40分を下回り、5時間を超える見込みは生じなかった。

## L60.26 純粋な79行（String・Bytes・List・Map・Set）

`StandardModel.collection_rows` は、`Primitive.collection` が真の79行の全てで、合成表の名前の契約 `PureRow (program externals) row.name` を返す（全行の全 `BuiltinArgs` で、合成表のδが型付きの非exitの応答を返し、応答が適格である）。各行の証拠は既存の任意のP/Bの応答の補題であり、部分表の `table_response` を使わない（verify.py が新しいモジュールの本文に `.table_response` がないことを照合）。

| 族（`StandardModel.PureRow.*`） | 行 | 既存の応答の証拠 |
|---|---:|---|
| string | 26 | `StandardStringOrdinaryResponse.response` |
| bytesOrdinary | 13 | `StandardBytesOrdinaryResponse.response` |
| map | 8 | `StandardCollections.map_api_response` |
| set | 8 | `StandardCollections.set_api_response` |
| bytes | 5 | `StandardBytesResponse.related_response` |
| list | 5 | `StandardListResponse.related_response` |
| listRemaining | 5 | `StandardListRemainingResponse.response` |
| precision | 4 | `StandardCollectionPrecision.map_response`・`set_response` |
| headTail | 2 | `StandardHeadTail.option_response` |
| replaceValues | 1 | `StandardMapReplaceValues.response` |
| append | 1 | `StandardHeadTail.append_response` |
| range | 1 | `StandardListRemainingResponse.range_response` |
| 計 | 79 | |

写像と集合の鍵の符号化は合成プログラムの全構成子の並び（`StandardModel.constructorNames`）を読み、`StandardModel.table externals`（`StandardKeyTyping.Table`）が鍵の宣言表の要約の一致・構成子名とデータ名の一意性を `decide` で供給する。Optionの宣言は `option_declarations`、変性の検査は `variance_valid` が供給する。篩付きの入力と全σのAdequateResultは既存の応答の補題の結論をそのまま使う。仮定側の名前は表へ足していない（四照合の2）。

## L60.27 全130本体の再証明

`StandardModel.body_typed externals body` は、任意の外部宣言について、全130本体（`Body.all`）が合成プログラムと合成表で型付くことを示す。`definition_typed` は成功した全lookupの定義へ、`program_typed externals hw` は `Program.WellTyped` へ広げる（変性は `variance_valid`、外部は `hw`、実装は空）。一般の表拡張の単調性は使わない。群Aの8本の試行は `externals = []` の具体の表だったが、全130本体を任意の `externals` で閉じた。

本体の証拠の三種（群Aの `resume3-body-classification.json`）ごとの方法と件数（[body-methods.json](body-methods.json)、台本 [body_methods.py](body_methods.py)）：

| 三種 | 方法 | 件数 | 合成表での証明 |
|---|---|---:|---|
| 任意のP/B（2） | 直接 | 2 | `StandardSafe.head_row_typed`・`toList_row_typed` をそのまま使う |
| 副条件付き（51） | 一般化 | 24 | getterの内部12と公開12。`StandardOrdinaryCoreBodies.Records P`（四つの記録型の宣言）を前提に取る `getter_typed_of`・`projection_typed_of` へ、合成表の `records externals` を供給 |
| | 副条件の供給 | 10 | Listのhelperと公開の5組。`StandardOrdinaryListBodies.helper_typed`・`public_typed` へ、合成表の `Inputs`（Optionの宣言・組込みの署名・helperのlookup・sat）を供給 |
| | 写し | 17 | Listのmap/filterの通常側・精密側と補助（8）、通常側・精密側のMap/Setのmap/filter（8）、非空の列の精密なmap（1）。元の証明の構成を、合成表の内部の名前（`FunctionNames.rename`）と合成表の署名の上で閉じた定理（`StandardModelOrdinaryList`・`StandardModelPreciseList`・`StandardModelOrdinaryCollection`・`StandardModelRefinedCollection`） |
| 固定のP/B（77） | 一般化 | 63 | 別名51は `StandardAliasBodies.body_typed_of`（Optionのarityを前提に取る）、通常core10は `StandardOrdinaryCoreProgram.body_typed_of`（`Context P B ρ`：データのarity・構成子・Optionの宣言・組込みの署名・写した関数参照のlookup）、Pairの射影2は `pair_typed_of` |
| | 写し | 13 | 安全な入口の4本と精密なgetter9本。`StandardSafe.Composed.*`（合成表の構成子と内部の組込み %List.getFront の上で元の証明の構成を閉じた） |
| | 直接 | 1 | `Internal.NonEmptyList.head` は `headRow` と名前だけが異なる同じ本体であり、任意のP/Bの `head_row_typed` を使う |
| 計 | | 130 | |

元の固定のP/Bの定理（`StandardAliasBodies.body_typed`・`StandardOrdinaryCoreBodies.getter_typed`・`projection_typed`・`StandardOrdinaryCoreProgram.body_typed`・`pair_typed`）は、一般化した定理の元の表への適用として残し、元の読者（`declarations_typed`・`all_lookup_typed` 等）の証明はそのまま通る。handled/effOps・ConstOK・isResourceと全lookupの副条件は、合成表の同じ定義を `rfl` か群Aのlookupの定理で供給した。

## L60.28 証拠のあるIO・ストア・範囲（9 kind）

| kind | 行 | 合成表の証拠 |
|---|---|---|
| pure（範囲付き） | Scope.checkPathIn・pathInValue・widenPathIn、Http.checkRequestIn・requestInValue・widenRequestIn の6行と内部の %List.getFront | `scope_rows`（`PureRow.scope` が `ScopeResponse.response`、`PureRow.front` が `StandardSafe.front_response` を読む） |
| io | File.readTextIn・readBytesIn・writeTextIn・writeBytesIn・appendTextIn・appendBytesIn・Http.sendIn・print・File.readText | `io_rows`（`IORow.scoped` が `ScopedIOResponse.response`、`IORow.print`・`IORow.readText` がModelTargetsのモデルの同じ応答の関係を読む） |
| exit | exit | `IORow.exit`（ModelTargetsのモデルの同じ応答の関係） |
| refGet・refSet | Reference.get・Reference.set | 群Eの `store_lookup`・`ref_get`・`ref_set` |
| refNew・refUpdate・force | Reference.new・Reference.update・Lazy.force | 群F1の `store_transitions`（δ・IO応答を持たず専用の遷移が受け持つ） |
| pathBases | Example.pathBases | `pathBases_shape`（発行の八欄とEnvironmentの所属） |

`IORow P b` は、名前bの全 `BuiltinArgs` と全てのIO応答について型付きで適格な結果・応答の種類・対象の条件を返し、全 `BuiltinArgs` についてIO応答の存在を返す契約である。`io_exists` は合成表のIO応答の存在であり、外部応答の存在 `external_exists`（入力を読まない定数のerr、`ExternalModel.external_assumptions`）と別の欄で示す。新しいIO・資源の意味は定義していない。証拠のある通常資源はFile.Handleの1名であり、群Eの `resource_table`・`resource_input` を同じ表で読む。

## L60.29 28+1欄・WellTyped・WellFormed

`StandardModel.core externals : Builtins.CoreAssumptions (program externals) (builtins (program externals))` と `targets externals : TargetAgreement …` を、任意の外部宣言について同じ合成プログラムと合成表で構成した。

| 欄の組 | 証拠 |
|---|---|
| 置換8（sat/admitsの改名・値の像・型の改名・置換） | `substitution_assumptions`。合成表の制約は `ModelConstraints.sat`（合成プログラムの宣言の要約）、許容はList.sortの行を除き `ModelConstraints.admits` と同値（`admits_form`）で、List.sortの順序の型の条件は改名・置換で保たれる |
| 外部3 | `external_assumptions`（群Aの `ExternalModel.external_assumptions`） |
| 応答4 | `response_assumptions`（`pure_rows` の361行、`io_rows` の10行、`response_classes` でIO応答を持つ行を10行に限る） |
| sig_scoped | `sig_scoped`（全377行の `PrimSig.Scoped`。族ごとの署名の形成と、範囲付きの行・IOの行はModelTargets・ModelHttpの既存の形成の補題） |
| sat_unconstrained・admits_sat | `ModelConstraints.sat_unconstrained`・`admits_sat` |
| release_exists | `release_exists`（群Eの `release_all`） |
| pathBases_shape・io_op・opEff_io・effect_ops・state_effect | `pathBases_shape`・`io_op`（10行ごとの効果の所属）・`opEff_io`・`effect_ops`・`state_effect` |
| ref_get・ref_set・store_shape・store_admits | 群E・F1の `ref_get`・`ref_set`・`store_shape` と `store_admits` |
| TargetAgreement | `target_agreement`（`io_rows` の対象の条件） |

`program_typed externals hw` と `program_wellFormed externals hw`（`Program.WellFormed`：全定義の `Def.Scoped`、全構成子のarityの一意性と `ConDecl.Scoped`、操作・クラス・実装・変性の情報が空であること、`hw`）を同じ表で示した。全定義の適格性は、型付け（注釈・種類）と本体の形成 `BodyScoped`（依存列の行と範囲の上限、本体の深さ）から `Def.scoped_of_typed` で得る。`body_scoped` は全130本体を元の本体の族ごとの補題（任意の関数参照名の写像ρについて量化）で閉じる。`cons_scoped` はarityの一意性を合成プログラムの宣言表の有限の判定で、欄の注釈と種類を `variance_valid` で、欄の行と範囲を `field_rows` で示す。`VarianceValid` は `variance_valid`（dataInfoは空、全構成子の欄の注釈・種類・既定の変性）が供給する。

### 欄の四分類（[conditions.json](conditions.json)、台本 [conditions.py](conditions.py)）

前提の否定で閉じる欄（空疎）は0。結論が入力を読まない欄（自明）は2（`external_exists`：定数のerr、`sat_unconstrained`：空の制約の判定が定義で真）。前提を満たす入力の証人を合成表の上で確認した欄（実質）は12（delta_typed は群F1の `numeric_inputs`・`operator_inputs`、sig_scoped・pathBases_shape・io_op・opEff_io・store_shape・store_admits は `row_lookup` の行、effect_ops は `effects_member`、release_exists は `resource_input`、前提のない state_effect・ref_get・ref_set）。証人を合成表の上で示していない欄は保留15（置換8、external_typed・external_no_targets、admits_sat、io_typed・io_kind・io_exists・io_target）であり、実質に数えない。行の契約は、群F2が接続した純粋な86行（79＋範囲付き6＋%List.getFront）とIOと終了の10行の全96行が保留である（契約は全 `BuiltinArgs` で示したが、前提を満たす入力の証人を示していない）。state_effect・ref_get・ref_set の三欄の分類はL50で受け入れた分類に従う。RV-L60.f2 中2 は自明とする読みを示し、群GのL60.32の照合へ論点として渡す。全欄の四分類の照合は群Gの単位が行う。

### tablesの四照合（[tables-check.json](tables-check.json)、台本 [tables_check.py](tables_check.py)）

群Aの台帳（640行）に群F1の差分（[ledger-diff.json](../f1/ledger-diff.json)）と群F2の差分（[ledger-diff.json](ledger-diff.json)、台本 [ledger_diff.py](ledger_diff.py)）を重ねた最終の台帳で照合した。

1. 全既存証拠→合成行：E01〜E15の出典行は552（E01 328、E02 73、E03 34、E04 2、E05 6、E06 7、E07 3、E08 15、E09 7、E10 1、E11 7、E12 9、E13 11、E14 1、E15 48）で表の件数と一致。台帳の行への対応なし0、仮定行への対応0、群F1・F2の差分が定理へ対応させたlookupを持たない出典行0。三モデルの75欄は群Eの条件の記録（既存75）の同じ欄へ全件対応し、読者を持つ。
2. 仮定側の行に証拠名がない：仮定行150の全てで証拠の完全名・出典行・名前の対応が空。独立に、仮定行のLean名・Rust名と同じ名前を持つ552出典行は0件、合成表の行の名前・本体のキーと一致する仮定行の名前は0件。全仮定行が理由を持つ。
3. 台帳の合成行↔合成表のlookup：合成行490の全てがlookupを持ち（計508）、lookupの全てが合成表の行・本体・資源名にある。合成表の377行・130本体・資源名File.Handleの全てに合成行がある。
4. Rust登録→台帳：61部分523参照の全てが台帳の行へ対応する（合成373・仮定150）。

照合は名前と台帳の対応の照合である。同じ署名・δ・本体・応答であることはLeanの `builtins_lookup_iff`・`row_lookup`・`body_lookup`・`lookup_body` と、各行の契約・本体の型付けの定理が示す。

### 仮定側の全名前と理由（[assumptions.json](assumptions.json)）

最終の台帳の仮定側は150行（δ 80、IO応答 47、通常資源の状態 16、形式化の外 7、専用の遷移 0）。各行の名前・Rust名・種類・理由を全件記録した。理由は群Aの台帳の理由を継承し、群F1の訂正（L518 Process.exit を専用の遷移からIO応答の仮定へ改めた `corrected`）を重ねる（E01〜E15に同名の実算法・状態の対応証拠がなく、δ・IO応答又は通常解放が既存の条件で量化される）。群F2は %List.getFront を仮定側から合成側へ移した（下の「台帳の差分」）。仮定側の名前はR50へ渡す。

### 台帳の差分（[ledger-diff.json](ledger-diff.json)）

- 移した行1：L489 %List.getFront（仮定→合成、`StandardModel.Primitive.p377`、署名 `StandardSafe.frontSig`、証拠 `StandardSafe.front_response`・`PureRow.front`・`scope_rows`・`row_lookup`）。安全な入口と精密なgetterの本体（E11・E12）が参照する内部の組込みであり、既存の応答の証拠を持つ。群Aの台帳はE01〜E15の出典行に名前がないことから仮定側へ置いていた。
- 接続した対応233：L60.26 79（純粋な行）、L60.27 130（本体）、L60.28 24（範囲付き7・IO 10・参照と明示遅延5・発行1・資源名1）。群F1の275と合わせて、合成表の子キー508（本体130・組込みの署名377・資源名1）の全てが定理へ対応する。
- 宣言の追加1：`StandardModel.byteOrder`（ByteOrder.BigEndian・LittleEndian）。Bytes.readUnsignedなどの引数の型が読むデータ宣言であり、子キーに数えない。

## 足した宣言と変えた既存のモジュール

新しいモジュール12（既定importの順）：`StandardModelCollectionRows`（純粋な79行・宣言表・変性）、`StandardModelListBodies`（Listのmap/filterと補助の本体）、`StandardModelCoreBodies`（通常core・getter・別名・Pairの射影の本体）、`StandardModelSafeBodies`（安全な入口と精密なgetterの本体）、`StandardModelCollectionBodies`（Map/Setのmap/filterの本体）、`StandardModelProgram`（全130本体と `program_typed`）、`StandardModelIORows`（IOと終了の10行・範囲付きの7行）、`StandardModelSubstitution`（制約と許容の八つの保存則）、`StandardModelCoreRows`（種類ごとの行の分類と応答・効果・対象の条件）、`StandardModelScoped`（全377行の署名の形成）、`StandardModelCore`（全28欄と対象の条件）、`StandardModelWellFormed`（格納された宣言の適格性）。全宣言の一覧・署名・依存は監査の記録（`declarations-*.json`、[added-declarations.json](added-declarations.json)）にある。公開した入口の読者は [readers.json](readers.json)。

既存のモジュールの変更（台本 [verify.py](verify.py) が変更の範囲を開始版と照合する）：

| モジュール | 変更 |
|---|---|
| StandardModelSignatures | `constructorNames` を足し、精密な写像・集合と写像の値の置き換えの出典の δ が合成プログラムの全構成子の並びを読むようにした。内部の組込み %List.getFront の行 `Primitive.p377`（出典 `StandardSafe.builtins`、署名 `StandardSafe.frontSig`、二分探索木への挿入）を足した（台本 [front_row.py](front_row.py)） |
| StandardModelPrimitiveLookup | p377のlookup |
| StandardModelDeclarations | `byteOrder` を足し、`declarations` に含めた |
| StandardModelPureRows | 丸めの宣言の補題の展開の一覧に `byteOrder` を足した（証明の追随） |
| StandardAliasBodies | `body_typed_of`（Optionのarityを前提に取る）を足し、`body_typed` をその適用にした。読者の無くなった非公開の `P` を除いた |
| StandardOrdinaryListBodies | `Inputs` の構成子の欄を `ListOptionDeclarations P`（Optionの二構成子とarity）に置き換えた |
| StandardOrdinaryCoreBodies | `Records P`・`Records.of_table`・`getter_typed_of`・`getter_reference_of`・`projection_typed_of` を足し、`getter_typed`・`projection_typed` をその適用にした。読者の無くなった `getter_reference` を除いた |
| StandardOrdinaryCoreProgram | `keyParam`・`pair` を公開し、`reference_of`・`primitive_of`・`Context P B ρ`・`body_typed_of`・`pair_typed_of` を足した。`body_typed`・`pair_typed` を固定の表への適用にした |

## 既定ビルドと公理

- 最後の既定ビルド：`formal/` から順番の錠の下で既定の対象の `lake build`、2026-11-05T20:01:03〜20:01:36（RV-L60.f2の処置の後）、終了0、1327ジョブ（[default-build.json](default-build.json)、生の出力 45,851バイト、SHA-256 `ddcf6f024df0e952f84624db6f588fbfbef2225bac5363eccf807e1296833696`）。新しいモジュールと変えたモジュールの警告0。
- 公理監査：順番の錠の下で [axioms.lean](axioms.lean) を `lake env lean -M 12288` で実行、20:01:36〜20:02:25、終了0（[axioms.json](axioms.json)、生の出力 26,447,766バイト、SHA-256 `640eb5887b9c13b7e3523d0c1fde0dc14f628ac1492f7a0e7bbe906b5e0c88d6`）。既定importの閉包1066モジュールの全プロジェクト宣言85,207件（非公開・生成宣言を含む。対象の一覧 5,699,653バイト、SHA-256 `d216d7c270c8b73ab4c7d0e7b1c2be87c3bb247b7aca689fbd1547784b7f477f`）を、所属モジュールから固定点（2巡）で列挙した。公理の組は none 39,943、propext 19,744、Classical.choice＋Quot.sound＋propext 21,607、Quot.sound＋propext 3,900、Quot.sound 9、Classical.choice 2、Classical.choice＋propext 2。許可した三公理の外は0、sorryAx 0、新しい公理0。
- 新しい12モジュールの宣言1149（非公開827、生成554）。全件の署名の型のハッシュと、今回の宣言への依存（全依存は個数とハッシュ）を [audit-summary.json](audit-summary.json) が指す declarations-01〜12.json に置いた（生成宣言の型は大きさとハッシュだけ）。対象の一覧は [inventory.py](inventory.py) と [audit.py](audit.py) で作り直せる。
- 公開した入口143のうち、名前付きの読者を持つもの139、既定ビルドの適用例で読むもの5（重なりを含む。[readers.json](readers.json)）。

## 計画からのずれ

| # | ずれ | 理由と影響 |
|---|---|---|
| 1 | 合成表に %List.getFront の行を足し、台帳のL489を仮定から合成へ移した | E11の安全な入口とE12の精密なgetterの本体が呼ぶ内部の組込みであり、合成表にlookupがないとこれらの本体を合成表で型付けできない。既存の応答の証拠（`StandardSafe.front_response`）がある。依頼の指定より必要な範囲が広い場合の拡張に当たる。四照合の2（仮定側の名前に合成表のlookupがない）もこの移動で成り立つ |
| 2 | 合成プログラムに ByteOrder の宣言を足した | Bytes.readUnsigned・readSigned・fromUnsigned・fromSigned の署名の引数の型が読むデータ宣言で、合成プログラムに宣言がなく、署名の形成（`sig_scoped`）と応答の宣言の条件が閉じなかった。データ宣言の追加であり、子キーと応答の行数は変わらない |
| 3 | 精密な写像・集合と %Map.replaceValues の出典のδが読む構成子の並びを、合成プログラムの全構成子（`constructorNames`）にした | 写像・集合の鍵の符号化が読む構成子の並びを合成プログラムの宣言表と一致させるため。`StandardKeyTyping.Table` の照合（鍵の宣言表の要約・`sat_eq`）が同じ表の上で成り立つ。署名・名前・kindは変えていない |
| 4 | 元の固定のP/Bの証明を前提付きの形へ一般化し（`_of` の定理、`Records`・`Context`・`Inputs` の欄の置き換え）、`keyParam`・`pair` を公開した | 元の証明の構成を合成表で使うため。元の定理は元の表への適用として残し、元の読者は変えていない |
| 5 | `getter_reference` を除いた | 一般化の後に読者が無くなった。後段の固定の署名の一覧（l40・l50のstage-results）にない |
| 6 | 群Aで固定した `definition_typed` と `core` の完全署名から、使わない前提 `hw : ExternalWF` を除いた | 型付けと28欄は外部宣言の構造検証を読まない。依頼の「使わない前提を除くだけの変更」に当たる。元の署名の形で使えることを既定ビルドの適用例で示した（StandardModelCore と StandardModelWellFormed の `example`）。`program_typed`・`program_wellFormed` は `hw` を `external` の欄に使うので残した |
| 7 | L60.27の完了の時点の途中の結果と残りの見込みを、その時点で本書へ書かなかった | 既定ビルドは.27の完了で終了0だった（18:05）。本書への記入はL60.29の作業中になった |
| 8 | 既定ビルドを一度、順番の錠（lockf）なしで起動した（17:45ごろ）。また一度、錠の下で対象を指定して `lake build Benitoite.Release.Refinement.StandardModelCoreBodies` を起動した（18:5x） | 手順の誤り。並行の検査と重なった記録はない。最後の既定ビルドと公理監査は錠の下で既定の対象で実行した |
| 9 | 新しいモジュールの `set_option maxHeartbeats`・`maxRecDepth` は、各行を外した写しを単独のLeanで検査し、外しても通るものを除いた | 残したのは、外すと時間切れになる5箇所（StandardModelCoreBodies 1、StandardModelListBodies 1、StandardModelCollectionBodies 2、StandardModelCoreRows 1）。安全な入口・精密なコレクションの写しは元のモジュールの設定を写していたが、外して通る行を除いた |
| 10 | 行の名前の比較を `simp [Primitive.name]` から `decide` へ改めた（StandardModelIORows・StandardModelCoreRows） | `simp` が377行の名前の照合の等式の補題を非公開の生成宣言として作り、監査の記録が大きくなったため。証明の結論は変わらない |
| 11 | 行の契約の前提を満たす入力の証人（純粋な86行・IOと終了の10行）と、15欄の入力の証人を示していない | 保留として記録し、実質に数えない。群Gの四分類の照合（.32）へ渡す |

## 担当の義務と受け口の判定

detailの第5節・第6節で、L60.26〜.29を名指す行（他段受持の行を除く）を一行ずつ判定した。「本群の分は完了」は、L60.26〜.29の分の証拠が既定ビルドにあり、行が名指す後段の分が残ることを表す。

| 行 | 判定 | 証拠と残り |
|---|---|---|
| H03 | 本群の分は完了 | 範囲付きの6行のδはScopeResponseの同じδで、`PureRow.scope` が `ScopeResponse.response` を読む。normal_factsの全実行はL70 |
| H04 | 本群の分は完了 | `IORow.scoped` が `ScopedIOResponse.response` の同じ要求・内容型・reqTarget・endpoint・σを合成表で読む。全位置の到達はL70、実装はR30/R50 |
| H06 | 本群の分は完了 | 全377行の `PrimSig.Scoped`（`sig_scoped`）と全130本体の `SourceScoped`（`body_scoped`）を合成表で供給。ソース生成はL70/R10b |
| H09 | 完了 | `substitution_assumptions` は合成表の制約を `ModelConstraints.sat`、許容を `ModelConstraints.admits`（List.sortの行は順序の型の条件を追加）で読み、値の四保存を再利用した。順序・長さ・重複を読む条件は足していない |
| H10 | 完了 | 同じ `substitution_assumptions` で型の改名・置換の四保存を再利用した。独立のsat_localはない |
| H12 | 本群の分は完了 | `io_op` は10行の署名の形（範囲付きの行の `Scope.PathIn`・`Http.RequestIn` の範囲）と効果の所属を同じ署名で示す。scopedの署名へ変えていない |
| H13 | 完了 | `http_declarations`・`core_arity`・`cons_scoped` がResult・Pairのarity2・要求・誤りの宣言と全構成子のarityを合成プログラムで示し、`body_lookup`・`lookup_body` が全lookupを対応させる。旧Scopedを流用していない |
| H16 | 本群の分は完了 | 範囲付きの行・IOの行の応答は合成表の同じ分類（群Aの合成表の定義）で読む。R30は実装側 |
| H19 | 本群の分は完了 | 範囲付きの行の対象3sortの観測・所属は `ScopeResponse.response` の同じδの結論を使う。R50への二つのlength観測の申し送りは群Gへ |
| H24 | 本群の分は完了 | 局所の証拠（各行の契約・各本体の型付け）と全体（`core`・`targets`・`program_typed`・`program_wellFormed`）を別の定理として置いた。O144の分類は群G |
| H25 | 完了 | `StandardModel.table externals` が合成プログラムの同じ有限宣言・要約・`satB` の一致を供給し、写像・集合の鍵の符号化が同じ構成子の並びを読む。ソース合成と全比較はL70/R10b/R50 |
| H29 | 完了 | 範囲付きのファイル6本とHttp.sendInは合成表のIO応答（`io_rows`）で、外部応答は `external_assumptions` の別の関係で読む |
| S01 | 本群の分は完了 | H06と同じ |
| S02 | 本群の分は完了 | 制約の判定は合成プログラムの宣言の要約を読む骨格で、小さい sat=True の例を証拠にしていない。旧Assumptionsの成功を使っていない |
| S03 | 本群の分は完了 | 各行の契約は既存の実応答の補題の結論を使い、PreparedLeafを再定義していない |
| S04 | 群Gへ | 本群は型付け・応答の存在を示した。算法の一致（machine_exact等）は型付けから推測していない。O022/O034の照合は.30 |
| S05 | 完了 | 28+1の新表（`core`・`targets`）を構成した。release_existsは `release_exists`（群Eの `release_all`） |
| S06 | 本群の分は完了 | 合成表の参照と明示遅延の5行の型引数の種類 `[value]` は群E・F1の `reference_rows`・`store_shape` を同じ表で読む。処理系の実四署名との照合は群F1の `store-signatures.json` |
| S15 | 完了 | 応答の条件は `BuiltinArgs` の正規形の量化をそのまま使い、Canonicalを外していない |
| S16 | 完了 | `opEff_io` と `effect_ops` が合成表の操作の効果を持つ全署名の種類をio・exit・pathBasesに限り、効果の表の所属と一致させる |
| S17 | 本群の分は完了 | 全標準の残りの署名の形成を `sig_scoped` で本番に置いた。ExternalSignature.WFの既存欄は変えていない |
| S18 | 完了 | 本体の型付けと署名の形成は合成プログラムのResult・Pair等のarity・kindを読む（`core_arity`・`http_declarations`） |
| S19 | 群Gへ | 本群のL60.26の行は既存の応答の補題をそのまま使い、閉包の二表現を区別する行の照合とR50への差の申し送りは.33 |
| S21 | 完了 | 新しいモジュールの全てで任意のP/Bの応答の補題を使い、`table_response` を使っていない（verify.pyが照合）。固定Pの証拠の無条件の移植は0 |
| S22 | 本群の分は完了 | 演算子と構造の等号は群F1の行を `pure_rows` で同じ表へ合成した。decoderの再証明はしていない |
| O013 | 本群の分は完了 | 12欄と同じP/Bの対象条件を `targets`、ShapeOkを `io_op` で全Coreへ。全体照合はL70/R50/V10 |
| O015 | 本群の分は完了 | 範囲付きの行の対象3sortの実応答を合成表へ。新しい論理規則はない |
| O022 | 本群の分は完了 | 同じout・toTerm?からの結論を既存の応答の補題から合成表へ接続した。R50/V10の照合は残る |
| O034 | 本群の分は完了 | 同じ値の表現・観測・所属を既存の応答の補題の結論のまま合成表へ置いた |
| O035 | 本群の分は完了 | Http.sendIn と要求の範囲付きの3行を同じ要求・endpoint・groundVal・valContentで合成表へ |
| O038 | 本群の分は完了 | 通常解放は群Eの `release_all` を合成表で、外部応答は `external_assumptions` で読む。L70の全保存は残る |
| O048 | 本群の分は完了 | Http.widenRequestIn を `ScopeResponse.response` で合成表へ。旧 eq_of_not_fn へ戻していない |
| O049 | 本群の分は完了 | 保持要求の同じreqTarget・内容型を `IORow.scoped` で合成表へ。既存の葉の再証明はない |
| O057 | 本群の分は完了 | 合成表の任意の型付き資源値の解放の応答の存在（`release_exists`）と外部応答の存在（`external_exists`）を `core` に置いた。L70 progressは残る |
| O058 | 本群の分は完了 | 置換・格納の保存則（`substitution_assumptions`）と解放の条件を合成表へ。L70 preservationは残る |
| O060 | 本群の分は完了 | `effect_ops`・`state_effect`（State の所属は空）を合成表の全effectsで示し、IOへ変換していない |
| O061 | 完了 | `external_no_targets` を `core` に、`io_target` を別の `targets` に置いた |
| O062 | 本群の分は完了 | 合成対象の純粋な全361行の同じδの全 `BuiltinArgs` での型付き非exitの応答（`pure_rows`）。仮定側は名前と理由を [assumptions.json](assumptions.json) に記録。R50の算法比較は残る |
| O063 | 本群の分は完了 | IO7行と print・exit・File.readText の全入力の応答（`io_rows`）と、外部三条件を別の欄に置いた。正常応答の存在は要求していない |
| O065 | 本群の分は完了 | 全署名の形成（sourceTelRows を含む `sig_scoped`）・操作の種類（`opEff_io`）・arity（`cons_scoped`）・StoreShape（`store_shape`）と仮定側の台帳。L70の切替は残る |
| O157 | 本群の分は完了 | 01-12と07-04の写しへ、合成表の純粋な全行・IO・本体・28+1欄・WellTyped/WellFormedの記述を同じ変更で加えた（[design_copies.py](design_copies.py)）。未実施の全比較を成功と書いていない |

## 申し送り

- 群G（.30〜.33）：28+1欄の保留15と行の契約の保留96の、前提を満たす入力の証人と四分類の照合（[conditions.json](conditions.json)）。S04・S19の照合。仮定側150行の名前と理由（[assumptions.json](assumptions.json)）をR50へ渡す一覧の確認。
- L70：利用者Pへの収集と全プログラムの切替。`program_typed`・`program_wellFormed`・`core`・`targets` は合成プログラム `StandardModel.program externals` についての定理であり、全Rust登録の意味の証明ではない。
- R50：仮定側150名の実登録との対応と、%List.getFront の合成側への移動（台帳のL489）の確認。

## 取りまとめに判断を求める点

1. 28+1欄の保留15（置換8・external_typed・external_no_targets・admits_sat・io_typed・io_kind・io_exists・io_target）と、行の契約の保留96（純粋な86行・IOと終了の10行）。いずれも契約は全場合で証明したが、合成表の上で前提を満たす入力の証人を示していない。群G（.32）で証人を足すか、保留のまま後段へ渡すか。
2. %List.getFront を仮定側から合成側へ移したこと（台帳のL489、計画からのずれの1）。E01〜E15の出典行の外の名前を、E11・E12の本体の参照先として合成表へ加えた。
3. 合成プログラムへのByteOrderの宣言の追加と、精密な写像・集合の出典のδが合成プログラムの全構成子の並びを読むようにした変更（ずれの2・3）。
4. 群Aで固定した `definition_typed` と `core` の完全署名から、使わない前提 `hw` を除いたこと（ずれの6）。元の署名の形での適用例を既定ビルドに置いた。
5. 既存のモジュールの一般化と `getter_reference` の削除（ずれの4・5）。
6. 手順のずれ：錠なしの既定ビルド1回と対象を指定したビルド1回、.27の途中の記録の遅れ（ずれの7・8）。

## 完了の照合

- 完了した単位：L60.26・.27・.28・.29。止める条件（主な10言明の形・新しい公理・独立の信頼条件・書ける形の制限・提供範囲の削減・精密な外部状態・型付けの規則・U02依存の公開形）に当たる変更はない。Pを外部宣言のないものに制限していない（`core`・`body_typed`・`program_typed`・`program_wellFormed` は任意の `externals` で量化）。既存証拠の合成を仮定側へ移して済ませた行は0。
- 全場合の量化：純粋な行は `pure_rows` が種類pureの全行、IOは `io_rows` が種類io・exitの全行、本体は `body_typed`・`body_scoped` が `Body` の全130構成子、構成子は `cons_scoped` が全lookup、28+1欄は構造体の全欄を、それぞれ全入力で量化する。
- 記録の照合：[verify.py](verify.py) が終了0（[verification.json](verification.json)）。変更の範囲（追加は本書のディレクトリと新しい12モジュール、変更は既定import・写し2・既存8モジュール）、写しの置換の組、既定importの全新モジュール、監査の範囲と公理、読者、130本体と79・10・7行の振り分けの網羅、`table_response` の不使用、台帳の差分と四照合の再実行の一致、条件の記録、記録の大きさ（各100 KB以下、全体約1.5 MB）、手元の絶対パスとdocs/todoへのリンクの不在を照合した。
- 生の出力（既定ビルドと監査のログ、対象の一覧）は一時領域に置き、本書の記録には大きさとSHA-256だけを残した。

## RV-L60.f2 の処置

取りまとめの指示（2026-11-05、19:59に受領）に従い、[RV-L60.f2](../../reviews/RV-L60.f2.md) の所見を処置した。

| 所見 | 処置 |
|---|---|
| 中1 | 直した。[tables_check.py](tables_check.py) の最終台帳の構成に、群F1の [ledger-diff.json](../f1/ledger-diff.json) の `corrected`（L518 Process.exit）を重ねた。[assumptions.json](assumptions.json) のL518の種類をIO応答、詳細と理由を群F1の訂正の理由にし、種類ごとの件数をδ 80・IO応答 47・通常資源の状態 16・形式化の外 7・専用の遷移 0へ直した。本書の内訳も同じに直した。前の群の記録は変えていない。四照合の件数は変わらない |
| 中2 | 直さない。state_effect・ref_get・ref_set を実質に数える判定は、L50で受け入れた分類とplanの群Eの取りまとめの判断に従う。四分類の節に、群GのL60.32の照合へ論点として渡す一文を足した |
| 軽1 | 直した。StandardModelProgram の `example` の説明を、空の外部宣言表の例であることに合わせた |
| 軽2 | 直した。StandardModelSafeBodies の `annotation_17`・`annotation_18`（言明と証明が `annotation_01`・`annotation_03` と同じ）と、`declarations_annotation` の到達しない二つの候補を除いた |
| 情報1・2 | 処置なし |

検査（いずれも一度ずつ）：
- 既定ビルド：順番の錠の下で既定の対象、2026-11-05T20:01:03〜20:01:36、終了0、1327ジョブ。新しいモジュールと変えたモジュールの警告0。
- 公理監査：順番の錠の下、20:01:36〜20:02:25、終了0。対象85,207件、許可した三公理の外0、sorryAx 0。新しい12モジュールの宣言1149。
- verify.py：20:02:52、終了0。変更の範囲の照合では、取りまとめが置いたレビューの記録（reviews/RV-L60.f2.md）を担当の変更の外として扱う一行を足した。

## 群 F2 の作業末の work の検査（取りまとめ）

- 基準: `25ea27a0f15bd9010e302bde340c7f1cd767319b`（HEAD と一致）。作業木は RV-L60.f2 の処置の後の未コミットの状態（worktree）。
- 事前に `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消した。
- コマンド: `scripts/check.sh --level work --base 25ea27a0f15bd9010e302bde340c7f1cd767319b`（`/usr/bin/time -l` で測定）。選ばれた検査は spec_tally・spec_examples・formal_build。
- 終了状態 0（selected checks passed）。外側の時間 877.69秒（20:03:36〜20:18:14）、最大常駐量 4,220,420,096 バイト。群 F1 の630.68秒より長いのは、群 F2 で足した12モジュールの再ビルドの分である。
- 生の記録は `<tmp>` に置いた（6,624 バイト、SHA-256 `2b9ff29700c9a776b2470c8c61f95be212d9b8e30214df2638a532f3605ddd2d`）。
- 計画からのずれ: なし。
