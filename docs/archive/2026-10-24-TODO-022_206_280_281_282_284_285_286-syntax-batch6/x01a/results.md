# X01a の結果

再開の着手: **2026-10-26 19:46:21 JST**。終了: **2026-10-26 20:20:14 JST**。所要時間: **33分53秒**。最初の起動の時刻・停止・試作の記録は、末尾の「最初の起動の確認」に残した。

**状態: X01a の実装・局所検査・指定 work と差分の点検を完了した。独立レビューと受け入れは取りまとめへ渡す。**

B_WORK と HEAD は `0341dfe350598fb3626137d4d47121301acea382`、ブランチは `mod012/X01a`。着手時の差分はなかった。共通依頼文、plan の前提・契約・X01〜X05・X01a の検査と RV-C5 後の変更、D4 の変更・D5・D17・D20、指定された L26〜L29S・A19〜A21 の申し送り、RV-C5、最初の起動の記録と試作差分を確認した。rtk・test-audit・japanese-tech-writing を適用した。

## 実装した範囲

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/typeck/interval/observation.rs`（新設）、同 `mod.rs` と `typeck/mod.rs`・`typeck/decls.rs` | 検査ごとに借用する任意の内部記録先を追加した。内部用の入口 `typecheck_with_interval_observations` が、通常の型検査と同じ処理の出力・診断と、所有した記録を返す。既存の訪問表と、親・独立入力自身・別本体の候補を、診断をまとめる前に記録する。無効時は複写・確保・解析予算の操作を追加しない。既存の型検査・解析の署名を保ち、大域の可変状態と本番からテストへの依存を作らない |
| `crates/benitoite/tests/desugar_export/exchange.rs` | 既存 Surface の各式へ元 NodeId・span・型を任意で付ける。定数の元本体、else-if、入れ子の with、リスト展開の concatenate、補間の変換関数も対応させる。`definitions_recorded` の記録なしの分岐を既存の入口から使い、記録ありの分岐で独立交換の材料を返す。実行開始の空のモジュール名と `.point`、impl の位置を含む名前を保つ |
| `crates/benitoite/tests/desugar_export/interval/source.rs`（新設） | Surface のフィールド順・リスト順と定数展開を独立に辿る。通常解析の番号・親・形・元 NodeId・span・取得済み終端を照合してから候補を写す。未取得の接尾辞には `acquired=false` を付け、観測した終端も別に残す。別本体にも新しい根を置いて照合し、候補の元位置を確かめる |
| `crates/benitoite/tests/desugar_export/interval.rs` | 本物の読み込み・名前解決・型検査・脱糖と交換をつなぐ一つの表形式の検査を追加した。13入力、元定義16本体・別本体3本体、計128出現を照合する。独立入力の包みから `.point` の interval-corpus を書き出す |
| `docs/design/02-impl/02-05-typechecker.md` | 任意の内部記録先と独立交換の照合、取得済み接頭辞と未取得の区別を反映した |

13入力は、一点定数、除数0、定数展開と未到達の枝、独立入力、ラムダ、リスト展開、書式付きも含む文字列補間、入れ子の with、lazy、同じ定数の複数回の展開、ハンドラ、guard 付き match、同名メソッドを持つ二つの impl である。合成した根は `syntheticBodyRoot` として元位置を持たないことを明示する。対応不一致と欠落は assertion で拒否し、警告の抑制・候補の除外・番号の詰め直しで通さない。

作成時の関門では、通常解析の出現と実 Surface の対応を独立した契約とした。現実的な退行は、定数展開の子の欠落、with の内外や合成関数の位置の混同、未到達部分の番号詰め、別本体の根の混入である。既存六入口は通常解析の訪問表と候補を読まず、このずれを捕まえない。計画で認められた任意の内部記録先を使い、解析器や処理系の段をテストダブルへ置き換えていない。最終の検査は、通常の pipeline が受理した同じ AST を、記録付きの本物の型検査へ再度渡して観測する。テストを削除していない。

本番 Rust は128行追加・11行削除、Rust のテストと交換の補助は724行追加・11行削除である（[集計](resume/code-lines.json)）。追加した検査関数は一つであり、53構成子と容器の順序を読む独立の走査、別本体と候補の照合を共有の補助にまとめた。

## 独立期待値と局所の比較

実ソースから新しく書き出した [point-input.json](resume/point-input.json) は、名前を補正せず `.point` と空名の実行開始モジュールを使う。区間 `[42,42]`、本体7操作・全体8操作、保存3項・最大保持7項、次番号2と二つの識別対応は手計算の期待値である。Rust または Lean の観測値から期待を生成していない。

この入力を既存の `intervalDiff analyze` へ渡し、**終了0、matched=true、accepted=true** を得た（[実行](resume/point-check.json)・[出力](resume/point-check.log)・[報告](resume/point-report.json)）。最終の書き出しとのバイト単位の一致も確認した。既存の独立交換の局所検査は五つの profile と負例を含む **144回の実CLI起動、終了0、3.149秒** だった（[記録](resume/exchange-local.json)・[出力](resume/exchange-local.log)）。解析174本体・閉じた評価器109本体、理由付きの評価除外65本体は従来の固定入力の値であり、Rust/VM の全比較済みとは数えない。

局所の入力・報告・対応記録は、相対リンクの情報も含む547項目を [ZIP](resume/local-records.zip) と [SHA-256 の索引](resume/local-records-index.json)に保存した。[要約](resume/local-summary.json)に、13入力の16元定義・3別本体・128出現と、point 入力の一致を記録した。

## 検査と失敗の修正

実行場所は `<repo>`、[run.py](resume/run.py) が手元のパスを伏せ、コマンド・終了状態・外側時間を同名の JSON と log に保存する。Cargo は既存の書き込み可能な `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を使った。

| 検査 | 結果・記録 |
|---|---|
| 試作の再点検後の局所検査 | 最初の6入力が成功。依存の再ビルドを含め80.419秒（[記録](resume/identity-first.json)）。別本体の照合追加後も成功、2.931秒（[記録](resume/identity-family.json)） |
| 合成節点等を含む局所検査 | 11入力が成功（[記録](resume/identity-synthetics.json)）。その後に加えた match の入力で枝の前の改行が欠けて終了1となった（[記録](resume/identity-final.json)・[出力](resume/identity-final.log)）。試験入力の改行を直し、13入力が成功、2.747秒（[記録](resume/identity-corrected.json)） |
| 途中の割り当て量2件 | 2件成功・失敗0、終了0、11.907秒（[記録](resume/allocations.json)・[出力](resume/allocations.log)）。20,000定数の鎖は442,858,487バイト（上限512 MiB）、5,000定数・1,000診断は254,972,750バイト（上限256 MiB）。A21d と同じであり、入力・上限・期待値を変えていない |
| 最初の work と同じ dry-run | 終了0、0.083秒。七単位を選択（[記録](resume/work-dry-run.json)） |
| 最初の work | fmt は成功し、clippy で終了1、本体41.045秒（[本体](resume/work-check.json)・[出力](resume/work.log)）。記録先の `expect()`、交換の Item のワイルドカード、lib テストでの入口の未使用を検出した。lib と全統合の実行前に止まった |
| 修正後の work | clippy で終了1（[本体](resume/work-check-corrected.json)・[出力](resume/work-corrected.log)）。JSON Value のワイルドカードと、共通交換器の未使用が残っていた。値の列挙を明示し、既存入口と新入口を任意の対応記録を選ぶ共通処理に整理した |
| 大域状態の修正前の work と同じ dry-run | 終了0、0.085秒。全 lib・全統合・examples を含む clippy・fmt・ソース規約・生成 Skill の照合・仕様集計の七単位を選択（[記録](resume/work-final-dry-run.json)） |
| 大域状態の修正前の work | 七単位成功・本体終了0（[本体](resume/work-check-final.json)・[出力](resume/work-final.log)）。外側489.423秒。この状態の成功を最終状態の検査へ引用して省略していない |
| 検査ごとに借用する記録先への修正後の局所検査 | 13入力成功、12.694秒（[記録](resume/identity-scoped.json)）。割り当て量も2件成功・失敗0、終了0、11.556秒。442,858,487バイトと254,972,750バイトで不変（[記録](resume/allocations-scoped.json)・[出力](resume/allocations-scoped.log)） |
| 最終の work と同じ dry-run | 終了0、0.089秒。上と同じ七単位と全統合を選択（[記録](resume/work-scoped-dry-run.json)） |
| 最終の work | **七単位すべて成功・本体終了0、471.491秒**（[本体](resume/work-check-scoped.json)・[出力](resume/work-scoped.log)）。lib は1,332件成功・失敗0・ignored 21、全統合は40ターゲット・392件成功・失敗0・ignored 10。clippy・fmt・ソース規約・Skill の生成照合・仕様の集計も成功（[集計](resume/work-summary.json)） |

作業末は次の指定を使った。初回と修正後の失敗は保存し、ソースの修正で古くなった fmt・clippy と、まだ実行していない残りの検査を同じ入口で続けた。成功後の検査を計測のために重ねていない。

```sh
scripts/check.sh --level work --base 0341dfe350598fb3626137d4d47121301acea382
```

最終点検で、流用した試作の `thread_local!` が AGENTS.md の大域可変状態の禁止に反することを見つけた。検査ごとに記録先を所有・借用する形へ直し、既存の入口は記録先なしで同じ処理を使うようにした。例外や警告抑制を追加していない。修正前の検査の終了を待ってから適用し、ソースの修正で古くなった七単位を最終状態で実行した。補助の文書更新コマンドが文字コードエラーで一度止まったが、文書の更新を通常のパッチへ切り替えて完了した。

本体と `/usr/bin/time -l` の終了は、[work-check-scoped.py](resume/work-check-scoped.py) と外側の実行器で区別した。**最大常駐量（maximum resident set size）は取得不能**である。最終も time が `sysctl kern.clockrate: Operation not permitted` を報告して終了1となった（[外側の記録](resume/work-scoped.json)）。検査本体の終了0と区別し、未取得を0と記録していない。外側471.520秒、real/user/sys は471.51 / 1400.13 / 71.56秒である。先の三回も同じ取得拒否だった。計測のための再実行は行っていない。

## 差分の点検と申し送り

[点検器](resume/audit.py)と検査前の [入力ハッシュ](resume/inputs-before-scoped.json)・検査後の [点検結果](resume/inputs-after.json)で、実装・設計書の八ファイルのハッシュが検査前後で一致することを確認した。`formal/`・予算固定表・割り当て量の検査・manifest・lock・固定版指定に差分はない。既存の `typecheck`・`decls::check`・`AnalysisState::analyze` の署名は開始版と一致し、記録先に大域の可変状態はない。差分の範囲、記録のパスの伏せ方、`git diff --check` も確認した。最終の work の後は、結果記録と点検・集計だけを更新した。

計画の範囲の変更、言語の規則・Lean の定義や定理・公理・予算固定表・既存の型検査の署名の変更はない。Lean はビルドも単体検査も起動せず、既存ビルド済みの `intervalDiff` を逐次実行した。`formal/lakefile.toml` と `-M 12288` は不変である。private/ とそのリンク、担当の委任、git の変更操作・コミット・取り込み・docs/todo の更新・公開は利用していない。

| 残る手順 | 担当・受け渡す内容 | 見込み |
|---|---|---|
| X01a の独立レビュー・受け入れ | 取りまとめ。対応記録、未取得部分、候補を写す前の照合、指定 work の証拠を確認する | 不明 |
| 合成節点・全対象演算と深い不正入力の接続、局所検査・work・レビュー・受け入れ | X01b と取りまとめ。現在の独立入力の包みは base の最小例で、標準表・apiAt は空である。Range/domain の標準束縛の実交換と sourceKeys の拡張、desugar_export.rs と Python の実入口を計画どおり接続する | 計画の1〜1.5時間。レビューは不明 |
| 全関係定義・全 profile・消費と段停止・候補と利用者警告・VM 比較・全比較・レビュー・受け入れ | X02〜X05 と取りまとめ。この入口は、現在の通常解析と同じく Prelude・Stdlib を除く定義を返す。全関係定義の manifest と未発見・未解析の件数は X02 で閉じる。候補の operation と停止は内部観測の表現であり、交換側の演算表現との照合も後続で行う | 計画による。今回未測定の時間は不明 |

## 最初の起動の確認

以下は再開前の記録である。空名のモジュールの読者の停止条件は、L29S の受け入れで解消した。

着手（最初の時刻取得）: **2026-10-26 19:17:15 JST**。終了: **2026-10-26 19:33:20 JST**。所要時間: **16分5秒**。時刻取得前の指示の読み込みは計測に含めていない。

**状態: 未完。実行開始モジュールの空の名前を Lean の独立交換の読者が拒否する問題を再現し、指示された停止条件に従って接続を停止した。実装完了・受け入れ済みとはしない。**

B_WORK と HEAD は `1e4b58f86b90d78a1102dd3ef8127850c8c84245`、ブランチは `mod012/X01a`。着手時の差分はなかった。共通依頼文、plan の前提・契約（独立交換・識別・警告）・作業群 X01〜X05・X01a の検査、D4 の変更・D5・D17・D20、RV-C5 と計画の変更、L26〜L29R・A19〜A21 の申し送り、現行の実装を確認した。rtk・test-audit・japanese-tech-writing を適用した。

### 停止した理由と再現

実行開始モジュールの名前は、現行の `crates/benitoite/src/modules/load.rs` の `load` で `ModulePath(Vec::new())` となる。`src/typeck/interval/input.rs` の `definitions` は、その `dotted()` の結果と宣言名を `format!("{module_name}.{}", declaration.name)` で結ぶ。そのため、[実ソース](entry-source.bnt) `const point: Integer = 42` の通常解析の定義名は `.point` となる。これはファイル名の欠落や試作の命名によるものではなく、現在の処理系の定義に従う名前である。

一方、`formal/Benitoite/Interval/Exchange.lean` の `readModule` は `name.isEmpty` を拒否する。`readDefinition` の通常の定義名の検査もモジュール名に `.` を続けた接頭辞を要求するので、名前 `.point` を保ったまま空でない別のモジュール名を渡すことはできない。impl の実行開始モジュールも同じ空の名前を持つ。

試作の Surface 交換から本文・型表・元キーを作り、通常解析の対応表と照合した `point` の入力を保存した。最後の再現では、独立の手計算による context も明示した [実行開始モジュールの入力](entry-final-input.json)を、現行の `intervalDiff analyze` に渡した。**終了2、`invalid module name`** となった（[実行記録](entry-final-check.json)・[出力](entry-final-check.log)・[報告](entry-final-report.json)）。

比較対象として、モジュール名を `M`、定義名と各キーを `M.point` に変えた[独立した対照入力](named-final-input.json)は、同じ本体・型・区間・消費の期待で **終了0、matched=true、accepted=true** となった（[実行記録](named-final-check.json)・[出力](named-final-check.log)・[報告](named-final-report.json)）。対照入力を実ソースの名前解決の結果とは扱わず、キーの書き換えを解決策として実装していない。

context の手計算は既存の `formal/tests/test_interval_exchange.py` の point の独立期待と同じである。入口2操作、根とリテラルの各2操作、Block.last の1操作で本体7操作、モジュールで全体に1操作を加える。出力枠と2対応で保存3項、最大保持7項となる。Lean の観測値から期待を生成していない。

### 取りまとめへ返す判断

推す案は、**別の Lean 作業で独立交換の読者が実行開始モジュールの空の名前を受けられるようにし、現行の `.point` と `%impl:...` の定義キーを保つ**ことである。変更先の候補は `Exchange.lean` の `readModule` の入力制約とその正負例である。モジュールと定義の重複、定義名との整合は引き続き検査する。この変更には今回の「Lean（formal/）の定義・定理は変えない」という指定の変更が要るため、本枝では行っていない。中心の健全性定理・言語規則・予算の変更を求めているわけではない。

代案は、実行開始モジュールの定義キーを Rust と交換全体で変更することである。しかし、これは識別の既存契約と後続の対応を変えるため、X01a の担当判断では採らない。空の名前の定義を manifest から除いたり、対応の不一致を警告抑制で隠したりして通すこともしない。

### 試作と残した差分

任意の内部 sink、Surface 交換の元 NodeId・span・型の記録、定数展開を含む先行順の照合、独立入力の包みを試作した。試作は本番からテストを呼ばず、sink が無効なら複写や予算操作を追加しない形である。保存した[試作差分](attempt.patch)は **539行の未完成の資料**であり、適用済みの実装でも、検査済みのパッチでもない。後続担当はそのまま適用しない。

停止後は、自分が編集した既存4ファイルを B_WORK の内容へ戻し、自分が作った Rust の2ファイルを取り除いた。復元には読み取りの `git show` と通常のファイル書き込みを使い、git の変更操作は行っていない。最終差分は本 `x01a/` の結果・再現入力・ログ・試作資料だけであり、`crates/`・`formal/`・設計書・予算の固定表に差分を残していない。

テストの作成時の関門では、Surface の元位置と通常解析の訪問順、候補を写す前の対応の完全性を契約とした。既存の六入口は通常解析の訪問表を読まず、定数展開や合成節点の元位置のずれをこの境界では捕まえない。計画で明示的に認められた任意の sink を試作したが、テストも含めて最終ソースへ残していない。

### 途中の検査と失敗

すべて `<repo>` で実行した。[run.py](run.py) が出力の手元のパスを伏せ、終了状態と外側時間を同名の JSON に保存した。Cargo は書き込み可能な既存の `CARGO_HOME=<tmp>/benitoite-a01a-cargo` を用いた。

| 実行 | 結果 | 記録 |
|---|---|---|
| 試作の `cargo test -p benitoite --test desugar_export export_interval_identity -- --nocapture` | 未完。初回は補助モジュールのパス、2回目は試作入力の return の欠落、3・4回目は段のスレッドに TLS sink が継承されないこと、5回目は flow の試作入力の余分な end if で失敗した。5回目は point と division の対応照合を通過してから失敗した。全テスト成功とはしない | `identity-first`〜`identity-fifth` の各 log・JSON |
| `cargo test -p benitoite --test call_allocations constant -- --nocapture` | **2件成功、失敗0、終了0、11.261秒**。停止時の試作状態で実行した | [実行記録](allocations-at-stop.json)・[出力](allocations-at-stop.log) |
| 初回の実行開始モジュールの読者確認 | 終了2、invalid module name | [記録](entry-reader.json) |
| 最初の名前付き対照 | 読者は通過し、context を省略したため比較が終了1となった。独立の手計算で context を明示した最終対照で終了0を確認した | [出力](named-control.log)・[報告](named-control-report.json) |
| 実ソースの `target/debug/benitoite test --check --report=json <入力>` | 終了0、1.195秒。status=ok、complete=true、診断なし、inputDefinitions=1、coverage=all | [記録](source-check.json)・[出力](source-check.log) |
| 最終の実行開始モジュール／名前付き対照 | 終了2／0、各0.019秒。上記の停止理由を確定した | `entry-final-check`・`named-final-check` |

割り当て量は20,000定数の鎖が **442,858,487バイト**（上限512 MiB）、5,000定数・1,000診断が **254,972,750バイト**（上限256 MiB）であり、A21d の最新値と一致した。入力・上限・期待値は緩めていない。これは試作の sink を無効にした通常経路の確認であり、未完成の交換の正しさの証拠にはしない。

途中の記録器で入力ファイルと実行メタデータの保存名が重なったため、名前付きの初回入力と中間の entry-complete 入力はメタデータで上書きされた。補正中の二つの短い Python コマンドも KeyError で止まった。保存名を `*-final-input.json`・`*-final-check.json`・`*-final-report.json` に分け、上の最終の二入力で再現と対照を確認した。中間の named-complete-check は入力不在による終了2であり、交換の拒否例に数えない。原本の entry-point.json と最終入力は保持している。

### 作業末の検査と申し送り

最終のソース差分はなく、plan の X01a の文書だけの指定に従い、次を同じ指定の dry-run の後に一度実行した。結果記録に保存した run.py 等は作業記録用であり、製品の Python 道具ではない。

```sh
scripts/check.sh --level work --base 1e4b58f86b90d78a1102dd3ef8127850c8c84245
```

| 検査 | 終了状態・外側時間 | 記録 |
|---|---|---|
| 同じ指定の dry-run | 終了0、0.081秒。「文書だけの変更、検査対象なし」を確認 | [記録](work-dry-run.json)・[出力](work-dry-run.log) |
| 作業末の work 本体 | 終了0。選択0単位、実行0単位。Rust の全 lib・全統合・clippy・fmt を実行したという意味ではない | [本体の記録](work-check.json) |
| `/usr/bin/time -l` を含む外側 | 終了1、0.103秒。real/user/sys は0.09 / 0.04 / 0.12秒 | [外側の記録](work.json)・[出力](work.log) |

**最大常駐量（maximum resident set size）は取得できなかった。** time がサンドボックス内で `sysctl kern.clockrate: Operation not permitted` を報告して終了1となった。検査本体の終了0と区別し、未取得を0と記録していない。計測のための再実行は行っていない。

`git diff --check`、追跡済みの全ソースが B_WORK と同じであること、保存した Python の構文・JSON・記録のパスの伏せ方を最終点検した。[点検結果](self-review.json)と[再現入力等の SHA-256](inputs-sha256.json)を保存した。点検器の初回は、これから保存する点検結果自身へのリンクを保存前に検査して止まった。保存してからリンクを調べる順に直し、成功した。検査対象の修正や work の再実行はしていない。今回の停止は時間上限によるものではなく、明示された Lean の変更禁止によるものである。

Lean のソース・定理・公理・固定表は一切変更していない。既存ビルド済みの intervalDiff を逐次実行しただけで、lake build や単体の lake env lean は起動していない。深さ停止・予算境界の除外や期待値の緩和で一致させていない。private/ とそこを指すリンク、担当の委任、git の変更操作・コミット・取り込み・公開は利用していない。

| 残る手順 | 担当・時期 | 見込み |
|---|---|---|
| 実行開始モジュールの交換形式の判断と、Lean 読者の別作業への割り当て | 取りまとめ、X01a の再開前 | 不明 |
| 読者の正負例・局所比較・指定 work・独立レビュー・受け入れ | 別作業の担当と取りまとめ、上の判断後 | 不明 |
| X01a の sink・Surface 対応・候補転記・独立入力の実装、割り当て量と全 lib／全統合／lint 等の work | X01a の再担当、読者の受け入れ後 | 元の見込み1〜2時間。今回の未完成パッチの流用可否は再点検が要る |
| X01a の独立レビュー・受け入れ、X01b 以降 | 取りまとめと各担当、X01a の実装と検査の完了後 | 計画による。今回未測定の時間は不明 |

### 取りまとめのレビュー（2026-10-26、最初の起動）

停止は正当である。Rust は実行開始のモジュールの名前を空文字列として定義のキー（`.point`）を作り、Lean の `Exchange.lean` の `readModule` は空のモジュール名を拒否する。名前の書き換えや定義の除外で回避しなかったのは計画に沿う。取りまとめは推す案を採り、Lean の作業 L29S で、読者が実行開始のモジュールの空の名前を受け付けるようにする（計画の変更（2026-10-26、X01a の停止を受けて））。その後に X01a を再開する。

## 取りまとめのレビュー（2026-10-26、再開）

受け入れる。記録先は検査ごとに渡す任意の値で、大域の可変状態（試作の `thread_local!`）は取り除かれ、本番からテストへの依存もない。通常の解析の訪問表と Surface の先行順を照合してから候補を写し、`.point` の独立入力は Lean の実 CLI で matched・accepted になった。Lean・予算の固定表は変わらず、work は七単位とも成功し、`call_allocations` の二件は A21d と同じである。X01b へ進む。
