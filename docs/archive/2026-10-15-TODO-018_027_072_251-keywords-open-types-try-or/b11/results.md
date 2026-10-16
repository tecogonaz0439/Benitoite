# B11 実装結果

## 変更と検査の境界

本番の parser で `or die` と `or die(message)` を受理し、先行する受理フラグと専用の cfg(test) の解析入口を除いた。既存の parser・formatter・modules・型検査・脱糖・交換の lib の検査は同じ公開の parse を使う。TryInfo の解決、Show 辞書、IR・バイトコード・実行の接続は先行実装を使う。

- parser: E0201 の単独の die と E0258 の `or return die` に処置の案内を追加し、E0259 の括弧の案内に die を加える。`[x]`・`-1` の既存の区別は変えない。
- 型検査: die の発生位置による E0501 に、Process の import がなければ import と uses を、あれば取り込んだ名前の uses を案内する。内部依存は利用者名を追加しない。Process の別名の import は既存の E0339 で拒否する（R63）。
- test runner: ソースから die の失敗・次のテストの成功を Direct/Request と文章/JSON で確認する。文章は R70 に従い、die では通常の exit の行を省く。JSON と通常の exit は保つ。
- 実行入力: Result/Option の成功を一つ、Result の複数行の説明付き失敗と Option の説明なしの失敗を一つずつ追加する。golden は VM/参照インタプリタ、IO の二方式、コア検査とフォーマッタの性質を既存の経路で比較する。追加の Show 不足と uses/import 不足の二件を含む新しい五件だけの golden の期待値を書き出し、別の CLI プロセスの検査で原因・説明・位置・終了状態・報告一回を独立に確認する。既存の golden は再生成しない。
- 現行文書: 受理した構文・型・エフェクト・評価と、先行検査から本番へ接続した範囲を揃える。生成物は gen_skill で再生成する。

## test-audit の作成時の関門

1. 主な境界は parser の公開の parse、pipeline の通常の読み込みからの型検査、CLI のプロセス、test runner の CLI、交換器と六入口である。各境界で AST、診断、依存、報告、終了状態、型付き表層とコアを観測する。
2. 本番だけ Die を拒否する、説明を落とす、標準依存をロードしない、Process の利用者名を暗黙に公開する、import/uses の案内を欠く、die を通常の exit としてだけ描画する、次のテストを実行しない、交換で Return へ変える退行を捕まえる。
3. 既存の AST 差し替えの fixture は、通常のソースからの内部依存の自動追加を証明しない。構造化した DieFailure の描画検査は、ソースの受理からの接続を証明しない。golden の差分は実行の意味、CLI の検査は文章/JSON の構造、test runner はテストごとの失敗の分類と継続を分担する。parser の既存の表を更新し、裸の try の成功・失敗の検査は維持する。
4. テストのための公開 API・本番フラグ・処理系の段の置き換えは加えない。先行する専用の解析入口は除いた。

R70 の修正前に `die_source_fails_one_test_and_keeps_running` が余分な `called Process.exit` の行で失敗した（`/private/tmp/b11-test-runner-first.log`）。本番の名前の公開を拒否する実際のコードは E0332 であり、新しい表の期待を実装に合わせた。既存の E0332 と E0339 の規則は変更していない。

## 診断と報告の対応

すべての静的な診断の終了状態は2、die の既定の実行の終了状態は1である。

| 対象 | 旧→新 | 主文・位置・help・維持する検査 |
|---|---|---|
| 単独の die / die(message) | E0201→E0201 | `expected an expression, found die` の主文と die の主位置は維持。try の処置を案内する help を追加。名前の E0216 と単独の拒否表を維持 |
| try r or die / die(message) | E0201→受理 | 処置の AST・任意の説明・改行・Pratt の境界を既存の parser 表で検査。本番の拒否の assert は、無診断の assert に更新 |
| try r or return die | E0201→E0258 | 主文は `invalid failure action after try`、主位置は die。return は値を取らないことと die の処置を案内。副位置なし。上の旧拒否表の二行をこの負の入力へ替え、単独の die の拒否は別の行で維持 |
| 明示形の継続 | E0259→E0259 | 主文・継続の主位置を維持。help に `(try ... or die)` を追加し、既存の完全一致の期待値を更新 |
| die の Exit 不足 | E0501→E0501 | 主文・die の主位置・宣言の副位置を維持。通常の効果不足の案内を、die の uses と必要な import の具体的な案内へ替える。通常の exit・他の効果・E0502 の既存の検査を維持 |
| test runner の文章 | 通常の exit の行＋die→die | die の報告を先頭に一回。原因・任意の説明・ソース位置・補足の順序を保持。通常の exit と JSON は既存の assert を維持 |

## 検査

scripts/check.sh（dry-run を含む）と gc-stress の構成は依頼に従って実行していない。formal の定義・証明は変更していない。

最終ツリーで、次の一式が終了状態0で成功した。ログは `/private/tmp/b11-rust-final.log` に置いた。

```sh
cargo test -p benitoite --lib --test golden --test desugar_export --test random_programs --test fmt_command --test cli_process --test test_command --test skill_docs --test skill_examples --test spec_examples --no-fail-fast
```

| 検査 | 結果 |
|---|---|
| lib | 1,192件成功。既存の長い21件は既定どおり未実行。77.54秒 |
| golden | 2件成功。通常の全入力を比較。56.08秒 |
| desugar_export | 16件成功。通常は未実行の全件出力1件も check-formal.sh の include-ignored で成功 |
| random_programs | 3件成功。49.92秒で、既定の60秒の時間制限内。件数や環境変数の上書きなし |
| fmt_command / cli_process / test_command | 15件 / 9件 / 18件成功 |
| skill_docs / skill_examples / spec_examples | 8件 / 3件 / 7件成功 |
| gen_skill | 再生成成功。生成物の一致は skill_docs で確認 |
| cargo clippy --workspace --all-targets | 成功。5.78秒。`/private/tmp/b11-clippy-final.log` |
| cargo fmt --all --check / git diff --check | 成功 |

最初の統合した一式では、生成器の固定の説明を更新する前にビルドした skill_docs が grammar.md の不一致で失敗した。gen_skill を再実行し、その後の skill_docs 8件・skill_examples 3件・spec_examples 7件は成功した。検査の期待値は変更していない。

`bash scripts/check-formal.sh` は lake build と六入口の本体、独立入力46件、全件の Rust の書き出しまで成功した。最後の manifest の照合だけが新しい五入力の未登録で停止した。書き出された同じ出力に対し、旧1,736入力の routing と programs の全行が一致することを確認してから、五入力と七定義だけを manifest に追加した。Rust の入力と交換器は変えず、最終の `python3 -I crates/benitoite/tests/desugar_export/check_named.py target/desugar-diff/b11-final target/coverage-diff/b11-final` を再実行して成功した。既存の対象内件数・対象外理由を下方修正していない。

| 六入口 | 結果 |
|---|---|
| coverageDiff | 通常10,020件、view付き10,028件が一致。不一致・fuelExhausted 0 |
| desugarDiff | golden 352入力、random 1,000入力が一致。全1,741入力中、対象1,352入力、静的な検査エラー389入力、範囲外0入力。golden の975定義・random の72,778定義が一致 |
| builtinCheck | 対象1,352入力、summary 比較72,600件が一致。不一致・非収束0 |
| coverageProgramDiff | match 16,417件・bind 6,036件、計22,453件が一致。不一致・範囲外・fuelExhausted 0 |
| surfaceCheckAll | 51,652件一致。不一致・準備失敗・lazyRestriction 0。既存の対象外19件・q11 1件を維持 |
| surfaceCheck と最終 manifest | 全1,741入力・73,753定義・22,453 coverage entries の対応が一致。corpus 10・型表3・網羅性3と六入口の件数・分類が一致 |

新しい成功側の三入力は合計七定義を持つ。二つの `bind _` は交換器が網羅性の対象にしないため、coverage entries は増えない。die が生成する内部照合もソースの網羅性の件数へ加えない。契約の破損3件・hole/pipe の破損6件・名前付きの破損6件を意図した理由で拒否し、die の版・必須欄・辞書・メソッド・exit・説明の独立した破損検査も成功した。lake build は成功し、新しい sorry・axiom・admit・native_decide はない。

形式化の出力は `target/desugar-diff/b11-final/` と `target/coverage-diff/b11-final/`、ログは `/private/tmp/b11-formal.log`・`b11-formal-final-compare.log`・`b11-manifest-update.log` に置いた。全件の Rust 書き出しは562.547秒だった。

Rust の差分は本番のコードが108行追加・49行削除、テストと準備が224行追加・32行削除である（既存ファイルの差分。生成物・manifest・新しい五入力は別）。既存の assert の個数は減らさず、受理の切り替えと R70 の文章表示だけを厳密な新しい期待値へ更新した。既存の ignore・乱択の60秒の制限は変更していない。

## 計画との差と申し送り

R72 に、先行する拒否の検査の更新と R70 の小さな文章の修正の先行を、R73 に新しいソースと manifest の追加、および Skill の受理の説明の同期を記録した。B12 の評価回数・ハンドラ・タスク・解放・flush・競合停止の追加検査、B13 の英語 reference と手書き Skill、B14 の段末検査は後続の担当である。コミットと docs/todo の変更は行わない。
