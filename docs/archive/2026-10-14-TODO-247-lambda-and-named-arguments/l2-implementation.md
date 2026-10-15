# L2 実装記録

## test-audit の作成時の関門

1. parser の入口で、短いラムダの本体の範囲・終端種別・外側の文と区切りの保持、物理行の制限、直接の入れ子、通常の構文診断と回復を確かめる。改行を捨てる位置で本体を広げる退行、内側のコンマで本体を閉じる退行、外側の終端を取り直す退行を検出する。
2. 成功入力は AST の本体と終端を、負の入力は具体的な診断コードの列を比較する。診断の編集は適用後の再解析を確かめる。
3. 既存の parser の検査は終端付きだけを扱う。新しい契約を parser の表形式の検査にまとめる。改行判定の単独の検査を重ねず、lexer → newline → parser の本物の工程を使う。CLI の構文診断は既存のゴールデン検査を維持する。
4. 本番の入口と既存のテスト用の準備だけを使い、公開範囲の拡大や差し込み口を加えない。

## 診断の文言の確認表

| 対象 | 維持するもの | 旧 → 新 |
|---|---|---|
| syntax/c11-lambda-colon.diag.json の主文 | E0243、主位置、終了状態 | ``a lambda is written with parentheses and `end lambda` `` → ``a lambda is written as `lambda(parameters)` followed by a body``（Q1・R10） |
| 同ヘルプ | 一つのヘルプ、編集なし | ``write `lambda(x) return x + 1 end lambda` `` → ``write `lambda(x) return x + 1 end lambda`; omit `end lambda` only when the entire lambda fits on one physical line`` |

既存の assert、診断コード、位置、期待する観測結果は保持する。

## 生成入力の追加移行の関門

| 入力 | 観測する契約と退行 | 既存の不足と検査の境界 | 差し込み口 |
|---|---|---|---|
| cancellation の action とランダム生成器の update | タイムアウト・取り消しの順序と結果、参照インタプリタと実行結果の一致。差し込み後の複数行の本体の誤分類で失敗する | L1a は format の差し込み後の二入力を抽出できていなかった。元のテストを本体開始への改行だけで移行し、同じ assert で再検査する | 既存のコンパイル・VM・差分検査の入口だけ |

接続後、二入力が E0254 で失敗することを確認した。テストの期待値の変更や新しい差し込み口はない（R17）。

## CLI の成功入力の関門

短いラムダの解析結果が型検査・脱糖・VM まで渡り、通常の return と捕えた値を維持することを、syntax/short-lambda の CLI の出力で検査する。parser の AST 検査では、後段が終端省略の形を通常のラムダとして扱う契約までは確認できない。入力は本物の CLI から実行し、出力と終了状態を固定する。テスト専用の本番コードは加えない。

## 短い形の深さの関門

既存の parser の深さの境界の表に、同じ行で束縛の値へ入れ子にする短いラムダを加える。終端の有無によらず、同じ Lambda・Block・Bind の深さを数える契約を守る。省略形で文の一段を数え忘れる退行は、従来の終端付きの行では検出できない。既存の公開の parser と成功・E0208 の assert を使い、準備と差し込み口は増やさない。

修正前に、333 個の入れ子を受理して期待する E0208 が出ないことを確認した。短い本体でも Block とその文を一段ずつ数えるよう直し、332 個の成功と 333 個の拒否を再確認した。

## 実装と L1a の再確認

字句の境界走査を改行判定と parser に接続した。開始位置をキーとして内側の分類を再利用し、AST・診断・ノード ID を境界走査では作らない。parser は通常の一文の規則で本体を解析し、Omitted の本体末尾、物理行、直接の入れ子を検査する。欠けた括弧・不正な型・同じ行の二文・セミコロンの診断と、外側の閉じ忘れの回復を維持する。E0254・E0256 を追加し、E0243 の文言を上表のとおり更新した。

01-01・01-02・02-03 に現在の受理規則と実装方式を反映し、07-04 の対応表には構文解析の終端省略を「対象外」と記した。型付き表層、脱糖、Lean の定義と証明は変更していない。01-02 の見出し名と既存の spec 印は維持し、CLI の成功ケースには「01-02 ラムダ」の印を付けた。Skill の文法・診断を生成元から再生成した。

L1a の抽出済み 649 入力を公開の lexer → newline → parser で再解析した。従来の成功入力 403 件は、位置とノード番号も含めた AST と診断が完全に一致した。負の入力では `uses` の型引数の回復に余分な E0201 が出る差を発見し、不正な見出しを通常の parser に委ねるよう直して E0209 だけを維持した。最終比較で診断コードの列が変わった八入力は、現在の言語の移行対象から除く tools/syntax-measure/variants/V01 の比較資料だけである。資料は変更していない。

三つの深さの生成断片は、typeck と pipeline の既存の深さテスト、および stack_probe の生成元を上限の 332 個で解析する実行で確認した。output_tests の既存の replace で二文になる二入力と、resume の負の入力の E0509・文脈の説明は、既定のライブラリ検査でそのまま通った。移行済みの IO・CLI・ベンチマーク・標準ライブラリの入力も、統合検査・ゴールデン検査と上の AST の照合で確認した。差し込み後に複数行になる追加の二入力は R17 のとおり移行した。

既存の assert の削除、期待値の緩和、ignore の追加はない。既存の期待値の変更は上表の E0243 の文言だけである。

## 検査の結果

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 最終のコードで 1,122 成功、既存の ignore 21 件。約 64 秒 |
| `cargo test -p benitoite --lib syntax::` | 94 成功。短い形の境界と深さの表を含む |
| `cargo test -p benitoite --test golden --test random_programs --test spec_examples --test reference_examples --test skill_docs --test skill_examples --test runtime_builtins --test io_modes --test fmt_command` | 9 スイート・51 テスト成功。後の境界の修正後に golden・random_programs・spec_examples・skill_docs も再確認して成功 |
| `cargo test -p benitoite --test interrupt_process` | 9 テスト成功 |
| `BENITOITE_GOLDEN_FILTER=syntax/short-lambda cargo test -p benitoite --test golden` | 新しい一ケースの出力・終了状態・参照インタプリタとの一致・既存の整形検査が成功 |
| `cargo run -p benitoite --example stack_probe -- run lambda max 16777216 parse` | 既存の生成元の上限の入力を解析し、終了状態 0 |
| `cargo run -p benitoite --example gen_skill` | 成功。文法と診断の生成物を更新 |
| `cargo clippy --all-targets` | 最終のコードで成功、警告なし |
| `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` | 最終のコードで成功、警告なし |
| `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` | 最終のコードで成功、警告なし |
| `cargo fmt --all --check`、`git diff --check` | 成功 |
| `scripts/check-formal.sh` | 終了状態 0。lake build（98 jobs）、交換形式の検査、Rust の書き出し、Lean との各比較が成功。書き出しは約 660 秒 |

形式化の記録は `target/desugar-diff/run-18742/` と `target/coverage-diff/run-18742/` にある。脱糖は 336 の golden プログラムと 1,000 の生成プログラムに不一致がなく、既存の検査の誤りによる除外は 378 件である。網羅性の 10,020 ケース、組み込みの表の 71,870 比較、プログラムの網羅性の 22,429 比較、表層の 51,033 比較も不一致 0 であった。表層の対象外 19 件はそのまま区別している。

## 計画との差と申し送り

R16 は、現行の match の分岐の区切りを維持し、一行の match を一分岐の形で検査する判断である。R17 は、L1a の抽出に含まれなかった二つの生成入力の追加移行である。R18 は、Skill の説明を実際の生成元 `src/cli/tools/skill/generate.rs` で変更する判断である。公開の型・シグネチャは追加変更していない。

L3 は `LambdaExpr.ending` と `body.span` を使い、短い形の本体に属する字句の範囲・終端種別・物理行を整形後にも検査する。新しい CLI の short-lambda ケースも、その検査の対象にできる。L4 の推奨の説明と例の変更、段 2 の名前付き引数は後の作業で行う。

依頼に従い、scripts/check.sh（dry-run を含む）と gc-stress の構成の検査は実行していない。コミットは作成しておらず、docs/todo/ にも触れていない。
