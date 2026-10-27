# C1Rc の結果

2026-10-25。基準 B_WORK と開始時の HEAD は `ff6f0b6ea421f81e486e61ada80c4f3be085d0d1`、ブランチは `mod012/C1Rc`。開始時の未コミット差分はなかった。private/ と、そこを指すスキルのリンクは読んでいない。git の変更操作は行っていない。

## 事前点検と停止の理由

C1Rc の中3は未完である。事前点検で、全体駆動・別本体の予算付き発見・深さの扱いと、その接続の検証・文書の照合を合わせると、枝の見込み1〜3時間に収まらないと判断した。読み取りに基づく暫定見積もりは4〜6時間であり、実装の試行による実測ではない。plan.md「前提と依存」の「着手時の点検または最初の30分で枝の見込みにも収まらないと分かったら、取りまとめが対象・保持する不変条件・依存・検査を追記して再分割する」に従い、Lean の変更前に止めた。

これは言語の規則、中心二命題、旧主定理の前提・結論の変更や、公理の追加を必要とすると分かったための停止ではない。深さの停止を報告の分類へ加える案は C1Rc の行で認められており、「深さで止まらない」補題を必須にする必要もない。以下の未接続部分を、既存の本体入口の証明から実装済みと結論することはできない。

| 読み取った箇所 | 現在の実装と、残る作業 |
|---|---|
| `formal/Benitoite/Interval/Analyze.lean` の `discoverBodies`・`discoverBlock`・`discoverClauses`・`functionBodies` | 全構文から捕捉境界の BodySeed を列挙するが、Budget.State を受け取らない。`startBody` の引数・捕捉環境の構築と忘却も計上しない。これを全体駆動の前に呼ぶだけでは、予算外の事前走査を避ける契約を満たさない |
| `formal/Benitoite/Interval/Identity.lean` の `embeddedBodies`・`bodyManifest`・`EmbeddedBody.definition` | 本体名と元の出現の対応の数学的な指定はある。節の開始位置を求めるための `preorderBlock` の長さや、`bodyManifest` の全列挙は、予算付きの実行から呼ばない契約である。次番号を逐次引き継ぎ、同じ owner・ordinal・parentStart を取得する手続きは別に必要となる |
| `formal/Benitoite/Interval/BudgetAnalyze.lean` の `bodyWork`・`analyzeBody`・`Report.after` | 本体の環境の忘却と根0からの解析、全体上限での事前停止、次の本体への消費の受け渡しはある。モジュール・定義の列と別本体を順序どおりに呼ぶ入口はない。発見の費用をどの本体の消費へ含めるか、発見した本体と入口環境の保持をいつ保存・返却するかも接続する必要がある |
| `formal/Benitoite/Interval/BudgetChildren.lean` と `BudgetIndependentRun.lean` | 未知の形の子は元キー・共有予算で独立解析する。ラムダ・lazy・節は番号だけを辿る。独立入力の保存列は別本体の列ではなく、これを別本体の発見結果として使うことはできない。未到達部分も別本体の構文上の列挙から落とさない必要がある |
| `formal/Benitoite/Interval/BudgetWalk.lean` の `Halt`、`BudgetAnalyze.lean` の `Coverage`・`Parameters` | `Halt.depth` と、それを保存する `Coverage.stopped` はある。呼び出し側が fuel を渡す。比較報告の契約表には深さの停止の件数と比較からの除外条件がなく、検査全体の入口での fuel の渡し方も定義されていない |

C1Rb3b・C1Rb3c の申し送りどおり、親の候補と各独立入力自身の候補を分けて保存する保証は利用できる。新たな駆動では、それぞれの本体へ既存の `analyzeBody` を接続し、入口の正常値・原因・位置・領域と `analyzeBody_independent_sound` の保証を保つ必要がある。

## 変更した文書と所見の対応

- plan.md の L22 に、RV-C1 の軽2を申し送った。`targetOperationAt` に同定表とキーを渡し、`standardAt` と同じ解決済みの表で標準演算を決める一般化と、WarningLocated・位置の補助定理・01-12の写しの同時更新を明記した。
- plan.md の L18 に、軽3を申し送った。不透明型の `other` と `checkedRange` の二表現について、同定済みの Range.value を未知から外す前に評価導出の欠落を確かめる手順と、レビューの二つの修正候補を明記した。L19のResultの構成子の値も照合対象とした。
- reviews/RV-C1-response.md に、中3の未完と停止の理由、軽2・軽3の申し送りを追記した。ほかの results.md には追記していない。

Lean・Rust・テスト・生成物・設計書の本文は変更していない。全体駆動の実行定義を作っていないため、契約表「解析入力と出力」「比較報告」と01-12を新しい定義へ揃える完了条件も未達である。

## 取りまとめへの再分割案

以下は再依頼のための候補であり、plan.md に新しい枝を登録した決定ではない。発見と本体解析の順序・費用の帰属は第一枝で固定し、第二枝が別の順序へ変えないことを勧める。全体駆動のために `discoverBodies` や `bodyManifest` を予算外で呼ぶ案は使わない。

| 候補 | 対象と保持する不変条件 | 依存と検証 | 暫定見込み |
|---|---|---|---|
| C1Rc1: 別本体の予算付き発見 | `BudgetDiscover.lean` 等を新設し、既存の BudgetScan の環境操作と有界走査を使う。全53構成子と相互帰納容器をフィールド順に辿り、束縛・パターン・builder・with・節の局所位置を保つ。引数・捕捉値はTop、constE自体は別本体にせず内側の境界を残す。元の定義の先行順の owner と節の ordinal、parentStart を逐次取得し、保存した seed・環境・作業枠を計上する。途中停止の接頭辞と未発見の残りを区別する。実際の発見の順序と数学的な manifest の順序の対応を補題で示す | C1Rb3c。既定import・01-12・07-04へ同時に接続する。固定期待値では入れ子、複数の節、const内の境界、捕捉位置、番号未取得・環境作成中の停止を検査する。指定の三単位のworkと定義・言明・仮定の独立レビュー | 実装・記録2〜3時間。独立レビューの時間は不明 |
| C1Rc2: 全体駆動と深さの報告 | 読み込み済みモジュールのソース順、定義順、親本体と別本体の順序を固定した入口を作る。同じ全体状態を各 `analyzeBody` と発見へ渡し、全体上限後に新しい環境・番号を作らない。発見済みだが未解析の本体、未発見部分、予算停止と深さ停止を区別する。計画で認められた深さ停止の別分類を使い、fuelを交換入力で明示し、深さ停止をRustとの一致の受け入れから外す案を勧める。契約表と01-12・07-04を実行定義と揃える | C1Rc1とそのレビュー。モジュール間・定義間・別本体間での全体超過、最初の本体で保存した候補の保持、停止分類と全体の順序を固定期待値で検査する。指定の三単位のworkと定義・言明・仮定の独立レビュー | 実装・記録2〜3時間。独立レビューの時間は不明 |

各枝の依頼時に、取りまとめが実際の対象・内部契約・基準と検査を固定する必要がある。C1Rc全体の完了とC1Rの受け入れ、S作業群・A01への着手条件を、この点検と既存ビルドの成功だけで満たしたとは扱わない。停止理由は枝の大きさであり、言語の規則や主定理を変更する判断は行っていない。

## 実行した検査

検査の割り当ての表にC1Rcの行はないため、今回の依頼で指定された三単位だけを実行した。Leanのビルドは直列とし、formal/lakefile.tomlの各プロセスの `-M 12288` を保った。単一ファイルのLean検査は実行していない。

```sh
scripts/check.sh --level work --base ff6f0b6ea421f81e486e61ada80c4f3be085d0d1 --only formal_build,spec_examples,spec_tally --dry-run
CARGO_HOME=/private/tmp/benitoite-c1ra-cargo-6o0m3fp5 scripts/check.sh --level work --base ff6f0b6ea421f81e486e61ada80c4f3be085d0d1 --only formal_build,spec_examples,spec_tally
```

dry-runは `rtk proxy` 経由で実行した。本実行は `rtk proxy /usr/bin/time -l python3 /private/tmp/benitoite-c1rc-work.py` で包み、Pythonのsubprocessから上記の検査を一度起動した。先行枝と同じ書き込み可能な一時CARGO_HOMEを使い、依存の版・入力・検査範囲を変えていない。

| 検査 | 終了状態と結果 | 外側の時間 |
|---|---|---|
| 指定のworkのdry-run | 0。spec_tally・spec_examples・formal_buildの三単位だけを選択 | 未計測（1秒未満） |
| 指定のwork本実行（一度） | 検査本体0。三単位とも成功 | Python monotonic 7.593034375秒、time real 7.62秒 |
| 仕様網羅の自己検査と集計（work内） | 成功。初回リリースの完了条件の未記入なし | 個別の外側時間は未計測 |
| 仕様例（work内） | 7成功・0失敗・0無視 | 個別の外側時間は未計測。テスト実行器の表示3.71秒 |
| 既定Leanビルドとsorry拒否（work内） | 成功 | 個別の外側時間は未計測 |
| 変更した3文書の相対Markdownファイルリンクと末尾空白（読み取りのPython） | 0。16リンクの参照先に欠落なし、末尾空白なし。アンカーの自動照合は含めない | 未計測 |
| `git diff --check`（読み取り） | 0 | 未計測 |

最大常駐量（maximum resident set size）は取得できなかった。`/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` を報告したためである。計測用timeの終了状態は1であり、Pythonが別に保存した検査本体の終了0と区別する。検査本体の失敗・再実行はなかった。

一時ログは `/private/tmp/benitoite-c1rc-work.log`、検査本体の終了状態と時間は `/private/tmp/benitoite-c1rc-work.json`、timeの出力は `/private/tmp/benitoite-c1rc-time.log` に保存した。必要な結果は上表へ転記しており、別の状態への検査結果の引用を目的とする記録ではない。work本実行後の編集は本結果記録と所見対応の追記だけであり、Lean・仕様例・仕様集計の入力は変えていない。


## 再開後の実装結果（2026-10-25）

**今回の依頼によるC1Rcの実装範囲を完了した。** 上の停止の記録と二枝の提案は、前回の記録として残す。取りまとめが再分割せず最大6時間を目安に同じ起動で仕上げることを認めたため、提案の二段を順に実装し、最後に決定済みの用語へ置き換えた。今回のB_WORKと開始時のHEADは `3623d802029dd16cbbc65850a34fecffd743a005`。ブランチは `mod012/C1Rc`、開始時に未コミット差分はなかった。private/と、そこを指すスキルのリンクは読んでいない。gitの変更操作は行っていない。

### 実装した二段と用語

| 段 | 変更と保持した契約 | 既定ビルド |
|---|---|---|
| 1 予算付き発見 | BudgetCount・BudgetDiscover・BudgetDiscoverProof・BudgetDiscoveryExamplesを追加した。全53構成子を、元の定義の番号・局所位置で辿る。handlerの全節を内側の境界より先に保存し、開始位置の先読みも同じ予算へ計上する。constE自身は別本体にしない。保存枠を先に確保し、環境作成中の停止にはinitial=noneを残す。discover_manifestは完走時の発見順・次キー・対応表をbodyManifestに対応させる | `cd formal && lake build`、終了0、337 jobs。外側時間は未計測 |
| 2 全体駆動と深さの報告 | BudgetWhole・BudgetWholeExamplesを追加した。モジュールのソース順・定義順、親、境界先行順・節順の別本体を処理する。入口作成・親解析・発見・待ち行列作成は同じ本体予算とし、その後に各別本体の予算へ切り替える。全体消費と保存項目を引き継ぐ。待ち行列も予算内で作り、全体上限後は新しい環境・番号・出力枠を作らない。未発見と発見済み未解析、残る定義・モジュールを区別する | `cd formal && lake build`、終了0、339 jobs。外側時間は未計測 |
| 最終の用語と照合 | 01-12・07-04・用語集・planとLeanの名前・コメントを構文的な到達可能性へ揃えた。原語syntactic reachabilityを用語集へ入れ、実行で到達できることとは異なると01-12・用語集・Leanの説明へ記した。別本体の標準束縛の参照にはentryEnvを使い、元の同定キーへ戻す。定義・系・独立例を既定importへ接続した | 用語の置き換え後と最終の局所 `lake build` は各終了0、339 jobs。外側時間は未計測。最終の作業末の検査は次表 |

中心二命題、対象構文の評価関係、旧主定理の前提・結論、公理、Builtins.Assumptionsは変更していない。Rust・既存テストの意味・生成物も変更していない。深さは計画で認められた別分類の案を採った。fuelは交換入力で明示し、同じ値を各本体と発見へ渡す。bodyStopsの本体停止件数とphaseStopsの入口・発見・待ち行列・制御の停止件数を分け、深さ停止がある結果はcomparisonEligibleによってRustとの一致の受け入れから外す。深さで止まらない補題を証明したとは扱わない。

元の定義から一度だけ発見し、別本体の解析から再発見しない。親と各独立入力自身の候補を混ぜずに保持する前段の保証も保つ。全体入口で保存したBodyOutputには、実際にanalyzeBodyへ渡したseedと出力を保存する。正常値・警告原因の既存の系を使う際は、そのseed.initialを忘却した環境についてのModelsと、その本体自身の評価導出を要求する。検査全体の意味保存や、実ソース・Rust/VMとの一致を証明したものではない。

用語の主な改名は次のとおりである。旧名の互換の別名は残していない。

| 旧名 | 今回の名前 |
|---|---|
| WarningRegion.lean・BudgetRegion.lean・WarningRegionExamples.lean | SyntacticReach.lean・BudgetReach.lean・SyntacticReachExamples.lean |
| InWarningRegion・WarningInRegion | InSyntacticReach・WarningsInSyntacticReach |
| regionExpr/Children/Block/Arms・numberRegion・outsideRegion | syntacticReachExpr/Children/Block/Arms・numberSyntacticReach・outsideSyntacticReach |
| IndependentInput.region・run_region | IndependentInput.syntacticReach・run_syntactic_reach |
| `*_warning_region`・region_analysis_walk・region_skip_walk | `*_warning_syntactic_reach`・syntacticReach_analysis_walk・syntacticReach_skip_walk |

過去のresults.mdとreviewsの本文は変更していない。reviews/RV-C1-response.mdには今回の対応だけを末尾へ追記した。軽2・軽3のL22・L18/L19への申し送りは、前回planへ記載したものを保つ。

### 独立例の作成時の関門と局所の修正

test-auditの作成時の関門を通し、発見の入口に7組、検査全体の入口に10組の#guardを置いた。守る契約は、観察可能な解析順と番号、捕捉位置・Topからの開始、途中停止後の入力と候補の保持、全体予算の共有、本体予算の切り替え、深さの報告と比較からの除外である。既存の直接の式・本体・独立入力の例は、全体入口や発見処理を呼ばないため、この接続の欠落を捕まえない。追加の例は実際の入口を使い、テスト専用の差し込み口は作っていない。新しい入口の独立例であり、修正前の処理系で再現した退行テストとは扱わない。

番号・開始位置・局所位置は手で数えた固定期待値を使った。全体消費93回は、最初の親終了19回、発見終了38回、待ち行列の分類・保存と別本体の終了50回、次の定義の終了71回、次モジュールの定義の終了93回という計上を確認した。40・50・71回の上限で、別本体・次の定義・次のモジュールへの停止をそれぞれ観察する。初回の試行で出力も調べたが、試行出力から期待値を自動生成していない。全53構成子とmanifestの任意の完走時の対応は、固定例だけでなくdiscovery_complete・discover_manifestで示した。

局所の検査はすべて直列に実行した。対象は `lake build Benitoite.Interval.BudgetCount`・`BudgetDiscover`・`BudgetDiscoverProof`・`BudgetWhole`・`BudgetWholeExamples`（各接頭辞はBenitoite.Interval）、各段と用語の置き換え後の `lake build`、後述の単一ファイルの公理確認である。各プロセスのメモリ上限はlakefile.tomlの `-M 12288`、単一ファイルは `lake env lean -M 12288 <file>` を使った。

初回の局所検査では、Leanの継続行の字下げ・括弧、使用できないprivateのarmCount、単位型やAbstractSlotの等値判定、深い組の等値判定の型クラス探索、容器の証明での式の正規化が失敗した。armCountは公開のcountListによる有界な走査へ、判定は必要な観察値の射影とパターン照合へ、深い組は本体名と候補の平坦な表へ直した。guardの任意式を含む証明はnone/someを明示して分け、カーネルの適用型の不一致を解消した。検査対象・期待の意味・予算・メモリ・時間制限を緩めていない。lakeを一度リポジトリの根で実行し、lakefileがないため終了1になった。formal/を指定して続けた。新しいLeanのlint警告は整理し、最終の局所ビルドに残った警告は既存のFlow.lean:710だけである。

### 指定された作業末の検査

今回の依頼の指定に従い、下記のdry-runと本実行を各一度行った。planの検査の割り当てにも、今回の基準と指定をC1Rcの行として追記した。

```sh
scripts/check.sh --level work --base 3623d802029dd16cbbc65850a34fecffd743a005 --only formal_build,spec_examples,spec_tally --dry-run
CARGO_HOME=/private/tmp/benitoite-c1ra-cargo-6o0m3fp5 scripts/check.sh --level work --base 3623d802029dd16cbbc65850a34fecffd743a005 --only formal_build,spec_examples,spec_tally
```

本実行は `rtk proxy /usr/bin/time -l python3 /private/tmp/benitoite-c1rc-current-work.py` で包み、Pythonのsubprocessから上記コマンドを起動した。先行作業と同じ書き込み可能な一時CARGO_HOMEを使い、依存の版と検査範囲は変えていない。

| 検査 | 終了状態と結果 | 外側時間・件数 |
|---|---|---|
| workのdry-run | 0。spec_tally・spec_examples・formal_buildの三単位だけを選択 | 未計測、1秒未満 |
| work本実行（一度） | 検査本体0。三単位すべて成功 | monotonic 7.698001375秒、time real 7.72秒 |
| 仕様網羅の自己検査と集計（work内） | 成功。初回リリースの完了条件の未記入なし | 個別の外側時間は未計測 |
| 仕様例（work内） | 7成功・0失敗・0無視 | 個別の外側時間は未計測。実行器の表示3.68秒 |
| 既定Leanビルドとsorry拒否（work内） | 成功 | 個別の外側時間は未計測 |
| `lake env lean -M 12288 /private/tmp/benitoite-c1rc-axioms.lean` | 0。新しい計数・発見・入口の補助定理、既存の式/本体の健全性・位置・構文的な到達可能性・独立入力の保存、Core/Release/Surfaceの主定理など26宣言を確認 | 未計測、1秒未満 |

公理依存は、entryEnv_parentがpropextのみ、depth_not_comparableが公理なし、Coreの三主定理がpropext・Quot.soundのみであった。他の確認対象はpropext・Classical.choice・Quot.soundのみであり、新しい公理を含まない。用語の改名は定理の内容を変えていない。

最大常駐量（maximum resident set size）は取得できなかった。`/usr/bin/time -l` が `sysctl kern.clockrate: Operation not permitted` を報告して終了1となったためである。Pythonが別に保存した検査本体の終了0とは区別する。work本実行の失敗・再実行はなかった。一時ログは `/private/tmp/benitoite-c1rc-current-work.log`、終了状態と時間は同名のjson、timeの出力は `/private/tmp/benitoite-c1rc-current-time.log`、公理確認は `/private/tmp/benitoite-c1rc-axioms.log` に保存した。必要な結果は本記録へ転記しており、別の状態へ結果を引用する記録ではない。

### 計画との差と申し送り

- 再分割は行わず、今回の明示の依頼どおり二段を同じ枝で終えた。中心定理・主定理の変更や公理の追加を求める停止条件には当たらなかった。実装の残りはない。
- 深さの扱いは、計画の二案のうち別分類の報告を採った。L27/L28は明示したfuelと、bodyStops/phaseStopsの二種類の件数、comparisonEligibleを交換に写す。未発見・未着手を0件とせず、発見結果と待ち行列と残る入力の参照を保持する。
- A01/A02/A11とX01/X02は、BudgetWholeの順序・親と発見をまとめた本体予算・別本体での切り替え・反転の計上・元キーへの同定の復帰を同じ形で写す。既存の親と各独立入力自身の候補をともに読む契約も保つ。全結果がTopであるだけの一致は、comparisonEligibleがtrueでも受け入れない。
- 軽2の標準演算の位置の一般化はL22、軽3の不透明型の二表現に対する評価導出の確認はL18/L19の担当である。この作業でその後続実装を先取りしていない。
- 独立レビュー、C1RcとC1Rの受け入れ、S作業群・A01への着手判断は取りまとめの担当である。今回の自己確認とworkの成功で受け入れを閉じない。コミット・取り込み・docs/todoの更新・公開は行っていない。


### 最後の差分と文書の確認

- `git diff --check` は終了0であった。
- 変更した6文書の相対Markdownファイルリンク413件を読み取りのPythonで確認し、参照先の欠落はなかった。アンカーの自動照合は含めない。
- 改名前後の既存のLean 5ファイルをB_WORKと比較し、名前の置換とコメントを除いたコードが一致することを確認した。構文的な到達可能性の定義・系と、独立入力の既存の証明は改名のみである。
- 現在のLean・01-12・07-04・用語集・planに旧名が残っていないことを確認した。過去の記録には改名前の名称を保つ。
- work後の編集は本結果記録と所見対応、番号未取得の説明へ先読みのcountの枠・分類を補う文書本文だけである。Lean・仕様例の入力のコードブロック・仕様集計の見出しは変えていない。
