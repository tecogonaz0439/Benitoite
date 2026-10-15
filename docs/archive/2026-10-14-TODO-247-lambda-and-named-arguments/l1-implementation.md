# L1 実装記録

## 範囲と判断

Token の物理行と LambdaExpr の終わりの表現を加える。終端付きラムダの構文と本体・診断・整形は維持する。ラムダの境界走査のモジュールを登録するが、走査と終端省略の受理は後の作業で実装する。他言語ラムダからの回復 AST の仮の終端は decisions.md の R14、終端情報による列挙型の増大への対応は R15 に従う。

## test-audit の作成時の関門

| 変更する検査 | 守る契約と退行 | 既存の検査で不足する点 | 差し込み口 |
|---|---|---|---|
| lexer の既存の Token 完全一致と共通の位置検査 | span の両端の物理行。CRLF の二重計数、文字列・補間・コメント・誤りの経路での行情報の欠落を捕まえる | 新しい行の欄を検査していない。既存の種類・値・span・診断の assert を保持して欄を補う | 既存の公開 lex のみ |
| lexer の物理行の表のテスト | 空入力、末尾の改行、複数行・raw・補間文字列、単独 CR の行番号を固定値で確認する | 既存の span 検査だけでは、物理行の定義の取り違えを検出できない | 公開 lex のみ |
| parser の終端の表のテスト | 通常・入れ子・空白を挟む終端の Explicit と終端全体の span、他言語ラムダの診断と仮の終端 | 既存の本体と診断の検査は ending を持たない。入れ子で外側の終端を記録する退行を捕まえる | 公開 parse と本物の lex・newline のみ |
| parser の EOF の診断位置 | EOF 字句が省略された入力でもソース末尾へ診断を置く | 通常の準備は lexer の EOF を含み、解析器が補う EOF に届かない | 公開 parse へ EOF を除いた字句列を渡す。公開範囲は広げない |

EOF の退行テストは、補完位置だけを従来の「最後の字句の末尾」に戻すと失敗することを確認した。末尾にコメント・CRLF・空行・空白がある入力で、旧位置は 33、正しいソース末尾は 36 となる。ソース末尾から補完する実装では成功する。

既存の assert、字句の種類・値・span、診断のコード・文言・修正案、統合テストの期待値を保持した。既存の Token の完全一致に新欄を加え、EOF の期待値を作る補助関数にソースを渡した。テストの削除・期待値の緩和・ignore の追加はない。差分の行数は、本番コードが追加 91・削除 28（新設の lambda_bounds を含む）、テストが追加 260・削除 12 である。削除行は、Token の期待値の補助関数の呼び出しの置き換えによる。

## 検査の結果

すべて最終のコードで成功した。

| 検査 | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1120 成功。既存の ignore 21 件は変更していない |
| `cargo test -p benitoite --lib syntax::lexer` | 27 成功 |
| `cargo test -p benitoite --lib syntax::parser` | 60 成功 |
| `cargo test -p benitoite --test fmt_command` | 14 成功 |
| `cargo clippy --all-targets` | 成功。R15 の箱と補助関数の変更後に警告なし |
| K の二構成の clippy | `scripts/check.sh` 内の `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` と `cargo clippy -p benitoite --lib --tests --no-default-features --features gc-mark-sweep` が成功 |
| `cargo fmt --all --check` | 成功 |
| `scripts/check.sh --dry-run` | `rust` を選択。長いテスト・全体の検査・heap・formal は選択されていない。分類不能なファイルはない |
| `scripts/check.sh` | 終了状態 0、`all checks passed`。mark-sweep と gc-stress のライブラリ各 1127 件と、golden・fmt_command・random_programs・spec_examples・reference_examples・Skill・VM などの関係する統合テストが成功。仮置きの許可・unsafe の場所・Skill の生成物・仕様の網羅率の検査も成功 |

gc-stress のライブラリ検査は 628.63 秒、golden は 524.91 秒かかった。通常の mark-sweep ではそれぞれ 63.00 秒と 51.51 秒であった。長く実行していた既存テストも、打ち切らずに完了を確認した。形式化した規則・型付き表層・脱糖に変更はなく、L1 では `lake build` と `check-formal.sh` は実行していない。

最終の差分確認で、既存の assert・観測結果・診断の期待値を維持し、公開型の表外の変更が R15 だけであることを確認した。git のコミットは作成していない。docs/todo/ は変更していない。

## 後の作業への申し送り

L1a で旧入力を移行してから、L2 で境界走査と Omitted を接続する。R14 の仮の終端は、診断を伴う回復 AST に限る。ラムダの直接構築は R15 の `Expr::Lambda(Box<LambdaExpr>)` に合わせる。`lexer/string.rs` はすべて既存の共通 push を使うため、編集せずに行情報を取得する。形式化した規則・型付き表層・脱糖は変更しておらず、formal/ の変更はない。
