# G1 改造全体の回帰と証拠の集約の結果

2026-10-23開始、2026-10-24完了（JST）。G1実装担当Codex。B_WORKとHEADは `baca0076e5f08abace9cc22136ed2f690f208684`、ブランチは `mod011/G1`。changeの開始版B0は `a9c4132e6451904698cf344db1794c4d03affcd6` である。G1の範囲と追加指示に従い、レビュー指摘の修正と記録の集約、回帰検査を完了した。独立レビューと受け入れは取りまとめへ渡す。

## 修正と集約

| 対象 | 変更と理由 |
|---|---|
| RV-F5 L1 | 07-04の「E2の準備」を、段階E2の入口の準備（`Exchange.CheckInput.prepare`）と明記 |
| RV-F5 L2 | 独立入力29定義のうち、Rustのソースと対応する25関数を比較する関係を記載 |
| RV-F5 L3 | `formattedStringFallback` と標準出力に、数えたstringExprの件数とplainStringの期待件数との差を使用。従来の受理条件は同じ |
| RV-F5 L4 | check-formalの先のbatch5単独呼び出しを削除。後の`--rust-dir`付き呼び出しが独立入力の単体テストとRust出力の比較を行うため、両方を一度ずつ実行する。検査の範囲は同じ |
| changeで見つけたlint | `examples/try_actions_inventory.rs` のTyのmatchの全域パターンを、残る全バリアントの列挙へ置換。関数型のguard不成立の場合も従来と同じNone。言語とinventoryの出力の意味は変えない |
| 全体の集約 | [改造のresults.md](../results.md)に作業28件（うち追加修正7件）、レビュー8件、short15回、段の接続とZ1への申し送りを集約 |
| D42 | K1を参考記録に限定し、受け入れの証拠には引用しない。全比較の唯一の証拠はZ1のK2 |
| 履歴の注意 | C2のnamed_arguments退行をC2のworkの対象限定で見落とし、F1で発見しC2Rで修正した経緯を一行で保存 |
| shortの転記 | W2の記録は「65点すべて判定不能」とあるが、元のresult-manifest.jsonは66点、達成1・判定不能65。集約には元データを採用 |

test-auditの作成時の関門では、既存の検査が守る独立入力の29定義・六入口、Rustの32定義・全14頭・formattedの保持の契約を確認した。L3は報告値の算出を実際の計数にそろえる変更で、失敗条件を緩めない。L4は同じunittest.mainとcheck_rustの呼び出しを残したまま、シェル側の重複する呼び出しだけを除く。検査関数の追加・削除、期待値・入力の大きさ・ignore・時間制限の変更、検査用の本番APIの追加はない。 Rustのexampleは1行追加・1行削除、既存のPython照合器は5行追加・3行削除、シェルは3行追加・7行削除である。処理系本体とテスト関数の増減はない。

## 実行と初回の失敗

正確なコマンドは [plan.mdの検査の割り当て](../plan.md#検査の割り当て)のwork G1・change・change G1の続行に集めた。各check.shは同じ基準・指定でdry-runを行い、選択と理由を確認してから実行した。実行記録のJSONにも実際の引数・終了状態・外側の時間・ログのSHA-256がある。実行の外側の時間はPythonのtime.monotonicでプロセスの開始から終了まで測った。文書確認だけは外側を計測せず、確認スクリプト内の走査時間と区別した。

| 実行 | 終了状態 | 外側の時間 | 記録と結果 |
|---|---:|---:|---|
| 最初のwork（Python・文書・シェルのみ） | 0 | 0.223秒 | [work.json](work.json)。formal_buildのみを選択し既定ビルドとsorry拒否が成功 |
| 局所のbatch5交換検査 | 0 | 2.141秒 | [batch5.json](batch5.json)。独立検査8件、Rust32定義、formatted28、書式付きString3、脱落0、14頭、六入口の照合に成功 |
| 初回change | 1 | 23.003秒 | [change.json](change.json)。fmt・lint_default成功後、lint_heapのworkspace all-targetsでexampleのwildcard_enum_match_armを検出し停止 |
| example修正後のRustのwork | 0 | 100.944秒 | [work-rust.json](work-rust.json)。fmt・lint_default・lib1271件（ignore21）・declarations24件（ignore1）・規約・生成物・仕様集計・formal_build成功 |
| changeの続行 | 0 | 4785.634秒（約79分46秒） | [change-resume.json](change-resume.json)と[check-summary.json](check-summary.json)。lint_heapと未実施分がすべて成功。fmt・lint_defaultは修正後workの成功を使用 |
| deriveのbin・helperビルド | 0 | 0.896秒 | [derive-build.json](derive-build.json)。現在のソースからbinとderive_inventoryをビルド |
| derive自己検査 | 0 | 73.743秒 | [derive-selftest.json](derive-selftest.json)。47件成功。A5後に共有入力が変わったため、旧結果を引用せず再実行 |
| 比較道具の自己検査 | 0 | 104.663秒 | [bench-selftest.json](bench-selftest.json)。37件成功、新旧APIの実コンパイルを含む |
| 文書と呼び出しの静的確認 | 0 | 外側未計時（初回の走査0.093秒） | [document-check.json](document-check.json)。4文書の相対リンク・アンカー84件、D1〜D42、28作業・8レビュー、batch5の単体テスト8件・check-formal内の呼び出し1回、bash構文とdiffの空白を確認 |

比較道具の自己検査は、最初のコマンドが引用符のないtest_*.pyをzshで展開できず起動前に終了1となった。パターンを引用符で囲んで実行し、37件すべて成功した。検査対象や期待値は変えていない。

初回の停止は、lib/testsを対象とする各workのlintではなく、G1の全examplesを含むlintで検出した規約違反である。Tyの全バリアントを明示して修正し、lintの許可を増やしていない。最初のchange全体を成功扱いにせず、失敗・未実施の単位だけを続行して成功した。

局所のbatch5はF5Rのworkで書き出された既存の `target/formal-batch5/{corpus,builtins,stdlib,coverage,coverage-program}.json` を用いた。入力は32定義であり、全corpusの比較ではない。無視対象の入力のSHA-256は[input-state.json](input-state.json)に保存した。計数後に得た脱落0を報告していること、単体テスト8件が一度だけ走ったことを局所の出力で確認した。`bash -n scripts/check-formal.sh` も終了0である。シェル全体の実行はZ1のK2に割り当てる。

補助的な進行確認の `ps -axo pid,ppid,etime,pcpu,comm` はsandboxの制限で拒否され、プロセス単位のCPU使用率は取得できなかった。検査コマンドの失敗とは区別し、未完了の検査を成功として数えていない。

## 確定した検査の件数

下表の失敗はすべて0件である。既定・heapの全ターゲットの合計には、wit_transfer_costのexample内にあるテストも含み、同じテストの重複を除いた数ではない。各ターゲットの件数はcheck-summary.jsonに保存した。

| 対象と構成 | 成功 | 既存のignore | 内訳・補足 |
|---|---:|---:|---|
| 既定workspace all-targets | 2918 | 52 | lib1271、全統合40ターゲット378、examples1269。ほかのbin等は0件 |
| heap-verify workspace all-targets | 2932 | 52 | lib1278、全統合40ターゲット378、examples1276 |
| heap-verifyとgc-stressのlib/tests | 1653 | 31 | lib1278、全統合40ターゲット375。call_allocationsの3件は既存のcfgでstress構成の対象外であり、上の二構成で各3件成功 |
| 既定の文書テスト | 34 | 1 | no_run等17件、compile_fail17件 |
| 長い対象・heap-verify | 29 | 0 | lib21、build_info5、declarations1、property_library2。形式化の全件書き出し2件を除外 |
| 長い対象・gc-stress | 29 | 0 | 同じ対象と件数。実行器が成功0件を拒否する条件も通過 |
| Miri・通常確保 | 59 | 1 | runtime::heapとvm::miri_tests。空白追加経路も含む |
| Miri・個別確保 | 52 | 1 | runtime::heap |
| 到達可能性の独立モデルとの比較 | 51 | 2 | BENITOITE_HEAP_RANDOM_CASES=20000 |
| 移行器の自己検査 | 6 / 10 | 0 | source-migrate / try-actions |
| 比較道具 / derive自己検査 | 37 / 47 | 0 | それぞれG1で実行 |
| batch5の局所交換 | 8 | 0 | 独立29定義と、Rust32定義の六入口照合を含む |

fmt・二構成のclippy・規約・Skill生成物の一致・仕様集計・Python構文・依存ライセンス・Leanの既定ビルドとsorry拒否も成功した。仕様集計の受け入れ条件に未記入はない。changeの初回23.003秒と続行4785.634秒の外側の計は4808.637秒であり、間の修正とworkの時間は別である。45〜90分の仮予算を超えていない。

K1は参考記録であり、この成功へ引用していない。K2・最適化ビルドのrelease_stack・候補のCLIと同梱物等の照合は、計画どおりZ1で実施する。

## 関係状態と結果の使用

最終入力は[input-state.json](input-state.json)に固定したHEADと、次のG1の未コミット差分である。取りまとめがこの差分をe0ed5eb2として取り込み、2026-10-24に `git diff --binary baca0076 e0ed5eb2 -- <4パス>` のSHA-256が下記の値と一致することを確かめた（RV-G1のL4）。改造の計画・結果記録は検査の後にも集約のため更新するが、実行するソースとテスト入力はexample修正後に変更していない。

- `crates/benitoite/examples/try_actions_inventory.rs`
- `docs/design/07-quality/07-04-formal-semantics.md`
- `formal/tests/test_batch5_exchange.py`
- `scripts/check-formal.sh`

この4ファイルを含む `git diff --binary B_WORK -- <4パス>` のSHA-256は `cddae71f98dfb21d682d05f2449ef84ebc3f6822c9bcfb506592e9c74bc181a6` である。未追跡の検査入力はない。局所の無視対象入力は別にハッシュを保存した。実行環境はaarch64-apple-darwin、Rust/Cargo 1.98.1、Python3.9.6、Lean4.34.1、nightly1.101.0-nightlyと同じ版のMiriであり、完全な版表示をinput-state.jsonに記録した。

changeから省いたfmt・lint_defaultの引用元は本書の修正後Rust workであり、[work-rust.json](work-rust.json)と本書に件数・指定を残した。同じHEAD・同じ未コミットの検査入力で成功しており、その後の集約文書はfmtとlib/testsのlintの入力を変えないため、G1実装担当Codexが2026-10-23に再実行不要と判断し、2026-10-24の最終確認でも入力ハッシュの一致を確認した。別状態への引用に必要な差分の一覧・SHA-256も上記へ保存した。

過去の作業とレビューの照合元とSHA-256は[work-audit.json](work-audit.json)、shortの比較する完全IDと元のmanifest等のSHA-256は[short-audit.json](short-audit.json)にある。これらは履歴の集約であり、古いworkの引用によってG1の全件検査を省いたものではない。stage S-W・S-C・S-Fは後続の修正で関係状態が変わっているため、旧状態の成功の引用で最終状態の接続を完了扱いにせず、changeの全件と特殊構成で再確認する。

## 計画との差と申し送り

- G1にRV-F5 L1〜L4の修正を加え、局所のPython・シェル検査をwork行へ記した。changeで見つけたexampleの規約違反は原因が確定する小さな修正としてG1に含め、Rustのworkと続行の指定を計画へ追加した。
- A5後に共有入力が変わっているのでderive自己検査を再実行し、47件成功した。shortはW1を比較元にするD41へ読み替え、W2R・A2R・A6R・F3Rを含む後続の比較も対応付けた。G1は処理系本体を変えず、追加のshortは行わない。
- 言語の規則、成功入力の型・エフェクト、Leanの定義・主な定理の前提・結論、公理は変えていない。設計者の判断が必要な停止事項は生じていない。
- G1の独立レビュー、Z1の版上げ・訳・CHANGELOG・実候補のCLIと同梱物・配布、release_stackと全比較K2、受け入れは取りまとめへ渡す。D42によりK1は受け入れの証拠に数えない。
- このリポジトリに対するgitの変更操作、privateとそれを指すリンクの読み取り、docs/todoの更新、版上げ・翻訳・公開の操作は行っていない。build_infoの既存の自己検査は、専用の一時fixture内でGitの状態を作って確認する。

最終の文書確認は相対リンク・アンカー91件を確認し終了0（走査0.1秒未満、外側未計時。詳細はdocument-check.json）。最後のworkのdry-runも、実行済みと同じ単位・コマンドを選び終了0であった。実行済み7コマンドの終了0・ログハッシュ、初回changeの終了1、HEADと4検査入力・5局所交換入力のハッシュ、変更範囲（追跡済み6ファイルとg1の結果記録だけ）も最終確認した。

## 引き渡し

G1の実装・集約・割り当てられた検査に未完了のものはない。設計者の判断を要する未決事項もない。後続の手順を次に示す。見込みは計画の仮予算であり、未測定の時間を確定値にしていない。

| 手順 | 担当 | 見込み時間 |
|---|---|---|
| G1の差分・集約・検査記録の独立レビューと取り込み判断 | 取りまとめ | 20〜40分 |
| Z1の0.0.11・訳・CHANGELOG・同梱物の準備 | Z1担当 | 実装・文書45〜60分、訳の継続は不明 |
| Z1のwork、K2、release_stackと実CLI・配布の照合 | Z1担当・取りまとめ | work8〜20分、K2は不明（仮予算15〜30分）、stack約5分＋ビルド不明、手動照合20〜40分 |
| 候補と証拠のレビュー・委任範囲の受け入れ、設計者への報告 | 取りまとめ | 20〜40分 |
