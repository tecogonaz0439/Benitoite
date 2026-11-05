# L60 群 D の実装記録

基準 B_WORK: `787e7139add411caac6a72ed4f072d70d27877b2`。指定ブランチ `m014/l60.d`。git の状態を変える操作と scripts/check.sh の実行は行わない（照合の台本は `git diff`・`git show`・`git ls-files` を読み取りだけに使う）。共通依頼文と2026-10-30の勧告照合・組み込まない判断を継承する。

## 単位の時刻と判定

準備の読解は 2026-11-05T14:04:20+09:00 から L60.14 の開始までに行った。各区間は外側の時間であり、能動時間と待ちは分離していない。単位の境界はコマンドの実行時刻から採った。L60.14 と L60.15 は連続して実装し、境界を別に採っていない。

| 単位 | 開始（JST） | 終了（JST） | 判定 |
|---|---|---|---|
| L60.14〜.15 | 2026-11-05T14:13:18+09:00 | 2026-11-05T14:16:20+09:00 | 完了。型付きの外部呼出しの開始から ExternalArgs・受信・応答の存在・一歩と行先の型付け、選択した対の所属と計算した一歩の一致、外部参照の適用の計算。具体の型付きの開始で三葉の全てに到達。局所Lean終了0 |
| L60.16 | 2026-11-05T14:16:20+09:00 | 2026-11-05T14:19:30+09:00 | 完了。型IDの参照の同値、外部名の参照のlookupからの型付けと逆転。局所Lean終了0 |
| L60.17 | 2026-11-05T14:19:30+09:00 | 2026-11-05T14:22:56+09:00 | 完了。直接の飽和呼出しの引数の数・State、名前付き引数の一般の並べ替え、部分適用の本体の葉。局所Lean終了0 |
| L60.18 | 2026-11-05T14:22:56+09:00 | 2026-11-05T14:33:50+09:00 | 完了。参照の部分型の戻し、五接続の型付き正例と、未知の型ID・外部名・非空の型引数・偽造の三境界の拒否を同じ表に置いた。写し、既定ビルド・全環境の公理監査・照合 |

群の外側の時間は準備の読解を含めて約30分（14:04:20〜14:33:50）である。計画の見込み2時間40分〜4時間35分を大きく下回った。主な理由は、群Cまでに選択関数 `Builtins.selectExternal`・受信の四葉・外部の状態の三葉（ExternalStateLeaves）・F08の二葉が本番にそろい、本群はそれらの読者と、型付きの開始からの入力の供給を書く作業になったことである。

## 現在の成果と全入力での判定

群Dは、外部3 Step、選択と計算→関係、表層の外部固有5接続の葉を閉じた。主定理（progress・preservation・step_sound など）は閉じていない。独立レビュー、取りまとめのwork、取り込み・受け入れは未実施で、担当の自己点検と区別する。

### 外部3 Stepと選択（L60.14〜.15）

全ての葉は任意の P・B・σ・Eb・q・f・ts・ws・k・μ と、`P.WellFormed`・`P.WellTyped B`・`Builtins.CoreAssumptions P B`・`StateTyE P B σ Eb (.run q k μ)`・view の等号を量化する。正常応答を選べるという前提、外部宣言のないPへの制限、空ストアやTopへの限定はない。

| 葉 | 本番の入口 | 前提を満たす証人（同じ表） | 四分類 |
|---|---|---|---|
| 開始からの入力 | `StateTyE.external_args` | `ExternalLeafExamples.start_typed` | 実質。状態と同じΨで lookup と ExternalArgs を返す。Ground・型引数と結果の正準性・注釈は元の閉包の型付けと閉性から得る |
| 受信の none・exit の排除 | `StateTyE.external_receive` | 同上と `integer_response` | 実質。関係に属する任意の応答で、受信が some であり exit でなく観測が空 |
| E_External | `StateTyE.external_step_of_response` の val 枝（既存 `external_value_all`） | 整数1の応答と `accept` | 実質。受信値は received_value で元の結果型・Ground・任意σの適格性を持つ |
| E_ExternalErr | 同 err 枝（既存 `external_error_all`） | 篩に反する整数0（`reject`）と任意の err r | 実質 |
| E_ExternalApply | `step_external_apply`（既存 `external_apply_all`） | `applyStart_typed` | 実質。任意の応答の選択で、計算した一歩と規則の一歩が同じ外部呼出しを返す |
| 応答の存在と一歩 | `StateTyE.external_response_step`（F05の署名どおり） | `start_typed` | 実質。応答の存在は三条件の `external_exists` を使う。三モデルではこの欄は定数errの自明欄であり、正常応答の存在を主張しない |
| 選択と計算→関係 | `step_external_selected` | `start_typed` | 実質。`B.selectExternal` の対の関係所属・空の観測と、`step … B.selectExternal …` の結果と同じ行先の Step・StateTyE。逆向きの完全性は結論に含めない |

σ・Eb・継続・ストアは全ての結論で開始と同じである。H14/H31 の受け持ちは、既存の `received_value`・`external_adequate` を `external_value_all` を通して実際に使い、δ/IO の証拠で代用していない。S11 は既存の `external_apply_all` を再利用し、本群では存在の供給だけを足した。

### 表層の外部固有5接続（L60.16〜.18）

全ての葉は任意の P・B・Ψ・Q・C・Γ・Φ・R・Δ を量化する。部分適用の生成ラムダの本体の文脈（ラムダの引数を束縛した Γ）もこの量化に入る。

| 接続 | 本番の入口 | 前提を満たす証人と対照 | 四分類 |
|---|---|---|---|
| 型IDの参照 | `ExternalSurface.type_declared_iff` | 宣言した ⟨0⟩ を受理し、未知の ⟨1⟩ と非空の型引数を拒否 | 実質 |
| 外部名の参照 | `ref_of_lookup`・`ref_inputs`・`ref_arguments` | ⟨1⟩ を宣言の依存列の正規形で受理し、未知の ⟨2⟩ を任意の型で拒否。参照の型の依存列に沿う `[1, 2]` を宣言の依存列へ戻す | 実質 |
| 直接の飽和呼出し | `call_of_lookup`（既存 `call_typed`） | 二引数の `pair` に宣言順 `[1, 2]` | 実質。引数の数＝宣言の引数の数、型引数が空、効果＝`callEffect d` |
| 名前付き引数の呼出し | `named_call` | `pair(b = 2, a = 1)` の位置 `[1, 0]` を `recordFields` で `[1, 2]` へ | 実質。各値が一つの位置に一度置かれ全位置が埋まり、ラベルは具体化後の同じ引数名を指す |
| 穴を持つ部分適用 | `partial_call`・`apply_typed` | `pair(b = 2, a = _)` の本体で、穴の引数（番号0）と2を宣言順に並べた外部参照の適用 | 実質 |
| 偽造を断る境界: ハンドルの直接構築 | 群Bの `handle_not_source` を同じ表に適用 | 外部型 ⟨0⟩ を宣言した表 | 自明（Source の False の枝で閉じる。群Bの分類を継承） |
| 偽造を断る境界: 表現を読むパターン | 群Bの `non_binding_pattern_rejected` を同じ表に適用 | 同上 | 空疎（不可能な型付けの前提を否定する。群Bの分類を継承） |
| 偽造を断る境界: 構成子値からの変換 | 群Bの `constructor_value_rejected` を同じ表に適用 | 同上 | 空疎（同上） |

宣言順とソース順の区別: 外部の依存列は宣言順の実引数だけを受ける（`call_of_lookup`）。ソース順の値と宣言上の位置の置換は、既存の一般の並べ替え `Benitoite.Surface.recordFields` で宣言順へ移す（`named_call`・`partial_call`）。ソース順の評価と束縛（let の連鎖）、穴のラムダの型付け、全表層の検査器への組込みは一般の脱糖と L70 の担当であり、本群で書き換えていない。非穴式の評価位置は、既存の `Surface.Desugar` の partialCall がラムダの本体で callee と非穴式を評価する形のままであり、外部参照の適用は呼出しのたびに `E_ExternalApply` で同じ外部呼出しへ進む（`step_external_apply`）。

結果の篩とState: `ref_of_lookup` は参照の型が `Tel.norm d.parameters` そのものであることを返し、篩を忘れない。`callEffect d` は uses が空なら空効果、そうでなければ State だけを持つ。`args_effect` は失敗の型を持たない効果が実引数の束縛で変わらないことを示し、`call_of_lookup`・`named_call`・`partial_call` は呼出しの効果がこの `callEffect d` であることを返す。

H02 の受け持ち: `.17` は `ref_arguments` で `TelClosure.apply` へ呼出し側の `Ctx.WF` と `SignatureInstance` の元列の注釈を渡す。`.14` 側は既存の `StateTyE.externalRef_contract_inputs` が実際の開始状態（`applyStart_typed`）から同じ入力を供給することを適用例で示した。除去済みの四前提は使っていない。

### 四分類の集計

| 母集団 | 不成立 | 空疎 | 自明 | 実質 | 保留 |
|---|---:|---:|---:|---:|---:|
| 外部3 Stepと受信の排除（4行） | 0 | 0 | 0 | 4 | 0 |
| 選択と計算→関係（3行） | 0 | 0 | 0 | 3 | 0 |
| 表層の5接続（5行） | 0 | 0 | 0 | 5 | 0 |
| 偽造を断る三境界（3行、群Bの分類を継承） | 0 | 2 | 1 | 0 | 0 |
| 合計（15行） | 0 | 2 | 1 | 12 | 0 |

実質と判定した12行は、いずれも前提の否定で閉じる葉ではなく、前提を満たす入力の証人を同じ表（`ExternalLeafExamples.program`・`builtins`）で既定ビルドの中に置いた。偽造の三境界は群Bの同じ三補題を同じ表へ適用したものであり、自明1・空疎2の分類を変えない。証人は大きさ0〜2の値と長さ0〜2の列だけであり、大きな具体値を評価していない。表層の証人は二引数の非依存の宣言であり、依存する宣言の並べ替えの正しさを具体例から推測していない。全称の言明は宣言の依存列・位置の置換・実引数の列を記号のまま量化する。87欄の分類は群Cの判定（実質76・自明3・空疎8）を変更していない。

## L70 への署名表

完全名の接頭辞は `Benitoite.Release.Refinement.`。全暗黙引数を含む実型・型のSHA-256・直接の型/値の依存は [audit-summary.json](audit-summary.json) の分割記録（declarations-01〜06）にある。

| 受け手 | 入口 | 量化・入力と結論 |
|---|---|---|
| L70 progress/preservation | `StateTyE.external_args`・`external_receive`・`external_step_of_response`・`external_response_step` | 任意の型付きの外部呼出しの開始と WellFormed・WellTyped・CoreAssumptions。同じΨの ExternalArgs、受信の some・非exit・空の観測、受信の結果に従う Step と同じσ・Eb・k・μ の StateTyE |
| L70 step_sound | `step_external_selected`・`step_external_apply`、群Aの `Builtins.selectExternal`・`selectExternal_response` | 実行関数の外部の選択に `B.selectExternal` を使う。選択した対の所属・空の観測、計算した一歩と規則の一歩の行先の一致。外部参照の適用は任意の選択で同じ外部呼出しへ。step→Step の向きだけ |
| L70 表層・脱糖・検査器 | `ExternalSurface.type_declared_iff`・`ref_of_lookup`・`ref_inputs`・`ref_arguments`・`call_of_lookup`・`apply_typed`・`named_call`・`partial_call`・`callEffect`・`args_effect`、既存 `ref_typed`・`call_typed` | 整形式の有限表とlookupから、型IDの宣言済み、参照の型（空の型引数・宣言の依存列の正規形・Stateの効果）、宣言順の実引数の型付き呼出し（引数の数・効果）、`recordFields` による全位置の充足とラベル。ソース順の評価・束縛、生成ラムダの型付け、全表層の健全性の合成は L70 |
| L70・R50 | `ExternalLeafExamples` の有限表と開始状態 | 値に依存する篩 `0 < self` の結果、二引数の外部関数、外部型の宣言を一つの表に持つ。三葉の到達、五接続の型付き正例、未知の型ID・外部名と非空の型引数の拒否、偽造の三境界 |

## 足した宣言

本番の新モジュールは `ExternalLeafSelection` の1件で、既定importへ加えた。既存の `ExternalSurfaceLeaves` に表層の葉を加え、`ExternalNominal`・`TelApplication`・`Surface.Lemmas.Calls` の import を足した。既存の定義・署名は変更していない。

二モジュールの全134宣言のうち、群Aから引き継いだ `ref_typed`・`call_typed` を除く132宣言を追加した（[added-declarations.json](added-declarations.json)）。全134宣言の内訳は定理100・定義34（構成子や補助の生成宣言を含む）であり、うち追加132宣言は定理98・定義34である。privateの宣言67とソース位置のない宣言69は、全134宣言についての数である。名前付きの公開の def/theorem は45件で、全件に名前付きの読者か既定ビルドで型検査した適用例がある（[readers.json](readers.json)：名前付きの読者23、適用例38、重なりあり）。

| モジュール | 主な公開の入口 |
|---|---|
| ExternalLeafSelection | `StateTyE.external_args`・`external_receive`・`external_step_of_response`・`external_response_step`、`step_external_selected`・`step_external_apply`、`ExternalLeafExamples` の有限表・開始状態・証人 |
| ExternalSurfaceLeaves | `ExternalSurface.args_effect`・`callEffect`・`type_declared_iff`・`ref_of_lookup`・`ref_inputs`・`call_of_lookup`・`apply_typed`・`ref_arguments`・`named_call`・`partial_call` |

## 既定ビルド・公理依存・照合

| 検査 | コマンド（formal/ 又は根から） | 終了 | 外側時間 | 記録 |
|---|---|---|---|---|
| 既定ビルド | `lake build`（lockf で順番を取る） | 0 | 5.87秒 | [default-build.json](default-build.json)。1309ジョブ。再ビルドは ExternalSurfaceLeaves とその読者3件・新モジュールの5件。本群の二モジュールの警告0 |
| 全環境の公理監査 | `lake env lean -M 12288 ../<改造>/l60/d/axioms.lean`（lockf） | 0 | 46.76秒 | [axioms.json](axioms.json)・[audit-summary.json](audit-summary.json)。既定importの1048モジュール・83,825宣言（private・生成宣言を含む、固定点2巡）。許す公理は propext・Quot.sound・Classical.choice の部分集合だけ。sorryAx・新公理・除外0 |
| 照合 | `python3 <改造>/l60/d/verify.py --tmp <tmp>` | 0 | 0.32秒 | [verification.json](verification.json) |

監査の対象一覧は [axioms.lean](axioms.lean) の環境の列挙と [inventory.py](inventory.py) で再生成できる。対象の全名一覧（5,544,773バイト前後、SHA-256は audit-summary）と生出力（約16.6 MB）は `<tmp>` に置き、改造には大きさと SHA-256 だけを残した。RSS は未取得（計画上の非採取）。

照合の台本は、基準からの変更が `formal/Benitoite.lean`・`ExternalSurfaceLeaves.lean`・01-12・07-04 の4ファイルと新モジュール1件と本記録だけであること、追加箇所を取り除くと基準の内容に一致すること、二モジュールが既定importの閉包にあること、sorry・axiom・native_decide・#eval・maxHeartbeats/maxRecDepth の指定・工程のIDがないこと、公開の入口の読者、記録の大きさ（各100 KB以下・群で約0.52 MB）・手元の絶対パスとdocs/todoへのリンクの不在を確かめる。

## 計画からのずれと局所検査

| 項目 | 扱い |
|---|---|
| 選択関数 | F05 の `Builtins.selectExternal`・`selectExternal_response` は群Aが ExternalModelTransport に置いていたので作り直さず使った。本群は `step_external_selected` と状態の葉を足した |
| 触ったファイル | 計画の ExternalLeafSelection・ExternalSurfaceLeaves のとおり。表層の具体の証人と偽造拒否の収集は、ExternalSignatureLeaves（ExternalSurfaceLeaves を import する）の宣言を使うため ExternalLeafSelection に置いた |
| 指定の広げ | H02 の `.17` の受け口として `ref_arguments` を、State を読むために `args_effect`・`callEffect` を足した。いずれも内部の補助の追加であり、前段の署名を変えていない |
| 一般の並べ替えの読者 | 新しい並べ替えを作らず、既存の `Benitoite.Surface.recordFields` と `recordFields_getElem` を使った。そのため ExternalSurfaceLeaves が旧 Surface の `Surface.Lemmas.Calls` を import する |
| 既定ビルドと監査の回数 | 作業末に一度の指定に対し、`ref_arguments` を足す前の14:26に一度ずつ実行し、その後に最終の一度ずつ（14:30〜14:31）を実行した。記録は最終の回だけを置き、最初の回の宣言の記録は削除した |
| 局所検査 | 単独の `lake env lean -M 12288` を同時に一つずつ実行した。変更した ExternalSurfaceLeaves を読む ExternalLeafSelection の局所検査では、一時領域にビルド出力のシンボリックリンクの木を作り、ExternalSurfaceLeaves の olean だけを `-o` でそこへ書き出して LEAN_PATH の先頭に置いた。`.lake/build` は上書きしていない（最終の既定ビルドで当該5モジュールを再ビルド） |
| 局所検査の失敗 | 相互帰納型への `induction`、`private def` の値の扱い、別モジュールの具体応答の取り違え（positiveProgram と本群の表）、Stateの効果の match の等号、暗黙引数、`Ordinary` の証拠、`Eff.norm` の簡約、import の不足（TelApplication・LeafInputs）を修正した。成功の根拠に失敗した入力を使っていない |
| 停止条件 | 主な10言明の形の変更・新公理・独立の信頼条件・書ける形を狭める変更（Pの制限を含む）・提供範囲の削減・精密な外部状態・型付けの規則の変更・U02の回答に依存する公開形の選択は0。前段の固定署名の変更0 |

テストの作成時の関門（test-audit）: 本群は Lean の定理と既定ビルドの適用例だけを足し、処理系のテストを加えていない。適用例が所有する契約は、型付きの外部開始から三葉へ進むこと、選択した対が関係に属し計算と規則が一致すること、五接続の型付き正例と、未知の型ID・外部名・非空の型引数・偽造の三境界の拒否が同じ表にあることである。直接呼出しの不正な引数、名前付き引数の不正な配置、部分適用の不正な穴を拒否する例は置いていない。開始からの ExternalArgs の供給が崩れる、受信の none/exit の排除が失われる、篩の拒否が誤りへ進まない、並べ替えが位置を取り違える、State の効果が失われる、未知の型ID・外部名を受理する退行をこの境界で検出する。

## 担当の義務の一行ずつの判定

| 行 | 群Dの判定 | 証拠 | 残る段 |
|---|---|---|---|
| O038 | 外部応答の同じ状態からの葉は完了 | `external_step_of_response`・`external_response_step` | 解放の葉（群E .20）、L70の全保存 |
| O057 | 任意の型付き外部開始からの応答存在は完了 | `external_args`・`external_response_step` | 解放の存在（群E）、.22/.29、L70 progress |
| O058 | σ/Eb/k/μ を保つ外部の保存の葉は完了 | 同上 | .20/.29、L70 preservation |
| O059 | 選んだ外部応答からの step→Step の局所証拠は完了 | `step_external_selected`・`step_external_apply` | 解放（.20）、L70 step_sound |
| O061 | external_no_targets を同じP/Bで状態の葉の結論へ渡した（観測が空） | `external_receive`・`step_external_selected` | .29、L70の一段・到達・表層 |
| O086 | 両除外を外すための外部の支持葉と型の受け口を用意した。実の除外0件は未実施 | 表層5接続の入口と適用例 | .33、L70の全reader、R50の両理由0件・F-CONN、K10 |
| O088 | 表層5接続の分は完了 | 同上 | 群E〜F、L70の主定理・全脱糖、R50 |
| O157 | 新しい外部の葉を01-12・07-04へ同じ変更で写した。全比較は未実施で成功と書いていない | 01-12「篩を含むコア計算の形式化」「篩を含む状態の型付け」、07-04「篩を含む形式化の範囲」・対応表 | .29/.33/.34、L70の境界の改訂、R50、D10/V10 |
| O168 | 名目性・不透明性の内側の葉の受理・拒否の対を同じ表で示した | 型ID・外部名の受理と拒否、偽造の三境界 | .33、R30/R50/R60/R70/D10/V10 の実CLI |
| O084 | 篩・σ・external の差を別記し、停止条件に当たる変更0 | 本記録 | L70/R/K/V |
| O118 | 本番のコメントと写しに工程のIDなし（照合の台本で確認） | verify.py | 後段 |
| H02 | `.17` は `ref_arguments`、`.14` は実開始からの `externalRef_contract_inputs` の適用例。除去済みの四前提の復活0 | 同上 | L70の全合成 |
| H14・H31 | 既存の received_value・external_adequate を状態の葉で実際に使用 | `external_value_all` 経由 | 公開の元入力の再点検は U02 の後 |
| S11 | 既済み継承。存在の供給だけを足した | `step_external_apply` | なし |

完了条件（群Dの行: 外部3 Step、選択と計算→関係、表層の外部固有5接続、主定理は閉じない）を照合した。三つとも全入力を量化する本番の定理と、前提を満たす同じ表の証人を既定ビルドに持つ。主定理は閉じていない。

## 取りまとめに判断を求める点

1. Lean の `Val.Source` は `.externalRef` を既定の枝で受け入れる（外部ハンドルは拒否する）。Rust は外部関数の参照を値として使う形を拒否する。本群の葉は参照を呼出しの頭に置く形だけを扱い、第一級の関数値の提供を加えていないが、Source の側の差は残る。L70 の新しい表層の検査器・R50 の比較で、この差をどこで閉じるか（Source の定義を狭めるか、検査器の受理側で断るか）の判断が要る。Source の定義を変えると Source の全読者へ波及するため、本群では変えていない。
2. ExternalSurfaceLeaves は一般の並べ替えの読者として旧 Surface の `recordFields`（型に依存しない定義）と `recordFields_getElem` を import して使う。新しい表層を作る L70 で同じ定義を使い続けるか、Refinement 側へ移すかの方針を確認したい。
3. 旧 Surface の部分適用は非依存の `.lam` を生成する。結果の篩が前の引数を参照する依存の宣言の部分適用には `dependentLam` の生成が要る可能性がある。外部に固有の点ではなく一般の脱糖の設計（L70）の論点として申し送る。
4. 群Eの担当も `formal/Benitoite.lean` の末尾へ import を足すため、取り込みのときに同じ箇所の差が重なる。
5. 本群の外側の時間は約30分で、計画の群Dの見込みを大きく下回った。後続の群の見込みの改定に使うかの判断は取りまとめに委ねる。

## 再開1（RV-L60.d の処置）

| 区間 | 開始（JST） | 終了（JST） |
|---|---|---|
| RV-L60.d の軽1〜3の処置 | 2026-11-05T14:43:59+09:00 | 2026-11-05T14:46:05+09:00 |

[RV-L60.d](../../reviews/RV-L60.d.md)（結論は可、軽3・情報3）の軽1〜3を、所見の箇所に限って処置した。情報1〜3は処置していない。Lean の宣言は変えていないので、既定ビルドと公理監査は再実行していない。

| 所見 | 処置 |
|---|---|
| 軽1 | 「表層の外部固有5接続」の偽造を断る境界を3行へ分け、群Bの分類（ハンドルの直接構築は自明、表現を読むパターンと構成子値からの変換は空疎）を継承した。「四分類の集計」を表層5接続の実質5と偽造の三境界の自明1・空疎2に分け、母集団を15行（不成立0・空疎2・自明1・実質12）とした。「いずれも」の文を実質と判定した12行に限った。群Dには別の conditions の記録がないので、集計は本書の表だけを直した。87欄の分類は変えていない |
| 軽2 | 01-12「篩を含む状態の型付け」と07-04「篩を含む形式化の範囲」の ExternalLeafExamples の説明、本書の L60.18 の判定・L70への署名表・テストの作成時の関門の文を、五接続の型付き正例と、実際に置いた拒否例（未知の型ID・外部名、非空の型引数、偽造の三境界）に分けて書いた。照合の台本の写しの除去の終端を新しい文に合わせた |
| 軽3 | 「足した宣言」に、全134宣言の内訳（定理100・定義34）と追加132宣言の内訳（定理98・定義34）を分けて書き、private67・位置なし69が全134宣言の数であることを明記した |

検査: 写しのハッシュを道具の記録（tools.json）へ反映し、verify.py を実行した。最初の実行（14:45）は、取りまとめが置いた未追跡の `reviews/RV-L60.d.md` を担当の変更の外として扱っていなかったため、変更範囲の照合で記録を書く前に終了1で止まった。照合の台本にこのファイルを除く一行を足して再実行し、終了0（[verify.json](verify.json)、14:45:55、外側0.28秒）。既定importの閉包1048モジュール、追加以外の不変、公開45入口の読者、記録の大きさと入力のハッシュの照合が通った。

## 群 D の作業末の work の検査（取りまとめ）

- 基準: `787e7139add411caac6a72ed4f072d70d27877b2`（HEAD と一致）。作業木は再開1の後の未コミットの状態（worktree）。
- 事前に `formal/.lake/build/lib/lean/Benitoite/Release/Refinement` と `formal/.lake/build/ir/Benitoite/Release/Refinement` を消した。
- コマンド: `scripts/check.sh --level work --base 787e7139add411caac6a72ed4f072d70d27877b2`（`/usr/bin/time -l` で測定）。
- 終了状態 0（selected checks passed）。外側の時間 615.28秒（14:46:42〜14:56:57）、最大常駐量 3,846,979,584 バイト。
- 生の記録は `<tmp>` に置いた（6,624 バイト、SHA-256 `84cf15fda60f20e4e3240f20c3015939942bf82f18d66eb9be843f864d87d949`）。
- 計画からのずれ: 群 E の作業と同じ機械で並行したので、外側の時間と最大常駐量は単独の実行より大きい。
