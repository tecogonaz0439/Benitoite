# L60 群 G の実装記録

基準 B_WORK: `d76269707008268af63e0149e638804d448a6c70`。指定ブランチ `m014/l60.g`。git の書き込み操作と scripts/check.sh の実行は行っていない。開始版との比較は読み取りだけのgitの照会（ls-tree・show・diff・check-ignore）で行う。共通依頼文と2026-10-30の勧告照合・組み込まない判断、J60-1=B・J60-2=F06・J60-3=(a)、群A〜F2の実署名と台帳を継承した。群A〜F2の記録とplan・detail・tables・README・レビューの記録は変えていない。

## 単位の時刻

依頼文・共通依頼文・detail・群F2の記録とRV-L60.f2・本番の該当モジュールの読解は2026-11-05T20:20:09+09:00に始めた。読解の中で、L60.32の不確かな接続（範囲付きのIOの行・外部宣言を持つ合成プログラム・制約の判定）を短い入力で確かめた（20:24〜20:29、`<tmp>` の入力だけ）。

| 単位 | 開始（JST） | 終了（JST） | 所要 | 判定 |
|---|---|---|---:|---|
| L60.30 | 2026-11-05T20:29:54+09:00 | 2026-11-05T20:33:39+09:00 | 3分45秒 | 義務27行の証拠と判定を台本に置いた。最後の閉包で照合（下の「群末」） |
| L60.31 | 2026-11-05T20:33:39+09:00 | 2026-11-05T20:35:00+09:00 | 1分21秒 | 申し送り59行の証拠と読者を置き、読者の型と値の閉包で照合した |
| L60.32 | 2026-11-05T20:35:00+09:00 | 2026-11-05T21:10:00+09:00 | 35分00秒 | 保留15欄と行の契約96行の入力の証人を本番に置き、四分類を照合した |
| L60.33 | 2026-11-05T21:10:00+09:00 | 2026-11-05T21:14:00+09:00 | 4分00秒 | 二つの除外の理由の境界と後段の契約、07-04の写し |
| 群末の検査と記録 | 2026-11-05T21:14:00+09:00 | 2026-11-05T21:22:00+09:00 | 8分00秒 | 既定ビルド・公理監査・閉包・記録の再生成・verify.py・本書 |

読解の開始からの全体は約1時間02分で、見込み3時間05分〜5時間を下回った。L60.30とL60.31の表はL60.32の前に置き、L60.32で足した証人の名前を含めて、最後の状態の閉包で照合し直した。

## L60.30 義務27行（[obligations.md](obligations.md)、[obligations.json](obligations.json)）

台本 [records.py](records.py) が、各行の証拠の完全名が既定環境にあること、完了と判定する行の証拠に定理があることを照合する。閉包は [graph.lean](graph.lean) が既定環境のBenitoiteの全宣言（85,412件）の型と値の定数を書き出したものから作る（生の出力 114,693,759バイト、SHA-256 `307612365a96cd2326453fc4313aa1c1e5697c1f656c5a28bf5f2e3f3182c22d`）。

| 分類 | 行 | 判定 |
|---|---:|---|
| 技術 | 21 | 全21行がL60の分は完了。残る所有は各行の右列（L70/R30/R50/V10/K10） |
| 記録 | 1 | O157：群Gの分は完了（07-04の外部除外の境界の写し）。.34は群H |
| 共通 | 4 | O016・O027：群Gの分なし（群Hの.35〜.37）。O084：群Gの分は完了（停止条件に当たる変更0）、.36は群H。O118：群Gの分は完了（本番と写しに工程IDなし、verify.pyで照合）、.34/.36は群H |
| 他段 | 1 | O144：他段（L60の所有なし）。証拠を合成に使うだけで、新しい理論・CLIの所有を足していない。誤移管0 |

定義があるだけの行は完了にしていない。完了の各行は定理の証拠を持つ（台本が種類を照合）。O022は群F2の時点で合成表の正常応答の篩の事実の読者がなかったので、`StandardModel.normal_facts` を本番に足した。O062・O063は、群F1・F2の契約に加え、群Gの前提を満たす入力の定理（`collection_inputs`・`scope_inputs`・`io_inputs`）を証拠に含める。

## L60.31 申し送り59行（[handoffs.md](handoffs.md)、[handoffs.json](handoffs.json)）

読者の型又は値の定数の閉包に証拠が含まれることを、行ごとの経路で照合した（handoffs.json の `dependencies`）。

| 分類 | 行 | 状態 |
|---|---:|---|
| L60受持 | 41 | 読者あり33。未使用（後段の読者）3（H02・S04・S05：名前付きの読者はL70/R50）。記録で照合4（S19 function-values.json、S21 table_responseの閉包、S26 本記録、S27 conditions.json）。群Hの単位1（S07） |
| 既済み継承 | 4 | S11は読者あり（`step_external_apply`）。H17・H18・S10は再実装せず、L60の新しい読者なし |
| 他段受持 | 14 | 送り先を保持。L60の読者なし |

読者を持つ行のうち、一部の証拠だけを読者が読む行は「読者のない証拠」の欄に書いた（S06の `reference_rows`、S13の `ExternalCarrier.accepted`、S15の `BuiltinArgs.normalized`）。S21は、名前が `StandardModel` で始まるモジュールの全4,023宣言のどれも型・値で `table_response` に依存しないことを閉包で照合した。

最初の案で挙げた読者のうち11行（H02・H06・H09・H13・H14・H31・S02・S06・S13・S15・S18）は、閉包で依存が成立しなかった。読者又は証拠の名前を実際の依存の経路に合わせて直した（S26の照合の観点）。

## L60.32 四分類（[cases.md](cases.md)、[conditions.json](conditions.json)、台本 [conditions.py](conditions.py)）

### 足した入力の定理

新しいモジュール3つを既定importに加えた。

| モジュール | 主な定理 | 方法 |
|---|---|---|
| StandardModelCollectionInputs | `collection_inputs`（79行）と族ごとの `PureRow.Satisfiable.string`・`bytesOrdinary`・`bytes`・`list`・`listRemaining`・`range`・`map`・`set`・`headTail`・`precision`・`append`・`replaceValues`、`front` | 具体化した依存列が `Ty.toTel` の形になる署名は、型付きの値の列から `BuiltinArgs` を組み立てる（`arguments_of_toTel`）。型引数はInteger、値は基本型の定数・空の列・バイト列・写像・集合（`inhabitant`）。結果型が引数の値を読む8行は、全署名の形成（`sig_scoped`）と型の具体化（`Tel.annotation_substAt`）から依存列の注釈を得て（`instance_annotation`）、引数の値を一つずつ束縛する（`one_argument`・`two_arguments`、`Tel.annotation_open`）。%Map.replaceValuesの第二引数は篩付きの列で、空の写像と空の列で長さの等式を評価する |
| StandardModelIOInputs | `scope_inputs`（範囲付きの6行と %List.getFront）、`io_inputs`（IOと終了の10行）、`IORow.Satisfiable` | 全体を許す範囲 `.absolute .top` の下で保持したパス（`heldPath`）と、ループバックの端点への要求（`heldRequest`）。範囲付きの効果の印は具体化した範囲へ写す。print・exit・File.readTextは基本型の定数 |
| StandardModelConditionInputs | `substitution_inputs`・`admits_sat_input`・`positive_inputs`・`io_field_inputs`・`normal_facts` | 置換の八欄はIntegerと鍵の制約を持つ型変数（`keyContext`）・恒等の改名・Integerへの具体化・Map.getの行。外部応答の二欄は外部関数 `0 < self` を一つ持つ外部宣言の表（`positiveExternals`）と正常値1の生応答。IOの四欄と対象の条件はFile.readTextInの行と、合成表のIO応答の存在から選んだ応答 |

大きな具体値の評価はしていない。証人の値は定数・空の値・一つの要求であり、%Map.replaceValuesの篩の評価だけを `rfl` で閉じた。`collection_inputs` は外部宣言の表の構造検証 `ExternalWF` を前提に取る。依存の結果型を持つ署名の注釈を `program_wellFormed`・`program_typed` から得るためであり、契約や欄の前提を変える仮定ではない。外部応答の二欄の証人は具体の外部宣言の表で示す（空の外部宣言の表では関数のlookupの前提が成り立たないため）。

### 正常と対照の証拠

- 置換の欄とadmits_sat：結論は型引数の制約の判定を読む。Floatは鍵の制約を満たさない（`admits_sat_input` の第二成分）。
- 外部応答の二欄：正常値1の生応答が関係に属し、同じ入力でerrの応答も属する（`positive_inputs`）。正常値には合成表の `external_typed` がcarrierを返す。
- IOの欄：IO応答は正常応答の存在を要求しないので、存在の欄の応答は関係の存在から選ぶ。

### 判定

最終の判定は、RV-L60.g の処置で、前提のない三欄（合成表3欄・三モデル9欄）と三モデルの `sat_unconstrained` 3欄を第2.4節の定義に従い自明に数えた後のものである（2026-11-05の設計者の決定）。

| 母集団 | 最終の判定 | 初回の報告の判定 | detail.mdの目標 | 目標との差 |
|---|---|---|---|---|
| 合成表の29欄 | 実質24・自明5（external_exists・sat_unconstrained・state_effect・ref_get・ref_set） | 実質27・自明2 | （なし） | — |
| 三モデルの新12欄 | 実質7・自明3・空疎2 | 同じ | 実質7・自明3・空疎2 | 0 |
| 三モデルの既存75欄 | 実質57・自明12・空疎6 | 実質69・空疎6 | 実質69・空疎6（L50の受け入れ） | 実質−12・自明+12 |
| 三モデルの87欄 | 実質64・自明15・空疎8 | 実質76・自明3・空疎8 | 実質76・自明3・空疎8 | 実質−12・自明+12 |
| 合成表の行の契約96行 | 実質96（純粋86・IO/終了10） | 同じ | （なし） | — |

目標との差の12欄は、三モデルの state_effect・ref_get・ref_set の9欄と sat_unconstrained の3欄である。証明は変わらず、分類の基準を第2.4節の定義に揃えた差である（conditions.json の `model_reclassified`・`difference_from_target`）。

保留15欄（置換8・external_typed・external_no_targets・admits_sat・io_typed・io_kind・io_exists・io_target）は、合成表の上で前提を満たす正常な入力を示し、結論が入力の型・形又は応答の証拠を読むので実質と判定した。不成立・空疎へ移った欄はない。行の契約96行も全て実質である。空疎の欄は前提の否定の導出を持つ群Eの8欄だけである。

### RV-L60.f2 中2 の論点（前提のない三欄）

`state_effect`・`ref_get`・`ref_set` は前提を持たず、`state_effect` は表の定義の値（rfl）で、`ref_get`・`ref_set` は固定の署名を証人にして閉じる。第2.4節の定義では、自明は「充足可能な前提に依存せず、定数の証人等で結論が閉じる」、実質は「前提の充足可能な入力があり、入力の型・形又は応答の証拠を使って結論を示す」である。三欄は入力を持たず、入力の証拠を使わないので、実質の定義に当たらず、自明の定義に当たる。同じ記録で自明とした `sat_unconstrained`（空の制約の判定が定義で真）とも判定の基準が揃う。

L50で受け入れた分類（実質）は、「表の内容を読む閉じた命題」を実質に数えた。この読みは表の内容への依存を根拠にするが、第2.4節の実質の条件（入力の証拠を使う）を満たさない。食い違いの理由はこの根拠の違いである。初回の報告では依頼文に従い分類を改めず判断を求めた。2026-11-05に設計者が第2.4節の定義に従い自明に数えると決め、群Gの記録を改めた（「RV-L60.g の処置」）。L50と前の群の記録は書き換えず、`l50/stage-results.md` の末尾に訂正の注記を一つ足した。

## L60.33 外部除外の境界（[boundary.md](boundary.md)、[boundary.json](boundary.json)、台本 [boundary.py](boundary.py)）

理由 `externalType`（区間の比較）と `external function`（脱糖の差分・surfaceCheckAll・網羅性の比較）について、除外を作る書き出し器、比較の台本と読者、除外の単位、現行の設計書の記述、L60の支持の葉、L70の受け口、R50の実の件数を別の欄に置いた。ソースの引用は文字列の出現で、Leanの葉は閉包で照合した。R50の実の件数はまだ数えていないので「未実施」と書き、0件と書いていない。07-04の形式化の範囲の表の「外部の関数と外部の型」の行に、Leanの外部の葉があっても書き出し器と比較の読者はそれを読まず、二つの除外が残ることを写した。

S19（生lambdaとclosureの差）は、無制約の型変数の関数型への具体化と入れ子の値を含めて、関数値が到達しうる合成表の27行を族ごとに台本で照合し（[function_values.py](function_values.py)、[function-values.json](function-values.json)）、値を保存・射影する22行と値の形を調べる5行に分けた。27行はR50の二表現の比較の入力に含める（boundary.md）。初回の報告の、引数の型の文字列の個数から「合成表の行は関数値を受けない」とした完了理由は誤りであり、削った（RV-L60.g 中2）。

## 足した宣言と変えたファイル

- 新しいモジュール3（既定importの順）：`StandardModelCollectionInputs`（114宣言）、`StandardModelIOInputs`（73）、`StandardModelConditionInputs`（18）。計205宣言（非公開66、生成54）。全件の署名の型のハッシュと依存は [audit-summary.json](audit-summary.json) が指す declarations-01〜03.json にある。公開した入口78のうち名前付きの読者を持つもの71、既定ビルドの適用例で読むもの9（重なりを含む。[readers.json](readers.json)）。
- 変えた既存のファイル：`formal/Benitoite.lean`（3行のimport）、`docs/design/01-spec/01-12-core-calculus.md`（入力の定理の段落1）、`docs/design/07-quality/07-04-formal-semantics.md`（モジュールの段落1、対応表の行1、外部の関数と外部の型の行の一文）。置換の組は [design_copies.py](design_copies.py)。既存のLeanのモジュールは変えていない。
- 既存の署名・定義・規則の変更はない。主な10言明・Step・型付けの規則・CoreAssumptions・TargetAgreementを変えていない。

## 既定ビルドと公理

- 既定ビルド：`formal/` から順番の錠の下で既定の対象の `lake build`。新しい3モジュールを含む最初の成功は 21:14:20〜21:14:39（18.44秒、1330ジョブ）。適用例の追加の後の最後の実行は 2026-11-05T21:16:38〜21:16:39、終了0（[default-build.json](default-build.json)、生の出力 45,585バイト、SHA-256 `4866f4e3e5c592a0090ef0d3f5a9426818373aea82bd24a0917d21a618fb6fee`）。新しいモジュールの警告0。
- 公理監査：順番の錠の下で [axioms.lean](axioms.lean) を `lake env lean -M 12288` で実行、21:16:39〜21:17:28、終了0（[axioms.json](axioms.json)、生の出力 18,336,575バイト、SHA-256 `a38b7e789953a26ac8a11e28ee0f37430177d5edaf0e717a3f431bfd1d2dddc9`）。既定importの閉包1069モジュールの全プロジェクト宣言85,412件（非公開・生成宣言を含む。対象の一覧 5,718,450バイト、SHA-256 `4c2247f818e2fbbdd1fdecabe635f75d017f7457cf2efefae3e7991df016c7f6`）を固定点（2巡）で列挙した。公理の組は none 39,973、propext 19,791、Classical.choice＋Quot.sound＋propext 21,735、Quot.sound＋propext 3,900、Quot.sound 9、Classical.choice 2、Classical.choice＋propext 2。許可した三公理の外0、sorryAx 0、新しい公理0。対象の一覧は [inventory.py](inventory.py) と [audit.py](audit.py) で作り直せる。
- 記録の照合：[verify.py](verify.py) が終了0（[verification.json](verification.json)）。変更の範囲、写しの置換の組、既定importの新モジュール、監査の範囲と公理、読者、入力の定理の場合の網羅（79・7・10とF2の `collection_rows` の場合の並び）、records.py・conditions.py・boundary.py の再生成の一致、記録の大きさ（各100 KB以下、全体約0.5 MB）、手元の絶対パスとdocs/todoへのリンクの不在を照合した。
- 生の出力（ビルド・監査・閉包のログ、対象の一覧）は一時領域に置き、本書には大きさとSHA-256だけを残した。RSSは未取得（計画上の非採取）。

## 計画からのずれ

| # | ずれ | 理由と影響 |
|---|---|---|
| 1 | L60.32の不確かな接続を、読解の中で短い入力で確かめた | 範囲付きのIO・外部宣言を持つ合成プログラム・制約の判定の証人が作れるかを最初に確かめるため（共通依頼文の「不確かな接続は最初の1時間で確かめる」）。本番には入れず、L60.32で本番の定理として作り直した |
| 2 | L60.30・L60.31の表を先に置き、L60.32の後に最後の閉包で照合し直した | 義務O022・O062・O063の証拠に、L60.32で足す定理（`normal_facts`・入力の定理）が要るため |
| 3 | `normal_facts` を足した | O022の「同じout/toTerm?からのfacts」の合成表の読者が群F2の時点でなかった。依頼の範囲より必要な範囲が広い場合の拡張に当たる |
| 4 | `collection_inputs` が `ExternalWF` を前提に取る | 依存の結果型を持つ8行の依存列の注釈を、合成プログラムの適格性と型付けから得るため。契約・欄の前提は変えていない |
| 5 | 最初の既定ビルド（21:04）がStringの族の定理で時間切れ（200000 heartbeats）になった | 同じソースの単独のLeanでは通った。証明を補助の5補題へ分けて通した。heartbeatsの上限は変えていない |
| 6 | `IORow.Satisfiable` を `PureRow.Satisfiable` と同じ本体で別に定義した | IOの行の契約の前提も同じlookupとBuiltinArgsであるが、名前を中身（IOの行）に合わせるため |
| 7 | 依存の閉包の書き出し（graph.lean）を群Gの台本に置いた | L50の群Kの同種の台本に倣い、読者の照合を全行で機械化するため |
| 8 | 初回の報告では前提のない三欄の分類を改めなかった | 依頼文の指示（分類を改める必要があると判断したら改めずに報告する）に従った。設計者の決定の後、RV-L60.g の処置で改めた |

## 担当の義務と受け口の判定

detailの第5節・第6節で、L60.30〜.33を名指す行を一行ずつ判定した。

| 行 | 判定 | 証拠と残り |
|---|---|---|
| H24 | 完了 | 局所の証拠と全体（`core`）を別の定理として照合。O144は他段（obligations） |
| O144 | 他段（誤移管0） | L60は既存の証拠を合成に使うだけ。R20/R10b/R40/R50/V10 |
| S04 | 完了（L60の分） | 算法の一致（`PreparedLeaf.machine_exact`）を型付けから推測していない。合成表の主な入口（`core`・`targets`・`program_typed`・`collection_inputs`・`io_inputs`）はこの証拠に型・値で依存しない（閉包で照合）。R50の算法比較 |
| S22 | 完了 | `operator_rows` が二つのresponseを読む（閉包で照合）。decoderの再証明なし |
| S26 | 完了 | 59行の読者を型と値の閉包で照合し、成立しない11行を直した |
| S27 | 完了 | 75欄の69/0/6と12欄の7/3/2を別の列で照合（conditions.json） |
| S28 | 完了 | Targetsの解放は通常資源の関係の接続であり、群Eの `ModelCase.release_all` を `composition` が読む |
| S19 | 完了（L60の分） | 関数値が到達しうる27行を族ごとに照合し、保存・射影22行と形を調べる5行に分けた（function-values.json）。二表現の比較はR50 |
| O086 | L60の分は完了 | 支持の葉と型の受け口を名指し、R50の実の件数は未実施と明記。L70全reader、R50両理由0件/F-CONN、K10 |
| O157 | 群Gの分は完了 | 07-04の除外の境界と新モジュールを01-12・07-04へ写した。全比較を成功と書いていない。.34は群H |
| O168 | L60の分は完了 | 名目性・不透明性の内側の葉の受理と拒否の対（boundary.md）。DET-Rの実CLIは後段 |

## 申し送り

- 群H（.34〜.37）：最終の件数（合成表29欄 24/5、87欄 64/15/8）、01-12の写しの全体の照合（S07）、段末のA-L・独立レビュー・最終work。
- L70：`collection_inputs`・`scope_inputs`・`io_inputs`・`substitution_inputs`・`admits_sat_input`・`io_field_inputs`・`positive_inputs`・`normal_facts` は合成プログラム `StandardModel.program externals` の上の定理であり、利用者Pへの収集の後に同じ形で読む。二つの比較の除外を外す読者と交換の切替。
- R50：二つの除外の理由の実の件数（未実施）、仮定側150名と実登録の対応、関数値が到達しうる27行での生lambdaとclosureの二表現の比較（function-values.json）。

## 取りまとめに判断を求めた点（初回の報告）

1. 前提のない三欄（state_effect・ref_get・ref_set）の分類。2026-11-05に設計者が自明に数えると決めた（三モデルの sat_unconstrained も同じ）。
2. `collection_inputs` が外部宣言の表の構造検証 `ExternalWF` を前提に取ること（ずれの4）。取りまとめが認めた。
3. O022の読者として `normal_facts` を足したこと（ずれの3）。取りまとめが認めた。

## 完了の照合

- 完了した単位：L60.30・.31・.32・.33。止める条件（主な10言明の形・新しい公理・独立の信頼条件・書ける形の制限・提供範囲の削減・精密な外部状態・型付けの規則・U02依存の公開形）に当たる変更はない。前の段の署名を変えていない。Pを外部宣言のないものに制限していない（行の入力は任意の externals、外部の欄は外部宣言を持つ表）。
- 全場合・全入力の量化：行の入力は `collection_inputs`・`scope_inputs`・`io_inputs` が各分類の全行の場合を持ち（Primitiveの全構成子の場合分けで、分類の外は前提の否定）、契約そのものは群F1・F2の定理が全入力で示す。欄の入力は欄ごとの前提の存在を示す。
- 四分類：全29欄・87欄・96行を判定した。保留は0。最終の件数は「判定」の表のとおり。

## RV-L60.g の処置

取りまとめの指示（2026-11-05T21:34に受領）に従い、[RV-L60.g](../../reviews/RV-L60.g.md) の所見と設計者の決定（本体の作業木の plan.md「計画の変更と取りまとめへの確認点」の2026-11-05）を処置した。21:34:32〜21:41。本番のLeanは変えていない。

| 所見・決定 | 処置 |
|---|---|
| 設計者の決定（判断点1） | 前提も入力も持たない `state_effect`・`ref_get`・`ref_set` を、合成表の3欄と三モデルの9欄で自明に数えた（[conditions.py](conditions.py) の `NO_PREMISE`・`MODEL_TRIVIAL`、conditions.json の `previous`・`model_reclassified`、[cases.md](cases.md)）。L50と前の群の記録は書き換えず、`l50/stage-results.md` の末尾に「訂正の注記（2026-11-05）」の節を一つ足した（表の行は変えていない） |
| 中1 | 三モデルの `sat_unconstrained` の3欄も自明に数えた。台本で数え直し、合成表29欄は実質24・自明5、既存75欄は実質57・自明12・空疎6、87欄は実質64・自明15・空疎8で、レビューの計算と一致した。detail.mdの目標（12欄7/3/2・87欄76/3/8）との差は「判定」の表に示した（12欄は差0、87欄は実質−12・自明+12） |
| 中2 | S19の完了理由（引数の型の文字列の個数から「行は関数値を受けない」とした部分）を本書・boundary.md・boundary.py から削った。全377行の署名の族を `sig_scoped` の場合の一覧から読み、無制約の型変数（関数型へ具体化できる）が引数の型に現れる行を族ごとにソースで照合する台本 [function_values.py](function_values.py) を置いた。到達する27行を、値を保存・射影する22行と値の形を調べる5行に分け、結果の篩が入力の項の観測を読む6行を別の欄に記した（[function-values.json](function-values.json)、boundary.md「関数値が到達しうる行」）。27行をR50の二表現の比較の入力に含めた。関数値を禁止する制限や新しい条件は足していない |
| 情報1 | 設計者の決定で処置済み |
| 判断点2・3 | 取りまとめが認めた。処置なし |

確認：三モデルの拡張表の `sat_unconstrained` の結論が任意のm・P・tで `cases m <;> rfl`、合成表の前提のない三欄が定義と固定の署名で閉じることを、`<tmp>` の短い入力（897バイト、SHA-256 `e1045a622fa206debd45d0402ff6a4608a8c170b4f9222c73f451ba6b0251feb`）を `lake env lean -M 12288` で検査し終了0を得た（本番には入れていない）。

検査：本番のLeanを変えていないので、既定ビルドと公理監査はやり直していない（最後の記録は21:16のまま）。records.py・conditions.py・boundary.py・function_values.py で記録を作り直し、[verify.py](verify.py) を一度実行して終了0（21:40:19、[verification.json](verification.json)）。verify.py は、l50/stage-results.md の変更が末尾の一つの節の追加だけであること、取りまとめが置いたレビューの記録を担当の変更の外として扱うこと、function_values.py の再現と最終の件数を照合する。

## 群 G の作業末の work の検査（取りまとめ）

- 基準: `d76269707008268af63e0149e638804d448a6c70`（HEAD と一致）。作業木は RV-L60.g の処置の後の未コミットの状態（worktree）。
- 事前に `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消した。
- コマンド: `scripts/check.sh --level work --base d76269707008268af63e0149e638804d448a6c70`（`/usr/bin/time -l` で測定）。選ばれた検査は spec_tally・spec_examples・formal_build。
- 終了状態 0（selected checks passed）。外側の時間 861.05秒（21:41:29〜21:55:50）、最大常駐量 4,191,420,416 バイト。
- 生の記録は `<tmp>` に置いた（6,624 バイト、SHA-256 `799d36d97eb75c32b93c1f0da2ca34644bd6da0934985e0f782bc8cc8ad9abb1`）。
- 計画からのずれ: 再レビュー（Lean を実行しない）と並行して実行した。
