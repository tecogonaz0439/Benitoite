# A11 の結果

2026-10-25。基準 B_WORK と HEAD は `3104373ac4660b2c64701c02b088ea3f03ab8697`。作業ブランチは取りまとめが用意した `mod012/A11` である。コミット・取り込み・参照の変更は行っていない。

**A11 は未完である。** 番号付け・解析・skip・発見・待ち行列の計上の差を閉じたが、既定の本体上限の境界で、現行 Lean と「全体上限未満なら無関係な関数を追加しても元診断が不変」という完了条件が両立しない例を再現した。設計者の指示「Lean の定義・定理・公理を変える必要が出たら止めて報告する」に従い、Lean の定義と上限を変えずに止めた。閉じた差分の検査結果と、再開に必要な判断を以下に残す。

## 停止理由と再現

`BudgetWhole.modules` はモジュールの分類一操作を計上した状態 `ready` を `definitions` へ渡す。その操作は全体消費に加え、最初の元定義の本体消費にも残る。元定義を終えると `finishBody` が本体消費を初期化するため、二つ目以降の定義にはこの一操作がない。Rust をこの定義へ揃えると、本体上限の直前では、無関係な空関数を先頭へ置くことで対象関数が使える残量が一操作増える。

再現入力は、Integer 引数 `x`、0を束縛する `z`、`x` の別名440個、Unit の破棄102個、括弧付き Unit の破棄2個、末尾の `return 1 div z` である。型とエフェクトの規則を満たす。操作上限・保持上限はすべて D16 の既定値のままである。別名の位置を順に読む操作も含め、本体入口 `analyze_body` 単独では99,999操作を使う。

| 元定義の並び | 対象関数の分類 | 新しい W0401 | 本体 operations / saved / peak | 全体 operations / saved / peak |
|---|---|---:|---|---|
| 対象関数だけ | 本体操作上限の exceeded | 0 | 100,000 / 554 / 1,988 | 100,000 / 554 / 1,988 |
| 空の `unrelated`、対象関数 | 完走 | 1 | 100,000 / 555 / 1,988 | 100,010 / 557 / 1,990 |

両方とも全体操作上限1,000,000・全体保持上限1,000,000を下回る。最初の入力は、除数 `z` を読む最後の操作を拒否して候補を作らない。二つ目はその操作を実行でき、候補を保存する。Rust の公開の型検査から得た内部報告と、既存の Lean の全体入口の実行で、上の数値・分類・警告数が一致した。

- Lean の再現入力: [unrelated-boundary.lean](unrelated-boundary.lean)。`formal/` から `lake env lean -M 12288 ../docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/a11/unrelated-boundary.lean` を実行する。
- Rust の内部報告の再現記録: [unrelated-boundary-rust.log](unrelated-boundary-rust.log)。既存の `check_files` から型検査し、内部報告と診断を表示した一時的な検査である。この表示用のテストと本番の表示コードは最終差分に残していない。
- Lean の再現記録: [unrelated-boundary-lean.log](unrelated-boundary-lean.log)。中心定理・実行定義・公理を変更せず、既存の `BudgetWhole.analyze` を呼んだ。
- CLI 用入力の生成: `python3 docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/a11/reproduce-unrelated-boundary.py`。既定では `<tmp>/a11-boundary-repro/first.bnt` と `prefixed.bnt` を作る。CLI の入力には同じ空の main を末尾に足すため、上表の全体消費の数値とは区別する。
- 実 CLI で `target/debug/benitoite check --report=json <入力>` も実行した。両方とも検査本体は終了0、`executed=false`、`complete=true` であり、`first.bnt` の診断は0件、`prefixed.bnt` は W0401 一件であった。外側0.093秒・0.081秒。記録は [unrelated-boundary-cli.log](unrelated-boundary-cli.log)、報告は [first](unrelated-first-report.json) と [prefixed](unrelated-prefixed-report.json) に残す。

再開には、モジュールの分類を各元定義の本体消費から切り離すよう Lean を先に改めるか、無関係関数についての完了条件を本体上限の境界では限定するか、取りまとめと設計者の判断が必要である。前者なら Lean の実行定義・独立例・対応文書の変更とレビューの後に、Rust の同じ変更と予算の境界例を揃える。後者を担当の判断で採ったことにはしない。

## 閉じた差

- `IdentityMap::build` で全番号表を先に作る本番の経路を外した。式の scope の枠、`identify` の番号操作と対応保存、式の訪問を、この順で一つの走査にした。`save_candidate` は現在の出現番号から直接対応を読む。定数の各展開も別々に計上し、元 NodeId による診断の統合をその後に行う。
- 括弧の連なりはループを保ち、各段の枠を内側の処理が終わるまで保持する。Block の各構成子も、分類一操作と枠を一つずつ数える。従来の「容器＋文」の二重の分類を外し、文の連鎖の各段の枠を保持する。
- 左辺が継続しない二項演算、選ばれない if・短絡・match の枝、return 後の残り、別本体の内容を、`BudgetWalk` の skip と同じ順で番号だけ走査する。容器の分類・枠の停止も unidentified とし、値の解析の枠・訪問の exceeded と分ける。
- 未対応の子の独立入力、合成した concatenate・補間変換関数・入れ子の with も、その実際の訪問で番号を保存する。環境の忘却・結果枠・候補を計上し、親へ値や return を戻さない。
- モジュールの分類を加え、元定義の出力枠を Lean と同じ「枠・分類・保存一項」にした。従来の余分な保存一項を外した。入口・親解析・発見・待ち行列を同じ本体予算で処理し、別本体だけを新しい本体予算へ切り替える。
- 全体の残量は scope が一時保持を返した後に判定する。保持上限の停止だけで後の段を止めず、`BudgetWhole` と同じ位置で exhausted を判定する。`Report.remaining_modules` に未着手のモジュールを残し、同じモジュールの未着手定義を示す `remaining` と分けた。入口作成で止まった定義には、未開始の親の BodyReport を作らない。
- 発見が途中停止して親の終端がない場合も、別本体の解析で実際に取得した接頭辞を元位置へ戻す。保存済み候補が診断から落ちる例を、予算の比較に加えた診断件数の確認で検出して修正した。
- 非整数の局所値が未知であることを、未対応構文の訪問と区別した。正常な local の処理だけで unsupported を立てない。
- 02-05「区間解析の駆動と予算」「区間解析の式の識別」を、以上の実装へ合わせた。D16 の既定値、診断用由来の最大8件と予算外の扱いは変えていない。

深い式でスタック超過を起こした中間実装は修正した。合成した根、算術結果の合成、if の後半と合流を再帰中の枠から分け、通常の Expr の振り分けを合成節点の振り分けから直接呼び分ける。Block.last は文列の合成値を持たない小さい処理にした。論理上の scope と予算の計上は変えていない。450段の加算・900段の括弧・300段の lambda・450段の if・200段の match の腕・450段の match の照合値を含む既存テストの入力・期待値・通常スレッドのスタックサイズは変更していない。

## 固定例の比較とテストの関門

`BudgetAnalysisExamples`・`BudgetChildrenExamples`・`BudgetWholeExamples` などの固定例から、Rust で受理される入力を [budget-reference.lean](budget-reference.lean) にまとめた。Rust の計上を期待値の生成元にせず、既存 Lean の入口を実行して固定値を得た。

- 本体24種類・2,346ケース: 括弧、算術、未到達部分、比較・短絡、bind/shadow、match/guard、独立入力、lambda、定数の比較と複数展開、未対応の乗算・負号、リスト展開、補間、穴、try と説明、with と入れ子、レコードパターン、条件分岐内の return 後の走査。
- 全体3種類・636ケース: 二つのモジュールと三つの元定義、lazy の発見・待ち行列・解析、handler、引数と捕捉値を持つ lambda。発見済み未解析・次の定義・次のモジュールを分け、停止後の候補が利用者の診断まで渡ることも確認する。
- 操作数・保存数・最大同時保持・次番号・exceeded/unidentified と資源・範囲・独立入力の保存順と停止・候補のキー・未対応の印を比較する。全体の表では各段の分類、発見と待ち行列の未着手、入口の準備の有無、未解析参照も比較する。
- 本体／全体の操作／保持の四つの上限を独立に動かす。0から最初の完走上限の直後までを含めるため、各資源の直前・ちょうど・直後を含む。深さは200で固定し、この表を深さ停止の全比較とは扱わない。

期待値は `crates/benitoite/testdata/interval-budget/body.tsv` と `whole.tsv`、テストは `interval/tests/budget_reference.rs` に置く。kind は0=本体操作、1=本体保持、2=全体操作、3=全体保持である。body の列は name/kind/cap/operations/saved/peak/next/stop/warnings/independent/unsupported、whole は name/kind/cap/operations/saved/peak/bodies/warnings/phases/discovered/pending/remaining/stop/modules である。停止の数値は両側の再現コードで明示し、0は成功、10は未着手、9は深さ停止とする。

再生成時は `budget-reference.lean` の標準出力を name と kind でまとめる。body は stop=0となる最小 cap の一つ後まで、whole は cap=200の最終要約（cap を除く全列）と一致する最小 cap の一つ後までを残す。cap の選択は Lean の実行結果によるものであり、Rust の結果から期待値や上限を調整していない。

通常の診断だけでは、停止位置・分類・保存済みの接頭辞・各段の未着手を検査できないため、この内部報告の比較を型検査の境界に置いた。準備は本物の名前解決・Body・solver・型の具体化・入力収集を使う。全体の反復では同じ解決済み Body から各試行の入力を収集し、本番の BodyInput に Clone や検査用フラグを足していない。

新しい本体比較テストを基準版の一時的な写しへ適用すると、空本体・操作上限2で、基準版は unidentified、独立期待値は exceeded となって終了101で失敗した。修正後は通る。記録は [regression-before.log](regression-before.log)である。既存の二つの予算テストは、同じ入力と上限を維持し、モジュール入口と prepareRoot の実際の停止位置へ期待値を合わせた。テストの削除、入力・上限・ignore の緩和はしていない。

無関係な関数を**末尾**へ加えた通常入力では、診断の一次・補助位置・注記と元本体の消費が同じであることを確認した。この成功を、先頭への追加と本体上限の境界まで含む完了条件の証拠にはしていない。

## 検査

Rust は `rustc 1.98.1 (48a229cea 2026-09-01)`、Cargo は `1.98.1 (797e8a9bc 2026-08-05)`、rtk は0.49.0である。検査の対象・構成は計画の work A11 の行に従う。作業末の基準はすべて同じ B_WORK とし、`--test` を省いて全統合を選んだ。

作業末の検査は `/usr/bin/time -l` で包んだ。ただしサンドボックスが `sysctl kern.clockrate` を `Operation not permitted` とするため、最大常駐量を取得できなかった。検査本体の終了状態を別ファイルへ保存し、time の終了1と区別した。

| コマンド・範囲 | 結果・時間 | 記録 |
|---|---|---|
| `scripts/check.sh --level work --base 3104373ac4660b2c64701c02b088ea3f03ab8697 --dry-run` | 終了0。fmt、examples込みlint、lib全件、全統合、source_rules、skill_generated、spec_tally | [work-dry-run.log](work-dry-run.log) |
| 初回の同じ work | lint の列挙型の包括的な分岐4箇所で終了1。外側11.771秒。構成子を明記して修正し、許可は追加していない | [work-initial.log](work-initial.log) |
| 2回目の同じ work | lint 成功後、lib の深い式のテストでスタック超過。外側42.119秒。上記の枠の分割で修正 | [work-stack-failure.log](work-stack-failure.log) |
| 修正後の小予算比較 `cargo test -p benitoite --lib budget_reference -- --nocapture` | 終了0、3件成功、テスト1.47秒、ビルド11.02秒。2,982ケースと通常の無関係関数の追加 | [local-reference.log](local-reference.log) |
| 修正後の通常スタックの深い式の既存テスト | 終了0、1件成功、テスト0.59秒。後の work でも一時表示を除いた同じ入力を実行する | work に集約 |
| `cargo test -p benitoite --test call_allocations long_constant_chain_has_bounded_check_allocations -- --exact --nocapture` | 途中確認で終了0、1件成功、テスト8.14秒。20,000定数は442,591,117バイト、上限536,870,912バイト | [allocations-chain.log](allocations-chain.log) |
| `cargo test -p benitoite --test call_allocations repeated_constant_diagnostics_share_bounded_origin_work -- --exact --nocapture` | 途中確認で終了0、1件成功、テスト1.25秒。5,000定数・1,000診断は254,825,372バイト、上限268,435,456バイト | [allocations-origins.log](allocations-origins.log) |
| `lake env lean -M 12288 Benitoite/Interval/BudgetAnalysisExamples.lean` | 検査本体は終了0、外側0.695秒 | [lean-examples.log](lean-examples.log) |
| `lake env lean -M 12288 Benitoite/Interval/BudgetChildrenExamples.lean` | 検査本体は終了0、外側0.450秒 | 同上 |
| `lake env lean -M 12288 Benitoite/Interval/BudgetWholeExamples.lean` | 検査本体は終了0、外側0.369秒 | 同上 |
| `lake env lean -M 12288 <改造>/a11/budget-reference.lean` | 検査本体は終了0、外側4.190秒。固定表を再生成できることを確認 | 同上、固定値は上記のTSV |
| `lake env lean -M 12288 <改造>/a11/unrelated-boundary.lean` | 検査本体は終了0、外側0.822秒。停止理由の境界例が Rust と一致 | [unrelated-boundary-lean.log](unrelated-boundary-lean.log) |
| 修正後の同じ work | **検査本体は終了0**、外側423.238秒。time の表示は423.23 real / 1292.94 user / 52.86 sys、最大常駐量は取得不能。time 自身は前述の環境制限で終了1 | [work.log](work.log)、[work-run.json](work-run.json) |
| work 内の全 lib | 1,298件成功・失敗0・ignored 21、テスト69.79秒 | 同上 |
| work 内の全統合 | 全40ターゲット、計382件成功・失敗0・ignored 10。割り当て量の3件も成功 | 同上 |
| work 内の fmt・examples込みlint・source_rules・skill_generated・spec_tally | 全選択単位が成功。lint は7.17秒。仕様集計の未記入条件は none | 同上 |

失敗後の実装変更で fmt・lint・lib が古くなり、統合以後はまだ未実施だったため、最終実行は同じ自動 work の指定で行った。最終 work の途中で、既存の発見のテストに残っていた「二走査の違い」という古い説明コメントだけを更新した。検査入力・テスト本体・処理系の実装は、最終 work の開始後に変更していない。終了後の変更は結果とログの保存だけである。

Lean はすべて直列に実行した。Lean の既定全ビルド、Rust/Lean の全比較 X02・check-formal、heap/stress、stage/change/release、性能測定は先取りしていない。今回の保持は Rust の整数・AST参照・所有する表であり、VM値とヒープの不変条件を変更していない。

すべての保存ログの手元の絶対パスを `<repo>`・`<home>`・`<tmp>` に伏せた。本番・テスト・固定表・再現入力の SHA-256 は [input-sha256.txt](input-sha256.txt) に置く。

本番 Rust は追加879行・削除1,091行、テスト Rust は追加576行・削除22行である（新しいテストファイルを含む）。旧 Walker の独立した本番走査を外し、番号だけの走査を発見の構造走査と共有した。テスト関数の削除はなく、削除行は既存の予算期待値と準備の処理の置き換えである。

## 計画からのずれと申し送り

- 計上の順序を一つの走査へ変えるため、指定の budget.rs/mod.rs だけでなく、identity/flow/discovery、独立入力と match、入力を作る既存の検査補助も変更した。全体駆動と通常の型検査の署名、言語の規則、実行時の検査は変えていない。
- 定数内の bind を含む Block は Rust の定数宣言の E0433 により受理されない。受理前に拒否される入力を型検査後の比較へ混ぜていない。定数内の比較・複数参照・展開中の停止・元 NodeId による統合は受理される入力で検査し、bind の計上は通常本体・独立入力・構造パターンで検査した。無条件の return の直後の文も E0439 となるため、受理される条件分岐内の return で後続の skip を検査した。言語の規則を変える理由にはしていない。
- `Report.remaining_modules` と、入口作成中の停止では親の BodyReport がないことを A12 へ申し送る。`prepared`・`discovery`・`queue`・`embedded_stop` と本体自身の分類を分けて読む。全体停止の事象数を未解析本体の数へ重ねない。既知の未解析参照と保存済み候補の保持までを本枝で確認し、CLIの非実行報告の集計は A12 に残す。
- X02 は本枝の固定例を全関係定義の比較に使えるが、2,982ケースの成功を全構文・任意深さ・全関係定義の比較完了とは扱わない。由来分の事後減算や予算境界の除外は行っていない。
- **未解決は先頭への無関係関数の追加と本体上限の境界の両立だけである。** 次の枝は、停止理由の判断と、必要なら Lean の `BudgetWhole.modules` と独立例・写しの修正を先行させる。そのレビュー後、Rust のモジュール入口の本体消費の扱いと固定表を揃え、同じ境界例を受け入れ条件にする。判断前に A11 を完了・受け入れ済みとして扱わない。
- 取りまとめが独立レビュー・判断・受け入れを担当する。担当は `private/` とそれを指すスキルを読まず、git の変更操作、docs/todo の更新、コミット・取り込み・公開を行っていない。基準版での退行確認には、読み取り専用の `git archive` で一時的な写しを作った。

## 取りまとめの判断（2026-10-25）

閉じた差（番号付けと値の解析の一体化、括弧・文列の枠の数、未到達部分の skip、独立入力・発見・待ち行列・出力枠の計上、停止後の候補の保持）は、固定例の比較（本体2,346件・全体636件）と work で確かめたので、この状態を A11a として取り込む。残る一点は Lean の `BudgetWhole.modules` が、モジュールの分類の一操作を `finishBody` で閉じずに最初の元定義の本体の消費へ引き継ぐことである。取りまとめは、分類が通った後の状態を `finishBody` で閉じてから `definitions` へ渡すよう Lean を改めると決めた（中心二命題・公理・既存の主定理の言明は変えない予算の駆動の定義の変更であり、取りまとめの判断の範囲）。A11b で Lean を先に改めてビルドと独立例を通し、続けて Rust と固定表を揃え、先頭に無関係な関数を置いても元の診断と本体の消費が変わらないことを受け入れの条件にする。完了の条件を本体上限の境界で限定する案は採らない。
