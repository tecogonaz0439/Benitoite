# B7 or の境界・改行・診断・整形

## 目的と変更

開始時の HEAD は `f91b462dd95dc0daa814158ee211d011f21c6a14`、作業ツリーは clean だった。

B6 の明示 return の解析を使い、ブロック・入れ子・改行・整形の境界を確認した。構文と意味の基準は design.md の「文法と式の境界」「AST・フォーマッタ・名前解決」、R13 の回答 B・R14 である。共通の関門 K のうち check.sh と gc-stress 構成は、今回の依頼に従ってオーケストレータへ残す。G4 の所定レビューと合意の完了は、この作業の自己確認から推測しない。

| ファイル | 変更 |
|---|---|
| `crates/benitoite/src/syntax/parser/effects.rs` | 値を付けた処置の E0258 の対象に `not` を追加。既存の解析の表へブロック・guard 内の lambda・補間・コンマ・短い lambda を追加し、別の表で入れ子の入力と処置の span を LF/CRLF で厳密比較 |
| `crates/benitoite/src/syntax/parser/mod.rs` | 本体が `or return` で終わる短い lambda の次行の旧終端にも、既存の終端の移行 help を付ける。括弧内に残る NEWLINE の先も確認する。未完の式に help を付けない既存の表も拡張 |
| `crates/benitoite/src/cli/tools/formatter/verify/tests.rs` | 裸／明示・入れ子・コメント・補間を含む有効な整形の受理と、処置の変更・短い lambda の物理行の変更の拒否を検査 |
| `crates/benitoite/testdata/fmt/try-actions.*` | パイプ・内外の処置・括弧・補間・コメント・複数行の引数・if/with/match の手書きの fmt golden。再解析と冪等性を確認 |
| `crates/benitoite/tests/desugar_export/{routing,exchange}-manifest.json` | 新しい fmt golden 一件の E0301 17 件と、全入力数・check error 数の増分を登録。既存入力の分類と対象内の定義数・比較数は不変 |
| `docs/design/01-spec/01-02-syntax.md` | 処置が外側へ残す区切りと、guard の既存の制限を明記 |
| `docs/design/06-tooling/06-03-formatter.md` | 裸／明示の選択、入力の範囲、コメントと物理行の保持、その検査を明記 |
| `decisions.md` と本記録 | R53 と検査・診断の対応を記録 |

Pratt の停止条件・内側の try の優先・newline/lambda_bounds・formatter の印字と verify の本体は、既存の処理で契約を満たすため変えていない。`diag/codes.rs` の主文と help の定義も変えていない。Die の AST・説明・本番受理は追加していない。

## test-audit の作成時の関門

1. 守る契約は、公開 parser が返す入力／処置の範囲、外側の区切り、診断コード・位置・help、formatter の処置・コメント・短い lambda の物理行の保持と冪等性である。形式化の全入力の識別子・診断列・対象内の定義数も既存の manifest で保つ。
2. 捕まえる退行は、内側の処置や guard を外側の try が奪うこと、Boolean or を処置と誤認すること、次行の取り込み、処置に付けた値への診断の誤り、未完の演算子への無関係な移行 help、整形による処置の消失・移動である。形式化の入力からの漏れや除外理由の付け替えも検出する。
3. B6 の既存の表に境界と診断の行を足した。B6 は then と基本的な入れ子を確認していたが、各ブロック・内側の guard・補間の入力範囲を直接比較する表はなかった。formatter/verify の表は検証入口の拒否を、fmt golden は公開 CLI の正規形と再整形を担当する。二つの manifest には新しい一件だけを追加し、既存の各入力の期待値を保持した。既存の assert・入力・ignore は変更していない。
4. テスト用の本番 API・フラグ・公開範囲の拡大はない。すべて既存の parser・formatter・CLI の入口で確認する。

修正前には、`try r or return not flag` が E0258 の代わりに E0201 となって解析の表が失敗した。`lambda() try r or return` の次行に旧終端を置く場合と、その lambda を呼び出しの引数に書く場合も、移行 help がなく表が失敗した。修正後に同じ表を通した。

処理系の本番コードは追加 47 行・削除 35 行、Rust のテストと fmt 入力は追加 157 行・削除 0 行である。cfg(test) の tests モジュールと新しい fmt の四ファイルをテスト側に数えた。二つの manifest は追加 55 行・削除 1 行であり、削除は新入力一件に伴う check error 数の 386→387 の置換だけである。既存テストの削除・弱化はない。

入力表を作る際、guard に直接書いた try は既存の E0218、補間の物理行を越えた入力は lexer の E0119/E0108 の対象と確認した。これらを有効な構文や E0254 の入力とは扱わない。内側の return の後で改行してから外側の処置を書き始める形も、R13 の一般規則に従って文が終わる。正の表では外側の or を同じ行に置き、return までの改行を確認する。

## 診断の対応

| 入力 | 旧→新のコード・主文 | help | 主／副位置・終了状態 | 理由と維持する検査 |
|---|---|---|---|---|
| `try r or return not flag` | E0201 ``expected a newline or the end of the block, found `not` `` → E0258 ``invalid failure action after `try` `` | なし → ``the `or return` action takes no value`` | `not` の位置。副位置なし。check の終了状態 1 は不変 | 値を付けた処置として既存の E0258 に揃える。parser の表でコード・主位置・help 全体を比較 |
| 短い lambda の `or return` の次行に `end lambda` | E0213 ``found `end lambda` but expected `end function` ``、引数内なら E0201 ``expected `,` or `)`, found a newline``。コード・主文は不変 | 既存の help に lambda_line を追加 | E0213 は旧終端、E0201 は return 直後の改行。既存の副位置は不変。終了状態 1 | 本体が終わった短い lambda の移行を案内。既存の終端の表で help の全文と編集なしを比較 |
| 未完の演算子・パイプ・`or` | 既存の E0201/E0203、明示形後の E0259 を維持 | 無関係な lambda_line を付けない | 変更なし | 既存の未完の式の表を拡張 |
| 裸の try、Boolean or、guard/lazy の禁止、短い lambda の E0254 | 変更なし | 変更なし | 変更なし | 既存の検査を維持し、入れ子と改行の表を拡張 |

## 実行した検査

| コマンド | 結果 |
|---|---|
| `cargo test -p benitoite --lib` | 1,166 件成功、既存の ignore 21 件。74.91 秒 |
| `cargo test -p benitoite --lib syntax:: -- --nocapture` | 110 件成功。後で追加した入力も最終の全 lib 検査で成功 |
| `cargo test -p benitoite --lib cli::tools::formatter -- --nocapture` | 30 件成功。最終の全 lib 検査でも成功 |
| `cargo test -p benitoite --test fmt_command --test golden --test spec_examples --test skill_docs` | fmt_command 15 件、golden の実行器 2 件、spec_examples 7 件、skill_docs 8 件がすべて成功。golden は 57.25 秒 |
| `cargo clippy --workspace --all-targets` | 成功。6.83 秒 |
| `cargo fmt --all --check` | 成功 |
| `git diff --check` | 成功 |
| `cargo run -p benitoite --example gen_skill` | 成功。生成物は既存と一致し、差分なし |
| `bash scripts/check-formal.sh` | manifest 登録後の全体の再実行が終了状態 0。lake build と六入口・交換形式の検査がすべて成功 |

コマンドは rtk 経由で実行した。通常検査のログは `/tmp/b7-{lib,integration,clippy,syntax,formatter,gen-skill}.log` にある。Rust とソース入力は通常検査後に変更していない。形式化の manifest だけを修正し、次の検査で確認した。

## 形式化の全入力の照合

初回の check-formal は Lean のビルド・交換形式・Rust の書き出し・比較まで成功し、最後に新しい fmt golden 一件の manifest 未登録で止まった。R54 に従って診断列と集計の増分を登録した。旧 manifest の全エントリが同一であり、新しい一件と check error の集計以外に差がないことも確認した。修正後は初回の同じ出力に対する `python3 -I crates/benitoite/tests/desugar_export/check_named.py target/desugar-diff/run-45451 target/coverage-diff/run-45451` が成功し、さらに check-formal 全体を最終の manifest で再実行して終了状態 0 を確認した。

| 入口 | 最終の結果 |
|---|---|
| desugarDiff | golden 968＋random 72,778＝73,746 定義が一致。不一致・定義の対象外・除外 0。プログラムは golden matched 349・check error の excluded 387、random matched 1,000・excluded 0 |
| builtinCheck | 1,349 入力・72,468 比較。不一致・非収束 0 |
| coverageDiff | 閉じた型 10,020 件と外部 view 付き 10,028 件が一致。不一致・燃料切れ 0 |
| coverageProgramDiff | match 16,417＋binding 6,036＝22,453 件が一致。不一致・対象外・燃料切れ 0 |
| surfaceCheck | 全 1,736 入力の識別子・診断列と、単独入口への振り分けが固定 manifest と一致 |
| surfaceCheckAll | matched 51,645・outOfScope 19・q11 1。不一致・準備失敗・lazyRestriction 0 |

全入力は新しい fmt golden 一件だけ増え、1,735→1,736 となった。追加した一件は E0301 17 件による名前解決の失敗であり、golden の check error が 386→387 となる。従来の対象内件数や対象外理由は変更していない。

交換形式の自己検査は width 4・named 12・extensible 22・try 8 の全 46 件が成功した。Rust の coverage_export は 2 件、desugar_export は 17 件が成功した。幅付きの 3 入力・30 定義も一致し、契約の破損 3 件、hole/pipe の破損 6 件、named export の破損 6 件を意図した理由で拒否した。corpus 9・型表 3・網羅性 3 の六入口が一致した。

最終の Rust の脱糖の書き出しは 570.65 秒、脱糖の比較は 27 秒、表層の全件検査は 21 秒、最後の照合は 204 秒だった。ログは `target/b7-check-formal.log`、比較結果は `target/desugar-diff/run-47852/` と `target/coverage-diff/run-47852/` にある。初回の失敗は `target/b7-check-formal-first.log`、初回の出力に対する修正後の照合は `target/b7-final-exports.log` に残す。Lean のソースと証明の変更、新しい axiom・sorry・admit・native_decide の追加はない。

## 計画との差と後の作業

変更箇所の最小の調整を R53・R54 の推す案として記録した。B7 の列挙にはない effects.rs に E0258 の判定があるため、その持ち主で修正した。新しい fmt golden は形式化の二つの manifest にも登録した。既に成立する停止条件・改行・印字を再実装しない。文法・型・脱糖・形式化の意味の変更はない。

次の B8 は終了結果・CLI・test runner の報告の型を担当する。Die の AST と説明の走査・型は B10a-1、脱糖は B10a-2、corpus 10 の出力は B10a-3、本番の受理と die を含む診断の案内は B11 に残す。コミット、docs/todo/ の編集、check.sh、gc-stress 構成の検査は行わない。
