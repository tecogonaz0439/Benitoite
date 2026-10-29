# R40.1 診断と拒否理由・修正案

## 作業と基準

B_WORK は `c2debc9200e7db6aacf4dde10b94eaf330270654`、比較の開始版は `6124775788579e60530f55fb85570f26ef7fa900` である。R40.1 の実装・関連入力・現行設計書・生成物・W-40D を完了した。E0521 の自然な到達と案内の効果など、指定された未確認の範囲は下の申し送りに残す。

`private/` と `docs/todo/` は読んでいない。公開の `test-audit` と `japanese-tech-writing` に従った。依存・Lean・scripts は変更せず、git の状態を変える操作も行っていない。

## 直した診断

文言の型板は `diag::codes`、補足の英文は `typeck::text`・`resolve::text`・`types::text` に置く。診断の理由の分類と受理規則は変えない。

| 対象 | 前の文言・表示 | 後の文言・表示 |
|---|---|---|
| E0513 | `invalid type arguments for effect ... (expected {count})` | `invalid type or scope arguments for effect ... (expected type argument count: {count}; scope arguments are not allowed)`。利用者エフェクトの範囲引数も拒否することを示す |
| PathIn の E0520 | `expected path string literal` | `expected exactly one path string literal`。RequestIn もホストとポートの一組と明記し、効果の複数範囲の略記とは区別する |
| Top の File.Read による E0519 | `declare the same effect without scope arguments ... or use a callee whose declared scope ...` | 契約を保つ案は `File.readTextIn`・`Scope.checkPathIn`・成功型への範囲の注釈。Top を許す案は周囲の `uses` の範囲引数を省略する変更と分ける |
| Top の File.Write／Http.Connect | File.Read と同じ一般的な案内 | `File.writeTextIn`／`Http.sendIn` と対応する検査を案内する |
| 純粋な必須判定の E0519 | note と help がともに `the range arguments of this direct call must cover ...` | note は規則の説明、help は被覆失敗・条件の未知・由来の未知・番号付け停止・局所解析の超過ごとの修正案とする |
| 射影・拡大の由来の未知 | 実行できる修正案がない | 入れ子は呼び出しを `bind` の右辺へ出す。狭い引数は裸の型へ変える案と、同じ狭い型へ転送して契約を保つ案を分ける。Top 入力を拡大する場合は戻り型も Top とする |
| 狭い節の引数 | 節の制限を説明しない | `bind` だけでは由来を得られないこと、裸の型にするには保護本体が Top を選び、IO の上限も広がる場合があることを明記する |
| 動的な検査条件 | 射影の位置の修正と同じ案内 | リテラルまたは静的に既知の定数の条件と範囲の注釈を使う案、結果を Top にする案を示す |
| 局所解析の超過 | `local Scope analysis exceeded ...` | `the final local Scope analysis Run still exceeds ...`。本体／全体と操作数／保持数、由来の忘却とリテラルの保持を示す |
| 戻り値の補助制約 | `argument 1 must match the parameter type of the called function` | `the result of this scope check or widening must match its annotated or inferred type`。`ScopeResult` と呼び出し位置を使い、実引数の制約と分ける |
| E0521 | `cannot stabilize the scope indices selected for this handle` | `cannot determine consistent scopes for this handler`。ラベル・説明も scopes にそろえる |
| 範囲変数の内部表示 | `RangeIndex::suffix` の `format!("[rvar {i}]")` | `types::text::range_variable` へ移す。表示は同じであり、利用者の構文にはしない |

E0521 の自然な到達例と案内による解消の効果は未確認である。文言の整合だけを行い、収束を確認したとはしない。番号付け停止の全規則 Top と、最後の Run の超過による Top を区別する。内側だけの超過から外側が回復したときの内側 Top は `unknownSource` のままである。

## 案内の確かめ

主な確認は `tests/cli_process/scoped_diagnostics.rs` の二つの表へ接続した。CLI の本物の `check --diagnostics=json` を使い、終了状態・英文・欄・元ソースの位置と、案内を当てた後の受理を確認する。既存の型検査の規則の検査は重ねず、本番へテスト専用の入口を加えていない。E0513 の既存 golden 三件は主文だけを追随した。

| 拒否・確認対象 | 当てた修正と結果 |
|---|---|
| `Ask["/a"]`／PathIn の複数範囲 | E0513／E0520 のコードと新しい期待形式、元の引数位置を確認した |
| `File.Read["/**"]` の下の旧 `readText` | `checkPathIn` の成功型に `/**` を注釈して `readTextIn` に変更すると元の `uses` で受理。`uses File.Read` へ拡大した別入力も受理 |
| 同名の一原子／複数原子の被覆失敗 | `notCovered`／`atomicCoverOnly` と欄を確認。複数原子の和で覆えるという断定はしない |
| Path／Request の射影・拡大の入れ子 | 各呼び出しを `bind` の右辺へ移すと受理 |
| 狭い関数引数の射影・拡大 | 引数を裸の型へ変更すると受理。拡大は戻り型も裸へ変更 |
| 狭い節引数の射影・拡大 | `bind` 済みでも `unknownSource`。呼び出し元と IO を Top にした別入力は受理。同じ狭い型へ転送した入力も受理し、こちらは狭い契約を保つ |
| 既知の成功値を覆わない拡大先 | `notCovered`、元と行き先の範囲、成功検査と必要な型注釈の補助位置を確認 |
| 保持数の超過 | 513個の検査値を保持する入力で `budgetExceeded` と body/items を確認。戻り型の範囲引数を省略する修正は受理 |
| 番号付けの停止 | 共有 const の展開が 200,000 イベントを超える入力で全規則 Top と番号取得不能を確認。const の参照を別の関数へ分ける修正は受理。長大な恒久テストは加えず実入力とログを保存 |
| 戻り値の誤った成功型 | `Result[Integer, ScopeError]` の注釈で E0401 が `ScopeResult` の説明と呼び出し位置を示す |

入力は [probes/](probes/) に置く。最初の読解・局所確認は `diagnostic-probes*-initial.log`、番号付けと戻り値は [diagnostic-budget-and-result.log](diagnostic-budget-and-result.log)、修正前の失敗は [diagnostic-regression-before.log](diagnostic-regression-before.log) に記録した。修正前の証拠は、比較器が明示の B_WORK から作った archive の CLI で再確認した。旧 debug バイナリだけを版の根拠にしていない。

## DET-05 の欄と位置

既存の診断 JSON の `notes` に欄名付きで補足し、JSON の必須構造や形式の版は変えない。E0520 の期待形式は主文、`found` は注記、`reason` は主文と注記に示す。

| 欄・位置 | 効果の被覆 | 純粋な必須判定 |
|---|---|---|
| 一次位置 | 覆われなかった原子が生じた呼び出し・引数 | 拒否した規則の呼び出し |
| 補助位置 | 実際の `uses` の該当原子。同じ略記位置は重ねない | 取得した契約の型注釈と、同じ成功値の由来となる検査 |
| `requiredUpperBound` | 周囲が要求する上限の同名原子 | 型の制約で確定した契約。拡大は元と行き先を明記 |
| `knownUpperBound` | 流入する効果原子 | 規則が選んだ範囲。未知・超過は Top と示し、空集合にはしない |
| `uncoveredAtom` | 覆われなかった原子 | 効果の原子を要求しないため省略 |
| `reason` | `notCovered`・`atomicCoverOnly`・`unknownSource` | `notCovered`・`unknownSource`・`budgetExceeded` |
| `source` | 原子を生じた位置と流入の説明 | 既知の条件／成功検査の定義と先行順番号／未知の条件・由来／番号付け停止／最後の Run の超過 |
| 予算区分 | 対象外 | 局所解析の body/whole と operations/items、番号付けの numberingLimit を区別 |

型の注釈だけから成功の所属を作らず、診断用に保持する注釈と既存の成功由来だけを読む。関数の戻り型については、該当型変数に既に保存された `Return` 等の明示的な関連位置を補助位置へ使い、別の同型注釈へ推測で結び付けない。[戻り注釈の確認](diagnostic-return-annotation.log)では、番号付け停止と小さい未知条件の両方で、拒否の理由を保ったまま実際の戻り型注釈を表示した。`Required.ofIndex`・`atomFailure` に対応する分類は変更していない。名前不足の E0501/E0502、CLI の E0512、旧 Scope の E0459〜E0462 は従来の経路を保つ。

## Show の判断

`Http.RequestCheckError` の `Show` は追加しない。現状は `Http -> Json -> Trait -> Scope` の依存であり、ScopeError の実装と同じ Trait 側へ置くと Http への循環が生じる。Http 側に実装する案は可能だが、表示の形式と配置を新たに決める変更になる。この枝では既存の構成子で扱えることを確認し、標準の表示は増やさない。

[request-error-show.bnt](probes/request-error-show.bnt) は直接の Show 呼び出しを E0705 で拒否し、[request-error-match.bnt](probes/request-error-match.bnt) は二構成子を `match` して、内側の ScopeError にだけ既存の Show を使って受理された。[diagnostic-show.log](diagnostic-show.log) に残した。V10.2 はこの判断と通常文書・Skill・訳の説明を照合し、標準 Show の追加を改めて扱うなら配置と表示の契約も検討する。採否の判断を未決のまま残したわけではない。

## 探査・生成物・検査

公開の `ReasonKind` に `ScopeResult` を追加し、全ての exhaustive な読者を追随した。`timing_probe.rs` 自体の変更は不要であった。比較器 README の自己検査を一度実行し、39件成功、終了0、外側94.067秒であった。開始版と B_WORK の probe はともにビルド・実行成功であり、`bridge-shared-8` も確認した。性能の標本採取と short の比較は行っていない。

コマンドは [compare-selftest.json](compare-selftest.json)、生ログは [compare-selftest.log](compare-selftest.log)、二版のビルドと探査の記録は [probe-builds.json](probe-builds.json) に置く。RSS 補助値は 2,971,205,632 bytes = 2,833.5625 MiB であり、一括実行の常駐量の合計ではない。

中間の `cargo check -p benitoite` は終了0、Cargo 表示23.97秒（[typeck-check.log](typeck-check.log)）。局所の CLI 3件は初回終了0・外側19.05秒、その後の補強を含む再実行も終了0・外側12.02秒（[初回](diagnostic-cli-tests-initial.log)・[再実行](diagnostic-cli-tests-final.log)）。これらは最終状態全体の W-40D の代わりにしない。

戻り注釈の補助位置を加えた後の `cargo build -p benitoite --bin benitoite` は終了0、外側39.130秒、RSS補助値3,848,339,456 bytes = 3,670.0625 MiB（[annotation-build.json](annotation-build.json)）。`gen_skill` は終了0、外側7.917秒（[gen-skill.json](gen-skill.json)）であり、診断の表から `skill/references/diagnostics.md` を更新した。他の生成物も生成器を通し、内容の差分はなかった。`cargo fmt -p benitoite` は終了0、外側2.657秒（[format.json](format.json)）。

作業末のコマンドは次の指定である。[run-record.py](run-record.py) がこのコマンドを子として実行し、子の `returncode` を `check_exit_code` に直接記録する。この記録器を `/usr/bin/time -p` で包む。`time -l` は使わない。最大常駐量は macOS の `getrusage(RUSAGE_CHILDREN).ru_maxrss` の補助値であり、原値の単位は bytes、MiB は 2^20 bytes で換算する。子孫の最大値であり、同時実行の全プロセスの合計ではない。

```sh
scripts/check.sh --level work --base c2debc9200e7db6aacf4dde10b94eaf330270654 \
  --test cli_process --test test_command --test golden --test spec_examples \
  --test reference_examples --test skill_docs --test package_command \
  --test desugar_export --test checked_args --test declarations
```

同じ指定に `--dry-run` を加えた確認は終了0であった（[work-dry-run.log](work-dry-run.log)・[計時](work-dry-run.json)）。Rust と診断の表の変更を理由に、fmt、既定構成の clippy、lib 全件、指定の統合10対象、source_rules、skill_generated、spec_tally を選択した。仕様例は統合対象に含むため、別の重複実行は省略された。依存・Lean の変更はなく、形式化や勧告の検査は選択されなかった。

初回の W-40D は終了1、外側9.469秒、RSS補助値1,657,356,288 bytes = 1,580.578125 MiB（[work.json](work.json)・[work.log](work.log)）。fmt は成功し、clippy の列挙型のワイルドカード3件と `manual_contains` の警告1件で停止した。後続の lib・統合・ソース規約・生成物・仕様集計は実行されていない。列挙型を明示的な変種の並びへ、検索を `contains` へ直し、免除は追加していない。修正で fmt の結果も古くなり、残りは未実行だったため、同じ指定で再実行した。

再実行は check.sh 自身の終了0、外側275.005716583秒、子の経過274.978014542秒、`time -p` の real は275.00秒であった。RSS補助値は4,527,210,496 bytes = 4,317.484375 MiB（約4.2163 GiB）である。[work-retry.json](work-retry.json)・[生ログ](work-retry.log)・[time の出力](work-retry-time.log)に保存した。約3〜5分の検査見込みの範囲内である。

| 検査 | 成功 | 失敗 | 無視・補足 |
|---|---:|---:|---|
| 既定 lib 全件 | 1,392 | 0 | 22 ignored |
| checked_args | 11 | 0 | 0 |
| cli_process | 40 | 0 | 新しい二つの表と戻り型注釈の補助位置を含む |
| declarations | 33 | 0 | 1 ignored |
| desugar_export | 44 | 0 | 1 ignored。形式化の全書き出しはこの枝の対象外 |
| golden | 2 | 0 | 既存のゴールデン実行器と構成要素の検査 |
| package_command | 16 | 0 | 0 |
| reference_examples | 1 | 0 | 0 |
| skill_docs | 8 | 0 | 0 |
| spec_examples | 7 | 0 | 0 |
| test_command | 52 | 0 | 0 |
| fmt・clippy | 終了0 | 0 | clippy は lib/tests/examples、no-default-features + gc-mark-sweep |
| source_rules・skill_generated | 終了0 | 0 | 既存の免除の規約と生成物の一致 |
| spec_tally | 終了0 | 0 | 自己検査成功、初回リリースの未記入完了条件なし。既存のテスト参照のない節の一覧は生ログに残す |

統合10対象は計254件成功・2件 ignored、lib と合わせて1,646件成功・24件 ignored である。指定した検査は全て成功した。入力の大きさ、予算、ignore、期待する拒否を成功のために緩めていない。確認した20ファイルの内容と SHA-256 は [checked-inputs.json](checked-inputs.json) に保存した。

## 失敗と修正

修正前の版では、新しい英文・修正案・DET-05 欄のアサーションが意図どおり失敗することを確認した。手動入力の初稿では `main` がなく E0414、Show の入力では同名束縛により E0338 が出た。`main` の追加と束縛名の修正後に、本来の拒否／受理を確認した。拡大先の注釈がない試行は E0407 となったため、ScopeResult の確認には成功型だけを誤った注釈にする入力を使った。戻り注釈の局所確認では `--report=json` を `--diagnostics=json` に修正した。W-40D 初回の clippy の失敗と修正は上に記した。探索時と正式検査の失敗はログから消していない。

独立した英文・案内レビューと、テストのレビューを別担当が行った。[診断レビュー](review-diagnostics.md)と[テストレビュー](review-tests.md)に、指摘と対応を保存した。戻り型も Top を要する案内、効果ごとの入口、未知条件の案内、一次／補助位置を同じ変更で直した。

テストの削除はない。[line-counts.json](line-counts.json) は本番・テスト・生成物・設計書の増減を区別する。テストは CLI の二つの表と E0513 の既存 golden にまとめた。所属の規則を模倣する検査や、テストからしか使わない本番の入口は増やしていない。

## ずれ・停止条件・申し送り

- R40.2 は `aggregateEffects.expanded` が範囲を表示せず名前集合を示す点と、任意の `bounds` の区別を受け持つ。今回の診断用 `source` を権限の集合へ混ぜない。
- R40.2 は `readTextIn`／`readBytesIn` の資源停止の主文に共有する旧本体名が出る点を受け持つ。この枝では資源停止の文言を変えていない。
- R40.3 は最終の通常・集約・test の報告、段の stage と独立レビューを行う。K10 は Rust/Lean の理由と最終の関係状態の全比較、V10.2 は Show の判断・通常文書・訳を照合する。
- E0521 の自然な到達例と案内の解消効果は未確認である。節引数の一時的な制限を恒久の規則と説明しない。
- 許可された追随として `resolve/scope.rs`・`resolve/text.rs`・`types/mod.rs`・`infer.rs`・`solve/effect_key.rs` も変更した。許可範囲の外へ編集を広げていない。
- 健全性、Lean の規則・仮定、四理由、JSON の既存の意味、公開 IO の契約は変更していない。停止条件への該当はない。`check-formal.sh`・`lake build`・short はこの枝では実行していない。
- 新しい `CARGO_TARGET_DIR` は設定していない。基準版の展開は既存の比較器の `target/bench/` の下で行った。自己検査の一時ディレクトリは実行器が終了時に削除し、`target/` の外に一時のビルドや基準版の展開を残していない。`probes/` は結果の根拠として保管する入力である。

## 時間

着手時の正確な時計は採取していない。最初の時計の採取は 2026-10-29 18:07:20 JST であり、それ以前に規約・計画の読解を始めている。着手からの外側の所要は約30分、検査待ちを除く経過としての能動時間は約20分の概算である。診断・文書・テストを分担して並行したため、担当別の能動時間の厳密な合算値は未採取である。見込みの上端の2倍（能動12時間）には達しておらず、時間による中断はない。

作業末の正式検査は初回9.469秒と再実行275.006秒、比較器の自己検査は94.067秒である。その他のビルド・局所検査・生成の時間は上のログに分けた。これらの待ちには記録の整理と並行した区間があり、単純な合算を外側の所要とはしない。設計者の回答待ちはない。最終記録時刻は 2026-10-29T18:28:25+09:00 である。


## R40.1b: RV-R40.1 への対応

2026-10-29、担当 Codex。B_WORK・HEAD は `c2debc9200e7db6aacf4dde10b94eaf330270654`、ブランチは `m013/r40.1` のままである。[RV-R40.1](../reviews/RV-R40.1.md) の中1〜中3・軽1〜軽8を対象とした。開始時の HEAD・ブランチ・index と、変更しないレビュー記録・`rv-probes/` の SHA-256 は [開始状態](r40.1b-start-state.json) に保存した。前回の記録は当時の結果として残し、案内と検査の現状は本節を正とする。

### 対応と前後の文言

中1・中2は E0519 の `scope_unknown` と 02-10 を修正した。入れ子は呼び出しを `bind` の右辺へ出す。狭い型の注釈だけを持つ関数・節の引数は `bind` だけでは由来を得ない。狭い契約を保つなら、その位置で射影・拡大せず、同じ狭い型を受け取る範囲付きの入口へ渡すか、検査済みの値が束縛されている呼び出し元で拡大し、引数を広い型にする。全対象を受け取る場合は引数の範囲引数を外し、呼び出し元で Top へ拡大して渡す。節の引数なら保護本体も Top を選び、`uses` の上限を広げる必要がある場合もある。前の「同じ狭い型を受け取る関数へ値をそのまま渡す」は、転送先で射影すれば再び拒否されるため、範囲付き IO の入口まで明示した。

中3では、主文と `scope_rule`・`atomic`・`unknown`・`uncovered` の量を欄名と対応させた。`requiredUpperBound` は確定した契約、`knownUpperBound` は局所規則が選んだ範囲または流入する効果原子である。拡大では行き先が元の契約を覆う必要もあるため、その条件も主文と規則の説明に残した。`text::SCOPE_REQUIRED_UPPER_BOUND` は欄名そのものの定数なので値を変えていない。ラベル用の文の定数 `SCOPE_RULE_CONTRACT` を `the required scope contract` から `the annotated scope contract (requiredUpperBound)` へ直した。

| 指摘・対象 | 前 | 後 |
|---|---|---|
| 中1・中2 `scope_unknown` | `one option is to remove its scope arguments`／`forward the value with the same narrow type instead` | `bind` だけでは由来を得ないことを明記し、`pass it unchanged to a scoped entry that accepts the same narrow type` と `widen it in the caller where the checked value is bound and declare the parameter with the wider type` を示す。Top にする案には呼び出し元の明示拡大も必要とする |
| 中3 主文 | `the range arguments ... do not cover the required scope` | `the scope arguments of the annotated contract ... (requiredUpperBound)` と、覆う対象の `the scope selected by the local Scope rule (knownUpperBound)` を明示する。拡大は元と行き先の被覆として示す |
| 中3 `scope_rule` | `the range arguments of this direct call must cover the ranges selected by the local Scope rule` | `the scope arguments of the annotated contract (requiredUpperBound) must cover the scope selected by the local Scope rule for this call (knownUpperBound); for widening, the destination must also cover the source contract` |
| 中3 `unknown`・`uncovered` | `the required scope is Top`／`covers the required scope` | `the incoming scope (knownUpperBound) is Top`／`covers the incoming scope (knownUpperBound)`。周囲の上限を `requiredUpperBound` と明示する |
| 軽1 `scope_coverage` | `use check conditions and a result annotation covered by it` | `change the check conditions so that the annotated result scope covers them` |
| 軽1 `scopes` | `use an entry whose declared scope it covers` | `use a callee or entry whose declared scope is covered by one surrounding atom` |
| 軽2 予算超過の案内 | `split this definition into smaller definitions to retain local provenance` | 同文に `(this helps only if the check conditions or checked values are statically known after splitting)` を加える |
| 軽3 `scope_budget`・`SCOPE_BUDGET_SOURCE` | `the final local Scope analysis Run`／`the final local analysis run` | 両方を `the final pass of local Scope analysis` にそろえる |
| 軽4 `top`・`top_write`・`top_endpoint` | 範囲付き入口と、周囲の `uses` を Top にする案 | 契約を保つ案に or narrow the callee's `uses` annotation を加える。文中の `uses` をコード表記にそろえる |
| 軽5 E0401 ScopeResult | `expected Scope.PathIn["/data/**"], found Integer` | `expected Integer, found Scope.PathIn["/data/**"]`。表示だけを通常の E0401 と同じ向きにする |
| 軽6 補足の順 | 純粋な判定は `reason` が先、効果の被覆は後 | 両方を `reason` → `requiredUpperBound` → `knownUpperBound` → 効果の被覆だけの `uncoveredAtom` → `source` にそろえる |
| 軽7 02-05 | `に従う。 診断の補足には` | `に従う。診断の補足には` |
| 軽8 02-10 E0521 | `この上限へ自然に到達する入力と、案内した変更による解消の効果は未確認であり、この修正案は収束を保証しない。` | `この修正案は収束を保証しない。`。未確認の限定は下の申し送りに残す |

型板の英文15項目の省略のない前後は [文言の記録](r40.1b-wording.json)、今回だけの差分は [差分](r40.1b-changes.patch) に保存した。

軽5は小さい変更で完了した。`render_failure` で ScopeResult の E0401 の表示の対だけを入れ替え、補助制約の生成・単一化の順序は変えていない。型検査の受理規則、四理由の分類、JSON の構造・欄名・形式の版は変えていない。

### 案内の確認とテストの関門

既存の CLI の二つの表を補強した。呼び出し元を欠く空の関数例では捕まえられない、型の不変性による呼び出し元の失敗と、転送先で再び由来が失われる失敗を守る。観察するものは、本物の CLI の終了状態・診断の英文・注記・修正後の受理である。本番の差し込み口、規則の模倣、別の層での重複テストは追加していない。テスト関数の新設・削除はない。偽の受け手が固定の成功値を返すだけだった転送例を、実際の範囲付き IO へ至る例に置き換えた。

| RV の入力の形 | CLI の表への接続と結果 |
|---|---|
| `caller-bare.bnt` | 裸の引数へ狭い検査済み値を直接渡すと E0401。PathIn／RequestIn と射影／拡大の組合せで確認 |
| `caller-bare-widen.bnt` | 同じ呼び出し元で `bind wideValue: <裸の型> <- Scope.widenPathIn(...)` または `Http.widenRequestIn(...)` を行ってから渡すと受理 |
| `forward-project.bnt` | 狭い型のまま転送し、転送先で射影すると E0519。呼び出し元を含めて確認 |
| `param-forward-io.bnt` | 同じ狭い型の関数引数を範囲付き IO の入口へ渡すと、呼び出し元も含め受理 |
| `clause-forward-io.bnt` | 同じ狭い型の節の引数を受け取る関数から範囲付き IO の入口へ渡すと、呼び出し元も含め受理 |
| E0401 ScopeResult | 修正前に expected/found の向きのアサーションが失敗し、修正後に成功 |

最初の退行確認はテスト名の `--exact` にモジュール名を付けなかったため実行0件となった（[ログ](r40.1b-regression-before.log)）。成功の証拠には使わず、絞り込みを修正して1件を実行し、期待した向きの差で終了101となることを確認した（[修正前の失敗](r40.1b-regression-before-executed.log)）。補強した局所テストの初回は、呼び出し元の断片を別の sample 関数へ付けて E0451 となったことと、JSON の help オブジェクトを文字列として読んだことにより失敗した（[初回](r40.1b-cli-initial.log)）。断片の位置と `helps[0].message` の参照を直し、2件成功・終了0、外側5.880秒となった（[再実行](r40.1b-cli-retry.log)）。入力の拒否や予算を緩めていない。

### 生成・W-40D

`cargo run -p benitoite --example gen_skill` は終了0、外側0.796秒であり、診断の生成物を更新した（[記録](r40.1b-gen-skill.json)）。`cargo fmt -p benitoite` は終了0、外側3.091秒である（[記録](r40.1b-format.json)）。公開の型や署名は変えていないため、R40.1 で済ませた計時探査の追随や比較器の自己検査は今回重ねていない。

作業末は、前の節に示した W-40D と同じ B_WORK・統合10対象を使った。`--dry-run` は終了0、外側0.158秒（[選択と理由](r40.1b-work-dry-run.log)・[記録](r40.1b-work-dry-run.json)）。選択は fmt、既定構成の clippy、lib 全件、指定の統合10対象、source_rules、skill_generated、spec_tally である。spec_examples は指定した統合に含まれ、重複の実行は省略された。Lean・依存の検査は選ばれていない。

正式実行の正確なコマンド、check.sh 自身の終了状態、外側の時間、RSS の補助値は [W-40D の記録](r40.1b-work.json)、生の出力は [ログ](r40.1b-work.log)、`/usr/bin/time -p` の出力は [time のログ](r40.1b-work-time.log) に保存する。既存の run-record.py が check.sh を直接子として起動して `returncode` を記録し、この記録器を `/usr/bin/time -p` で包む。`time -l` は使わない。

正式な W-40D は一度の実行で check.sh 自身の終了0、外側254.341116792秒（約4分14秒）、子の経過254.314918250秒、`time -p` の real は254.33秒であった。RSS 補助値は3,323,904,000 bytes = 3,169.921875 MiB（約3.096 GiB）である。macOS の `getrusage(RUSAGE_CHILDREN)` が示す子孫の最大値であり、一括実行全体の常駐量の合計ではない。正式検査の初回失敗や再実行はない。

| 検査 | 成功 | 失敗 | 無視・補足 |
|---|---:|---:|---|
| 既定 lib 全件 | 1,392 | 0 | 22 ignored |
| checked_args | 11 | 0 | 0 |
| cli_process | 40 | 0 | 呼び出し元を含む表の補強を含む |
| declarations | 33 | 0 | 1 ignored |
| desugar_export | 44 | 0 | 1 ignored。形式化の全書き出しは対象外 |
| golden | 2 | 0 | 0 |
| package_command | 16 | 0 | 0 |
| reference_examples | 1 | 0 | 0 |
| skill_docs | 8 | 0 | 0 |
| spec_examples | 7 | 0 | 0 |
| test_command | 52 | 0 | 0 |
| fmt・clippy | 終了0 | 0 | clippy は lib/tests/examples、no-default-features + gc-mark-sweep |
| source_rules・skill_generated・spec_tally | 終了0 | 0 | 規約・生成物・仕様集計の照合 |

統合10対象は254件成功・2件 ignored、lib と合わせて1,646件成功・24件 ignored である。正式実行時は結果のログなど未追跡の記録が増えたため、差分のファイル数だけが dry-run の154から157になった。対象の選択と理由は同じであり、指定された全ての検査に成功した。

今回の行数の増減は [記録](r40.1b-line-counts.json) に分けた。本番コードは25行追加・20行削除、テストは96行追加・11行削除である。生成物と設計書は別に計上した。テスト専用の本番コードや公開範囲は増やしていない。

### 申し送りと範囲

- R40.2: 注釈がある `bind value: String <- Scope.widenPathIn(...)` に E0407 が出ても `add a type annotation` と案内する点を扱う。今回の英文の修正と軽5には含めない。
- K10.2: 効果原子の経路では Top が常に unknownSource となり budgetExceeded を出さない点と、Lean の `atomFailure` が exceeded の src を取りうるかを比較する。今回の理由の分類は変更していない。
- R40.3／V10: E0521 の自然な上限到達例と、案内した変更による解消の効果は未確認である。この限定を確認済みへ書き換えない。設計書には収束を保証しないことだけを残した。
- 前の節の `aggregateEffects.expanded`／bounds・資源停止の表示・Show・通常文書と訳・Rust/Lean の全比較の担当は引き続き同じである。
- `private/`・`docs/todo/` は読んでいない。依存・Lean・scripts、レビュー記録と `rv-probes/` は変更していない。git の状態を変える操作、新しい CARGO_TARGET_DIR の設定は行っていない。`lake build`・`check-formal.sh`・short は実行していない。停止条件への該当はない。

### 最終確認と時間

[最終照合](r40.1b-review.json) で HEAD・ブランチ・index の不変と、レビュー記録および `rv-probes/` の24ファイルの SHA-256 の一致を確認した。`git diff --check` は終了0である。新しいログ・JSON・差分に手元のホームまたは作業先の絶対パスがないことも確認した。差分を比べるための `<tmp>/r40.1b-before` の写しは削除済みであり、`target/` の外に一時のビルドや基準版の展開は作っていない。中1〜中3・軽1〜軽8の未完の対応はない。

最初の時計取得は2026-10-29 09:37:28 UTC（18:37:28 JST）、最終記録は2026-10-29T09:47:51.350577+00:00である。取得時計間の外側は623.4秒（約10.4分）で、冒頭の時計取得に先行する読解を含めて約11分である。能動時間は概算6〜7分、正式検査の待ちは254.341秒である。その他の局所検査・生成・整形は各記録に分けた。正式検査待ちにも記録を整理しているため、待ちと能動時間を単純に足した値を外側の時間とはしない。途中のプロセス状態の参照は sandbox による `ps` の拒否で取得不能だったが、検査の終了状態は記録器から直接取得した。設計者の回答待ちはない。見込み40分〜1.5時間および3時間の停止条件を超えていない。
